# MapSumbong Backend Guide

Complete FastAPI implementation with Claude AI and Whisper integration.

---

## Prerequisites

- Python 3.11 or higher
- pip package manager
- Git
- Text editor (VS Code recommended)

---

## Project Setup

### Step 1: Create Project Directory

```bash
# Create and navigate to project directory
mkdir mapsumbong-backend
cd mapsumbong-backend

# Initialize git repository
git init

# Create .gitignore
cat > .gitignore << EOF
venv/
__pycache__/
*.pyc
.env
*.log
.DS_Store
EOF
```

### Step 2: Set Up Virtual Environment

```bash
# Create virtual environment
python -m venv venv

# Activate virtual environment
# On Windows:
venv\Scripts\activate

# On macOS/Linux:
source venv/bin/activate

# Verify Python version
python --version  # Should be 3.11+
```

### Step 3: Install Dependencies

```bash
# Install all required packages
pip install fastapi uvicorn[standard] supabase anthropic openai python-dotenv httpx python-multipart websockets

# Create requirements.txt
pip freeze > requirements.txt
```

### Step 4: Create Project Structure

```bash
# Create folder structure
mkdir -p services routes utils
touch main.py .env
touch services/__init__.py routes/__init__.py utils/__init__.py

# Your structure should look like:
# mapsumbong-backend/
# ├── main.py
# ├── .env
# ├── requirements.txt
# ├── services/
# │   ├── __init__.py
# │   ├── claude_service.py
# │   ├── whisper_service.py
# │   └── cluster_service.py
# ├── routes/
# │   ├── __init__.py
# │   ├── reports.py
# │   └── telegram.py
# └── utils/
#     ├── __init__.py
#     └── geocoding.py
```

---

## Configuration

### Create .env File

```bash
# .env
# Copy your actual values from Supabase and API providers

# Supabase
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Claude API (Anthropic)
ANTHROPIC_API_KEY=sk-ant-api03-xxxxx

# OpenAI (Whisper)
OPENAI_API_KEY=sk-xxxxx

# Telegram Bot
TELEGRAM_BOT_TOKEN=1234567890:ABCdefGHIjklMNOpqrsTUVwxyz

# Environment
ENVIRONMENT=development

# Optional
DEBUG=true
```

---

## Core Implementation

### main.py

Main FastAPI application entry point.

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv()

# Import routers
from routes import reports, telegram

# Create FastAPI app
app = FastAPI(
    title='MapSumbong API',
    description='Backend API for disaster reporting system',
    version='1.0.0'
)

# Configure CORS for web dashboard
app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],  # In production: ['https://dashboard.mapsumbong.app']
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*'],
)

# Include routers
app.include_router(reports.router, tags=['reports'])
app.include_router(telegram.router, prefix='/telegram', tags=['telegram'])

# Health check endpoint
@app.get('/')
def health_check():
    return {
        'status': 'healthy',
        'service': 'MapSumbong Backend',
        'version': '1.0.0',
        'environment': os.getenv('ENVIRONMENT', 'development')
    }

@app.get('/health')
def detailed_health():
    """Detailed health check with service status"""
    return {
        'status': 'healthy',
        'services': {
            'database': 'connected',  # TODO: Add actual Supabase ping
            'claude_api': 'configured' if os.getenv('ANTHROPIC_API_KEY') else 'not_configured',
            'whisper_api': 'configured' if os.getenv('OPENAI_API_KEY') else 'not_configured',
        },
        'environment': os.getenv('ENVIRONMENT', 'development')
    }

# Run with: uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

---

## Services

### services/claude_service.py

Claude AI integration for message processing.

