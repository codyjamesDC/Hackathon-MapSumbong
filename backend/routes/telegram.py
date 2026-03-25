from fastapi import APIRouter, Request
import httpx
import os
import tempfile

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
            voice = message.get('voice', {})
            file_id = voice.get('file_id')
            if not file_id:
                await send_telegram_message(
                    chat_id,
                    'Hindi mabasa ang voice file. Pakisubukan ulit.'
                )
                return {'ok': True}

            if not TELEGRAM_BOT_TOKEN:
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
                        await send_telegram_message(
                            chat_id,
                            'Hindi ma-download ang voice file. Pakisubukan ulit.'
                        )
                        return {'ok': True}

                    # 2) Download binary voice payload
                    download_url = (
                        f'https://api.telegram.org/file/bot{TELEGRAM_BOT_TOKEN}/{tg_path}'
                    )
                    audio_resp = await client.get(download_url)
                    audio_resp.raise_for_status()

                suffix = '.ogg'
                if '.' in tg_path:
                    suffix = f".{tg_path.rsplit('.', 1)[-1]}"
                with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp:
                    temp_path = temp.name
                    temp.write(audio_resp.content)

                # 3) Transcribe and send plain transcript back to user
                result = await transcribe_audio(temp_path)
                text = (result.get('text') or '').strip()
                if text:
                    await send_telegram_message(
                        chat_id,
                        f'📝 Transcribed text:\n{text}'
                    )
                else:
                    await send_telegram_message(
                        chat_id,
                        'Na-download ang audio pero walang malinaw na transcription.'
                    )
            except Exception as e:
                print(f'Telegram voice handling error: {e}')
                await send_telegram_message(
                    chat_id,
                    'Nagka-problema sa pag-process ng voice message. Pakisubukan ulit.'
                )
            finally:
                if temp_path and os.path.exists(temp_path):
                    os.remove(temp_path)

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