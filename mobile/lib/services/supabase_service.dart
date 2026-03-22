import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/report.dart';
import '../models/user.dart' as app_user;
import '../models/message.dart';

class SupabaseService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Reports operations
  static Future<List<Report>> getUserReports(String userId) async {
    final response = await _supabase
        .from('reports')
        .select()
        .eq('reporter_anonymous_id', userId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false);

    return response.map((json) => Report.fromJson(json)).toList();
  }

  static Future<Report?> getReport(String reportId) async {
    final response = await _supabase
        .from('reports')
        .select()
        .eq('id', reportId)
        .eq('is_deleted', false)
        .single();

    return response != null ? Report.fromJson(response) : null;
  }

  static Future<void> updateReportStatus({
    required String reportId,
    required String status,
    String? resolutionNote,
    String? resolutionPhotoUrl,
  }) async {
    await _supabase
        .from('reports')
        .update({
          'status': status,
          'resolution_note': resolutionNote,
          'resolution_photo_url': resolutionPhotoUrl,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', reportId);
  }

  // User operations
  static Future<app_user.User?> getCurrentUser() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final response = await _supabase
        .from('users')
        .select()
        .eq('id', user.id)
        .single();

    return response != null ? app_user.User.fromJson(response) : null;
  }

  static Future<String> getOrCreateAnonymousId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return '';

    final userData = await getCurrentUser();
    return userData?.anonymousId ?? '';
  }

  // Real-time subscriptions
  static Stream<List<Map<String, dynamic>>> subscribeToUserReports(String userId) {
    return _supabase
        .from('reports')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data.where((report) => 
            report['reporter_anonymous_id'] == userId && 
            report['is_deleted'] == false
        ).toList());
  }

  static Stream<List<Map<String, dynamic>>> subscribeToClusters(String barangay) {
    return _supabase
        .from('clusters')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data.where((cluster) => 
            cluster['barangay'] == barangay
        ).toList());
  }

  // Authentication helpers
  static Future<AuthResponse> signInWithOtp({
    required String phone,
    String? captchaToken,
  }) async {
    await _supabase.auth.signInWithOtp(
      phone: phone,
    );
    // Return a dummy response since the method doesn't return anything
    return AuthResponse();
  }

  static Future<AuthResponse> verifyOtp({
    required String phone,
    required String token,
  }) async {
    return await _supabase.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );
  }

  static Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Messages operations
  static Future<List<Message>> getMessagesForReport(String reportId) async {
    final response = await _supabase
        .from('messages')
        .select()
        .eq('report_id', reportId)
        .order('created_at', ascending: true);

    return response.map((json) => Message.fromJson(json)).toList();
  }

  // Additional reports operations
  static Future<List<Report>> getAllReports() async {
    final response = await _supabase
        .from('reports')
        .select()
        .eq('is_deleted', false)
        .order('created_at', ascending: false);

    return response.map((json) => Report.fromJson(json)).toList();
  }

  static Future<List<Report>> getReportsByStatus(String status) async {
    final response = await _supabase
        .from('reports')
        .select()
        .eq('status', status)
        .eq('is_deleted', false)
        .order('created_at', ascending: false);

    return response.map((json) => Report.fromJson(json)).toList();
  }

  static Future<Report> getReportById(String reportId) async {
    final response = await _supabase
        .from('reports')
        .select()
        .eq('id', reportId)
        .eq('is_deleted', false)
        .single();

    return Report.fromJson(response);
  }

  // Real-time subscriptions for messages and reports
  static Stream<List<Map<String, dynamic>>> subscribeToMessages(String reportId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((data) => data.where((item) => item['report_id'] == reportId).toList());
  }

  static Stream<List<Map<String, dynamic>>> subscribeToAllReports() {
    return _supabase
        .from('reports')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data.where((item) => item['is_deleted'] == false).toList());
  }

  static void unsubscribeFromReports() {
    // Supabase streams are automatically managed
  }

  static void unsubscribeFromMessages() {
    // Supabase streams are automatically managed
  }

  static User? get currentUser => _supabase.auth.currentUser;
  static bool get isAuthenticated => _supabase.auth.currentUser != null;
}