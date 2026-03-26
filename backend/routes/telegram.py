from fastapi import APIRouter, Request
import httpx
import os
import tempfile
import hmac
import uuid
from collections import defaultdict, deque
from supabase import create_client

from services.whisper_service import transcribe_audio
from services.gemini_service import process_message as process_with_gemini
from config.logging import get_logger
from utils.geocoding import get_coordinates, reverse_geocode_barangay
from utils.los_banos_data import LOS_BANOS_CENTER

logger = get_logger(__name__)

router = APIRouter()

TELEGRAM_BOT_TOKEN = os.getenv('TELEGRAM_BOT_TOKEN')
TELEGRAM_API_BASE = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}"

# Keep lightweight per-chat context to avoid repetitive follow-up questions.
_CHAT_HISTORY: dict[int, deque[str]] = defaultdict(lambda: deque(maxlen=8))
_CHAT_ACK_SENT: dict[int, bool] = defaultdict(bool)
_CHAT_REPORT_ID: dict[int, str] = {}

_ALLOWED_ISSUE_TYPES = {
    'flood', 'waste', 'road_hazard', 'road', 'power_outage', 'power',
    'water_supply', 'water', 'medical', 'emergency', 'fire', 'crime',
    'landslide', 'earthquake_damage', 'other',
}
_ALLOWED_URGENCY = {'critical', 'high', 'medium', 'low'}


def _get_supabase_client():
    url = os.getenv('SUPABASE_URL')
    key = os.getenv('SUPABASE_SERVICE_KEY') or os.getenv('SUPABASE_SERVICE_ROLE_KEY')
    if not url or not key:
        raise ValueError('Supabase credentials missing for Telegram report persistence')
    return create_client(url, key)


def _normalize_issue_type(value: str | None) -> str:
    raw = str(value or '').strip().lower().replace(' ', '_').replace('-', '_')
    aliases = {
        'pothole': 'road_hazard',
        'fallen_tree': 'road_hazard',
        'obstruction': 'road_hazard',
        'brownout': 'power_outage',
        'blackout': 'power_outage',
        'roadhazard': 'road_hazard',
    }
    normalized = aliases.get(raw, raw)
    if normalized in _ALLOWED_ISSUE_TYPES:
        return normalized
    return 'other'


def _normalize_urgency(value: str | None) -> str:
    raw = str(value or '').strip().lower()
    if raw in _ALLOWED_URGENCY:
        return raw
    return 'medium'


def _extract_location_from_history(chat_id: int) -> str:
    lines = list(_CHAT_HISTORY.get(chat_id, []))
    resident_lines = [line for line in lines if line.startswith('Resident:')]
    for line in reversed(resident_lines):
        text = line.replace('Resident:', '', 1).strip()
        if any(token in text.lower() for token in (' sa ', ' near ', ' tapat ', ' gate ', ' park ', ' barangay ')):
            return text
    return resident_lines[-1].replace('Resident:', '', 1).strip() if resident_lines else ''


def _extract_barangay_hint(location_text: str) -> str:
    text = (location_text or '').lower()
    known = [
        'anos', 'bagong silang', 'bambang', 'batong malake', 'baybayin', 'bayog',
        'lalakay', 'maahas', 'malinta', 'mayondon', 'putho-tuntungin',
        'san antonio', 'tadlac', 'timugan',
    ]
    for name in known:
        if name in text:
            return name.title()
    return ''


