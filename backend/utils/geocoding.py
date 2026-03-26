import httpx
import math
from typing import Dict, Optional
from .los_banos_data import (
    LOS_BANOS_CENTER,
    LOS_BANOS_BARANGAYS,
    is_within_los_banos,
    detect_barangay,
    get_barangay_coordinates
)

async def get_coordinates(
    location_text: str,
    barangay: str = 'Poblacion'
) -> Dict[str, float]:
    """
    Convert location text to coordinates using OpenStreetMap Nominatim

    Args:
        location_text: Location description (e.g., "school gate")
        barangay: Barangay context for better accuracy (Los Baños only)

    Returns:
        Dictionary with lat and lng
    """
    try:
        # Build search query for Los Baños
        query = f"{location_text}, {barangay}, Los Baños, Laguna, Philippines"

        # Call Nominatim API
        async with httpx.AsyncClient() as client:
            response = await client.get(
                'https://nominatim.openstreetmap.org/search',
                params={
                    'q': query,
                    'format': 'json',
                    'limit': 1
                },
                headers={
                    'User-Agent': 'MapSumbong/1.0 (Disaster Reporting System)'
                },
                timeout=5.0
            )

        data = response.json()

        if data and len(data) > 0:
            return {
                'lat': float(data[0]['lat']),
                'lng': float(data[0]['lon'])
            }
        else:
            # Fallback to barangay center if location not found
            print(f'Location not found: {query}, using barangay center')
            return get_default_coordinates(barangay)

    except Exception as e:
        print(f'Geocoding error: {e}')
        return get_default_coordinates(barangay)

def get_default_coordinates(barangay: str) -> Dict[str, float]:
    """
    Get default coordinates for Los Baños barangay
    """
    # Extract barangay name cleanly
    barangay_name = barangay.split(',')[0].strip()

    # Return specific Los Baños barangay coordinates or center
    coords = get_barangay_coordinates(barangay_name)
    return coords

def reverse_geocode_barangay(lat: float, lng: float) -> str:
    """
    Detect which Los Baños barangay the coordinates belong to.
    Uses distance calculation to find closest barangay.
    
    Args:
        lat: Latitude
        lng: Longitude
        
    Returns:
        Barangay name (string)
    """
    if not is_within_los_banos(lat, lng):
        return 'Unknown'
    
    return detect_barangay(lat, lng)