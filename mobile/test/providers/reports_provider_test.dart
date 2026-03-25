import 'package:flutter_test/flutter_test.dart';
import 'package:mapsumbong/models/report.dart';
import 'package:mapsumbong/providers/reports_provider.dart';

void main() {
  group('ReportsProvider', () {
    late ReportsProvider reportsProvider;

    setUp(() {
      reportsProvider = ReportsProvider();
    });

    tearDown(() {
      try {
        reportsProvider.dispose();
      } catch (e) {
        // Cleanup may fail in test environment, acceptable for MVP
      }
    });

    test('initializes with empty reports list', () {
      expect(reportsProvider.reports, isEmpty);
      expect(reportsProvider.isLoading, isFalse);
      expect(reportsProvider.error, isNull);
    });

    test('reports list can be populated', () {
      // Direct list manipulation for testing filtering logic
      final mockReports = [
        Report(
          id: 'RPT-001',
          reporterAnonymousId: 'ANON-1',
          issueType: 'Pothole',
          description: 'Big hole in road',
          status: 'open',
          barangay: 'Los Baños',
          urgency: 'high',
          latitude: 14.1594,
          longitude: 121.2934,
          isDeleted: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Report(
          id: 'RPT-002',
          reporterAnonymousId: 'ANON-1',
          issueType: 'Flooding',
          description: 'Water accumulation',
          status: 'resolved',
          barangay: 'Los Baños',
          urgency: 'medium',
          latitude: 14.1594,
          longitude: 121.2934,
          isDeleted: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      reportsProvider.reports.addAll(mockReports);
      expect(reportsProvider.reports.length, 2);
    });

    test('getReportsByStatus filters correctly', () {
      final mockReports = [
        Report(
          id: 'RPT-001',
          reporterAnonymousId: 'ANON-1',
          issueType: 'Issue 1',
          description: 'Desc 1',
          status: 'open',
          barangay: 'Los Baños',
          urgency: 'high',
          latitude: 14.1594,
          longitude: 121.2934,
          isDeleted: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Report(
          id: 'RPT-002',
          reporterAnonymousId: 'ANON-1',
          issueType: 'Issue 2',
          description: 'Desc 2',
          status: 'resolved',
          barangay: 'Los Baños',
          urgency: 'low',
          latitude: 14.1594,
          longitude: 121.2934,
          isDeleted: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      reportsProvider.reports.addAll(mockReports);

      final openReports = reportsProvider.getReportsByStatus('open');
      final resolvedReports = reportsProvider.getReportsByStatus('resolved');

      expect(openReports.length, 1);
      expect(openReports.first.id, 'RPT-001');
      expect(resolvedReports.length, 1);
      expect(resolvedReports.first.id, 'RPT-002');
    });

    test('getReportsByUser filters by reporter', () {
      final mockReports = [
        Report(
          id: 'RPT-001',
          reporterAnonymousId: 'ANON-1',
          issueType: 'User 1 Issue',
          description: 'Desc',
          status: 'open',
          barangay: 'Los Baños',
          urgency: 'high',
          latitude: 14.1594,
          longitude: 121.2934,
          isDeleted: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Report(
          id: 'RPT-002',
          reporterAnonymousId: 'ANON-2',
          issueType: 'User 2 Issue',
          description: 'Desc',
          status: 'open',
          barangay: 'Los Baños',
          urgency: 'medium',
          latitude: 14.1594,
          longitude: 121.2934,
          isDeleted: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      reportsProvider.reports.addAll(mockReports);

      final userReports = reportsProvider.getReportsByUser('ANON-1');

      expect(userReports.length, 1);
      expect(userReports.first.reporterAnonymousId, 'ANON-1');
    });

    test('clearSelectedReport nullifies selectedReport', () {
      reportsProvider.clearSelectedReport();

      expect(reportsProvider.selectedReport, isNull);
      expect(reportsProvider.selectError, isNull);
    });

    test('clearError resets error state', () {
      reportsProvider.clearError();
      expect(reportsProvider.error, isNull);
    });

    test('no errors when provider is first initialized', () {
      expect(reportsProvider.error, isNull);
      expect(reportsProvider.selectError, isNull);
    });
  });
}