async def _persist_telegram_report(chat_id: int, user_message: str, extracted_data: dict) -> str | None:
    issue_type = _normalize_issue_type(extracted_data.get('issue_type'))
    if issue_type == 'other':
        return None

    location_text = str(extracted_data.get('location_text') or '').strip()
    if not location_text:
        location_text = _extract_location_from_history(chat_id)
    if not location_text:
        return None

    description = str(extracted_data.get('description') or '').strip()
    if not description:
        description = user_message.strip() or 'Incident reported via Telegram'

    barangay = str(extracted_data.get('barangay') or '').strip()
    barangay_hint = _extract_barangay_hint(location_text)
    if not barangay and barangay_hint:
        barangay = barangay_hint

    lat = extracted_data.get('latitude')
    lng = extracted_data.get('longitude')
    if lat is None or lng is None:
        try:
            coords = await get_coordinates(location_text, barangay or 'Batong Malake')
            lat = coords.get('lat')
            lng = coords.get('lng')
        except Exception:
            lat = None
            lng = None

    if lat is None or lng is None:
        lat = float(LOS_BANOS_CENTER['lat'])
        lng = float(LOS_BANOS_CENTER['lng'])

    if not barangay:
        try:
            barangay = reverse_geocode_barangay(float(lat), float(lng))
        except Exception:
            barangay = ''
    if not barangay or barangay == 'Unknown':
        barangay = 'Batong Malake'

    reporter_id = os.getenv('TELEGRAM_DEFAULT_REPORTER_ANON_ID', 'ANON-DEV01').strip() or 'ANON-DEV01'
    supabase = _get_supabase_client()

    existing = (
        supabase.table('users')
        .select('anonymous_id')
        .eq('anonymous_id', reporter_id)
        .limit(1)
        .execute()
    )
    if not existing.data:
        supabase.table('users').insert({
            'anonymous_id': reporter_id,
            'account_type': 'resident',
            'display_name': f'Telegram {chat_id}',
            'is_anonymous': True,
            'barangay': barangay,
        }).execute()

    report_id = f'RPT-{uuid.uuid4().hex[:8].upper()}'
    report = {
        'id': report_id,
        'reporter_anonymous_id': reporter_id,
        'issue_type': issue_type,
        'description': description,
        'latitude': float(lat),
        'longitude': float(lng),
        'location_text': location_text,
        'urgency': _normalize_urgency(extracted_data.get('urgency')),
        'sdg_tag': extracted_data.get('sdg_tag'),
        'status': 'received',
        'barangay': barangay,
        'photo_url': None,
    }

    supabase.table('reports').insert(report).execute()
    return report_id


def _is_reset_intent(user_message: str) -> bool:
    text = (user_message or '').strip().lower()
    return text in {
        '/start',
        '/reset',
        'start',
        'reset',
        'new report',
        'bagong report',
    }


def _append_chat_turn(chat_id: int, role: str, text: str):
    clean = str(text or '').strip().replace('\n', ' ')
    if not clean:
        return
    _CHAT_HISTORY[chat_id].append(f'{role}: {clean[:280]}')


def _build_contextual_input(chat_id: int, user_message: str) -> str:
    history = list(_CHAT_HISTORY.get(chat_id, []))
    if not history:
        return user_message

    context_text = '\n'.join(history)
    return (
        'Conversation context (latest turns):\n'
        f'{context_text}\n\n'
        f'Current resident message: {user_message}\n'
        'Continue the same report intake conversation. '
        'Avoid asking again for details already provided unless clarification is truly needed.'
    )


def _is_valid_report_id(report_id: str | None) -> bool:
    if not report_id:
        return False

    normalized = report_id.strip().upper()
    invalid_placeholders = {'N/A', 'NA', 'NONE', 'NULL', 'UNKNOWN', '-', ''}
    if normalized in invalid_placeholders:
        return False

    return True


def _looks_like_report_intent(user_message: str, extracted_data: dict) -> bool:
    text = (user_message or '').strip().lower()
    if not text:
        return False

    greeting_only = {
        'hi', 'hello', 'hey', 'good morning', 'good afternoon', 'good evening',
        'kumusta', 'kamusta', 'kumusta po', 'kamusta po', 'yo', 'hola',
    }
    if text in greeting_only:
        return False

    # Fast path for common report verbs in Filipino/English.
    report_keywords = {
        'report', 'i-report', 'ireport', 'sumbong', 'isyu', 'issue',
        'pothole', 'flood', 'baha', 'sunog', 'aksidente', 'crime',
        'broken', 'sira', 'barado', 'landslide',
    }
    if any(keyword in text for keyword in report_keywords):
        return True

    # For very short messages without clear issue keywords, treat as general chat.
    word_count = len([w for w in text.split() if w])
    if word_count <= 3:
        return False

    issue_type = str(extracted_data.get('issue_type', '')).strip().lower()
    description = str(extracted_data.get('description', '')).strip()
    location_text = str(extracted_data.get('location_text', '')).strip()

    # Consider it a report when extraction contains concrete details,
    # but only after a sufficiently descriptive user message.
    if len(text) < 15:
        return False

    if issue_type and issue_type not in {'other', 'general', 'unknown', 'none'}:
        return True
    if len(description) >= 20:
        return True
    if location_text:
        return True

    return False


