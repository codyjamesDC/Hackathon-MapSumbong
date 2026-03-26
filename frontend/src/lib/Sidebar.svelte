<script>
  import { incidents, selectedIncident, activeFilter, toastMsg, stats } from './store.js';
  import { resolveIncident } from './api.js';

  let search = '';
  let tab = 'incidents';

  const FILTERS = ['All','Open','Critical','High','Medium','Low'];

  const SEV = {
    critical: { color:'#ff4560', bg:'rgba(255,69,96,0.12)' },
    high:     { color:'#ff8c00', bg:'rgba(255,140,0,0.12)' },
    medium:   { color:'#f5c800', bg:'rgba(245,200,0,0.12)' },
    low:      { color:'#00c896', bg:'rgba(0,200,150,0.12)' }
  };

  // Avatar background colors per category — like brand logos in reference
  const AVG_BG = {
    flood:          '#1a2a3a',
    fire:           '#2a1a1a',
    infrastructure: '#1a1a2a',
    medical:        '#2a1a2a',
    waste:          '#1a2a1a',
    other:          '#1e1e28'
  };

  const CAT_SVG = {
    flood:`<svg viewBox="0 0 24 24" fill="currentColor"><path d="M3 13c1.5 0 1.5-1 3-1s1.5 1 3 1 1.5-1 3-1 1.5 1 3 1 1.5-1 3-1v2c-1.5 0-1.5 1-3 1s-1.5-1-3-1-1.5 1-3 1-1.5-1-3-1-1.5 1-3 1zm0 4c1.5 0 1.5-1 3-1s1.5 1 3 1 1.5-1 3-1 1.5 1 3 1 1.5-1 3-1v2c-1.5 0-1.5 1-3 1s-1.5-1-3-1-1.5 1-3 1-1.5-1-3-1-1.5 1-3 1zM11.5 1l3 7H13v3h-2V8H9.5z"/></svg>`,
    fire:`<svg viewBox="0 0 24 24" fill="currentColor"><path d="M17.66 11.2c-.23-.3-.51-.56-.77-.82-.67-.6-1.43-1.03-2.07-1.67C13.33 7.3 13 4.65 13.95 2c-1 .23-1.98.68-2.83 1.23-2.86 1.94-3.99 5.44-3.15 8.86.06.31-.01.63-.23.85C5.5 12.9 4 14.74 4 16.8c0 2.76 2.24 5 5 5 2.76 0 5-2.24 5-5 0-1.38-.56-2.64-1.47-3.55-.43.6-.75 1.28-.9 1.97.84.62 1.6 1.34 2.17 2.23.53.83.83 1.78.83 2.76 0 2.42-1.67 4.46-3.93 5.01A5.005 5.005 0 0 0 17.66 11.2z"/></svg>`,
    infrastructure:`<svg viewBox="0 0 24 24" fill="currentColor"><path d="M22 9V7h-2V5c0-1.1-.9-2-2-2H4c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2v-2h2v-2h-2v-2h2v-2h-2V9h2zm-4 10H4V5h14v14zM6 13h5v4H6zm6 0h3v2h-3zm0-4h3v2h-3zM6 7h5v5H6z"/></svg>`,
    medical:`<svg viewBox="0 0 24 24" fill="currentColor"><path d="M19 3H5c-1.1 0-1.99.9-1.99 2L3 19c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-1 11h-4v4h-4v-4H6v-4h4V6h4v4h4v4z"/></svg>`,
    waste:`<svg viewBox="0 0 24 24" fill="currentColor"><path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z"/></svg>`,
    other:`<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/></svg>`
  };

  let showResolveModal = false;
  let resolvingIncident = null;
  let resolutionNote = '';
  let resolutionPhotoUrl = '';
  let isSavingResolution = false;

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

  $: filtered = $incidents.filter(i => {
    const fk = $activeFilter.toLowerCase();
    const fMatch = fk==='all'?true : fk==='open'?!i.resolved : i.severity===fk;
    const sMatch = !search.trim()?true
      : i.type.toLowerCase().includes(search.toLowerCase())
      || i.barangay.toLowerCase().includes(search.toLowerCase());
    return fMatch && sMatch;
  });

  $: sorted = [...filtered].sort((a,b) => {
    if (a.resolved!==b.resolved) return a.resolved?1:-1;
    const o={critical:0,high:1,medium:2,low:3};
    if (o[a.severity]!==o[b.severity]) return o[a.severity]-o[b.severity];
    return b.reports-a.reports;
  });

  $: typeCounts = $incidents.reduce((a,i)=>{ a[i.category]=(a[i.category]||0)+1; return a; },{});
  $: maxType = Math.max(...Object.values(typeCounts),1);
  $: brgyGroups = $incidents.reduce((a,i)=>{
    if (!a[i.barangay]) a[i.barangay]={count:0,critical:0};
    a[i.barangay].count++; if(i.severity==='critical') a[i.barangay].critical++; return a;
  },{});

  function openResolveModal(inc, e) {
    if (e?.stopPropagation) e.stopPropagation();
    resolvingIncident = inc;
    resolutionNote = inc?.resolutionNote || '';
    resolutionPhotoUrl = inc?.resolutionPhotoUrl || '';
    showResolveModal = true;
  }

  function closeResolveModal() {
    if (isSavingResolution) return;
    showResolveModal = false;
    resolvingIncident = null;
    resolutionNote = '';
    resolutionPhotoUrl = '';
  }

  async function submitResolution() {
    if (!resolvingIncident || isSavingResolution) return;
    isSavingResolution = true;

    try {
      const updated = await resolveIncident(resolvingIncident.id, {
        resolutionNote,
        resolutionPhotoUrl,
      });

      const fallbackResolved = {
        ...resolvingIncident,
        resolved: true,
        resolutionNote: hasText(resolutionNote) ? resolutionNote.trim() : '',
        resolutionPhotoUrl: hasText(resolutionPhotoUrl)
          ? resolutionPhotoUrl.trim()
          : '',
      };
      const fallbackComplete =
        hasText(fallbackResolved.resolutionNote) &&
        hasText(fallbackResolved.resolutionPhotoUrl);
      fallbackResolved.resolutionComplete = fallbackComplete;
      fallbackResolved.resolutionPendingProof = !fallbackComplete;

      const merged = updated || fallbackResolved;

      incidents.update((list) =>
        list.map((i) => (i.id === resolvingIncident.id ? { ...i, ...merged } : i))
      );

      if ($selectedIncident?.id === resolvingIncident.id) {
        selectedIncident.set({ ...$selectedIncident, ...merged });
      }

      if (merged.resolutionPendingProof) {
        toastMsg.set('Marked as resolved. Pending written report and photo evidence.');
      } else {
        toastMsg.set('Resolved and fully completed with written report + evidence.');
      }

      closeResolveModal();
    } catch (err) {
      toastMsg.set(err?.message || 'Failed to update report status.');
    } finally {
      isSavingResolution = false;
    }
  }
