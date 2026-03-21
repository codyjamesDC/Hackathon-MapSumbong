# MapSumbong Architecture

## System Overview

MapSumbong is an AI-powered disaster reporting system that allows Filipino residents to report community issues via mobile app or Telegram, while barangay officials monitor and respond through a web dashboard.

## Architecture Diagram

```
┌───────────────────────────────────────────────────────────────────┐
│                         USER LAYER                                 │
├───────────────────────────────────────────────────────────────────┤
│                                                                    │
│  RESIDENTS (Report Issues)          OFFICIALS (Monitor & Respond)  │
│  ┌─────────────────────┐            ┌──────────────────────┐     │
│  │  Flutter App        │            │  Web Dashboard       │     │
│  │  (Android)          │            │  (React + Leaflet)   │     │
│  │  • Chat interface   │            │  • Live map view     │     │
│  │  • Photo upload     │            │  • Incident queue    │     │
│  │  • OTP login        │            │  • Status updates    │     │
│  └─────────────────────┘            │  • Analytics         │     │
│           │                          └──────────────────────┘     │
│           │                                     │                  │
│  ┌─────────────────────┐                       │                  │
│  │  Telegram Bot       │                       │                  │
│  │  (Fallback)         │                       │                  │
│  │  • Text messages    │                       │                  │
│  │  • Voice notes      │                       │                  │
│  └─────────────────────┘                       │                  │
│           │                                     │                  │
└───────────┼─────────────────────────────────────┼──────────────────┘
            │                                     │
            └──────────────┬──────────────────────┘
                          │
                          ▼
┌───────────────────────────────────────────────────────────────────┐
│                      BACKEND LAYER                                 │
├───────────────────────────────────────────────────────────────────┤
│                                                                    │
│  FastAPI Server (Python)                                          │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │  Routes:                                                  │    │
│  │  • POST /process-message    (Claude AI processing)       │    │
│  │  • POST /transcribe         (Whisper voice-to-text)      │    │
│  │  • POST /telegram-webhook   (Telegram integration)       │    │
│  │  • GET  /reports            (Fetch reports)              │    │
│  │  • PATCH /reports/:id       (Update status)              │    │
│  │  • DELETE /reports/:id      (Soft delete + audit)        │    │
│  │  • GET  /clusters           (Cluster detection)          │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                    │
│  Services:                                                        │
│  • Claude Service    (Extract issue data, respond in Filipino)   │
│  • Whisper Service   (Transcribe voice messages)                 │
│  • Geocoding Service (Location text → coordinates)               │
│  • Cluster Service   (Detect 3+ reports in 500m radius)          │
│                                                                    │
└───────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌───────────────────────────────────────────────────────────────────┐
│                       DATA LAYER                                   │
├───────────────────────────────────────────────────────────────────┤
│                                                                    │
│  Supabase (PostgreSQL + Realtime + Storage + Auth)               │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │  Tables:                                                  │    │
│  │  • users         (Residents and officials)               │    │
│  │  • reports       (All incident reports)                  │    │
│  │  • audit_log     (Deletion trail)                        │    │
│  │  • clusters      (Detected incident clusters)            │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                    │
│  Features:                                                        │
│  • Row-Level Security (RLS) policies                             │
│  • Realtime subscriptions (live dashboard updates)               │
│  • Storage buckets (report photos)                               │
│  • OTP authentication (for residents)                            │
│                                                                    │
└───────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌───────────────────────────────────────────────────────────────────┐
│                      EXTERNAL SERVICES                             │
├───────────────────────────────────────────────────────────────────┤
│                                                                    │
│  • Claude API (Anthropic)      - Message processing & extraction  │
│  • OpenAI Whisper              - Voice transcription              │
│  • OpenStreetMap Nominatim     - Geocoding (free)                │
│  • Telegram Bot API            - Messaging platform               │
│                                                                    │
└───────────────────────────────────────────────────────────────────┘
```

## Technology Stack

### Frontend

**Resident Interface: Flutter (Android)**
- Framework: Flutter 3.x (Dart)
- State Management: Provider
- Routing: GoRouter
- Key Packages:
  - `supabase_flutter` - Database & Auth
  - `http` - API calls
  - `image_picker` - Photo upload
  - `flutter_dotenv` - Environment variables

**Official Interface: React Web Dashboard**
- Framework: React 18
- Styling: Tailwind CSS
- Maps: Leaflet.js + react-leaflet
- Key Packages:
  - `@supabase/supabase-js` - Database & Realtime
  - `leaflet` - OpenStreetMap integration
  - `recharts` - Analytics charts

### Backend

**API Server: FastAPI (Python)**
- Framework: FastAPI
- Runtime: Uvicorn (ASGI)
- Key Libraries:
  - `anthropic` - Claude API client
  - `openai` - Whisper API
  - `supabase` - Database client
  - `httpx` - Async HTTP client
  - `python-multipart` - File uploads

