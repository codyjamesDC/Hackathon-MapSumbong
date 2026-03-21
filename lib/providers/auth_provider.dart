import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../models/user.dart' as app_user;
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  app_user.User? _user;
  bool _isLoading = false;
  String? _error;

  app_user.User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _initializeAuth();
  }

  void _initializeAuth() {
    // Check existing session on startup
    final currentUser = AuthService.getCurrentUser();
    if (currentUser != null) {
      _user = currentUser;
    }

    // Listen to Supabase auth state changes
    AuthService.onAuthStateChange().listen(_handleAuthStateChange);
  }

  void _handleAuthStateChange(supabase.AuthState event) {
    switch (event.event) {
      case supabase.AuthChangeEvent.signedIn:
        if (event.session?.user != null) {
          _user = app_user.User.fromSupabaseUser(event.session!.user!);
          _error = null;
        }
        break;
      case supabase.AuthChangeEvent.signedOut:
        _user = null;
        _error = null;
        break;
      case supabase.AuthChangeEvent.tokenRefreshed:
        if (event.session?.user != null) {
          _user = app_user.User.fromSupabaseUser(event.session!.user!);
        }
        break;
      default:
        break;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> signInWithPhone(String phoneNumber) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await AuthService.signInWithPhone(phoneNumber);
    } catch (e) {
      _error = _friendlyError(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> verifyOTP(String phoneNumber, String otp) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await AuthService.verifyOTP(phoneNumber, otp);
      if (response.user != null) {
        _user = app_user.User.fromSupabaseUser(response.user!);
      }
    } catch (e) {
      _error = _friendlyError(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Dev-only: skip Supabase auth entirely and create a local guest user.
  /// This lets you test the app without a working SMS provider.
  /// Call [signOut] to clear it.
  Future<void> signInAsGuest() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Small artificial delay so the button feels responsive
    await Future.delayed(const Duration(milliseconds: 400));

    _user = app_user.User(
      id: 'dev-guest-001',
      anonymousId: 'ANON-DEV01',
      accountType: 'resident',
      displayName: 'Dev User',
      isAnonymous: true,
      barangay: 'Los Baños',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Only call Supabase signOut if we have a real session
      if (AuthService.isAuthenticated()) {
        await AuthService.signOut();
      }
      _user = null;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    String? displayName,
    String? barangay,
    String? purok,
  }) async {
    if (_user == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      // Skip Supabase update for guest/dev users
      if (_user!.id == 'dev-guest-001') {
        _user = app_user.User(
          id: _user!.id,
          anonymousId: _user!.anonymousId,
          accountType: _user!.accountType,
          displayName: displayName ?? _user!.displayName,
          isAnonymous: _user!.isAnonymous,
          barangay: barangay ?? _user!.barangay,
          purok: purok ?? _user!.purok,
          createdAt: _user!.createdAt,
          updatedAt: DateTime.now(),
        );
      } else {
        await AuthService.updateUserProfile(
          displayName: displayName,
          barangay: barangay,
          purok: purok,
        );
        final updated = await AuthService.getUserProfile(_user!.id);
        if (updated != null) _user = updated;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Convert raw Supabase/network errors into user-friendly messages.
  String _friendlyError(String raw) {
    if (raw.contains('Token has expired') ||
        raw.contains('token is expired')) {
      return 'OTP expired. Please request a new code.';
    }
    if (raw.contains('Invalid OTP') || raw.contains('invalid_otp')) {
      return 'Incorrect code. Please check the SMS and try again.';
    }
    if (raw.contains('rate limit') || raw.contains('429')) {
      return 'Too many attempts. Please wait a minute and try again.';
    }
    if (raw.contains('Network') || raw.contains('SocketException')) {
      return 'No internet connection. Please check your network.';
    }
    return raw;
  }
}