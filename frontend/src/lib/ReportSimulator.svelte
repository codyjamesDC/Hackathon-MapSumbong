<script>
  import { incidents, selectedIncident, toastMsg, severityConfig } from './store.js';

  let open = false;
  let loading = false;
  let channel = 'Telegram';
  let inputType = 'text';
  let message = '';
  let barangay = 'Anos';
  let previewResult = null;

  const CHANNELS = ['Telegram', 'SMS', 'Messenger', 'Viber', 'Voice call'];
  const INPUT_TYPES = ['text', 'voice', 'photo'];

  // Los Baños, Laguna barangays - from Overpass Turbo
  const LOS_BANOS_BARANGAYS = [
    'Anos',
    'Bagong Silang',
    'Bambang',
    'Batong Malake',
    'Baybayin',
    'Bayog',
    'Lalakay',
    'Maahas',
    'Malinta',
    'Mayondon',
    'Putho-Tuntungin',
    'San Antonio',
    'Tadlac',
    'Timugan'
  ];

  // Barangay coordinates for auto-detection - from Overpass Turbo boundaries
  const BARANGAY_COORDS = {
    'Anos': { lat: 14.173906, lng: 121.233077 },
    'Bagong Silang': { lat: 14.139438, lng: 121.210343 },
    'Bambang': { lat: 14.17166, lng: 121.21682 },
    'Batong Malake': { lat: 14.159099, lng: 121.230251 },
    'Baybayin': { lat: 14.181197, lng: 121.223237 },
    'Bayog': { lat: 14.189349, lng: 121.249352 },
    'Lalakay': { lat: 14.170333, lng: 121.208158 },
    'Maahas': { lat: 14.171918, lng: 121.257908 },
    'Malinta': { lat: 14.184989, lng: 121.231089 },
    'Mayondon': { lat: 14.189879, lng: 121.238891 },
    'Putho-Tuntungin': { lat: 14.153004, lng: 121.249828 },
    'San Antonio': { lat: 14.174239, lng: 121.247285 },
    'Tadlac': { lat: 14.179379, lng: 121.206832 },
    'Timugan': { lat: 14.170458, lng: 121.222579 }
  };

  // Detect barangay from coordinates
  function detectBarangay(lat, lng) {
    let closestBarangay = 'Anos';
    let minDistance = Infinity;

    Object.entries(BARANGAY_COORDS).forEach(([brgy, coords]) => {
      const distance = Math.sqrt((lat - coords.lat) ** 2 + (lng - coords.lng) ** 2);
      if (distance < minDistance) {
        minDistance = distance;
        closestBarangay = brgy;
      }
    });

    return closestBarangay;
  }

  const SAMPLE_REPORTS = [
    {
      message: "Grabe ang baha dito sa Baybayin, tuhod na ang tubig sa daan.",
      type: 'Flash Flood', category: 'flood', severity: 'critical',
      barangay: 'Baybayin', location: 'Main road, Baybayin',
      lat: 14.181197 + (Math.random()-0.5)*0.003, lng: 121.223237 + (Math.random()-0.5)*0.003,
      ai: 'Flash flood confirmed. Significant water accumulation in downtown area.',
      action: 'Lumikas na agad. Pumunta sa pinakamataas na lugar.',
      authorities: ['MDRRMO', 'Barangay Captain']
    },
    {
      message: "May sunog sa Batong Malake, kumakalat na ang apoy sa isang bahay.",
      type: 'Structure Fire', category: 'fire', severity: 'critical',
      barangay: 'Batong Malake', location: 'Residential area, Batong Malake',
      lat: 14.159099 + (Math.random()-0.5)*0.003, lng: 121.230251 + (Math.random()-0.5)*0.003,
      ai: 'Active structure fire in residential area. Rapid response needed.',
      action: 'Lumayo sa gusali. Tumawag sa BFP: 160.',
      authorities: ['BFP', 'PNP', 'MDRRMO']
    },
    {
      message: "Malalim ang butas sa kalsada sa San Antonio at delikado sa mga motor.",
      type: 'Road Hazard', category: 'infrastructure', severity: 'high',
      barangay: 'San Antonio', location: 'Main Road, San Antonio',
      lat: 14.174239 + (Math.random()-0.5)*0.003, lng: 121.247285 + (Math.random()-0.5)*0.003,
      ai: 'Road obstruction with pothole and water accumulation. Vehicle hazard.',
      action: 'Iwasan ang lugar. Gumamit ng alternate routes.',
      authorities: ['MMDA', 'Barangay Tanod']
    },
    {
      message: "May matanda na nahihirapan huminga dito sa Maahas. Kailangan ng tulong.",
      type: 'Medical Emergency', category: 'medical', severity: 'high',
      barangay: 'Maahas', location: 'Residential area, Maahas',
      lat: 14.171918 + (Math.random()-0.5)*0.003, lng: 121.257908 + (Math.random()-0.5)*0.003,
      ai: 'Elderly person in respiratory distress. Immediate EMS dispatch recommended.',
      action: 'Tumawag sa 911 agad. Huwag gumalaw ang pasyente.',
      authorities: ['PNP', 'MDRRMO']
    },
    {
      message: "Maraming basura sa drainage dito sa Putho-Tuntungin, barado na.",
      type: 'Illegal Dumping', category: 'waste', severity: 'medium',
      barangay: 'Putho-Tuntungin', location: 'Drainage area, Putho-Tuntungin',
      lat: 14.153004 + (Math.random()-0.5)*0.003, lng: 121.249828 + (Math.random()-0.5)*0.003,
      ai: 'Drainage blockage from accumulated garbage. Flood risk concern.',
      action: 'Iulat sa barangay hall. Huwag mag-dump ng basura.',
      authorities: ['Barangay Captain']
    }
  ];

  function fillSample() {
    const s = SAMPLE_REPORTS[Math.floor(Math.random() * SAMPLE_REPORTS.length)];
    message = s.message;
    barangay = s.barangay;
  }

  async function submitReport() {
    if (!message.trim()) return;
    loading = true;
    previewResult = null;

    // Simulate AI triage delay
    await new Promise(r => setTimeout(r, 2000 + Math.random() * 1000));

    // Match to closest sample or generate generic
    const matched = SAMPLE_REPORTS.find(s =>
      message.toLowerCase().includes('baha') ? s.category === 'flood' :
      message.toLowerCase().includes('sunog') ? s.category === 'fire' :
      message.toLowerCase().includes('daan') || message.toLowerCase().includes('kalsada') ? s.category === 'infrastructure' :
      message.toLowerCase().includes('basura') ? s.category === 'waste' :
      s.category === 'medical'
    ) || SAMPLE_REPORTS[0];

    const newInc = {
      ...matched,
      id: Date.now(),
      lat: (BARANGAY_COORDS[barangay]?.lat ?? matched.lat) + (Math.random() - 0.5) * 0.003,
      lng: (BARANGAY_COORDS[barangay]?.lng ?? matched.lng) + (Math.random() - 0.5) * 0.003,
      reports: Math.floor(Math.random() * 6) + 1,
      time: 'Just now',
      channel,
      description: message,
      barangay,
      location: `Near barangay hall, ${barangay}`,
      resolved: false,
      radius: 100 + Math.random() * 200
    };

    // Auto-detect barangay from coordinates
    const detectedBarangay = detectBarangay(newInc.lat, newInc.lng);
    newInc.barangay = detectedBarangay;

    previewResult = newInc;
    loading = false;
  }

  function confirmSubmit() {
    if (!previewResult) return;
    incidents.update(list => {
      // Check cluster
      const nearby = list.filter(i =>
        !i.resolved &&
        i.category === previewResult.category &&
        Math.abs(i.lat - previewResult.lat) < 0.005 &&
        Math.abs(i.lng - previewResult.lng) < 0.005
      );
      const finalInc = {
        ...previewResult,
        reports: previewResult.reports + nearby.length
      };
      selectedIncident.set(finalInc);
      return [finalInc, ...list];
    });
    toastMsg.set(`Report triaged. ${previewResult.authorities.join(', ')} notified via SMS.`);
    message = '';
    previewResult = null;
    open = false;
  }
