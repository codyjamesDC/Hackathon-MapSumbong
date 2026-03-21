# MapSumbong Telegram Bot Guide

Telegram integration as fallback reporting channel.

## Setup Bot

### 1. Create Bot with BotFather

```
1. Open Telegram
2. Search for @BotFather
3. Send /newbot
4. Name: MapSumbong
5. Username: mapsumbong_bot (or available alternative)
6. Copy the bot token
```

### 2. Add Token to Backend .env

```bash
TELEGRAM_BOT_TOKEN=1234567890:ABCdefGHIjklMNOpqrsTUVwxyz
```

### 3. Set Webhook (Development)

```bash
# Install ngrok for local testing
# Download from https://ngrok.com/download

# Start ngrok tunnel
ngrok http 8000

# Copy the https URL (e.g., https://abc123.ngrok.io)

# Set webhook
curl -X POST https://api.telegram.org/bot<YOUR_TOKEN>/setWebhook \
  -d url=https://abc123.ngrok.io/telegram/webhook
```

### 4. Verify Webhook

```bash
curl https://api.telegram.org/bot<YOUR_TOKEN>/getWebhookInfo
```

## Backend Implementation

Already included in `routes/telegram.py` (see 03_BACKEND_GUIDE.md)

Key features:
- Text message handling
- Voice note transcription
- Photo uploads
- Chatbot responses in Filipino

## Enhanced Features

### Add Welcome Message

Add to `routes/telegram.py`:

```python
@router.post('/webhook')
async def telegram_webhook(request: Request):
    update = await request.json()
    
    if 'message' not in update:
        return {'ok': True}
    
    message = update['message']
    chat_id = message['chat']['id']
    
    # Handle /start command
    if message.get('text') == '/start':
        welcome = """
👋 Kumusta! Welcome to MapSumbong!

I-report ang mga problema sa inyong komunidad:
• Baha (Flooding)
• Basura (Waste)
• Sira na kalsada (Road damage)
• Walang kuryente (Power outage)
• At iba pa

Mag-type lang ng mensahe describing ang problema.
Example: "May baha sa gate ng school"
        """
        await send_telegram_message(chat_id, welcome)
        return {'ok': True}
    
    # ... rest of existing code
```

### Add Report Status Check

```python
# Handle /status command
if message.get('text', '').startswith('/status '):
    report_id = message['text'].replace('/status ', '').strip()
    
    # Fetch report from Supabase
    result = supabase.table('reports').select('*').eq('id', report_id).execute()
    
    if result.data:
        report = result.data[0]
        status_msg = f"""
📋 Report Status: {report_id}

Type: {report['issue_type'].upper()}
Status: {report['status'].upper()}
Created: {report['created_at']}
Location: {report['location_text']}
        """
        await send_telegram_message(chat_id, status_msg)
    else:
        await send_telegram_message(chat_id, "Report not found.")
    
    return {'ok': True}
```

## Testing

### Manual Test

```bash
# Send message to your bot in Telegram
"May basura sa kanto ng Rizal Street"

# Check backend logs
# Should see webhook received and processed
```

### Automated Tests

```python
# test_telegram.py
import httpx
import asyncio

async def test_telegram_webhook():
    payload = {
        "update_id": 123,
        "message": {
            "message_id": 1,
            "from": {"id": 123456, "first_name": "Test"},
            "chat": {"id": 123456, "type": "private"},
            "text": "May baha sa gate"
        }
    }
    
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "http://localhost:8000/telegram/webhook",
            json=payload
        )
    
    print(response.json())

asyncio.run(test_telegram_webhook())
```

## Production Deployment

### Set Permanent Webhook

```bash
# After deploying to Render.com
curl -X POST https://api.telegram.org/bot<YOUR_TOKEN>/setWebhook \
  -d url=https://mapsumbong-backend.onrender.com/telegram/webhook
```

## Troubleshooting

**Bot not responding:**
1. Check webhook is set: `/getWebhookInfo`
2. Check backend logs
3. Verify ngrok tunnel is running (dev)
4. Test backend endpoint directly

**Messages not processing:**
1. Check TELEGRAM_BOT_TOKEN in .env
2. Verify webhook URL is accessible
3. Check FastAPI logs for errors

**Next:** Read 07_DEPLOYMENT.md