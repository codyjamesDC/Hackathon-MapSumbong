import httpx
from typing import Dict, Optional

async def get_coordinates(
    location_text: str,
    barangay: str = 'Nangka, Valenzuela'
) -> Dict[str, float]:
    """
    Convert location text to coordinates using OpenStreetMap Nominatim

    Args:
        location_text: Location description (e.g., "elementary school gate")
        barangay: Barangay context for better accuracy

    Returns:
        Dictionary with lat and lng
    """
    try:
        # Build search query
        query = f"{location_text}, {barangay}, Metro Manila, Philippines"

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
            print(f'Location not found: {query}, using default coordinates')
            return get_default_coordinates(barangay)

    except Exception as e:
        print(f'Geocoding error: {e}')
        return get_default_coordinates(barangay)

def get_default_coordinates(barangay: str) -> Dict[str, float]:
    """
    Get default coordinates for barangay
    """
    # Default coordinates for common barangays in Valenzuela
    defaults = {
        'Nangka': {'lat': 14.6042, 'lng': 120.9822},
        'Marulas': {'lat': 14.7080, 'lng': 120.9617},
        'Malinta': {'lat': 14.7028, 'lng': 120.9681},
    }

    # Extract barangay name
    barangay_name = barangay.split(',')[0].strip()

    # Return specific coordinates or Valenzuela center
    return defaults.get(barangay_name, {'lat': 14.6942, 'lng': 120.9834})