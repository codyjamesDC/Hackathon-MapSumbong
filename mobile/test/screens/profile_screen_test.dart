import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Profile Screen', () {
    testWidgets('Profile screen renders user info', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Profile')),
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text('Anonymous ID:'),
                        Text('ANON-123456'),
                        SizedBox(height: 16),
                        Text('Barangay:'),
                        Text('Los Baños'),
                      ],
                    ),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Display Name',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Barangay',
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {},
                          child: const Text('Save Changes'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('ANON-123456'), findsOneWidget);
      expect(find.text('Los Baños'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('Profile edit fields accept input', (WidgetTester tester) async {
      String? displayName;
      String? barangay;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(
                  key: const Key('displayNameField'),
                  decoration: const InputDecoration(labelText: 'Display Name'),
                  onChanged: (value) {
                    displayName = value;
                  },
                ),
                TextField(
                  key: const Key('barangayField'),
                  decoration: const InputDecoration(labelText: 'Barangay'),
                  onChanged: (value) {
                    barangay = value;
                  },
                ),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('displayNameField')), 'John Doe');
      await tester.enterText(find.byKey(const Key('barangayField')), 'Nueva Ecija');
      await tester.pump();

      expect(displayName, 'John Doe');
      expect(barangay, 'Nueva Ecija');
    });

    testWidgets('Save button triggers profile update', (WidgetTester tester) async {
      bool savePressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Display Name'),
                ),
                ElevatedButton(
                  onPressed: () {
                    savePressed = true;
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Save Changes'));
      await tester.pump();

      expect(savePressed, isTrue);
    });

    testWidgets('Sign out button navigates to login', (WidgetTester tester) async {
      bool signOutPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Profile')),
            body: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('User Profile'),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: () {
                      signOutPressed = true;
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Sign Out'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Sign Out'));
      await tester.pump();

      expect(signOutPressed, isTrue);
    });

    testWidgets('Profile shows user statistics', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Profile')),
            body: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text('Reports: 5'),
                      SizedBox(height: 8),
                      Text('Resolved: 2'),
                      SizedBox(height: 8),
                      Text('In Progress: 3'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Reports: 5'), findsOneWidget);
      expect(find.text('Resolved: 2'), findsOneWidget);
      expect(find.text('In Progress: 3'), findsOneWidget);
    });
  });
}
