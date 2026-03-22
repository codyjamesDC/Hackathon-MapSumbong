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
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

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
      // Location picker — navigated to imperatively via Navigator.push
      // so it can return a LatLng value back to the caller
      GoRoute(
        path: '/pick-location',
        builder: (context, state) => const LocationPickerScreen(),
      ),
    ],
  );
}