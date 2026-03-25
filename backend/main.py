from dotenv import load_dotenv
load_dotenv()  # Must be first — before any service imports read os.getenv()

import uuid
import json
import os
import time
import sys
from datetime import datetime
from collections import defaultdict

import httpx
from fastapi import Depends, FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware

from google import genai
from google.genai import types

from prompts import (
    get_chatbot_system_prompt,
    get_extraction_system_prompt,
    build_extraction_prompt,
)
from routes import reports, telegram
from utils.security import build_rate_limit_middleware, require_roles
from config.environment import EnvironmentValidator
from config.logging import StructuredLogger

# ── Supabase client ───────────────────────────────────────────────────────────
def _get_supabase():
    """Lazy Supabase client — supports both common key name variants."""
    from supabase import create_client
    url = os.getenv('SUPABASE_URL')
    # Support both SUPABASE_SERVICE_KEY and SUPABASE_SERVICE_ROLE_KEY
    key = os.getenv('SUPABASE_SERVICE_KEY') or os.getenv('SUPABASE_SERVICE_ROLE_KEY')
    if not url or not key:
        raise ValueError(
            f'Supabase credentials missing. '
            f'URL={bool(url)} KEY={bool(key)}. '
            f'Check your .env file.'
        )
    return create_client(url, key)


# ── Gemini client (new SDK) ────────────────────────────────────────────────────
_gemini = genai.Client(api_key=os.getenv('GEMINI_API_KEY'))
_MODEL = 'gemini-2.5-flash'

# ── In-memory session store  {session_id: [{"role": ..., "parts": [...]}]} ────
sessions: dict[str, list] = {}

# ── FastAPI app ────────────────────────────────────────────────────────────────
app = FastAPI(
    title='MapSumbong API',
    description='Backend API for disaster reporting system',
    version='1.0.0',
)

# ── Initialize structured logging ──────────────────────────────────────────────
logger = StructuredLogger.setup('mapsumbong')

# ── Validate environment on startup ────────────────────────────────────────────
def _validate_environment_startup():
    """Validate environment variables. Exit with error if critical vars missing."""
    logger.info('Validating environment configuration...')
    
    try:
        validator = EnvironmentValidator()
        
        # Check required variables
        is_valid, missing = validator.validate_required()
        if not is_valid:
            logger.error(f'Missing required environment variables: {missing}')
            logger.error('Application cannot start without these variables.')
            sys.exit(1)
        
        # Print startup report
        logger.info('Environment validation passed.')
        validator.print_startup_report()
        
    except Exception as e:
        logger.error(f'Environment validation failed: {e}')
        sys.exit(1)

# Run validation on module load (before app starts)
_validate_environment_startup()


def _cors_allow_origins() -> list[str]:
    raw = os.getenv('CORS_ALLOW_ORIGINS', '')
    if raw.strip():
        return [o.strip() for o in raw.split(',') if o.strip()]
    if os.getenv('ENVIRONMENT', 'development').lower() == 'development':
        return ['*']
    return []


_request_metrics = {
    'total': 0,
    'by_path': defaultdict(int),
    'by_status': defaultdict(int),
    'latency_ms_total': 0.0,
}


@app.middleware('http')
async def request_metrics_middleware(request: Request, call_next):
    start = time.perf_counter()
    request_id = str(uuid.uuid4())

    try:
        response = await call_next(request)
    except Exception:
        elapsed_ms = (time.perf_counter() - start) * 1000.0
        _request_metrics['total'] += 1
        _request_metrics['by_path'][request.url.path] += 1
        _request_metrics['by_status']['500'] += 1
        _request_metrics['latency_ms_total'] += elapsed_ms
        return JSONResponse(
            status_code=500,
            content={'detail': 'Internal server error', 'request_id': request_id},
        )

    elapsed_ms = (time.perf_counter() - start) * 1000.0
    _request_metrics['total'] += 1
    _request_metrics['by_path'][request.url.path] += 1
    _request_metrics['by_status'][str(response.status_code)] += 1
    _request_metrics['latency_ms_total'] += elapsed_ms
    response.headers['X-Request-ID'] = request_id
    response.headers['X-Response-Time-Ms'] = f'{elapsed_ms:.2f}'
    return response

app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_allow_origins(),
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*'],
)
app.middleware('http')(build_rate_limit_middleware())

app.include_router(reports.router, tags=['reports'])
app.include_router(telegram.router, prefix='/telegram', tags=['telegram'])


# ── Health checks ──────────────────────────────────────────────────────────────

@app.get('/')
def health_check():
    return {
        'status': 'healthy',
        'service': 'MapSumbong Backend',
        'version': '1.0.0',
        'environment': os.getenv('ENVIRONMENT', 'development'),
    }


@app.get('/health')
def detailed_health():
    return {
        'status': 'healthy',
        'services': {
            'gemini_api': 'configured' if os.getenv('GEMINI_API_KEY') else 'not_configured',
            'supabase': 'configured' if os.getenv('SUPABASE_URL') else 'not_configured',
        },
        'environment': os.getenv('ENVIRONMENT', 'development'),
    }


