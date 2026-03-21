# MapSumbong Database Schema

Complete PostgreSQL schema for Supabase, including tables, indexes, RLS policies, and triggers.

## Setup Instructions

1. Go to supabase.com → Create new project
2. Name: `mapsumbong`
3. Choose region closest to Philippines (Singapore)
4. Copy Project URL and API keys
5. Go to SQL Editor
6. Run all SQL statements below in order

---

## Tables

### Table: users

Stores both residents and officials with privacy features.

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_hash TEXT UNIQUE,  -- SHA256 hash of phone number (residents only)
  anonymous_id TEXT UNIQUE NOT NULL,  -- Format: ANON-XXXXX
  account_type TEXT NOT NULL CHECK (account_type IN ('resident', 'official')),
  display_name TEXT,
  is_anonymous BOOLEAN DEFAULT true,
  barangay TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_users_phone_hash ON users(phone_hash);
CREATE INDEX idx_users_anonymous_id ON users(anonymous_id);
CREATE INDEX idx_users_account_type ON users(account_type);

-- Comments
COMMENT ON TABLE users IS 'Stores residents and barangay officials';
COMMENT ON COLUMN users.phone_hash IS 'SHA256 hash of phone number for privacy';
COMMENT ON COLUMN users.anonymous_id IS 'Public-facing anonymous identifier';
COMMENT ON COLUMN users.is_anonymous IS 'Whether to show display name publicly';
```

**Sample Data:**
```sql
INSERT INTO users (anonymous_id, account_type, display_name, is_anonymous, phone_hash) VALUES
  ('ANON-12345', 'resident', 'Juan Dela Cruz', false, 'hash_of_09171234567'),
  ('ANON-67890', 'resident', NULL, true, 'hash_of_09189876543'),
  ('OFFICIAL-001', 'official', 'Barangay Captain', false, NULL);