```python
import anthropic
import os
import json
from typing import Dict, Any, Optional

# Initialize Claude client
client = anthropic.Anthropic(api_key=os.getenv('ANTHROPIC_API_KEY'))

SYSTEM_PROMPT = """You are a helpful Filipino disaster reporting assistant for MapSumbong.

Your tasks:
1. Extract structured information from casual Filipino messages (Tagalog/Bisaya/Taglish)
2. Classify urgency based on severity
3. Identify the type of issue
4. Detect spam or joke messages
5. Respond naturally in Filipino

Extract this JSON structure:
{
  "issue_type": "flood|waste|road|power|water|emergency|fire|crime|other",
  "location_text": "exact landmark or street name mentioned",
  "urgency": "critical|high|medium|low",
  "sdg_tag": "SDG 3|SDG 6|SDG 11|SDG 13",
  "is_spam": true|false,
  "confidence": 0.0-1.0
}

Urgency Classification:
- critical: Life-threatening (flood >1m, fire, medical emergency, crime in progress)
- high: Urgent but not immediately life-threatening (rising flood, power outage, blocked main road)
- medium: Important but can wait hours (waste collection, minor road damage)
- low: Maintenance issues (street light out, small pothole)

After extracting the JSON, provide a warm response in Filipino acknowledging the report.
If the message is spam or a joke, politely ask for a valid report.

Examples:

Input: "May baha sa gate ng elementary school, halos 1 metro na"
Output JSON: {"issue_type": "flood", "location_text": "elementary school gate", "urgency": "critical", "sdg_tag": "SDG 11", "is_spam": false, "confidence": 0.95}
Response: "Salamat sa pag-report! Naitala na ang ulat tungkol sa mataas na baha sa gate ng elementary school. Magiging alerto ang barangay ninyo. Report ID ay ibibigay sa inyo."

Input: "hahaha joke lang"
Output JSON: {"is_spam": true, "confidence": 1.0}
Response: "Pasensya na, kailangan namin ng tunay na ulat tungkol sa mga problema sa komunidad. Mayroon ka bang gustong i-report?"
"""

async def process_message(user_message: str, photo_url: Optional[str] = None) -> Dict[str, Any]:
    """
    Process user message with Claude AI
    
    Args:
        user_message: Text message from user
        photo_url: Optional photo URL for visual analysis
        
    Returns:
        Dictionary with extracted_data, chatbot_response, and success flag
    """
    try:
        # Build message content
        content = [{'type': 'text', 'text': user_message}]
        
        # Add image if provided (Claude can analyze flood depth, damage, etc.)
        if photo_url:
            content.append({
                'type': 'image',
                'source': {
                    'type': 'url',
                    'url': photo_url
                }
            })
        
        # Call Claude API
        message = client.messages.create(
            model='claude-sonnet-4-20250514',
            max_tokens=1500,
            system=SYSTEM_PROMPT,
            messages=[{'role': 'user', 'content': content}]
        )
        
        # Extract response text
        response_text = message.content[0].text
        
        # Parse JSON from response
        # Claude should return JSON block + friendly message
        json_start = response_text.find('{')
        json_end = response_text.rfind('}') + 1
        
        if json_start != -1 and json_end > json_start:
            extracted_json = response_text[json_start:json_end]
            extracted_data = json.loads(extracted_json)
            
            # Extract chatbot response (text after JSON)
            chatbot_response = response_text[json_end:].strip()
            
            # If no response text after JSON, use a default
            if not chatbot_response:
                chatbot_response = "Salamat sa pag-report!"
        else:
            # Fallback if JSON parsing fails
            extracted_data = {
                'issue_type': 'other',
                'urgency': 'medium',
                'is_spam': False,
                'confidence': 0.5
            }
            chatbot_response = response_text
        
        return {
            'extracted_data': extracted_data,
            'chatbot_response': chatbot_response,
            'success': not extracted_data.get('is_spam', False)
        }
    
    except anthropic.APIError as e:
        print(f'Claude API error: {e}')
        return {
            'extracted_data': {},
            'chatbot_response': 'Pasensya na, may technical issue sa sistema. Subukan ulit.',
            'success': False,
            'error': str(e)
        }
    except json.JSONDecodeError as e:
        print(f'JSON parsing error: {e}')
        print(f'Response text: {response_text}')
        return {
            'extracted_data': {'issue_type': 'other', 'urgency': 'medium'},
            'chatbot_response': 'Naitala ang inyong report.',
            'success': True
        }
    except Exception as e:
        print(f'Unexpected error: {e}')
        return {
            'extracted_data': {},
            'chatbot_response': 'Pasensya na, may technical issue. Subukan ulit.',
            'success': False,
            'error': str(e)
        }
```

### services/whisper_service.py

OpenAI Whisper integration for voice transcription.

```python
import openai
import os
from typing import Dict

# Initialize OpenAI client
openai.api_key = os.getenv('OPENAI_API_KEY')

async def transcribe_audio(audio_file_path: str) -> Dict[str, any]:
    """
    Transcribe audio file using OpenAI Whisper
    
    Args:
        audio_file_path: Path to audio file on disk
        
    Returns:
        Dictionary with text, confidence, and language
    """
    try:
        with open(audio_file_path, 'rb') as audio_file:
            transcript = openai.Audio.transcribe(
                model='whisper-1',
                file=audio_file,
                language='tl',  # Filipino
                response_format='json'
            )
        
        return {
            'text': transcript['text'],
            'confidence': 0.95,  # Whisper doesn't provide confidence scores
            'language': 'tl'
        }
    
    except openai.APIError as e:
        print(f'Whisper API error: {e}')
        return {
            'text': '',
            'confidence': 0.0,
            'error': str(e)
        }
    except Exception as e:
        print(f'Unexpected error: {e}')
        return {
            'text': '',
            'confidence': 0.0,
            'error': str(e)
        }
```

