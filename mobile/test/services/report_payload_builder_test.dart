import 'package:flutter_test/flutter_test.dart';
import 'package:mapsumbong/services/report_payload_builder.dart';

void main() {
  group('ReportPayloadBuilder', () {
    test('normalizes invalid issue_type to other', () {
      final payload = ReportPayloadBuilder.fromExtraction(
        extracted: {
          'issue_type': 'unexpected_type',
          'description': 'desc',
          'location_text': 'loc',
          'barangay': 'Batong Malake',
          'urgency': 'high',
        },
      );

      expect(payload['issue_type'], 'other');
      expect(payload['barangay'], 'Batong Malake');
    });

    test('keeps numeric coordinates and optional photo', () {
      final payload = ReportPayloadBuilder.fromExtraction(
        extracted: {
          'issue_type': 'flood',
          'description': 'flooded road',
          'location_text': 'Main street',
          'barangay': 'Lopez',
          'urgency': 'critical',
          'latitude': 14.123,
          'longitude': 121.321,
        },
        photoUrl: 'https://cdn/sample.jpg',
      );

      expect(payload['issue_type'], 'flood');
      expect(payload['latitude'], 14.123);
      expect(payload['longitude'], 121.321);
      expect(payload['photo_url'], 'https://cdn/sample.jpg');
    });
  });
}
