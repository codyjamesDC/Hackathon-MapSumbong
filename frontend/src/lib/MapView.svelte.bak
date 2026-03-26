<script>
  import { onMount, onDestroy } from 'svelte';
  import { incidents, selectedIncident, severityConfig, disasterMode } from './store.js';
  import L from 'leaflet';
  import 'leaflet/dist/leaflet.css';

  let mapEl;
  let map;
  let markerLayer = {};
  let circleLayer = {};
  let markerSnapshot = {};
  let currentTile = null;
  let styleMenuOpen = false;
  let activeStyle = 'dark';

  // Los Baños, Laguna center coordinates
  const LOS_BANOS_CENTER = [14.1698, 121.2430];

  const MAP_STYLES = [
    {
      id: 'dark',
      label: 'Dark',
      icon: `<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9z"/></svg>`,
      url: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
      filter: 'brightness(0.6) contrast(1.05) saturate(0.3) hue-rotate(200deg)',
      subdomains: ['a','b','c']
    },
    {
      id: 'color',
      label: 'Color',
      icon: `<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="12" r="10"/></svg>`,
      url: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
      filter: 'brightness(0.85) saturate(1.4) contrast(1.05)',
      subdomains: ['a','b','c']
    },
    {
      id: 'satellite',
      label: 'Satellite',
      icon: `<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93V18c0-.55.45-1 1-1s1 .45 1 1v1.93c-3.95-.49-7-3.85-7-7.93s3.05-7.44 7-7.93V6c0 .55.45 1 1 1s1-.45 1-1V4.07c3.95.49 7 3.85 7 7.93s-3.05 7.44-7 7.93z"/></svg>`,
      url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      filter: 'brightness(0.75) saturate(0.9)',
      subdomains: []
    },
    {
      id: 'topo',
      label: 'Topo',
      icon: `<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M14 6l-1-2H5v17h2v-7h5l1 2h7V6h-6zm4 8h-4l-1-2H7V6h5l1 2h5v6z"/></svg>`,
      url: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
      filter: 'brightness(0.7) saturate(0.8) contrast(1.1)',
      subdomains: ['a','b','c']
    },
    {
      id: 'light',
      label: 'Light',
      icon: `<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="12" r="5"/><path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/></svg>`,
      url: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
      filter: 'brightness(0.9) invert(0.92) hue-rotate(180deg) saturate(0.5)',
      subdomains: 'abcd'
    },
  ];

  const ORDER = { critical:0, high:1, medium:2, low:3 };
  const SEV_COLORS = { critical:'#ff4560', high:'#ff8c00', medium:'#f5c800', low:'#00c896' };
  const CAT_SVG = {
    flood:`<svg viewBox="0 0 24 24" fill="currentColor"><path d="M3 13c1.5 0 1.5-1 3-1s1.5 1 3 1 1.5-1 3-1 1.5 1 3 1 1.5-1 3-1v2c-1.5 0-1.5 1-3 1s-1.5-1-3-1-1.5 1-3 1-1.5-1-3-1-1.5 1-3 1zm0 4c1.5 0 1.5-1 3-1s1.5 1 3 1 1.5-1 3-1 1.5 1 3 1 1.5-1 3-1v2c-1.5 0-1.5 1-3 1s-1.5-1-3-1-1.5 1-3 1-1.5-1-3-1-1.5 1-3 1zM11.5 1l3 7H13v3h-2V8H9.5z"/></svg>`,
    fire:`<svg viewBox="0 0 24 24" fill="currentColor"><path d="M17.66 11.2c-.23-.3-.51-.56-.77-.82-.67-.6-1.43-1.03-2.07-1.67C13.33 7.3 13 4.65 13.95 2c-1 .23-1.98.68-2.83 1.23-2.86 1.94-3.99 5.44-3.15 8.86C5.5 12.9 4 14.74 4 16.8c0 2.76 2.24 5 5 5 2.76 0 5-2.24 5-5 0-1.38-.56-2.64-1.47-3.55-.43.6-.75 1.28-.9 1.97.84.62 1.6 1.34 2.17 2.23A5.005 5.005 0 0 0 17.66 11.2z"/></svg>`,
    infrastructure:`<svg viewBox="0 0 24 24" fill="currentColor"><path d="M22 9V7h-2V5c0-1.1-.9-2-2-2H4c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2v-2h2v-2h-2v-2h2v-2h-2V9h2zm-4 10H4V5h14v14z"/></svg>`,
    medical:`<svg viewBox="0 0 24 24" fill="currentColor"><path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-1 11h-4v4h-4v-4H6v-4h4V6h4v4h4v4z"/></svg>`,
    waste:`<svg viewBox="0 0 24 24" fill="currentColor"><path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z"/></svg>`,
    other:`<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/></svg>`
  };

  function applyStyle(styleId) {
    const style = MAP_STYLES.find(s => s.id === styleId);
    if (!style || !map) return;
    activeStyle = styleId;
    if (currentTile) { currentTile.remove(); currentTile = null; }
    const opts = { maxZoom:19, crossOrigin:'anonymous', keepBuffer:6 };
    if (style.subdomains && style.subdomains.length) opts.subdomains = style.subdomains;
    currentTile = L.tileLayer(style.url, opts).addTo(map);
    document.getElementById('tile-filter-style').textContent =
      `.leaflet-tile-pane { filter: ${style.filter} !important; }`;
    styleMenuOpen = false;
  }

  function mkIcon(inc) {
    const col = inc.resolved ? '#00c896' : SEV_COLORS[inc.severity];
    const svg = CAT_SVG[inc.category] || CAT_SVG.other;
    const size = inc.severity==='critical' ? 42 : inc.severity==='high' ? 38 : 34;
    const pulse = inc.severity==='critical' && !inc.resolved;
    return L.divIcon({
      className: '',
      iconSize: [size+24, size+30],
      iconAnchor: [(size+24)/2, size+30],
      html: `
        <div style="display:flex;flex-direction:column;align-items:center;gap:0;pointer-events:none;">
          ${pulse ? `<div style="position:absolute;width:${size+16}px;height:${size+16}px;border-radius:50%;background:${col}22;border:1.5px solid ${col}66;top:-8px;left:-8px;animation:ripple 1.4s ease-out infinite;pointer-events:none;"></div>` : ''}
          <div style="width:${size}px;height:${size}px;border-radius:50%;background:#13131f;border:2.5px solid ${col};display:flex;align-items:center;justify-content:center;box-shadow:0 4px 16px ${col}55;cursor:pointer;pointer-events:all;position:relative;z-index:2;">
            <div style="width:${Math.round(size*0.45)}px;height:${Math.round(size*0.45)}px;color:${col};">${svg}</div>
          </div>
          <div style="background:#13131f;border:1px solid ${col}55;color:${col};font-size:10px;font-weight:700;padding:2px 7px;border-radius:20px;margin-top:3px;font-family:'Inter',sans-serif;white-space:nowrap;pointer-events:all;cursor:pointer;box-shadow:0 2px 8px rgba(0,0,0,0.4);">${inc.resolved ? '✓' : inc.reports+' reports'}</div>
        </div>`
    });
  }

  function renderAll($incs) {
    if (!map) return;
    const nextById = {};
    [...$incs].sort((a,b) => ORDER[b.severity]-ORDER[a.severity]).forEach(inc => {
      nextById[inc.id] = inc;
    });

    // Remove layers that are no longer present.
    Object.keys(markerLayer).forEach((id) => {
      if (!nextById[id]) {
        markerLayer[id].remove();
        circleLayer[id]?.remove();
        delete markerLayer[id];
        delete circleLayer[id];
        delete markerSnapshot[id];
      }
    });

    // Upsert changed/new markers and circles.
    Object.values(nextById).forEach(inc => {
      const snap = `${inc.lat}|${inc.lng}|${inc.severity}|${inc.resolved}|${inc.reports}|${inc.radius}|${inc.category}`;
      if (markerSnapshot[inc.id] === snap) return;

      markerLayer[inc.id]?.remove();
      circleLayer[inc.id]?.remove();

      const col = inc.resolved ? '#00c896' : SEV_COLORS[inc.severity];
      const circle = L.circle([inc.lat,inc.lng], {
        radius: inc.radius, color: col, fillColor: col,
        fillOpacity: inc.resolved ? 0.03 : inc.severity==='critical' ? 0.1 : 0.06,
        weight: 1,
        opacity: inc.resolved ? 0.2 : inc.severity==='critical' ? 0.7 : 0.4,
        dashArray: inc.resolved ? '6 4' : null
      }).addTo(map);
      circleLayer[inc.id] = circle;
      const m = L.marker([inc.lat,inc.lng], {
        icon: mkIcon(inc),
        zIndexOffset: (4-ORDER[inc.severity])*1000
      }).addTo(map);
      m.on('click', () => selectedIncident.set(inc));
      markerLayer[inc.id] = m;
      markerSnapshot[inc.id] = snap;
    });
  }

  onMount(() => {
    const filterStyle = document.createElement('style');
    filterStyle.id = 'tile-filter-style';
    filterStyle.textContent = `.leaflet-tile-pane { filter: brightness(0.6) contrast(1.05) saturate(0.3) hue-rotate(200deg) !important; }`;
    document.head.appendChild(filterStyle);

    const s = document.createElement('style');
    s.textContent = `
      @keyframes ripple { 0%{transform:scale(0.4);opacity:0.9} 100%{transform:scale(1.6);opacity:0} }
      .leaflet-container { background: #0a0a10 !important; }
      .leaflet-control-attribution { display:none !important; }
      .ms-tip { background:#13131f !important; border:1px solid rgba(255,255,255,0.1) !important; border-radius:10px !important; color:#e0e0f0 !important; padding:8px 12px !important; font-family:'Inter',sans-serif !important; font-size:12px !important; box-shadow:0 8px 32px rgba(0,0,0,0.5) !important; }
      .ms-tip::before,.ms-tip::after { display:none !important; }
      .leaflet-control-zoom { border:none !important; box-shadow:none !important; margin:0 16px 16px 0 !important; }
      .leaflet-control-zoom a { background:rgba(10,10,16,0.9) !important; backdrop-filter:blur(8px) !important; border:1px solid rgba(255,255,255,0.1) !important; color:#a0a0b8 !important; width:34px !important; height:34px !important; line-height:32px !important; font-size:18px !important; border-radius:10px !important; margin-bottom:4px !important; display:block !important; }
      .leaflet-control-zoom a:hover { color:#00c896 !important; background:rgba(0,200,150,0.1) !important; }
    `;
    document.head.appendChild(s);

    map = L.map(mapEl, {
      center: LOS_BANOS_CENTER,
      zoom: 12,
      zoomControl: false,
      attributionControl: false,
      preferCanvas: false
    });

    applyStyle('dark');
    L.control.zoom({ position: 'bottomright' }).addTo(map);

    const unsub = incidents.subscribe(renderAll);
    return unsub;
  });

  let prev = null;
  $: if (map && $selectedIncident && $selectedIncident !== prev) {
    prev = $selectedIncident;
    map.flyTo([$selectedIncident.lat, $selectedIncident.lng], 15, { duration:0.9, easeLinearity:0.3 });
  }

  onDestroy(() => { if (map) map.remove(); });
