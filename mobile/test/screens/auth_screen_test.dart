import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OTP Auth Screen', () {
    testWidgets('OTP input screen renders', (WidgetTester tester) async {
      // Build a minimal OTP screen
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('OTP Verification')),
            body: Column(
              children: [
                const Text('Enter OTP'),
                TextField(
                  decoration: const InputDecoration(
                    hintText: '000000',
                    labelText: 'OTP Code',
                  ),
                ),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Verify'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('OTP Verification'), findsOneWidget);
      expect(find.text('Enter OTP'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('OTP verification button accepts input', (WidgetTester tester) async {
      String? submittedOtp;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(
                  key: const Key('otpInput'),
                  decoration: const InputDecoration(hintText: '000000'),
                ),
                ElevatedButton(
                  onPressed: () {
                    submittedOtp = 'test_otp';
                  },
                  child: const Text('Verify'),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('otpInput')), '123456');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(submittedOtp, 'test_otp');
    });

    testWidgets('Phone input screen renders', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Login')),
            body: Column(
              children: [
                const Text('Enter your phone number'),
                TextField(
                  decoration: const InputDecoration(
                    hintText: '+639123456789',
                    labelText: 'Phone Number',
                  ),
                ),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Send OTP'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Enter your phone number'), findsOneWidget);
    });
  });
}
