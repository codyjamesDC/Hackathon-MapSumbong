"""
Los Baños, Laguna location data and barangay information.
Used for restricting reports to Los Baños area and detecting barangay from coordinates.
"""

# Los Baños, Laguna center coordinates
LOS_BANOS_CENTER = {'lat': 14.1698, 'lng': 121.2430}

# Map boundaries for Los Baños (latitude and longitude ranges)
# Extracted from Overpass Turbo barangay boundaries
LOS_BANOS_BOUNDS = {
    'min_lat': 14.111328,
    'max_lat': 14.197138,
    'min_lng': 121.171335,
    'max_lng': 121.266119
}

# Barangay data with center coordinates and approximate bounds
# Coordinates extracted from Overpass Turbo - actual OSM administrative boundaries
LOS_BANOS_BARANGAYS = {
    'Anos': {
        'lat': 14.173906,
        'lng': 121.233077,
        'bounds': {
            'min_lat': 14.165876,
            'max_lat': 14.181936,
            'min_lng': 121.225943,
            'max_lng': 121.240212
        }
    },
    'Bagong Silang': {
        'lat': 14.139438,
        'lng': 121.210343,
        'bounds': {
            'min_lat': 14.111328,
            'max_lat': 14.167548,
            'min_lng': 121.171335,
            'max_lng': 121.249351
        }
    },
    'Bambang': {
        'lat': 14.17166,
        'lng': 121.21682,
        'bounds': {
            'min_lat': 14.162554,
            'max_lat': 14.180767,
            'min_lng': 121.210951,
            'max_lng': 121.222689
        }
    },
    'Batong Malake': {
        'lat': 14.159099,
        'lng': 121.230251,
        'bounds': {
            'min_lat': 14.136346,
            'max_lat': 14.181852,
            'min_lng': 121.204279,
            'max_lng': 121.256222
        }
    },
    'Baybayin': {
        'lat': 14.181197,
        'lng': 121.223237,
        'bounds': {
            'min_lat': 14.179488,
            'max_lat': 14.182906,
            'min_lng': 121.220531,
            'max_lng': 121.225943
        }
    },
    'Bayog': {
        'lat': 14.189349,
        'lng': 121.249352,
        'bounds': {
            'min_lat': 14.181561,
            'max_lat': 14.197138,
            'min_lng': 121.238492,
            'max_lng': 121.260213
        }
    },
    'Lalakay': {
        'lat': 14.170333,
        'lng': 121.208158,
        'bounds': {
            'min_lat': 14.163604,
            'max_lat': 14.177061,
            'min_lng': 121.200216,
            'max_lng': 121.216099
        }
    },
    'Maahas': {
        'lat': 14.171918,
        'lng': 121.257908,
        'bounds': {
            'min_lat': 14.156248,
            'max_lat': 14.187588,
            'min_lng': 121.249698,
            'max_lng': 121.266119
        }
    },
    'Malinta': {
        'lat': 14.184989,
        'lng': 121.231089,
        'bounds': {
            'min_lat': 14.181274,
            'max_lat': 14.188704,
            'min_lng': 121.225679,
            'max_lng': 121.2365
        }
    },
    'Mayondon': {
        'lat': 14.189879,
        'lng': 121.238891,
        'bounds': {
            'min_lat': 14.181649,
            'max_lat': 14.19811,
            'min_lng': 121.231703,
            'max_lng': 121.246079
        }
    },
    'Putho-Tuntungin': {
        'lat': 14.153004,
        'lng': 121.249828,
        'bounds': {
            'min_lat': 14.14095,
            'max_lat': 14.165058,
            'min_lng': 121.236601,
            'max_lng': 121.263055
        }
    },
    'San Antonio': {
        'lat': 14.174239,
        'lng': 121.247285,
        'bounds': {
            'min_lat': 14.166696,
            'max_lat': 14.181783,
            'min_lng': 121.240981,
            'max_lng': 121.253589
        }
    },
    'Tadlac': {
        'lat': 14.179379,
        'lng': 121.206832,
        'bounds': {
            'min_lat': 14.171661,
            'max_lat': 14.187097,
            'min_lng': 121.201377,
            'max_lng': 121.212287
        }
    },
    'Timugan': {
        'lat': 14.170458,
        'lng': 121.222579,
        'bounds': {
            'min_lat': 14.159642,
            'max_lat': 14.181274,
            'min_lng': 121.212102,
            'max_lng': 121.233057
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
