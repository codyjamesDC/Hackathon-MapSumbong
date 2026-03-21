# MapSumbong Dashboard Guide

React web dashboard for barangay officials.

## Setup

```bash
npx create-react-app mapsumbong-dashboard
cd mapsumbong-dashboard
npm install @supabase/supabase-js leaflet react-leaflet recharts
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
```

## Project Structure

```
src/
├── App.js
├── components/
│   ├── Map.js
│   └── ReportsList.js
└── services/
    └── supabase.js
```

## Implementation

### .env

```bash
REACT_APP_SUPABASE_URL=https://xxxxx.supabase.co
REACT_APP_SUPABASE_ANON_KEY=eyJ...
REACT_APP_BACKEND_URL=http://localhost:8000
```

### src/services/supabase.js

```javascript
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.REACT_APP_SUPABASE_URL,
  process.env.REACT_APP_SUPABASE_ANON_KEY
);

export default supabase;
```

### src/components/Map.js

```javascript
import React from 'react';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';

// Fix default marker icons
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: require('leaflet/dist/images/marker-icon-2x.png'),
  iconUrl: require('leaflet/dist/images/marker-icon.png'),
  shadowUrl: require('leaflet/dist/images/marker-shadow.png'),
});

// Custom marker colors by urgency
const getMarkerColor = (urgency) => {
  const colors = {
    critical: '#EF4444',
    high: '#F59E0B',
    medium: '#FBBF24',
    low: '#10B981',
  };
  return colors[urgency] || '#6B7280';
};

const createCustomIcon = (urgency) => {
  return L.divIcon({
    className: 'custom-marker',
    html: `<div style="background-color: ${getMarkerColor(urgency)}; width: 24px; height: 24px; border-radius: 50%; border: 2px solid white;"></div>`,
    iconSize: [24, 24],
  });
};

export default function Map({ reports, onReportClick }) {
  const center = [14.6942, 120.9834]; // Valenzuela center

  return (
    <MapContainer 
      center={center} 
      zoom={13} 
      style={{ height: '600px', width: '100%' }}
    >
      <TileLayer
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        attribution='&copy; OpenStreetMap contributors'
      />
      
      {reports.map(report => (
        <Marker
          key={report.id}
          position={[report.latitude, report.longitude]}
          icon={createCustomIcon(report.urgency)}
          eventHandlers={{ click: () => onReportClick(report) }}
        >
          <Popup>
            <div>
              <h3 className="font-bold">{report.issue_type.toUpperCase()}</h3>
              <p>{report.description}</p>
              <p className="text-sm text-gray-600">
                {new Date(report.created_at).toLocaleString()}
              </p>
              <span className={`px-2 py-1 rounded text-xs ${
                report.urgency === 'critical' ? 'bg-red-100 text-red-800' :
                report.urgency === 'high' ? 'bg-orange-100 text-orange-800' :
                'bg-yellow-100 text-yellow-800'
              }`}>
                {report.urgency}
              </span>
            </div>
          </Popup>
        </Marker>
      ))}
    </MapContainer>
  );
}
```

### src/components/ReportsList.js

```javascript
import React from 'react';

export default function ReportsList({ reports, onStatusUpdate }) {
  const statusColors = {
    received: 'bg-blue-100 text-blue-800',
    in_progress: 'bg-yellow-100 text-yellow-800',
    resolved: 'bg-green-100 text-green-800',
  };

  return (
    <div className="overflow-x-auto">
      <table className="min-w-full bg-white">
        <thead>
          <tr className="bg-gray-100">
            <th className="px-4 py-2 text-left">ID</th>
            <th className="px-4 py-2 text-left">Type</th>
            <th className="px-4 py-2 text-left">Location</th>
            <th className="px-4 py-2 text-left">Urgency</th>
            <th className="px-4 py-2 text-left">Status</th>
            <th className="px-4 py-2 text-left">Date</th>
            <th className="px-4 py-2 text-left">Actions</th>
          </tr>
        </thead>
        <tbody>
          {reports.map(report => (
            <tr key={report.id} className="border-b hover:bg-gray-50">
              <td className="px-4 py-2">{report.id}</td>
              <td className="px-4 py-2 capitalize">{report.issue_type}</td>
              <td className="px-4 py-2">{report.location_text}</td>
              <td className="px-4 py-2">
                <span className={`px-2 py-1 rounded text-xs ${
                  report.urgency === 'critical' ? 'bg-red-100 text-red-800' :
                  report.urgency === 'high' ? 'bg-orange-100 text-orange-800' :
                  'bg-yellow-100 text-yellow-800'
                }`}>
                  {report.urgency}
                </span>
              </td>
              <td className="px-4 py-2">
                <span className={`px-2 py-1 rounded text-xs ${statusColors[report.status]}`}>
                  {report.status.replace('_', ' ')}
                </span>
              </td>
              <td className="px-4 py-2">
                {new Date(report.created_at).toLocaleDateString()}
              </td>
              <td className="px-4 py-2">
                <select 
                  className="border rounded px-2 py-1"
                  value={report.status}
                  onChange={(e) => onStatusUpdate(report.id, e.target.value)}
                >
                  <option value="received">Received</option>
                  <option value="in_progress">In Progress</option>
                  <option value="repair_scheduled">Scheduled</option>
                  <option value="resolved">Resolved</option>
                </select>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
```

