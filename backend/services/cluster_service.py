from dotenv import load_dotenv
load_dotenv()

import os
from datetime import datetime, timedelta
from typing import List, Dict

def _get_supabase():
    """Lazy-load Supabase client so .env is always loaded first."""
    from supabase import create_client
    return create_client(
        os.getenv('SUPABASE_URL'),
        os.getenv('SUPABASE_SERVICE_KEY'),
    )


async def detect_clusters(barangay: str = None) -> List[Dict]:
    """
    Detect clusters of 3+ reports within 500m in last 2 hours.
    """
    try:
        supabase = _get_supabase()

        two_hours_ago = datetime.utcnow() - timedelta(hours=2)

        query = supabase.table('reports').select('*').gte(
            'created_at',
            two_hours_ago.isoformat()
        ).eq('is_deleted', False)

        if barangay:
            query = query.eq('barangay', barangay)

        response = query.execute()
        recent_reports = response.data

        if len(recent_reports) < 3:
            return []

        clusters = []
        processed_reports = set()

        for i, report in enumerate(recent_reports):
            if report['id'] in processed_reports:
                continue

            cluster_reports = [report]

            for other_report in recent_reports[i + 1:]:
                if other_report['id'] in processed_reports:
                    continue

                distance = calculate_distance(
                    report['latitude'], report['longitude'],
                    other_report['latitude'], other_report['longitude'],
                )

                if (distance <= 500 and
                        report['issue_type'] == other_report['issue_type']):
                    cluster_reports.append(other_report)
                    processed_reports.add(other_report['id'])

            if len(cluster_reports) >= 3:
                avg_lat = sum(r['latitude'] for r in cluster_reports) / len(cluster_reports)
                avg_lng = sum(r['longitude'] for r in cluster_reports) / len(cluster_reports)

                cluster_data = {
                    'barangay': report['barangay'],
                    'issue_type': report['issue_type'],
                    'report_count': len(cluster_reports),
                    'latitude': avg_lat,
                    'longitude': avg_lng,
                    'radius_meters': 500,
                    'report_ids': [r['id'] for r in cluster_reports],
                    'alerted': False,
                }

                result = supabase.table('clusters').insert(cluster_data).execute()
                clusters.append(result.data[0])

                for r in cluster_reports:
                    processed_reports.add(r['id'])

        return clusters

    except Exception as e:
        print(f'Cluster detection error: {e}')
        return []


def calculate_distance(lat1: float, lng1: float,
                        lat2: float, lng2: float) -> float:
    """Haversine distance in metres."""
    from math import radians, sin, cos, sqrt, atan2

    R = 6_371_000  # Earth radius in metres
    dlat = radians(lat2 - lat1)
    dlng = radians(lng2 - lng1)
    a = (sin(dlat / 2) ** 2 +
         cos(radians(lat1)) * cos(radians(lat2)) * sin(dlng / 2) ** 2)
    return R * 2 * atan2(sqrt(a), sqrt(1 - a))