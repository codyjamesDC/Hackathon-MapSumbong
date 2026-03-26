-- ============================================================
-- MapSumbong — Full Database Reset & Seed Script
-- Run this in: Supabase Dashboard → SQL Editor
-- ============================================================
-- ⚠️  WARNING: This drops ALL existing data. Run on a fresh project.
-- ============================================================


-- ============================================================
-- STEP 1: DROP EVERYTHING (order matters for FKs)
-- ============================================================

DROP TABLE IF EXISTS audit_log   CASCADE;
DROP TABLE IF EXISTS messages     CASCADE;
DROP TABLE IF EXISTS clusters     CASCADE;
DROP TABLE IF EXISTS reports      CASCADE;
DROP TABLE IF EXISTS users        CASCADE;

DROP FUNCTION IF EXISTS update_updated_at()       CASCADE;
DROP FUNCTION IF EXISTS log_report_deletion()     CASCADE;
DROP FUNCTION IF EXISTS generate_anonymous_id()   CASCADE;
DROP FUNCTION IF EXISTS earth_distance(FLOAT, FLOAT, FLOAT, FLOAT) CASCADE;


-- ============================================================
-- STEP 2: CREATE TABLES
-- ============================================================

-- users -------------------------------------------------------
CREATE TABLE users (
  id            UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_hash    TEXT    UNIQUE,
  anonymous_id  TEXT    UNIQUE NOT NULL,
  account_type  TEXT    NOT NULL CHECK (account_type IN ('resident', 'official')),
  display_name  TEXT,
  is_anonymous  BOOLEAN DEFAULT true,
  barangay      TEXT,
  purok         TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_users_phone_hash    ON users(phone_hash);
CREATE INDEX idx_users_anonymous_id  ON users(anonymous_id);
CREATE INDEX idx_users_account_type  ON users(account_type);

COMMENT ON TABLE  users              IS 'Residents and barangay officials';
COMMENT ON COLUMN users.phone_hash   IS 'SHA-256 hash of phone number for privacy';
COMMENT ON COLUMN users.anonymous_id IS 'Public-facing anonymous identifier (ANON-XXXXX)';


-- reports -----------------------------------------------------
CREATE TABLE reports (
  id                    TEXT    PRIMARY KEY,
  reporter_anonymous_id TEXT    NOT NULL REFERENCES users(anonymous_id) ON DELETE RESTRICT,

  -- Content
  issue_type    TEXT    NOT NULL CHECK (issue_type IN (
    'flood', 'waste', 'road_hazard', 'road',
    'power_outage', 'power', 'water_supply', 'water',
    'medical', 'emergency', 'fire', 'crime',
    'landslide', 'earthquake_damage', 'other'
  )),
  description   TEXT    NOT NULL,
  photo_url     TEXT,

  -- Location
  latitude      FLOAT   NOT NULL,
  longitude     FLOAT   NOT NULL,
  location_text TEXT,
  barangay      TEXT    NOT NULL,
  purok         TEXT,

  -- Classification
  urgency   TEXT NOT NULL DEFAULT 'medium'
    CHECK (urgency IN ('critical', 'high', 'medium', 'low')),
  sdg_tag   TEXT,

  -- Status
  status TEXT NOT NULL DEFAULT 'received'
    CHECK (status IN ('received', 'in_progress', 'repair_scheduled', 'resolved', 'reopened')),

  -- Resolution
  resolution_photo_url  TEXT,
  resolution_note       TEXT,
  resident_confirmed    BOOLEAN,
  resolved_at           TIMESTAMPTZ,
  resolved_by           TEXT,

  -- Soft delete
  is_deleted    BOOLEAN     DEFAULT false,
  deleted_at    TIMESTAMPTZ,
  deleted_by    TEXT,

  -- Timestamps
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_reports_reporter    ON reports(reporter_anonymous_id);
CREATE INDEX idx_reports_status      ON reports(status);
CREATE INDEX idx_reports_urgency     ON reports(urgency);
CREATE INDEX idx_reports_barangay    ON reports(barangay);
CREATE INDEX idx_reports_issue_type  ON reports(issue_type);
CREATE INDEX idx_reports_created_at  ON reports(created_at DESC);
CREATE INDEX idx_reports_is_deleted  ON reports(is_deleted);

COMMENT ON TABLE reports IS 'All incident reports submitted by residents';


-- messages ----------------------------------------------------
CREATE TABLE messages (
  id           UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id    TEXT    REFERENCES reports(id) ON DELETE CASCADE,
  sender_id    TEXT    NOT NULL,
  sender_type  TEXT    NOT NULL CHECK (sender_type IN ('resident', 'authority', 'ai', 'system')),
  content      TEXT    NOT NULL,
  message_type TEXT    NOT NULL DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'system')),
  image_url    TEXT,
  timestamp    TIMESTAMPTZ DEFAULT NOW(),
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_messages_report_id  ON messages(report_id);
CREATE INDEX idx_messages_timestamp  ON messages(timestamp ASC);

COMMENT ON TABLE messages IS 'Chat messages between residents, officials, and AI';


-- clusters ----------------------------------------------------
CREATE TABLE clusters (
  id             UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  barangay       TEXT    NOT NULL,
  latitude       FLOAT   NOT NULL,
  longitude      FLOAT   NOT NULL,
  radius_meters  INT     NOT NULL DEFAULT 500,
  issue_type     TEXT    NOT NULL,
  report_count   INT     NOT NULL DEFAULT 0,
  report_ids     TEXT[],
  alerted        BOOLEAN DEFAULT false,
  alerted_at     TIMESTAMPTZ,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_clusters_barangay    ON clusters(barangay);
CREATE INDEX idx_clusters_issue_type  ON clusters(issue_type);
CREATE INDEX idx_clusters_alerted     ON clusters(alerted);
CREATE INDEX idx_clusters_created_at  ON clusters(created_at DESC);

COMMENT ON TABLE clusters IS 'Detected incident clusters (3+ reports within 500m)';


-- audit_log ---------------------------------------------------
CREATE TABLE audit_log (
  id           UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id    TEXT    REFERENCES reports(id) ON DELETE CASCADE,
  action       TEXT    NOT NULL,
  performed_by TEXT    NOT NULL,
  old_value    TEXT,
  new_value    TEXT,
  note         TEXT,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_log_report_id    ON audit_log(report_id);
CREATE INDEX idx_audit_log_action       ON audit_log(action);
CREATE INDEX idx_audit_log_created_at   ON audit_log(created_at DESC);
CREATE INDEX idx_audit_log_performed_by ON audit_log(performed_by);

COMMENT ON TABLE audit_log IS 'Immutable log of all administrative actions';


-- ============================================================
-- STEP 3: FUNCTIONS & TRIGGERS
-- ============================================================

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_reports_updated_at
  BEFORE UPDATE ON reports
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_clusters_updated_at
  BEFORE UPDATE ON clusters
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Auto-log soft deletes
CREATE OR REPLACE FUNCTION log_report_deletion()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_deleted = true AND OLD.is_deleted = false THEN
    INSERT INTO audit_log (report_id, action, performed_by, note)
    VALUES (NEW.id, 'delete', COALESCE(NEW.deleted_by, 'system'), 'Report soft deleted');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_report_delete
  AFTER UPDATE ON reports
  FOR EACH ROW EXECUTE FUNCTION log_report_deletion();

-- Helper: generate unique anonymous ID
CREATE OR REPLACE FUNCTION generate_anonymous_id()
RETURNS TEXT AS $$
DECLARE
  new_id     TEXT;
  id_exists  BOOLEAN;
BEGIN
  LOOP
    new_id := 'ANON-' || upper(substring(md5(random()::text) FROM 1 FOR 5));
    SELECT EXISTS(SELECT 1 FROM users WHERE anonymous_id = new_id) INTO id_exists;
    EXIT WHEN NOT id_exists;
  END LOOP;
  RETURN new_id;
END;
$$ LANGUAGE plpgsql;


-- ============================================================
-- STEP 4: ROW LEVEL SECURITY
-- NOTE: reports RLS is DISABLED for dev/guest login compatibility.
--       The dev guest login has no Supabase auth session, so
--       auth.uid() = NULL and all RLS policies block reads.
--       Re-enable RLS on reports when moving to production.
-- ============================================================

ALTER TABLE users      ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports    DISABLE ROW LEVEL SECURITY;   -- ← dev-friendly: no auth required to read
ALTER TABLE messages   ENABLE ROW LEVEL SECURITY;
ALTER TABLE clusters   ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log  ENABLE ROW LEVEL SECURITY;

-- users policies
CREATE POLICY "Users can view own profile or officials"
  ON users FOR SELECT
  USING (id = auth.uid() OR account_type = 'official');

CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  USING (id = auth.uid());

CREATE POLICY "Users can insert own profile"
  ON users FOR INSERT
  WITH CHECK (id = auth.uid());

-- reports policies
CREATE POLICY "Residents view own reports; officials view all"
  ON reports FOR SELECT
  USING (
    reporter_anonymous_id = (
      SELECT anonymous_id FROM users WHERE id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND account_type = 'official'
    )
  );

CREATE POLICY "Residents insert own reports"
  ON reports FOR INSERT
  WITH CHECK (
    reporter_anonymous_id = (
      SELECT anonymous_id FROM users WHERE id = auth.uid()
    )
  );

CREATE POLICY "Officials can update reports"
  ON reports FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND account_type = 'official'
    )
  );

-- messages policies
CREATE POLICY "Users view messages for their reports; officials view all"
  ON messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM reports r
      JOIN users u ON r.reporter_anonymous_id = u.anonymous_id
      WHERE r.id = report_id AND u.id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND account_type = 'official'
    )
  );

