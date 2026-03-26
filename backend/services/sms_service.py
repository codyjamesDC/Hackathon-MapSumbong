from dotenv import load_dotenv
load_dotenv()

import base64
import hashlib
import hmac
import os
import uuid
from typing import Any, Dict, Optional

import httpx
from supabase import create_client

from config.logging import get_logger
from services.gemini_service import process_message as process_with_gemini
from utils.geocoding import reverse_geocode_barangay
from utils.los_banos_data import LOS_BANOS_CENTER


logger = get_logger(__name__)


ALLOWED_ISSUE_TYPES = {
    'flood',
    'waste',
    'road_hazard',
    'road',
    'power_outage',
    'power',
    'water_supply',
    'water',
    'medical',
    'emergency',
    'fire',
    'crime',
    'landslide',
    'earthquake_damage',
    'other',
}

ALLOWED_URGENCY = {'critical', 'high', 'medium', 'low'}

ISSUE_ALIASES = {
    'power outage': 'power_outage',
    'brownout': 'power_outage',
    'blackout': 'power_outage',
    'pothole': 'road_hazard',
    'traffic accident': 'road_hazard',
    'accident': 'road_hazard',
    'water': 'water_supply',
}


def _get_supabase():
    url = os.getenv('SUPABASE_URL')
    key = os.getenv('SUPABASE_SERVICE_KEY') or os.getenv('SUPABASE_SERVICE_ROLE_KEY')
    if not url or not key:
        raise ValueError('Supabase credentials are not configured')
    return create_client(url, key)


def _normalize_phone(phone_number: str) -> str:
    value = str(phone_number or '').strip()
    if not value:
        return value
    if value.startswith('+'):
        return '+' + ''.join(ch for ch in value[1:] if ch.isdigit())
    digits = ''.join(ch for ch in value if ch.isdigit())
    return digits


def _normalize_philsms_recipient(phone_number: str) -> str:
    digits = ''.join(ch for ch in _normalize_phone(phone_number) if ch.isdigit())
    if not digits:
        return ''

    if digits.startswith('0') and len(digits) == 11:
        return f'63{digits[1:]}'
    if digits.startswith('9') and len(digits) == 10:
        return f'63{digits}'
    if digits.startswith('63'):
        return digits
    return digits


def _contains_shortened_url(message: str) -> bool:
    lowered = (message or '').lower()
    short_domains = (
        'bit.ly',
        'tinyurl.com',
        't.co',
        'goo.gl',
        'tiny.cc',
        'is.gd',
        'shorturl.at',
        'rb.gy',
        'cutt.ly',
        'ow.ly',
        'rebrand.ly',
    )
    return any(domain in lowered for domain in short_domains)


def _resolve_sms_sender_id() -> str:
    return (
        os.getenv('SMS_SENDER_ID')
        or os.getenv('SMS_SYSTEM_NUMBER')
        or os.getenv('SMS_FROM_NUMBER')
        or ''
    ).strip()


def _hash_phone(phone_number: str) -> str:
    normalized = _normalize_phone(phone_number)
    return hashlib.sha256(normalized.encode('utf-8')).hexdigest()


def _normalize_issue_type(value: Optional[str]) -> str:
    normalized = str(value or '').strip().lower().replace('-', ' ').replace('_', ' ')
    if not normalized:
        return 'other'

    mapped = ISSUE_ALIASES.get(normalized, normalized).replace(' ', '_')
    if mapped in ALLOWED_ISSUE_TYPES:
        return mapped

    for allowed in ALLOWED_ISSUE_TYPES:
        if allowed in mapped or mapped in allowed:
            return allowed
    return 'other'


def _normalize_urgency(value: Optional[str]) -> str:
    normalized = str(value or '').strip().lower()
    if normalized in ALLOWED_URGENCY:
        return normalized
    return 'medium'


