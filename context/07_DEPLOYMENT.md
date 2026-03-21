# MapSumbong Deployment Guide

Production deployment to free tier services.

## Overview

- **Database:** Supabase (free tier)
- **Backend:** Render.com (free tier)
- **Dashboard:** Vercel (free tier)
- **Mobile App:** Build APK locally

## 1. Database Deployment (Supabase)

### Already Completed

If you followed 01_DATABASE_SCHEMA.md, your database is already deployed.

### Verify

1. Go to https://supabase.com
2. Open your project
3. Check Database → Tables (should see users, reports, audit_log, clusters)
4. Check Storage → Buckets (should have photos bucket)

## 2. Backend Deployment (Render.com)

### Prerequisites

- GitHub account
- Backend code pushed to GitHub

### Steps

**1. Push Backend to GitHub**

```bash
cd mapsumbong-backend

# Initialize git if not already done
git init
git add .
git commit -m "Initial backend commit"

# Create repo on GitHub, then:
git remote add origin https://github.com/yourusername/mapsumbong-backend.git
git push -u origin main
```

**2. Deploy to Render**

1. Go to https://render.com
2. Sign up with GitHub
3. Click "New +" → "Web Service"
4. Connect your GitHub repo
5. Configure:
   - **Name:** mapsumbong-backend
   - **Region:** Singapore (closest to Philippines)
   - **Branch:** main
   - **Build Command:** `pip install -r requirements.txt`
   - **Start Command:** `uvicorn main:app --host 0.0.0.0 --port $PORT`

**3. Add Environment Variables**

In Render dashboard → Environment:

```
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_SERVICE_KEY=eyJ...
SUPABASE_ANON_KEY=eyJ...
ANTHROPIC_API_KEY=sk-ant-api03-...
OPENAI_API_KEY=sk-...
TELEGRAM_BOT_TOKEN=123456:ABC...
ENVIRONMENT=production
```

**4. Deploy**

- Click "Create Web Service"
- Wait 5-10 minutes for deployment
- Copy the URL (e.g., `https://mapsumbong-backend.onrender.com`)

**5. Test**

```bash
curl https://mapsumbong-backend.onrender.com/
# Should return: {"status": "healthy", ...}
```

**6. Update Telegram Webhook**

```bash
curl -X POST https://api.telegram.org/bot<YOUR_TOKEN>/setWebhook \
  -d url=https://mapsumbong-backend.onrender.com/telegram/webhook
```

## 3. Dashboard Deployment (Vercel)

### Prerequisites

- Dashboard code pushed to GitHub

### Steps

**1. Push Dashboard to GitHub**

```bash
cd mapsumbong-dashboard

git init
git add .
git commit -m "Initial dashboard commit"
git remote add origin https://github.com/yourusername/mapsumbong-dashboard.git
git push -u origin main
```

**2. Deploy to Vercel**

1. Go to https://vercel.com
2. Sign up with GitHub
3. Click "New Project"
4. Import `mapsumbong-dashboard` repo
5. Configure:
   - **Framework Preset:** Create React App
   - **Build Command:** `npm run build`
   - **Output Directory:** `build`

**3. Add Environment Variables**

```
REACT_APP_SUPABASE_URL=https://xxxxx.supabase.co
REACT_APP_SUPABASE_ANON_KEY=eyJ...
REACT_APP_BACKEND_URL=https://mapsumbong-backend.onrender.com
```

**4. Deploy**

- Click "Deploy"
- Wait 2-3 minutes
- Copy the URL (e.g., `https://mapsumbong-dashboard.vercel.app`)

**5. Test**

Open the URL in browser. You should see the dashboard.

## 4. Mobile App Build (APK)

### Build APK

```bash
cd mapsumbong
flutter build apk --release
```

APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

### Update Backend URL

Before building, update `.env`:

```bash
BACKEND_URL=https://mapsumbong-backend.onrender.com
```

Then rebuild:

```bash
flutter clean
flutter build apk --release
```

### Distribute APK

**Option 1: Google Drive**
1. Upload APK to Google Drive
2. Share link with residents

