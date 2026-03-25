import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapsumbong/widgets/message_input.dart';

void main() {
  testWidgets('MessageInput sends typed message', (WidgetTester tester) async {
    String? sent;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageInput(
            reportId: 'RPT-001',
            onSendMessage: (content, {imageUrl}) => sent = content,
            onSendWithAI: (content, {imageUrl}) {},
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Test message');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(sent, 'Test message');
  });
}
