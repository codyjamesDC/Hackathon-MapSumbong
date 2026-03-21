# MapSumbong Testing & Troubleshooting Guide

Comprehensive testing strategies and solutions to common issues.

---

## Testing Strategy

### 1. Unit Testing

Test individual components in isolation.

**Backend Tests (pytest)**

```bash
# Install pytest
pip install pytest pytest-asyncio

# Create test file
cat > test_claude.py << EOF
import pytest
from services.claude_service import process_message

@pytest.mark.asyncio
async def test_flood_report():
    result = await process_message("May baha sa gate ng school")
    assert result['success'] == True
    assert result['extracted_data']['issue_type'] == 'flood'
    assert result['extracted_data']['urgency'] in ['critical', 'high']

@pytest.mark.asyncio
async def test_spam_detection():
    result = await process_message("hahaha joke lang")
    assert result['success'] == False
    assert result['extracted_data']['is_spam'] == True
EOF

# Run tests
pytest test_claude.py -v
```

**Flutter Tests**

```dart
// test/api_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mapsumbong/services/api_service.dart';

void main() {
  test('Process message returns report ID', () async {
    final result = await ApiService.processMessage(
      message: 'May basura sa kanto',
      reporterId: 'TEST-001',
    );
    
    expect(result['success'], true);
    expect(result['report_id'], isNotNull);
  });
}
```

### 2. Integration Testing

Test complete workflows end-to-end.

**Backend Integration Test**

```python
# test_integration.py
import httpx
import asyncio

async def test_full_report_flow():
    base_url = "http://localhost:8000"
    
    # 1. Send message
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{base_url}/process-message",
            json={
                "message": "May baha sa gate",
                "reporter_id": "TEST-001"
            }
        )
    
    assert response.status_code == 200
    data = response.json()
    assert data['success'] == True
    report_id = data['report_id']
    
    # 2. Fetch report
    async with httpx.AsyncClient() as client:
        response = await client.get(f"{base_url}/reports/{report_id}")
    
    assert response.status_code == 200
    report = response.json()
    assert report['id'] == report_id
    
    # 3. Update status
    async with httpx.AsyncClient() as client:
        response = await client.patch(
            f"{base_url}/reports/{report_id}/status",
            json={"status": "resolved", "updated_by": "test_official"}
        )
    
    assert response.status_code == 200

asyncio.run(test_full_report_flow())
```

### 3. Manual Testing Checklist

#### Resident App Flow

- [ ] Install APK on Android device
- [ ] Open app (no crashes)
- [ ] Type message: "May baha sa gate ng school"
- [ ] Send message
- [ ] Receive chatbot response in Filipino
- [ ] See report ID displayed
- [ ] Close and reopen app (state persists)

#### Dashboard Flow

- [ ] Open dashboard URL
- [ ] Map loads with tiles
- [ ] See existing reports as pins
- [ ] Click a pin → popup shows details
- [ ] Select a report from queue
- [ ] Change status to "In Progress"
- [ ] Status updates on map in real-time
- [ ] Mark as Resolved with photo
- [ ] Verify audit log entry created

#### Telegram Flow

- [ ] Send message to bot: "May basura sa kanto"
- [ ] Receive acknowledgment
- [ ] Receive report ID
- [ ] Send /status <report_id>
- [ ] Receive status information
- [ ] Send voice note
- [ ] Receive transcription + response

---

## Common Issues & Solutions

### Issue 1: Backend Won't Start

**Symptoms:**
```
ModuleNotFoundError: No module named 'fastapi'
```

**Solution:**
```bash
# Activate virtual environment first
source venv/bin/activate  # Windows: venv\Scripts\activate

# Reinstall dependencies
pip install -r requirements.txt
```

---

### Issue 2: Claude API Error

**Symptoms:**
```
anthropic.APIError: Authentication failed
```

**Solutions:**

**Check API key:**
```bash
echo $ANTHROPIC_API_KEY  # Should show key
```

**Verify .env loaded:**
```python
# Add to main.py
import os
print(f"Claude API Key: {os.getenv('ANTHROPIC_API_KEY')[:20]}...")
```

**Test API directly:**
```bash
curl https://api.anthropic.com/v1/messages \
  -H "anthropic-version: 2023-06-01" \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "content-type: application/json" \
  -d '{"model":"claude-sonnet-4-20250514","max_tokens":100,"messages":[{"role":"user","content":"Hello"}]}'
```

---

### Issue 3: Supabase Connection Failed

**Symptoms:**
```
supabase.exceptions.APIError: Connection refused
```

**Solutions:**

