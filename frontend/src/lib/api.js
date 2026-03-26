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
const SUPABASE_STORAGE_BUCKET = import.meta.env.VITE_SUPABASE_STORAGE_BUCKET || 'photos';
const BACKEND_URL = import.meta.env.VITE_BACKEND_URL || 'http://localhost:8000';

const headers = {
  'apikey': SUPABASE_KEY,
  'Authorization': `Bearer ${SUPABASE_KEY}`,
  'Content-Type': 'application/json'
};

const RESOLVE_REQUEST_TIMEOUT_MS = 12000;
const RESOLVE_UPLOAD_TIMEOUT_MS = 45000;
export const MAX_EVIDENCE_FILE_SIZE_BYTES = 15 * 1024 * 1024;

async function fetchWithTimeout(url, options = {}, timeoutMs = RESOLVE_REQUEST_TIMEOUT_MS) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

  try {
    return await fetch(url, {
      ...options,
      signal: controller.signal,
    });
  } catch (err) {
    if (err?.name === 'AbortError') {
      throw new Error('Request timed out. Please try again.');
    }
    throw err;
  } finally {
    clearTimeout(timeoutId);
  }
}

async function extractErrorMessage(res) {
  try {
    const data = await res.clone().json();
    if (typeof data?.message === 'string' && data.message.trim()) {
      return data.message.trim();
    }
    if (typeof data?.error_description === 'string' && data.error_description.trim()) {
      return data.error_description.trim();
    }
    if (typeof data?.error === 'string' && data.error.trim()) {
      return data.error.trim();
    }
  } catch {
    // Fall back to plain text below.
  }

  try {
    const text = await res.text();
    if (typeof text === 'string' && text.trim()) {
      return text.trim();
    }
  } catch {
    // Ignore and return status text fallback.
  }

  return res.statusText || 'Request failed';
}

async function patchReport(encodedId, payload) {
  const updateRes = await fetchWithTimeout(`${SUPABASE_URL}/rest/v1/reports?id=eq.${encodedId}`, {
    method: 'PATCH',
    headers: { ...headers, Prefer: 'return=representation' },
    body: JSON.stringify(payload)
  });

  if (!updateRes.ok) {
    const reason = await extractErrorMessage(updateRes);
    return {
      ok: false,
      row: null,
      errorMessage: `${updateRes.status} ${reason}`
    };
  }

  const updatedRows = await updateRes.json().catch(() => []);
  const updatedRow = Array.isArray(updatedRows) && updatedRows.length
    ? updatedRows[0]
    : null;

  return {
    ok: true,
    row: updatedRow,
    errorMessage: ''
  };
}

