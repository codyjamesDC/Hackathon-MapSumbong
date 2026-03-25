# SMS Gateway Integration Guide

This document describes how to implement SMS functionality in MapSumbong, allowing residents without internet access to report issues via text message.

**Status**: Design document for future implementation. Not required for MVP.

---

## Overview

SMS provides a text-only fallback for residents on feature phones without the MapSumbong app. Messages are routed through the same backend as mobile/Telegram, processed by Gemini AI, and stored in the same database.

### Architecture

```
Resident SMS
    ↓
SMS Gateway (Twilio/Plivo/AWS SNS)
    ↓
/sms/webhook (FastAPI, planned)
    ↓
Report creation + Gemini AI processing
    ↓
Response SMS → Resident
```

### Supported Gateways

| Provider | Startup Cost | Per SMS | Pros | Cons |
|----------|-------------|---------|------|------|
| **Twilio** | $0 (free tier) | $0.0075 | Largest provider, great docs | Higher cost at scale |
| **Plivo** | $5 | $0.0025 | Cheapest SMS cost | Less US support |
| **AWS SNS** | $0 (free tier 100/mo) | $0.00645 | AWS integrated | Less SMS-focused |
| **Vonage** | Pay-as-you-go | $0.0068 | Modern API | Fewer PH networks |

**Recommendation for PH market**: Start with Twilio Free Tier for testing, then migrate to Plivo for better Philippines coverage and cost.

---

## Environment Variables

Add to `.env.example`:

```env
# SMS Gateway Configuration (Optional for MVP, required for SMS feature)
SMS_ENABLED=false
SMS_PROVIDER=twilio  # Options: twilio, plivo, aws_sns, vonage
SMS_API_KEY=your_api_key_or_account_sid
SMS_API_SECRET=your_auth_token_or_api_secret
SMS_FROM_NUMBER=+1234567890  # Your SMS sender ID or number
SMS_WEBHOOK_SECRET=your_webhook_secret  # For validating incoming webhooks
```

Load in config:

```python
# config/environment.py
SMS_ENABLED = get_env('SMS_ENABLED', 'false').lower() == 'true'
SMS_PROVIDER = get_env('SMS_PROVIDER', 'twilio')
SMS_API_KEY = get_env('SMS_API_KEY', None)
SMS_API_SECRET = get_env('SMS_API_SECRET', None)
SMS_FROM_NUMBER = get_env('SMS_FROM_NUMBER', None)
SMS_WEBHOOK_SECRET = get_env('SMS_WEBHOOK_SECRET', None)
```

---

## Implementation Pattern

### Step 1: Create SMS Service Module

**File**: `backend/services/sms_service.py`

```python
"""SMS gateway abstraction layer."""

from abc import ABC, abstractmethod
from typing import Optional
from config.environment import SMS_PROVIDER, SMS_API_KEY, SMS_API_SECRET
from config.logging import get_logger

logger = get_logger(__name__)


class SMSProvider(ABC):
    """Abstract SMS provider interface."""
    
    @abstractmethod
    async def send(self, phone_number: str, message: str) -> dict:
        """Send SMS message.
        
        Args:
            phone_number: Recipient phone in E.164 format (+1234567890)
            message: Message text (max 160 chars recommended)
            
        Returns:
            {
                'success': bool,
                'message_id': str,
                'error': Optional[str]
            }
        """
        pass

    @abstractmethod
    def validate_webhook(self, request_headers: dict, body: bytes) -> bool:
        """Validate incoming webhook signature."""
        pass


class TwilioProvider(SMSProvider):
    """Twilio SMS implementation."""
    
    def __init__(self, account_sid: str, auth_token: str, from_number: str):
        try:
            from twilio.rest import Client
            self.client = Client(account_sid, auth_token)
            self.from_number = from_number
        except ImportError:
            raise ImportError("twilio not installed. Run: pip install twilio")
    
    async def send(self, phone_number: str, message: str) -> dict:
        """Send SMS via Twilio."""
        try:
            msg = self.client.messages.create(
                body=message,
                from_=self.from_number,
                to=phone_number
            )
            logger.info(f'SMS sent: {msg.sid} to {phone_number}')
            return {'success': True, 'message_id': msg.sid}
        except Exception as e:
            logger.error(f'SMS send failed: {e}')
            return {'success': False, 'message_id': None, 'error': str(e)}
    
    def validate_webhook(self, request_headers: dict, body: bytes) -> bool:
        """Validate Twilio webhook signature."""
        try:
            from twilio.request_validator import RequestValidator
            validator = RequestValidator(SMS_API_SECRET)
            signature = request_headers.get('X-Twilio-Signature', '')
            # Note: FastAPI handler needs to reconstruct full callback URL
            return validator.validate(callback_url, body, signature)
        except Exception as e:
            logger.error(f'Twilio signature validation failed: {e}')
            return False


class PlivoProvider(SMSProvider):
    """Plivo SMS implementation."""
    
    def __init__(self, auth_id: str, auth_token: str, from_number: str):
        try:
            import plivo
            self.client = plivo.RestClient(auth_id, auth_token)
            self.from_number = from_number
        except ImportError:
            raise ImportError("plivo not installed. Run: pip install plivo")
    
    async def send(self, phone_number: str, message: str) -> dict:
        """Send SMS via Plivo."""
        try:
            response = self.client.messages.create(
                src=self.from_number,
                dst=phone_number,
                text=message
            )
            logger.info(f'SMS sent: {response.message_uuid} to {phone_number}')
            return {'success': True, 'message_id': response.message_uuid}
        except Exception as e:
            logger.error(f'SMS send failed: {e}')
            return {'success': False, 'message_id': None, 'error': str(e)}
    
    def validate_webhook(self, request_headers: dict, body: bytes) -> bool:
        """Validate Plivo webhook signature."""
        import hashlib
        import hmac
        try:
            signature = request_headers.get('X-Plivo-Signature', '')
            # Plivo uses HMAC-SHA1 of request URL + body
            expected = hmac.new(
                SMS_API_SECRET.encode(),
                body,
                hashlib.sha1
            ).hexdigest()
            return hmac.compare_digest(signature, expected)
        except Exception as e:
            logger.error(f'Plivo signature validation failed: {e}')
            return False


def get_sms_provider() -> Optional[SMSProvider]:
    """Factory function to get SMS provider based on config."""
    if SMS_PROVIDER == 'twilio':
        return TwilioProvider(SMS_API_KEY, SMS_API_SECRET, SMS_FROM_NUMBER)
    elif SMS_PROVIDER == 'plivo':
        return PlivoProvider(SMS_API_KEY, SMS_API_SECRET, SMS_FROM_NUMBER)
    else:
        logger.warning(f'Unknown SMS provider: {SMS_PROVIDER}')
        return None
```