@app.get('/ready')
def readiness():
    missing = []
    if not os.getenv('SUPABASE_URL'):
        missing.append('SUPABASE_URL')
    if not os.getenv('SUPABASE_SERVICE_KEY') and not os.getenv('SUPABASE_SERVICE_ROLE_KEY'):
        missing.append('SUPABASE_SERVICE_KEY|SUPABASE_SERVICE_ROLE_KEY')
    if not os.getenv('JWT_SECRET'):
        missing.append('JWT_SECRET')

    if missing:
        return {
            'ready': False,
            'missing': missing,
        }
    return {'ready': True}


@app.get('/metrics')
def metrics(_user: dict = Depends(require_roles('admin'))):
    total = _request_metrics['total']
    avg_latency = (
        _request_metrics['latency_ms_total'] / total if total > 0 else 0.0
    )
    return {
        'total_requests': total,
        'avg_latency_ms': round(avg_latency, 2),
        'by_path': dict(_request_metrics['by_path']),
        'by_status': dict(_request_metrics['by_status']),
    }


# ── Main chat / report-creation endpoint ──────────────────────────────────────

@app.post('/process-message')
async def process_message(
    payload: dict,
    _user: dict = Depends(require_roles('user', 'admin')),
):
    """
    Multi-turn AI conversation that extracts a structured report.

    Payload:  { message, reporter_id?, session_id?, latitude?, longitude? }
    Returns:  { success, session_id, response, is_complete, report_data }
    """
    try:
        user_message = payload.get('message', '').strip()
        session_id = payload.get('session_id') or str(uuid.uuid4())
        latitude = payload.get('latitude')
        longitude = payload.get('longitude')

        if not user_message:
            raise HTTPException(status_code=400, detail='message is required')

        if session_id not in sessions:
            sessions[session_id] = []

            # On the FIRST turn only, if GPS coords were provided,
            # reverse-geocode them and inject location context so Gemini
            # never needs to ask for the barangay.
            if latitude is not None and longitude is not None:
                location_info = await _reverse_geocode(latitude, longitude)
                # Prepend a hidden system note so Gemini treats GPS as
                # authoritative location even when reverse geocoding fails.
                if location_info:
                    location_context = (
                        f"[SYSTEM: The resident's GPS location has been captured. "
                        f"Coordinates: {latitude:.5f}, {longitude:.5f}. "
                        f"Address: {location_info}. "
                        f"Use this as the location — do NOT ask for barangay or address.]"
                    )
                else:
                    location_context = (
                        f"[SYSTEM: The resident's GPS location has been captured. "
                        f"Coordinates: {latitude:.5f}, {longitude:.5f}. "
                        f"Use these GPS coordinates as the report location. "
                        f"Do NOT ask for barangay or address; infer locality from coordinates if needed.]"
                    )

                sessions[session_id] = [{
                    'role': 'user',
                    'parts': [location_context]
                }, {
                    'role': 'model',
                    'parts': ['Noted. I have the location from GPS.']
                }]

        history = sessions[session_id]

        # Build contents list for multi-turn: history + new user turn
        contents = []
        for turn in history:
            role = 'user' if turn['role'] == 'user' else 'model'
            contents.append(types.Content(
                role=role,
                parts=[types.Part(text=turn['parts'][0])],
            ))
        contents.append(types.Content(
            role='user',
            parts=[types.Part(text=user_message)],
        ))

        response = _gemini.models.generate_content(
            model=_MODEL,
            contents=contents,
            config=types.GenerateContentConfig(
                system_instruction=get_chatbot_system_prompt(),
            ),
        )
        ai_reply = response.text

        # Persist history
        history.append({'role': 'user', 'parts': [user_message]})
        history.append({'role': 'model', 'parts': [ai_reply]})
        sessions[session_id] = history

        # Attempt structured extraction after enough context
        report_data = None
        is_complete = False
        if len(history) >= 6:
            report_data, is_complete = await _extract_report_data(history)

        # Always inject GPS into report_data if provided
        if report_data and latitude is not None and longitude is not None:
            report_data['latitude'] = report_data.get('latitude') or latitude
            report_data['longitude'] = report_data.get('longitude') or longitude

        return {
            'success': True,
            'session_id': session_id,
            'response': ai_reply,
            'is_complete': is_complete,
            'report_data': report_data,
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f'submit_report error: {e}')
        return {'success': False, 'error': str(e)}


# ── Structured extraction ──────────────────────────────────────────────────────

