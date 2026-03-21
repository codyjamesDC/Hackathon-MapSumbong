import uuid
import json
import os

import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

load_dotenv()

import google.generativeai as genai
from prompts import (
    get_chatbot_system_prompt,
    get_extraction_system_prompt,
    build_extraction_prompt,
)

# Import routers
from routes import reports, telegram

# Initialize Gemini models
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

chat_model = genai.GenerativeModel(
    "models/gemini-2.5-flash",
    system_instruction=get_chatbot_system_prompt(),
)
extraction_model = genai.GenerativeModel(
    "models/gemini-2.5-flash",
    system_instruction=get_extraction_system_prompt(),
)

# In-memory session store  {session_id: [{"role": ..., "parts": [...]}]}
sessions: dict[str, list] = {}

# Create FastAPI app
app = FastAPI(
    title="MapSumbong API",
    description="Backend API for disaster reporting system",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production: restrict to your dashboard domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(reports.router, tags=["reports"])
app.include_router(telegram.router, prefix="/telegram", tags=["telegram"])


# ── Health checks ──────────────────────────────────────────────────────────────
@app.get("/")
def health_check():
    return {
        "status": "healthy",
        "service": "MapSumbong Backend",
        "version": "1.0.0",
        "environment": os.getenv("ENVIRONMENT", "development"),
    }


@app.get("/health")
def detailed_health():
    return {
        "status": "healthy",
        "services": {
            "database": "connected",
            "gemini_api": "configured" if os.getenv("GEMINI_API_KEY") else "not_configured",
            "whisper_api": "configured" if os.getenv("OPENAI_API_KEY") else "not_configured",
        },
        "environment": os.getenv("ENVIRONMENT", "development"),
    }


# ── Main chat endpoint ─────────────────────────────────────────────────────────
@app.post("/process-message")
async def process_message(payload: dict):
    """
    Receives a user message, maintains conversation history per session,
    returns the AI response + structured extraction when the report is complete.

    Payload:
        message (str): The user's message
        session_id (str, optional): Existing session ID. Omit to start a new session.

    Returns:
        {
            success: bool,
            session_id: str,
            response: str,
            is_complete: bool,
            report_data: dict | null
        }
    """
    try:
        user_message = payload.get("message", "").strip()
        session_id = payload.get("session_id") or str(uuid.uuid4())

        if not user_message:
            raise HTTPException(status_code=400, detail="Message is required")

        if session_id not in sessions:
            sessions[session_id] = []

        history = sessions[session_id]

        # Send to Gemini with full history
        chat = chat_model.start_chat(history=history)
        try:
            response = chat.send_message(user_message)
        except Exception as gemini_err:
            err_str = str(gemini_err)
            if "429" in err_str or "quota" in err_str.lower():
                import re
                import asyncio as _asyncio
                match = re.search(r"seconds:\s*(\d+)", err_str)
                wait = int(match.group(1)) + 2 if match else 15
                await _asyncio.sleep(wait)
                response = chat.send_message(user_message)
            else:
                raise

        ai_reply = response.text

        # Update history
        history.append({"role": "user", "parts": [user_message]})
        history.append({"role": "model", "parts": [ai_reply]})
        sessions[session_id] = history

        # Attempt structured extraction once we have enough context
        report_data = None
        is_complete = False

        if len(history) >= 6:
            report_data, is_complete = await extract_report_data(history)

        return {
            "success": True,
            "session_id": session_id,
            "response": ai_reply,
            "is_complete": is_complete,
            "report_data": report_data,
        }

    except Exception as e:
        return {"success": False, "error": str(e)}


# ── Structured extraction ──────────────────────────────────────────────────────
async def extract_report_data(conversation_history: list) -> tuple[dict | None, bool]:
    """Extract structured JSON from the conversation. Returns (data, is_complete)."""
    try:
        extraction_prompt = build_extraction_prompt(conversation_history)
        response = extraction_model.generate_content(extraction_prompt)

        raw = response.text.strip()
        # Strip markdown code fences if present
        if raw.startswith("```"):
            raw = raw.split("```")[1]
            if raw.startswith("json"):
                raw = raw[4:]
        raw = raw.strip()

        data = json.loads(raw)
        is_complete = bool(data.get("is_complete", False))

        # Geocode if we have a location but no coordinates yet
        if data.get("location_text") and not data.get("latitude"):
            coords = await geocode_location(data["location_text"])
            if coords:
                data["latitude"] = coords["lat"]
                data["longitude"] = coords["lon"]

        if is_complete and not data.get("report_id"):
            data["report_id"] = f"RPT-{uuid.uuid4().hex[:8].upper()}"

        return data, is_complete

    except (json.JSONDecodeError, Exception):
        return None, False


# ── Nominatim geocoding ────────────────────────────────────────────────────────
async def geocode_location(location_text: str) -> dict | None:
    """Convert a landmark/address string to lat/lon via OpenStreetMap Nominatim."""
    try:
        query = f"{location_text}, Philippines"
        params = {"q": query, "format": "json", "limit": 1, "countrycodes": "ph"}
        headers = {"User-Agent": "MapSumbong/1.0 (hackathon project)"}

        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(
                "https://nominatim.openstreetmap.org/search",
                params=params,
                headers=headers,
            )
            results = resp.json()

        if results:
            return {
                "lat": float(results[0]["lat"]),
                "lon": float(results[0]["lon"]),
                "display_name": results[0].get("display_name", ""),
            }
        return None

    except Exception:
        return None


# ── Submit confirmed report to Supabase ───────────────────────────────────────
@app.post("/submit-report")
async def submit_report(payload: dict):
    """Save a confirmed structured report to Supabase."""
    try:
        from supabase import create_client

        supabase_url = os.getenv("SUPABASE_URL")
        supabase_key = os.getenv("SUPABASE_SERVICE_KEY")

        if not supabase_url or not supabase_key:
            raise HTTPException(status_code=500, detail="Supabase not configured")

        supabase = create_client(supabase_url, supabase_key)

        report = {
            "id": payload.get("report_id") or f"RPT-{uuid.uuid4().hex[:8].upper()}",
            "reporter_anonymous_id": payload.get("reporter_anonymous_id"),
            "issue_type": payload.get("issue_type", "other"),
            "description": payload.get("description", ""),
            "latitude": payload.get("latitude"),
            "longitude": payload.get("longitude"),
            "location_text": payload.get("location_text", ""),
            "urgency": payload.get("urgency", "medium"),
            "sdg_tag": payload.get("sdg_tag"),
            "status": "received",
            "barangay": payload.get("barangay", "unknown"),
            "photo_url": payload.get("photo_url"),
        }

        result = supabase.table("reports").insert(report).execute()

        return {
            "success": True,
            "report_id": report["id"],
            "message": f"Report {report['id']} saved successfully.",
        }

    except Exception as e:
        return {"success": False, "error": str(e)}


# ── Session management ─────────────────────────────────────────────────────────
@app.get("/session/{session_id}")
def get_session(session_id: str):
    history = sessions.get(session_id, [])
    return {"session_id": session_id, "history": history, "message_count": len(history)}


@app.delete("/session/{session_id}")
def clear_session(session_id: str):
    sessions.pop(session_id, None)
    return {"success": True, "message": f"Session {session_id} cleared."}


# ── Telegram webhook ───────────────────────────────────────────────────────────
@app.post("/telegram-webhook")
async def telegram_webhook(payload: dict):
    try:
        message = payload.get("message", {})
        chat_id = message.get("chat", {}).get("id")
        text = message.get("text", "")

        if not chat_id or not text:
            return {"ok": True}

        result = await process_message(
            {"message": text, "session_id": f"telegram_{chat_id}"}
        )

        bot_token = os.getenv("TELEGRAM_BOT_TOKEN")
        if bot_token and result.get("success"):
            async with httpx.AsyncClient() as client:
                await client.post(
                    f"https://api.telegram.org/bot{bot_token}/sendMessage",
                    json={
                        "chat_id": chat_id,
                        "text": result["response"],
                        "parse_mode": "Markdown",
                    },
                )

        return {"ok": True}

    except Exception as e:
        return {"ok": False, "error": str(e)}


# ── Debug helpers ──────────────────────────────────────────────────────────────
@app.get("/list-models")
def list_models():
    models = genai.list_models()
    available = [
        m.name for m in models if "generateContent" in m.supported_generation_methods
    ]
    return {"available_models": available}