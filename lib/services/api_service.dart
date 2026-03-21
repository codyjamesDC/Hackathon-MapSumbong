import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/report.dart';
import '../models/message.dart';

class ApiService {
  static String get baseUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:8000';

  // Gemini 2.5 Flash can take 30-60s on free tier — use 90s to be safe
  static const Duration _timeout = Duration(seconds: 90);

  // ── Process message with Gemini AI ────────────────────────────────────────
  static Future<Map<String, dynamic>> processMessage({
    required String message,
    required String reporterId,
    String? photoUrl,
    String? sessionId,
  }) async {
    debugPrint('ApiService: POST $baseUrl/process-message');

    try {
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
          .timeout(
            _timeout,
            onTimeout: () => throw Exception(
              'The AI is taking too long to respond. '
              'Please check your internet connection and try again.',
            ),
          );

      debugPrint('ApiService: response ${response.statusCode}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception(
          'Server error ${response.statusCode}: ${response.body}');
    } catch (e) {
      debugPrint('ApiService.processMessage error: $e');
      rethrow;
    }
  }

  // ── Submit confirmed report ───────────────────────────────────────────────
  static Future<Map<String, dynamic>> submitReport({
    required Map<String, dynamic> reportData,
    required String reporterAnonymousId,
  }) async {
    debugPrint('ApiService: POST $baseUrl/submit-report');

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

  // ── Get reports list ──────────────────────────────────────────────────────
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
    final response =
        await http.get(uri).timeout(_timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(
          data['reports'] as List? ?? []);
    }
    throw Exception(
        'getReports failed: ${response.statusCode} ${response.body}');
  }

  // ── Get single report ─────────────────────────────────────────────────────
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

  // ── Update report status ──────────────────────────────────────────────────
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

  // ── Legacy wrappers ───────────────────────────────────────────────────────

  static Future<Report> submitReportModel(Report report) async {
    final result = await submitReport(
      reportData: report.toJson(),
      reporterAnonymousId: report.reporterAnonymousId,
    );
    final fetched = await getReport(result['report_id'] as String);
    return Report.fromJson(fetched);
  }

  static Future<Message> sendMessage(Message message) async {
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