function hasText(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

function encodeStoragePath(path) {
  return String(path)
    .split('/')
    .filter(Boolean)
    .map(segment => encodeURIComponent(segment))
    .join('/');
}

function sanitizeForPathSegment(value, fallback = 'file') {
  const sanitized = String(value || '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/[^a-z0-9._-]/g, '-');
  return sanitized || fallback;
}

function buildPublicStorageUrl(objectPath) {
  const bucket = encodeURIComponent(SUPABASE_STORAGE_BUCKET);
  return `${SUPABASE_URL}/storage/v1/object/public/${bucket}/${encodeStoragePath(objectPath)}`;
}

function buildBackendUrl(path) {
  return `${BACKEND_URL.replace(/\/$/, '')}${path}`;
}

function ensureFileWithinLimit(file, label) {
  if (!file) return;
  if (!(file instanceof File)) {
    throw new Error(`Invalid ${label} file selected.`);
  }
  if (file.size <= 0) {
    throw new Error(`${label} file is empty.`);
  }
  if (file.size > MAX_EVIDENCE_FILE_SIZE_BYTES) {
    throw new Error(`${label} file is too large. Maximum size is 15 MB.`);
  }
}

async function uploadResolutionEvidenceFile(incidentId, file, kind) {
  if (!SUPABASE_URL || !SUPABASE_KEY) {
    throw new Error('Dashboard is not connected to Supabase. Cannot upload files.');
  }

  const fileName = String(file.name || 'evidence');
  const dotIndex = fileName.lastIndexOf('.');
  const ext = dotIndex > -1 ? sanitizeForPathSegment(fileName.slice(dotIndex + 1), '') : '';
  const baseName = dotIndex > -1 ? fileName.slice(0, dotIndex) : fileName;
  const safeBaseName = sanitizeForPathSegment(baseName, 'evidence');
  const safeIncidentId = sanitizeForPathSegment(incidentId, 'incident');
  const uniqueSuffix = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  const objectFileName = ext
    ? `${kind}-${safeBaseName}-${uniqueSuffix}.${ext}`
    : `${kind}-${safeBaseName}-${uniqueSuffix}`;
  const objectPath = `resolutions/${safeIncidentId}/${objectFileName}`;

  const uploadRes = await fetchWithTimeout(
    `${SUPABASE_URL}/storage/v1/object/${encodeURIComponent(SUPABASE_STORAGE_BUCKET)}/${encodeStoragePath(objectPath)}`,
    {
      method: 'POST',
      headers: {
        apikey: SUPABASE_KEY,
        Authorization: `Bearer ${SUPABASE_KEY}`,
        'x-upsert': 'true',
        'Content-Type': file.type || 'application/octet-stream',
      },
      body: file,
    },
    RESOLVE_UPLOAD_TIMEOUT_MS
  );

  if (!uploadRes.ok) {
    const reason = await extractErrorMessage(uploadRes);
    if (/row-level|permission|not authorized|forbidden/i.test(reason) || uploadRes.status === 401 || uploadRes.status === 403) {
      throw new Error(
        'File upload blocked by storage policy. Ensure the photos bucket allows dashboard uploads for authority users.'
      );
    }
    throw new Error(
      `Failed to upload ${kind} evidence file: ${uploadRes.status} ${reason}`
    );
  }

  return buildPublicStorageUrl(objectPath);
}

export async function uploadResolutionEvidence(
  incidentId,
  {
    writtenReportFile = null,
    photoEvidenceFile = null,
  } = {}
) {
  ensureFileWithinLimit(writtenReportFile, 'Written report');
  ensureFileWithinLimit(photoEvidenceFile, 'Photo evidence');

  async function uploadViaBackendFallback() {
    const formData = new FormData();
    if (writtenReportFile) {
      formData.append('written_report_file', writtenReportFile, writtenReportFile.name);
    }
    if (photoEvidenceFile) {
      formData.append('photo_evidence_file', photoEvidenceFile, photoEvidenceFile.name);
    }

    const fallbackRes = await fetchWithTimeout(
      buildBackendUrl(`/reports/${encodeURIComponent(incidentId)}/resolution-evidence`),
      {
        method: 'POST',
        body: formData,
      },
      RESOLVE_UPLOAD_TIMEOUT_MS
    );

    if (!fallbackRes.ok) {
      const reason = await extractErrorMessage(fallbackRes);
      throw new Error(`File upload fallback failed: ${fallbackRes.status} ${reason}`);
    }

    const fallbackData = await fallbackRes.json().catch(() => ({}));
    return {
      resolutionNote: hasText(fallbackData?.resolution_note)
        ? fallbackData.resolution_note.trim()
        : '',
      resolutionPhotoUrl: hasText(fallbackData?.resolution_photo_url)
        ? fallbackData.resolution_photo_url.trim()
        : '',
    };
  }

  try {
    const [writtenReportUrl, photoEvidenceUrl] = await Promise.all([
      writtenReportFile
        ? uploadResolutionEvidenceFile(incidentId, writtenReportFile, 'report')
        : Promise.resolve(''),
      photoEvidenceFile
        ? uploadResolutionEvidenceFile(incidentId, photoEvidenceFile, 'photo')
        : Promise.resolve(''),
    ]);

    return {
      resolutionNote: writtenReportUrl,
      resolutionPhotoUrl: photoEvidenceUrl,
    };
  } catch (err) {
    const message = String(err?.message || '').toLowerCase();
    const shouldTryFallback =
      message.includes('file upload blocked by storage policy') ||
      message.includes('not authorized') ||
      message.includes('forbidden') ||
      message.includes('row-level');

    if (!shouldTryFallback) {
      throw err;
    }

    return uploadViaBackendFallback();
  }
}

function buildResolutionState(row) {
  const status = String(row.status || '').toLowerCase();
  const resolvedFromStatus = status === 'resolved';
  const resolvedFromBoolean =
    typeof row.resolved === 'boolean'
      ? row.resolved
      : typeof row.is_resolved === 'boolean'
        ? row.is_resolved
        : false;
  const resolved = resolvedFromStatus || resolvedFromBoolean;
  const resolutionNote = hasText(row.resolution_note)
    ? row.resolution_note.trim()
    : '';
  const resolutionPhotoUrl = hasText(row.resolution_photo_url)
    ? row.resolution_photo_url.trim()
    : '';
  const resolutionComplete =
    resolved && hasText(resolutionNote) && hasText(resolutionPhotoUrl);

  return {
    resolved,
    resolutionNote,
    resolutionPhotoUrl,
    resolutionComplete,
    resolutionPendingProof: resolved && !resolutionComplete,
  };
}

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
export async function resolveIncident(
  id,
  {
    resolutionNote = '',
    resolutionPhotoUrl = '',
  } = {}
) {
  if (!SUPABASE_URL) {
    throw new Error('Dashboard is not connected to Supabase. Cannot persist resolution status.');
  }

  const encodedId = encodeURIComponent(id);

  const payload = { status: 'resolved' };
  if (hasText(resolutionNote)) {
    payload.resolution_note = resolutionNote.trim();
  }
  if (hasText(resolutionPhotoUrl)) {
    payload.resolution_photo_url = resolutionPhotoUrl.trim();
  }

  let updateResult = await patchReport(encodedId, payload);
  if (!updateResult.ok) {
    const shouldTryBooleanResolve = /column .*status|status.*does not exist|schema cache|enum|constraint/i.test(
      updateResult.errorMessage
    );

    if (shouldTryBooleanResolve) {
      const booleanPayload = {
        resolved: true,
        ...payload,
      };
      delete booleanPayload.status;
      updateResult = await patchReport(encodedId, booleanPayload);
    }
  }

  if (!updateResult.ok) {
    throw new Error(`Failed to resolve incident ${id}: ${updateResult.errorMessage}`);
  }

  const resolutionNoteValue = hasText(payload.resolution_note)
    ? payload.resolution_note.trim()
    : '';
  const resolutionPhotoUrlValue = hasText(payload.resolution_photo_url)
    ? payload.resolution_photo_url.trim()
    : '';
  const resolutionComplete =
    hasText(resolutionNoteValue) && hasText(resolutionPhotoUrlValue);

  let updatedRow = updateResult.row;

  // Some Supabase/RLS combinations may return empty representation even when update succeeded.
  // Confirm persisted state by reading the row back before allowing UI update.
  if (!updatedRow) {
    try {
      const confirmRes = await fetchWithTimeout(
        `${SUPABASE_URL}/rest/v1/reports?select=*&id=eq.${encodedId}&limit=1`,
        { headers }
      );

      if (confirmRes.ok) {
        const confirmedRows = await confirmRes.json().catch(() => []);
        updatedRow = Array.isArray(confirmedRows) && confirmedRows.length
          ? confirmedRows[0]
          : null;
      }
    } catch {
      // Fallback below keeps UI state in sync when read-after-write is blocked.
    }
  }

  const mappedUpdatedRow = updatedRow ? mapRow(updatedRow) : null;
  const resolvedMappedRow = mappedUpdatedRow && mappedUpdatedRow.resolved
    ? mappedUpdatedRow
    : null;

  // Only send completion SMS when full closure proof is present.
  if (hasText(payload.resolution_note) && hasText(payload.resolution_photo_url)) {
    const smsRes = await fetchWithTimeout(`${SUPABASE_URL}/functions/v1/send-resolution-sms`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ incident_id: id })
    });
    if (!smsRes.ok) {
      console.warn(`Resolved incident ${id}, but SMS trigger failed.`);
    }
  }

  if (resolvedMappedRow) {
    return resolvedMappedRow;
  }

  return {
    id,
    resolved: true,
    resolutionNote: resolutionNoteValue,
    resolutionPhotoUrl: resolutionPhotoUrlValue,
    resolutionComplete,
    resolutionPendingProof: !resolutionComplete,
  };
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

