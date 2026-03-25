"""
MapSumbong Day 3-4 Integration Script
Run: python scripts/pipeline_integration.py

Checks:
- 10 sample messages across Tagalog, Bisaya, Taglish, English
- Spam filter validation
- Multi-turn conversation with structured extraction
"""

import asyncio
import json

import httpx

DELAY = 13  # seconds between requests (free tier = 5 req/min = 12s apart)
BASE_URL = "http://localhost:8000"

# Color helpers
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
RESET = "\033[0m"
BOLD = "\033[1m"


def p(color, label, text):
    print(f"{color}{BOLD}[{label}]{RESET} {text}")


async def send_message(client, message, session_id=None):
    payload = {"message": message}
    if session_id:
        payload["session_id"] = session_id

    resp = await client.post(f"{BASE_URL}/process-message", json=payload, timeout=30)
    return resp.json()


async def run_full_conversation(client):
    print(f"\n{BOLD}{'=' * 60}{RESET}")
    print(f"{BOLD}TEST: Full multi-turn conversation (Tagalog){RESET}")
    print(f"{'=' * 60}")

    session_id = None
    turns = [
        "May baha sa aming kanto",
        "Sa tapat ng Jollibee sa Rizal Street, Brgy. San Isidro",
        "Halos tuhod na ang taas ng tubig, mabilis pa lumalaki",
    ]

    for i, msg in enumerate(turns):
        p(BLUE, f"Turn {i + 1}", f"User: {msg}")
        result = await send_message(client, msg, session_id)
        session_id = result.get("session_id")

        if result.get("success"):
            p(GREEN, "AI", result["response"][:120] + "...")
            if result.get("is_complete"):
                p(
                    GREEN,
                    "EXTRACTED",
                    json.dumps(result["report_data"], indent=2, ensure_ascii=False),
                )
                p(GREEN, "PASS", "Report successfully extracted!")
            else:
                p(YELLOW, "STATUS", f"Gathering info... (session: {session_id})")
        else:
            p(RED, "FAIL", result.get("error"))


async def run_spam_filter(client):
    print(f"\n{BOLD}{'=' * 60}{RESET}")
    print(f"{BOLD}TEST: Spam filter (should NOT create reports){RESET}")
    print(f"{'=' * 60}")

    spam_messages = [
        "lol wala lang",
        "kumain ka na ba?",
        "testing 1 2 3",
        "joke lang haha",
    ]

    for msg in spam_messages:
        result = await send_message(client, msg)
        p(BLUE, "INPUT", msg)
        if result.get("success"):
            ai_reply = result["response"]
            if not result.get("is_complete"):
                p(GREEN, "PASS", f"Spam rejected correctly. AI: {ai_reply[:80]}...")
            else:
                p(RED, "FAIL", "Spam got through as complete report!")
        else:
            err = str(result.get("error", ""))[:80]
            p(RED, "ERROR", err + "...")
        print()
        await asyncio.sleep(DELAY)


async def run_10_messages(client):
    print(f"\n{BOLD}{'=' * 60}{RESET}")
    print(f"{BOLD}TEST: 10 sample messages (3 languages){RESET}")
    print(f"{'=' * 60}")

    test_cases = [
        ("Tagalog", "May nasirang ilaw sa daan sa Brgy. Poblacion, hindi nag-iilaw gabi"),
        (
            "Tagalog",
            "Maraming basura sa tabi ng creek sa Barangay Sta. Cruz, matagal na hindi nako-kolekta",
        ),
        ("Tagalog", "Butas ang kalsada sa may entrance ng subdivision namin sa Brgy. Bagong Silang"),
        ("Bisaya", "Nag-baha ang among kanto sa Sitio Mahayag, Brgy. Poblacion"),
        ("Bisaya", "Naay nabugto nga wire sa kuryente sa Brgy. San Roque, delikado kaayo"),
        ("Bisaya", "Dili mo mahimong makaagi ang mga sakyanan sa dalan sa Brgy. Lawis tungod sa basura"),
        ("Taglish", "May water interruption sa aming area sa Brgy. San Jose, 2 days na walang tubig"),
        ("Taglish", "Yung streetlight sa Rizal Ave corner Quezon St. hindi na nag-ilaw, dark na kapag gabi"),
        ("English", "There's a large pothole on the main road near the elementary school in Brgy. Mabini"),
        (
            "English",
            "Flooding emergency at the low-lying area near the river in Barangay San Antonio, water rising fast",
        ),
    ]

    passed = 0
    for lang, msg in test_cases:
        result = await send_message(client, msg)
        p(BLUE, lang, msg[:70] + "...")

        if result.get("success"):
            p(GREEN, "AI", result["response"][:100] + "...")
            if result.get("report_data"):
                data = result["report_data"]
                p(
                    YELLOW,
                    "DATA",
                    f"type={data.get('issue_type')} urgency={data.get('urgency')} barangay={data.get('barangay')}",
                )
            passed += 1
        else:
            p(RED, "FAIL", result.get("error")[:80] + "...")
        print()
        await asyncio.sleep(DELAY)

    p(GREEN if passed == 10 else YELLOW, "RESULT", f"{passed}/10 messages processed successfully")


async def run_geocoding(client):
    print(f"\n{BOLD}{'=' * 60}{RESET}")
    print(f"{BOLD}TEST: Multi-turn with geocoding{RESET}")
    print(f"{'=' * 60}")

    session_id = None
    turns = [
        "May sunog sa aming kapitbahayan",
        "Sa Rizal Street, Los Banos, Laguna",
        "Malaki ang apoy, kailangan ng tulong ng BFP agad",
    ]

    for i, msg in enumerate(turns):
        result = await send_message(client, msg, session_id)
        session_id = result.get("session_id")
        p(BLUE, f"Turn {i + 1}", msg)

        if result.get("success"):
            p(GREEN, "AI", result["response"][:100] + "...")
            if result.get("report_data"):
                data = result["report_data"]
                lat = data.get("latitude")
                lon = data.get("longitude")
                if lat and lon:
                    p(GREEN, "GEOCODED", f"lat={lat}, lon={lon}")
                else:
                    p(YELLOW, "NO COORDS", "Nominatim did not return coordinates for this location")
        print()


async def main():
    print(f"\n{BOLD}MapSumbong Day 3-4 Integration Checks{RESET}")
    print(f"Testing against: {BASE_URL}\n")

    try:
        async with httpx.AsyncClient() as client:
            health = await client.get(f"{BASE_URL}/", timeout=5)
            p(GREEN, "SERVER", f"Backend is running: {health.json()}")
    except Exception:
        p(RED, "ERROR", f"Backend not running at {BASE_URL}. Start with: uvicorn main:app --reload")
        return

    async with httpx.AsyncClient() as client:
        await run_10_messages(client)
        await run_spam_filter(client)
        await run_full_conversation(client)
        await run_geocoding(client)

    print(f"\n{BOLD}{'=' * 60}{RESET}")
    print(f"{BOLD}All checks complete.{RESET}")
    print(f"{'=' * 60}\n")


if __name__ == "__main__":
    asyncio.run(main())