</script>

<div bind:this={mapEl} class="map"></div>

<!-- Map style switcher -->
<div class="style-switcher">
  <button class="style-toggle" on:click={() => styleMenuOpen = !styleMenuOpen} title="Map style">
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
      <path d="M1 6v16l7-4 8 4 7-4V2l-7 4-8-4-7 4z"/>
      <path d="M8 2v16M16 6v16"/>
    </svg>
    <span>Map style</span>
    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" style="transform:{styleMenuOpen?'rotate(180deg)':'none'};transition:transform 0.2s">
      <path d="m6 9 6 6 6-6"/>
    </svg>
  </button>

  {#if styleMenuOpen}
    <div class="style-menu">
      {#each MAP_STYLES as style}
        <button
          class="style-opt"
          class:active={activeStyle === style.id}
          on:click={() => applyStyle(style.id)}
        >
          <span class="style-icon">{@html style.icon}</span>
          <span class="style-label">{style.label}</span>
          {#if activeStyle === style.id}
            <svg class="style-check" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#00c896" stroke-width="2.5"><path d="M20 6 9 17l-5-5"/></svg>
          {/if}
        </button>
      {/each}
    </div>
  {/if}
</div>

<style>
  .map { position:absolute; inset:0; width:100%; height:100%; }

  :global(.leaflet-control-zoom) { border:none !important; box-shadow:none !important; margin:0 16px 16px 0 !important; }
  :global(.leaflet-control-zoom a) { background:rgba(10,10,16,0.9) !important; border:1px solid rgba(255,255,255,0.1) !important; color:#a0a0b8 !important; width:34px !important; height:34px !important; line-height:32px !important; font-size:18px !important; border-radius:10px !important; margin-bottom:4px !important; display:block !important; }
  :global(.leaflet-control-zoom a:hover) { color:#00c896 !important; }

  .style-switcher {
    position: absolute;
    bottom: 96px;
    right: 16px;
    z-index: 800;
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 6px;
  }

  .style-toggle {
    display: flex; align-items: center; gap: 7px;
    padding: 9px 14px;
    background: rgba(10,10,16,0.92);
    border: 1px solid rgba(255,255,255,0.1);
    border-radius: 12px;
    color: #c0c0d0;
    font-size: 12px; font-weight: 500;
    cursor: pointer; font-family: 'Inter', sans-serif;
    backdrop-filter: blur(12px);
    transition: all 0.15s;
    box-shadow: 0 4px 20px rgba(0,0,0,0.4);
    white-space: nowrap;
  }
  .style-toggle:hover { border-color: rgba(0,200,150,0.3); color: #00c896; }

  .style-menu {
    background: rgba(10,10,16,0.96);
    border: 1px solid rgba(255,255,255,0.08);
    border-radius: 14px;
    overflow: hidden;
    padding: 5px;
    backdrop-filter: blur(16px);
    box-shadow: 0 8px 32px rgba(0,0,0,0.5);
    animation: pop 0.15s cubic-bezier(0.34,1.56,0.64,1);
  }
  @keyframes pop { from{opacity:0;transform:scale(0.95) translateY(6px)} to{opacity:1;transform:none} }

  .style-opt {
    display: flex; align-items: center; gap: 9px;
    width: 100%; padding: 9px 12px;
    background: transparent;
    border: none; border-radius: 9px;
    color: #808090; font-size: 13px; font-weight: 500;
    cursor: pointer; font-family: 'Inter', sans-serif;
    transition: all 0.12s; white-space: nowrap;
    text-align: left;
  }
  .style-opt:hover { background: rgba(255,255,255,0.05); color: #d0d0e0; }
  .style-opt.active { color: #00c896; background: rgba(0,200,150,0.06); }
  .style-icon { display: flex; flex-shrink: 0; }
  .style-label { flex: 1; }
  .style-check { flex-shrink: 0; }
</style>
