import google.generativeai as genai
import json
import os
from typing import Dict, Any, Optional
from prompts import get_chatbot_system_prompt, get_extraction_system_prompt

# Initialize Gemini
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

# Two model instances: one for conversation, one for JSON extraction
chat_model = genai.GenerativeModel(
    "models/gemini-2.5-flash",
    system_instruction=get_chatbot_system_prompt(),
)
extraction_model = genai.GenerativeModel(
    "models/gemini-2.5-flash",
    system_instruction=get_extraction_system_prompt(),
)

async def process_message(user_message: str, photo_url: Optional[str] = None) -> Dict[str, Any]:
    """
    Process user message with Gemini AI

    Args:
        user_message: Text message from user
        photo_url: Optional photo URL for visual analysis

    Returns:
        Dictionary with extracted_data, chatbot_response, and success flag
    """
    try:
        # Build message content
        content = [user_message]

        # Add image if provided (Gemini can analyze flood depth, damage, etc.)
        if photo_url:
            # For Gemini, we would need to handle image input differently
            # For now, just include the URL in the text
            content[0] += f"\nPhoto URL: {photo_url}"

        # Call Gemini API for extraction
        extraction_response = extraction_model.generate_content(
            f"Extract report data from this message: {user_message}"
        )

        # Parse JSON from response
        response_text = extraction_response.text

        # Try to extract JSON
        json_start = response_text.find('{')
        json_end = response_text.rfind('}') + 1

        if json_start != -1 and json_end > json_start:
            extracted_json = response_text[json_start:json_end]
            extracted_data = json.loads(extracted_json)
        else:
            # Fallback
            extracted_data = {
                'issue_type': 'other',
                'urgency': 'medium',
                'is_spam': False,
                'confidence': 0.5
            }

        # Get chatbot response
        chat_response = chat_model.generate_content(user_message)
        chatbot_response = chat_response.text

        return {
            'extracted_data': extracted_data,
            'chatbot_response': chatbot_response,
            'success': not extracted_data.get('is_spam', False)
        }

    except Exception as e:
        print(f'Gemini API error: {e}')
        return {
            'extracted_data': {},
            'chatbot_response': 'Pasensya na, may technical issue sa sistema. Subukan ulit.',
            'success': False,
            'error': str(e)
        }