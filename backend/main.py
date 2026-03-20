from fastapi import FastAPI
from dotenv import load_dotenv
import os

load_dotenv()

app = FastAPI(title='MapSumbong API')

@app.get('/')
def health_check():
    return {
        'status': 'MapSumbong backend is running',
        'supabase_connected': os.getenv('SUPABASE_URL') is not None,
        'claude_api_configured': os.getenv('ANTHROPIC_API_KEY') is not None
    }

@app.post('/process-message')
async def process_message(payload: dict):
    # Claude pipeline goes here (Day 3-4)
    return {'message': 'Process message endpoint ready'}

@app.post('/transcribe')
async def transcribe_audio(payload: dict):
    # Whisper pipeline goes here (Day 5)
    return {'message': 'Transcribe endpoint ready'}

@app.post('/telegram-webhook')
async def telegram_webhook(payload: dict):
    # Telegram bot handler goes here (Day 2)
    return {'message': 'Telegram webhook ready'}