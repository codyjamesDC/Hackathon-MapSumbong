from fastapi import APIRouter, Request
import httpx
import os
import tempfile
import hmac
import hashlib

from services.whisper_service import transcribe_audio
from services.gemini_service import process_message as process_with_gemini
from config.logging import get_logger

logger = get_logger(__name__)

router = APIRouter()

TELEGRAM_BOT_TOKEN = os.getenv('TELEGRAM_BOT_TOKEN')
TELEGRAM_BOT_SECRET = os.getenv('TELEGRAM_BOT_SECRET', '')
TELEGRAM_API_BASE = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}"


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


def _validate_telegram_signature(request_headers: dict, body: bytes) -> bool:
    """
    Validate Telegram webhook signature.
    
    Telegram sends X-Telegram-Bot-Api-Secret-Sha256 header with SHA256 hash
    of the bot secret and request body.
    """
    if not TELEGRAM_BOT_SECRET:
        logger.warning('Telegram webhook secret not configured; skipping signature verification')
        return True
    
    try:
        signature = request_headers.get('X-Telegram-Bot-Api-Secret-Sha256', '')
        if not signature:
            logger.warning('Missing X-Telegram-Bot-Api-Secret-Sha256 header')
            return False
        
        # Calculate expected signature: SHA256(secret + body)
        expected = hashlib.sha256(
            TELEGRAM_BOT_SECRET.encode() + body
        ).hexdigest()
        
        # Compare with constant time to prevent timing attacks
        if not hmac.compare_digest(signature, expected):
            logger.error(f'Telegram signature mismatch. Expected: {expected[:8]}..., Got: {signature[:8]}...')
            return False
        
        logger.debug('Telegram webhook signature valid')
        return True
    except Exception as e:
        logger.error(f'Telegram signature validation error: {e}')
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
    
    request_body = await request.body()

    try:
        # Validate webhook signature (security)
        if not _validate_telegram_signature(dict(request.headers), request_body):
            logger.warning('Telegram webhook signature validation failed')
            return {'ok': False, 'error': 'Invalid signature'}
        
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
                # Process with Gemini
                result = await process_with_gemini(user_message)
                extracted_data = result.get('extracted_data') or {}
                is_report_intent = _looks_like_report_intent(user_message, extracted_data)

                # Send response
                await send_telegram_message(chat_id, result['chatbot_response'])

                if result['success'] and is_report_intent:
                    # Only send a report ID if one was actually generated.
                    report_id = result.get('report_id')
                    if _is_valid_report_id(report_id):
                        logger.info(f'Report created via Telegram: report_id={report_id}, chat_id={chat_id}')
                        await send_telegram_message(
                            chat_id,
                            f"✅ Report ID: {report_id}\n\nSalamat sa pag-report!"
                        )
                    else:
                        logger.info(f'Telegram message processed without report ID: chat_id={chat_id}')
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