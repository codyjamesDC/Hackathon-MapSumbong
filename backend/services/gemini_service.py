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
        return {
            'extracted_data': {},
            'chatbot_response': (
                'Pasensya na, may technical issue sa sistema. Subukan ulit.'
            ),
            'success': False,
            'error': str(e),
        }