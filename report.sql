WITH seed(barangay, latitude, longitude, issue_type, urgency, description, location_text, sdg_tag) AS (
    VALUES
        -- Cluster: 5 Reports in Batong Malake
        ('Batong Malake', 14.1595, 121.2310, 'waste', 'medium', 'Overflowing bin near food establishments', 'Raymundo Gate area', 'SDG11'),
        ('Batong Malake', 14.1602, 121.2305, 'road_hazard', 'high', 'Deep pothole hidden by puddle', 'F.O. Santos St.', 'SDG9'),
        ('Batong Malake', 14.1588, 121.2322, 'medical', 'low', 'Request for stray animal capture/control', 'Democracy Plaza vicinity', 'SDG3'),
        ('Batong Malake', 14.1615, 121.2318, 'power_outage', 'medium', 'Partial brownout affecting one side of the street', 'Lopez Avenue upper', 'SDG7'),
        ('Batong Malake', 14.1592, 121.2300, 'flood', 'high', 'Gutter overflow reaching sidewalk level', 'Near UPLB Main Gate', 'SDG11'),

        -- 15 Additional Reports
        ('Anos', 14.1720, 121.2345, 'road_hazard', 'medium', 'Loose gravel on sharp curve', 'Anos diversion road', 'SDG9'),
        ('Bagong Silang', 14.1405, 121.2115, 'landslide', 'critical', 'Significant mud across the road after rain', 'Bagong Silang entry', 'SDG13'),
        ('Bambang', 14.1700, 121.2155, 'water_supply', 'low', 'Low water pressure reported during peak hours', 'Bambang Zone 3', 'SDG6'),
        ('Baybayin', 14.1800, 121.2220, 'waste', 'medium', 'Plastic waste clogging drainage grate', 'Baybayin shoreline', 'SDG14'),
        ('Bayog', 14.1875, 121.2480, 'flood', 'high', 'Rising lake water affecting coastal path', 'Bayog lakeside', 'SDG13'),
        ('Lalakay', 14.1725, 121.2100, 'road_hazard', 'critical', 'Large boulder fell onto the shoulder', 'Lalakay mountain side', 'SDG9'),
        ('Maahas', 14.1705, 121.2565, 'medical', 'high', 'Allergic reaction incident at local residence', 'Maahas interior', 'SDG3'),
        ('Malinta', 14.1835, 121.2300, 'fire', 'low', 'Smoldering trash pile near forest edge', 'Malinta boundary', 'SDG15'),
        ('Mayondon', 14.1905, 121.2395, 'road_hazard', 'medium', 'Missing drainage cover on sidewalk', 'Mayondon primary school road', 'SDG11'),
        ('Putho-Tuntungin', 14.1550, 121.2505, 'earthquake_damage', 'low', 'Small hairline cracks on water tank base', 'Tuntungin water tower', 'SDG11'),
        ('San Antonio', 14.1760, 121.2495, 'power_outage', 'high', 'Downed power line due to fallen branch', 'San Antonio perimeter', 'SDG7'),
        ('Tadlac', 14.1785, 121.2055, 'waste', 'low', 'Abandoned bulky furniture on roadside', 'Tadlac access path', 'SDG12'),
        ('Timugan', 14.1695, 121.2210, 'medical', 'critical', 'Unconscious individual found in park', 'Timugan plaza', 'SDG3'),
        ('Anos', 14.1745, 121.2335, 'water_supply', 'medium', 'Discolored water from main line', 'Anos Crossing', 'SDG6'),
        ('Mayondon', 14.1870, 121.2360, 'flood', 'medium', 'Persistent ponding after short showers', 'Mayondon lower zone', 'SDG11')
)
INSERT INTO reports (
    id,
    reporter_anonymous_id,
    issue_type,
    description,
    latitude,
    longitude,
    location_text,
    urgency,
    sdg_tag,
    status,
    barangay,
    photo_url
)
SELECT
    'RPT-' || upper(substr(md5(clock_timestamp()::text || row_number() OVER ()::text), 1, 8)) AS id,
    'ANON-SEED-' || lpad((row_number() OVER () + 34)::text, 3, '0') AS reporter_anonymous_id,
    issue_type,
    description,
    latitude,
    longitude,
    location_text,
    urgency,
    sdg_tag,
    'received' AS status,
    barangay,
    NULL::text AS photo_url
FROM seed;