def _validate_telegram_secret(request_headers: dict) -> bool:
    """
    Validate Telegram webhook secret token.

    Telegram includes the configured secret token in
    X-Telegram-Bot-Api-Secret-Token for webhook requests.
    """
    expected_secret = os.getenv('TELEGRAM_BOT_SECRET', '')
    if not expected_secret:
        logger.warning('Telegram webhook secret not configured; skipping signature verification')
        return True

    try:
        provided_secret = (
            request_headers.get('X-Telegram-Bot-Api-Secret-Token')
            or request_headers.get('x-telegram-bot-api-secret-token')
            or ''
        )
        if not provided_secret:
            logger.warning('Missing X-Telegram-Bot-Api-Secret-Token header')
            return False

        # Constant-time compare to reduce token oracle risk.
        if not hmac.compare_digest(provided_secret, expected_secret):
            logger.error('Telegram secret token mismatch')
            return False

        logger.debug('Telegram webhook secret token valid')
        return True
    except Exception as e:
        logger.error(f'Telegram secret token validation error: {e}')
        return False


async def send_telegram_message(chat_id: int, text: str):
    """Send message to Telegram user"""
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                f"{TELEGRAM_API_BASE}/sendMessage",
                json={'chat_id': chat_id, 'text': text}
            )
            response.raise_for_status()
            logger.debug(f'Telegram message sent to chat_id={chat_id}')
    except Exception as e:
        logger.error(f'Failed to send Telegram message to {chat_id}: {e}')


