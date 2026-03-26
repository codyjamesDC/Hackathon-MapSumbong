<script>
  import { onMount, onDestroy } from 'svelte';
  import { incidents, selectedIncident, severityConfig, disasterMode } from './store.js';
  import maplibregl from 'maplibre-gl';
  import 'maplibre-gl/dist/maplibre-gl.css';
  import barangayGeoJSONRaw from '../data/los_banos_barangays.geojson?raw';
  
  const barangayGeoJSON = JSON.parse(barangayGeoJSONRaw);

  let mapEl;
  let map;
  let popup;
  let selectedBarangay = null;

  // Los Baños center
  const LOS_BANOS_CENTER = [121.2430, 14.1698];

  // Barangay incident counts
  let barangayStats = {};

  const ORDER = { critical: 0, high: 1, medium: 2, low: 3 };
  const SEV_COLORS = {
    critical: '#ff4560',
    high: '#ff8c00',
    medium: '#f5c800',
    low: '#00c896'
  };

  const SEV_HEIGHTS = {
    critical: 2200,
    high: 1600,
    medium: 1100,
    low: 750
  };

  // Calculate color based on incident count and severity
  function getBarangayColor(barangay, incidentList) {
    const barangayIncidents = incidentList.filter(inc => inc.barangay === barangay && !inc.resolved);
    
    if (barangayIncidents.length === 0) return '#1a472a'; // Dark green - no incidents
    
    // Find highest severity
    let highestSeverity = 'low';
    barangayIncidents.forEach(inc => {
      if (ORDER[inc.severity] < ORDER[highestSeverity]) {
        highestSeverity = inc.severity;
      }
    });

    // Adjust opacity based on incident count
    const severityColor = SEV_COLORS[highestSeverity];
    return severityColor;
  }

  function getBarangayHeight(barangay, incidentList) {
    const barangayIncidents = incidentList.filter(inc => inc.barangay === barangay && !inc.resolved);

    if (barangayIncidents.length === 0) return 120;

    let highestSeverity = 'low';
    barangayIncidents.forEach(inc => {
      if (ORDER[inc.severity] < ORDER[highestSeverity]) {
        highestSeverity = inc.severity;
      }
    });

    // Taller extrusions indicate both severity and number of active incidents.
    return SEV_HEIGHTS[highestSeverity] + barangayIncidents.length * 180;
  }

  // Update barangay statistics
  function updateBarangayStats(incidentList) {
    barangayStats = {};
    barangayGeoJSON.features.forEach(feature => {
      const barangay = feature.properties.name;
      const barangayIncidents = incidentList.filter(inc => inc.barangay === barangay);
      const activeIncidents = barangayIncidents.filter(inc => !inc.resolved);
      
      // Find highest severity
      let highestSeverity = 'low';
      let severityCount = { critical: 0, high: 0, medium: 0, low: 0 };
      
      activeIncidents.forEach(inc => {
        severityCount[inc.severity] = (severityCount[inc.severity] || 0) + 1;
        if (ORDER[inc.severity] < ORDER[highestSeverity]) {
          highestSeverity = inc.severity;
        }
      });

      barangayStats[barangay] = {
        total: activeIncidents.length,
        resolved: barangayIncidents.length - activeIncidents.length,
        highestSeverity,
        severityCount
      };
    });

    // Update choropleth layer colors
    if (map && map.getLayer('barangays-extrusion')) {
      updateChoropleth();
    }
  }

  function updateChoropleth() {
    if (!map || !map.getLayer('barangays-extrusion')) return;

    const fillColorExpr = ['case'];
    const extrusionHeightExpr = ['case'];
    barangayGeoJSON.features.forEach(feature => {
      const barangay = feature.properties.name;
      const color = getBarangayColor(barangay, $incidents);
      const height = getBarangayHeight(barangay, $incidents);
      fillColorExpr.push(['==', ['get', 'name'], barangay]);
      fillColorExpr.push(color);
      extrusionHeightExpr.push(['==', ['get', 'name'], barangay]);
      extrusionHeightExpr.push(height);
    });
    fillColorExpr.push('#1a1a2e'); // default
    extrusionHeightExpr.push(120); // default

    map.setPaintProperty('barangays-extrusion', 'fill-extrusion-color', fillColorExpr);
    map.setPaintProperty('barangays-extrusion', 'fill-extrusion-height', extrusionHeightExpr);
  }

  function onBarangayClick(e) {
    if (e.features.length > 0) {
      const feature = e.features[0];
      const barangay = feature.properties.name;
      const stats = barangayStats[barangay] || {};

      selectedBarangay = barangay;

      // Show popup
      const coordinates = e.lngLat;
      const html = `
        <div style="font-family: 'DM Sans', sans-serif; padding: 10px;">
          <h3 style="margin: 0 0 8px 0; color: #f0f4ff;">${barangay}</h3>
          <div style="color: #8892aa; font-size: 12px;">
            <p style="margin: 3px 0;"><strong>Active:</strong> ${stats.total || 0}</p>
            ${stats.severityCount ? `
              <p style="margin: 3px 0;"><strong style="color: #ff4560;">Critical:</strong> ${stats.severityCount.critical || 0}</p>
              <p style="margin: 3px 0;"><strong style="color: #ff8c00;">High:</strong> ${stats.severityCount.high || 0}</p>
              <p style="margin: 3px 0;"><strong style="color: #f5c800;">Medium:</strong> ${stats.severityCount.medium || 0}</p>
              <p style="margin: 3px 0;"><strong style="color: #00c896;">Low:</strong> ${stats.severityCount.low || 0}</p>
            ` : ''}
          </div>
        </div>
      `;

      if (popup) {
        popup.remove();
      }

      popup = new maplibregl.Popup({ offset: 35 })
        .setLngLat(coordinates)
        .setHTML(html)
        .addTo(map);
    }
  }

  onMount(async () => {
    // Create map
    map = new maplibregl.Map({
      container: mapEl,
      style: {
        version: 8,
        sources: {
          'osm': {
            type: 'raster',
            tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],
            tileSize: 256,
            attribution: '© OpenStreetMap contributors'
          }
        },
        layers: [
          {
            id: 'osm',
            type: 'raster',
            source: 'osm'
          }
        ]
      },
      center: LOS_BANOS_CENTER,
      zoom: 13.7,
      pitch: 58,
      bearing: -18
    });

    // Add dark filter to tiles
    const filterStyle = document.createElement('style');
    filterStyle.textContent = `
      .maplibregl-canvas { filter: brightness(0.6) contrast(1.05) saturate(0.3) hue-rotate(200deg) !important; }
    `;
    document.head.appendChild(filterStyle);

    // Wait for map to load, then add barangay layer
    map.on('load', () => {
      // Add GeoJSON source
      map.addSource('barangays', {
        type: 'geojson',
        data: barangayGeoJSON
      });

      // Add 3D extrusion layer
      map.addLayer({
        id: 'barangays-extrusion',
        type: 'fill-extrusion',
        source: 'barangays',
        paint: {
          'fill-extrusion-color': '#1a472a',
          'fill-extrusion-height': 120,
          'fill-extrusion-base': 0,
          'fill-extrusion-opacity': 0.78
        }
      });

      // Add outline layer
      map.addLayer({
        id: 'barangays-outline',
        type: 'line',
        source: 'barangays',
        paint: {
          'line-color': '#fff',
          'line-width': 1.2,
          'line-opacity': 0.35
        }
      });

      // Make extrusion layer interactive
      map.on('click', 'barangays-extrusion', onBarangayClick);
      map.on('mouseenter', 'barangays-extrusion', () => {
        map.getCanvas().style.cursor = 'pointer';
      });
      map.on('mouseleave', 'barangays-extrusion', () => {
        map.getCanvas().style.cursor = '';
      });

      // Add zoom controls
      map.addControl(new maplibregl.NavigationControl());

      // Initial update
      updateBarangayStats($incidents);
    });

    // Subscribe to incidents changes
    const unsub = incidents.subscribe(inc => {
      updateBarangayStats(inc);
    });

    // Fly to selected incident
    let prevIncident = null;
    const unsub2 = selectedIncident.subscribe(inc => {
      if (inc && inc !== prevIncident) {
        prevIncident = inc;
        if (map && map.isStyleLoaded()) {
          map.flyTo({
            center: [inc.lng, inc.lat],
            zoom: 16,
            pitch: 60,
            bearing: -20,
            duration: 900,
            easing: (t) => t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
          });
        }
      }
    });

    return () => {
      unsub();
      unsub2();
      if (map) map.remove();
    };
  });

  onDestroy(() => {
    if (map) map.remove();
  });
</script>

<div bind:this={mapEl} class="map"></div>

<style>
  .map {
    width: 100%;
    height: 100%;
    position: relative;
  }

  :global(.maplibregl-popup-content) {
    background: #111827 !important;
    border: 1px solid rgba(255, 255, 255, 0.1) !important;
    border-radius: 8px !important;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.5) !important;
  }

  :global(.maplibregl-popup-tip) {
    border-top-color: #111827 !important;
  }

  :global(.maplibregl-ctrl-group button) {
    background: rgba(10, 10, 16, 0.9) !important;
    border: 1px solid rgba(255, 255, 255, 0.1) !important;
    color: #a0a0b8 !important;
  }

  :global(.maplibregl-ctrl-group button:hover) {
    background: rgba(0, 200, 150, 0.1) !important;
    color: #00c896 !important;
  }
</style>
