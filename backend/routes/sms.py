from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel

from config.logging import get_logger
from services.sms_service import (
    get_sms_status,
    process_incoming_sms,
    send_sms,
    validate_sms_webhook,
)


logger = get_logger(__name__)
router = APIRouter()


class GenericSMSPayload(BaseModel):
    phone_number: str | None = None
    from_number: str | None = None
    from_phone: str | None = None
    sender: str | None = None
    msisdn: str | None = None
    message: str | None = None
    text: str | None = None
    body: str | None = None
    content: str | None = None
    message_id: str | None = None


class TestSMSPayload(BaseModel):
    phone_number: str
    message: str


def _extract_text(payload: GenericSMSPayload) -> str:
    return (payload.message or payload.text or payload.body or payload.content or '').strip()


def _extract_phone(payload: GenericSMSPayload) -> str:
    return (
        payload.phone_number
        or payload.from_number
        or payload.from_phone
        or payload.sender
        or payload.msisdn
        or ''
    ).strip()


async def _send_reply(phone_number: str, reply_text: str) -> dict:
    try:
        return await send_sms(phone_number, reply_text)
    except Exception as e:
        logger.error('Failed to send SMS reply to %s: %s', phone_number, e)
        return {'success': False, 'error': str(e)}


@router.post('/webhook/twilio')
async def twilio_webhook(request: Request):
    try:
        form = await request.form()
        form_data = {k: str(v) for k, v in form.items()}

        if not validate_sms_webhook(dict(request.headers), str(request.url), form_data):
            logger.warning('Twilio SMS webhook validation failed')
            raise HTTPException(status_code=403, detail='Invalid webhook signature')

        phone_number = str(form_data.get('From', '')).strip()
        message_text = str(form_data.get('Body', '')).strip()
        message_id = str(form_data.get('MessageSid', '')).strip() or None

        if not phone_number or not message_text:
            raise HTTPException(status_code=400, detail='Missing From or Body in webhook payload')

        logger.info('Twilio webhook received from=%s message_id=%s', phone_number, message_id)

        result = await process_incoming_sms(phone_number, message_text, external_id=message_id)
        send_result = await _send_reply(phone_number, result['reply_text'])

        return {
            'ok': True,
            'provider': 'twilio',
            'message_id': message_id,
            'report_id': result.get('report_id'),
            'send_result': send_result,
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error('Twilio SMS webhook error: %s', e)
        raise HTTPException(status_code=500, detail='Failed to process Twilio SMS webhook')


@router.post('/webhook/generic')
async def generic_webhook(payload: GenericSMSPayload, request: Request):
    try:
        if not validate_sms_webhook(dict(request.headers), str(request.url), None):
            logger.warning('Generic SMS webhook validation failed')
            raise HTTPException(status_code=403, detail='Invalid webhook signature')

        phone_number = _extract_phone(payload)
        message_text = _extract_text(payload)
        message_id = payload.message_id

        if not phone_number or not message_text:
            raise HTTPException(status_code=400, detail='Missing sender phone or message text in payload')

        logger.info('Generic SMS webhook received from=%s message_id=%s', phone_number, message_id)

        result = await process_incoming_sms(phone_number, message_text, external_id=message_id)
        send_result = await _send_reply(phone_number, result['reply_text'])

        return {
            'ok': True,
            'provider': 'generic',
            'message_id': message_id,
            'report_id': result.get('report_id'),
            'send_result': send_result,
            'reply_text': result['reply_text'],
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error('Generic SMS webhook error: %s', e)
        raise HTTPException(status_code=500, detail='Failed to process generic SMS webhook')


@router.post('/webhook/startup')
async def startup_webhook(payload: GenericSMSPayload, request: Request):
    try:
        if not validate_sms_webhook(dict(request.headers), str(request.url), None):
            logger.warning('Startup SMS webhook validation failed')
            raise HTTPException(status_code=403, detail='Invalid API key or webhook signature')

        phone_number = _extract_phone(payload)
        message_text = _extract_text(payload)
        message_id = payload.message_id

        if not phone_number or not message_text:
            raise HTTPException(status_code=400, detail='Missing sender phone or message text in payload')

        logger.info('Startup SMS webhook received from=%s message_id=%s', phone_number, message_id)

        result = await process_incoming_sms(phone_number, message_text, external_id=message_id)
        send_result = await _send_reply(phone_number, result['reply_text'])

        return {
            'ok': True,
            'provider': 'startup',
            'message_id': message_id,
            'report_id': result.get('report_id'),
            'send_result': send_result,
            'reply_text': result['reply_text'],
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error('Startup SMS webhook error: %s', e)
        raise HTTPException(status_code=500, detail='Failed to process startup SMS webhook')


@router.post('/test-send')
async def test_send_sms(payload: TestSMSPayload):
    try:
        result = await send_sms(payload.phone_number, payload.message)
        return {'ok': True, 'result': result}
    except Exception as e:
        logger.error('SMS test send error: %s', e)
        raise HTTPException(status_code=500, detail='SMS test send failed')


@router.get('/status/{message_uid}')
async def check_sms_status(message_uid: str):
    try:
        result = await get_sms_status(message_uid)
        return {'ok': True, 'result': result}
    except Exception as e:
        logger.error('SMS status lookup error: %s', e)
        raise HTTPException(status_code=500, detail='SMS status lookup failed')