### Database & Infrastructure

**Database: Supabase**
- PostgreSQL 15
- Realtime (WebSocket subscriptions)
- Storage (S3-compatible)
- Auth (OTP via SMS/Email)

**Maps: OpenStreetMap**
- Free tile server
- Nominatim geocoding API
- No API key required

### Deployment

- **Backend**: Render.com (free tier, 512MB RAM)
- **Dashboard**: Vercel (free tier, unlimited bandwidth)
- **Database**: Supabase (free tier, 500MB)
- **Domain**: Optional (~₱150/year for .site domain)

## Key Design Decisions

### 1. Web Dashboard for Officials (Not Mobile App)

**Why:**
- ✅ Officials work from desktop computers in barangay halls
- ✅ No installation needed - just open a URL
- ✅ Better for data entry (larger screens, full keyboards)
- ✅ Multiple officials can view same dashboard simultaneously
- ✅ Easier to project in meetings
- ✅ Faster development (one Flutter app instead of two account types)

**Trade-offs:**
- ❌ Officials can't easily access from mobile devices
- ✅ But officials typically have desktops/laptops at work

### 2. Telegram as Fallback Channel

**Why:**
- ✅ Universal - everyone in Philippines already has Telegram
- ✅ Zero friction - no app installation
- ✅ Voice message support built-in
- ✅ Works on slow internet connections
- ✅ Free (no SMS costs)

**Trade-offs:**
- ❌ Less control over UX compared to native app
- ✅ But perfect for users who can't/won't install the Flutter app

### 3. OpenStreetMap Instead of Google Maps

**Why:**
- ✅ Completely free (no API key, no billing)
- ✅ No quota limits
- ✅ Sufficient coverage for Philippines
- ✅ Nominatim geocoding also free

**Trade-offs:**
- ❌ Slightly less detailed than Google Maps
- ❌ Geocoding might be less accurate
- ✅ But perfectly adequate for barangay-level mapping
- ✅ Fits ₱0 budget constraint

### 4. Supabase Instead of Firebase

**Why:**
- ✅ PostgreSQL (familiar SQL, better for complex queries)
- ✅ Row-Level Security (fine-grained access control)
- ✅ Realtime subscriptions (live dashboard updates)
- ✅ Free tier very generous (500MB DB, 1GB storage)
- ✅ Better suited for data-heavy applications

**Trade-offs:**
- ❌ Slightly more complex setup than Firebase
- ✅ But better long-term scalability

### 5. Claude API Instead of OpenAI GPT

**Why:**
- ✅ Better at understanding Filipino/Taglish
- ✅ More reliable structured output extraction
- ✅ Longer context window (useful for chat history)
- ✅ Better at following system prompts

**Trade-offs:**
- ❌ Slightly more expensive per token
- ✅ But higher quality results mean fewer retries

## Data Flow Examples

### Example 1: Resident Reports via Flutter App

```
1. User opens Flutter app
2. User types: "May baha sa may gate ng elementary school"
3. App → Backend POST /process-message
4. Backend → Claude API (extract issue data)
5. Claude returns:
   {
     "issue_type": "flood",
     "location_text": "elementary school gate",
     "urgency": "high",
     "sdg_tag": "SDG 11"
   }
6. Backend → Nominatim (geocode location)
7. Nominatim returns: {lat: 14.6042, lng: 120.9822}
8. Backend → Supabase (save report)
9. Supabase Realtime → Dashboard (new pin appears)
10. Backend → User (chatbot response in Filipino)
11. App displays: "Salamat! Report ID: VM-2026-0042"
```

### Example 2: Telegram Voice Report

```
1. User sends voice note to @mapsumbong_bot
2. Telegram → Backend POST /telegram-webhook
3. Backend downloads audio file
4. Backend → Whisper API (transcribe)
5. Whisper returns: "May basura sa kanto ng Rizal Street"
6. Continue same flow as Example 1 from step 4
7. Backend → Telegram (send chatbot response)
```

### Example 3: Official Updates Status

```
1. Official opens web dashboard
2. Dashboard → Supabase (fetch all reports)
3. Official clicks report pin on map
4. Official fills resolution form + uploads photo
5. Official clicks "Mark as Resolved"
6. Dashboard → Backend PATCH /reports/:id
7. Backend → Supabase (update status)
8. Backend → Supabase audit_log (log action)
9. Backend → Push notification to resident
10. Supabase Realtime → Dashboard (pin updates)
```

### Example 4: Cluster Detection

```
1. 3 reports of flooding saved within 2 hours
2. All reports within 500m radius
3. Backend cluster detection runs
4. Backend → Supabase clusters table (create entry)
5. Backend → Telegram API (send alert to barangay captain)
6. Dashboard shows cluster ring on map
```

## Security Architecture

### Authentication

