import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'providers/reports_provider.dart';
import 'providers/messages_provider.dart';
import 'services/notification_service.dart';
import 'screens/auth/phone_auth_screen.dart';
import 'screens/auth/otp_verification_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/reports/reports_list_screen.dart';
import 'screens/reports/report_detail_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/map/map_screen.dart';
import 'screens/location/location_picker_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? initError;

  try {
    await dotenv.load(fileName: '.env');
    debugPrint('✓ Environment variables loaded');

    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseKey == null) {
      throw Exception('Missing Supabase credentials in .env file');
    }

    debugPrint('✓ Initializing Supabase...');
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
    );
    debugPrint('✓ Supabase initialized successfully');

    debugPrint('✓ Initializing notifications...');
    await NotificationService.initialize();
    debugPrint('✓ Notifications initialized');

  } catch (e, stackTrace) {
    initError = e;
    debugPrint('❌ Initialization error: $e');
    debugPrint('Stack trace: $stackTrace');
  }

  if (initError != null) {
    runApp(InitializationErrorApp(errorMessage: initError.toString()));
    return;
  }

  runApp(const MapSumbongApp());
}

class InitializationErrorApp extends StatelessWidget {
  final String errorMessage;

  const InitializationErrorApp({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 56),
                  const SizedBox(height: 16),
                  const Text(
                    'App initialization failed',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please check your app configuration and try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MapSumbongApp extends StatelessWidget {
  const MapSumbongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ReportsProvider()),
        ChangeNotifierProvider(create: (_) => MessagesProvider()),
      ],
      child: MaterialApp.router(
        title: 'MapSumbong',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _buildRouter(),
      ),
    );
  }
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/auth',
    redirect: (context, state) {
      final authProvider =
          Provider.of<AuthProvider>(context, listen: false);
      final isAuthenticated = authProvider.isAuthenticated;
      final path = state.uri.path;

      final isAuthRoute =
          path.startsWith('/auth') || path.startsWith('/otp');

      if (!isAuthenticated && !isAuthRoute) return '/auth';
      if (isAuthenticated && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/auth',
        builder: (context, state) => const PhoneAuthScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          return OtpVerificationScreen(phoneNumber: phone);
        },
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsListScreen(),
      ),
      GoRoute(
        path: '/reports/:id',
        builder: (context, state) {
          final reportId = state.pathParameters['id']!;
          return ReportDetailScreen(reportId: reportId);
        },
      ),
      GoRoute(
        path: '/chat/:reportId',
        builder: (context, state) {
          final reportId = state.pathParameters['reportId']!;
          return ChatScreen(reportId: reportId);
        },
      ),
      GoRoute(
        path: '/map',
        builder: (context, state) => const MapScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      // Location picker — navigated to imperatively via Navigator.push
      // so it can return a LatLng value back to the caller
      GoRoute(
        path: '/pick-location',
        builder: (context, state) => const LocationPickerScreen(),
      ),
    ],
  );
}