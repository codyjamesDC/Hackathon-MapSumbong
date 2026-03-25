import 'package:flutter_test/flutter_test.dart';
import 'package:mapsumbong/models/message.dart';

void main() {
  group('Message model', () {
    test('fromJson parses created_at fallback', () {
      final json = {
        'id': 'm1',
        'report_id': 'RPT-001',
        'sender_id': 'ANON-1',
        'sender_type': 'resident',
        'content': 'Hello',
        'message_type': 'text',
        'created_at': '2026-03-25T01:02:03Z',
      };

      final message = Message.fromJson(json);

      expect(message.id, 'm1');
      expect(message.reportId, 'RPT-001');
      expect(message.content, 'Hello');
      expect(message.timestamp.toUtc().year, 2026);
    });

    test('toJson writes required keys', () {
      final message = Message(
        id: 'm2',
        reportId: 'RPT-002',
        senderId: 'ANON-2',
        senderType: 'authority',
        content: 'Resolved',
        messageType: 'text',
      );

      final json = message.toJson();

      expect(json['id'], 'm2');
      expect(json['report_id'], 'RPT-002');
      expect(json['sender_type'], 'authority');
      expect(json.containsKey('timestamp'), isTrue);
    });
  });
}
