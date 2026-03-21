# MapSumbong API Reference

Complete FastAPI backend endpoint documentation with request/response examples.

**Base URL (Development):** `http://localhost:8000`  
**Base URL (Production):** `https://mapsumbong-backend.onrender.com`

---

## Authentication

### Resident Endpoints
Require Supabase JWT token in header:
```
Authorization: Bearer <supabase_jwt_token>
```

### Official Endpoints  
Require service role key or official JWT token.

### Public Endpoints
No authentication required (audit logs, public transparency feed).

---

## Endpoints

### Health Check

#### GET /

Check if backend is running.

**Request:**
```bash
curl http://localhost:8000/
```

**Response:**
```json
{
  "status": "healthy",
  "service": "MapSumbong Backend",
  "version": "1.0.0"
}
```

---

### POST /process-message

Process a message from resident using Claude AI.

**Request Body:**
```json
{
  "message": "May baha sa may gate ng elementary school sa Brgy Nangka",
  "reporter_id": "ANON-12345",
  "photo_url": "https://supabase.co/storage/v1/object/public/photos/abc123.jpg"
}
```

**Response (Success):**
```json
{
  "success": true,
  "report_id": "VM-2026-0042",
  "chatbot_response": "Salamat sa pag-report! Nai-record na ang ulat tungkol sa baha sa elementary school gate. Report ID: VM-2026-0042. Magiging alerto ang inyong barangay.",
  "extracted_data": {
    "issue_type": "flood",
    "location_text": "Elementary school gate",
    "urgency": "high",
    "sdg_tag": "SDG 11",
    "coordinates": {
      "latitude": 14.6042,
      "longitude": 120.9822
    },
    "confidence": 0.95
  }
}
```

**Response (Spam Detected):**
```json
{
  "success": false,
  "chatbot_response": "Pasensya na, hindi ko maintindihan ang mensahe. Pwede mo bang ulitin at ilarawan ang problema?",
  "extracted_data": {
    "is_spam": true
  }
}
```

**Error Response:**
```json
{
  "success": false,
  "error": "Claude API error: Connection timeout",
  "chatbot_response": "Pasensya na, may technical issue. Subukan ulit."
}
```

**cURL Example:**
```bash
curl -X POST http://localhost:8000/process-message \
  -H "Content-Type: application/json" \
  -d '{
    "message": "May basura sa kanto",
    "reporter_id": "ANON-12345"
  }'
```

---

### POST /transcribe

Transcribe voice message using Whisper.

**Request:**
```
POST /transcribe
Content-Type: multipart/form-data

audio_file: [binary data]
```

**Response:**
```json
{
  "text": "May baha sa kanto ng Rizal Street",
  "confidence": 0.92,
  "language": "tl"
}
```

**Error Response:**
```json
{
  "text": "",
  "confidence": 0.0,
  "error": "Failed to transcribe audio"
}
```

**cURL Example:**
```bash
curl -X POST http://localhost:8000/transcribe \
  -F "audio_file=@voice_note.ogg"
```

---

### POST /telegram-webhook

Telegram webhook handler (called by Telegram servers).

**Request Body (from Telegram):**
```json
{
  "update_id": 123456789,
  "message": {
    "message_id": 123,
    "from": {
      "id": 987654321,
      "first_name": "Juan"
    },
    "chat": {
      "id": 987654321,
      "type": "private"
    },
    "text": "May basura sa kanto"
  }
}
```

**Response:**
```json
{
  "ok": true
}
```

**Internal Flow:**
1. Extract message text or voice
2. If voice: call `/transcribe`
3. Call `/process-message`
4. Send response back to Telegram via Bot API

---

### GET /reports

Get all reports (paginated).

**Query Parameters:**
- `status` (optional): Filter by status  
  - Values: `received`, `in_progress`, `repair_scheduled`, `resolved`, `reopened`
- `barangay` (optional): Filter by barangay
- `urgency` (optional): Filter by urgency
  - Values: `critical`, `high`, `medium`, `low`
- `issue_type` (optional): Filter by issue type
  - Values: `flood`, `waste`, `road`, `power`, `water`, `emergency`, `fire`, `crime`, `other`
- `limit` (default: 100): Number of results
- `offset` (default: 0): Pagination offset

**Request:**
```bash
curl "http://localhost:8000/reports?status=received&barangay=Nangka&limit=50"
```

**Response:**
```json
{
  "reports": [
    {
      "id": "VM-2026-0001",
      "issue_type": "flood",
      "description": "May baha sa gate ng elementary school",
      "latitude": 14.6042,
      "longitude": 120.9822,
      "location_text": "Elementary School Gate",
      "urgency": "critical",
      "status": "received",
      "barangay": "Nangka",
      "created_at": "2026-03-21T10:30:00Z",
      "photo_url": "https://...",
      "reporter_display_name": "ANON-12345",
      "sdg_tag": "SDG 11"
    }
  ],
  "total": 1,
  "limit": 50,
  "offset": 0
}
```

