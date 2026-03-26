import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/report.dart';
import '../models/message.dart';

class ApiService {
  static String get baseUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:8000';

  // Gemini 2.5 Flash can take 30-60s on free tier — use 90s to be safe
  static const Duration _timeout = Duration(seconds: 90);

  /// Bearer token for FastAPI routes. Uses Supabase session JWT when signed in;
  /// optional `BACKEND_JWT` in `.env` for local dev / guest flows without Supabase session.
  /// Backend `JWT_SECRET` must match Supabase **JWT Secret** (Project Settings → API).
  static String? get _accessToken {
    final session = Supabase.instance.client.auth.currentSession;
    final fromSession = session?.accessToken;
    if (fromSession != null && fromSession.isNotEmpty) {
      return fromSession;
    }
    final dev = dotenv.env['BACKEND_JWT'];
    if (dev != null && dev.trim().isNotEmpty) {
      return dev.trim();
    }
    return null;
  }

  static Map<String, String> _headersJson() {
    final h = <String, String>{'Content-Type': 'application/json'};
    final t = _accessToken;
    if (t != null) {
      h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  static Map<String, String> _headersForGet() {
    final t = _accessToken;
    if (t == null) return {};
    return {'Authorization': 'Bearer $t'};
  }

  // ── Process message with Gemini AI ────────────────────────────────────────
  static Future<Map<String, dynamic>> processMessage({
    required String message,
    required String reporterId,
    String? photoUrl,
    String? sessionId,
    double? latitude,
    double? longitude,
  }) async {
    final url = '$baseUrl/process-message';
    debugPrint('ApiService: POST $url');

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: _headersJson(),
            body: jsonEncode({
              'message': message,
              'reporter_id': reporterId,
              'photo_url': ?photoUrl,
              'session_id': ?sessionId,
              'latitude': ?latitude,
              'longitude': ?longitude,
            }),
          )
          .timeout(
            _timeout,
            onTimeout: () => throw Exception(
              'Matagal na sumasakot ang AI. '
              'Pakisuriin ang iyong koneksyon at subukan ulit.',
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
    final url = '$baseUrl/submit-report';
    debugPrint('ApiService: POST $url');

    final response = await http
        .post(
          Uri.parse(url),
          headers: _headersJson(),
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
      'status': ?status,
      'barangay': ?barangay,
      'urgency': ?urgency,
      'issue_type': ?issueType,
    };

    final uri = Uri.parse('$baseUrl/reports')
        .replace(queryParameters: queryParams);
    final response =
        await http.get(uri, headers: _headersForGet()).timeout(_timeout);

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
    final url = '$baseUrl/reports/$reportId';
    final response = await http
        .get(Uri.parse(url), headers: _headersForGet())
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
    final url = '$baseUrl/reports/$reportId/status';
    final response = await http
        .patch(
          Uri.parse(url),
          headers: _headersJson(),
          body: jsonEncode({
            'status': status,
            'resolution_note': ?resolutionNote,
            'resolution_photo_url': ?resolutionPhotoUrl,
            'updated_by': ?updatedBy,
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
    final url = '$baseUrl/send-message';
    final response = await http
        .post(
          Uri.parse(url),
          headers: _headersJson(),
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