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
    // Listen to auth state changes
    AuthService.onAuthStateChange().listen((event) {
      _handleAuthStateChange(event);
    });

    // Check current session
    final currentUser = AuthService.getCurrentUser();
    if (currentUser != null) {
      _user = currentUser;
      notifyListeners();
    }
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

  Future<void> signUpWithPhone(String phoneNumber) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await AuthService.signUpWithPhone(phoneNumber);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithPhone(String phoneNumber) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await AuthService.signInWithPhone(phoneNumber);
    } catch (e) {
      _error = e.toString();
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
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await AuthService.signOut();
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
      await AuthService.updateUserProfile(
        displayName: displayName,
        barangay: barangay,
        purok: purok,
      );

      // Refresh user data
      if (_user?.id != null) {
        final updatedUser = await AuthService.getUserProfile(_user!.id);
        if (updatedUser != null) {
          _user = updatedUser;
        }
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
}