def _looks_like_report_intent(user_message: str, extracted_data: dict) -> bool:
    text = (user_message or '').strip().lower()
    if not text:
        return False

    greeting_only = {
        'hi', 'hello', 'hey', 'good morning', 'good afternoon', 'good evening',
        'kumusta', 'kamusta', 'kumusta po', 'kamusta po', 'yo',
    }
    if text in greeting_only:
        return False

    report_keywords = {
        'report', 'i-report', 'ireport', 'sumbong', 'isyu', 'issue',
        'pothole', 'flood', 'baha', 'sunog', 'aksidente', 'crime',
        'broken', 'sira', 'barado', 'landslide', 'walang kuryente',
    }
    if any(keyword in text for keyword in report_keywords):
        return True

    word_count = len([w for w in text.split() if w])
    if word_count <= 3:
        return False

    issue_type = str(extracted_data.get('issue_type', '')).strip().lower()
    description = str(extracted_data.get('description', '')).strip()
    location_text = str(extracted_data.get('location_text', '')).strip()

    if issue_type and issue_type not in {'other', 'general', 'unknown', 'none'}:
        return True
    if len(description) >= 20:
        return True
    if location_text:
        return True

    return False


def _generate_sms_anonymous_id() -> str:
    return f"ANON-SMS-{uuid.uuid4().hex[:6].upper()}"


def _get_or_create_reporter_anonymous_id(phone_number: str) -> str:
    supabase = _get_supabase()
    phone_hash = _hash_phone(phone_number)

    existing = (
        supabase.table('users')
        .select('anonymous_id')
        .eq('phone_hash', phone_hash)
        .limit(1)
        .execute()
    )

    if existing.data:
        return existing.data[0]['anonymous_id']

    fallback_anon = os.getenv('SMS_DEFAULT_REPORTER_ANON_ID', '').strip()
    if fallback_anon:
        return fallback_anon

    for _ in range(5):
        anonymous_id = _generate_sms_anonymous_id()
        try:
            supabase.table('users').insert({
                'phone_hash': phone_hash,
                'anonymous_id': anonymous_id,
                'account_type': 'resident',
                'display_name': 'SMS Resident',
                'is_anonymous': True,
                'barangay': os.getenv('SMS_DEFAULT_BARANGAY', 'Batong Malake'),
            }).execute()
            return anonymous_id
        except Exception:
            continue

    logger.warning('Falling back to ANON-DEV01 for SMS reporter identity')
    return 'ANON-DEV01'


def _parse_float(value: Any) -> Optional[float]:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


async def _build_report_record(phone_number: str, message_text: str, extracted_data: Dict[str, Any]) -> Dict[str, Any]:
    latitude = _parse_float(extracted_data.get('latitude'))
    longitude = _parse_float(extracted_data.get('longitude'))

    if latitude is None:
        latitude = float(LOS_BANOS_CENTER['lat'])
    if longitude is None:
        longitude = float(LOS_BANOS_CENTER['lng'])

    barangay = str(extracted_data.get('barangay') or '').strip()
    if not barangay:
        detected = reverse_geocode_barangay(latitude, longitude)
        if detected and detected != 'Unknown':
            barangay = detected
        else:
            barangay = os.getenv('SMS_DEFAULT_BARANGAY', 'Batong Malake')

    description = str(extracted_data.get('description') or '').strip() or message_text.strip()
    location_text = str(extracted_data.get('location_text') or '').strip() or f'SMS report from {phone_number}'

    return {
        'id': f'RPT-{uuid.uuid4().hex[:8].upper()}',
        'reporter_anonymous_id': _get_or_create_reporter_anonymous_id(phone_number),
        'issue_type': _normalize_issue_type(extracted_data.get('issue_type')),
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'location_text': location_text,
        'urgency': _normalize_urgency(extracted_data.get('urgency')),
        'sdg_tag': extracted_data.get('sdg_tag'),
        'status': 'received',
        'barangay': barangay,
        'photo_url': None,
    }


async def process_incoming_sms(phone_number: str, message_text: str, external_id: Optional[str] = None) -> Dict[str, Any]:
    ai_result = await process_with_gemini(message_text)
    extracted_data = ai_result.get('extracted_data') or {}

    report_id = None
    is_report = ai_result.get('success', False) and _looks_like_report_intent(message_text, extracted_data)

    if is_report:
        try:
            report = await _build_report_record(phone_number, message_text, extracted_data)
            _get_supabase().table('reports').insert(report).execute()
            report_id = report['id']
            logger.info('SMS report created: report_id=%s external_id=%s', report_id, external_id)
        except Exception as e:
            logger.error('Failed to create SMS report for %s: %s', phone_number, e)

    reply_text = (ai_result.get('chatbot_response') or '').strip()
    if not reply_text:
        reply_text = 'Salamat sa mensahe. Natanggap na namin ang report mo.'

    if report_id:
        reply_text = f'{reply_text}\n\nReport ID: {report_id}'

    if len(reply_text) > 480:
        reply_text = reply_text[:477] + '...'

    return {
        'success': True,
        'reply_text': reply_text,
        'report_id': report_id,
        'is_report_intent': is_report,
    }