</script>

<aside class="sidebar">
  <!-- Header -->
  <div class="sb-head">
    <div class="sb-logo">
      <svg width="18" height="18" viewBox="0 0 24 24" fill="#00c896"><path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/></svg>
      <span>Map<b>Sumbong</b></span>
    </div>
    <div class="sb-counts">
      <span style="color:#ff4560">{$stats.critical}</span>
      <span style="color:#ff8c00">{$stats.open}</span>
      <span style="color:#00c896">{$stats.resolved}</span>
    </div>
  </div>

  <!-- Search -->
  <div class="search-row">
    <div class="search-box">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#404050" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>
      <input bind:value={search} placeholder="Search..." />
      {#if search}
        <button class="clr" on:click={()=>search=''} aria-label="Clear search">
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><path d="M18 6 6 18M6 6l12 12"/></svg>
        </button>
      {/if}
    </div>
  </div>

  <!-- Show me / Sort row — matching reference style -->
  <div class="control-row">
    <span class="ctrl-label">Show:</span>
    <div class="ctrl-scroll">
      {#each FILTERS as f}
        <button
          class="ctrl-chip"
          class:active={$activeFilter.toLowerCase()===f.toLowerCase()}
          on:click={()=>activeFilter.set(f.toLowerCase()==='all'?'all':f.toLowerCase())}
        >{f}</button>
      {/each}
    </div>
  </div>

  <!-- Tabs -->
  <div class="tabs">
    <button class="tab" class:active={tab==='incidents'} on:click={()=>tab='incidents'}>
      Incidents
      <span class="tab-n" class:active={tab==='incidents'}>{sorted.length}</span>
    </button>
    <button class="tab" class:active={tab==='analytics'} on:click={()=>tab='analytics'}>Analytics</button>
  </div>

  {#if tab==='incidents'}
    <div class="list">
      {#each sorted as inc (inc.id)}
        {@const sev = SEV[inc.severity]}
        <div
          class="row"
          class:active={$selectedIncident?.id===inc.id}
          class:resolved={inc.resolved && !isResolutionPendingProof(inc)}
          class:pending-proof={isResolutionPendingProof(inc)}
          on:click={()=>selectedIncident.set(inc)}
          role="button"
          tabindex="0"
          on:keypress={e=>e.key==='Enter'&&selectedIncident.set(inc)}
        >
          <!-- Circular avatar like reference screenshot -->
          <div class="avatar" style="background:{AVG_BG[inc.category]};color:{sev.color}">
            <div class="avatar-svg">{@html CAT_SVG[inc.category]||CAT_SVG.other}</div>
            <!-- Green dot for open, grey for resolved -->
            <div
              class="status-dot"
              class:open={!inc.resolved}
              class:pending={isResolutionPendingProof(inc)}
              class:done={inc.resolved && !isResolutionPendingProof(inc)}
            ></div>
          </div>

          <!-- Main content -->
          <div class="row-body">
            <div class="row-top">
              <span class="row-name">{inc.type}</span>
              <span class="row-sev" style="color:{sev.color}">{inc.severity}</span>
            </div>
            <div class="row-sub">{inc.barangay}</div>
            <div class="row-meta">
              <span style="color:{sev.color};font-weight:700;">{inc.reports}</span>
              <span>reports · {inc.time}</span>
              {#if isResolutionPendingProof(inc)}
                <span class="proof-pill">pending proof</span>
              {/if}
            </div>
          </div>

          <!-- Two action icons on the right (matching reference) -->
          <div class="row-actions">
            <button class="act-btn" title="View on map" on:click|stopPropagation={()=>selectedIncident.set(inc)}>
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 6v16l7-4 8 4 7-4V2l-7 4-8-4-7 4z"/><path d="M8 2v16M16 6v16"/></svg>
            </button>
            <button
              class="act-btn"
              class:resolved={isResolutionComplete(inc)}
              class:pending={isResolutionPendingProof(inc)}
              title={
                isResolutionComplete(inc)
                  ? 'Already fully completed'
                  : isResolutionPendingProof(inc)
                    ? 'Add written report and evidence'
                    : 'Mark resolved'
              }
              on:click={(e)=>!isResolutionComplete(inc)&&openResolveModal(inc,e)}
            >
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6 9 17l-5-5"/></svg>
            </button>
          </div>
        </div>
      {/each}
      {#if !sorted.length}
        <div class="empty">
          <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#303040" stroke-width="1.5"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>
          No reports found
        </div>
      {/if}
    </div>

  {:else}
    <div class="analytics">
      <div class="a-section">By type</div>
      {#each Object.entries(typeCounts).sort((a,b)=>b[1]-a[1]) as [cat,n]}
        <div class="a-row">
          <div class="a-icon" style="color:{SEV['medium'].color}">{@html CAT_SVG[cat]||CAT_SVG.other}</div>
          <div class="a-lbl">{cat}</div>
          <div class="a-track"><div class="a-fill" style="width:{Math.round(n/maxType*100)}%"></div></div>
          <div class="a-n">{n}</div>
        </div>
      {/each}
      <div class="a-section" style="margin-top:16px">By barangay</div>
      {#each Object.entries(brgyGroups).sort((a,b)=>b[1].count-a[1].count) as [b,d]}
        <div class="a-row">
          <div class="a-lbl wide">{b.replace('Brgy. ','')}</div>
          <div class="a-track"><div class="a-fill green" style="width:{Math.round(d.count/Math.max(...Object.values(brgyGroups).map(x=>x.count),1)*100)}%"></div></div>
          <div class="a-n">{d.count}</div>
          {#if d.critical}<div class="a-crit">{d.critical}</div>{/if}
        </div>
      {/each}
    </div>
  {/if}
</aside>

{#if showResolveModal && resolvingIncident}
  <div
    class="resolve-overlay"
    role="button"
    tabindex="0"
    aria-label="Close resolution form"
    on:click|self={closeResolveModal}
    on:keydown={(e) => (e.key === 'Escape' || e.key === 'Enter') && closeResolveModal()}
  >
    <div class="resolve-modal">
      <h3>Mark as resolved</h3>
      <p>
        Pwede i-mark as resolved ngayon. Para fully completed,
        kailangan ang written report at photo evidence.
      </p>

      <label for="resolution-note">Written report</label>
      <textarea
        id="resolution-note"
        bind:value={resolutionNote}
        rows="3"
        placeholder="Halimbawa: Natapos ang clearing, nalinis ang kanal, at na-verify ng barangay team."
      ></textarea>

      <label for="resolution-photo-url">Photo evidence URL</label>
      <input
        id="resolution-photo-url"
        type="url"
        bind:value={resolutionPhotoUrl}
        placeholder="https://..."
      />

      {#if !resolutionNote.trim() || !resolutionPhotoUrl.trim()}
        <div class="resolve-hint">
          Resolved lang muna ito. Pending proof pa hanggang may written report at photo evidence.
        </div>
      {/if}

      <div class="resolve-actions">
        <button type="button" class="btn ghost" on:click={closeResolveModal} disabled={isSavingResolution}>
          Cancel
        </button>
        <button type="button" class="btn primary" on:click={submitResolution} disabled={isSavingResolution}>
          {isSavingResolution ? 'Saving...' : 'Save Status'}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .sidebar {
    position: absolute;
    top: 0; left: 0; bottom: 0;
    width: 300px;
    z-index: 400;
    background: rgba(10,10,16,0.97);
    backdrop-filter: blur(24px) saturate(1.8);
    -webkit-backdrop-filter: blur(24px) saturate(1.8);
    border-right: 1px solid rgba(255,255,255,0.07);
    border-radius: 0 20px 20px 0;
    display: flex; flex-direction: column; overflow: hidden;
    box-shadow: 4px 0 40px rgba(0,0,0,0.5);
  }

  /* Header */
  .sb-head {
    display: flex; align-items: center; justify-content: space-between;
    padding: 13px 14px 10px;
    border-bottom: 1px solid rgba(255,255,255,0.05);
    flex-shrink: 0;
  }
  .sb-logo { display: flex; align-items: center; gap: 7px; font-size: 14px; color: #c0c0d0; }
  .sb-logo b { color: #00c896; font-weight: 700; }
  .sb-counts { display: flex; gap: 10px; font-size: 13px; font-weight: 700; }

  /* Search */
  .search-row { padding: 8px 12px 6px; flex-shrink: 0; }
  .search-box {
    display: flex; align-items: center; gap: 8px;
    background: rgba(255,255,255,0.05);
    border: 1px solid rgba(255,255,255,0.07);
    border-radius: 10px; padding: 8px 11px;
    transition: border-color 0.2s;
  }
  .search-box:focus-within { border-color: rgba(0,200,150,0.3); }
  .search-box input {
    flex: 1; background: none; border: none; outline: none;
    color: #c0c0d0; font-size: 13px; font-family: 'Inter', sans-serif;
  }
  .search-box input::placeholder { color: #303040; }
  .clr { background: none; border: none; color: #404050; cursor: pointer; display: flex; padding: 1px; }
  .clr:hover { color: #808090; }

  /* Control row */
  .control-row {
    display: flex; align-items: center; gap: 8px;
    padding: 0 12px 8px; flex-shrink: 0;
  }
  .ctrl-label { font-size: 11px; color: #303040; white-space: nowrap; }
  .ctrl-scroll { display: flex; gap: 4px; flex-wrap: wrap; }
  .ctrl-chip {
    padding: 4px 10px; border-radius: 8px;
    border: 1px solid rgba(255,255,255,0.07);
    background: transparent; color: #404050;
    font-size: 11px; font-weight: 500;
    cursor: pointer; font-family: 'Inter', sans-serif;
    transition: all 0.15s;
  }
  .ctrl-chip:hover { border-color: rgba(255,255,255,0.14); color: #a0a0b0; }
  .ctrl-chip.active { background: #00c896; border-color: #00c896; color: #0a1a14; font-weight: 600; }

  /* Tabs */
  .tabs {
    display: flex; padding: 0 12px;
    border-bottom: 1px solid rgba(255,255,255,0.05);
    flex-shrink: 0;
  }
  .tab {
    padding: 8px 0; margin-right: 16px;
    font-size: 12px; font-weight: 500;
    background: none; border: none; color: #404050;
    cursor: pointer; border-bottom: 2px solid transparent;
    transition: all 0.15s; font-family: 'Inter', sans-serif;
    display: flex; align-items: center; gap: 5px;
  }
  .tab.active { color: #e0e0f0; border-bottom-color: #00c896; }
  .tab-n {
    font-size: 10px; background: rgba(255,255,255,0.06);
    color: #404050; padding: 1px 5px; border-radius: 20px;
  }
  .tab-n.active { background: rgba(0,200,150,0.15); color: #00c896; }

  /* List */
  .list { flex: 1; overflow-y: auto; padding: 4px 8px; scrollbar-width: thin; scrollbar-color: rgba(255,255,255,0.05) transparent; }

  .row {
    width: 100%; text-align: left;
    display: flex; align-items: center; gap: 10px;
    padding: 9px 8px; border-radius: 12px;
    border: 1px solid transparent;
    background: transparent; cursor: pointer;
    transition: all 0.15s; margin-bottom: 1px;
    font-family: 'Inter', sans-serif;
  }
  .row:hover { background: rgba(255,255,255,0.04); }
  .row.active { background: rgba(0,200,150,0.06); border-color: rgba(0,200,150,0.18); }
  .row.resolved { opacity: 0.4; }
  .row.pending-proof { opacity: 1; border-color: rgba(245,200,0,0.22); }

  /* Circular avatar — key reference match */
  .avatar {
    width: 44px; height: 44px; border-radius: 50%;
    display: flex; align-items: center; justify-content: center;
    flex-shrink: 0; position: relative;
    border: 1.5px solid rgba(255,255,255,0.08);
  }
  .avatar-svg { width: 20px; height: 20px; display: flex; }
  .status-dot {
    position: absolute; bottom: 1px; right: 1px;
    width: 9px; height: 9px; border-radius: 50%;
    border: 1.5px solid rgba(10,10,16,0.9);
  }
  .status-dot.open { background: #00c896; }
  .status-dot.pending { background: #f5c800; }
  .status-dot.done { background: #303040; }

  .row-body { flex: 1; min-width: 0; }
  .row-top { display: flex; align-items: center; justify-content: space-between; gap: 6px; margin-bottom: 2px; }
  .row-name { font-size: 13px; font-weight: 600; color: #d0d0e0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .row-sev { font-size: 10px; font-weight: 600; text-transform: capitalize; flex-shrink: 0; }
  .row-sub { font-size: 11px; color: #404050; margin-bottom: 3px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .row-meta { font-size: 10px; color: #303040; display: flex; gap: 4px; align-items: center; }
  .proof-pill {
    font-size: 9px;
    text-transform: uppercase;
    letter-spacing: 0.4px;
    color: #f5c800;
    background: rgba(245,200,0,0.14);
    border: 1px solid rgba(245,200,0,0.28);
    border-radius: 999px;
    padding: 1px 6px;
  }

  /* Two action buttons on right — matches reference screenshot */
  .row-actions { display: flex; flex-direction: column; gap: 3px; flex-shrink: 0; }
  .act-btn {
    width: 26px; height: 26px; border-radius: 8px;
    background: rgba(255,255,255,0.05);
    border: 1px solid rgba(255,255,255,0.07);
    display: flex; align-items: center; justify-content: center;
    cursor: pointer; color: #505060;
    transition: all 0.15s;
  }
  .act-btn:hover { background: rgba(255,255,255,0.1); color: #c0c0d0; }
  .act-btn.resolved { color: #00c896; background: rgba(0,200,150,0.1); border-color: rgba(0,200,150,0.2); }
  .act-btn.pending { color: #f5c800; background: rgba(245,200,0,0.1); border-color: rgba(245,200,0,0.24); }

  .resolve-overlay {
    position: fixed;
    inset: 0;
    z-index: 1300;
    background: rgba(0, 0, 0, 0.58);
    display: grid;
    place-items: center;
  }
  .resolve-modal {
    width: min(500px, calc(100vw - 32px));
    background: #101018;
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 14px;
    padding: 16px;
    display: grid;
    gap: 10px;
  }
  .resolve-modal h3 {
    margin: 0;
    color: #e9e9f5;
    font-size: 16px;
  }
  .resolve-modal p {
    margin: 0;
    color: #b9b9cc;
    font-size: 12px;
    line-height: 1.5;
  }
  .resolve-modal label {
    color: #d3d3e3;
    font-size: 12px;
    font-weight: 600;
  }
  .resolve-modal textarea,
  .resolve-modal input {
    width: 100%;
    border: 1px solid rgba(255, 255, 255, 0.14);
    background: rgba(255, 255, 255, 0.04);
    color: #ececf8;
    border-radius: 10px;
    padding: 10px;
    font-family: 'Inter', sans-serif;
    font-size: 12px;
  }
  .resolve-modal textarea { resize: vertical; min-height: 78px; }
  .resolve-modal textarea:focus,
  .resolve-modal input:focus {
    outline: none;
    border-color: rgba(0, 200, 150, 0.5);
  }
  .resolve-hint {
    color: #f5c800;
    background: rgba(245, 200, 0, 0.1);
    border: 1px solid rgba(245, 200, 0, 0.25);
    border-radius: 10px;
    padding: 8px 10px;
    font-size: 11px;
    line-height: 1.4;
  }
  .resolve-actions {
    display: flex;
    justify-content: flex-end;
    gap: 8px;
    margin-top: 2px;
  }
  .btn {
    border-radius: 9px;
    border: 1px solid transparent;
    padding: 8px 12px;
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
  }
  .btn.ghost {
    background: rgba(255, 255, 255, 0.05);
    border-color: rgba(255, 255, 255, 0.14);
    color: #d9d9e8;
  }
  .btn.primary {
    background: #00c896;
    color: #062117;
  }
  .btn:disabled { opacity: 0.65; cursor: not-allowed; }

  .empty { display: flex; flex-direction: column; align-items: center; gap: 8px; padding: 40px 20px; color: #303040; font-size: 12px; }

  /* Analytics */
  .analytics { flex: 1; overflow-y: auto; padding: 12px 14px; }
  .a-section { font-size: 10px; font-weight: 600; color: #303040; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 10px; }
  .a-row { display: flex; align-items: center; gap: 7px; margin-bottom: 7px; }
  .a-icon { width: 16px; height: 16px; display: flex; flex-shrink: 0; }
  .a-lbl { font-size: 11px; color: #505060; width: 70px; flex-shrink: 0; text-transform: capitalize; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .a-lbl.wide { width: 86px; }
  .a-track { flex: 1; height: 4px; background: rgba(255,255,255,0.05); border-radius: 2px; overflow: hidden; }
  .a-fill { height: 100%; background: #00c896; border-radius: 2px; transition: width 0.5s; }
  .a-fill.green { background: #7c86ff; }
  .a-n { font-size: 11px; color: #404050; width: 16px; text-align: right; flex-shrink: 0; }
  .a-crit { background: rgba(255,69,96,0.15); color: #ff4560; font-size: 10px; font-weight: 700; padding: 1px 5px; border-radius: 5px; flex-shrink: 0; }
</style>