---

### GET /reports/{report_id}

Get a single report by ID.

**Request:**
```bash
curl http://localhost:8000/reports/VM-2026-0001
```

**Response:**
```json
{
  "id": "VM-2026-0001",
  "issue_type": "flood",
  "description": "May baha sa gate ng elementary school",
  "latitude": 14.6042,
  "longitude": 120.9822,
  "location_text": "Elementary School Gate",
  "urgency": "critical",
  "status": "received",
  "barangay": "Nangka",
  "created_at": "2026-03-21T10:30:00Z",
  "updated_at": "2026-03-21T10:30:00Z",
  "photo_url": "https://...",
  "reporter_anonymous_id": "ANON-12345",
  "sdg_tag": "SDG 11"
}
```

**Error Response (Not Found):**
```json
{
  "detail": "Report not found"
}
```

---

### PATCH /reports/{report_id}/status

Update report status (officials only).

**Request Body:**
```json
{
  "status": "resolved",
  "resolution_note": "Drainage cleared by DPWH team. Water subsided.",
  "resolution_photo_url": "https://supabase.co/storage/v1/object/public/photos/resolved_123.jpg",
  "updated_by": "barangay_captain_1"
}
```

**Response:**
```json
{
  "success": true,
  "report_id": "VM-2026-0001",
  "new_status": "resolved",
  "notification_sent": true
}
```

**Side Effects:**
- Creates audit log entry
- Sends push notification to resident
- Triggers resident confirmation request (SMS/notification)

**cURL Example:**
```bash
curl -X PATCH http://localhost:8000/reports/VM-2026-0001/status \
  -H "Content-Type: application/json" \
  -d '{
    "status": "resolved",
    "resolution_note": "Fixed",
    "updated_by": "official_1"
  }'
```

---

### DELETE /reports/{report_id}

Soft delete a report (officials only).

**Request Body:**
```json
{
  "deleted_by": "barangay_captain_1",
  "reason": "Duplicate report"
}
```

**Response:**
```json
{
  "success": true,
  "report_id": "VM-2026-0001",
  "audit_log_id": "uuid-xxx-xxx",
  "notification_sent": true
}
```

**Side Effects:**
- Sets `is_deleted = true` (soft delete)
- Creates audit log entry
- Sends notification to reporter
- Adds entry to public transparency feed

**cURL Example:**
```bash
curl -X DELETE http://localhost:8000/reports/VM-2026-0001 \
  -H "Content-Type: application/json" \
  -d '{
    "deleted_by": "barangay_captain_1",
    "reason": "Duplicate"
  }'
```

---

### POST /reports/{report_id}/reopen

Resident reopens a resolved report.

**Request Body:**
```json
{
  "reason": "Problem still exists - baha pa rin",
  "reporter_id": "ANON-12345"
}
```

**Response:**
```json
{
  "success": true,
  "report_id": "VM-2026-0001",
  "new_status": "reopened"
}
```

**Side Effects:**
- Sets status to `reopened`
- Creates audit log entry
- Notifies barangay officials

---

### GET /clusters

Get detected report clusters.

**Query Parameters:**
- `barangay` (optional): Filter by barangay
- `alerted` (optional): Filter by alert status (true/false)
- `limit` (default: 50)

**Request:**
```bash
curl "http://localhost:8000/clusters?barangay=Nangka&alerted=false"
```

**Response:**
```json
{
  "clusters": [
    {
      "id": "uuid-xxx",
      "barangay": "Nangka",
      "issue_type": "flood",
      "report_count": 5,
      "latitude": 14.6042,
      "longitude": 120.9822,
      "radius_meters": 500,
      "report_ids": ["VM-2026-0001", "VM-2026-0003", "VM-2026-0005"],
      "alerted": true,
      "created_at": "2026-03-21T11:00:00Z"
    }
  ],
  "total": 1
}
```

---

### GET /audit-log

Get public audit log (transparency feed).

**Query Parameters:**
- `report_id` (optional): Filter by report ID
- `action` (optional): Filter by action type
- `limit` (default: 50)
- `offset` (default: 0)

**Request:**
```bash
curl "http://localhost:8000/audit-log?limit=10"
```