@router.post('/webhook')
async def telegram_webhook(request: Request):
    """Handle incoming Telegram messages"""

    await request.body()

    try:
        # Validate webhook secret token (security)
        if not _validate_telegram_secret(dict(request.headers)):
            logger.warning('Telegram webhook secret token validation failed')
            return {'ok': False, 'error': 'Invalid webhook secret'}
        
        update = await request.json()
        
        # Log incoming message for auditing
        message_id = update.get('update_id', 'UNKNOWN')
        logger.info(f'Telegram webhook received: update_id={message_id}')

        if 'message' not in update:
            logger.debug('Webhook received but no message field')
            return {'ok': True}

        message = update['message']
        chat_id = message.get('chat', {}).get('id', 'UNKNOWN')
        from_id = message.get('from', {}).get('id', 'UNKNOWN')
        
        logger.info(f'Processing Telegram message from chat_id={chat_id}, user_id={from_id}')

        # Handle text messages
        if 'text' in message:
            user_message = message['text']
            logger.debug(f'Text message: {user_message[:50]}...')

            try:
                if _is_reset_intent(user_message):
                    _CHAT_HISTORY.pop(chat_id, None)
                    _CHAT_ACK_SENT[chat_id] = False
                    _CHAT_REPORT_ID.pop(chat_id, None)

                _append_chat_turn(chat_id, 'Resident', user_message)

                # Process with Gemini
                contextual_input = _build_contextual_input(chat_id, user_message)
                result = await process_with_gemini(contextual_input)
                extracted_data = result.get('extracted_data') or {}
                is_report_intent = _looks_like_report_intent(user_message, extracted_data)

                # Send response
                await send_telegram_message(chat_id, result['chatbot_response'])
                _append_chat_turn(chat_id, 'Assistant', result.get('chatbot_response', ''))

                if result['success'] and is_report_intent:
                    # Only send a report ID if one was actually generated.
                    report_id = _CHAT_REPORT_ID.get(chat_id) or result.get('report_id')
                    if not _is_valid_report_id(report_id):
                        try:
                            persisted_id = await _persist_telegram_report(chat_id, user_message, extracted_data)
                            if _is_valid_report_id(persisted_id):
                                report_id = persisted_id
                                _CHAT_REPORT_ID[chat_id] = persisted_id
                        except Exception as persist_error:
                            logger.error(f'Failed to persist Telegram report for chat_id={chat_id}: {persist_error}')

                    if _is_valid_report_id(report_id):
                        logger.info(f'Report created via Telegram: report_id={report_id}, chat_id={chat_id}')
                        _CHAT_ACK_SENT[chat_id] = False
                        _CHAT_HISTORY.pop(chat_id, None)
                        _CHAT_REPORT_ID.pop(chat_id, None)
                        await send_telegram_message(
                            chat_id,
                            f"✅ Report ID: {report_id}\n\nSalamat sa pag-report!"
                        )
                    elif not _CHAT_ACK_SENT[chat_id]:
                        logger.info(f'Telegram message processed without report ID: chat_id={chat_id}')
                        _CHAT_ACK_SENT[chat_id] = True
                        await send_telegram_message(
                            chat_id,
                            '✅ Natanggap ko ang report mo. Kukuha pa ako ng ilang detalye bago mag-generate ng Report ID.'
                        )
                elif result['success']:
                    logger.debug(f'Telegram message treated as general chat: chat_id={chat_id}')
            except Exception as e:
                logger.error(f'Error processing Telegram text message: {e}')
                await send_telegram_message(
                    chat_id,
                    'Nagka-problema sa pag-process ng mensahe. Pakisubukan ulit.'
                )

        # Handle voice messages
        elif 'voice' in message:
            logger.debug(f'Voice message from chat_id={chat_id}')
            voice = message.get('voice', {})
            file_id = voice.get('file_id')
            if not file_id:
                logger.warning(f'Voice message missing file_id from chat_id={chat_id}')
                await send_telegram_message(
                    chat_id,
                    'Hindi mabasa ang voice file. Pakisubukan ulit.'
                )
                return {'ok': True}

            if not TELEGRAM_BOT_TOKEN:
                logger.error('Telegram bot token not configured')
                await send_telegram_message(
                    chat_id,
                    'Server misconfiguration: missing Telegram bot token.'
                )
                return {'ok': True}

            temp_path = None
            try:
                async with httpx.AsyncClient(timeout=20.0) as client:
                    # 1) Resolve Telegram file path from file_id
                    file_resp = await client.get(
                        f'{TELEGRAM_API_BASE}/getFile',
                        params={'file_id': file_id},
                    )
                    file_data = file_resp.json()
                    tg_path = file_data.get('result', {}).get('file_path')
                    if not tg_path:
                        logger.error(f'Could not resolve file_path for file_id={file_id}')
                        await send_telegram_message(
                            chat_id,
                            'Hindi ma-download ang voice file. Pakisubukan ulit.'
                        )
                        return {'ok': True}

                    logger.debug(f'Downloading voice file from Telegram: {tg_path}')
                    
                    # 2) Download binary voice payload
                    download_url = (
                        f'https://api.telegram.org/file/bot{TELEGRAM_BOT_TOKEN}/{tg_path}'
                    )
                    audio_resp = await client.get(download_url)
                    audio_resp.raise_for_status()
                    logger.debug(f'Voice file downloaded: {len(audio_resp.content)} bytes')

                suffix = '.ogg'
                if '.' in tg_path:
                    suffix = f".{tg_path.rsplit('.', 1)[-1]}"
                with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp:
                    temp_path = temp.name
                    temp.write(audio_resp.content)

                # 3) Transcribe and send plain transcript back to user
                logger.debug(f'Transcribing voice file: {temp_path}')
                result = await transcribe_audio(temp_path)
                text = (result.get('text') or '').strip()
                if text:
                    logger.info(f'Voice transcribed from chat_id={chat_id}: {text[:50]}...')
                    await send_telegram_message(
                        chat_id,
                        f'📝 Transcribed text:\n{text}'
                    )
                else:
                    logger.warning(f'Voice file could not be transcribed from chat_id={chat_id}')
                    await send_telegram_message(
                        chat_id,
                        'Na-download ang audio pero walang malinaw na transcription.'
                    )
            except Exception as e:
                logger.error(f'Telegram voice handling error: {e}')
                await send_telegram_message(
                    chat_id,
                    'Nagka-problema sa pag-process ng voice message. Pakisubukan ulit.'
                )
            finally:
                if temp_path and os.path.exists(temp_path):
                    os.remove(temp_path)
                    logger.debug(f'Cleaned up temp file: {temp_path}')

        # Handle photos
        elif 'photo' in message:
            logger.debug(f'Photo message from chat_id={chat_id}')
            await send_telegram_message(
                chat_id,
                "Photo received! Please describe the issue in your next message."
            )

        return {'ok': True}

    except Exception as e:
        logger.error(f'Telegram webhook error: {e}', exc_info=True)
        return {'ok': False, 'error': str(e)}