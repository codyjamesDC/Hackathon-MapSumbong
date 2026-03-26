<script>
  import { onMount, onDestroy } from 'svelte';
  import { incidents, selectedIncident } from './store.js';
  import maplibregl from 'maplibre-gl';
  import 'maplibre-gl/dist/maplibre-gl.css';
  import barangayGeoJSONRaw from '../data/los_banos_barangays.geojson?raw';
  
  const barangayGeoJSON = JSON.parse(barangayGeoJSONRaw);

  let mapEl;
  let map;
  let popup;
  let selectedBarangay = null;
  let baseMap = 'osm';
  let viewMode = 'polygon';
  let hiddenBarangay = null;
  let currentIncidents = [];
  let suppressSingleClickUntil = 0;
  const DOUBLE_CLICK_GUARD_MS = 280;

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

  function normalizeBarangayName(name) {
    return String(name || '')
      .toLowerCase()
      .replace(/[^a-z0-9]/g, '');
  }

  function getIncidentListForBarangay(barangay, incidentList) {
    const key = normalizeBarangayName(barangay);
    return incidentList.filter(inc => normalizeBarangayName(inc.barangay) === key);
  }

  function getBaseMapStyle() {
    return {
      version: 8,
      sources: {
        'basemap-osm': {
          type: 'raster',
          tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],
          tileSize: 256,
          attribution: '© OpenStreetMap contributors'
        },
        'basemap-topo': {
          type: 'raster',
          tiles: [
            'https://a.tile.opentopomap.org/{z}/{x}/{y}.png',
            'https://b.tile.opentopomap.org/{z}/{x}/{y}.png',
            'https://c.tile.opentopomap.org/{z}/{x}/{y}.png'
          ],
          tileSize: 256,
          attribution: '© OpenTopoMap contributors'
        },
        'basemap-sat': {
          type: 'raster',
          tiles: ['https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'],
          tileSize: 256,
          attribution: 'Tiles © Esri'
        },
        'basemap-dark': {
          type: 'raster',
          tiles: [
            'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
            'https://b.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
            'https://c.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
          ],
          tileSize: 256,
          attribution: '© CARTO, © OpenStreetMap contributors'
        }
      },
      layers: [
        { id: 'base-osm', type: 'raster', source: 'basemap-osm', layout: { visibility: 'visible' } },
        { id: 'base-topo', type: 'raster', source: 'basemap-topo', layout: { visibility: 'none' } },
        { id: 'base-sat', type: 'raster', source: 'basemap-sat', layout: { visibility: 'none' } },
        { id: 'base-dark', type: 'raster', source: 'basemap-dark', layout: { visibility: 'none' } }
      ]
    };
  }

  function applyBaseMapVisibility() {
    if (!map || !map.isStyleLoaded()) return;
    map.setLayoutProperty('base-osm', 'visibility', baseMap === 'osm' ? 'visible' : 'none');
    map.setLayoutProperty('base-topo', 'visibility', baseMap === 'topo' ? 'visible' : 'none');
    map.setLayoutProperty('base-sat', 'visibility', baseMap === 'satellite' ? 'visible' : 'none');
    map.setLayoutProperty('base-dark', 'visibility', baseMap === 'dark' ? 'visible' : 'none');
  }

  function applyViewMode() {
    if (!map || !map.isStyleLoaded()) return;

    if (map.getLayer('barangays-extrusion')) {
      map.setLayoutProperty(
        'barangays-extrusion',
        'visibility',
        viewMode === 'extruded' ? 'visible' : 'none'
      );
    }
    if (map.getLayer('barangays-fill')) {
      map.setLayoutProperty(
        'barangays-fill',
        'visibility',
        viewMode === 'polygon' ? 'visible' : 'none'
      );
    }

    map.easeTo({
      pitch: hiddenBarangay ? 0 : viewMode === 'extruded' ? 58 : 0,
      bearing: hiddenBarangay ? 0 : viewMode === 'extruded' ? -18 : 0,
      duration: 350
    });
  }

  function buildIncidentGeoJSON() {
    return {
      type: 'FeatureCollection',
      features: currentIncidents
        .filter(inc => Number.isFinite(Number(inc.lng)) && Number.isFinite(Number(inc.lat)))
        .map(inc => ({
          type: 'Feature',
          geometry: {
            type: 'Point',
            coordinates: [Number(inc.lng), Number(inc.lat)]
          },
          properties: {
            id: inc.id,
            type: inc.type,
            severity: inc.severity,
            barangay: inc.barangay,
            reports: inc.reports || 1,
            resolved: Boolean(inc.resolved)
          }
        }))
    };
  }

  function updateIncidentSource() {
    if (!map || !map.getSource('incidents')) return;
    map.getSource('incidents').setData(buildIncidentGeoJSON());
  }

  function getVisibleBarangayGeoJSON() {
    if (!hiddenBarangay) return barangayGeoJSON;

    const hiddenKey = normalizeBarangayName(hiddenBarangay);
    return {
      ...barangayGeoJSON,
      features: barangayGeoJSON.features.filter(
        feature => normalizeBarangayName(feature?.properties?.name) !== hiddenKey
      )
    };
  }

  function shouldSuppressSingleClick() {
    return Date.now() < suppressSingleClickUntil;
  }

  function guardNextSingleClicks() {
    suppressSingleClickUntil = Date.now() + DOUBLE_CLICK_GUARD_MS;
  }

  function updateBarangaySourceVisibility() {
    if (!map || !map.getSource('barangays')) return;
    map.getSource('barangays').setData(getVisibleBarangayGeoJSON());
  }

  function addOperationalLayers() {
    if (!map.getSource('barangays')) {
      map.addSource('barangays', {
        type: 'geojson',
        data: getVisibleBarangayGeoJSON()
      });
    }

    if (!map.getLayer('barangays-extrusion')) {
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
    }

    if (!map.getLayer('barangays-fill')) {
      map.addLayer({
        id: 'barangays-fill',
        type: 'fill',
        source: 'barangays',
        paint: {
          'fill-color': '#1a472a',
          'fill-opacity': 0.52
        },
        layout: {
          visibility: 'none'
        }
      });
    }

    if (!map.getLayer('barangays-outline')) {
      map.addLayer({
        id: 'barangays-outline',
        type: 'line',
        source: 'barangays',
        paint: {
          'line-color': '#ffffff',
          'line-width': 1.2,
          'line-opacity': 0.45
        }
      });
    }

    if (!map.getSource('incidents')) {
      map.addSource('incidents', {
        type: 'geojson',
        data: buildIncidentGeoJSON()
      });
    }

    if (!map.getLayer('incidents-circle')) {
      map.addLayer({
        id: 'incidents-circle',
        type: 'circle',
        source: 'incidents',
        paint: {
          'circle-radius': ['interpolate', ['linear'], ['zoom'], 10, 5, 15, 9],
          'circle-color': [
            'match', ['get', 'severity'],
            'critical', SEV_COLORS.critical,
            'high', SEV_COLORS.high,
            'medium', SEV_COLORS.medium,
            SEV_COLORS.low
          ],
          'circle-stroke-color': '#0b1220',
          'circle-stroke-width': 1.6,
          'circle-opacity': ['case', ['==', ['get', 'resolved'], true], 0.45, 0.95]
        }
      });
    }

    if (!map.getLayer('incidents-label')) {
      map.addLayer({
        id: 'incidents-label',
        type: 'symbol',
        source: 'incidents',
        layout: {
          'text-field': ['to-string', ['get', 'reports']],
          'text-size': 11,
          'text-offset': [0, 0],
          'text-allow-overlap': true
        },
        paint: {
          'text-color': '#ffffff'
        }
      });
    }

    applyBaseMapVisibility();
    applyViewMode();
    updateChoropleth();
    updateIncidentSource();
  }

  // Calculate color based on incident count and severity
  function getBarangayColor(barangay, incidentList) {
    const barangayIncidents = getIncidentListForBarangay(barangay, incidentList).filter(inc => !inc.resolved);
    
    if (barangayIncidents.length === 0) return '#1a472a'; // Dark green - no incidents

    const activeReportCount = barangayIncidents.reduce((sum, inc) => sum + Number(inc.reports || 1), 0);

    // Find highest severity
    let highestSeverity = 'low';
    barangayIncidents.forEach(inc => {
      if (ORDER[inc.severity] < ORDER[highestSeverity]) {
        highestSeverity = inc.severity;
      }
    });

    // Severity is the base signal, then report volume boosts intensity.
    const severityWeight = { low: 1, medium: 2, high: 3, critical: 4 };
    const boostedWeight = Math.min(
      4,
      severityWeight[highestSeverity] + (activeReportCount >= 10 ? 2 : activeReportCount >= 5 ? 1 : 0)
    );

    if (boostedWeight >= 4) return SEV_COLORS.critical;
    if (boostedWeight === 3) return SEV_COLORS.high;
    if (boostedWeight === 2) return SEV_COLORS.medium;
    return SEV_COLORS.low;
  }

  function getBarangayHeight(barangay, incidentList) {
    const barangayIncidents = getIncidentListForBarangay(barangay, incidentList).filter(inc => !inc.resolved);

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
      const barangayIncidents = getIncidentListForBarangay(barangay, incidentList);
      const activeIncidents = barangayIncidents.filter(inc => !inc.resolved);
      const activeReportCount = activeIncidents.reduce((sum, inc) => sum + Number(inc.reports || 1), 0);
      const totalReportCount = barangayIncidents.reduce((sum, inc) => sum + Number(inc.reports || 1), 0);
      
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
        activeReports: activeReportCount,
        totalReports: totalReportCount,
        highestSeverity,
        severityCount
      };
    });

    // Update choropleth layer colors
    if (map && map.getLayer('barangays-extrusion')) {
      updateChoropleth();
    }

    if (map && map.getSource('incidents')) {
      updateIncidentSource();
    }
  }

  function updateChoropleth() {
    if (!map || !map.getLayer('barangays-extrusion')) return;

    const fillColorExpr = ['case'];
    const extrusionHeightExpr = ['case'];
    const extrusionOpacityExpr = ['case'];
    const fillOpacityExpr = ['case'];
    const outlineColorExpr = ['case'];
    const outlineOpacityExpr = ['case'];

    barangayGeoJSON.features.forEach(feature => {
      const barangay = feature.properties.name;
      const isHidden = hiddenBarangay && normalizeBarangayName(hiddenBarangay) === normalizeBarangayName(barangay);
      const color = getBarangayColor(barangay, $incidents);
      const height = getBarangayHeight(barangay, $incidents);

      fillColorExpr.push(['==', ['get', 'name'], barangay]);
      fillColorExpr.push(color);
      extrusionHeightExpr.push(['==', ['get', 'name'], barangay]);
      extrusionHeightExpr.push(isHidden ? 0 : height);
      extrusionOpacityExpr.push(['==', ['get', 'name'], barangay]);
      extrusionOpacityExpr.push(isHidden ? 0 : 0.78);
      fillOpacityExpr.push(['==', ['get', 'name'], barangay]);
      fillOpacityExpr.push(isHidden ? 0 : 0.52);
      outlineColorExpr.push(['==', ['get', 'name'], barangay]);
      outlineColorExpr.push('#ffffff');
      outlineOpacityExpr.push(['==', ['get', 'name'], barangay]);
      outlineOpacityExpr.push(isHidden ? 0 : 0.45);
    });

    fillColorExpr.push('#1a1a2e'); // default
    extrusionHeightExpr.push(120); // default
    extrusionOpacityExpr.push(0.78); // default
    fillOpacityExpr.push(0.52); // default
    outlineColorExpr.push('#ffffff'); // default
    outlineOpacityExpr.push(0.45); // default

    map.setPaintProperty('barangays-extrusion', 'fill-extrusion-color', fillColorExpr);
    map.setPaintProperty('barangays-extrusion', 'fill-extrusion-height', extrusionHeightExpr);
    map.setPaintProperty('barangays-extrusion', 'fill-extrusion-opacity', extrusionOpacityExpr);

    if (map.getLayer('barangays-fill')) {
      map.setPaintProperty('barangays-fill', 'fill-color', fillColorExpr);
      map.setPaintProperty('barangays-fill', 'fill-opacity', fillOpacityExpr);
    }

    if (map.getLayer('barangays-outline')) {
      map.setPaintProperty('barangays-outline', 'line-color', outlineColorExpr);
      map.setPaintProperty('barangays-outline', 'line-opacity', outlineOpacityExpr);
    }
  }

  function showIncidentPopup(incident, lngLat) {
    const activeReportsInBarangay = getIncidentListForBarangay(
      incident?.barangay,
      currentIncidents
    )
      .filter(inc => !inc.resolved)
      .reduce((sum, inc) => sum + Number(inc.reports || 1), 0);

    const html = `
      <div style="font-family: 'DM Sans', sans-serif; padding: 10px; min-width: 220px;">
        <h3 style="margin: 0 0 8px 0; color: #f0f4ff;">${incident.type}</h3>
        <div style="color: #8892aa; font-size: 12px;">
          <p style="margin: 3px 0;"><strong>Barangay:</strong> ${incident.barangay || 'Unknown'}</p>
          <p style="margin: 3px 0;"><strong>Severity:</strong> ${incident.severity || 'low'}</p>
          <p style="margin: 3px 0;"><strong>Active reports (barangay):</strong> ${activeReportsInBarangay}</p>
          <p style="margin: 3px 0;"><strong>Status:</strong> ${incident.resolved ? 'Resolved' : 'Active'}</p>
        </div>
      </div>
    `;

    if (popup) popup.remove();
    popup = new maplibregl.Popup({ offset: 26 }).setLngLat(lngLat).setHTML(html).addTo(map);
  }

  function showLocationPopup(lngLat, nearbyCount) {
    const html = `
      <div style="font-family: 'DM Sans', sans-serif; padding: 10px; min-width: 220px;">
        <h3 style="margin: 0 0 8px 0; color: #f0f4ff;">Map Location</h3>
        <div style="color: #8892aa; font-size: 12px;">
          <p style="margin: 3px 0;"><strong>Lat:</strong> ${lngLat.lat.toFixed(5)}</p>
          <p style="margin: 3px 0;"><strong>Lng:</strong> ${lngLat.lng.toFixed(5)}</p>
          <p style="margin: 3px 0;"><strong>Nearby reports:</strong> ${nearbyCount}</p>
        </div>
      </div>
    `;

    if (popup) popup.remove();
    popup = new maplibregl.Popup({ offset: 20 }).setLngLat(lngLat).setHTML(html).addTo(map);
  }

  function getFeatureBounds(feature) {
    const bounds = new maplibregl.LngLatBounds();

    function extendFromCoords(coords) {
      if (!Array.isArray(coords) || coords.length === 0) return;

      if (typeof coords[0] === 'number' && typeof coords[1] === 'number') {
        bounds.extend([coords[0], coords[1]]);
        return;
      }

      coords.forEach(extendFromCoords);
    }

    if (feature?.geometry?.coordinates) {
      extendFromCoords(feature.geometry.coordinates);
    }

    return bounds;
  }

  function showBarangayReportsPopup(barangay, lngLat) {
    const brgyIncidents = getIncidentListForBarangay(barangay, currentIncidents);
    const activeIncidents = brgyIncidents.filter(inc => !inc.resolved);
    const activeReportCount = activeIncidents.reduce((sum, inc) => sum + Number(inc.reports || 1), 0);
    const reportRows = activeIncidents
      .slice(0, 6)
      .map(inc => `<li style="margin: 2px 0;"><strong>${inc.type}</strong> · ${inc.severity} · ${Number(inc.reports || 1)} report(s)</li>`)
      .join('');

    const html = `
      <div style="font-family: 'DM Sans', sans-serif; padding: 10px; min-width: 240px;">
        <h3 style="margin: 0 0 8px 0; color: #f0f4ff;">${barangay}</h3>
        <div style="color: #8892aa; font-size: 12px;">
          <p style="margin: 3px 0;"><strong>Active reports:</strong> ${activeReportCount}</p>
          <p style="margin: 3px 0;"><strong>Active incidents:</strong> ${activeIncidents.length}</p>
          ${activeIncidents.length > 0
            ? `<ul style="margin: 8px 0 0 16px; padding: 0; color: #c5cfdf;">${reportRows}</ul>`
            : '<p style="margin: 6px 0 0 0;">No active incidents in this barangay.</p>'}
        </div>
      </div>
    `;

    if (popup) popup.remove();
    popup = new maplibregl.Popup({ offset: 30 }).setLngLat(lngLat).setHTML(html).addTo(map);
  }

  function onMapClick(e) {
    if (!map || shouldSuppressSingleClick()) return;

    // Dedicated layer handlers own marker/polygon clicks.
    const incidentHit = map.queryRenderedFeatures(e.point, { layers: ['incidents-circle'] });
    if (incidentHit.length > 0) return;

    const barangayHit = map.queryRenderedFeatures(e.point, {
      layers: ['barangays-extrusion', 'barangays-fill']
    });
    if (barangayHit.length > 0) return;

    // Clicking random coordinates should not show a report/location popup.
    if (popup) {
      popup.remove();
      popup = null;
    }
  }

  function onIncidentMarkerClick(e) {
    if (!map || !e.features?.length || shouldSuppressSingleClick()) return;

    const id = e.features[0]?.properties?.id;
    const incident = currentIncidents.find(inc => String(inc.id) === String(id));
    if (!incident) return;

    selectedIncident.set(incident);
    showIncidentPopup(incident, e.lngLat);
  }

  function onMapDoubleClick(e) {
    if (!map) return;
    guardNextSingleClicks();

    // Barangay-specific double click is handled separately.
    const barangayHits = map.queryRenderedFeatures(e.point, {
      layers: ['barangays-extrusion', 'barangays-fill']
    });
    if (barangayHits.length > 0) return;

    map.flyTo({
      center: [e.lngLat.lng, e.lngLat.lat],
      zoom: Math.max(map.getZoom(), 15),
      pitch: viewMode === 'extruded' ? 58 : 0,
      bearing: viewMode === 'extruded' ? -18 : 0,
      duration: 700
    });
    showLocationPopup(e.lngLat, currentIncidents.length);
  }

  function onBarangayDoubleClick(e) {
    if (!map || !e.features?.length) return;
    guardNextSingleClicks();

    if (e.originalEvent?.preventDefault) e.originalEvent.preventDefault();
    if (e.originalEvent?.stopPropagation) e.originalEvent.stopPropagation();

    const feature = e.features[0];
    const barangay = feature?.properties?.name;
    if (!barangay) return;

    hiddenBarangay = barangay;
    updateBarangaySourceVisibility();
    updateChoropleth();

    const bounds = getFeatureBounds(feature);
    if (!bounds.isEmpty()) {
      map.fitBounds(bounds, {
        padding: { top: 70, right: 70, bottom: 70, left: 70 },
        duration: 700,
        maxZoom: 16.8,
        pitch: 0,
        bearing: 0
      });
    }

    const related = getIncidentListForBarangay(barangay, currentIncidents).filter(inc => !inc.resolved);
    if (related.length > 0) {
      selectedIncident.set(related[0]);
    }

    showBarangayReportsPopup(barangay, e.lngLat);
  }

  function onBarangayClick(e) {
    if (shouldSuppressSingleClick()) return;

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
            <p style="margin: 3px 0;"><strong>Active incidents:</strong> ${stats.total || 0}</p>
            <p style="margin: 3px 0;"><strong>Active reports (barangay):</strong> ${stats.activeReports || 0}</p>
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

  function onMapRightClick(e) {
    if (e?.originalEvent?.preventDefault) e.originalEvent.preventDefault();

    hiddenBarangay = null;
    updateBarangaySourceVisibility();
    updateChoropleth();
    applyViewMode();

    if (popup) {
      popup.remove();
      popup = null;
    }
  }

  onMount(async () => {
    // Create map
    map = new maplibregl.Map({
      container: mapEl,
      style: getBaseMapStyle(),
      center: LOS_BANOS_CENTER,
      zoom: 13.7,
      pitch: 58,
      bearing: -18,
      attributionControl: false
    });

    map.doubleClickZoom.disable();

    // Wait for map to load, then add barangay layer
    map.on('load', () => {
      addOperationalLayers();

      // Layer interactions
      map.on('click', 'barangays-extrusion', onBarangayClick);
      map.on('click', 'barangays-fill', onBarangayClick);
      map.on('click', 'incidents-circle', onIncidentMarkerClick);
      map.on('dblclick', 'barangays-extrusion', onBarangayDoubleClick);
      map.on('dblclick', 'barangays-fill', onBarangayDoubleClick);
      map.on('mouseenter', 'barangays-extrusion', () => {
        map.getCanvas().style.cursor = 'pointer';
      });
      map.on('mouseenter', 'barangays-fill', () => {
        map.getCanvas().style.cursor = 'pointer';
      });
      map.on('mouseleave', 'barangays-extrusion', () => {
        map.getCanvas().style.cursor = '';
      });
      map.on('mouseleave', 'barangays-fill', () => {
        map.getCanvas().style.cursor = '';
      });

      // Generic interactions
      map.on('click', onMapClick);
      map.on('dblclick', onMapDoubleClick);
      map.on('contextmenu', onMapRightClick);

      // Keep attribution pinned at the bottom-right edge.
      map.addControl(new maplibregl.AttributionControl(), 'bottom-right');

      // Keep only the compass and place it bottom-right above the map option cards.
      map.addControl(
        new maplibregl.NavigationControl({
          showCompass: true,
          showZoom: false,
          visualizePitch: true
        }),
        'bottom-right'
      );

      // Initial update
      updateBarangayStats($incidents);
    });

    // Subscribe to incidents changes
    const unsub = incidents.subscribe(inc => {
      currentIncidents = inc;
      updateBarangayStats(inc);
    });

    // Fly to selected incident
    let prevIncident = null;
    const unsub2 = selectedIncident.subscribe(inc => {
      if (inc && inc !== prevIncident) {
        prevIncident = inc;
        if (map && map.isStyleLoaded()) {
          const withinLosBanos = Number(inc.lat) >= 14.10 && Number(inc.lat) <= 14.21 && Number(inc.lng) >= 121.17 && Number(inc.lng) <= 121.27;
          const center = withinLosBanos ? [inc.lng, inc.lat] : LOS_BANOS_CENTER;
          map.flyTo({
            center,
            zoom: withinLosBanos ? 16 : 13.7,
            pitch: viewMode === 'extruded' ? 60 : 0,
            bearing: viewMode === 'extruded' ? -20 : 0,
            duration: 900,
            easing: (t) => t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
          });
        }
      } else if (!inc) {
        prevIncident = null;
        if (popup) {
          popup.remove();
          popup = null;
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

  $: if (map && map.isStyleLoaded() && baseMap) {
    applyBaseMapVisibility();
  }

  $: if (map && map.isStyleLoaded() && (viewMode || hiddenBarangay !== null)) {
    applyViewMode();
    updateBarangaySourceVisibility();
    updateChoropleth();
  }
</script>

<div class="map-wrap">
  <div bind:this={mapEl} class="map"></div>
  <div class="map-controls">
    <div class="control-group">
      <span class="control-label">Base map</span>
      <select bind:value={baseMap}>
        <option value="osm">Street</option>
        <option value="topo">Topography</option>
        <option value="satellite">Satellite</option>
        <option value="dark">Dark</option>
      </select>
    </div>
    <div class="control-group">
      <span class="control-label">Barangay mode</span>
      <select bind:value={viewMode}>
        <option value="extruded">3D Extruded</option>
        <option value="polygon">Geometric Polygon</option>
      </select>
    </div>
  </div>
</div>

<style>
  .map-wrap {
    width: 100%;
    height: 100%;
    position: relative;
  }

  .map {
    width: 100%;
    height: 100%;
    position: relative;
  }

  .map-controls {
    position: absolute;
    bottom: 12px;
    right: 12px;
    display: flex;
    flex-direction: column;
    gap: 8px;
    z-index: 10;
  }

  /* Put only the compass directly above the Base Map / Barangay mode stack. */
  :global(.maplibregl-ctrl-bottom-right .maplibregl-ctrl-group) {
    margin: 0 12px 124px 0;
  }

  /* Keep attribution fixed at the bottom-right edge. */
  :global(.maplibregl-ctrl-bottom-right .maplibregl-ctrl-attrib) {
    margin: 0 10px 10px 0;
  }

  .control-group {
    display: flex;
    flex-direction: column;
    gap: 4px;
    background: rgba(8, 14, 28, 0.82);
    border: 1px solid rgba(255, 255, 255, 0.16);
    border-radius: 8px;
    padding: 8px;
    min-width: 152px;
    backdrop-filter: blur(6px);
  }

  .control-label {
    color: #c6d2ea;
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.02em;
    text-transform: uppercase;
  }

  .control-group select {
    border-radius: 6px;
    border: 1px solid rgba(255, 255, 255, 0.22);
    background: rgba(10, 18, 35, 0.95);
    color: #e8eefc;
    padding: 6px 8px;
    font-size: 12px;
    outline: none;
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