### Step 2: Create SMS Webhook Handler

**File**: `backend/routes/sms.py`

```python
"""SMS webhook handling."""

from fastapi import APIRouter, Request, HTTPException
from pydantic import BaseModel
from services.sms_service import get_sms_provider
from services.report_service import create_report_from_text
from services.ai_service import analyze_report
from config.logging import get_logger

logger = get_logger(__name__)
router = APIRouter(prefix="/api/sms", tags=["sms"])


class SMSMessage(BaseModel):
    """SMS message received from gateway."""
    phone_number: str
    message_text: str
    message_id: str  # Gateway message ID
    timestamp: str


@router.post("/webhook/twilio")
async def handle_twilio_webhook(request: Request):
    """Handle Twilio incoming SMS webhook.
    
    Twilio sends form-encoded data:
    - From: +1234567890 (sender phone)
    - Body: Message text
    - MessageSid: Unique message ID
    - Timestamp: Unix timestamp
    """
    try:
        form = await request.form()
        
        # Validate webhook signature
        provider = get_sms_provider()
        if not provider or not provider.validate_webhook(dict(request.headers), await request.body()):
            logger.warning('Invalid Twilio webhook signature')
            raise HTTPException(status_code=403, detail='Invalid signature')
        
        # Extract message
        phone = form.get('From')
        text = form.get('Body')
        msg_id = form.get('MessageSid')
        
        logger.info(f'SMS received from {phone}: {text[:50]}...')
        
        # Create report from text
        report = await create_report_from_text(
            phone_number=phone,
            text=text,
            source='sms',
            external_id=msg_id
        )
        
        # Analyze with AI
        analysis = await analyze_report(report)
        
        # Send response SMS
        response_text = analysis.get('summary', 'Thank you for reporting.')
        if len(response_text) > 160:
            response_text = response_text[:157] + '...'
        
        await provider.send(phone, response_text)
        logger.info(f'SMS response sent to {phone}')
        
        return {'status': 'ok', 'message_id': msg_id}
    
    except Exception as e:
        logger.error(f'SMS webhook error: {e}')
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/webhook/plivo")
async def handle_plivo_webhook(request: Request):
    """Handle Plivo incoming SMS webhook.
    
    Similar flow to Twilio but different parameter names.
    """
    # Implementation similar to Twilio handler
    # See Plivo webhook docs: https://www.plivo.com/docs/sms/webhook/
    pass


@router.post("/test")
async def test_sms(phone_number: str, message: str):
    """Manual SMS send for testing (dev only).
    
    Usage:
    curl -X POST "http://localhost:8000/sms/test?phone_number=%2B1234567890&message=Hello"
    """
    provider = get_sms_provider()
    if not provider:
        raise HTTPException(status_code=503, detail='SMS not configured')
    
    result = await provider.send(phone_number, message)
    return result
```

### Step 3: Add SMS Route to Main

**File**: `backend/main.py`

