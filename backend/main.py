from dotenv import load_dotenv
load_dotenv()  # Must be first — before any service imports read os.getenv()

import uuid
import json
import os

import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from google import genai
from google.genai import types

from prompts import (
    get_chatbot_system_prompt,
    get_extraction_system_prompt,
    build_extraction_prompt,
)
from routes import reports, telegram

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
async def process_message(payload: dict):
    """
    Multi-turn AI conversation that extracts a structured report.

    Payload:  { message, reporter_id?, session_id? }
    Returns:  { success, session_id, response, is_complete, report_data }
    """
    try:
        user_message = payload.get('message', '').strip()
        session_id = payload.get('session_id') or str(uuid.uuid4())

        if not user_message:
            raise HTTPException(status_code=400, detail='message is required')

        if session_id not in sessions:
            sessions[session_id] = []

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

        return {
            'success': True,
            'session_id': session_id,
            'response': ai_reply,
            'is_complete': is_complete,
            'report_data': report_data,
        }

    except Exception as e:
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


# ── Nominatim geocoding ────────────────────────────────────────────────────────

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
async def submit_report(payload: dict):
    try:
        from supabase import create_client
        supabase = create_client(
            os.getenv('SUPABASE_URL'),
            os.getenv('SUPABASE_SERVICE_KEY'),
        )

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
        return {'success': False, 'error': str(e)}


# ── Session helpers ────────────────────────────────────────────────────────────

@app.get('/session/{session_id}')
def get_session(session_id: str):
    history = sessions.get(session_id, [])
    return {'session_id': session_id, 'history': history, 'message_count': len(history)}


@app.delete('/session/{session_id}')
def clear_session(session_id: str):
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