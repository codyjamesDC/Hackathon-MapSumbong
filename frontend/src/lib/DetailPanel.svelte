<script>
  import { selectedIncident, incidents, severityConfig, categoryIcons, toastMsg } from './store.js';

  function close() { selectedIncident.set(null); }

  function resolve() {
    incidents.update(list =>
      list.map(i => i.id === $selectedIncident.id ? { ...i, resolved: true } : i)
    );
    toastMsg.set('Resolved. SMS confirmation sent to reporter in Filipino.');
    selectedIncident.set(null);
  }

  $: inc = $selectedIncident;
  $: cfg = inc ? severityConfig[inc.severity] : null;
</script>

{#if inc}
  <div class="panel">
    <!-- Header -->
    <div class="panel-header">
      <div class="header-icon" style="background:{cfg.bg}">
        <span style="font-size:20px">{categoryIcons[inc.category]}</span>
      </div>
      <div class="header-info">
        <div class="header-title">{inc.type}</div>
        <div class="header-sub">{inc.barangay}</div>
      </div>
      <button class="close-btn" on:click={close}>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M18 6 6 18M6 6l12 12"/></svg>
      </button>
    </div>

    <!-- Tags row -->
    <div class="tags-row">
      <div class="tag" style="background:{cfg.bg};color:{cfg.color}">{inc.severity}</div>
      <div class="tag channel">{inc.channel}</div>
      <div class="tag time">{inc.time}</div>
      {#if inc.resolved}<div class="tag resolved">✓ resolved</div>{/if}
    </div>

    <div class="body">
      <!-- Report count card -->
      <div class="count-card" style="border-color:{cfg.color}22">
        <div class="count-num" style="color:{cfg.color}">{inc.reports}</div>
        <div class="count-label">community reports</div>
        <div class="count-bar">
          <div class="count-fill" style="width:{Math.min(inc.reports/20*100,100)}%;background:{cfg.color}"></div>
        </div>
        {#if inc.reports >= 10}
          <div class="cluster-alert" style="color:{cfg.color}">⚡ Cluster threshold — captain auto-alerted</div>
        {:else if inc.reports >= 3}
          <div class="cluster-warn">⚠ Cluster forming — severity elevated</div>
        {/if}
      </div>

      <!-- Original report -->
      <div class="section">
        <div class="section-label">Original report</div>
        <div class="quote">"{inc.description}"</div>
      </div>

      <!-- AI assessment -->
      <div class="section">
        <div class="section-label ai">
          <div class="ai-dot"></div>
          AI assessment
        </div>
        <div class="ai-box">{inc.ai}</div>
      </div>

      <!-- Action -->
      <div class="section">
        <div class="section-label">Sent to reporter</div>
        <div class="action-box">{inc.action}</div>
      </div>

      <!-- Authorities -->
      <div class="section">
        <div class="section-label">Notified authorities</div>
        <div class="auth-row">
          {#each inc.authorities as a}
            <div class="auth-tag">{a}</div>
          {/each}
        </div>
      </div>

      <!-- Location -->
      <div class="section">
        <div class="section-label">Location</div>
        <div class="loc-box">
          <div class="loc-main">{inc.location}</div>
          <div class="loc-coords">{inc.lat.toFixed(4)}°N {inc.lng.toFixed(4)}°E</div>
        </div>
      </div>
    </div>

    <!-- Footer -->
    <div class="footer">
      {#if !inc.resolved}
        <button class="resolve-btn" on:click={resolve}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6 9 17l-5-5"/></svg>
          Mark as resolved
        </button>
      {:else}
        <div class="resolved-msg">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#4ade80" stroke-width="2.5"><path d="M20 6 9 17l-5-5"/></svg>
          Report resolved
        </div>
      {/if}
    </div>
  </div>
{/if}

<style>
  .panel {
    position: absolute;
    top: 16px; right: 16px;
    width: 300px;
    max-height: calc(100% - 32px);
    background: #13131a;
    border: 1px solid rgba(255,255,255,0.08);
    border-radius: 16px;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    z-index: 900;
    box-shadow: 0 24px 64px rgba(0,0,0,0.7), 0 0 0 1px rgba(255,255,255,0.04);
    animation: slidein 0.2s cubic-bezier(0.34, 1.56, 0.64, 1);
  }
  @keyframes slidein { from { opacity:0; transform:translateX(24px) scale(0.97); } to { opacity:1; transform:none; } }

  .panel-header {
    display: flex; align-items: center; gap: 10px;
    padding: 14px 14px 10px;
  }
  .header-icon {
    width: 42px; height: 42px;
    border-radius: 12px;
    display: flex; align-items: center; justify-content: center;
    flex-shrink: 0;
  }
  .header-info { flex: 1; min-width: 0; }
  .header-title { font-size: 15px; font-weight: 600; color: #cdd6f4; font-family: 'Syne', sans-serif; }
  .header-sub { font-size: 12px; color: #585b70; margin-top: 1px; }
  .close-btn {
    background: rgba(255,255,255,0.06); border: none;
    width: 28px; height: 28px; border-radius: 8px;
    display: flex; align-items: center; justify-content: center;
    cursor: pointer; color: #6c7086; flex-shrink: 0;
    transition: all 0.15s;
  }
  .close-btn:hover { background: rgba(255,255,255,0.1); color: #cdd6f4; }

  .tags-row {
    display: flex; gap: 5px; flex-wrap: wrap;
    padding: 0 14px 10px;
  }
  .tag {
    font-size: 10px; font-weight: 600;
    padding: 3px 8px; border-radius: 6px;
    text-transform: capitalize;
    background: rgba(255,255,255,0.06);
    color: #585b70;
  }
  .tag.channel { background: rgba(124,134,255,0.12); color: #7c86ff; }
  .tag.time { background: rgba(255,255,255,0.05); color: #45475a; }
  .tag.resolved { background: rgba(74,222,128,0.12); color: #4ade80; }

  .body {
    flex: 1; overflow-y: auto; padding: 0 14px 4px;
    scrollbar-width: thin; scrollbar-color: rgba(255,255,255,0.06) transparent;
  }

  .count-card {
    background: rgba(255,255,255,0.03);
    border: 1px solid;
    border-radius: 10px;
    padding: 12px 14px;
    margin-bottom: 14px;
  }
  .count-num { font-size: 28px; font-weight: 700; font-family: 'Syne', sans-serif; line-height: 1; }
  .count-label { font-size: 11px; color: #585b70; margin-top: 2px; margin-bottom: 8px; }
  .count-bar { height: 3px; background: rgba(255,255,255,0.06); border-radius: 2px; overflow: hidden; margin-bottom: 6px; }
  .count-fill { height: 100%; border-radius: 2px; transition: width 0.6s; }
  .cluster-alert { font-size: 10px; font-weight: 600; }
  .cluster-warn { font-size: 10px; color: #ff8c42; }

  .section { margin-bottom: 12px; }
  .section-label {
    font-size: 10px; font-weight: 600; color: #45475a;
    text-transform: uppercase; letter-spacing: 0.8px;
    margin-bottom: 5px;
    display: flex; align-items: center; gap: 5px;
  }
  .section-label.ai { color: #00d4aa; }
  .ai-dot { width: 6px; height: 6px; border-radius: 50%; background: #00d4aa; animation: pulse 2s infinite; }
  @keyframes pulse { 0%,100%{opacity:1} 50%{opacity:0.3} }

  .quote {
    font-size: 12px; color: #585b70; font-style: italic; line-height: 1.6;
    padding: 8px 10px;
    background: rgba(255,255,255,0.03);
    border-left: 2px solid rgba(255,255,255,0.08);
    border-radius: 0 6px 6px 0;
  }
  .ai-box {
    font-size: 12px; color: #a6adc8; line-height: 1.6;
    padding: 10px;
    background: rgba(0,212,170,0.05);
    border: 1px solid rgba(0,212,170,0.12);
    border-radius: 8px;
  }
  .action-box {
    font-size: 12px; color: #cdd6f4; line-height: 1.6;
    padding: 8px 10px;
    background: rgba(255,255,255,0.04);
    border-radius: 8px;
  }
  .auth-row { display: flex; flex-wrap: wrap; gap: 5px; }
  .auth-tag {
    font-size: 11px; padding: 3px 9px; border-radius: 6px;
    background: rgba(124,134,255,0.1); color: #7c86ff;
  }
  .loc-box { padding: 8px 10px; background: rgba(255,255,255,0.03); border-radius: 8px; }
  .loc-main { font-size: 12px; color: #cdd6f4; margin-bottom: 2px; }
  .loc-coords { font-size: 10px; color: #45475a; font-family: monospace; }

  .footer {
    padding: 12px 14px;
    border-top: 1px solid rgba(255,255,255,0.06);
    flex-shrink: 0;
  }
  .resolve-btn {
    width: 100%; padding: 10px;
    background: #00d4aa; color: #13131a;
    border: none; border-radius: 10px;
    font-size: 13px; font-weight: 600;
    cursor: pointer; font-family: 'DM Sans', sans-serif;
    transition: all 0.15s;
    display: flex; align-items: center; justify-content: center; gap: 7px;
  }
  .resolve-btn:hover { background: #00b894; transform: translateY(-1px); }
  .resolve-btn:active { transform: none; }
  .resolved-msg {
    display: flex; align-items: center; justify-content: center; gap: 6px;
    font-size: 13px; color: #4ade80; padding: 8px;
  }
</style>
