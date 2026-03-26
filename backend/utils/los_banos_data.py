"""
Los Baños, Laguna location data and barangay information.
Used for restricting reports to Los Baños area and detecting barangay from coordinates.
"""

# Los Baños, Laguna center coordinates
LOS_BANOS_CENTER = {'lat': 14.1698, 'lng': 121.2430}

# Map boundaries for Los Baños (latitude and longitude ranges)
LOS_BANOS_BOUNDS = {
    'min_lat': 14.13,
    'max_lat': 14.21,
    'min_lng': 121.22,
    'max_lng': 121.27
}

# Barangay data with center coordinates and approximate bounds
# Coordinates approximate, used for reverse geocoding
LOS_BANOS_BARANGAYS = {
    'Poblacion': {
        'lat': 14.1694,
        'lng': 121.2428,
        'bounds': {
            'min_lat': 14.1650,
            'max_lat': 14.1738,
            'min_lng': 121.2380,
            'max_lng': 121.2476
        }
    },
    'Baybagin': {
        'lat': 14.1542,
        'lng': 121.2378,
        'bounds': {
            'min_lat': 14.1490,
            'max_lat': 14.1594,
            'min_lng': 121.2320,
            'max_lng': 121.2436
        }
    },
    'Masili': {
        'lat': 14.1756,
        'lng': 121.2456,
        'bounds': {
            'min_lat': 14.1708,
            'max_lat': 14.1804,
            'min_lng': 121.2408,
            'max_lng': 121.2504
        }
    },
    'Magsayo': {
        'lat': 14.1634,
        'lng': 121.2520,
        'bounds': {
            'min_lat': 14.1586,
            'max_lat': 14.1682,
            'min_lng': 121.2472,
            'max_lng': 121.2568
        }
    },
    'Putintan': {
        'lat': 14.1780,
        'lng': 121.2380,
        'bounds': {
            'min_lat': 14.1732,
            'max_lat': 14.1828,
            'min_lng': 121.2332,
            'max_lng': 121.2428
        }
    },
    'Canlubang': {
        'lat': 14.1468,
        'lng': 121.2543,
        'bounds': {
            'min_lat': 14.1420,
            'max_lat': 14.1516,
            'min_lng': 121.2495,
            'max_lng': 121.2591
        }
    },
    'Dalahican': {
        'lat': 14.1810,
        'lng': 121.2456,
        'bounds': {
            'min_lat': 14.1762,
            'max_lat': 14.1858,
            'min_lng': 121.2408,
            'max_lng': 121.2504
        }
    }
}


def is_within_los_banos(lat: float, lng: float) -> bool:
    """
    Check if coordinates are within Los Baños bounds.
    
    Args:
        lat: Latitude
        lng: Longitude
        
    Returns:
        True if within Los Baños bounds, False otherwise
    """
    return (
        LOS_BANOS_BOUNDS['min_lat'] <= lat <= LOS_BANOS_BOUNDS['max_lat'] and
        LOS_BANOS_BOUNDS['min_lng'] <= lng <= LOS_BANOS_BOUNDS['max_lng']
    )


def detect_barangay(lat: float, lng: float) -> str:
    """
    Detect which barangay the coordinates belong to using distance calculation.
    Returns the closest barangay.
    
    Args:
        lat: Latitude
        lng: Longitude
        
    Returns:
        Barangay name (string)
    """
    import math
    
    if not is_within_los_banos(lat, lng):
        return 'Unknown'
    
    min_distance = float('inf')
    closest_barangay = 'Poblacion'  # Default fallback
    
    for barangay_name, barangay_data in LOS_BANOS_BARANGAYS.items():
        # Calculate Euclidean distance
        distance = math.sqrt(
            (lat - barangay_data['lat']) ** 2 +
            (lng - barangay_data['lng']) ** 2
        )
        
        if distance < min_distance:
            min_distance = distance
            closest_barangay = barangay_name
    
    return closest_barangay


def get_barangay_coordinates(barangay: str) -> dict:
    """
    Get center coordinates for a Los Baños barangay.
    
    Args:
        barangay: Barangay name
        
    Returns:
        Dictionary with lat and lng, or Los Baños center if not found
    """
    if barangay in LOS_BANOS_BARANGAYS:
        barangay_data = LOS_BANOS_BARANGAYS[barangay]
        return {
            'lat': barangay_data['lat'],
            'lng': barangay_data['lng']
        }
    
    # Default to Los Baños center
    return LOS_BANOS_CENTER.copy()


def get_all_barangay_names() -> list:
    """
    Get list of all Los Baños barangay names.
    
    Returns:
        List of barangay names sorted alphabetically
    """
    return sorted(list(LOS_BANOS_BARANGAYS.keys()))
