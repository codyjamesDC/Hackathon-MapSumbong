import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../models/user.dart' as app_user;

class AuthService {
  static final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;

  // Sign up with phone number
  static Future<supabase.AuthResponse> signUpWithPhone(String phoneNumber) async {
    try {
      final response = await _supabase.auth.signUp(
        phone: phoneNumber,
        password: '', // Phone auth doesn't require password
      );
      return response;
    } catch (e) {
      throw Exception('Failed to sign up: $e');
    }
  }

  // Verify OTP
  static Future<supabase.AuthResponse> verifyOTP(String phoneNumber, String otp) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        phone: phoneNumber,
        token: otp,
        type: supabase.OtpType.sms,
      );
      return response;
    } catch (e) {
      throw Exception('Failed to verify OTP: $e');
    }
  }

  // Sign in with phone number (resend OTP)
  static Future<void> signInWithPhone(String phoneNumber) async {
    try {
      await _supabase.auth.signInWithOtp(
        phone: phoneNumber,
      );
    } catch (e) {
      throw Exception('Failed to send OTP: $e');
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  // Get current user
  static app_user.User? getCurrentUser() {
    final session = _supabase.auth.currentSession;
    if (session?.user != null) {
      return app_user.User.fromSupabaseUser(session!.user!);
    }
    return null;
  }

  // Check if user is authenticated
  static bool isAuthenticated() {
    return _supabase.auth.currentSession != null;
  }

  // Listen to auth state changes
  static Stream<supabase.AuthState> onAuthStateChange() {
    return _supabase.auth.onAuthStateChange;
  }

  // Update user profile
  static Future<void> updateUserProfile({
    String? displayName,
    String? barangay,
    String? purok,
  }) async {
    try {
      final user = getCurrentUser();
      if (user == null) throw Exception('No authenticated user');

      final updates = <String, dynamic>{};
      if (displayName != null) updates['display_name'] = displayName;
      if (barangay != null) updates['barangay'] = barangay;
      if (purok != null) updates['purok'] = purok;

      await _supabase
          .from('users')
          .update(updates)
          .eq('id', user.id);
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // Get user profile
  static Future<app_user.User?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      return app_user.User.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }
}