**Residents:**
- OTP via Supabase Auth (phone number)
- Anonymous IDs for privacy
- Optional display names

**Officials:**
- Username + password (issued credentials)
- Session-based authentication
- Role-based access control

### Privacy

**Phone Number Hashing:**
```sql
-- Never store raw phone numbers
phone_hash = SHA256(phone_number)
```

**Anonymous Reporting:**
```sql
-- Reports linked to anonymous IDs, not phone numbers
reporter_anonymous_id = "ANON-12345"
```

**Public Data:**
- Report type, location (barangay-level), timestamp
- NO personal information exposed

### Row-Level Security (RLS)

**Residents can only see their own reports:**
```sql
CREATE POLICY "Residents see own reports"
ON reports FOR SELECT
USING (reporter_anonymous_id = current_user_anonymous_id);
```

**Officials can see all reports:**
```sql
CREATE POLICY "Officials see all reports"
ON reports FOR SELECT
USING (is_official(auth.uid()));
```

### Audit Trail

**Every deletion is logged:**
```sql
CREATE TRIGGER on_report_delete
  AFTER UPDATE ON reports
  WHEN (NEW.is_deleted = true)
  INSERT INTO audit_log (report_id, action, performed_by);
```

**Deleted reports remain in database:**
- Soft delete only (`is_deleted = true`)
- Accessible to higher authorities
- Public transparency feed shows deletions

## Scalability Considerations

### Current Architecture (Free Tier)

**Limits:**
- Supabase: 500MB database, 1GB storage
- Render: 512MB RAM, sleeps after 15min inactivity
- Claude API: Rate limited to 50 requests/min

**Capacity:**
- ~10,000 reports (at ~50KB each)
- ~2,000 photos (at ~500KB each)
- ~100 concurrent users
- **Sufficient for 5-10 barangays**

### Scaling Strategy

**Phase 1: Optimize Free Tier**
- Compress images before upload
- Cache geocoding results
- Use background tasks for cluster detection
- → Supports 10-20 barangays

**Phase 2: Upgrade Database**
- Supabase Pro ($25/month)
- 8GB database, 100GB storage
- → Supports 50+ barangays

**Phase 3: Dedicated Backend**
- Render Standard ($7/month)
- 1GB RAM, no sleep
- → Better response times

**Phase 4: Multi-Region**
- Deploy backend in multiple regions
- CDN for dashboard
- → National scale

## Budget Breakdown

| Service | Free Tier | Cost |
|---------|-----------|------|
| Supabase | 500MB DB, 1GB storage | ₱0 |
| Render.com | 512MB RAM | ₱0 |
| Vercel | Unlimited bandwidth | ₱0 |
| Claude API | Pay-per-use | ~₱100 (demo usage) |
| OpenStreetMap | Unlimited | ₱0 |
| Telegram Bot | Unlimited | ₱0 |
| Domain (optional) | - | ₱150/year |
| **TOTAL** | | **₱100-250** |

## Performance Targets

- Report submission: < 3 seconds
- Dashboard load: < 2 seconds  
- Real-time update latency: < 1 second
- Geocoding: < 500ms (cached)
- Claude API: < 2 seconds
- Whisper transcription: < 5 seconds

## Error Handling Strategy

**Backend:**
- All API calls wrapped in try-catch
- Graceful fallbacks (default coordinates if geocoding fails)
- Retry logic for transient failures

**Frontend:**
- Offline queue for reports (retry when online)
- Loading indicators during API calls
- User-friendly error messages in Filipino

**Database:**
- Foreign key constraints
- Check constraints on enums
- Automatic timestamps

## Monitoring & Logging

**Production Monitoring:**
- Render logs for backend errors
- Vercel analytics for dashboard traffic
- Supabase dashboard for database metrics

**Development:**
- `console.log` for debugging
- FastAPI automatic docs at `/docs`
- Postman for API testing

## Disaster Recovery

**Data Backup:**
- Supabase automatic daily backups
- Point-in-time recovery (7 days)

**Code Backup:**
- Git repository (GitHub)
- All code version controlled

**Recovery Plan:**
1. Restore database from Supabase backup
2. Redeploy backend from Git
3. Redeploy dashboard from Git
4. Test critical flows

## Future Enhancements (Post-MVP)

1. **SMS Notifications** (Semaphore API - ₱500 credit)
2. **More Languages** (Ilocano, Cebuano)
3. **Photo Analysis** (Claude Vision for flood depth detection)
4. **Disaster Mode** (PAGASA integration for typhoon alerts)
5. **iOS App** (Extend Flutter to iOS)
6. **PWA Support** (Dashboard installable on mobile)
7. **Advanced Analytics** (ML for incident prediction)
8. **Integration with LGU systems** (DILG reporting)

---

**Next Steps:** Read 01_DATABASE_SCHEMA.md to set up the database structure.