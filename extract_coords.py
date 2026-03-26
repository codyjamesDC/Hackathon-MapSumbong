import json

# Read the GeoJSON
with open('frontend/src/data/los_banos_barangays.geojson', 'r') as f:
    data = json.load(f)

# Extract barangay centers and bounds
barangays = {}
for feature in data['features']:
    name = feature['properties'].get('name')
    if not name:
        continue
    coords = feature['geometry']['coordinates'][0]  # Get polygon coordinates
    
    # Calculate bounds
    lats = [c[1] for c in coords]
    lngs = [c[0] for c in coords]
    min_lat, max_lat = min(lats), max(lats)
    min_lng, max_lng = min(lngs), max(lngs)
    center_lat = (min_lat + max_lat) / 2
    center_lng = (min_lng + max_lng) / 2
    
    barangays[name] = {
        'lat': round(center_lat, 6),
        'lng': round(center_lng, 6),
        'min_lat': round(min_lat, 6),
        'max_lat': round(max_lat, 6),
        'min_lng': round(min_lng, 6),
        'max_lng': round(max_lng, 6)
    }

# Print as Python dict format
print('{')
for name in sorted(barangays.keys()):
    data_dict = barangays[name]
    print(f"    '{name}': " + "{")
    print(f"        'lat': {data_dict['lat']},")
    print(f"        'lng': {data_dict['lng']},")
    print(f"        'bounds': " + "{")
    print(f"            'min_lat': {data_dict['min_lat']},")
    print(f"            'max_lat': {data_dict['max_lat']},")
    print(f"            'min_lng': {data_dict['min_lng']},")
    print(f"            'max_lng': {data_dict['max_lng']}")
    print(f"        " + "}")
    print(f"    " + "},")
print('}')
