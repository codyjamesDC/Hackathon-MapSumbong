import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/report.dart';
import '../models/message.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8000'; // Android emulator

  static Future<Map<String, dynamic>> processMessage({
    required String message,
    required String reporterId,
    String? photoUrl,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/process-message'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'message': message,
        'reporter_id': reporterId,
        'photo_url': photoUrl,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to process message: ${response.statusCode}');
    }
  }

  static Future<List<Map<String, dynamic>>> getReports({
    String? status,
    String? barangay,
    String? urgency,
    String? issueType,
    int limit = 100,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{};
    if (status != null) queryParams['status'] = status;
    if (barangay != null) queryParams['barangay'] = barangay;
    if (urgency != null) queryParams['urgency'] = urgency;
    if (issueType != null) queryParams['issue_type'] = issueType;
    queryParams['limit'] = limit.toString();
    queryParams['offset'] = offset.toString();

    final uri = Uri.parse('$baseUrl/reports').replace(queryParameters: queryParams);
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['reports']);
    } else {
      throw Exception('Failed to get reports: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> getReport(String reportId) async {
    final response = await http.get(Uri.parse('$baseUrl/reports/$reportId'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get report: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> updateReportStatus({
    required String reportId,
    required String status,
    String? resolutionNote,
    String? resolutionPhotoUrl,
    String? updatedBy,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/reports/$reportId/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'status': status,
        'resolution_note': resolutionNote,
        'resolution_photo_url': resolutionPhotoUrl,
        'updated_by': updatedBy,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update report status: ${response.statusCode}');
    }
  }

  static Future<List<Map<String, dynamic>>> getClusters({
    String? barangay,
    bool? alerted,
    int limit = 50,
  }) async {
    final queryParams = <String, String>{};
    if (barangay != null) queryParams['barangay'] = barangay;
    if (alerted != null) queryParams['alerted'] = alerted.toString();
    queryParams['limit'] = limit.toString();

    final uri = Uri.parse('$baseUrl/clusters').replace(queryParameters: queryParams);
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['clusters']);
    } else {
      throw Exception('Failed to get clusters: ${response.statusCode}');
    }
  }

  static Future<List<Map<String, dynamic>>> getAuditLog({
    String? reportId,
    String? action,
    int limit = 50,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{};
    if (reportId != null) queryParams['report_id'] = reportId;
    if (action != null) queryParams['action'] = action;
    queryParams['limit'] = limit.toString();
    queryParams['offset'] = offset.toString();

    final uri = Uri.parse('$baseUrl/audit-log').replace(queryParameters: queryParams);
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['logs']);
    } else {
      throw Exception('Failed to get audit log: ${response.statusCode}');
    }
  }

  // Submit a new report
  static Future<Report> submitReport(Report report) async {
    final response = await http.post(
      Uri.parse('$baseUrl/submit-report'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(report.toJson()),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return Report.fromJson(data['report']);
    } else {
      throw Exception('Failed to submit report: ${response.statusCode}');
    }
  }

  // Send a message
  static Future<Message> sendMessage(Message message) async {
    final response = await http.post(
      Uri.parse('$baseUrl/send-message'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(message.toJson()),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return Message.fromJson(data['message']);
    } else {
      throw Exception('Failed to send message: ${response.statusCode}');
    }
  }

  // Send message with AI processing
  static Future<Map<String, dynamic>> sendMessageWithAI(
    String reportId,
    String content, {
    String? imageUrl,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/send-message-ai'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'report_id': reportId,
        'content': content,
        'image_url': imageUrl,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to send message with AI: ${response.statusCode}');
    }
  }
}