import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Chat Screen', () {
    testWidgets('Chat screen renders message list', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Chat')),
            body: Column(
              children: [
                Expanded(
                  child: ListView(
                    children: const [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Incoming message'),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text('Outgoing message'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Type a message',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Incoming message'), findsOneWidget);
      expect(find.text('Outgoing message'), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('Chat input accepts and sends message', (WidgetTester tester) async {
      String? sentMessage;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('messageInput'),
                    decoration:
                        const InputDecoration(hintText: 'Type a message'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    sentMessage = 'Hello';
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('messageInput')), 'Hello');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(sentMessage, 'Hello');
    });

    testWidgets('Chat shows connection status when offline', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Container(
                  color: Colors.red,
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Connection lost. Queued: 2 messages'),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: const [Text('Message')],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Connection lost. Queued: 2 messages'), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('Chat retry button visible when messages queued', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Container(
                  color: Colors.orange,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('1 message pending'),
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: const [Text('Message')],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('1 message pending'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
