import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/report.dart';
import '../models/message.dart';

class ApiService {
  // Read from .env — falls back to Android emulator address
  static String get baseUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:8000';

  static const Duration _timeout = Duration(seconds: 30);

  // ── Process a message with Gemini AI and (optionally) create a report ──────
  static Future<Map<String, dynamic>> processMessage({
    required String message,
    required String reporterId,
    String? photoUrl,
    String? sessionId,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/process-message'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'message': message,
            'reporter_id': reporterId,
            if (photoUrl != null) 'photo_url': photoUrl,
            if (sessionId != null) 'session_id': sessionId,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
        'processMessage failed: ${response.statusCode} ${response.body}');
  }

  // ── Submit a fully-extracted report to Supabase via backend ────────────────
  static Future<Map<String, dynamic>> submitReport({
    required Map<String, dynamic> reportData,
    required String reporterAnonymousId,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/submit-report'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            ...reportData,
            'reporter_anonymous_id': reporterAnonymousId,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
        'submitReport failed: ${response.statusCode} ${response.body}');
  }

  // ── Get reports list ────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getReports({
    String? status,
    String? barangay,
    String? urgency,
    String? issueType,
    int limit = 100,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (status != null) 'status': status,
      if (barangay != null) 'barangay': barangay,
      if (urgency != null) 'urgency': urgency,
      if (issueType != null) 'issue_type': issueType,
    };

    final uri = Uri.parse('$baseUrl/reports')
        .replace(queryParameters: queryParams);
    final response = await http.get(uri).timeout(_timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(
          data['reports'] as List? ?? []);
    }
    throw Exception(
        'getReports failed: ${response.statusCode} ${response.body}');
  }

  // ── Get single report ───────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getReport(String reportId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/reports/$reportId'))
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
        'getReport failed: ${response.statusCode} ${response.body}');
  }

  // ── Update report status ───────────────────────────────────────────────────
  static Future<Map<String, dynamic>> updateReportStatus({
    required String reportId,
    required String status,
    String? resolutionNote,
    String? resolutionPhotoUrl,
    String? updatedBy,
  }) async {
    final response = await http
        .patch(
          Uri.parse('$baseUrl/reports/$reportId/status'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'status': status,
            if (resolutionNote != null) 'resolution_note': resolutionNote,
            if (resolutionPhotoUrl != null)
              'resolution_photo_url': resolutionPhotoUrl,
            if (updatedBy != null) 'updated_by': updatedBy,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
        'updateReportStatus failed: ${response.statusCode} ${response.body}');
  }

  // ── Legacy wrappers kept so other files still compile ─────────────────────

  static Future<Report> submitReportModel(Report report) async {
    final result = await submitReport(
      reportData: report.toJson(),
      reporterAnonymousId: report.reporterAnonymousId,
    );
    // Backend returns {success, report_id, message} — re-fetch full report
    final fetched = await getReport(result['report_id'] as String);
    return Report.fromJson(fetched);
  }

  static Future<Message> sendMessage(Message message) async {
    // Direct message save — not used in the AI flow, kept for authority chat
    final response = await http
        .post(
          Uri.parse('$baseUrl/send-message'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(message.toJson()),
        )
        .timeout(_timeout);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Message.fromJson(
          data['message'] as Map<String, dynamic>? ?? data);
    }
    throw Exception(
        'sendMessage failed: ${response.statusCode} ${response.body}');
  }
}