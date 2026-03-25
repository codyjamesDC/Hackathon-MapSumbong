/// Normalizes AI `report_data` into the shape expected by `POST /submit-report`.
class ReportPayloadBuilder {
  static const _issueTypes = {
    'flood',
    'pothole',
    'broken_streetlight',
    'garbage',
    'road_damage',
    'power_outage',
    'water_problem',
    'emergency',
    'fire',
    'other',
  };

  static String _normalizeIssueType(dynamic raw) {
    final s = (raw ?? 'other').toString().trim().toLowerCase();
    if (_issueTypes.contains(s)) return s;
    return 'other';
  }

  static String? _string(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Build JSON body for [ApiService.submitReport] (spread + reporter_anonymous_id added there).
  static Map<String, dynamic> fromExtraction({
    required Map<String, dynamic> extracted,
    String? photoUrl,
  }) {
    final lat = _asDouble(extracted['latitude']);
    final lng = _asDouble(extracted['longitude']);

    return {
      if (extracted['report_id'] != null)
        'report_id': extracted['report_id'].toString(),
      'issue_type': _normalizeIssueType(extracted['issue_type']),
      'description': _string(extracted['description']) ?? '',
      'location_text': _string(extracted['location_text']) ?? '',
      'barangay': _string(extracted['barangay']) ?? 'unknown',
      'urgency': _string(extracted['urgency']) ?? 'medium',
      if (_string(extracted['sdg_tag']) != null) 'sdg_tag': _string(extracted['sdg_tag']),
      if (lat != null) 'latitude': lat,
      if (lng != null) 'longitude': lng,
      if (photoUrl != null && photoUrl.isNotEmpty) 'photo_url': photoUrl,
    };
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
