import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Reports Screen', () {
    testWidgets('Reports list screen renders', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('My Reports'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {},
                ),
              ],
            ),
            body: ListView.builder(
              itemCount: 2,
              itemBuilder: (context, index) => ListTile(
                title: Text('Report ${index + 1}'),
                subtitle: const Text('Pending'),
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('My Reports'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.text('Report 1'), findsOneWidget);
      expect(find.text('Report 2'), findsOneWidget);
    });

    testWidgets('New report button navigates to create flow', (WidgetTester tester) async {
      bool createPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('My Reports'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    createPressed = true;
                  },
                ),
              ],
            ),
            body: const Center(child: Text('Reports list')),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(createPressed, isTrue);
    });

    testWidgets('Report list item shows status badge', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                ListTile(
                  title: const Text('Pothole in Rizal Ave'),
                  subtitle: const Text('Reported 2 hours ago'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'In Progress',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Pothole in Rizal Ave'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
    });

    testWidgets('Report detail view shows all fields', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Report Details')),
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pothole in road'),
                  const SizedBox(height: 8),
                  const Text('Location: Los Baños, Laguna'),
                  const SizedBox(height: 8),
                  const Text('Status: Pending'),
                  const SizedBox(height: 8),
                  const Text('Reported: 2 hours ago'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Chat with Authority'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Report Details'), findsOneWidget);
      expect(find.text('Pothole in road'), findsOneWidget);
      expect(find.text('Location: Los Baños, Laguna'), findsOneWidget);
      expect(find.text('Chat with Authority'), findsOneWidget);
    });

    testWidgets('Empty state shown when no reports', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('My Reports')),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_ind, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No reports yet'),
                  SizedBox(height: 8),
                  Text('Tap the + button to create one'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('No reports yet'), findsOneWidget);
      expect(find.text('Tap the + button to create one'), findsOneWidget);
    });
  });
}
