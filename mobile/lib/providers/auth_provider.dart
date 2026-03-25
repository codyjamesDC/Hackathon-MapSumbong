import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'dart:async';
import '../models/user.dart' as app_user;
import '../services/auth_service.dart';

void _logDebug(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

class AuthProvider with ChangeNotifier {
  app_user.User? _user;
  bool _isLoading = false;
  String? _error;
  int _activeAuthOp = 0;
  StreamSubscription<supabase.AuthState>? _authStateSub;

  app_user.User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _logDebug('🔐 AuthProvider initializing...');
    _initializeAuth();
  }

  void _initializeAuth() {
    _logDebug('🔐 Checking existing session...');
    final currentUser = AuthService.getCurrentUser();
    if (currentUser != null) {
      _logDebug('✓ Found existing user: ${currentUser.id}');
      _user = currentUser;
    } else {
      _logDebug('ℹ No existing session found');
    }

    _logDebug('🔐 Setting up auth state listener...');
    _authStateSub = AuthService.onAuthStateChange().listen(_handleAuthStateChange);
    _logDebug('✓ Auth provider initialized');
  }

  void _handleAuthStateChange(supabase.AuthState event) {
    switch (event.event) {
      case supabase.AuthChangeEvent.signedIn:
        final signedInUser = event.session?.user;
        if (signedInUser != null) {
          _user = app_user.User.fromSupabaseUser(signedInUser);
          _error = null;
        }
        break;
      case supabase.AuthChangeEvent.signedOut:
        _user = null;
        _error = null;
        break;
      case supabase.AuthChangeEvent.tokenRefreshed:
        final refreshedUser = event.session?.user;
        if (refreshedUser != null) {
          _user = app_user.User.fromSupabaseUser(refreshedUser);
        }
        break;
      default:
        break;
    }
    // Auth stream callbacks can arrive late under slow networks. We still
    // update user state, but we avoid unexpectedly flipping loading state for
    // an unrelated/newer auth operation.
    if (_activeAuthOp == 0) {
      _isLoading = false;
    }
    notifyListeners();
  }

  int _beginAuthOp() {
    _activeAuthOp += 1;
    return _activeAuthOp;
  }

  bool _isStaleOp(int opId) => opId != _activeAuthOp;

  Future<void> signInWithPhone(String phoneNumber) async {
    final opId = _beginAuthOp();
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await AuthService.signInWithPhone(phoneNumber);
    } catch (e) {
      if (_isStaleOp(opId)) return;
      _error = _friendlyError(e.toString());
    } finally {
      if (!_isStaleOp(opId)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> verifyOTP(String phoneNumber, String otp) async {
    final opId = _beginAuthOp();
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await AuthService.verifyOTP(phoneNumber, otp);
      if (_isStaleOp(opId)) return;
      final verifiedUser = response.user;
      if (verifiedUser != null) {
        _user = app_user.User.fromSupabaseUser(verifiedUser);
      }
    } catch (e) {
      if (_isStaleOp(opId)) return;
      _error = _friendlyError(e.toString());
    } finally {
      if (!_isStaleOp(opId)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Dev-only: skip Supabase auth entirely and create a local guest user.
  /// This lets you test the app without a working SMS provider.
  /// Call [signOut] to clear it.
  Future<void> signInAsGuest() async {
    final opId = _beginAuthOp();
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Small artificial delay so the button feels responsive
    await Future.delayed(const Duration(milliseconds: 400));
    if (_isStaleOp(opId)) return;

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
    final opId = _beginAuthOp();
    _isLoading = true;
    notifyListeners();

    try {
      // Only call Supabase signOut if we have a real session
      if (AuthService.isAuthenticated()) {
        await AuthService.signOut();
      }
      if (_isStaleOp(opId)) return;
      _user = null;
      _error = null;
    } catch (e) {
      if (_isStaleOp(opId)) return;
      _error = e.toString();
    } finally {
      if (!_isStaleOp(opId)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> updateProfile({
    String? displayName,
    String? barangay,
    String? purok,
  }) async {
    if (_user == null) return;
    final opId = _beginAuthOp();
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
        if (_isStaleOp(opId)) return;
        final updated = await AuthService.getUserProfile(_user!.id);
        if (updated != null) _user = updated;
      }
    } catch (e) {
      if (_isStaleOp(opId)) return;
      _error = e.toString();
    } finally {
      if (!_isStaleOp(opId)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _authStateSub?.cancel();
    _authStateSub = null;
    super.dispose();
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