**Verify credentials:**
```python
from supabase import create_client
import os

supabase = create_client(
    os.getenv('SUPABASE_URL'),
    os.getenv('SUPABASE_SERVICE_KEY')
)

# Test connection
result = supabase.table('reports').select('*').limit(1).execute()
print(f"Connected! Found {len(result.data)} reports")
```

**Check RLS policies:**
- If getting empty results, RLS might be blocking
- Use SERVICE_KEY (not ANON_KEY) in backend
- Verify policies in Supabase Dashboard

---

### Issue 4: Flutter App Can't Connect to Backend

**Symptoms:**
```
SocketException: Failed to connect to localhost:8000
```

**Solutions:**

**Android Emulator:**
```dart
// Use 10.0.2.2 instead of localhost
const baseUrl = 'http://10.0.2.2:8000';
```

**Real Device:**
```dart
// Use your computer's IP address
const baseUrl = 'http://192.168.1.100:8000';

// Find your IP:
// Windows: ipconfig
// Mac/Linux: ifconfig
```

**Check CORS:**
```python
# main.py
app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],  # Allow all in development
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*'],
)
```

---

### Issue 5: Map Not Loading

**Symptoms:**
- Dashboard loads but map is blank
- Console error: "Tiles failed to load"

**Solutions:**

**Check internet connection**

**Verify tile URL:**
```javascript
<TileLayer
  url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
  attribution='&copy; OpenStreetMap contributors'
/>
```

**Add error handler:**
```javascript
<MapContainer 
  center={center} 
  zoom={13}
  whenCreated={(map) => {
    map.on('tileerror', (error) => {
      console.error('Tile error:', error);
    });
  }}
>
```

---

### Issue 6: Realtime Updates Not Working

**Symptoms:**
- New reports don't appear on dashboard automatically
- Must refresh to see changes

**Solutions:**

**Enable Realtime in Supabase:**
1. Database → Replication
2. Enable `reports` table
3. Enable `clusters` table

**Check subscription code:**
```javascript
const subscription = supabase
  .channel('reports')
  .on('postgres_changes', 
    { event: '*', schema: 'public', table: 'reports' },
    (payload) => {
      console.log('Change received!', payload);
      fetchReports(); // Refresh data
    }
  )
  .subscribe();
```

**Verify in browser console:**
```
Should see: "Change received!" when reports are created/updated
```

---

### Issue 7: Telegram Bot Not Responding

**Symptoms:**
- Messages sent to bot but no response

**Solutions:**

**Verify webhook:**
```bash
curl https://api.telegram.org/bot<TOKEN>/getWebhookInfo
```

Should show:
```json
{
  "url": "https://your-backend.onrender.com/telegram/webhook",
  "has_custom_certificate": false,
  "pending_update_count": 0
}
```

**Check backend logs:**
```
Should see POST /telegram/webhook requests
```

**Test webhook manually:**
```bash
curl -X POST http://localhost:8000/telegram/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "chat": {"id": 123},
      "text": "Test message"
    }
  }'
```

---

### Issue 8: Photos Not Uploading

**Symptoms:**
```
Error: Failed to upload photo
```

**Solutions:**

**Check storage bucket exists:**
- Supabase → Storage
- Should have `photos` bucket

**Verify bucket is public:**
- Click bucket → Settings
- Public: ON

**Check file size:**
```dart
// Compress image before upload
final compressedImage = await FlutterImageCompress.compressWithFile(
  file.path,
  quality: 70,
  minWidth: 800,
  minHeight: 600,
);
```

**Test upload directly:**
```python
from supabase import create_client
import os

supabase = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_KEY'))

with open('test.jpg', 'rb') as f:
    result = supabase.storage.from_('photos').upload('test.jpg', f)
    print(result)
```

---

### Issue 9: Geocoding Returns Wrong Coordinates

**Symptoms:**
- Reports appear in wrong location on map

**Solutions:**

**Add more context to location:**
```python
# Instead of:
query = "elementary school gate"

# Use:
query = "elementary school gate, Brgy Nangka, Valenzuela, Metro Manila"
```

**Implement fallback coordinates:**
```python
async def get_coordinates(location_text, barangay='Nangka'):
    coords = await geocode_via_nominatim(location_text, barangay)
    
    if coords is None:
        # Fallback to barangay center
        return get_default_barangay_coords(barangay)
    
    return coords
```

**Cache geocoding results:**
```python
# Avoid repeated API calls for same locations
geocode_cache = {}

async def get_coordinates(location_text, barangay):
    cache_key = f"{location_text}|{barangay}"
    
    if cache_key in geocode_cache:
        return geocode_cache[cache_key]
    
    coords = await geocode_via_nominatim(location_text, barangay)
    geocode_cache[cache_key] = coords
    return coords
```

