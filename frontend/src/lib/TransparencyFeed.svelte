<script>
  import { incidents } from './store.js';
  export let open = false;

  const SEV = {
    critical: { color:'#ff4560', bg:'rgba(255,69,96,0.12)' },
    high:     { color:'#ff8c00', bg:'rgba(255,140,0,0.12)' },
    medium:   { color:'#f5c800', bg:'rgba(245,200,0,0.12)' },
    low:      { color:'#00c896', bg:'rgba(0,200,150,0.12)' }
  };

  const CAT_SVG = {
    flood:`<svg viewBox="0 0 24 24" fill="currentColor" width="16" height="16"><path d="M3 13c1.5 0 1.5-1 3-1s1.5 1 3 1 1.5-1 3-1 1.5 1 3 1 1.5-1 3-1v2c-1.5 0-1.5 1-3 1s-1.5-1-3-1-1.5 1-3 1-1.5-1-3-1-1.5 1-3 1zm0 4c1.5 0 1.5-1 3-1s1.5 1 3 1 1.5-1 3-1 1.5 1 3 1 1.5-1 3-1v2c-1.5 0-1.5 1-3 1s-1.5-1-3-1-1.5 1-3 1-1.5-1-3-1-1.5 1-3 1zM11.5 1l3 7H13v3h-2V8H9.5z"/></svg>`,
    fire:`<svg viewBox="0 0 24 24" fill="currentColor" width="16" height="16"><path d="M17.66 11.2c-.23-.3-.51-.56-.77-.82-.67-.6-1.43-1.03-2.07-1.67C13.33 7.3 13 4.65 13.95 2c-1 .23-1.98.68-2.83 1.23-2.86 1.94-3.99 5.44-3.15 8.86.06.31-.01.63-.23.85C5.5 12.9 4 14.74 4 16.8c0 2.76 2.24 5 5 5 2.76 0 5-2.24 5-5 0-1.38-.56-2.64-1.47-3.55-.43.6-.75 1.28-.9 1.97.84.62 1.6 1.34 2.17 2.23.53.83.83 1.78.83 2.76 0 2.42-1.67 4.46-3.93 5.01A5.005 5.005 0 0 0 17.66 11.2z"/></svg>`,
    infrastructure:`<svg viewBox="0 0 24 24" fill="currentColor" width="16" height="16"><path d="M22 9V7h-2V5c0-1.1-.9-2-2-2H4c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2v-2h2v-2h-2v-2h2v-2h-2V9h2zm-4 10H4V5h14v14zM6 13h5v4H6zm6 0h3v2h-3zm0-4h3v2h-3zM6 7h5v5H6z"/></svg>`,
    medical:`<svg viewBox="0 0 24 24" fill="currentColor" width="16" height="16"><path d="M19 3H5c-1.1 0-1.99.9-1.99 2L3 19c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-1 11h-4v4h-4v-4H6v-4h4V6h4v4h4v4z"/></svg>`,
    waste:`<svg viewBox="0 0 24 24" fill="currentColor" width="16" height="16"><path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z"/></svg>`,
    other:`<svg viewBox="0 0 24 24" fill="currentColor" width="16" height="16"><path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/></svg>`
  };

  function hasText(value) {
    return typeof value === 'string' && value.trim().length > 0;
  }

  function isResolutionComplete(inc) {
    if (!inc?.resolved) return false;
    if (typeof inc.resolutionComplete === 'boolean') {
      return inc.resolutionComplete;
    }
    return hasText(inc.resolutionNote) && hasText(inc.resolutionPhotoUrl);
  }

  function isResolutionPendingProof(inc) {
    return Boolean(inc?.resolved) && !isResolutionComplete(inc);
  }

  $: sorted = [...$incidents].sort((a,b) => b.id - a.id);
  $: resolved = $incidents.filter(i => i.resolved).length;
  $: completed = $incidents.filter(i => isResolutionComplete(i)).length;
  $: pendingProof = $incidents.filter(i => isResolutionPendingProof(i)).length;
  $: open_count = $incidents.filter(i => !i.resolved).length;
  $: rate = $incidents.length ? Math.round(completed/$incidents.length*100) : 0;