</script>

<div class="sim-wrapper">
  <button class="sim-toggle" on:click={() => open = !open} class:active={open}>
    {open ? '✕ Close' : '＋ Simulate Incoming Report'}
  </button>

  {#if open}
    <div class="sim-panel">
      <div class="sim-header">
        <span class="sim-title">AI Triage Simulator</span>
        <span class="sim-sub">Test the report pipeline</span>
      </div>

      <div class="field">
        <label>Channel</label>
        <div class="channel-pills">
          {#each CHANNELS as ch}
            <button class="ch-pill" class:active={channel===ch} on:click={() => channel=ch}>{ch}</button>
          {/each}
        </div>
      </div>

      <div class="field">
        <label>Input type</label>
        <div class="type-pills">
          {#each INPUT_TYPES as t}
            <button class="ch-pill" class:active={inputType===t} on:click={() => inputType=t}>{t}</button>
          {/each}
        </div>
      </div>

      <div class="field">
        <label>Barangay</label>
        <select bind:value={barangay} class="barangay-select">
          {#each LOS_BANOS_BARANGAYS as brgy}
            <option value={brgy}>{brgy}</option>
          {/each}
        </select>
      </div>

      <div class="field">
        <label>
          Message
          <button class="sample-btn" on:click={fillSample}>use sample</button>
        </label>
        <textarea
          bind:value={message}
          placeholder="Ilarawan ang problema sa Filipino o English..."
          rows="3"
        ></textarea>
      </div>

      {#if !previewResult}
        <button class="triage-btn" on:click={submitReport} disabled={loading || !message.trim()}>
          {#if loading}
            <span class="spinner"></span> AI is triaging...
          {:else}
            Send to AI triage
          {/if}
        </button>
      {:else}
        <div class="preview">
          <div class="preview-label">AI triage result</div>
          <div class="preview-row">
            <span class="sev-tag" style="background:{severityConfig[previewResult.severity].bg};color:{severityConfig[previewResult.severity].color}">
              {previewResult.severity}
            </span>
            <span class="preview-type">{previewResult.type}</span>
          </div>
          <div class="preview-loc">📍 {previewResult.location}</div>
          <div class="preview-auth">→ {previewResult.authorities.join(', ')}</div>
          <div class="preview-action-row">
            <button class="confirm-btn" on:click={confirmSubmit}>Confirm &amp; add to dashboard</button>
            <button class="retry-btn" on:click={() => { previewResult = null; }}>Retriage</button>
          </div>
        </div>
      {/if}
    </div>
  {/if}
</div>

<style>
  .sim-wrapper {
    position: absolute;
    bottom: 20px;
    left: 316px;
    z-index: 900;
  }

  .sim-toggle {
    padding: 8px 16px;
    background: #111827;
    border: 1px solid rgba(255,255,255,0.12);
    border-radius: 8px;
    color: #f0f4ff;
    font-size: 12px;
    font-weight: 500;
    cursor: pointer;
    font-family: 'DM Sans', sans-serif;
    transition: all 0.2s;
    box-shadow: 0 4px 20px rgba(0,0,0,0.4);
  }
  .sim-toggle:hover, .sim-toggle.active { background: #1a2235; border-color: #00d4aa; color: #00d4aa; }

  .sim-panel {
    position: absolute;
    bottom: 44px;
    left: 0;
    width: 300px;
    background: #111827;
    border: 1px solid rgba(255,255,255,0.1);
    border-radius: 10px;
    padding: 14px;
    box-shadow: 0 20px 60px rgba(0,0,0,0.6);
    animation: slideup 0.2s ease;
  }
  @keyframes slideup { from { opacity:0; transform:translateY(10px); } to { opacity:1; transform:translateY(0); } }

  .sim-header { margin-bottom: 12px; }
  .sim-title { font-size: 13px; font-weight: 600; color: #f0f4ff; font-family: 'Syne', sans-serif; display: block; }
  .sim-sub { font-size: 11px; color: #4a5568; }

  .field { margin-bottom: 10px; }
  label { font-size: 10px; font-weight: 500; color: #4a5568; text-transform: uppercase; letter-spacing: 0.8px; display: flex; align-items: center; justify-content: space-between; margin-bottom: 5px; }

  .channel-pills, .type-pills { display: flex; flex-wrap: wrap; gap: 4px; }
  .ch-pill {
    padding: 3px 9px; border-radius: 20px;
    border: 1px solid rgba(255,255,255,0.1);
    background: transparent; color: #8892aa;
    font-size: 11px; cursor: pointer;
    font-family: 'DM Sans', sans-serif;
    transition: all 0.15s;
  }
  .ch-pill:hover { border-color: rgba(255,255,255,0.2); color: #f0f4ff; }
  .ch-pill.active { background: #00d4aa; border-color: #00d4aa; color: #0a0e1a; font-weight: 500; }

  .sample-btn {
    font-size: 10px; color: #00d4aa; background: none; border: none;
    cursor: pointer; font-family: 'DM Sans', sans-serif; padding: 0;
  }
  .sample-btn:hover { text-decoration: underline; }

  textarea {
    width: 100%; padding: 8px 10px;
    background: rgba(255,255,255,0.05);
    border: 1px solid rgba(255,255,255,0.1);
    border-radius: 6px; color: #f0f4ff;
    font-size: 12px; font-family: 'DM Sans', sans-serif;
    line-height: 1.5; resize: none;
    transition: border-color 0.15s;
  }
  textarea::placeholder { color: #4a5568; }
  textarea:focus { outline: none; border-color: rgba(0,212,170,0.4); }

  .barangay-select {
    width: 100%; padding: 8px 10px;
    background: rgba(255,255,255,0.05);
    border: 1px solid rgba(255,255,255,0.1);
    border-radius: 6px; color: #f0f4ff;
    font-size: 12px; font-family: 'DM Sans', sans-serif;
    transition: border-color 0.15s;
    cursor: pointer;
  }
  .barangay-select option { background: #111827; color: #f0f4ff; }
  .barangay-select:focus { outline: none; border-color: rgba(0,212,170,0.4); }

  .triage-btn {
    width: 100%; padding: 9px;
    background: #00d4aa; color: #0a0e1a;
    border: none; border-radius: 6px;
    font-size: 12px; font-weight: 600;
    cursor: pointer; font-family: 'DM Sans', sans-serif;
    display: flex; align-items: center; justify-content: center; gap: 8px;
    transition: background 0.15s;
  }
  .triage-btn:hover { background: #00b894; }
  .triage-btn:disabled { background: rgba(0,212,170,0.3); color: rgba(10,14,26,0.5); cursor: not-allowed; }

  .spinner {
    width: 12px; height: 12px; border-radius: 50%;
    border: 2px solid rgba(10,14,26,0.3);
    border-top-color: #0a0e1a;
    animation: spin 0.8s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }

  .preview {
    background: rgba(0,212,170,0.06);
    border: 1px solid rgba(0,212,170,0.2);
    border-radius: 6px; padding: 10px;
    animation: fadein 0.3s ease;
  }
  @keyframes fadein { from{opacity:0} to{opacity:1} }
  .preview-label { font-size: 10px; color: #00d4aa; text-transform: uppercase; letter-spacing: 0.8px; margin-bottom: 6px; }
  .preview-row { display: flex; align-items: center; gap: 8px; margin-bottom: 5px; }
  .sev-tag { font-size: 10px; font-weight: 600; padding: 2px 7px; border-radius: 4px; text-transform: capitalize; }
  .preview-type { font-size: 13px; font-weight: 600; color: #f0f4ff; }
  .preview-loc { font-size: 11px; color: #8892aa; margin-bottom: 3px; }
  .preview-auth { font-size: 11px; color: #6ab4ff; margin-bottom: 10px; }
  .preview-action-row { display: flex; gap: 6px; }
  .confirm-btn {
    flex: 1; padding: 7px; background: #00d4aa; color: #0a0e1a;
    border: none; border-radius: 5px; font-size: 11px; font-weight: 600;
    cursor: pointer; font-family: 'DM Sans', sans-serif;
  }
  .confirm-btn:hover { background: #00b894; }
  .retry-btn {
    padding: 7px 12px; background: transparent;
    border: 1px solid rgba(255,255,255,0.12); color: #8892aa;
    border-radius: 5px; font-size: 11px; cursor: pointer;
    font-family: 'DM Sans', sans-serif;
  }
  .retry-btn:hover { border-color: rgba(255,255,255,0.25); color: #f0f4ff; }
</style>
