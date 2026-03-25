import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/message.dart';

class OfflineStoreService {
  static const String _queuedMessagesKey = 'offline.queued_messages';

  static String _reportMessagesKey(String reportId) =>
      'offline.messages.$reportId';

  static Future<List<Message>> loadQueuedMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queuedMessagesKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Message.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> saveQueuedMessages(List<Message> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(messages.map((m) => m.toJson()).toList());
    await prefs.setString(_queuedMessagesKey, encoded);
  }

  static Future<void> saveReportMessages(
    String reportId,
    List<Message> messages,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(messages.map((m) => m.toJson()).toList());
    await prefs.setString(_reportMessagesKey(reportId), encoded);
  }

  static Future<List<Message>> loadReportMessages(String reportId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_reportMessagesKey(reportId));
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Message.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