def _get_sms_provider() -> str:
    return (os.getenv('SMS_PROVIDER', 'philsms') or 'philsms').strip().lower()


def _extract_bearer_token(value: str) -> str:
    raw = str(value or '').strip()
    if raw.lower().startswith('bearer '):
        return raw.split(' ', 1)[1].strip()
    return raw


def _is_twilio_signature_valid(signature: str, url: str, form_data: Dict[str, Any]) -> bool:
    auth_token = os.getenv('SMS_API_SECRET', '')
    if not auth_token:
        return False

    payload = url + ''.join(f'{key}{form_data[key]}' for key in sorted(form_data.keys()))
    digest = hmac.new(auth_token.encode('utf-8'), payload.encode('utf-8'), hashlib.sha1).digest()
    expected = base64.b64encode(digest).decode('utf-8')
    return hmac.compare_digest(expected, signature)


def validate_sms_webhook(headers: Dict[str, Any], callback_url: str, form_data: Optional[Dict[str, Any]] = None) -> bool:
    provider = _get_sms_provider()

    if provider == 'twilio':
        signature = headers.get('X-Twilio-Signature') or headers.get('x-twilio-signature')
        if not signature:
            logger.warning('Missing X-Twilio-Signature header; skipping strict SMS validation')
            return True

        if not form_data:
            return False
        return _is_twilio_signature_valid(signature, callback_url, form_data)

    if provider == 'startup':
        expected_key = os.getenv('SMS_API_KEY', '').strip()
        provided = (
            headers.get('X-API-Key')
            or headers.get('x-api-key')
            or headers.get('Authorization')
            or headers.get('authorization')
            or ''
        )
        provided_key = _extract_bearer_token(str(provided))

        if expected_key and provided_key:
            return hmac.compare_digest(provided_key, expected_key)
        if expected_key and not provided_key:
            logger.warning('Startup SMS webhook missing API key header')
            return False

    expected_secret = os.getenv('SMS_WEBHOOK_SECRET', '').strip()
    if not expected_secret:
        logger.warning('SMS webhook secret not configured; skipping signature verification')
        return True

    provided_secret = (
        headers.get('X-SMS-Webhook-Secret')
        or headers.get('x-sms-webhook-secret')
        or ''
    )
    return hmac.compare_digest(provided_secret, expected_secret)


