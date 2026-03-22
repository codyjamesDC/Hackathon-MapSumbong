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
    barangay: 'Brgy. Nangka',
    location: 'Near Nangka Elementary School gate',
    lat: 14.6507,
    lng: 121.1008,
    reports: 14,
    time: '2 mins ago',
    channel: 'Telegram',
    description: 'Bumabaha na sa may gate ng elementary school ng Nangka. Tuhod na halos ang tubig.',
    ai: 'Flash flood confirmed via 14 clustered reports within 500m radius. Water level at knee height — vehicles and pedestrians at serious risk. Pre-emptive evacuation recommended.',
    action: 'Lumikas na sa pinakamalapit na evacuation center. Huwag tumawid sa baha.',
    authorities: ['MDRRMO', 'Barangay Captain'],
    resolved: false,
    radius: 420
  },
  {
    id: 2,
    type: 'Structure Fire',
    category: 'fire',
    severity: 'critical',
    barangay: 'Brgy. Poblacion',
    location: 'Near Poblacion Market, Makati',
    lat: 14.5609,
    lng: 121.0198,
    reports: 9,
    time: '5 mins ago',
    channel: 'SMS',
    description: 'May sunog sa tabi ng palengke. Kumakalat na ang apoy sa mga karatig bahay.',
    ai: 'Active fire in high-density residential area adjacent to market. BFP dispatch critical. Risk of rapid spread due to proximity of informal structures.',
    action: 'Lumayo sa gusali. Tumawag sa BFP: 160. Huwag gumamit ng elevator.',
    authorities: ['BFP', 'PNP', 'MDRRMO'],
    resolved: false,
    radius: 310
  },
  {
    id: 3,
    type: 'Road Hazard',
    category: 'infrastructure',
    severity: 'high',
    barangay: 'Brgy. Guadalupe',
    location: 'EDSA near Guadalupe Bridge',
    lat: 14.5657,
    lng: 121.0436,
    reports: 7,
    time: '12 mins ago',
    channel: 'Messenger',
    description: 'Malaking butas sa kalsada at may baha. Hindi na makadaan ang mga sasakyan.',
    ai: 'Major road obstruction on primary arterial road. 7 reports from distinct locations confirm multi-lane blockage. Diversion and MMDA response required.',
    action: 'Iwasan ang EDSA Guadalupe. Gumamit ng alternative routes.',
    authorities: ['MMDA', 'Barangay Tanod'],
    resolved: false,
    radius: 280
  },
  {
    id: 4,
    type: 'Medical Emergency',
    category: 'medical',
    severity: 'high',
    barangay: 'Brgy. Holy Spirit',
    location: 'Holy Spirit Drive, Quezon City',
    lat: 14.6889,
    lng: 121.0631,
    reports: 3,
    time: '18 mins ago',
    channel: 'Voice call',
    description: 'May matanda na nanghihina sa kalsada. Hindi makatayo.',
    ai: 'Medical emergency — elderly individual reported unresponsive. Voice transcription indicates collapse event. Immediate EMS dispatch recommended.',
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
    barangay: 'Brgy. Culiat',
    location: 'Culiat Creek drainage area',
    lat: 14.6721,
    lng: 121.0412,
    reports: 5,
    time: '34 mins ago',
    channel: 'Viber',
    description: 'Nagtatapon ng basura sa may drainage. Baka bumaha na naman pag umuulan.',
    ai: 'Illegal waste dumping near drainage canal. Risk of flood escalation during rainfall. Non-urgent but requires barangay response within 24 hours.',
    action: 'Iulat sa barangay hall.',
    authorities: ['Barangay Captain'],
    resolved: false,
    radius: 200
  },
  {
    id: 6,
    type: 'Downed Power Line',
    category: 'infrastructure',
    severity: 'medium',
    barangay: 'Brgy. Pinyahan',
    location: 'Pinyahan Street near basketball court',
    lat: 14.6234,
    lng: 121.0567,
    reports: 4,
    time: '41 mins ago',
    channel: 'Telegram',
    description: 'May nahulog na linya ng kuryente. Delikado para sa mga bata.',
    ai: 'Downed electrical line in residential area. Electrocution risk if standing water is present. Meralco and barangay dispatch required.',
    action: 'Huwag lapitan ang wire. Makipag-ugnayan sa Meralco: 16211.',
    authorities: ['Barangay Captain', 'MDRRMO'],
    resolved: true,
    radius: 180
  },
  {
    id: 7,
    type: 'Flash Flood',
    category: 'flood',
    severity: 'critical',
    barangay: 'Brgy. Bagong Silang',
    location: 'Bagong Silang Caloocan — Zone 4',
    lat: 14.7421,
    lng: 121.0312,
    reports: 18,
    time: '8 mins ago',
    channel: 'SMS',
    description: 'Grabe ang baha dito. Hindi na makakalabas ang mga tao sa bahay nila.',
    ai: 'Rapid flooding in low-lying informal settlement. 18 clustered reports — highest volume in current session. Auto-escalated to critical. Pre-emptive evacuation strongly recommended.',
    action: 'Mag-evacuate na agad. Pumunta sa pinakamataas na lugar.',
    authorities: ['MDRRMO', 'Barangay Captain', 'DSWD'],
    resolved: false,
    radius: 550
  },
  {
    id: 8,
    type: 'Broken Drainage',
    category: 'infrastructure',
    severity: 'low',
    barangay: 'Brgy. New Era',
    location: 'New Era Street corner Batangas',
    lat: 14.6634,
    lng: 121.0523,
    reports: 2,
    time: '1 hr ago',
    channel: 'Messenger',
    description: 'Sira ang drainage. Umaapon na ang basura sa kalsada.',
    ai: 'Blocked drainage causing minor overflow. Low priority — barangay response within 48 hours recommended.',
    action: 'Iulat sa DPWH at barangay.',
    authorities: ['Barangay Captain'],
    resolved: true,
    radius: 120
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