```python
# At top
from routes import telegram, sms  # Add sms import
from config.environment import SMS_ENABLED

# After app initialization
if SMS_ENABLED:
    app.include_router(sms.router)
    logger.info('SMS gateway enabled')
else:
    logger.info('SMS gateway disabled')
```

---

## Integration with Report Workflow

When an SMS is received, it should:

1. **Create Report**: Extract issue type and location from text using regex/AI
2. **Process with Gemini**: Analyze severity, category, urgency
3. **Store in Database**: Same `reports` table as mobile/Telegram
4. **Send Confirmation**: Reply with summary and estimated resolution time
5. **Notify Barangay**: Add to dashboard notifications

### Database Schema (No changes needed)

Existing `reports` table handles SMS reports with:

```sql
source TEXT  -- 'mobile', 'telegram', 'sms'
external_id TEXT  -- Message ID from gateway (for deduplication)
```

---

## Gateway Setup Instructions

### Twilio

1. **Create Account**: https://www.twilio.com/console
2. **Get Trial Number**: Projects → Phone Numbers → Get a number
3. **Enable Webhooks**: Phone Numbers → Active Numbers → Your number → SMS → Webhooks
    - URL: `https://your-domain.com/sms/webhook/twilio`
   - Method: POST
4. **Get Credentials**:
   - Account SID: Settings → Account
   - Auth Token: Settings → API Credentials
5. **Set Environment**:
   ```env
   SMS_ENABLED=true
   SMS_PROVIDER=twilio
   SMS_API_KEY=ACxxxxxxxxxxxxxxxx  # Account SID
   SMS_API_SECRET=your_auth_token
   SMS_FROM_NUMBER=+1234567890  # Your Twilio number
   SMS_WEBHOOK_SECRET=your_auth_token  # For validation
   ```

### Plivo

1. **Create Account**: https://www.plivo.com
2. **Buy Phone Number**: Numbers → Search → Add number
3. **Configure Webhook**: Phone Numbers → Your number → Message → Webhook URL
    - URL: `https://your-domain.com/sms/webhook/plivo`
4. **Get Credentials**:
   - Auth ID: Settings → API Credentials
   - Auth Token: Settings → API Credentials
5. **Set Environment**:
   ```env
   SMS_ENABLED=true
   SMS_PROVIDER=plivo
   SMS_API_KEY=your_auth_id
   SMS_API_SECRET=your_auth_token
   SMS_FROM_NUMBER=MessageSource  # Alphanumeric sender ID
   SMS_WEBHOOK_SECRET=your_webhook_secret
   ```

---

## Testing

### Local Testing (Without Real SMS)

Use a mock provider:

```python
# config/environment.py
if ENVIRONMENT == 'test':
    SMS_PROVIDER = 'mock'

# services/sms_service.py
class MockProvider(SMSProvider):
    async def send(self, phone: str, msg: str) -> dict:
        print(f'[MOCK SMS] To: {phone}, Body: {msg}')
        return {'success': True, 'message_id': 'mock_12345'}
    
    def validate_webhook(self, headers: dict, body: bytes) -> bool:
        return True
```

### Production Testing

```bash
# Use provider's SMS testing endpoints or send to test number (your own phone)
curl -X POST http://localhost:8000/sms/test \
  -d "phone_number=%2B639123456789&message=Test+message"
```

---

## Cost Estimates

For a barangay with ~5,000 residents sending 2 reports/week each:

| Provider | SMS/Month | Cost/Month | Annual |
|----------|-----------|-----------|--------|
| Twilio | ~50,000 | $375 | $4,500 |
| Plivo | ~50,000 | $125 | $1,500 |
| AWS SNS | ~50,000 | $323 | $3,876 |

**Recommendation**: Start with Twilio free tier (100 SMS/day = ~3,000/month free). At scale, switch to Plivo.

---

## Future Enhancements

- [ ] Inbound voice (transcribe voice messages to text)
- [ ] MMS support (receive photos from feature phones)
- [ ] USSD menu system (for phones without SMS)
- [ ] Smart rate limiting (max 5 reports/resident/day)
- [ ] Scheduled SMS reminders ("Your report status: In Progress")
- [ ] Multi-language auto-translation (Tagalog → English)

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| SMS not received | Check webhook URL in SMS provider console |
| Signature validation fails | Verify `SMS_WEBHOOK_SECRET` is correct |
| Response SMS not sent | Check SMS_FROM_NUMBER is valid for provider |
| Rate limiting | Configure `X-RateLimit-Per-User` header in middleware |

---

## See Also

- [API_DOCUMENTATION.md](./API_DOCUMENTATION.md) - Full API spec
- [DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md) - Production setup
- [Twilio Docs](https://www.twilio.com/docs/sms)
- [Plivo Docs](https://www.plivo.com/docs/sms/)

---

**Status**: Design document. Ready to implement when needed.