```

---

### Table: reports

Main table for all incident reports.

```sql
CREATE TABLE reports (
  id TEXT PRIMARY KEY,  -- Format: VM-2026-XXXX (Valenzuela Municipality - Year - Sequence)
  reporter_anonymous_id TEXT NOT NULL REFERENCES users(anonymous_id) ON DELETE RESTRICT,
  
  -- Report content
  issue_type TEXT NOT NULL CHECK (issue_type IN (
    'flood', 'waste', 'road', 'power', 'water', 'emergency', 'fire', 'crime', 'other'
  )),
  description TEXT NOT NULL,
  photo_url TEXT,
  
  -- Location
  latitude FLOAT NOT NULL,
  longitude FLOAT NOT NULL,
  location_text TEXT,  -- Human-readable location
  barangay TEXT NOT NULL,
  
  -- Classification
  urgency TEXT NOT NULL CHECK (urgency IN ('critical', 'high', 'medium', 'low')) DEFAULT 'medium',
  sdg_tag TEXT,  -- SDG 3, SDG 6, SDG 11, etc.
  
  -- Status tracking
  status TEXT NOT NULL DEFAULT 'received' CHECK (status IN (
    'received', 'in_progress', 'repair_scheduled', 'resolved', 'reopened'
  )),
  
  -- Resolution
  resolution_photo_url TEXT,
  resolution_note TEXT,
  resident_confirmed BOOLEAN,  -- Did resident confirm resolution?
  resolved_at TIMESTAMPTZ,
  resolved_by TEXT,
  
  -- Soft delete
  is_deleted BOOLEAN DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by TEXT,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_reports_reporter ON reports(reporter_anonymous_id);
CREATE INDEX idx_reports_status ON reports(status);
CREATE INDEX idx_reports_urgency ON reports(urgency);
CREATE INDEX idx_reports_barangay ON reports(barangay);
CREATE INDEX idx_reports_issue_type ON reports(issue_type);
CREATE INDEX idx_reports_created_at ON reports(created_at DESC);
CREATE INDEX idx_reports_is_deleted ON reports(is_deleted);

-- Geospatial index for cluster detection
CREATE INDEX idx_reports_location ON reports USING GIST (
  ll_to_earth(latitude, longitude)
);

-- Comments
COMMENT ON TABLE reports IS 'All incident reports from residents';
COMMENT ON COLUMN reports.id IS 'Unique report ID shown to users';
COMMENT ON COLUMN reports.urgency IS 'Critical = life-threatening, High = urgent, Medium = important, Low = maintenance';
COMMENT ON COLUMN reports.is_deleted IS 'Soft delete flag - deleted reports remain in DB';
```

**Sample Data:**
```sql
INSERT INTO reports (
  id, reporter_anonymous_id, issue_type, description,
  latitude, longitude, location_text, urgency, sdg_tag, barangay, status
) VALUES
  (
    'VM-2026-0001',
    'ANON-12345',
    'flood',
    'May mataas na baha sa gate ng elementary school, halos 1 metro',
    14.6042,
    120.9822,
    'Elementary School Gate, Brgy Nangka',
    'critical',
    'SDG 11',
    'Nangka',
    'received'
  ),
  (
    'VM-2026-0002',
    'ANON-67890',
    'waste',
    'Hindi nakolekta ang basura, 3 days na',
    14.6050,
    120.9830,
    'Corner of Rizal Street and Santos Avenue',
    'medium',
    'SDG 11',
    'Nangka',
    'in_progress'
  );
```

---

### Table: audit_log

Tracks all administrative actions for transparency and accountability.

```sql
CREATE TABLE audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id TEXT REFERENCES reports(id) ON DELETE CASCADE,
  
  -- Action details
  action TEXT NOT NULL,  -- 'delete', 'status_change', 'reopen', 'edit'
  performed_by TEXT NOT NULL,  -- Official username or system
  
  -- Change tracking
  old_value TEXT,
  new_value TEXT,
  note TEXT,
  
  -- Timestamp
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_audit_log_report_id ON audit_log(report_id);
CREATE INDEX idx_audit_log_action ON audit_log(action);
CREATE INDEX idx_audit_log_created_at ON audit_log(created_at DESC);
CREATE INDEX idx_audit_log_performed_by ON audit_log(performed_by);

-- Comments
COMMENT ON TABLE audit_log IS 'Immutable log of all administrative actions';
COMMENT ON COLUMN audit_log.action IS 'Type of action performed';
COMMENT ON COLUMN audit_log.performed_by IS 'Username of official who performed action';
```

**Sample Data:**
```sql
INSERT INTO audit_log (report_id, action, performed_by, old_value, new_value, note) VALUES
  ('VM-2026-0001', 'status_change', 'barangay_captain_1', 'received', 'in_progress', 'Dispatched cleanup crew'),
  ('VM-2026-0002', 'delete', 'barangay_secretary', NULL, NULL, 'Duplicate report');
```

---

### Table: clusters

Stores detected report clusters for early warning.

```sql
CREATE TABLE clusters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Location
  barangay TEXT NOT NULL,
  latitude FLOAT NOT NULL,  -- Center of cluster
  longitude FLOAT NOT NULL,
  radius_meters INT NOT NULL DEFAULT 500,
  
  -- Cluster details
  issue_type TEXT NOT NULL,
  report_count INT NOT NULL DEFAULT 0,
  report_ids TEXT[],  -- Array of report IDs in this cluster
  
  -- Alert status
  alerted BOOLEAN DEFAULT false,
  alerted_at TIMESTAMPTZ,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_clusters_barangay ON clusters(barangay);
CREATE INDEX idx_clusters_issue_type ON clusters(issue_type);
CREATE INDEX idx_clusters_alerted ON clusters(alerted);
CREATE INDEX idx_clusters_created_at ON clusters(created_at DESC);

-- Comments
COMMENT ON TABLE clusters IS 'Detected incident clusters (3+ reports within 500m)';
COMMENT ON COLUMN clusters.report_count IS 'Number of reports in this cluster';
COMMENT ON COLUMN clusters.alerted IS 'Has alert been sent to officials?';
```

**Sample Data:**
```sql
INSERT INTO clusters (barangay, latitude, longitude, issue_type, report_count, report_ids, alerted) VALUES
  ('Nangka', 14.6042, 120.9822, 'flood', 5, ARRAY['VM-2026-0001', 'VM-2026-0003', 'VM-2026-0005', 'VM-2026-0007', 'VM-2026-0009'], true);
```

---

## Row-Level Security (RLS)

Enable RLS on all tables:

```sql
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE clusters ENABLE ROW LEVEL SECURITY;
```

### Users Table Policies

```sql
-- Residents can view their own profile
CREATE POLICY "Users can view own profile"
ON users FOR SELECT
USING (id = auth.uid() OR account_type = 'official');

-- Residents can update their own profile
CREATE POLICY "Users can update own profile"
ON users FOR UPDATE
USING (id = auth.uid());
```

### Reports Table Policies

```sql
-- Residents can view their own reports
CREATE POLICY "Residents view own reports"
ON reports FOR SELECT
USING (
  reporter_anonymous_id = (
    SELECT anonymous_id FROM users WHERE id = auth.uid()
  )
  OR
  EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid() AND account_type = 'official'
  )
);

