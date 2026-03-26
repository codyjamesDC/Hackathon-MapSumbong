import { writable, derived } from 'svelte/store';

export const disasterMode = writable(false);
export const selectedIncident = writable(null);
export const toastMsg = writable('');
export const activeFilter = writable('all');

export const incidents = writable([
  {
    id: 1,
    type: 'Flash Flood',
    category: 'flood',
    severity: 'critical',
    barangay: 'Baybayin',
    location: 'Main road near Baybayin riverside',
    lat: 14.1812,
    lng: 121.2232,
    reports: 9,
    time: '2 mins ago',
    channel: 'Telegram',
    description: 'Tumataas ang tubig sa kalye sa Baybayin at hirap nang makadaan ang tricycle.',
    ai: 'Flash flood confirmed via clustered reports in low-lying road segment. Temporary road closure recommended.',
    action: 'Lumikas na sa pinakamalapit na evacuation center. Huwag tumawid sa baha.',
    authorities: ['MDRRMO', 'Barangay Captain'],
    resolved: false,
    radius: 360
  },
  {
    id: 2,
    type: 'Structure Fire',
    category: 'fire',
    severity: 'critical',
    barangay: 'Batong Malake',
    location: 'Interior residential area, Batong Malake',
    lat: 14.1591,
    lng: 121.2303,
    reports: 6,
    time: '5 mins ago',
    channel: 'SMS',
    description: 'May sunog sa isang bahay at kumakalat na ang usok sa katabing lote.',
    ai: 'Active structure fire in residential cluster. Immediate BFP and crowd control response needed.',
    action: 'Lumayo sa gusali. Tumawag sa BFP: 160. Huwag gumamit ng elevator.',
    authorities: ['BFP', 'PNP', 'MDRRMO'],
    resolved: false,
    radius: 280
  },
  {
    id: 3,
    type: 'Road Hazard',
    category: 'infrastructure',
    severity: 'high',
    barangay: 'San Antonio',
    location: 'Crossroad near San Antonio barangay hall',
    lat: 14.1742,
    lng: 121.2473,
    reports: 4,
    time: '12 mins ago',
    channel: 'Messenger',
    description: 'Malaking butas sa kalsada na may nakatigil na tubig at delikado sa motorsiklo.',
    ai: 'Road hazard confirmed by multiple reports. Temporary warning barriers are recommended.',
    action: 'Iwasan ang EDSA Guadalupe. Gumamit ng alternative routes.',
    authorities: ['MMDA', 'Barangay Tanod'],
    resolved: false,
    radius: 210
  },
  {
    id: 4,
    type: 'Medical Emergency',
    category: 'medical',
    severity: 'high',
    barangay: 'Maahas',
    location: 'Near footbridge, Maahas',
    lat: 14.1719,
    lng: 121.2579,
    reports: 3,
    time: '18 mins ago',
    channel: 'Voice call',
    description: 'May senior citizen na nahihilo at nahihirapan huminga sa kalsada.',
    ai: 'Medical emergency report indicates respiratory distress. EMS dispatch is recommended immediately.',
    action: 'Tumawag sa 911 agad. Huwag gumalaw ang pasyente.',
    authorities: ['PNP', 'MDRRMO'],
    resolved: false,
    radius: 150
  },
  {
    id: 5,
    type: 'Illegal Dumping',
    category: 'waste',
    severity: 'medium',
    barangay: 'Putho-Tuntungin',
    location: 'Drainage channel, Putho-Tuntungin',
    lat: 14.1530,
    lng: 121.2498,
    reports: 4,
    time: '34 mins ago',
    channel: 'Viber',
    description: 'May nagtatapon ng basura sa kanal kaya bumabara ang daloy ng tubig.',
    ai: 'Illegal dumping near drainage canal increases flood risk during rainfall. Barangay enforcement is needed.',
    action: 'Iulat sa barangay hall.',
    authorities: ['Barangay Captain'],
    resolved: false,
    radius: 170
  },
  {
    id: 6,
    type: 'Downed Power Line',
    category: 'infrastructure',
    severity: 'medium',
    barangay: 'Lalakay',
    location: 'Roadside near multipurpose court, Lalakay',
    lat: 14.1703,
    lng: 121.2082,
    reports: 2,
    time: '41 mins ago',
    channel: 'Telegram',
    description: 'May nahulog na kawad ng kuryente sa tabi ng kalsada.',
    ai: 'Downed electrical line in residential zone. Secure perimeter and coordinate utility response.',
    action: 'Huwag lapitan ang wire. Makipag-ugnayan sa Meralco: 16211.',
    authorities: ['Barangay Captain', 'MDRRMO'],
    resolved: true,
    radius: 150
  }
]);

export const stats = derived(incidents, $incidents => ({
  critical: $incidents.filter(i => i.severity === 'critical' && !i.resolved).length,
  open: $incidents.filter(i => !i.resolved).length,
  resolved: $incidents.filter(i => i.resolved).length,
  total: $incidents.length
}));

export const severityConfig = {
  critical: { color: '#ff3b5c', bg: 'rgba(255,59,92,0.12)', label: 'Critical', ring: 'rgba(255,59,92,0.25)' },
  high:     { color: '#ff8c42', bg: 'rgba(255,140,66,0.12)', label: 'High',     ring: 'rgba(255,140,66,0.2)' },
  medium:   { color: '#f5c842', bg: 'rgba(245,200,66,0.12)', label: 'Medium',   ring: 'rgba(245,200,66,0.18)' },
  low:      { color: '#4ade80', bg: 'rgba(74,222,128,0.12)', label: 'Low',      ring: 'rgba(74,222,128,0.18)' }
};

export const categoryIcons = {
  flood:          '🌊',
  fire:           '🔥',
  infrastructure: '🔧',
  medical:        '🚑',
  waste:          '🗑️',
  other:          '📍'
};
