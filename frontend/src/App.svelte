<script>
  import { onMount } from 'svelte';
  import MapView from './lib/MapView.svelte';
  import Sidebar from './lib/Sidebar.svelte';
  import DetailCard from './lib/DetailCard.svelte';
  import Topbar from './lib/Topbar.svelte';
  import Toast from './lib/Toast.svelte';
  import TransparencyFeed from './lib/TransparencyFeed.svelte';
  import { selectedIncident, toastMsg, incidents } from './lib/store.js';
  import { fetchIncidents, subscribeToIncidents } from './lib/api.js';

  let toastVisible = false;
  let toastText = '';
  let feedOpen = false;
  let ws = null;

  toastMsg.subscribe(msg => {
    if (msg) {
      toastText = msg;
      toastVisible = true;
      setTimeout(() => { toastVisible = false; setTimeout(() => toastMsg.set(''), 300); }, 3200);
    }
  });

  onMount(async () => {
    try {
      const live = await fetchIncidents();
      if (live && live.length > 0) {
        incidents.set(live);
        ws = subscribeToIncidents(
          (n) => { incidents.update(l => [n, ...l]); toastMsg.set(`New report via ${n.channel}`); },
          (u) => { incidents.update(l => l.map(i => i.id === u.id ? u : i)); }
        );
      }
    } catch {}
    return () => { if (ws) ws.close(); };
  });
</script>

<svelte:head>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
</svelte:head>

<div class="root">
  <!-- Full-bleed map behind everything -->
  <MapView />

  <!-- Topbar overlay -->
  <Topbar on:feedopen={() => feedOpen = true} />

  <!-- Floating sidebar overlay (left) -->
  <Sidebar />

  <!-- Detail card overlay (right, appears on selection) -->
  {#if $selectedIncident}
    <DetailCard />
  {/if}

  <!-- Bottom center actions -->
  <div class="bottom-actions">
    <button class="action-btn accent" on:click={() => {
      const types = [
        {type:'Flash Flood',category:'flood',severity:'critical',barangay:'Brgy. Nangka',location:'Near Nangka Elementary',lat:14.651,lng:121.101,description:'Bumabaha na dito. Tuhod na halos.',ai:'Flash flood confirmed. 14 reports clustered.',action:'Lumikas agad.',authorities:['MDRRMO','Barangay Captain'],reports:14,radius:400},
        {type:'Structure Fire',category:'fire',severity:'critical',barangay:'Brgy. Poblacion',location:'Near Poblacion Market',lat:14.561,lng:121.020,description:'May sunog! Kumakalat na.',ai:'Active fire in dense area.',action:'Tumawag sa BFP: 160.',authorities:['BFP','PNP'],reports:9,radius:300},
        {type:'Road Hazard',category:'infrastructure',severity:'high',barangay:'Brgy. Guadalupe',location:'EDSA Guadalupe',lat:14.566,lng:121.044,description:'Malaking butas at baha.',ai:'Multi-lane blockage confirmed.',action:'Iwasan ang EDSA Guadalupe.',authorities:['MMDA'],reports:7,radius:250}
      ];
      const s = types[Math.floor(Math.random()*types.length)];
      const inc = {...s, id:Date.now(), time:'Just now', channel:['Telegram','SMS','Messenger'][Math.floor(Math.random()*3)], resolved:false};
      incidents.update(l => [inc, ...l]);
      selectedIncident.set(inc);
      toastMsg.set('New report triaged by AI.');
    }}>
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M12 5v14M5 12h14"/></svg>
      Simulate Report
    </button>
    <button class="action-btn" on:click={() => feedOpen = true}>
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M2 12h20M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg>
      Transparency Feed
    </button>
  </div>
</div>

<TransparencyFeed bind:open={feedOpen} />
<Toast visible={toastVisible} message={toastText} />

<style>
  :global(*) { margin:0; padding:0; box-sizing:border-box; }
  :global(body) {
    font-family: 'Inter', sans-serif;
    background: #111114;
    color: #f0f0f5;
    height: 100vh;
    overflow: hidden;
  }

  .root {
    position: relative;
    width: 100vw;
    height: 100vh;
    overflow: hidden;
  }

  .bottom-actions {
    position: absolute;
    bottom: 24px;
    left: 50%;
    transform: translateX(-50%);
    z-index: 500;
    display: flex;
    gap: 8px;
    padding: 6px;
    background: rgba(18, 18, 22, 0.85);
    backdrop-filter: blur(12px);
    border: 1px solid rgba(255,255,255,0.08);
    border-radius: 16px;
    box-shadow: 0 8px 32px rgba(0,0,0,0.4);
  }

  .action-btn {
    display: flex;
    align-items: center;
    gap: 7px;
    padding: 9px 18px;
    border-radius: 10px;
    border: none;
    background: rgba(255,255,255,0.06);
    color: #a0a0b0;
    font-size: 13px;
    font-weight: 500;
    font-family: 'Inter', sans-serif;
    cursor: pointer;
    transition: all 0.15s;
    white-space: nowrap;
  }
  .action-btn:hover { background: rgba(255,255,255,0.1); color: #f0f0f5; }
  .action-btn.accent { background: #00c896; color: #0a1410; font-weight: 600; }
  .action-btn.accent:hover { background: #00b584; }
</style>
