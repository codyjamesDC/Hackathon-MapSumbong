# MapSumbong

## Description
MapSumbong is a community reporting platform for local incidents such as flooding, road damage, blocked drainage, power outages, and other neighborhood concerns. It combines a Flutter mobile app, a FastAPI backend, AI-assisted triage, and messaging channels so residents can report issues even when they are not using the app.

## What it does
- Lets residents submit incident reports with text, location, and optional media.
- Uses AI-assisted follow-up prompts to collect clearer and more complete report details.
- Stores reports in a central database for tracking and response.
- Supports Telegram-based reporting as an alternative access channel.
- Includes security hardening, structured logging, and environment validation for safer operations.

## How it works
1. A user sends an incident report through the mobile app or Telegram.
2. The backend receives the report request and validates the payload.
3. AI processing helps classify the concern and ask clarifying questions when needed.
4. The report is saved to the backend data store.
5. The app can then show report details, status, and updates.

High-level flow:

`Mobile App / Telegram -> FastAPI Backend -> AI + Geocoding Services -> Database -> Status/Response`

## How the app works
1. User signs in and opens the report flow.
2. User enters what happened and where it happened.
3. User can attach photos or voice input (depending on channel/feature support).
4. The app (or bot) sends data to the backend.
5. The backend returns confirmation and report metadata.
6. User can monitor report progress from the app interface.

## How to run it

### Prerequisites
- Python 3.10+ (recommended for backend)
- Flutter SDK (for mobile app)
- A configured backend `.env` file based on `.env.example`

### 1) Run the backend
```bash
cd backend
python -m venv venv
# Windows PowerShell
./venv/Scripts/Activate.ps1

pip install -r requirements.txt
copy .env.example .env
# Edit .env and set required values (Supabase, Gemini, JWT, etc.)

python main.py
```

Backend default URL: `http://0.0.0.0:8000`

### 2) Run the mobile app
```bash
cd mobile
flutter pub get
flutter run
```

### 3) Optional: run frontend web client
```bash
cd frontend
npm install
npm run dev
```

### 4) Validate setup
- Backend health/boot logs should show successful environment validation.
- Mobile app should connect to the backend base URL.
- Telegram flow can be tested if bot credentials are configured.

## Documentation
- [Quick Start](QUICKSTART.md)
- [Complete Session Recap](COMPLETE_SESSION_RECAP.md)
- [Backend Demo Setup Guide](backend/docs/DEMO_SETUP_GUIDE.md)
- [Backend SMS Integration Guide](backend/docs/SMS_INTEGRATION_GUIDE.md)
