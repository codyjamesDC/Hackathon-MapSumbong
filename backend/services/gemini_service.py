from dotenv import load_dotenv
load_dotenv()

import os
import json
from typing import Dict, Any, Optional

from google import genai
from google.genai import types

from prompts import get_chatbot_system_prompt, get_extraction_system_prompt

# Initialise the new SDK client
_client = genai.Client(api_key=os.getenv('GEMINI_API_KEY'))

_MODEL = 'gemini-2.5-flash'


def _extract_current_message_for_fallback(user_message: str) -> str:
    text = str(user_message or '').strip()
    marker = 'Current resident message:'
    if marker not in text:
        return text

    tail = text.split(marker, 1)[1].strip()
    if '\n' in tail:
        tail = tail.split('\n', 1)[0].strip()
    return tail or text


def _fallback_issue_type(user_message: str) -> str:
    text = (user_message or '').lower()
    if any(k in text for k in ('natumbang puno', 'tumba na puno', 'fallen tree', 'obstruction', 'blocked road', 'naharang')):
        return 'road_hazard'
    if any(k in text for k in ('pothole', 'lubak', 'butas', 'road')):
        return 'road_hazard'
    if any(k in text for k in ('flood', 'baha')):
        return 'flood'
    if any(k in text for k in ('sunog', 'fire')):
        return 'fire'
    if any(k in text for k in ('crime', 'nakaw', 'holdap')):
        return 'crime'
    if any(k in text for k in ('walang kuryente', 'brownout', 'blackout', 'power')):
        return 'power_outage'
    if any(k in text for k in ('tubig', 'water')):
        return 'water_supply'
    return 'other'


def _has_location_hint(user_message: str) -> bool:
    text = (user_message or '').lower()
    location_tokens = (
        'sa ', 'near ', 'tapat', 'gate', 'street', 'kanto',
        'batong malake', 'anos', 'bayog', 'maahas', 'mayondon', 'uplb',
    )
    return any(token in text for token in location_tokens)


def _fallback_urgency(user_message: str) -> str:
    text = (user_message or '').lower()
    low_indicators = (
        'hindi malala', 'di malala', 'minor', 'abala lang', 'walang nasaktan', 'no injury',
    )
    critical_indicators = (
        'critical', 'emergency', 'may nasaktan', 'injured', 'unconscious', 'sunog', 'fire',
        'landslide', 'gumuguho',
    )
    high_indicators = (
        'malaki', 'malalim', 'delikado', 'hazard', 'aksidente', 'accident', 'baha', 'flood',
    )

    if any(token in text for token in low_indicators):
        return 'low'
    if any(token in text for token in critical_indicators):
        return 'critical'
    if any(token in text for token in high_indicators):
        return 'high'
    return 'medium'


def _has_impact_hint(user_message: str) -> bool:
    text = (user_message or '').lower()
    impact_tokens = (
        'nasaktan', 'walang nasaktan', 'abala', 'delikado', 'malaki', 'malalim',
        'harang', 'blocked', 'trapik', 'traffic',
    )
    return any(token in text for token in impact_tokens)


def _fallback_chatbot_response(user_message: str) -> str:
    current_text = _extract_current_message_for_fallback(user_message)
    text = current_text.lower()
    context_text = (user_message or '').strip().lower()
    if text in {'hi', 'hello', 'hey', 'kumusta', 'kamusta', '/start'}:
        return 'Hello po! Ano pong isyu ang gusto ninyong i-report at saan po ito nangyari?'

    issue_type = _fallback_issue_type(context_text)
    if issue_type == 'other':
        return (
            'Salamat po sa mensahe. Pakisabi po ang eksaktong problema '
            '(hal. baha, pothole, sunog) at eksaktong lokasyon para maihanda ko ang report.'
        )

    has_location = _has_location_hint(context_text)
    if not has_location:
        return (
            'Salamat sa pag-uulat. Para makumpleto ang report, '
            'saan po eksakto ang lokasyon (barangay/landmark/kalsada)?'
        )

    if not _has_impact_hint(context_text):
        return (
            'Noted po ang issue at lokasyon. Para mas mabilis ang validation, '
            'may landmark o picture po ba kayo? (optional)'
        )

    return (
        'Salamat po. Na-log ko na ang detalye at ia-assess ng system ang urgency. '
        'Magbibigay ako ng update kapag handa na ang report summary.'
    )


async def process_message(
    user_message: str,
    photo_url: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Process a resident message with Gemini AI.

    Returns:
        {
            'extracted_data': dict,
            'chatbot_response': str,
            'success': bool,
        }
    """
    try:
        # ── 1. Extract structured data ────────────────────────────────────────
        extraction_prompt = (
            f"Extract report data from this message: {user_message}"
        )
        if photo_url:
            extraction_prompt += f"\nPhoto URL: {photo_url}"

        extraction_response = _client.models.generate_content(
            model=_MODEL,
            contents=extraction_prompt,
            config=types.GenerateContentConfig(
                system_instruction=get_extraction_system_prompt(),
            ),
        )

        raw = extraction_response.text.strip()

        # Strip markdown fences if present
        if raw.startswith('```'):
            parts = raw.split('```')
            raw = parts[1] if len(parts) > 1 else raw
            if raw.startswith('json'):
                raw = raw[4:]
        raw = raw.strip()

        try:
            extracted_data = json.loads(raw)
        except json.JSONDecodeError:
            # Fallback: try to find JSON object inside the text
            start = raw.find('{')
            end = raw.rfind('}') + 1
            if start != -1 and end > start:
                extracted_data = json.loads(raw[start:end])
            else:
                extracted_data = {
                    'issue_type': 'other',
                    'urgency': 'medium',
                    'is_spam': False,
                    'confidence': 0.5,
                }

        # ── 2. Generate friendly chatbot reply ───────────────────────────────
        chat_response = _client.models.generate_content(
            model=_MODEL,
            contents=user_message,
            config=types.GenerateContentConfig(
                system_instruction=get_chatbot_system_prompt(),
            ),
        )
        chatbot_response = chat_response.text

        return {
            'extracted_data': extracted_data,
            'chatbot_response': chatbot_response,
            'success': not extracted_data.get('is_spam', False),
        }

    except Exception as e:
        print(f'Gemini API error: {e}')
        error_text = str(e)
        lower_error = error_text.lower()
        quota_exhausted = (
            'resource_exhausted' in lower_error
            or 'quota' in lower_error
            or '429' in lower_error
        )

        fallback_issue_type = _fallback_issue_type(user_message)
        fallback_urgency = _fallback_urgency(user_message)
        fallback_reply = _fallback_chatbot_response(user_message)

        if quota_exhausted:
            fallback_reply = (
                'Medyo mataas ang system traffic ngayon, pero tuloy ang intake.\n\n'
                f'{fallback_reply}'
            )

        return {
            'extracted_data': {
                'issue_type': fallback_issue_type,
                'urgency': fallback_urgency,
                'is_spam': False,
                'confidence': 0.35,
            },
            'chatbot_response': fallback_reply,
            'success': quota_exhausted,
            'error': str(e),
        }