from fastapi import FastAPI
from dotenv import load_dotenv
import os
import google.generativeai as genai 

load_dotenv()

app = FastAPI(title='MapSumbong API')

# Configure Gemini API
genai.configure(api_key=os.getenv('GEMINI_API_KEY'))

# System prompt function
def get_system_prompt():
    return """You are a Filipino community issue reporter chatbot for MapSumbong.
    Your role is to help residents report barangay issues in a friendly way.
    You understand Tagalog, Bisaya, Taglish, and English.
    
    Extract the following information:
    - issue_type (flood, waste, road, emergency, etc.)
    - description
    - location (landmark or address)
    - urgency (critical, high, medium, low)
    
    Be conversational and helpful. Filter out spam or joke messages politely."""

# Create the model ONCE at startup
gemini_model = genai.GenerativeModel(
    'models/gemini-2.5-flash',
    system_instruction=get_system_prompt()  # ✅ CORRECT parameter name
)

@app.get('/')
def health_check():
    return {'status': 'MapSumbong backend is running'}

@app.post('/process-message')
async def process_message(payload: dict):
    try:
        user_message = payload.get('message', '')
        
        # Include system prompt in the conversation
        full_prompt = f"""{get_system_prompt()}

User message: {user_message}

Please respond as the MapSumbong chatbot."""
        
        # Generate response using Gemini
        response = gemini_model.generate_content(full_prompt)
        
        return {
            'success': True,
            'response': response.text
        }
    except Exception as e:
        return {
            'success': False,
            'error': str(e)
        }

@app.post('/transcribe')
async def transcribe_audio(payload: dict):
    # Whisper pipeline goes here
    return {'status': 'transcribe endpoint ready'}

@app.post('/telegram-webhook')
async def telegram_webhook(payload: dict):
    # Telegram bot handler goes here
    return {'status': 'telegram webhook ready'}

@app.get('/list-models')
def list_models():
    import google.generativeai as genai
    models = genai.list_models()
    available = [m.name for m in models if 'generateContent' in m.supported_generation_methods]
    return {'available_models': available}