CREATE POLICY "Users insert messages for their reports"
  ON messages FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM reports r
      JOIN users u ON r.reporter_anonymous_id = u.anonymous_id
      WHERE r.id = report_id AND u.id = auth.uid()
    )
    OR auth.role() = 'service_role'
  );

-- clusters policies
CREATE POLICY "Anyone can view clusters"
  ON clusters FOR SELECT USING (true);

CREATE POLICY "Only backend manages clusters"
  ON clusters FOR ALL
  USING (auth.role() = 'service_role');

-- audit_log policies
CREATE POLICY "Public can view audit logs"
  ON audit_log FOR SELECT USING (true);

CREATE POLICY "Only backend inserts audit logs"
  ON audit_log FOR INSERT
  WITH CHECK (auth.role() = 'service_role');


-- ============================================================
-- STEP 5: REALTIME
-- ============================================================

ALTER PUBLICATION supabase_realtime ADD TABLE reports;
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE clusters;
ALTER PUBLICATION supabase_realtime ADD TABLE audit_log;


-- ============================================================
-- STEP 6: SEED USERS
-- ============================================================
-- Two users are created:
--   1. 'ANON-DEV01'  — matches the app's built-in dev guest login (signInAsGuest button)
--   2. 'ANON-DEMO-001' — a general demo resident
--
-- After you sign in with your REAL phone number via OTP, run the
-- "Post-Login Step" at the bottom of this file to link your
-- Supabase auth UUID to 'ANON-DEV01'.
-- ============================================================