### services/cluster_service.py

Cluster detection for multiple reports in same area.

```python
from supabase import create_client
import os
from datetime import datetime, timedelta
from typing import List, Dict

# Initialize Supabase client
supabase = create_client(
    os.getenv('SUPABASE_URL'),
    os.getenv('SUPABASE_SERVICE_KEY')
)

async def detect_clusters(barangay: str = None) -> List[Dict]:
    """
    Detect clusters of 3+ reports within 500m in last 2 hours
    
    Args:
        barangay: Optional barangay filter
        
    Returns:
        List of detected clusters
    """
    try:
        # Get reports from last 2 hours
        two_hours_ago = datetime.utcnow() - timedelta(hours=2)
        
        query = supabase.table('reports').select('*').gte(
            'created_at', 
            two_hours_ago.isoformat()
        ).eq('is_deleted', False)
        
        if barangay:
            query = query.eq('barangay', barangay)
        
        response = query.execute()
        recent_reports = response.data
        
        if len(recent_reports) < 3:
            return []
        
        # Group by location (within 500m) and issue type
        clusters = []
        processed_reports = set()
        
        for i, report in enumerate(recent_reports):
            if report['id'] in processed_reports:
                continue
            
            # Find nearby reports of same type
            cluster_reports = [report]
            
            for j, other_report in enumerate(recent_reports[i+1:]):
                if other_report['id'] in processed_reports:
                    continue
                
                # Calculate distance
                distance = calculate_distance(
                    report['latitude'], report['longitude'],
                    other_report['latitude'], other_report['longitude']
                )
                
                # Same issue type and within 500m
                if (distance <= 500 and 
                    report['issue_type'] == other_report['issue_type']):
                    cluster_reports.append(other_report)
                    processed_reports.add(other_report['id'])
            
            # If 3+ reports, it's a cluster
            if len(cluster_reports) >= 3:
                # Calculate center point
                avg_lat = sum(r['latitude'] for r in cluster_reports) / len(cluster_reports)
                avg_lng = sum(r['longitude'] for r in cluster_reports) / len(cluster_reports)
                
                # Create cluster entry
                cluster_data = {
                    'barangay': report['barangay'],
                    'issue_type': report['issue_type'],
                    'report_count': len(cluster_reports),
                    'latitude': avg_lat,
                    'longitude': avg_lng,
                    'radius_meters': 500,
                    'report_ids': [r['id'] for r in cluster_reports],
                    'alerted': False
                }
                
                # Save to database
                result = supabase.table('clusters').insert(cluster_data).execute()
                
                clusters.append(result.data[0])
                
                # Mark reports as processed
                for r in cluster_reports:
                    processed_reports.add(r['id'])
        
        return clusters
    
    except Exception as e:
        print(f'Cluster detection error: {e}')
        return []

def calculate_distance(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """
    Calculate distance between two points in meters using Haversine formula
    """
    from math import radians, sin, cos, sqrt, atan2
    
    R = 6371000  # Earth radius in meters
    
    lat1_rad = radians(lat1)
    lat2_rad = radians(lat2)
    delta_lat = radians(lat2 - lat1)
    delta_lng = radians(lng2 - lng1)
    
    a = sin(delta_lat/2)**2 + cos(lat1_rad) * cos(lat2_rad) * sin(delta_lng/2)**2
    c = 2 * atan2(sqrt(a), sqrt(1-a))
    
    return R * c
```

### utils/geocoding.py

OpenStreetMap Nominatim geocoding.

