import 'package:flutter_test/flutter_test.dart';
import 'package:mapsumbong/models/message.dart';
import 'package:mapsumbong/providers/messages_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('queues message when send API fails', () async {
    final provider = MessagesProvider(
      sendMessageApi: (message) async => throw Exception('offline'),
      getMessagesApi: (_) async => const [],
      subscribeMessagesApi: (_) => const Stream.empty(),
    );

    await provider.sendAuthorityMessage(
      reportId: 'RPT-001',
      senderId: 'ANON-1',
      senderType: 'resident',
      content: 'Hello offline',
    );

    expect(provider.queuedMessageCount, 1);
    expect(provider.hasConnectionIssue, isTrue);
  });

  test('retry queued messages clears queue when API recovers', () async {
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
          imageUrl: message.imageUrl,
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
      content: 'Retry me',
    );

    expect(provider.queuedMessageCount, 1);

    shouldFail = false;
    await provider.retryQueuedMessages();

    expect(provider.queuedMessageCount, 0);
    expect(provider.hasConnectionIssue, isFalse);
  });
}