function prettifyIssueType(issueType) {
  if (!issueType) return 'Community Report';
  return String(issueType)
    .replace(/_/g, ' ')
    .replace(/\b\w/g, c => c.toUpperCase());
}

function normalizeSeverity(value) {
  const sev = String(value || 'medium').toLowerCase().trim();
  if (sev === 'critical' || sev === 'high' || sev === 'medium' || sev === 'low') {
    return sev;
  }
  return 'medium';
}

function buildAiFallback({ severity, category, barangay }) {
  const sev = String(severity || 'medium');
  const brgy = barangay || 'the reported area';
  const guidance = {
    flood: 'Potential flood-prone condition detected from community submission.',
    fire: 'Possible fire-related incident that needs rapid validation.',
    medical: 'Potential medical emergency requiring timely triage.',
    infrastructure: 'Possible public infrastructure issue requiring inspection.',
    waste: 'Possible sanitation-related hazard requiring barangay action.',
    other: 'Incident submitted and queued for barangay verification.'
  };
  return `${guidance[category] || guidance.other} Severity tagged as ${sev} in ${brgy}.`;
}

function buildActionFallback({ severity, category }) {
  if (severity === 'critical' || severity === 'high') {
    return 'Stay clear of the area and wait for responder instructions. Contact emergency services if conditions worsen.';
  }
  if (category === 'waste' || category === 'infrastructure') {
    return 'Avoid the affected spot and coordinate with barangay officials for safe temporary routing.';
  }
  return 'Exercise caution near the reported location and monitor official barangay updates.';
}