**Option 2: Direct Download**
1. Upload to GitHub Releases
2. Share download link

**Option 3: Firebase App Distribution (Free)**
1. Go to https://console.firebase.google.com
2. Create project
3. Enable App Distribution
4. Upload APK
5. Share download link

## 5. Production Checklist

### Security

- [ ] Environment variables set (no secrets in code)
- [ ] CORS configured in backend (only allow dashboard domain)
- [ ] RLS policies enabled on all Supabase tables
- [ ] API rate limiting enabled

### Backend

- [ ] Health check endpoint working
- [ ] All API endpoints returning correct responses
- [ ] Claude API calls working
- [ ] Telegram webhook receiving messages
- [ ] Logs visible in Render dashboard

### Dashboard

- [ ] Map loads with OpenStreetMap tiles
- [ ] Real-time updates working (Supabase Realtime)
- [ ] Reports display on map
- [ ] Status updates work
- [ ] Responsive on mobile browsers

### Mobile App

- [ ] APK installs on Android device
- [ ] Chat interface works
- [ ] Messages send to backend
- [ ] Chatbot responses appear
- [ ] Photo upload works

### Database

- [ ] All tables created
- [ ] RLS policies active
- [ ] Realtime enabled
- [ ] Storage bucket configured

## 6. Monitoring

### Backend Logs (Render)

```
1. Go to Render dashboard
2. Click on your service
3. Click "Logs" tab
4. Monitor for errors
```

### Database Metrics (Supabase)

```
1. Go to Supabase dashboard
2. Click "Reports" section
3. Monitor database size, connections
```

### Error Tracking

Add basic error logging to backend:

```python
# main.py
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@app.middleware("http")
async def log_requests(request, call_next):
    logger.info(f"{request.method} {request.url}")
    response = await call_next(request)
    logger.info(f"Status: {response.status_code}")
    return response
```

## 7. Free Tier Limits

### Supabase Free Tier
- 500MB database
- 1GB storage
- 2GB bandwidth/month
- Good for 5-10 barangays

### Render Free Tier
- 512MB RAM
- Sleeps after 15 min inactivity
- 750 hours/month (enough for demo)
- Restart takes ~30 seconds

### Vercel Free Tier
- Unlimited bandwidth
- 100GB build time/month
- Perfect for static dashboard

## 8. Domain Setup (Optional)

### Buy Domain (~₱150/year)

1. Go to https://namecheap.com
2. Search for domain (e.g., mapsumbong.site)
3. Purchase (~$2.88/year for .site)

### Configure DNS

**For Dashboard:**
1. Vercel → Settings → Domains
2. Add custom domain
3. Follow DNS instructions

**For Backend:**
1. Render → Settings → Custom Domain
2. Add domain
3. Follow DNS instructions

## 9. Rollback Plan

### If deployment fails:

**Backend:**
1. Go to Render → Deploys
2. Click "Redeploy" on last working version

**Dashboard:**
1. Go to Vercel → Deployments
2. Click "..." → "Promote to Production" on working version

**Database:**
1. Supabase → Settings → Backups
2. Restore from daily backup

## 10. Production Testing

### End-to-End Test

```bash
# 1. Send Telegram message
"May baha sa gate ng school"

# 2. Check backend logs (Render)
# Should see webhook received

# 3. Open dashboard
# Should see new pin on map

# 4. Update status
# Should trigger notification

# 5. Check Supabase
# Report should be in database
```

## Cost Estimate

| Service | Free Tier | Paid Upgrade |
|---------|-----------|--------------|
| Supabase | ✅ Free | $25/month (Pro) |
| Render | ✅ Free | $7/month (Standard) |
| Vercel | ✅ Free | $20/month (Pro) |
| Claude API | ~₱100 demo usage | Pay per use |
| Domain | - | ₱150/year |
| **Total** | **₱100-250** | **₱1,800+/month** |

## Next Steps

1. ✅ Everything deployed
2. → Read 08_TESTING.md for testing and troubleshooting
3. → Seed demo data
4. → Prepare live demo

---

**Congratulations!** MapSumbong is now live in production! 🎉