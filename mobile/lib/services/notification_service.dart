import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Request notification permissions
    await _requestPermissions();

    // Initialize notification settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    final bool? initialized = await _notifications.initialize(
      settings: InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    if (initialized != true) {
      throw Exception('Failed to initialize notifications');
    }
  }

  static Future<void> _requestPermissions() async {
    await Permission.notification.request();
  }

  static Future<void> showReportSubmittedNotification(String reportId) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'reports_channel',
      'Reports',
      channelDescription: 'Notifications for report updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.show(
      id: 1,
      title: 'Report Submitted',
      body: 'Your report $reportId has been submitted successfully!',
      notificationDetails: details,
    );
  }

  static Future<void> showReportStatusUpdateNotification(
    String reportId,
    String newStatus,
  ) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'status_updates_channel',
      'Status Updates',
      channelDescription: 'Notifications for report status changes',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    final statusMessages = {
      'in_progress': 'Your report is now being processed.',
      'repair_scheduled': 'Repair work has been scheduled for your report.',
      'resolved': 'Your report has been resolved!',
    };

    final message = statusMessages[newStatus] ?? 'Your report status has been updated.';

    await _notifications.show(
      id: 2,
      title: 'Report Update',
      body: message,
      notificationDetails: details,
    );
  }

  static Future<void> showClusterAlertNotification(
    String barangay,
    int reportCount,
  ) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'cluster_alerts_channel',
      'Cluster Alerts',
      channelDescription: 'Notifications for report clusters',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.show(
      id: 3,
      title: 'Alert: Multiple Reports',
      body: '$reportCount similar reports detected in $barangay. Authorities have been notified.',
      notificationDetails: details,
    );
  }

  static void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - could navigate to specific screen
    // This would be implemented with navigation logic
  }
}