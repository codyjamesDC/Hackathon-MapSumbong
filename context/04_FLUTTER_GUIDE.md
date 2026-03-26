# MapSumbong Flutter Guide

Complete Flutter mobile app implementation for resident disaster reporting.

---

## Prerequisites

- Flutter 3.10 or higher
- Android Studio or VS Code with Flutter extension
- Android device or emulator (API 21+)
- Git

---

## Project Setup

### Step 1: Create Flutter Project

```bash
# Create new Flutter project
flutter create mapsumbong
cd mapsumbong

# Initialize git repository
git init
git add .
git commit -m "Initial Flutter project"
```

### Step 2: Add Dependencies

```bash
# Core dependencies
flutter pub add supabase_flutter http image_picker flutter_dotenv provider go_router

# Additional dependencies for enhanced UX
flutter pub add cached_network_image flutter_image_compress intl shared_preferences
flutter pub add flutter_local_notifications permission_handler geolocator

# Development dependencies
flutter pub add flutter_lints flutter_test --dev

# Create pubspec.yaml backup
cp pubspec.yaml pubspec.yaml.backup
```

### Step 3: Project Structure

Create the following folder structure:

```bash
# Create directories
mkdir -p lib/{screens,pages,widgets,services,models,providers,utils,constants}

# Create files
touch lib/{main.dart,constants/app_constants.dart}
touch lib/services/{api_service.dart,supabase_service.dart,notification_service.dart}
touch lib/models/{report.dart,user.dart,message.dart}
touch lib/providers/{auth_provider.dart,reports_provider.dart}
touch lib/screens/{auth_screen.dart,chat_screen.dart,reports_screen.dart,profile_screen.dart}
touch lib/widgets/{chat_bubble.dart,report_card.dart,loading_indicator.dart}
touch lib/utils/{validators.dart,formatters.dart,permissions.dart}
```

---

## Configuration

### Environment Variables

Create `.env` file in project root:

```bash
# Supabase Configuration
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Backend Configuration
BACKEND_URL=http://10.0.2.2:8000  # Android emulator
# BACKEND_URL=http://localhost:8000  # iOS simulator
# BACKEND_URL=https://mapsumbong-backend.onrender.com  # Production

# App Configuration
APP_NAME=MapSumbong
APP_VERSION=1.0.0
ENVIRONMENT=development

# Optional: Push Notifications
FCM_SERVER_KEY=your_fcm_server_key_here
```

### Resolved Status Behavior (Mobile)

When backend/dashboard marks a report as `resolved`:

- Mobile app should display the report as `resolved` immediately.
- Mobile app should still show a follow-up requirement if closure proof is incomplete.
- Full completion requires both:
  - `resolution_note` (written report from official)
  - `resolution_photo_url` (evidence photo)

Recommended resident-facing copy (Taglish):

- `Naka-resolve na ayon sa opisyal, pero hinihintay pa ang written report at photo evidence para ma-finalize ang case.`

### App Constants

Create `lib/constants/app_constants.dart`:

```dart
class AppConstants {
  // API Endpoints
  static const String baseUrl = String.fromEnvironment('BACKEND_URL',
      defaultValue: 'http://10.0.2.2:8000');

  // Supabase
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // App Info
  static const String appName = 'MapSumbong';
  static const String appVersion = '1.0.0';

  // Issue Types
  static const List<String> issueTypes = [
    'flood', 'waste', 'road', 'power', 'water',
    'emergency', 'fire', 'crime', 'other'
  ];

  // Urgency Levels
  static const Map<String, String> urgencyLabels = {
    'critical': 'Kritikal',
    'high': 'Mataas',
    'medium': 'Katamtaman',
    'low': 'Mababa'
  };

  // Status Labels
  static const Map<String, String> statusLabels = {
    'received': 'Natanggap',
    'in_progress': 'Pinoproseso',
    'repair_scheduled': 'Nakaiskedyul',
    'resolved': 'Nalutas',
    'reopened': 'Muling Binuka'
  };

  // Colors
  static const Map<String, int> urgencyColors = {
    'critical': 0xFFEF4444,  // Red
    'high': 0xFFF59E0B,     // Orange
    'medium': 0xFFFBBF24,   // Yellow
    'low': 0xFF10B981,      // Green
  };
}
```

---

## Core Implementation

### main.dart

