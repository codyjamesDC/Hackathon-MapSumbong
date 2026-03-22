<script>
  import { selectedIncident, incidents, toastMsg } from './store.js';

  const SEV = {
    critical: { color:'#ff4560', bg:'rgba(255,69,96,0.1)' },
    high:     { color:'#ff8c00', bg:'rgba(255,140,0,0.1)' },
    medium:   { color:'#f5c800', bg:'rgba(245,200,0,0.1)' },
    low:      { color:'#00c896', bg:'rgba(0,200,150,0.1)' }
  };

  const CAT_SVG = {
    flood: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M3 13c1.5 0 1.5-1 3-1s1.5 1 3 1 1.5-1 3-1 1.5 1 3 1 1.5-1 3-1v2c-1.5 0-1.5 1-3 1s-1.5-1-3-1-1.5 1-3 1-1.5-1-3-1-1.5 1-3 1zm0 4c1.5 0 1.5-1 3-1s1.5 1 3 1 1.5-1 3-1 1.5 1 3 1 1.5-1 3-1v2c-1.5 0-1.5 1-3 1s-1.5-1-3-1-1.5 1-3 1-1.5-1-3-1-1.5 1-3 1zM11.5 1l3 7H13v3h-2V8H9.5z"/></svg>`,
    fire: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M17.66 11.2c-.23-.3-.51-.56-.77-.82-.67-.6-1.43-1.03-2.07-1.67C13.33 7.3 13 4.65 13.95 2c-1 .23-1.98.68-2.83 1.23-2.86 1.94-3.99 5.44-3.15 8.86.06.31-.01.63-.23.85-.22.2-.56.27-.84.14-.28-.12-.48-.42-.51-.72C5.5 12.9 4 14.74 4 16.8c0 2.76 2.24 5 5 5 2.76 0 5-2.24 5-5 0-1.38-.56-2.64-1.47-3.55-.43.6-.75 1.28-.9 1.97.84.62 1.6 1.34 2.17 2.23.53.83.83 1.78.83 2.76 0 2.42-1.67 4.46-3.93 5.01A5.005 5.005 0 0 0 17.66 11.2z"/></svg>`,
    infrastructure: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M22 9V7h-2V5c0-1.1-.9-2-2-2H4c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2v-2h2v-2h-2v-2h2v-2h-2V9h2zm-4 10H4V5h14v14zM6 13h5v4H6zm6 0h3v2h-3zm0-4h3v2h-3zM6 7h5v5H6z"/></svg>`,
    medical: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M19 3H5c-1.1 0-1.99.9-1.99 2L3 19c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-1 11h-4v4h-4v-4H6v-4h4V6h4v4h4v4z"/></svg>`,
    waste: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z"/></svg>`,
    other: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/></svg>`
  };

  $: inc = $selectedIncident;
  $: sev = inc ? SEV[inc.severity] : null;

  function close() { selectedIncident.set(null); }
  function resolve() {
    incidents.update(l => l.map(i => i.id === inc.id ? {...i, resolved:true} : i));
    toastMsg.set('Resolved. SMS confirmation sent to reporter.');
    selectedIncident.set(null);
  }
</script>

{#if inc && sev}
  <div class="card">
    <!-- Header -->
    <div class="card-header">
      <div class="cat-icon" style="background:{sev.bg};color:{sev.color}">
        <div class="icon-svg">{@html CAT_SVG[inc.category]||CAT_SVG.other}</div>
      </div>
      <div class="header-text">
        <div class="card-title">{inc.type}</div>
        <div class="card-sub">{inc.barangay}</div>
      </div>
      <button class="close-btn" on:click={close}>
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><path d="M18 6 6 18M6 6l12 12"/></svg>
      </button>
    </div>

    <!-- Pills -->
    <div class="pills">
      <div class="pill" style="background:{sev.bg};color:{sev.color}">{inc.severity}</div>
      <div class="pill ch">{inc.channel}</div>
      <div class="pill tm">{inc.time}</div>
      {#if inc.resolved}<div class="pill res">✓ resolved</div>{/if}
    </div>

    <!-- Report count -->
    <div class="count-row" style="border-color:{sev.color}22">
      <div class="count-big" style="color:{sev.color}">{inc.reports}</div>
      <div class="count-info">
        <div class="count-label">community reports</div>
        <div class="count-bar"><div class="count-fill" style="width:{Math.min(inc.reports/20*100,100)}%;background:{sev.color}"></div></div>
        {#if inc.reports >= 10}
          <div class="cluster-tag" style="color:{sev.color}">
            <svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor"><path d="M7 2v11h3v9l7-12h-4l4-8z"/></svg>
            Captain auto-alerted
          </div>
        {:else if inc.reports >= 3}
          <div class="cluster-tag warn">
            <svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2L1 21h22L12 2z"/></svg>
            Cluster forming
          </div>
        {/if}
      </div>
    </div>

    <div class="body">
      <div class="sec">
        <div class="sec-label">Original report</div>
        <div class="quote">"{inc.description}"</div>
      </div>

      <div class="sec">
        <div class="sec-label ai">
          <svg width="10" height="10" viewBox="0 0 24 24" fill="#00c896"><circle cx="12" cy="12" r="10"/></svg>
          AI assessment
        </div>
        <div class="ai-box">{inc.ai}</div>
      </div>

      <div class="sec">
        <div class="sec-label">Sent to reporter</div>
        <div class="action-box">{inc.action}</div>
      </div>

      <div class="sec">
        <div class="sec-label">Authorities notified</div>
        <div class="auth-row">
          {#each inc.authorities as a}
            <span class="auth-tag">{a}</span>
          {/each}
        </div>
      </div>

      <div class="sec">
        <div class="sec-label">Coordinates</div>
        <div class="coords">{inc.lat.toFixed(4)}°N, {inc.lng.toFixed(4)}°E</div>
      </div>
    </div>

    <div class="card-footer">
      {#if !inc.resolved}
        <button class="resolve-btn" on:click={resolve}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6 9 17l-5-5"/></svg>
          Mark as Resolved
        </button>
      {:else}
        <div class="resolved-row">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#00c896" stroke-width="2.5"><path d="M20 6 9 17l-5-5"/></svg>
          Report resolved
        </div>
      {/if}
    </div>
  </div>
{/if}

<style>
  .card {
    position: absolute;
    top: 76px;
    right: 16px;
    bottom: 80px;
    width: 290px;
    z-index: 400;
    background: rgba(14,14,20,0.92);
    backdrop-filter: blur(20px) saturate(1.8);
    -webkit-backdrop-filter: blur(20px) saturate(1.8);
    border: 1px solid rgba(255,255,255,0.08);
    border-radius: 20px;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    box-shadow: 0 24px 64px rgba(0,0,0,0.5);
    animation: slidein 0.25s cubic-bezier(0.34,1.56,0.64,1);
  }
  @keyframes slidein { from{opacity:0;transform:translateX(20px) scale(0.97)} to{opacity:1;transform:none} }

  .card-header {
    display: flex; align-items: center; gap: 10px;
    padding: 14px 14px 10px;
    flex-shrink: 0;
  }
  .cat-icon {
    width: 40px; height: 40px; border-radius: 12px;
    display: flex; align-items: center; justify-content: center;
    flex-shrink: 0;
  }
  .icon-svg { width: 20px; height: 20px; display: flex; }
  .header-text { flex: 1; min-width: 0; }
  .card-title { font-size: 14px; font-weight: 700; color: #e8e8f0; }
  .card-sub { font-size: 11px; color: #505060; margin-top: 1px; }
  .close-btn {
    background: rgba(255,255,255,0.06); border: none;
    width: 26px; height: 26px; border-radius: 8px;
    display: flex; align-items: center; justify-content: center;
    cursor: pointer; color: #505060; flex-shrink: 0; transition: all 0.15s;
  }
  .close-btn:hover { background: rgba(255,255,255,0.1); color: #d0d0e0; }

  .pills { display: flex; gap: 4px; flex-wrap: wrap; padding: 0 14px 10px; flex-shrink: 0; }
  .pill { font-size: 10px; font-weight: 600; padding: 2px 8px; border-radius: 6px; text-transform: capitalize; background: rgba(255,255,255,0.06); color: #505060; }
  .pill.ch { background: rgba(124,134,255,0.12); color: #7c86ff; }
  .pill.tm { color: #404050; }
  .pill.res { background: rgba(0,200,150,0.1); color: #00c896; }

  .count-row {
    margin: 0 14px 10px;
    background: rgba(255,255,255,0.03);
    border: 1px solid;
    border-radius: 12px;
    padding: 12px;
    display: flex;
    align-items: center;
    gap: 12px;
    flex-shrink: 0;
  }
  .count-big { font-size: 32px; font-weight: 800; line-height: 1; flex-shrink: 0; }
  .count-info { flex: 1; }
  .count-label { font-size: 11px; color: #505060; margin-bottom: 5px; }
  .count-bar { height: 3px; background: rgba(255,255,255,0.06); border-radius: 2px; overflow: hidden; margin-bottom: 5px; }
  .count-fill { height: 100%; border-radius: 2px; }
  .cluster-tag { font-size: 10px; font-weight: 600; display: flex; align-items: center; gap: 3px; }
  .cluster-tag.warn { color: #ff8c00; }

  .body { flex: 1; overflow-y: auto; padding: 0 14px 4px; scrollbar-width: thin; scrollbar-color: rgba(255,255,255,0.05) transparent; }

  .sec { margin-bottom: 11px; }
  .sec-label { font-size: 10px; font-weight: 600; color: #404050; text-transform: uppercase; letter-spacing: 0.8px; margin-bottom: 5px; display: flex; align-items: center; gap: 5px; }
  .sec-label.ai { color: #00c896; }

  .quote { font-size: 12px; color: #505060; font-style: italic; line-height: 1.6; padding: 7px 10px; background: rgba(255,255,255,0.03); border-left: 2px solid rgba(255,255,255,0.07); border-radius: 0 6px 6px 0; }
  .ai-box { font-size: 12px; color: #909090; line-height: 1.6; padding: 9px; background: rgba(0,200,150,0.05); border: 1px solid rgba(0,200,150,0.1); border-radius: 8px; }
  .action-box { font-size: 12px; color: #c0c0d0; line-height: 1.6; padding: 7px 10px; background: rgba(255,255,255,0.04); border-radius: 8px; }
  .auth-row { display: flex; flex-wrap: wrap; gap: 4px; }
  .auth-tag { font-size: 11px; padding: 3px 9px; border-radius: 6px; background: rgba(124,134,255,0.1); color: #7c86ff; }
  .coords { font-size: 11px; color: #505060; font-family: monospace; background: rgba(255,255,255,0.03); padding: 6px 10px; border-radius: 6px; }

  .card-footer { padding: 12px 14px; border-top: 1px solid rgba(255,255,255,0.06); flex-shrink: 0; }
  .resolve-btn {
    width: 100%; padding: 10px;
    background: #00c896; color: #0a1a14;
    border: none; border-radius: 12px;
    font-size: 13px; font-weight: 700;
    cursor: pointer; font-family: 'Inter', sans-serif;
    transition: all 0.15s;
    display: flex; align-items: center; justify-content: center; gap: 7px;
  }
  .resolve-btn:hover { background: #00b584; transform: translateY(-1px); box-shadow: 0 4px 16px rgba(0,200,150,0.3); }
  .resolve-btn:active { transform: none; box-shadow: none; }
  .resolved-row { display: flex; align-items: center; justify-content: center; gap: 6px; font-size: 12px; color: #00c896; padding: 8px; }
</style>