```python
import httpx
from typing import Dict, Optional

async def get_coordinates(
    location_text: str, 
    barangay: str = 'Nangka, Valenzuela'
) -> Dict[str, float]:
    """
    Convert location text to coordinates using OpenStreetMap Nominatim
    
    Args:
        location_text: Location description (e.g., "elementary school gate")
        barangay: Barangay context for better accuracy
        
    Returns:
        Dictionary with lat and lng
    """
    try:
        # Build search query
        query = f"{location_text}, {barangay}, Metro Manila, Philippines"
        
        # Call Nominatim API
        async with httpx.AsyncClient() as client:
            response = await client.get(
                'https://nominatim.openstreetmap.org/search',
                params={
                    'q': query,
                    'format': 'json',
                    'limit': 1
                },
                headers={
                    'User-Agent': 'MapSumbong/1.0 (Disaster Reporting System)'
                },
                timeout=5.0
            )
        
        data = response.json()
        
        if data and len(data) > 0:
            return {
                'lat': float(data[0]['lat']),
                'lng': float(data[0]['lon'])
            }
        else:
            # Fallback to barangay center if location not found
            print(f'Location not found: {query}, using default coordinates')
            return get_default_coordinates(barangay)
    
    except Exception as e:
        print(f'Geocoding error: {e}')
        return get_default_coordinates(barangay)

def get_default_coordinates(barangay: str) -> Dict[str, float]:
    """
    Get default coordinates for barangay
    """
    # Default coordinates for common barangays in Valenzuela
    defaults = {
        'Nangka': {'lat': 14.6042, 'lng': 120.9822},
        'Marulas': {'lat': 14.7080, 'lng': 120.9617},
        'Malinta': {'lat': 14.7028, 'lng': 120.9681},
    }
    
    # Extract barangay name
    barangay_name = barangay.split(',')[0].strip()
    
    # Return specific coordinates or Valenzuela center
    return defaults.get(barangay_name, {'lat': 14.6942, 'lng': 120.9834})
```

---

## Routes

### routes/reports.py

Report management endpoints.

