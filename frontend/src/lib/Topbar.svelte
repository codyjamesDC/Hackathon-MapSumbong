<script>
  import { createEventDispatcher } from 'svelte';
  import { disasterMode, toastMsg, stats } from './store.js';
  const dispatch = createEventDispatcher();

  function toggleDisaster() {
    disasterMode.update(v => {
      toastMsg.set(v ? 'Disaster Mode deactivated.' : '🚨 Disaster Mode active — SMS check-ins broadcasting.');
      return !v;
    });
  }
</script>

<header class="topbar" class:disaster={$disasterMode}>

  <!-- Brand -->
  <div class="brand">
    <div class="brand-icon">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="white"><path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/></svg>
    </div>
    <div class="brand-text">
      <span class="brand-name">Map<em>Sumbong</em></span>
      <span class="brand-sub">Barangay Intelligence</span>
    </div>
  </div>

  <!-- Thin separator -->
  <div class="sep"></div>

  <!-- Live pill — sits right after brand, not centered -->
  <div class="live-pill">
    <div class="live-dot"></div>
    Live · Metro Manila
  </div>

  {#if $disasterMode}
    <div class="disaster-pill">
      <svg width="12" height="12" viewBox="0 0 24 24" fill="#ff4560"><path d="M12 2L1 21h22L12 2zm0 3.5L20.5 19h-17L12 5.5zM11 10v4h2v-4h-2zm0 6v2h2v-2h-2z"/></svg>
      DISASTER MODE ACTIVE
    </div>
  {/if}

  <!-- Pushes everything after to the right -->
  <div class="spacer"></div>

  <!-- Right: stats + button -->
  <div class="right">
    <div class="stat-chips">
      <div class="chip red">
        <svg width="10" height="10" viewBox="0 0 24 24" fill="#ff4560"><path d="M12 2L1 21h22L12 2z"/></svg>
        {$stats.critical} Critical
      </div>
      <div class="chip amber">
        <svg width="10" height="10" viewBox="0 0 24 24" fill="#ff8c00"><circle cx="12" cy="12" r="10"/></svg>
        {$stats.open} Open
      </div>
      <div class="chip green">
        <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="#00c896" stroke-width="2.5"><path d="M20 6 9 17l-5-5"/></svg>
        {$stats.resolved} Resolved
      </div>
    </div>
    <button class="disaster-btn" class:active={$disasterMode} on:click={toggleDisaster}>
      <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2L1 21h22L12 2zm0 3.5L20.5 19h-17L12 5.5zM11 10v4h2v-4h-2zm0 6v2h2v-2h-2z"/></svg>
      {$disasterMode ? 'Exit Disaster Mode' : 'Disaster Mode'}
    </button>
    <button class="profile-btn" title="Open profile" aria-label="Open profile" on:click={() => dispatch('profile')}>
      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M20 21a8 8 0 0 0-16 0"/>
        <circle cx="12" cy="7" r="4"/>
      </svg>
    </button>
  </div>
</header>

<style>
  .topbar {
    position: absolute;
    top: 16px; left: 316px; right: 16px;
    height: 56px;
    z-index: 400;
    background: rgba(10,10,16,0.92);
    backdrop-filter: blur(20px);
    -webkit-backdrop-filter: blur(20px);
    border: 1px solid rgba(255,255,255,0.08);
    border-radius: 18px;
    display: flex;
    align-items: center;
    padding: 0 14px;
    gap: 12px;
    box-shadow: 0 8px 32px rgba(0,0,0,0.4);
    transition: border-color 0.3s;
  }
  .topbar.disaster { border-color: rgba(255,69,96,0.4); }

  .brand { display: flex; align-items: center; gap: 10px; flex-shrink: 0; }
  .brand-icon {
    width: 32px; height: 32px; border-radius: 10px;
    background: #00c896;
    display: flex; align-items: center; justify-content: center;
    flex-shrink: 0;
  }
  .brand-text { display: flex; flex-direction: column; }
  .brand-name { font-size: 15px; font-weight: 700; color: #e8e8f0; line-height: 1.15; letter-spacing: -0.3px; }
  .brand-name em { font-style: normal; color: #00c896; }
  .brand-sub { font-size: 10px; color: #404050; font-weight: 400; }

  .sep {
    width: 1px; height: 22px;
    background: rgba(255,255,255,0.08);
    flex-shrink: 0;
  }

  .live-pill {
    display: flex; align-items: center; gap: 6px;
    font-size: 12px; color: #00c896; font-weight: 600;
    background: rgba(0,200,150,0.08);
    border: 1px solid rgba(0,200,150,0.18);
    padding: 5px 11px; border-radius: 20px;
    flex-shrink: 0;
  }
  .live-dot {
    width: 7px; height: 7px; border-radius: 50%;
    background: #00c896;
    animation: pulse 2s ease-in-out infinite;
  }
  @keyframes pulse { 0%,100%{opacity:1;transform:scale(1)} 50%{opacity:0.4;transform:scale(0.8)} }

  .disaster-pill {
    display: flex; align-items: center; gap: 6px;
    font-size: 11px; color: #ff4560; font-weight: 700;
    background: rgba(255,69,96,0.1);
    border: 1px solid rgba(255,69,96,0.3);
    padding: 5px 11px; border-radius: 20px;
    letter-spacing: 0.5px;
    flex-shrink: 0;
    animation: fadein 0.3s;
  }
  @keyframes fadein { from{opacity:0} to{opacity:1} }

  /* This is the key fix — pushes stats to the far right */
  .spacer { flex: 1; }

  .right { display: flex; align-items: center; gap: 10px; flex-shrink: 0; }

  .stat-chips { display: flex; gap: 5px; }
  .chip {
    display: flex; align-items: center; gap: 5px;
    font-size: 11px; font-weight: 600;
    padding: 5px 10px; border-radius: 8px;
    background: rgba(255,255,255,0.05);
    white-space: nowrap;
  }
  .chip.red { color: #ff4560; }
  .chip.amber { color: #ff8c00; }
  .chip.green { color: #00c896; }

  .disaster-btn {
    display: flex; align-items: center; gap: 6px;
    padding: 7px 14px; border-radius: 10px;
    border: 1px solid rgba(255,69,96,0.3);
    background: rgba(255,69,96,0.08);
    color: #ff4560; font-size: 12px; font-weight: 600;
    cursor: pointer; font-family: 'Inter', sans-serif;
    transition: all 0.2s; white-space: nowrap;
  }
  .disaster-btn:hover { background: rgba(255,69,96,0.15); }
  .disaster-btn.active { background: #ff4560; color: white; border-color: #ff4560; }

  .profile-btn {
    width: 34px;
    height: 34px;
    border-radius: 10px;
    border: 1px solid rgba(255,255,255,0.1);
    background: rgba(255,255,255,0.05);
    color: #bcbccc;
    display: grid;
    place-items: center;
    cursor: pointer;
    transition: all 0.15s;
  }
  .profile-btn:hover {
    color: #00c896;
    border-color: rgba(0,200,150,0.28);
    background: rgba(0,200,150,0.08);
  }
</style>
