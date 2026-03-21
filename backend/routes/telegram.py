from fastapi import APIRouter, Request
import httpx
import os

from services.whisper_service import transcribe_audio
from services.gemini_service import process_message as process_with_gemini

router = APIRouter()

TELEGRAM_BOT_TOKEN = os.getenv('TELEGRAM_BOT_TOKEN')
TELEGRAM_API_BASE = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}"

async def send_telegram_message(chat_id: int, text: str):
    """Send message to Telegram user"""
    async with httpx.AsyncClient() as client:
        await client.post(
            f"{TELEGRAM_API_BASE}/sendMessage",
            json={'chat_id': chat_id, 'text': text}
        )

@router.post('/webhook')
async def telegram_webhook(request: Request):
    """Handle incoming Telegram messages"""

    try:
        update = await request.json()

        if 'message' not in update:
            return {'ok': True}

        message = update['message']
        chat_id = message['chat']['id']

        # Handle text messages
        if 'text' in message:
            user_message = message['text']

            # Process with Gemini
            result = await process_with_gemini(user_message)

            # Send response
            await send_telegram_message(chat_id, result['chatbot_response'])

            if result['success']:
                # Report created successfully
                report_id = result.get('report_id', 'N/A')
                await send_telegram_message(
                    chat_id,
                    f"✅ Report ID: {report_id}\n\nSalamat sa pag-report!"
                )

        # Handle voice messages
        elif 'voice' in message:
            # TODO: Download audio, transcribe with Whisper, process
            await send_telegram_message(
                chat_id,
                "Voice message support coming soon! Para sa ngayon, i-type lang po ang inyong report."
            )

        # Handle photos
        elif 'photo' in message:
            await send_telegram_message(
                chat_id,
                "Photo received! Please describe the issue in your next message."
            )

        return {'ok': True}

    except Exception as e:
        print(f'Telegram webhook error: {e}')
        return {'ok': False, 'error': str(e)}