```python
from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import Optional, List
import uuid
from supabase import create_client
import os

from services.claude_service import process_message as process_with_claude
from services.cluster_service import detect_clusters
from utils.geocoding import get_coordinates

router = APIRouter()

# Initialize Supabase
supabase = create_client(
    os.getenv('SUPABASE_URL'),
    os.getenv('SUPABASE_SERVICE_KEY')
)

# Request models
class ProcessMessageRequest(BaseModel):
    message: str
    reporter_id: str
    photo_url: Optional[str] = None

class UpdateStatusRequest(BaseModel):
    status: str
    resolution_note: Optional[str] = None
    resolution_photo_url: Optional[str] = None
    updated_by: Optional[str] = None

class DeleteReportRequest(BaseModel):
    deleted_by: str
    reason: str

@router.post('/process-message')
async def process_message(
    request: ProcessMessageRequest,
    background_tasks: BackgroundTasks
):
    """Process message from resident using Claude AI"""
    
    # Call Claude to extract data
    result = await process_with_claude(request.message, request.photo_url)
    
    # If spam, return early
    if not result['success']:
        return result
    
    extracted = result['extracted_data']
    
    # Geocode location
    coordinates = await get_coordinates(
        extracted.get('location_text', ''),
        'Nangka, Valenzuela'  # TODO: Get from user profile
    )
    
    # Generate report ID
    report_id = f"VM-2026-{str(uuid.uuid4())[:4].upper()}"
    
    # Prepare report data
    report_data = {
        'id': report_id,
        'reporter_anonymous_id': request.reporter_id,
        'issue_type': extracted.get('issue_type', 'other'),
        'description': request.message,
        'latitude': coordinates['lat'],
        'longitude': coordinates['lng'],
        'location_text': extracted.get('location_text'),
        'urgency': extracted.get('urgency', 'medium'),
        'sdg_tag': extracted.get('sdg_tag'),
        'photo_url': request.photo_url,
        'barangay': 'Nangka',  # TODO: Derive from coordinates or user profile
        'status': 'received'
    }
    
    # Save to database
    try:
        supabase.table('reports').insert(report_data).execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Database error: {str(e)}')
    
    # Check for clusters in background
    background_tasks.add_task(detect_clusters, 'Nangka')
    
    # Return success response
    return {
        'success': True,
        'report_id': report_id,
        'chatbot_response': result['chatbot_response'],
        'extracted_data': extracted
    }

@router.get('/reports')
async def get_reports(
    status: Optional[str] = None,
    barangay: Optional[str] = None,
    urgency: Optional[str] = None,
    issue_type: Optional[str] = None,
    limit: int = 100,
    offset: int = 0
):
    """Get all reports with filters"""
    
    query = supabase.table('reports').select('*').eq('is_deleted', False)
    
    if status:
        query = query.eq('status', status)
    if barangay:
        query = query.eq('barangay', barangay)
    if urgency:
        query = query.eq('urgency', urgency)
    if issue_type:
        query = query.eq('issue_type', issue_type)
    
    query = query.order('created_at', desc=True).range(offset, offset + limit - 1)
    
    response = query.execute()
    
    return {
        'reports': response.data,
        'total': len(response.data),
        'limit': limit,
        'offset': offset
    }

@router.get('/reports/{report_id}')
async def get_report(report_id: str):
    """Get single report by ID"""
    
    response = supabase.table('reports').select('*').eq('id', report_id).execute()
    
    if not response.data:
        raise HTTPException(status_code=404, detail='Report not found')
    
    return response.data[0]

@router.patch('/reports/{report_id}/status')
async def update_report_status(
    report_id: str,
    request: UpdateStatusRequest
):
    """Update report status (officials only)"""
    
    update_data = {'status': request.status}
    
    if request.resolution_note:
        update_data['resolution_note'] = request.resolution_note
    if request.resolution_photo_url:
        update_data['resolution_photo_url'] = request.resolution_photo_url
    
    try:
        # Update report
        supabase.table('reports').update(update_data).eq('id', report_id).execute()
        
        # Create audit log
        supabase.table('audit_log').insert({
            'report_id': report_id,
            'action': 'status_change',
            'performed_by': request.updated_by or 'system',
            'old_value': None,  # TODO: Fetch old status first
            'new_value': request.status,
            'note': f'Status changed to {request.status}'
        }).execute()
        
        return {
            'success': True,
            'report_id': report_id,
            'new_status': request.status
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete('/reports/{report_id}')
async def delete_report(report_id: str, request: DeleteReportRequest):
    """Soft delete a report"""
    
    try:
        # Soft delete
        supabase.table('reports').update({
            'is_deleted': True,
            'deleted_by': request.deleted_by
        }).eq('id', report_id).execute()
        
        # Create audit log (also triggered by database trigger)
        result = supabase.table('audit_log').insert({
            'report_id': report_id,
            'action': 'delete',
            'performed_by': request.deleted_by,
            'note': request.reason
        }).execute()
        
        return {
            'success': True,
            'report_id': report_id,
            'audit_log_id': result.data[0]['id']
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get('/clusters')
async def get_clusters(
    barangay: Optional[str] = None,
    alerted: Optional[bool] = None,
    limit: int = 50
):
    """Get detected clusters"""
    
    query = supabase.table('clusters').select('*')
    
    if barangay:
        query = query.eq('barangay', barangay)
    if alerted is not None:
        query = query.eq('alerted', alerted)
    
    query = query.order('created_at', desc=True).limit(limit)
    
    response = query.execute()
    
    return {
        'clusters': response.data,
        'total': len(response.data)
    }

@router.get('/audit-log')
async def get_audit_log(
    report_id: Optional[str] = None,
    action: Optional[str] = None,
    limit: int = 50,
    offset: int = 0
):
    """Get public audit log"""
    
    query = supabase.table('audit_log').select('*')
    
    if report_id:
        query = query.eq('report_id', report_id)
    if action:
        query = query.eq('action', action)
    
    query = query.order('created_at', desc=True).range(offset, offset + limit - 1)
    
    response = query.execute()
    
    return {
        'logs': response.data,
        'total': len(response.data)
    }
```

### routes/telegram.py

Telegram webhook handler.

```python
from fastapi import APIRouter, Request
import httpx
import os

from services.whisper_service import transcribe_audio
from services.claude_service import process_message as process_with_claude

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
            
            # Process with Claude
            result = await process_with_claude(user_message)
            
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
```

---

## Running the Backend

### Development Mode

```bash
# Activate virtual environment
source venv/bin/activate  # Windows: venv\Scripts\activate

# Run with auto-reload
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Server will start at http://localhost:8000
# API docs at http://localhost:8000/docs
```

### Testing Endpoints

```bash
# Health check
curl http://localhost:8000/

# Process message
curl -X POST http://localhost:8000/process-message \
  -H "Content-Type: application/json" \
  -d '{
    "message": "May baha sa gate ng school",
    "reporter_id": "ANON-TEST"
  }'

# Get reports
curl http://localhost:8000/reports

# View API documentation
# Open browser: http://localhost:8000/docs
```

---

## Next Steps

1. ✅ Backend is running
2. → Read 04_FLUTTER_GUIDE.md to build the resident app
3. → Read 05_DASHBOARD_GUIDE.md to build the admin dashboard
4. → Read 06_TELEGRAM_BOT.md to set up Telegram integration

---

**Troubleshooting:** See 08_TESTING.md for common issues and solutions.