-- Residents can insert their own reports
CREATE POLICY "Residents insert own reports"
ON reports FOR INSERT
WITH CHECK (
  reporter_anonymous_id = (
    SELECT anonymous_id FROM users WHERE id = auth.uid()
  )
);

-- Officials can view all non-deleted reports
CREATE POLICY "Officials view all reports"
ON reports FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid() AND account_type = 'official'
  )
);

-- Officials can update reports
CREATE POLICY "Officials update reports"
ON reports FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid() AND account_type = 'official'
  )
);

-- Only service role can delete (soft delete via backend)
CREATE POLICY "Only backend can delete"
ON reports FOR UPDATE
USING (auth.role() = 'service_role');
```

### Audit Log Policies

```sql
-- Anyone can view audit logs (public transparency)
CREATE POLICY "Public can view audit logs"
ON audit_log FOR SELECT
USING (true);

-- Only service role can insert audit logs
CREATE POLICY "Only backend can insert audit logs"
ON audit_log FOR INSERT
WITH CHECK (auth.role() = 'service_role');
```

### Clusters Table Policies

```sql
-- Officials can view clusters
CREATE POLICY "Officials view clusters"
ON clusters FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid() AND account_type = 'official'
  )
);

-- Only backend can manage clusters
CREATE POLICY "Only backend manages clusters"
ON clusters FOR ALL
USING (auth.role() = 'service_role');
```

---

## Triggers

### Auto-update updated_at timestamp

```sql
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_reports_updated_at
  BEFORE UPDATE ON reports
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_clusters_updated_at
  BEFORE UPDATE ON clusters
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();
```

### Auto-log report deletions

```sql
CREATE OR REPLACE FUNCTION log_report_deletion()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_deleted = true AND OLD.is_deleted = false THEN
    INSERT INTO audit_log (report_id, action, performed_by, note)
    VALUES (NEW.id, 'delete', NEW.deleted_by, 'Report soft deleted');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_report_delete
  AFTER UPDATE ON reports
  FOR EACH ROW
  EXECUTE FUNCTION log_report_deletion();
```

---

## Realtime Configuration

Enable realtime for live dashboard updates:

```sql
-- Enable realtime for reports table
ALTER PUBLICATION supabase_realtime ADD TABLE reports;

-- Enable realtime for clusters table
ALTER PUBLICATION supabase_realtime ADD TABLE clusters;

-- Enable realtime for audit_log table
ALTER PUBLICATION supabase_realtime ADD TABLE audit_log;
```

**Or do it in Supabase Dashboard:**
1. Go to Database → Replication
2. Enable `reports` table
3. Enable `clusters` table
4. Enable `audit_log` table

---

## Storage Buckets

Create storage bucket for photos:

```sql
-- Create photos bucket (do this in Supabase Dashboard → Storage)
-- Bucket name: photos
-- Public: true
-- File size limit: 5MB
-- Allowed MIME types: image/jpeg, image/png, image/webp
```

**Storage Policies:**

```sql
-- Allow authenticated users to upload photos
CREATE POLICY "Authenticated users can upload photos"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'photos' AND
  auth.role() = 'authenticated'
);