Main application entry point with providers and routing.

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'constants/app_constants.dart';
import 'providers/auth_provider.dart';
import 'providers/reports_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/profile_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Supabase
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  // Initialize notifications
  await NotificationService.initialize();

  runApp(const MapSumbongApp());
}

class MapSumbongApp extends StatelessWidget {
  const MapSumbongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ReportsProvider()),
      ],
      child: MaterialApp.router(
        title: AppConstants.appName,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'Roboto',
          textTheme: const TextTheme(
            bodyLarge: TextStyle(fontSize: 16),
            bodyMedium: TextStyle(fontSize: 14),
          ),
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', ''), // English
          Locale('tl', ''), // Filipino
        ],
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

// GoRouter configuration
final GoRouter _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) => const ChatScreen(),
    ),
    GoRoute(
      path: '/reports',
      builder: (context, state) => const ReportsScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
  ],
  redirect: (context, state) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isLoggedIn = authProvider.isAuthenticated;

    if (!isLoggedIn && state.location != '/') {
      return '/';
    }
    if (isLoggedIn && state.location == '/') {
      return '/chat';
    }
    return null;
  },
);
```

---

## Models

### Report Model

```dart
// lib/models/report.dart
class Report {
  final String id;
  final String reporterAnonymousId;
  final String issueType;
  final String description;
  final String? photoUrl;
  final double latitude;
  final double longitude;
  final String? locationText;
  final String barangay;
  final String urgency;
  final String? sdgTag;
  final String status;
  final String? resolutionNote;
  final String? resolutionPhotoUrl;
  final bool? residentConfirmed;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  Report({
    required this.id,
    required this.reporterAnonymousId,
    required this.issueType,
    required this.description,
    this.photoUrl,
    required this.latitude,
    required this.longitude,
    this.locationText,
    required this.barangay,
    required this.urgency,
    this.sdgTag,
    required this.status,
    this.resolutionNote,
    this.resolutionPhotoUrl,
    this.residentConfirmed,
    this.resolvedAt,
    this.resolvedBy,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'],
      reporterAnonymousId: json['reporter_anonymous_id'],
      issueType: json['issue_type'],
      description: json['description'],
      photoUrl: json['photo_url'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      locationText: json['location_text'],
      barangay: json['barangay'],
      urgency: json['urgency'],
      sdgTag: json['sdg_tag'],
      status: json['status'],
      resolutionNote: json['resolution_note'],
      resolutionPhotoUrl: json['resolution_photo_url'],
      residentConfirmed: json['resident_confirmed'],
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'])
          : null,
      resolvedBy: json['resolved_by'],
      isDeleted: json['is_deleted'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reporter_anonymous_id': reporterAnonymousId,
      'issue_type': issueType,
      'description': description,
      'photo_url': photoUrl,
      'latitude': latitude,
      'longitude': longitude,
      'location_text': locationText,
      'barangay': barangay,
      'urgency': urgency,
      'sdg_tag': sdgTag,
      'status': status,
      'resolution_note': resolutionNote,
      'resolution_photo_url': resolutionPhotoUrl,
      'resident_confirmed': residentConfirmed,
      'resolved_at': resolvedAt?.toIso8601String(),
      'resolved_by': resolvedBy,
      'is_deleted': isDeleted,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helper methods
  String getUrgencyLabel() {
    return AppConstants.urgencyLabels[urgency] ?? urgency;
  }

  String getStatusLabel() {
    return AppConstants.statusLabels[status] ?? status;
  }

  Color getUrgencyColor() {
    final colorValue = AppConstants.urgencyColors[urgency];
    return colorValue != null ? Color(colorValue) : Colors.grey;
  }

  bool get isResolved => status == 'resolved';
  bool get isInProgress => status == 'in_progress';
  bool get isCritical => urgency == 'critical';
}
```

### Message Model

```dart
// lib/models/message.dart
class Message {
  final String id;
  final String content;
  final bool isUser;
  final String? reportId;
  final String? photoUrl;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.content,
    required this.isUser,
    this.reportId,
    this.photoUrl,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      content: json['content'],
      isUser: json['is_user'],
      reportId: json['report_id'],
      photoUrl: json['photo_url'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'is_user': isUser,
      'report_id': reportId,
      'photo_url': photoUrl,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
```

### User Model

```dart
// lib/models/user.dart
class User {
  final String id;
  final String? phoneHash;
  final String anonymousId;
  final String accountType;
  final String? displayName;
  final bool isAnonymous;
  final String? barangay;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.phoneHash,
    required this.anonymousId,
    required this.accountType,
    this.displayName,
    required this.isAnonymous,
    this.barangay,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      phoneHash: json['phone_hash'],
      anonymousId: json['anonymous_id'],
      accountType: json['account_type'],
      displayName: json['display_name'],
      isAnonymous: json['is_anonymous'] ?? true,
      barangay: json['barangay'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone_hash': phoneHash,
      'anonymous_id': anonymousId,
      'account_type': accountType,
      'display_name': displayName,
      'is_anonymous': isAnonymous,
      'barangay': barangay,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String getDisplayName() {
    if (!isAnonymous && displayName != null) {
      return displayName!;
    }
    return 'Anonymous User';
  }
}
```

---

## Services

### API Service

```dart
// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../constants/app_constants.dart';
import '../models/report.dart';

class ApiService {
  static final String _baseUrl = AppConstants.baseUrl;
  static const String _timeout = Duration(seconds: 30);

  // Process message with Claude AI
  static Future<Map<String, dynamic>> processMessage({
    required String message,
    required String reporterId,
    File? photo,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/process-message'),
      );

      request.fields['message'] = message;
      request.fields['reporter_id'] = reporterId;

      // Compress and add photo if provided
      if (photo != null) {
        final compressedPhoto = await _compressImage(photo);
        request.files.add(
          http.MultipartFile.fromBytes(
            'photo',
            compressedPhoto,
            filename: 'report_photo.jpg',
          ),
        );
      }

      final response = await request.send().timeout(_timeout);
      final responseData = await response.stream.bytesToString();
      final data = jsonDecode(responseData);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['detail'] ?? 'Failed to process message');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get user's reports
  static Future<List<Report>> getUserReports(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/reports?reporter_id=$userId&limit=50'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['reports'] as List)
            .map((report) => Report.fromJson(report))
            .toList();
      } else {
        throw Exception('Failed to fetch reports');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get single report
  static Future<Report> getReport(String reportId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/reports/$reportId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return Report.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Report not found');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Reopen resolved report
  static Future<void> reopenReport({
    required String reportId,
    required String reason,
    required String reporterId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/reports/$reportId/reopen'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'reason': reason,
          'reporter_id': reporterId,
        }),
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        final data = jsonDecode(response.body);
        throw Exception(data['detail'] ?? 'Failed to reopen report');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Confirm resolution
  static Future<void> confirmResolution(String reportId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/reports/$reportId/confirm'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('Failed to confirm resolution');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Helper method to compress images
  static Future<Uint8List> _compressImage(File file) async {
    final result = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      quality: 70,
      minWidth: 800,
      minHeight: 600,
    );

    if (result == null) {
      // Return original if compression fails
      return await file.readAsBytes();
    }

    return result;
  }
}
```

### Supabase Service

```dart
// lib/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart';
import '../models/report.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Authentication methods
  static Future<User?> signInWithOTP(String phoneNumber) async {
    try {
      final response = await _client.auth.signInWithOtp(
        phone: phoneNumber,
      );
      return null; // OTP sent, user will be signed in via callback
    } catch (e) {
      throw Exception('Failed to send OTP: $e');
    }
  }

  static Future<User?> verifyOTP(String phoneNumber, String otp) async {
    try {
      final response = await _client.auth.verifyOTP(
        phone: phoneNumber,
        token: otp,
        type: OtpType.sms,
      );

      if (response.user != null) {
        // Get or create user profile
        return await _getOrCreateUser(response.user!.id, phoneNumber);
      }
      return null;
    } catch (e) {
      throw Exception('Invalid OTP: $e');
    }
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // User management
  static Future<User> _getOrCreateUser(String authId, String phoneNumber) async {
    try {
      // Check if user exists
      final existingUser = await _client
          .from('users')
          .select()
          .eq('id', authId)
          .single();

      if (existingUser != null) {
        return User.fromJson(existingUser);
      }

      // Create new user
      final newUser = {
        'id': authId,
        'phone_hash': _hashPhoneNumber(phoneNumber),
        'anonymous_id': _generateAnonymousId(),
        'account_type': 'resident',
        'is_anonymous': true,
      };

      final response = await _client
          .from('users')
          .insert(newUser)
          .select()
          .single();

      return User.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  static Future<User?> getCurrentUser() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return null;

    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', authUser.id)
          .single();

      return User.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Real-time subscriptions
  static Stream<List<Report>> subscribeToUserReports(String userId) {
    return _client
        .from('reports')
        .stream(primaryKey: ['id'])
        .eq('reporter_anonymous_id', userId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .map((data) => data.map((report) => Report.fromJson(report)).toList());
  }

  // Storage methods
  static Future<String> uploadPhoto(File photo, String userId) async {
    try {
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final response = await _client.storage
          .from('photos')
          .upload(fileName, photo);

      final publicUrl = _client.storage
          .from('photos')
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload photo: $e');
    }
  }

  // Helper methods
  static String _hashPhoneNumber(String phoneNumber) {
    // Simple hash for demo - use proper hashing in production
    return phoneNumber.hashCode.toString();
  }

  static String _generateAnonymousId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'ANON-${timestamp.toString().substring(6)}';
  }
}
```

### Notification Service

```dart
// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Request permissions
    await _requestPermissions();

    // Initialize notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
  }

  static Future<void> _requestPermissions() async {
    await Permission.notification.request();
  }

  static Future<void> showReportUpdateNotification({
    required String title,
    required String body,
    required String reportId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'reports_channel',
      'Report Updates',
      channelDescription: 'Notifications for report status updates',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      reportId.hashCode,
      title,
      body,
      details,
      payload: reportId,
    );
  }

  static Future<void> showResolutionNotification(String reportId) async {
    await showReportUpdateNotification(
      title: 'Report Nalutas',
      body: 'Ang inyong report #$reportId ay nalutas na. Paki-confirm kung satisfied kayo.',
      reportId: reportId,
    );
  }

  static Future<void> showReopenedNotification(String reportId) async {
    await showReportUpdateNotification(
      title: 'Report Muling Binuka',
      body: 'Mayroon pang issue sa report #$reportId. Magpoproseso ulit ang barangay.',
      reportId: reportId,
    );
  }
}
```

---

## Providers

### Auth Provider

```dart
// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart';
import '../services/supabase_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      _user = await SupabaseService.getCurrentUser();
    } catch (e) {
      debugPrint('Auth initialization error: $e');
    }

    _isLoading = false;
    notifyListeners();

    // Listen to auth changes
    Supabase.instance.client.auth.onAuthStateChange.listen((event) async {
      if (event.event == AuthChangeEvent.signedIn) {
        _user = await SupabaseService.getCurrentUser();
      } else if (event.event == AuthChangeEvent.signedOut) {
        _user = null;
      }
      notifyListeners();
    });
  }

  Future<void> signInWithOTP(String phoneNumber) async {
    _isLoading = true;
    notifyListeners();

    try {
      await SupabaseService.signInWithOTP(phoneNumber);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> verifyOTP(String phoneNumber, String otp) async {
    _isLoading = true;
    notifyListeners();

    try {
      _user = await SupabaseService.verifyOTP(phoneNumber, otp);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    await SupabaseService.signOut();
    _user = null;
    notifyListeners();
  }
}
```

### Reports Provider

```dart
// lib/providers/reports_provider.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/report.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/supabase_service.dart';

class ReportsProvider with ChangeNotifier {
  List<Report> _reports = [];
  List<Message> _messages = [];
  bool _isLoading = false;
  String? _error;

  List<Report> get reports => _reports;
  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Stream<List<Report>>? _reportsStream;

  void initializeReportsStream(String userId) {
    _reportsStream = SupabaseService.subscribeToUserReports(userId);
    _reportsStream?.listen((reports) {
      _reports = reports;
      notifyListeners();
    });
  }

  Future<void> sendMessage({
    required String message,
    required String reporterId,
    File? photo,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Add user message to chat
      final userMessage = Message(
        id: DateTime.now().toString(),
        content: message,
        isUser: true,
        photoUrl: photo != null ? 'uploading' : null,
      );
      _messages.add(userMessage);
      notifyListeners();

      // Process message with backend
      final result = await ApiService.processMessage(
        message: message,
        reporterId: reporterId,
        photo: photo,
      );

      // Add bot response
      final botMessage = Message(
        id: DateTime.now().toString(),
        content: result['chatbot_response'],
        isUser: false,
        reportId: result['report_id'],
      );
      _messages.add(botMessage);

      // Refresh reports if new report was created
      if (result['success'] == true) {
        // Reports will be updated via stream
      }

    } catch (e) {
      _error = e.toString();
      // Add error message to chat
      final errorMessage = Message(
        id: DateTime.now().toString(),
        content: 'Pasensya na, may error. Subukan ulit.',
        isUser: false,
      );
      _messages.add(errorMessage);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> reopenReport(String reportId, String reason, String reporterId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await ApiService.reopenReport(
        reportId: reportId,
        reason: reason,
        reporterId: reporterId,
      );
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> confirmResolution(String reportId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await ApiService.confirmResolution(reportId);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
```

---

## Screens

### Authentication Screen

```dart
// lib/screens/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/loading_indicator.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    if (_phoneController.text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signInWithOTP(_phoneController.text);

      setState(() => _otpSent = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP sent to your phone')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.verifyOTP(_phoneController.text, _otpController.text);

      if (mounted) {
        context.go('/chat');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/Title
              const Icon(
                Icons.report_problem,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              const Text(
                'MapSumbong',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Report community issues',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 48),

              // Phone input
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '+63 9XX XXX XXXX',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                enabled: !_otpSent,
              ),
              const SizedBox(height: 16),

              // OTP input (shown after OTP sent)
              if (_otpSent) ...[
                TextField(
                  controller: _otpController,
                  decoration: const InputDecoration(
                    labelText: 'OTP Code',
                    hintText: 'Enter 6-digit code',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
                const SizedBox(height: 16),
              ],

              // Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : (_otpSent ? _verifyOTP : _sendOTP),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const LoadingIndicator(size: 20)
                      : Text(_otpSent ? 'Verify OTP' : 'Send OTP'),
                ),
              ),

              // Back button (when OTP sent)
              if (_otpSent) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => _otpSent = false),
                  child: const Text('Change Phone Number'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

### Chat Screen

```dart
// lib/screens/chat_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/reports_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/loading_indicator.dart';
import '../utils/permissions.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reportsProvider = Provider.of<ReportsProvider>(context, listen: false);

    if (authProvider.user != null) {
      reportsProvider.initializeReportsStream(authProvider.user!.anonymousId);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final hasPermission = await Permissions.requestPhotoPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo permission required')),
        );
      }
      return;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    }
  }

  Future<void> _takePhoto() async {
    final hasPermission = await Permissions.requestCameraPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission required')),
        );
      }
      return;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty && _selectedImage == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reportsProvider = Provider.of<ReportsProvider>(context, listen: false);

    if (authProvider.user == null) return;

    await reportsProvider.sendMessage(
      message: message,
      reporterId: authProvider.user!.anonymousId,
      photo: _selectedImage,
    );

    _messageController.clear();
    setState(() => _selectedImage = null);

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final reportsProvider = Provider.of<ReportsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MapSumbong'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () => context.go('/reports'),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => context.go('/profile'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: reportsProvider.messages.length,
              itemBuilder: (context, index) {
                final message = reportsProvider.messages[index];
                return ChatBubble(message: message);
              },
            ),
          ),

          // Selected image preview
          if (_selectedImage != null) ...[
            Container(
              height: 100,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImage!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => setState(() => _selectedImage = null),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Error message
          if (reportsProvider.error != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reportsProvider.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: reportsProvider.clearError,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Photo buttons
                IconButton(
                  icon: const Icon(Icons.photo),
                  onPressed: _pickImage,
                ),
                IconButton(
                  icon: const Icon(Icons.camera),
                  onPressed: _takePhoto,
                ),

                // Text input
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Describe the problem...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),

                const SizedBox(width: 8),

                // Send button
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: reportsProvider.isLoading ? null : _sendMessage,
                ),
              ],
            ),
          ),

          // Loading indicator
          if (reportsProvider.isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LoadingIndicator(),
            ),
        ],
      ),
    );
  }
}
```

### Reports Screen

```dart
// lib/screens/reports_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/reports_provider.dart';
import '../widgets/report_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final reportsProvider = Provider.of<ReportsProvider>(context);

    if (authProvider.user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reports'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: reportsProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : reportsProvider.reports.isEmpty
              ? const Center(
                  child: Text('No reports yet. Start chatting to report issues!'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reportsProvider.reports.length,
                  itemBuilder: (context, index) {
                    final report = reportsProvider.reports[index];
                    return ReportCard(
                      report: report,
                      onReopen: () => _showReopenDialog(report),
                      onConfirm: () => _confirmResolution(report),
                    );
                  },
                ),
    );
  }

  void _showReopenDialog(Report report) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reopen Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Why do you want to reopen this report?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Enter reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final reportsProvider = Provider.of<ReportsProvider>(context, listen: false);

              if (authProvider.user != null && reasonController.text.isNotEmpty) {
                await reportsProvider.reopenReport(
                  report.id,
                  reasonController.text,
                  authProvider.user!.anonymousId,
                );
              }

              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Reopen'),
          ),
        ],
      ),
    );
  }

  void _confirmResolution(Report report) async {
    final reportsProvider = Provider.of<ReportsProvider>(context, listen: false);

    await reportsProvider.confirmResolution(report.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resolution confirmed!')),
      );
    }
  }
}
```

### Profile Screen

```dart
// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anonymous ID',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      authProvider.user?.anonymousId ?? 'Not logged in',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Display Name',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      authProvider.user?.getDisplayName() ?? 'Not logged in',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Actions
            ListTile(
              leading: const Icon(Icons.help),
              title: const Text('Help & Support'),
              onTap: () => _showHelpDialog(context),
            ),

            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('About MapSumbong'),
              onTap: () => _showAboutDialog(context),
            ),

            const Spacer(),

            // Sign out button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await authProvider.signOut();
                  if (context.mounted) {
                    context.go('/');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Sign Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How to report issues:'),
            SizedBox(height: 8),
            Text('1. Go to Chat screen'),
            Text('2. Type your problem in Filipino/English'),
            Text('3. Add photo if available'),
            Text('4. Send message'),
            SizedBox(height: 16),
            Text('For support, contact your barangay office.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About MapSumbong'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('MapSumbong is an AI-powered disaster reporting system for Filipino communities.'),
            SizedBox(height: 8),
            Text('Version 1.0.0'),
            Text('© 2026 MapSumbong Team'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
```

---

## Widgets

### Chat Bubble

```dart
// lib/widgets/chat_bubble.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/message.dart';

class ChatBubble extends StatelessWidget {
  final Message message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final theme = Theme.of(context);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? theme.primaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo
            if (message.photoUrl != null && message.photoUrl != 'uploading') ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: message.photoUrl!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Photo uploading indicator
            if (message.photoUrl == 'uploading') ...[
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Text
            Text(
              message.content,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black,
                fontSize: 16,
              ),
            ),

            // Report ID
            if (message.reportId != null) ...[
              const SizedBox(height: 8),
              Text(
                'Report ID: ${message.reportId}',
                style: TextStyle(
                  color: isUser ? Colors.white70 : Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

### Report Card

```dart
// lib/widgets/report_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/report.dart';

class ReportCard extends StatelessWidget {
  final Report report;
  final VoidCallback? onReopen;
  final VoidCallback? onConfirm;

  const ReportCard({
    super.key,
    required this.report,
    this.onReopen,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Report #${report.id}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: report.getUrgencyColor(),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    report.getUrgencyLabel(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Issue type and status
            Row(
              children: [
                Text(
                  report.issueType.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(report.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    report.getStatusLabel(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Description
            Text(
              report.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            const SizedBox(height: 8),

            // Location
            if (report.locationText != null) ...[
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      report.locationText!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Photo
            if (report.photoUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: report.photoUrl!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 120,
                    color: Colors.grey.shade200,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 120,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.error),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Resolution note
            if (report.resolutionNote != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resolution:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(report.resolutionNote!),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Timestamp
            Text(
              DateFormat('MMM dd, yyyy hh:mm a').format(report.createdAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 12),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (report.isResolved && onConfirm != null)
                  OutlinedButton(
                    onPressed: onConfirm,
                    child: const Text('Confirm Resolution'),
                  ),
                if (report.isResolved && onReopen != null) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: onReopen,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Reopen'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'received':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      case 'reopened':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
```

### Loading Indicator

```dart
// lib/widgets/loading_indicator.dart
import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  final double size;

  const LoadingIndicator({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CircularProgressIndicator(),
    );
  }
}
```

---

## Utilities

### Validators

```dart
// lib/utils/validators.dart
class Validators {
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    // Philippine phone number regex
    final phoneRegex = RegExp(r'^(09|\+639)\d{9}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Please enter a valid Philippine phone number';
    }

    return null;
  }

  static String? validateOTP(String? value) {
    if (value == null || value.isEmpty) {
      return 'OTP is required';
    }

    if (value.length != 6) {
      return 'OTP must be 6 digits';
    }

    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'OTP must contain only numbers';
    }

    return null;
  }

  static String? validateMessage(String? value) {
    if (value == null || value.isEmpty) {
      return 'Message cannot be empty';
    }

    if (value.trim().length < 5) {
      return 'Message must be at least 5 characters';
    }

    return null;
  }
}
```

### Permissions

```dart
// lib/utils/permissions.dart
import 'package:permission_handler/permission_handler.dart';

class Permissions {
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<bool> requestPhotoPermission() async {
    final status = await Permission.photos.request();
    return status.isGranted;
  }

  static Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }
}
```

### Formatters

```dart
// lib/utils/formatters.dart
import 'package:intl/intl.dart';

class Formatters {
  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy hh:mm a').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  static String formatPhoneNumber(String phone) {
    if (phone.startsWith('+63')) {
      return phone;
    }
    if (phone.startsWith('09')) {
      return '+63${phone.substring(1)}';
    }
    return phone;
  }

  static String formatReportId(String id) {
    // Format: VM-2026-XXXX → VM-2026-XXXX
    return id.toUpperCase();
  }
}
```

---

## Testing

### Unit Tests

```dart
// test/models/report_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mapsumbong/models/report.dart';

void main() {
  group('Report Model', () {
    test('should create report from JSON', () {
      final json = {
        'id': 'VM-2026-0001',
        'reporter_anonymous_id': 'ANON-12345',
        'issue_type': 'flood',
        'description': 'Test description',
        'latitude': 14.6042,
        'longitude': 120.9822,
        'urgency': 'critical',
        'status': 'received',
        'barangay': 'Nangka',
        'is_deleted': false,
        'created_at': '2026-03-21T10:00:00Z',
        'updated_at': '2026-03-21T10:00:00Z',
      };

      final report = Report.fromJson(json);

      expect(report.id, 'VM-2026-0001');
      expect(report.issueType, 'flood');
      expect(report.urgency, 'critical');
      expect(report.isCritical, true);
      expect(report.isResolved, false);
    });

    test('should get correct urgency color', () {
      final report = Report(
        id: 'test',
        reporterAnonymousId: 'test',
        issueType: 'flood',
        description: 'test',
        latitude: 0,
        longitude: 0,
        barangay: 'test',
        urgency: 'critical',
        status: 'received',
        isDeleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(report.getUrgencyColor().value, 0xFFEF4444); // Red
    });
  });
}
```

### Widget Tests

```dart
// test/widgets/chat_bubble_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapsumbong/widgets/chat_bubble.dart';
import 'package:mapsumbong/models/message.dart';

void main() {
  testWidgets('ChatBubble displays user message', (WidgetTester tester) async {
    final message = Message(
      id: '1',
      content: 'Hello world',
      isUser: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(message: message),
        ),
      ),
    );

    expect(find.text('Hello world'), findsOneWidget);
    expect(find.byType(ChatBubble), findsOneWidget);
  });

  testWidgets('ChatBubble displays bot message', (WidgetTester tester) async {
    final message = Message(
      id: '1',
      content: 'Salamat sa report',
      isUser: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(message: message),
        ),
      ),
    );

    expect(find.text('Salamat sa report'), findsOneWidget);
  });
}
```

### Integration Tests

```dart
// integration_test/app_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mapsumbong/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('end-to-end test', () {
    testWidgets('full app flow', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Should start at auth screen
      expect(find.text('MapSumbong'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);

      // TODO: Add more integration tests
    });
  });
}
```

---

## Building & Deployment

### Android APK Build

```bash
# Development build
flutter build apk --debug

# Production build
flutter build apk --release

# APK location: build/app/outputs/flutter-apk/app-release.apk
```

### iOS Build (if needed)

```bash
# iOS build (requires macOS)
flutter build ios --release
```

### App Store Deployment

1. **Google Play Store:**
   - Create developer account ($25 one-time fee)
   - Upload APK/AAB
   - Fill store listing
   - Submit for review

2. **App Store (iOS):**
   - Apple Developer Program ($99/year)
   - Build with Xcode
   - Submit via App Store Connect

### CI/CD (Optional)

```yaml
# .github/workflows/build.yml
name: Build and Release APK

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.10.0'
    
    - name: Build APK
      run: flutter build apk --release
    
    - name: Upload APK
      uses: actions/upload-artifact@v3
      with:
        name: app-release.apk
        path: build/app/outputs/flutter-apk/app-release.apk
```

---

## Troubleshooting

### Common Issues

**1. Network errors:**
- Check internet connection
- Verify backend URL in `.env`
- Test backend health endpoint

**2. Authentication fails:**
- Verify Supabase credentials
- Check phone number format (+63 required)
- Ensure OTP is entered correctly

**3. Photos not uploading:**
- Check storage permissions
- Verify Supabase storage bucket exists
- Check image file size (< 5MB)

**4. Real-time updates not working:**
- Verify Supabase RLS policies
- Check internet connection
- Restart app

**5. Build fails:**
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --release
```

### Debug Commands

```bash
# Check Flutter setup
flutter doctor

# Check connected devices
flutter devices

# Run with verbose logging
flutter run --verbose

# Clear Flutter cache
flutter clean && flutter pub get
```

---

## Performance Optimization

### Image Optimization

```dart
// Compress images before upload
Future<Uint8List> compressImage(File file) async {
  final result = await FlutterImageCompress.compressWithFile(
    file.absolute.path,
    quality: 70,  // Reduce quality
    minWidth: 800,
    minHeight: 600,
    rotate: 0,
  );
  return result ?? await file.readAsBytes();
}
```

### List Virtualization

```dart
// Use ListView.builder for large lists
ListView.builder(
  itemCount: reports.length,
  itemBuilder: (context, index) {
    return ReportCard(report: reports[index]);
  },
);
```

### State Management Optimization

```dart
// Use selective rebuilds
class ReportsProvider with ChangeNotifier {
  // Only notify when specific data changes
  void updateReport(Report updatedReport) {
    final index = _reports.indexWhere((r) => r.id == updatedReport.id);
    if (index != -1) {
      _reports[index] = updatedReport;
      notifyListeners();
    }
  }
}
```

---

## Next Steps

1. ✅ Flutter app structure complete
2. → Test all features thoroughly
3. → Build and deploy APK
4. → Set up push notifications
5. → Add offline support
6. → Implement location services

---

**Note:** This comprehensive Flutter guide provides a production-ready mobile app that matches the functionality and quality of the web dashboard. The app includes authentication, real-time chat, photo uploads, report management, and follows Flutter best practices.
  );
  
  runApp(const MapSumbongApp());
}

class MapSumbongApp extends StatelessWidget {
  const MapSumbongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MapSumbong',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ChatScreen(),
    );
  }
}
```

### services/api_service.dart

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static final String _baseUrl = dotenv.env['BACKEND_URL']!;
  
  static Future<Map<String, dynamic>> processMessage({
    required String message,
    required String reporterId,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/process-message'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'message': message, 'reporter_id': reporterId}),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to process message');
  }
}
```

### screens/chat_screen.dart

```dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final List<Message> _messages = [];
  bool _loading = false;

  Future<void> _send() async {
    if (_controller.text.trim().isEmpty) return;

    final userMsg = _controller.text;
    _controller.clear();

    setState(() {
      _messages.add(Message(userMsg, true));
      _loading = true;
    });

    try {
      final res = await ApiService.processMessage(
        message: userMsg,
        reporterId: 'ANON-12345',
      );

      setState(() {
        _messages.add(Message(
          res['chatbot_response'],
          false,
          reportId: res['report_id'],
        ));
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(Message('Error: $e', false));
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MapSumbong')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (ctx, i) => ChatBubble(_messages[_messages.length - 1 - i]),
            ),
          ),
          if (_loading) const CircularProgressIndicator(),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Describe the problem...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _send,
          ),
        ],
      ),
    );
  }
}

class Message {
  final String text;
  final bool isUser;
  final String? reportId;
  Message(this.text, this.isUser, {this.reportId});
}

class ChatBubble extends StatelessWidget {
  final Message msg;
  const ChatBubble(this.msg, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: msg.isUser ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          msg.text,
          style: TextStyle(color: msg.isUser ? Colors.white : Colors.black),
        ),
      ),
    );
  }
}
```

## Run

```bash
flutter run
```

**Next:** Read 05_DASHBOARD_GUIDE.md