async def send_sms(phone_number: str, message: str) -> Dict[str, Any]:
    provider = _get_sms_provider()
    to_number = _normalize_phone(phone_number)

    if provider == 'philsms':
        api_key = (os.getenv('SMS_API_KEY') or '').strip()
        sender_id = _resolve_sms_sender_id()
        message_type = (os.getenv('SMS_MESSAGE_TYPE') or 'plain').strip().lower()
        if message_type not in {'plain', 'unicode'}:
            message_type = 'plain'

        if not api_key:
            raise ValueError('PhilSMS requires SMS_API_KEY')
        if not sender_id:
            raise ValueError('PhilSMS requires SMS_SENDER_ID (or SMS_SYSTEM_NUMBER/SMS_FROM_NUMBER)')

        recipient = _normalize_philsms_recipient(phone_number)
        if not recipient:
            raise ValueError('Recipient phone number is invalid')

        if _contains_shortened_url(message):
            logger.warning('Message contains URL shortener. SMART delivery may fail based on PhilSMS advisory.')

        send_url = (
            os.getenv('SMS_PHILSMS_SEND_URL')
            or os.getenv('SMS_STARTUP_SEND_URL')
            or 'https://dashboard.philsms.com/api/v3/sms/send'
        ).strip()
        headers = {
            'Authorization': f'Bearer {api_key}',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
        }
        payload = {
            'recipient': recipient,
            'sender_id': sender_id,
            'type': message_type,
            'message': message,
        }

        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.post(send_url, headers=headers, json=payload)

        response.raise_for_status()
        try:
            data = response.json()
        except Exception:
            data = {'raw': response.text}

        message_uid = (
            data.get('uid')
            or (data.get('data') or {}).get('uid')
            or data.get('id')
        )
        return {
            'success': True,
            'provider': 'philsms',
            'message_uid': message_uid,
            'response': data,
        }

    if provider == 'startup':
        api_key = (os.getenv('SMS_API_KEY') or '').strip()
        if not api_key:
            raise ValueError('Startup SMS provider requires SMS_API_KEY')

        send_url = (
            os.getenv('SMS_STARTUP_SEND_URL')
            or os.getenv('SMS_GATEWAY_URL')
            or 'https://smsapiph.onrender.com/api/v1/send/sms'
        ).strip()
        sender = (os.getenv('SMS_SYSTEM_NUMBER') or os.getenv('SMS_FROM_NUMBER') or '').strip()

        headers = {
            'x-api-key': api_key,
            'Content-Type': 'application/json',
        }
        payload = {
            'recipient': to_number,
            'message': message,
        }
        if sender:
            payload['sender'] = sender

        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.post(send_url, headers=headers, json=payload)

        response.raise_for_status()
        try:
            data = response.json()
        except Exception:
            data = {'raw': response.text}
        return {
            'success': True,
            'provider': 'startup',
            'response': data,
        }

    if provider == 'twilio':
        account_sid = os.getenv('SMS_API_KEY', '').strip()
        auth_token = os.getenv('SMS_API_SECRET', '').strip()
        from_number = os.getenv('SMS_FROM_NUMBER', '').strip()
        if not account_sid or not auth_token or not from_number:
            raise ValueError('Twilio is selected but SMS_API_KEY/SMS_API_SECRET/SMS_FROM_NUMBER are missing')

        url = f'https://api.twilio.com/2010-04-01/Accounts/{account_sid}/Messages.json'
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.post(
                url,
                data={'To': to_number, 'From': from_number, 'Body': message},
                auth=(account_sid, auth_token),
            )

        response.raise_for_status()
        data = response.json()
        return {'success': True, 'provider': 'twilio', 'message_id': data.get('sid')}

    gateway_url = os.getenv('SMS_GATEWAY_URL', '').strip()
    gateway_key = (os.getenv('SMS_GATEWAY_KEY') or os.getenv('SMS_API_KEY') or '').strip()
    if not gateway_url or not gateway_key:
        raise ValueError('Generic SMS provider requires SMS_GATEWAY_URL and SMS_GATEWAY_KEY')

    headers = {
        'Authorization': f'Bearer {gateway_key}',
        'X-API-Key': gateway_key,
        'Content-Type': 'application/json',
    }
    payload = {
        'to': to_number,
        'message': message,
    }
    sender = os.getenv('SMS_FROM_NUMBER', '').strip()
    if sender:
        payload['from'] = sender

    async with httpx.AsyncClient(timeout=20.0) as client:
        response = await client.post(gateway_url, headers=headers, json=payload)

    response.raise_for_status()
    try:
        data = response.json()
    except Exception:
        data = {'raw': response.text}
    return {'success': True, 'provider': 'generic', 'response': data}


async def get_sms_status(message_uid: str) -> Dict[str, Any]:
    provider = _get_sms_provider()
    uid = str(message_uid or '').strip()
    if not uid:
        raise ValueError('message_uid is required')

    if provider == 'philsms':
        api_key = (os.getenv('SMS_API_KEY') or '').strip()
        if not api_key:
            raise ValueError('PhilSMS status lookup requires SMS_API_KEY')

        base_url = (os.getenv('SMS_PHILSMS_BASE_URL') or 'https://dashboard.philsms.com/api/v3/sms').strip().rstrip('/')
        url = f'{base_url}/{uid}'
        headers = {
            'Authorization': f'Bearer {api_key}',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
        }

        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.get(url, headers=headers)

        response.raise_for_status()
        try:
            data = response.json()
        except Exception:
            data = {'raw': response.text}
        return {'provider': 'philsms', 'uid': uid, 'response': data}

    raise ValueError(f'SMS status lookup is not configured for provider: {provider}')