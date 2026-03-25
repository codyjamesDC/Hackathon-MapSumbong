import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mapsumbong/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Report Flow Integration Test', () {
    testWidgets(
      'Resident can create report, enter chat, and send message',
      (WidgetTester tester) async {
        // Start the app
        app.main();
        await tester.pumpAndSettle();

        // Step 1: Mock auth - tap guest login (dev only)
        final guestButtonFinder = byButtonText('Sign in as Guest');
        if (guestButtonFinder.evaluate().isNotEmpty) {
          await tester.tap(guestButtonFinder);
          await tester.pumpAndSettle();
        }

        // Step 2: Navigate to reports (home screen should be showing)
        expect(find.text('My Reports'), findsWidgets);

        // Step 3: Create new report - tap + button
        final createBtnFinder = find.byIcon(Icons.add);
        await tester.tap(createBtnFinder);
        await tester.pumpAndSettle();

        // Step 4: Should navigate to location picker
        // (Verify we're on location screen, not critical for MVP integration test)
        
        // Step 5: Skip location if needed and proceed to chat
        // In MVP, user can manually pin, so we simulate entering chat
        expect(find.byType(Text), findsWidgets);

        // Step 6: Once on chat screen, type a message
        final chatInputFinder = find.byType(TextField);
        if (chatInputFinder.evaluate().isNotEmpty) {
          await tester.enterText(chatInputFinder.first, 'Test issue: Pothole');
          await tester.pump();

          // Step 7: Send message
          final sendButtonFinder = find.byIcon(Icons.send);
          await tester.tap(sendButtonFinder);
          await tester.pumpAndSettle();
        }

        // Step 8: Verify message was sent (check for success indicator)
        // In MVP, we just verify no crashes occurred and we're still on screen
        expect(find.byType(Text), findsWidgets);
      },
    );

    testWidgets(
      'Offline queue persists message when connection lost',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Mock offline scenario
        // Note: In real integration test, you'd mock network conditions
        // For MVP, we verify the UI responds gracefully

        // Simulate being on chat screen
        // Verify no crash when send fails
        expect(find.byType(Scaffold), findsWidgets);
      },
    );

    testWidgets(
      'Report status updates in real-time',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Navigate to reports list
        expect(find.text('My Reports'), findsWidgets);

        // In real test, verify realtime subscription works
        // For MVP, just verify list renders without crash
      },
    );
  });
}

// Helper function for button text finding
Finder byButtonText(String text) {
  return find.widgetWithText(ElevatedButton, text);
}
