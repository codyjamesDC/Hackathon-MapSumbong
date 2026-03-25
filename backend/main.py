from dotenv import load_dotenv
load_dotenv()  # Must be first — before any service imports read os.getenv()

import uuid
import json
import os
from datetime import datetime

import httpx
from fastapi import Depends, FastAPI, HTTPException
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

app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
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
                if location_info:
                    # Prepend a hidden system note to the conversation
                    # so Gemini already knows the location
                    location_context = (
                        f"[SYSTEM: The resident's GPS location has been captured. "
                        f"Coordinates: {latitude:.5f}, {longitude:.5f}. "
                        f"Address: {location_info}. "
                        f"Use this as the location — do NOT ask for barangay or address.]"
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


# ── Telegram webhook (simple passthrough) ─────────────────────────────────────

@app.post('/telegram-webhook')
async def telegram_webhook(payload: dict):
    try:
        message = payload.get('message', {})
        chat_id = message.get('chat', {}).get('id')
        text = message.get('text', '')

        if not chat_id or not text:
            return {'ok': True}

        result = await process_message(
            {'message': text, 'session_id': f'telegram_{chat_id}'}
        )

        bot_token = os.getenv('TELEGRAM_BOT_TOKEN')
        if bot_token and result.get('success'):
            async with httpx.AsyncClient() as client:
                await client.post(
                    f'https://api.telegram.org/bot{bot_token}/sendMessage',
                    json={
                        'chat_id': chat_id,
                        'text': result['response'],
                    },
                )
        return {'ok': True}

    except Exception as e:
        return {'ok': False, 'error': str(e)}