# MapSumbong Context Documentation

This folder contains all technical documentation for building MapSumbong - an AI-powered disaster reporting system for Filipino communities.

## 📁 Documentation Structure

### Core Documents

1. **00_ARCHITECTURE.md** - System design, tech stack, and key decisions
2. **01_DATABASE_SCHEMA.md** - Complete database structure and RLS policies  
3. **02_API_REFERENCE.md** - All backend endpoints with examples
4. **03_BACKEND_GUIDE.md** - FastAPI implementation (Python)
5. **04_FLUTTER_GUIDE.md** - Mobile app implementation (Resident interface)
6. **05_DASHBOARD_GUIDE.md** - Web admin dashboard (React)
7. **06_TELEGRAM_BOT.md** - Telegram integration
8. **07_DEPLOYMENT.md** - Production deployment steps
9. **08_TESTING.md** - Testing strategies and troubleshooting

## 🎯 Quick Start

**New to the project?** Read in this order:
1. 00_ARCHITECTURE.md - Understand the system
2. 01_DATABASE_SCHEMA.md - Set up database
3. Choose your component and read its guide

**Building a specific component?**
- Backend → 03_BACKEND_GUIDE.md
- Mobile App → 04_FLUTTER_GUIDE.md  
- Admin Dashboard → 05_DASHBOARD_GUIDE.md
- Telegram Bot → 06_TELEGRAM_BOT.md

**Deploying?** → 07_DEPLOYMENT.md

**Debugging?** → 08_TESTING.md

## 🤖 Using with AI Tools

### GitHub Copilot
```
@workspace /explain How does cluster detection work? Use .context/02_API_REFERENCE.md
```

### Claude
```
"Check .context/03_BACKEND_GUIDE.md and help me implement the Claude service"
```

### Cursor
The AI will automatically reference these files when you ask questions about the project.

## 📋 Architecture Overview

```
┌─────────────────────────────────────────────┐
│              USER LAYER                      │
├─────────────────────────────────────────────┤
│  Residents                │  Officials       │
│  • Flutter App            │  • Web Dashboard │
│  • Telegram Bot           │  (React)         │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│           BACKEND (FastAPI)                  │
│  • Claude AI processing                      │
│  • Whisper transcription                     │
│  • Report management                         │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│        DATABASE (Supabase)                   │
│  • PostgreSQL + Realtime                     │
│  • Storage for photos                        │
└─────────────────────────────────────────────┘
```

## 🛠️ Tech Stack

**User Interface:**
- Flutter (Android app for residents)
- React + Tailwind (Web dashboard for officials)
- Telegram Bot API (Fallback channel)

**Backend:**
- FastAPI (Python)
- Claude API (Anthropic)
- OpenAI Whisper (Voice transcription)

**Database & Infrastructure:**
- Supabase (PostgreSQL + Realtime + Storage)
- OpenStreetMap + Nominatim (Free mapping)

**Deployment:**
- Render.com (Backend - free tier)
- Vercel (Dashboard - free tier)
- Supabase (Database - free tier)

**Total Budget:** ₱100-250 (Claude API usage only)

## 🔑 Key Features

### Resident Features
- Report issues via chat (Filipino language)
- Voice message support (transcribed automatically)
- Photo upload
- Anonymous reporting option
- Report tracking

### Official Features  
- Real-time map dashboard
- Color-coded urgency pins
- Incident queue management
- Status updates with resolution photos
- Analytics and reporting

### Accountability Features
- Deletion audit trail (public transparency)
- Automatic cluster detection (3+ reports in 500m)
- Resident confirmation of resolutions
- Anti-corruption by design

## 📝 Implementation Checklist

- [ ] Set up Supabase project and database
- [ ] Build FastAPI backend with Claude integration
- [ ] Create Flutter resident app
- [ ] Build React admin dashboard
- [ ] Implement Telegram bot
- [ ] Deploy to production
- [ ] Seed demo data
- [ ] Test end-to-end flow

## 🚀 Getting Started

1. **Prerequisites**: Install Flutter, Python 3.11+, Node.js
2. **Database**: Follow 01_DATABASE_SCHEMA.md
3. **Backend**: Follow 03_BACKEND_GUIDE.md
4. **Choose Interface**: 
   - Resident app → 04_FLUTTER_GUIDE.md
   - Admin dashboard → 05_DASHBOARD_GUIDE.md

## 💡 Pro Tips

- Read the architecture first to understand the big picture
- Follow implementation guides step-by-step
- Test each component individually before integration
- Use the API reference as your source of truth
- Check testing guide when debugging

## 🆘 Need Help?

1. Check the relevant guide first
2. Look in 08_TESTING.md for common issues
3. Search across all markdown files (Ctrl+F in VS Code)
4. Ask GitHub Copilot: `@workspace /explain [your question]`
5. Ask Claude with context: Upload the relevant .md file

---

**Ready to build?** Start with 00_ARCHITECTURE.md to understand the system! 🎉