**Response:**
```json
{
  "logs": [
    {
      "id": "uuid-xxx",
      "report_id": "VM-2026-0001",
      "action": "delete",
      "performed_by": "barangay_captain_1",
      "note": "Duplicate report",
      "created_at": "2026-03-21T12:00:00Z"
    },
    {
      "id": "uuid-yyy",
      "report_id": "VM-2026-0002",
      "action": "status_change",
      "performed_by": "barangay_secretary",
      "old_value": "received",
      "new_value": "in_progress",
      "note": "Dispatched cleanup team",
      "created_at": "2026-03-21T11:45:00Z"
    }
  ],
  "total": 2
}
```

---

### GET /analytics

Get analytics summary (officials only).

**Query Parameters:**
- `barangay` (optional): Filter by barangay
- `start_date` (optional): Start date (ISO format)
- `end_date` (optional): End date (ISO format)

**Request:**
```bash
curl "http://localhost:8000/analytics?barangay=Nangka"
```

**Response:**
```json
{
  "total_reports": 125,
  "by_status": {
    "received": 45,
    "in_progress": 30,
    "resolved": 40,
    "reopened": 10
  },
  "by_urgency": {
    "critical": 15,
    "high": 35,
    "medium": 50,
    "low": 25
  },
  "by_issue_type": {
    "flood": 40,
    "waste": 30,
    "road": 25,
    "power": 15,
    "water": 10,
    "other": 5
  },
  "average_resolution_time_hours": 48,
  "clusters_detected": 3
}
```

---

## WebSocket Endpoints

### WS /ws

Real-time updates for dashboard.

**Connection:**
```javascript
const ws = new WebSocket('ws://localhost:8000/ws');

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('New update:', data);
};
```

**Message Types:**

**New Report:**
```json
{
  "type": "new_report",
  "data": {
    "id": "VM-2026-0042",
    "issue_type": "flood",
    "latitude": 14.6042,
    "longitude": 120.9822,
    "urgency": "critical",
    "barangay": "Nangka"
  }
}
```

**Status Update:**
```json
{
  "type": "status_update",
  "data": {
    "report_id": "VM-2026-0001",
    "old_status": "received",
    "new_status": "in_progress"
  }
}
```

**New Cluster:**
```json
{
  "type": "new_cluster",
  "data": {
    "id": "uuid-xxx",
    "barangay": "Nangka",
    "issue_type": "flood",
    "report_count": 3
  }
}
```

---

## Error Codes

| Status Code | Meaning |
|-------------|---------|
| 200 | Success |
| 400 | Bad Request (invalid input) |
| 401 | Unauthorized (missing/invalid token) |
| 403 | Forbidden (insufficient permissions) |
| 404 | Not Found |
| 429 | Too Many Requests (rate limited) |
| 500 | Internal Server Error |

**Error Response Format:**
```json
{
  "detail": "Error message here",
  "error_code": "INVALID_INPUT"
}
```

---

## Rate Limiting

- **Anonymous requests:** 10 requests/minute per IP
- **Authenticated requests:** 60 requests/minute per user
- **Claude API calls:** 50 requests/minute (Anthropic limit)
- **Whisper calls:** 30 requests/minute

**Rate Limit Response:**
```json
{
  "detail": "Rate limit exceeded. Try again in 30 seconds.",
  "retry_after": 30
}
```

---

## Environment Variables

Backend requires these environment variables:

```bash
# Supabase
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Claude API
ANTHROPIC_API_KEY=sk-ant-api03-xxxxx

# OpenAI (Whisper)
OPENAI_API_KEY=sk-xxxxx

# Telegram
TELEGRAM_BOT_TOKEN=1234567890:ABCdefGHIjklMNOpqrsTUVwxyz

# Optional: SMS (Semaphore)
SEMAPHORE_API_KEY=xxxxx

# Environment
ENVIRONMENT=development  # or production
```

---

## API Client Examples

### Python (requests)

```python
import requests

BASE_URL = "http://localhost:8000"

# Process message
response = requests.post(
    f"{BASE_URL}/process-message",
    json={
        "message": "May baha sa gate",
        "reporter_id": "ANON-12345"
    }
)
print(response.json())

# Get reports
response = requests.get(f"{BASE_URL}/reports?status=received")
print(response.json())
```

### JavaScript (fetch)

```javascript
const BASE_URL = 'http://localhost:8000';

// Process message
const response = await fetch(`${BASE_URL}/process-message`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    message: 'May basura sa kanto',
    reporter_id: 'ANON-12345'
  })
});
const data = await response.json();
console.log(data);
```

### Dart (http)

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

const baseUrl = 'http://10.0.2.2:8000';  // Android emulator

// Process message
final response = await http.post(
  Uri.parse('$baseUrl/process-message'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'message': 'May baha sa gate',
    'reporter_id': 'ANON-12345'
  }),
);
print(jsonDecode(response.body));
```

---

**Next Steps:** Read 03_BACKEND_GUIDE.md to implement the FastAPI backend.