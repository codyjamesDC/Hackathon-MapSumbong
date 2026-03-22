<script>
  import { incidents, selectedIncident, toastMsg, severityConfig } from './store.js';

  let open = false;
  let loading = false;
  let channel = 'Telegram';
  let inputType = 'text';
  let message = '';
  let previewResult = null;

  const CHANNELS = ['Telegram', 'SMS', 'Messenger', 'Viber', 'Voice call'];
  const INPUT_TYPES = ['text', 'voice', 'photo'];

  const SAMPLE_REPORTS = [
    {
      message: "Grabe ang baha dito sa may gate ng elementarya namin sa Brgy. Nangka. Tuhod na halos ang tubig.",
      type: 'Flash Flood', category: 'flood', severity: 'critical',
      barangay: 'Brgy. Nangka', location: 'Near Nangka Elementary gate',
      lat: 14.6510 + (Math.random()-0.5)*0.01, lng: 121.1012 + (Math.random()-0.5)*0.01,
      ai: 'Flash flood confirmed. Knee-level water at school entrance — children and pedestrians at high risk. Cluster forming.',
      action: 'Lumikas na agad. Pumunta sa pinakamataas na lugar.',
      authorities: ['MDRRMO', 'Barangay Captain']
    },
    {
      message: "May sunog sa tabi ng palengke! Kumakalat na ang apoy.",
      type: 'Structure Fire', category: 'fire', severity: 'critical',
      barangay: 'Brgy. Tejeros', location: 'Tejeros Market area, Makati',
      lat: 14.5521 + (Math.random()-0.5)*0.01, lng: 121.0189 + (Math.random()-0.5)*0.01,
      ai: 'Active structure fire near market. High density area — rapid spread risk. BFP dispatch critical.',
      action: 'Lumayo sa gusali. Tumawag sa BFP: 160.',
      authorities: ['BFP', 'PNP', 'MDRRMO']
    },
    {
      message: "Nagsara ang daan sa may Quirino Highway. May malaking butas at tubig.",
      type: 'Road Hazard', category: 'infrastructure', severity: 'high',
      barangay: 'Brgy. Talipapa', location: 'Quirino Highway, Novaliches',
      lat: 14.7012 + (Math.random()-0.5)*0.01, lng: 121.0234 + (Math.random()-0.5)*0.01,
      ai: 'Major road obstruction on primary route. Pothole and flooding combination — vehicle damage risk high.',
      action: 'Iwasan ang Quirino Highway. Gumamit ng alternate routes.',
      authorities: ['MMDA', 'Barangay Tanod']
    },
    {
      message: "May matanda na nahihirapan huminga sa may kanto ng Rizal Ave.",
      type: 'Medical Emergency', category: 'medical', severity: 'high',
      barangay: 'Brgy. 596', location: 'Rizal Avenue corner, Manila',
      lat: 14.6012 + (Math.random()-0.5)*0.01, lng: 120.9834 + (Math.random()-0.5)*0.01,
      ai: 'Elderly person in respiratory distress. Possible cardiac event. Immediate EMS dispatch recommended.',
      action: 'Tumawag sa 911 agad. Huwag gumalaw ang pasyente.',
      authorities: ['PNP', 'MDRRMO']
    },
    {
      message: "Nagtatapon ng basura sa drainage canal namin. Delikado pag umuulan.",
      type: 'Illegal Dumping', category: 'waste', severity: 'medium',
      barangay: 'Brgy. Manggahan', location: 'Manggahan Floodway area',
      lat: 14.5923 + (Math.random()-0.5)*0.01, lng: 121.0956 + (Math.random()-0.5)*0.01,
      ai: 'Illegal dumping near floodway. Drainage blockage increases flood risk. Non-urgent but time-sensitive.',
      action: 'Iulat sa barangay hall. Huwag mag-dump ng basura sa drainage.',
      authorities: ['Barangay Captain']
    }
  ];

  function fillSample() {
    const s = SAMPLE_REPORTS[Math.floor(Math.random() * SAMPLE_REPORTS.length)];
    message = s.message;
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
      lat: matched.lat + (Math.random() - 0.5) * 0.02,
      lng: matched.lng + (Math.random() - 0.5) * 0.02,
      reports: Math.floor(Math.random() * 6) + 1,
      time: 'Just now',
      channel,
      description: message,
      resolved: false,
      radius: 100 + Math.random() * 200
    };

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