INSERT INTO users (anonymous_id, account_type, display_name, is_anonymous, barangay)
VALUES
  ('ANON-DEV01',    'resident', 'Dev User',        true, 'Batong Malake'),
  ('ANON-DEMO-001', 'resident', 'Demo Resident',   true, 'Batong Malake');


-- ============================================================
-- STEP 7: SEED REPORTS
-- All 20 reports are linked to 'ANON-DEV01' so they appear
-- immediately when you use the Dev Guest Login in the app.
-- ============================================================

WITH seed(barangay, latitude, longitude, issue_type, urgency, description, location_text, sdg_tag) AS (
  VALUES
    -- Cluster: 5 reports in Batong Malake
    ('Batong Malake',    14.1595, 121.2310, 'waste',           'medium',   'Overflowing bin near food establishments',       'Raymundo Gate area',           'SDG11'),
    ('Batong Malake',    14.1602, 121.2305, 'road_hazard',     'high',     'Deep pothole hidden by puddle',                  'F.O. Santos St.',              'SDG9'),
    ('Batong Malake',    14.1588, 121.2322, 'medical',         'low',      'Request for stray animal capture/control',       'Democracy Plaza vicinity',     'SDG3'),
    ('Batong Malake',    14.1615, 121.2318, 'power_outage',    'medium',   'Partial brownout affecting one side of street',  'Lopez Avenue upper',           'SDG7'),
    ('Batong Malake',    14.1592, 121.2300, 'flood',           'high',     'Gutter overflow reaching sidewalk level',        'Near UPLB Main Gate',          'SDG11'),

    -- 15 additional reports across different barangays
    ('Anos',             14.1720, 121.2345, 'road_hazard',     'medium',   'Loose gravel on sharp curve',                    'Anos diversion road',          'SDG9'),
    ('Bagong Silang',    14.1405, 121.2115, 'landslide',       'critical', 'Significant mud across the road after rain',     'Bagong Silang entry',          'SDG13'),
    ('Bambang',          14.1700, 121.2155, 'water_supply',    'low',      'Low water pressure during peak hours',           'Bambang Zone 3',               'SDG6'),
    ('Baybayin',         14.1800, 121.2220, 'waste',           'medium',   'Plastic waste clogging drainage grate',          'Baybayin shoreline',           'SDG14'),
    ('Bayog',            14.1875, 121.2480, 'flood',           'high',     'Rising lake water affecting coastal path',       'Bayog lakeside',               'SDG13'),
    ('Lalakay',          14.1725, 121.2100, 'road_hazard',     'critical', 'Large boulder fell onto the shoulder',           'Lalakay mountain side',        'SDG9'),
    ('Maahas',           14.1705, 121.2565, 'medical',         'high',     'Allergic reaction incident at local residence',  'Maahas interior',              'SDG3'),
    ('Malinta',          14.1835, 121.2300, 'fire',            'low',      'Smoldering trash pile near forest edge',         'Malinta boundary',             'SDG15'),
    ('Mayondon',         14.1905, 121.2395, 'road_hazard',     'medium',   'Missing drainage cover on sidewalk',             'Mayondon primary school road', 'SDG11'),
    ('Putho-Tuntungin',  14.1550, 121.2505, 'earthquake_damage','low',     'Hairline cracks on water tank base',             'Tuntungin water tower',        'SDG11'),
    ('San Antonio',      14.1760, 121.2495, 'power_outage',    'high',     'Downed power line due to fallen branch',         'San Antonio perimeter',        'SDG7'),
    ('Tadlac',           14.1785, 121.2055, 'waste',           'low',      'Abandoned bulky furniture on roadside',          'Tadlac access path',           'SDG12'),
    ('Timugan',          14.1695, 121.2210, 'medical',         'critical', 'Unconscious individual found in park',           'Timugan plaza',                'SDG3'),
    ('Anos',             14.1745, 121.2335, 'water_supply',    'medium',   'Discolored water from main line',                'Anos Crossing',                'SDG6'),
    ('Mayondon',         14.1870, 121.2360, 'flood',           'medium',   'Persistent ponding after short showers',         'Mayondon lower zone',          'SDG11')
)
INSERT INTO reports (
  id, reporter_anonymous_id,
  issue_type, description,
  latitude, longitude, location_text,
  urgency, sdg_tag, status, barangay,
  photo_url
)
SELECT
  'RPT-' || upper(substr(md5(clock_timestamp()::text || row_number() OVER ()::text), 1, 8)),
  'ANON-DEV01',   -- ← all linked to dev guest user
  issue_type, description,
  latitude, longitude, location_text,
  urgency, sdg_tag,
  'received',
  barangay,
  NULL::text
FROM seed;


-- ============================================================
-- ✅ VERIFICATION — run these to confirm everything is OK
-- ============================================================

-- SELECT COUNT(*) FROM users;    -- should be 2
-- SELECT COUNT(*) FROM reports;  -- should be 20
-- SELECT id, reporter_anonymous_id, issue_type, status FROM reports LIMIT 5;


-- ============================================================
-- POST-LOGIN STEP (run AFTER signing in with your phone number)
-- ============================================================
-- After you log in via OTP, find your Supabase auth UUID:
--   Supabase Dashboard → Authentication → Users → copy your UUID
--
-- Then run this to link your real account to the seed data:
--
-- INSERT INTO users (id, anonymous_id, account_type, display_name, is_anonymous, barangay)
-- VALUES (
--   '<YOUR-SUPABASE-AUTH-UUID>',  -- ← paste your UUID here
--   'ANON-DEV01',
--   'resident',
--   'Your Name',
--   false,
--   'Batong Malake'
-- )
-- ON CONFLICT (anonymous_id) DO UPDATE
--   SET id = EXCLUDED.id,
--       display_name = EXCLUDED.display_name,
--       is_anonymous = EXCLUDED.is_anonymous,
--       updated_at = NOW();
-- ============================================================