-- Anyone can view photos (public bucket)
CREATE POLICY "Public can view photos"
ON storage.objects FOR SELECT
USING (bucket_id = 'photos');

-- Only uploaders can delete their photos
CREATE POLICY "Users can delete own photos"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'photos' AND
  auth.uid()::text = (storage.foldername(name))[1]
);
```

---

## Helper Functions

### Generate Anonymous ID

```sql
CREATE OR REPLACE FUNCTION generate_anonymous_id()
RETURNS TEXT AS $$
DECLARE
  new_id TEXT;
  exists BOOLEAN;
BEGIN
  LOOP
    -- Generate random 5-character alphanumeric ID
    new_id := 'ANON-' || upper(substring(md5(random()::text) from 1 for 5));
    
    -- Check if it exists
    SELECT EXISTS(SELECT 1 FROM users WHERE anonymous_id = new_id) INTO exists;
    
    EXIT WHEN NOT exists;
  END LOOP;
  
  RETURN new_id;
END;
$$ LANGUAGE plpgsql;
```

### Calculate Distance Between Reports

```sql
CREATE OR REPLACE FUNCTION earth_distance(lat1 FLOAT, lng1 FLOAT, lat2 FLOAT, lng2 FLOAT)
RETURNS FLOAT AS $$
DECLARE
  earth_radius FLOAT := 6371000;  -- Earth radius in meters
  dlat FLOAT;
  dlng FLOAT;
  a FLOAT;
  c FLOAT;
BEGIN
  dlat := radians(lat2 - lat1);
  dlng := radians(lng2 - lng1);
  
  a := sin(dlat/2) * sin(dlat/2) + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlng/2) * sin(dlng/2);
  c := 2 * atan2(sqrt(a), sqrt(1-a));
  
  RETURN earth_radius * c;
END;
$$ LANGUAGE plpgsql;
```

---

## Database Maintenance

### Vacuum and Analyze

Run periodically to optimize performance:

```sql
VACUUM ANALYZE users;
VACUUM ANALYZE reports;
VACUUM ANALYZE audit_log;
VACUUM ANALYZE clusters;
```

### Clean Up Old Clusters

Delete clusters older than 7 days:

```sql
DELETE FROM clusters
WHERE created_at < NOW() - INTERVAL '7 days';
```

---

## Backup Strategy

**Supabase Automatic Backups:**
- Daily backups (retained for 7 days on free tier)
- Point-in-time recovery available
- Manual backups: Dashboard → Settings → Backups

**Manual Export:**
```bash
# Export entire database
pg_dump -h db.xxxxx.supabase.co -U postgres -d postgres > backup.sql

# Export specific table
pg_dump -h db.xxxxx.supabase.co -U postgres -d postgres -t reports > reports_backup.sql
```

---

## Schema Migrations

When updating schema in production:

1. **Create migration file:**
   ```sql
   -- migrations/0002_add_urgency_colors.sql
   ALTER TABLE reports ADD COLUMN urgency_color TEXT;
   ```

2. **Test in staging first**

3. **Apply to production:**
   - Go to Supabase Dashboard → SQL Editor
   - Run migration script
   - Verify with `SELECT * FROM reports LIMIT 1;`

4. **Update application code** to use new column

---

## Monitoring Queries

### Check table sizes

```sql
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname || '.' || tablename) DESC;
```

### Count reports by status

```sql
SELECT status, COUNT(*) FROM reports GROUP BY status ORDER BY COUNT(*) DESC;
```

### Recent audit log entries

```sql
SELECT * FROM audit_log ORDER BY created_at DESC LIMIT 10;
```

### Active clusters

```sql
SELECT * FROM clusters WHERE alerted = false ORDER BY created_at DESC;
```

---

**Next Steps:** Read 02_API_REFERENCE.md for backend endpoint specifications.