### src/App.js

```javascript
import React, { useState, useEffect } from 'react';
import supabase from './services/supabase';
import Map from './components/Map';
import ReportsList from './components/ReportsList';

function App() {
  const [reports, setReports] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedReport, setSelectedReport] = useState(null);

  useEffect(() => {
    fetchReports();
    
    // Subscribe to real-time updates
    const subscription = supabase
      .channel('reports')
      .on('postgres_changes', 
        { event: '*', schema: 'public', table: 'reports' },
        (payload) => {
          console.log('Change received!', payload);
          fetchReports();
        }
      )
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  }, []);

  const fetchReports = async () => {
    setLoading(true);
    const { data, error } = await supabase
      .from('reports')
      .select('*')
      .eq('is_deleted', false)
      .order('created_at', { ascending: false });

    if (error) {
      console.error('Error fetching reports:', error);
    } else {
      setReports(data);
    }
    setLoading(false);
  };

  const handleStatusUpdate = async (reportId, newStatus) => {
    const response = await fetch(
      `${process.env.REACT_APP_BACKEND_URL}/reports/${reportId}/status`,
      {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          status: newStatus,
          updated_by: 'barangay_official'
        }),
      }
    );

    if (response.ok) {
      fetchReports();
    }
  };

  return (
    <div className="min-h-screen bg-gray-100">
      <header className="bg-blue-600 text-white p-4">
        <h1 className="text-2xl font-bold">MapSumbong Dashboard</h1>
        <p className="text-sm">Barangay Nangka, Valenzuela</p>
      </header>

      <main className="container mx-auto p-4">
        {loading ? (
          <div className="text-center py-8">Loading...</div>
        ) : (
          <>
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-4 mb-4">
              <div className="bg-white p-4 rounded shadow">
                <h3 className="text-gray-600 text-sm">Total Reports</h3>
                <p className="text-3xl font-bold">{reports.length}</p>
              </div>
              <div className="bg-white p-4 rounded shadow">
                <h3 className="text-gray-600 text-sm">Critical</h3>
                <p className="text-3xl font-bold text-red-600">
                  {reports.filter(r => r.urgency === 'critical').length}
                </p>
              </div>
              <div className="bg-white p-4 rounded shadow">
                <h3 className="text-gray-600 text-sm">Pending</h3>
                <p className="text-3xl font-bold text-yellow-600">
                  {reports.filter(r => r.status === 'received').length}
                </p>
              </div>
            </div>

            <div className="bg-white p-4 rounded shadow mb-4">
              <h2 className="text-xl font-bold mb-4">Live Map</h2>
              <Map reports={reports} onReportClick={setSelectedReport} />
            </div>

            <div className="bg-white p-4 rounded shadow">
              <h2 className="text-xl font-bold mb-4">Reports Queue</h2>
              <ReportsList reports={reports} onStatusUpdate={handleStatusUpdate} />
            </div>
          </>
        )}
      </main>
    </div>
  );
}

export default App;
```

### tailwind.config.js

```javascript
module.exports = {
  content: ["./src/**/*.{js,jsx,ts,tsx}"],
  theme: { extend: {} },
  plugins: [],
}
```

### src/index.css

```css
@tailwind base;
@tailwind components;
@tailwind utilities;
```

## Run

```bash
npm start
```

Open http://localhost:3000

**Next:** Read 06_TELEGRAM_BOT.md