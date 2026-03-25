# MapSumbong MVP Demo Setup Guide

This guide walks through setting up and running the complete MapSumbong MVP (mobile app + backend) for demonstration purposes.

**Est. Time**: 30-45 minutes (first time), 10-15 minutes (subsequent runs)

---

## Prerequisites

### System Requirements
- **Python**: 3.12 or higher
- **Node.js**: 18 or higher with npm/pnpm
- **Flutter**: 3.11 or higher
- **Git**: For cloning the repository
- **IDE/Editor**: VS Code (recommended), Android Studio, or Xcode

### Accounts & Credentials
- **Telegram**: BotFather account to create a test bot
- **Supabase**: Free tier project (https://supabase.com)
- **Google Gemini API**: Free tier access (https://ai.google.dev)
- Optional: SMS gateway account (Twilio, Plivo, etc.)

---

## Part 1: Backend Setup (FastAPI)

### 1.1 Clone and Navigate
```bash
cd mapsumbong/backend
```

### 1.2 Create Python Virtual Environment
```bash
# Windows (PowerShell)
python -m venv venv
.\venv\Scripts\Activate.ps1

# macOS/Linux
python3 -m venv venv
source venv/bin/activate
```

### 1.3 Install Dependencies
```bash
pip install -r requirements.txt
```

### 1.4 Set Up Environment Variables

Copy `.env.example` to `.env`:
```bash
# Windows
copy .env.example .env

# macOS/Linux
cp .env.example .env
```

Edit `.env` with your credentials:
```env
# REQUIRED - Application
ENVIRONMENT=development
DEBUG=true
LOG_LEVEL=DEBUG

# REQUIRED - Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=eyJhbGc...  # Service role key (not anon)

# REQUIRED - Gemini AI
GEMINI_API_KEY=AIzaSy...

# TELEGRAM - MVP Feature
TELEGRAM_BOT_TOKEN=789456123:ABCDefGhIjKlMnOpQ...
TELEGRAM_WEBHOOK_URL=https://your-domain.com/telegram/webhook
TELEGRAM_BOT_SECRET=your-secret-key-for-signature-verification

# SMS - Optional (remove if not needed)
SMS_PROVIDER=twilio  # or plivo, aws_sns, etc.
SMS_ACCOUNT_SID=ACxxxxxxxxxxxxxxxx
SMS_AUTH_TOKEN=xxxxxxxxxxxxxxxx
SMS_FROM_NUMBER=+1234567890
```

**How to get credentials:**
- **Supabase**: Create project, go to Settings → API, copy Project URL and service_role_key
- **Gemini**: Visit https://ai.google.dev → "Get API key" → Create free tier key
- **Telegram**: Open @BotFather in Telegram, `/newbot`, follow steps to get token

### 1.5 Verify Environment Configuration
```bash
python -m config.environment
```

Expected output:
```
================================================
Environment Configuration Status
================================================
✓ Application: development, Debug: ON
✓ Supabase configured and accessible
✓ Gemini AI API key loaded
✓ Telegram bot configured (webhook ready)
✗ SMS provider not configured (optional)

================================================
Ready to start. Run: uvicorn main:app --reload
================================================
```

### 1.6 Start Backend Server

**Development** (auto-reload on file changes):
```bash
uvicorn main:app --reload
```

**Production** (with gunicorn):
```bash
gunicorn -w 2 -k uvicorn.workers.UvicornWorker -b 0.0.0.0:8000 main:app
```

**Docker** (optional):
```bash
docker build -t mapsumbong-backend .
docker run -p 8000:8000 --env-file .env mapsumbong-backend
```

**Verify running:**
- Health check: `curl http://localhost:8000/health` → includes `"status": "healthy"`
- View logs: Check console output for `Uvicorn running on http://0.0.0.0:8000`

---

## Part 2: Frontend Setup (Flutter Mobile)

### 2.1 Navigate to Mobile App
```bash
cd mapsumbong/mobile
# or
cd mapsumbong/frontend  # if not yet migrated
```

### 2.2 Install Flutter Dependencies
```bash
flutter pub get
```

### 2.3 Configure App for Backend Connection

Edit `lib/services/api_service.dart`:
```dart
// Update baseUrl to your backend
static const String baseUrl = 'http://localhost:8000';  // Local dev
// or
static const String baseUrl = 'https://your-domain.com';  // Production
```

### 2.4 Run Mobile App

**On Android Emulator:**
```bash
# Start emulator if not already running
emulator -avd <emulator_name>

# Run app
flutter run -d emulator
```

**On iOS Simulator:**
```bash
open -a Simulator
flutter run -d iphone
```

**On Physical Device:**
```bash
# Connect via USB, enable developer mode
flutter run
```

**Web** (for quick testing):
```bash
flutter run -d web --web-port 3000
```

---

## Part 3: Telegram Bot Setup

### 3.1 Create Test Bot (@BotFather)
1. Open Telegram and search for `@BotFather`
2. Send `/newbot`
3. Choose a name (e.g., "MapSumbong Dev Bot")
4. Choose a username (e.g., "mapsumbong_dev_bot")
5. Copy the bot token: `123456:ABCdefGhIjKlMnOpQ...`
6. Paste into `.env` file as `TELEGRAM_BOT_TOKEN`

### 3.2 Configure Webhook
For local development without public URL:
```bash
# Option A: Use ngrok for public URL
ngrok http 8000
# Copy your ngrok URL (https://xxxx-x.ngrok.io)

# Then set in .env:
# TELEGRAM_WEBHOOK_URL=https://xxxx-x.ngrok.io/telegram/webhook
```

Or for production deployment:
```
TELEGRAM_WEBHOOK_URL=https://your-domain.com/telegram/webhook
```

### 3.3 Test Telegram Integration

**Direct test via cURL:**
```bash
curl -X POST http://localhost:8000/telegram/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "update_id": 123456789,
    "message": {
      "message_id": 1,
      "chat": {"id": 12345, "type": "private"},
      "from": {"id": 12345, "first_name": "Test"},
      "text": "Test message from MapSumbong"
    }
  }'
```

Expected response: `{"ok": true}`

**Via Telegram Client:**
1. Start chat with your bot (@mapsumbong_dev_bot)
2. Send a message: "There's a pothole on Oak Street"
3. Check backend logs for processing
4. Wait ~5 seconds for response with AI analysis

---

## Part 4: Complete Demo Flow

### 4.1 Offline Accessibility Simulation

**Via Telegram** (primary offline channel):
1. Open Telegram, chat with your bot
2. Send: "Broken streetlight near school"
3. Bot processes via Gemini AI
4. Response: "Issue logged as Public Safety. Our team will review immediately."

**Via SMS** (future feature):
- SMS webhook routes are not implemented in the current backend build.
- Use Telegram as the offline channel for the MVP demo.

### 4.2 Mobile App Demo Flow

1. **Launch App**
   - Tap "Get Started"
   - Enter phone: +63 9XX XXXX XXX (any number, no actual SMS sent in dev)

2. **Verify Code** (Dev: auto-populates with "000000")
   - Enter OTP: 000000
   - Tap "Verify"

3. **Allow Permissions**
   - Location: "While Using App" (needed for reports)
   - Camera: "Allow" (for photo reports)

4. **Create Report**
   - Tap "+" button
   - Enter issue type: "Pothole"
   - Enter description: "Large hole near market entrance"
   - Tap location pin to set coordinates
   - Optional: Take photo with camera
   - Tap "Submit Report"

5. **Chat Flow**
   - Report created shows in list
   - Tap report to open detail
   - Tap "Chat with AI" button
   - Ask follow-up: "When will this be fixed?"
   - Bot responds with AI-generated timeline

6. **Offline Access Verification**
   - Disable WiFi/Mobile data in app settings
   - Show message: "Unable to connect. Report via Telegram or SMS"
   - Demonstrate Telegram fallback (send same issue via bot)

### 4.3 View Analytics/Admin Dashboard

**Backend Metrics:**
```bash
curl http://localhost:8000/health
# /metrics requires admin JWT in Authorization header
curl http://localhost:8000/ready
```

**Supabase Dashboard:**
1. Open https://app.supabase.com
2. Go to SQL Editor
3. Query recent reports:
   ```sql
   SELECT id, issue_type, description, status, created_at 
   FROM reports 
   ORDER BY created_at DESC 
   LIMIT 10;
   ```

---

## Part 5: Troubleshooting

### Issue: Backend won't start

**Error**: `ModuleNotFoundError: No module named 'fastapi'`
- **Solution**: Ensure virtual environment is activated: `source venv/bin/activate` (or `.\venv\Scripts\Activate.ps1` on Windows)

**Error**: `SUPABASE_URL not found`
- **Solution**: Copy `.env.example` to `.env` and fill in credentials

**Error**: `Address already in use on port 8000`
- **Solution**: Change port in main.py or kill existing process:
  ```bash
  # Windows
  netstat -ano | findstr :8000
  taskkill /PID <PID> /F
  
  # macOS/Linux
  lsof -i :8000
  kill -9 <PID>
  ```

### Issue: Mobile app can't connect to backend

**Error**: `Failed to connect to localhost:8000`
- **Solution**: Change `baseUrl` in `api_service.dart` to your computer's IP:
  ```dart
  static const String baseUrl = 'http://192.168.1.XX:8000';
  ```
  (Get IP: `ipconfig` on Windows, `ifconfig` on macOS/Linux)

**Error**: CORS error in logs
- **Solution**: Backend CORS is configured in `main.py`. Ensure mobile baseUrl matches allowed origins.

### Issue: Telegram bot not responding

**Error**: `Message sent but no response from bot`
- **Solution**: Check webhook is set correctly:
  ```bash
  curl https://api.telegram.org/bot<YOUR_TOKEN>/getWebhookInfo
  ```
  - Verify `webhook_url` matches `TELEGRAM_WEBHOOK_URL` in `.env`
  - Confirm ngrok is still running (if using local dev)

**Error**: `Gemini API key invalid`
- **Solution**: Regenerate key at https://ai.google.dev → Settings → API keys → Delete & create new

---

## Part 6: Demo Narrative (5-10 minutes)

**Setup** (Before demo):
1. Start backend: `uvicorn main:app --reload`
2. Open Flutter app on emulator/device
3. Have Telegram app open on another device/window

**Script**:

> "MapSumbong is a civic engagement platform that lets residents report local issues—potholes, broken streetlights, flooded roads—directly to their barangay.
>
> **Demo 1 - Mobile App (connected)**
> - [Open app, login, create report via UI]
> - "Residents can report issues via our mobile app with photos and GPS location."
> - [Chat with AI]
> - "The AI analyzes each report for severity and categorizes it for the barangay team."
>
> **Demo 2 - Offline Access (no internet)**
> - [Show "Warning: Offline" banner]
> - "For residents without constant internet access, we provide Telegram and SMS channels."
> - [Switch to Telegram, send message to bot]
> - [Show bot response]
> - "Same AI analysis, same backend processing—just different entry points."
>
> **Demo 3 - Admin View (Supabase)**
> - [Open Supabase dashboard]
> - "Barangay officials can see all reports, their status, and analytics in real-time."
>
> **Closing**:
> - "By bridging digital and non-digital communication, MapSumbong makes civic engagement accessible to everyone."

---

## Part 7: Production Deployment Checklist

Before launching to real users:
- [ ] Database RLS policies enabled (Supabase → Settings → Auth)
- [ ] Service key rotated and stored securely
- [ ] Telegram webhook secret verified
- [ ] SMS gateway configured (if using)
- [ ] Error monitoring set up (Sentry, DataDog, etc.)
- [ ] Rate limiting configured (60 req/min per IP)
- [ ] HTTPS enforced
- [ ] CORS origins restricted to your domain
- [ ] Logging enabled and monitored
- [ ] Backup strategy documented
- [ ] Incident response plan prepared

See [DEPLOYMENT_CHECKLIST.md](../DEPLOYMENT_CHECKLIST.md) for detailed checklist.

---

## Next Steps

- **Mobile**: Flutter tests in CI/CD pipeline (GitHub Actions)
- **Backend**: SMS integration for feature phone support
- **Analytics**: Usage dashboard for barangay officials
- **Scaling**: Migrate from SQLite to PostgreSQL, add caching layer

---

**Questions?** Check logs in `logs/` directory or review [API_DOCUMENTATION.md](../docs/API_DOCUMENTATION.md).