async def _extract_report_data(history: list) -> tuple[dict | None, bool]:
    try:
        prompt = build_extraction_prompt(history)

        response = _gemini.models.generate_content(
            model=_MODEL,
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction=get_extraction_system_prompt(),
            ),
        )

        raw = response.text.strip()
        if raw.startswith('```'):
            parts = raw.split('```')
            raw = parts[1] if len(parts) > 1 else raw
            if raw.startswith('json'):
                raw = raw[4:]
        raw = raw.strip()

        data = json.loads(raw)
        is_complete = bool(data.get('is_complete', False))

        # Geocode if location present but no coordinates yet
        if data.get('location_text') and not data.get('latitude'):
            coords = await _geocode(data['location_text'])
            if coords:
                data['latitude'] = coords['lat']
                data['longitude'] = coords['lon']

        if is_complete and not data.get('report_id'):
            data['report_id'] = f'RPT-{uuid.uuid4().hex[:8].upper()}'

        return data, is_complete

    except Exception as e:
        print(f'Extraction error: {e}')
        return None, False


# ── Nominatim reverse geocoding ───────────────────────────────────────────────

async def _reverse_geocode(lat: float, lng: float) -> str | None:
    """Convert GPS coordinates to a human-readable address string."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(
                'https://nominatim.openstreetmap.org/reverse',
                params={
                    'lat': lat,
                    'lon': lng,
                    'format': 'json',
                    'addressdetails': 1,
                },
                headers={'User-Agent': 'MapSumbong/1.0'},
            )
            data = resp.json()

        address = data.get('address', {})
        parts = []

        # Build address from most specific to least
        for key in ['village', 'suburb', 'city_district', 'quarter',
                    'neighbourhood', 'city', 'municipality', 'province']:
            val = address.get(key)
            if val:
                parts.append(val)
            if len(parts) >= 3:
                break

        return ', '.join(parts) if parts else data.get('display_name', '')
    except Exception as e:
        print(f'Reverse geocode error: {e}')
        return None


# ── Nominatim forward geocoding ────────────────────────────────────────────────

async def _geocode(location_text: str) -> dict | None:
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(
                'https://nominatim.openstreetmap.org/search',
                params={
                    'q': f'{location_text}, Philippines',
                    'format': 'json',
                    'limit': 1,
                    'countrycodes': 'ph',
                },
                headers={'User-Agent': 'MapSumbong/1.0'},
            )
            results = resp.json()

        if results:
            return {
                'lat': float(results[0]['lat']),
                'lon': float(results[0]['lon']),
            }
    except Exception:
        pass
    return None


# ── Submit confirmed report to Supabase ───────────────────────────────────────

@app.post('/submit-report')
async def submit_report(
    payload: dict,
    _user: dict = Depends(require_roles('user', 'admin')),
):
    try:
        supabase = _get_supabase()

        report = {
            'id': payload.get('report_id') or f'RPT-{uuid.uuid4().hex[:8].upper()}',
            'reporter_anonymous_id': payload.get('reporter_anonymous_id', 'ANON-UNKNOWN'),
            'issue_type': payload.get('issue_type', 'other'),
            'description': payload.get('description', ''),
            'latitude': payload.get('latitude') or 14.6942,
            'longitude': payload.get('longitude') or 120.9834,
            'location_text': payload.get('location_text', ''),
            'urgency': payload.get('urgency', 'medium'),
            'sdg_tag': payload.get('sdg_tag'),
            'status': 'received',
            'barangay': payload.get('barangay', 'unknown'),
            'photo_url': payload.get('photo_url'),
        }

        supabase.table('reports').insert(report).execute()

        return {
            'success': True,
            'report_id': report['id'],
            'message': f"Report {report['id']} saved successfully.",
        }

    except Exception as e:
        print(f'submit_report error: {e}')
        return {'success': False, 'error': str(e)}


@app.post('/send-message')
async def send_message(
    payload: dict,
    _user: dict = Depends(require_roles('user', 'admin')),
):
    try:
        supabase = _get_supabase()
        report_id = payload.get('report_id')
        sender_id = payload.get('sender_id')
        sender_type = payload.get('sender_type')
        content = payload.get('content', '').strip()

        if not report_id or not sender_id or not sender_type or not content:
            raise HTTPException(
                status_code=400,
                detail='report_id, sender_id, sender_type, and content are required',
            )

        message = {
            'report_id': report_id,
            'sender_id': sender_id,
            'sender_type': sender_type,
            'content': content,
            'message_type': payload.get('message_type', 'text'),
            'image_url': payload.get('image_url'),
            'timestamp': datetime.utcnow().isoformat(),
        }
        result = supabase.table('messages').insert(message).execute()
        return {'success': True, 'message': result.data[0] if result.data else message}
    except HTTPException:
        raise
    except Exception as e:
        print(f'send_message error: {e}')
        return {'success': False, 'error': str(e)}


# ── Session helpers ────────────────────────────────────────────────────────────

@app.get('/session/{session_id}')
def get_session(
    session_id: str,
    _user: dict = Depends(require_roles('user', 'admin')),
):
    history = sessions.get(session_id, [])
    return {'session_id': session_id, 'history': history, 'message_count': len(history)}


@app.delete('/session/{session_id}')
def clear_session(
    session_id: str,
    _user: dict = Depends(require_roles('user', 'admin')),
):
    sessions.pop(session_id, None)
    return {'success': True}