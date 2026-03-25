import 'package:flutter_test/flutter_test.dart';
import 'package:mapsumbong/models/message.dart';
import 'package:mapsumbong/services/offline_store_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saves and loads queued messages', () async {
    final queued = [
      Message(
        id: 'local-1',
        reportId: 'RPT-001',
        senderId: 'ANON-1',
        senderType: 'resident',
        content: 'Queued message',
        messageType: 'text',
      ),
    ];

    await OfflineStoreService.saveQueuedMessages(queued);
    final loaded = await OfflineStoreService.loadQueuedMessages();

    expect(loaded.length, 1);
    expect(loaded.first.content, 'Queued message');
  });

  test('saves and loads report cache', () async {
    final messages = [
      Message(
        id: 'm-1',
        reportId: 'RPT-002',
        senderId: 'ANON-2',
        senderType: 'resident',
        content: 'Cached',
        messageType: 'text',
      ),
    ];

    await OfflineStoreService.saveReportMessages('RPT-002', messages);
    final loaded = await OfflineStoreService.loadReportMessages('RPT-002');

    expect(loaded.length, 1);
    expect(loaded.first.reportId, 'RPT-002');
  });
}