---

### Issue 10: Render Backend Sleeping

**Symptoms:**
- First request takes 30+ seconds
- Subsequent requests are fast

**Explanation:**
- Render free tier sleeps after 15 minutes of inactivity
- Cold start takes ~30 seconds

**Solutions:**

**Option 1: Accept the delay** (free)
- Inform users first request is slow
- Subsequent requests are instant

**Option 2: Keep-alive ping** (free but hacky)
```python
# Add background task to ping self every 10 minutes
import asyncio
import httpx

async def keep_alive():
    while True:
        await asyncio.sleep(600)  # 10 minutes
        try:
            async with httpx.AsyncClient() as client:
                await client.get(os.getenv('BACKEND_URL'))
        except:
            pass

# Start in background
asyncio.create_task(keep_alive())
```

**Option 3: Upgrade to paid tier** ($7/month)
- No sleep
- Always instant

---

## Performance Optimization

### Database Queries

**Index frequently queried columns:**
```sql
CREATE INDEX idx_reports_barangay_status ON reports(barangay, status);
CREATE INDEX idx_reports_created_at_desc ON reports(created_at DESC);
```

**Limit query results:**
```python
# Bad
reports = supabase.table('reports').select('*').execute()

# Good
reports = supabase.table('reports').select('*').limit(100).execute()
```

### Frontend Caching

**Cache map tiles:**
```javascript
// In Map component
const tileLayer = L.tileLayer(
  'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
  {
    maxZoom: 19,
    attribution: '© OpenStreetMap',
    // Cache tiles in browser
    crossOrigin: true
  }
);
```

### API Response Compression

```python
# main.py
from fastapi.middleware.gzip import GZipMiddleware

app.add_middleware(GZipMiddleware, minimum_size=1000)
```

---

## Debugging Tools

### Backend Debugging

**Enable debug logs:**
```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

**Use FastAPI interactive docs:**
```
Open: http://localhost:8000/docs
Test all endpoints interactively
```

### Frontend Debugging

**React DevTools:**
```bash
# Install browser extension
# Chrome: React Developer Tools
# Firefox: React Developer Tools
```

**Console logging:**
```javascript
useEffect(() => {
  console.log('Reports updated:', reports);
}, [reports]);
```

### Database Debugging

**Supabase Studio:**
- Table Editor: View/edit data directly
- SQL Editor: Run custom queries
- API Logs: See all database calls

**Enable query logging:**
```sql
-- See slow queries
SELECT * FROM pg_stat_statements 
ORDER BY mean_exec_time DESC 
LIMIT 10;
```

---

## Demo Data Seeding

Create realistic test data for presentations.

```python
# seed_demo_data.py
from supabase import create_client
import os
from datetime import datetime, timedelta
import random

supabase = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_KEY'))

demo_reports = [
    {
        'id': 'VM-2026-DEMO1',
        'reporter_anonymous_id': 'ANON-DEMO1',
        'issue_type': 'flood',
        'description': 'May mataas na baha sa may gate ng elementary school',
        'latitude': 14.6042,
        'longitude': 120.9822,
        'location_text': 'Elementary School Gate',
        'urgency': 'critical',
        'barangay': 'Nangka',
        'status': 'received',
        'sdg_tag': 'SDG 11'
    },
    {
        'id': 'VM-2026-DEMO2',
        'reporter_anonymous_id': 'ANON-DEMO2',
        'issue_type': 'waste',
        'description': 'Hindi nakolekta ang basura, 3 days na',
        'latitude': 14.6050,
        'longitude': 120.9830,
        'location_text': 'Corner of Rizal Street',
        'urgency': 'medium',
        'barangay': 'Nangka',
        'status': 'in_progress',
        'sdg_tag': 'SDG 11'
    },
    # Add more...
]

for report in demo_reports:
    supabase.table('reports').insert(report).execute()

print(f"Seeded {len(demo_reports)} demo reports")
```

Run:
```bash
python seed_demo_data.py
```

---

## Pre-Demo Checklist

- [ ] Backend is deployed and healthy
- [ ] Dashboard loads with map
- [ ] At least 10 demo reports visible on map
- [ ] Telegram bot responds to messages
- [ ] Mobile APK tested on real device
- [ ] All credentials secured (not in code)
- [ ] Backup of database taken
- [ ] Rollback plan ready

---

**Remember:** Test early, test often. Most issues are caught in testing, not production! 🔍