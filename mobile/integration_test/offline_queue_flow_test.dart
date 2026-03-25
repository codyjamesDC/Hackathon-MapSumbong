import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mapsumbong/models/message.dart';
import 'package:mapsumbong/providers/messages_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline queue can be retried successfully', (tester) async {
    SharedPreferences.setMockInitialValues({});

    var shouldFail = true;
    final provider = MessagesProvider(
      sendMessageApi: (message) async {
        if (shouldFail) throw Exception('offline');
        return Message(
          id: 'server-1',
          reportId: message.reportId,
          senderId: message.senderId,
          senderType: message.senderType,
          content: message.content,
          messageType: message.messageType,
          timestamp: DateTime.now(),
        );
      },
      getMessagesApi: (_) async => const [],
      subscribeMessagesApi: (_) => const Stream.empty(),
    );

    await provider.sendAuthorityMessage(
      reportId: 'RPT-001',
      senderId: 'ANON-1',
      senderType: 'resident',
      content: 'Will queue',
    );
    expect(provider.queuedMessageCount, 1);

    shouldFail = false;
    await provider.retryQueuedMessages();
    expect(provider.queuedMessageCount, 0);
  });
}
