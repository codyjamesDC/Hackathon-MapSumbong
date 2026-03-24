/**
 * MapSumbong API Service
 * ----------------------
 * Drop-in integration layer for connecting to your Supabase backend.
 * Replace SUPABASE_URL and SUPABASE_KEY with your actual credentials.
 * Your Flutter app writes to the same Supabase tables — this dashboard reads in real time.
 *
 * Flutter → Supabase (insert) → This dashboard (real-time subscription)
 */

const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL || '';
const SUPABASE_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY || '';

const headers = {
  'apikey': SUPABASE_KEY,
  'Authorization': `Bearer ${SUPABASE_KEY}`,
  'Content-Type': 'application/json'
};

/**
 * Fetch all incidents from Supabase
 * Maps Supabase row schema → MapSumbong incident object
 */
export async function fetchIncidents() {
  if (!SUPABASE_URL) return null;

  const res = await fetch(`${SUPABASE_URL}/rest/v1/reports?select=*&order=created_at.desc`, { headers });
  if (!res.ok) throw new Error('Failed to fetch incidents');
  const rows = await res.json();

  return rows.map(mapRow);
}

/**
 * Resolve an incident — updates Supabase and triggers SMS via Edge Function
 */
export async function resolveIncident(id) {
  if (!SUPABASE_URL) return;

  const updateRes = await fetch(`${SUPABASE_URL}/rest/v1/reports?id=eq.${id}`, {
    method: 'PATCH',
    headers,
    body: JSON.stringify({ status: 'resolved'})
  });
  if (!updateRes.ok) {
    throw new Error(`Failed to resolve incident ${id}`);
  }

  // Trigger Edge Function to send resolution SMS to reporter
  const smsRes = await fetch(`${SUPABASE_URL}/functions/v1/send-resolution-sms`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ incident_id: id })
  });
  if (!smsRes.ok) {
    throw new Error(`Resolved but SMS trigger failed for ${id}`);
  }
}

/**
 * Subscribe to real-time incident updates via Supabase Realtime
 * Call this once on mount — new Flutter reports appear instantly on the map
 *
 * @param {function} onInsert - called with new incident when Flutter app submits report
 * @param {function} onUpdate - called with updated incident when status changes
 * @returns {WebSocket} - call .close() to unsubscribe
 */
export function subscribeToIncidents(onInsert, onUpdate) {
  if (!SUPABASE_URL) return null;

  const wsUrl = SUPABASE_URL
    .replace('https://', 'wss://')
    .replace('http://', 'ws://');

  const ws = new WebSocket(`${wsUrl}/realtime/v1/websocket?apikey=${SUPABASE_KEY}&vsn=1.0.0`);

  ws.onopen = () => {
    ws.send(JSON.stringify({
      topic: 'realtime:public:reports',
      event: 'phx_join',
      payload: {
        config: {
          broadcast: { ack: false, self: false },
          presence: { key: '' },
          postgres_changes: [{ event: '*', schema: 'public', table: 'reports' }]
        }
      },
      ref: null
    }));
  };

  ws.onmessage = (e) => {
    const msg = JSON.parse(e.data);
    // Newer Supabase realtime payload shape
    if (msg.event === 'postgres_changes' && msg.payload?.data) {
      const change = msg.payload.data;
      if (change.type === 'INSERT' && change.record) onInsert(mapRow(change.record));
      if (change.type === 'UPDATE' && change.record) onUpdate(mapRow(change.record));
    }
    // Legacy/fallback shape
    if (msg.event === 'INSERT' && msg.payload?.record) onInsert(mapRow(msg.payload.record));
    if (msg.event === 'UPDATE' && msg.payload?.record) onUpdate(mapRow(msg.payload.record));
  };

  return ws;
}

function deriveCategory(issueType) {
  const map = {
    flood: 'flood',
    emergency: 'medical',
    fire: 'fire',
    road_damage: 'infrastructure',
    pothole: 'infrastructure',
    broken_streetlight: 'infrastructure',
    power_outage: 'infrastructure',
    garbage: 'waste',
    water_problem: 'waste',
    other: 'other',
  };
  return map[issueType] || 'other';
}

/**
 * Maps a Supabase DB row to the MapSumbong incident schema
 * Adjust field names to match your actual Supabase table columns
 */
function mapRow(row) {
  return {
    id: row.id,
    type: row.issue_type || 'Unknown',
    category: deriveCategory(row.issue_type),
    severity: row.urgency || 'medium',
    barangay: row.barangay || 'Unknown Barangay',
    location: row.location_text || '',
    lat: parseFloat(row.latitude) || 14.6,
    lng: parseFloat(row.longitude) || 121.0,
    reports: 1,
    time: formatTime(row.created_at),
    channel: 'App',
    description: row.description || '',
    ai: '',
    action: '',
    authorities: [],
    resolved: row.status === 'resolved',
    radius: 150,
  };
}

function formatTime(isoString) {
  if (!isoString) return 'Unknown';
  const diff = Date.now() - new Date(isoString).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return 'Just now';
  if (mins < 60) return `${mins} min${mins > 1 ? 's' : ''} ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs} hr${hrs > 1 ? 's' : ''} ago`;
  return new Date(isoString).toLocaleDateString('en-PH');
}

/**
 * Supabase table schema (run this SQL in your Supabase dashboard):
 *
 * create table incidents (
 *   id uuid primary key default gen_random_uuid(),
 *   incident_type text,
 *   category text,
 *   severity text default 'medium',
 *   barangay text,
 *   location_description text,
 *   latitude float,
 *   longitude float,
 *   report_count int default 1,
 *   channel text,
 *   raw_message text,
 *   ai_assessment text,
 *   immediate_action text,
 *   notified_authorities text[],
 *   resolved boolean default false,
 *   resolved_at timestamptz,
 *   reporter_id text,
 *   created_at timestamptz default now()
 * );
 *
 * -- Enable realtime
 * alter publication supabase_realtime add table incidents;
 */
