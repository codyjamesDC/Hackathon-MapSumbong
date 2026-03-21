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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
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
        ChangeNotifierProvider(create: (_) => MessagesProvider()),
      ],
      child: MaterialApp.router(
        title: 'MapSumbong',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          fontFamily: 'Inter',
        ),
        routerConfig: _router,
      ),
    );
  }
}

// Router configuration
final GoRouter _router = GoRouter(
  initialLocation: '/auth',
  routes: [
    GoRoute(
      path: '/auth',
      builder: (context, state) => const PhoneAuthScreen(),
    ),
    GoRoute(
      path: '/otp',
      builder: (context, state) {
        final phoneNumber = state.uri.queryParameters['phone'] ?? '';
        return OtpVerificationScreen(phoneNumber: phoneNumber);
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
  ],
  redirect: (context, state) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isAuthenticated = authProvider.isAuthenticated;
    final isAuthRoute = state.matchedLocation.startsWith('/auth') ||
                       state.matchedLocation.startsWith('/otp');

    if (!isAuthenticated && !isAuthRoute) {
      return '/auth';
    }

    if (isAuthenticated && isAuthRoute) {
      return '/home';
    }

    return null;
  },
);