</script>

{#if open}
  <div class="overlay" on:click|self={() => open=false} role="presentation">
    <div class="modal">
      <div class="modal-header">
        <div class="modal-title-row">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="#00c896"><circle cx="12" cy="12" r="10"/><path d="M2 12h20M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z" fill="none" stroke="#00c896" stroke-width="1.5"/></svg>
          <span class="modal-title">Public Transparency Feed</span>
        </div>
        <p class="modal-sub">All verified community reports — publicly visible, no login required</p>
        <button class="close-btn" on:click={() => open=false} aria-label="Close transparency feed">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M18 6 6 18M6 6l12 12"/></svg>
        </button>
      </div>

      <div class="stats-row">
        <div class="stat-box">
          <div class="stat-n">{$incidents.length}</div>
          <div class="stat-l">Total</div>
        </div>
        <div class="stat-box">
          <div class="stat-n" style="color:#ff4560">{open_count}</div>
          <div class="stat-l">Open</div>
        </div>
        <div class="stat-box">
          <div class="stat-n" style="color:#f5c800">{pendingProof}</div>
          <div class="stat-l">Pending Proof</div>
        </div>
        <div class="stat-box">
          <div class="stat-n" style="color:#00c896">{completed}</div>
          <div class="stat-l">Completed</div>
        </div>
        <div class="stat-box">
          <div class="stat-n" style="color:#00c896">{rate}%</div>
          <div class="stat-l">Completion rate</div>
        </div>
      </div>

      <div class="feed-list">
        {#each sorted as inc (inc.id)}
          {@const sev = SEV[inc.severity]}
          <div class="feed-row" class:resolved={isResolutionComplete(inc)} class:pending={isResolutionPendingProof(inc)}>
            <div class="feed-avatar" style="background:{sev.bg};color:{sev.color}">
              {@html CAT_SVG[inc.category]||CAT_SVG.other}
            </div>
            <div class="feed-body">
              <div class="feed-top">
                <span class="feed-name">{inc.type}</span>
                <span class="feed-sev" style="background:{sev.bg};color:{sev.color}">{inc.severity}</span>
              </div>
              <div class="feed-loc">{inc.barangay} · {inc.location}</div>
              <div class="feed-meta">{inc.reports} reports · {inc.time} · {inc.channel}</div>
            </div>
            <div class="feed-status" class:resolved={isResolutionComplete(inc)} class:pending={isResolutionPendingProof(inc)}>
              <div
                class="status-pip"
                class:green={isResolutionComplete(inc)}
                class:yellow={isResolutionPendingProof(inc)}
                class:red={!inc.resolved}
              ></div>
              {#if isResolutionComplete(inc)}
                Completed
              {:else if isResolutionPendingProof(inc)}
                Resolved - Pending Proof
              {:else}
                Open
              {/if}
            </div>
          </div>
        {/each}
      </div>

      <div class="modal-footer">
        Updated in real time · No personal data displayed · MapSumbong · SDG 11.3, 11.5, 11.6
      </div>
    </div>
  </div>
{/if}

<style>
  .overlay {
    position: fixed; inset: 0;
    background: rgba(0,0,0,0.75);
    z-index: 9000;
    display: flex; align-items: center; justify-content: center;
    animation: fadein 0.2s ease;
  }
  @keyframes fadein { from{opacity:0} to{opacity:1} }

  .modal {
    width: 600px; max-width: 95vw; max-height: 85vh;
    background: #0e0e14;
    border: 1px solid rgba(255,255,255,0.08);
    border-radius: 20px;
    display: flex; flex-direction: column; overflow: hidden;
    animation: up 0.25s cubic-bezier(0.34,1.56,0.64,1);
  }
  @keyframes up { from{opacity:0;transform:translateY(20px)} to{opacity:1;transform:none} }

  .modal-header {
    padding: 18px 20px 14px; position: relative;
    border-bottom: 1px solid rgba(255,255,255,0.06);
    flex-shrink: 0;
  }
  .modal-title-row { display: flex; align-items: center; gap: 8px; margin-bottom: 4px; }
  .modal-title { font-size: 16px; font-weight: 700; color: #e8e8f0; font-family: 'Inter', sans-serif; }
  .modal-sub { font-size: 12px; color: #404050; }
  .close-btn {
    position: absolute; top: 16px; right: 16px;
    background: rgba(255,255,255,0.06); border: none;
    width: 28px; height: 28px; border-radius: 8px;
    display: flex; align-items: center; justify-content: center;
    cursor: pointer; color: #505060; transition: all 0.15s;
  }
  .close-btn:hover { background: rgba(255,255,255,0.1); color: #d0d0e0; }

  .stats-row {
    display: grid; grid-template-columns: repeat(5,1fr);
    border-bottom: 1px solid rgba(255,255,255,0.06);
    flex-shrink: 0;
  }
  .stat-box {
    padding: 14px 16px; text-align: center;
    border-right: 1px solid rgba(255,255,255,0.06);
  }
  .stat-box:last-child { border-right: none; }
  .stat-n { font-size: 22px; font-weight: 700; color: #e8e8f0; font-family: 'Inter', sans-serif; line-height: 1; }
  .stat-l { font-size: 11px; color: #404050; margin-top: 4px; }

  .feed-list {
    flex: 1; overflow-y: auto; padding: 8px 12px;
    scrollbar-width: thin; scrollbar-color: rgba(255,255,255,0.06) transparent;
  }

  .feed-row {
    display: flex; align-items: center; gap: 12px;
    padding: 10px 8px; border-radius: 10px;
    border-bottom: 1px solid rgba(255,255,255,0.04);
    transition: background 0.15s;
  }
  .feed-row:hover { background: rgba(255,255,255,0.03); }
  .feed-row.resolved { opacity: 0.45; }
  .feed-row.pending { opacity: 0.9; border-left: 2px solid rgba(245,200,0,0.4); }

  .feed-avatar {
    width: 36px; height: 36px; border-radius: 10px;
    display: flex; align-items: center; justify-content: center;
    flex-shrink: 0;
  }
  .feed-body { flex: 1; min-width: 0; }
  .feed-top { display: flex; align-items: center; gap: 8px; margin-bottom: 3px; }
  .feed-name { font-size: 13px; font-weight: 600; color: #d8d8e8; }
  .feed-sev { font-size: 10px; font-weight: 600; padding: 2px 7px; border-radius: 6px; text-transform: capitalize; }
  .feed-loc { font-size: 11px; color: #404050; margin-bottom: 2px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .feed-meta { font-size: 10px; color: #303040; }

  .feed-status {
    display: flex; align-items: center; gap: 5px;
    font-size: 11px; color: #ff4560; white-space: nowrap; flex-shrink: 0;
    font-weight: 500;
  }
  .feed-status.resolved { color: #00c896; }
  .feed-status.pending { color: #f5c800; }
  .status-pip { width: 6px; height: 6px; border-radius: 50%; flex-shrink: 0; }
  .status-pip.red { background: #ff4560; animation: blink 2s step-end infinite; }
  .status-pip.yellow { background: #f5c800; }
  .status-pip.green { background: #00c896; }
  @keyframes blink { 0%,100%{opacity:1} 50%{opacity:0.2} }

  .modal-footer {
    padding: 10px 20px; font-size: 10px; color: #303040;
    border-top: 1px solid rgba(255,255,255,0.05);
    text-align: center; flex-shrink: 0;
  }
</style>