function normalizeAuthorities(row, category) {
  if (Array.isArray(row.notified_authorities) && row.notified_authorities.length > 0) {
    return row.notified_authorities;
  }

  if (typeof row.notified_authorities === 'string' && row.notified_authorities.trim()) {
    return row.notified_authorities
      .split(',')
      .map(v => v.trim())
      .filter(Boolean);
  }

  const defaults = {
    flood: ['MDRRMO', 'Barangay Captain'],
    fire: ['BFP', 'Barangay Captain'],
    medical: ['MDRRMO', 'Health Unit'],
    infrastructure: ['Municipal Engineering', 'Barangay Captain'],
    waste: ['Barangay Captain', 'Sanitation Team'],
    other: ['Barangay Captain']
  };

  return defaults[category] || defaults.other;
}

function normalizeLocationText(row, barangay) {
  const candidates = [
    row.location_text,
    row.location,
    row.address,
    row.street,
    row.street_name,
    row.nearby_street,
    row.landmark
  ];

  const found = candidates.find(v => typeof v === 'string' && v.trim());
  if (found) return found.trim();

  return `Near a local street in ${barangay || 'the reported barangay'}`;
}

/**
 * Maps a Supabase DB row to the MapSumbong incident schema
 * Adjust field names to match your actual Supabase table columns
 */
function mapRow(row) {
  const category = deriveCategory(row.issue_type);
  const severity = normalizeSeverity(row.urgency);
  const barangay = row.barangay || 'Unknown Barangay';
  const locationText = normalizeLocationText(row, barangay);
  const resolutionState = buildResolutionState(row);

  return {
    id: row.id,
    type: prettifyIssueType(row.issue_type),
    category,
    severity,
    barangay,
    location: locationText,
    lat: parseFloat(row.latitude) || 14.6,
    lng: parseFloat(row.longitude) || 121.0,
    reports: Number(row.report_count || row.reports || 1),
    time: formatTime(row.created_at),
    channel: row.channel || 'App',
    description: row.description || 'No additional details were provided by the reporter.',
    ai: row.ai_assessment || row.ai || buildAiFallback({ severity, category, barangay }),
    action: row.immediate_action || row.action || buildActionFallback({ severity, category }),
    authorities: normalizeAuthorities(row, category),
    resolved: resolutionState.resolved,
    resolutionNote: resolutionState.resolutionNote,
    resolutionPhotoUrl: resolutionState.resolutionPhotoUrl,
    resolutionComplete: resolutionState.resolutionComplete,
    resolutionPendingProof: resolutionState.resolutionPendingProof,
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
