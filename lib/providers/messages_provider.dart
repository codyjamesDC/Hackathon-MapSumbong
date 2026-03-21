import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/supabase_service.dart';

class MessagesProvider with ChangeNotifier {
  List<Message> _messages = [];
  bool _isLoading = false;
  String? _error;
  bool _isTyping = false;
  StreamSubscription? _messagesSubscription;

  // Tracks the Gemini session ID so multi-turn conversation works correctly
  String? _sessionId;

  // Once the backend marks is_complete=true, we store the extracted data
  Map<String, dynamic>? _pendingReportData;

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isTyping => _isTyping;
  Map<String, dynamic>? get pendingReportData => _pendingReportData;
  bool get hasCompletedReport => _pendingReportData != null;

  // ── Load messages for an existing report ──────────────────────────────────
  Future<void> loadMessages(String reportId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _messages = await SupabaseService.getMessagesForReport(reportId);
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Send a plain message (authority chat, not AI) ─────────────────────────
  Future<void> sendMessage(Message message) async {
    try {
      _messages.add(message);
      notifyListeners();

      final sent = await ApiService.sendMessage(message);
      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        _messages[index] = sent;
        notifyListeners();
      }
    } catch (e) {
      _messages.removeWhere((m) => m.id == message.id);
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ── Send a message through Gemini AI ─────────────────────────────────────
  // This is the main entry point for the "new report" chat flow.
  Future<void> sendMessageWithAI(
    String reportId,
    String content, {
    String? imageUrl,
    String? reporterAnonymousId,
  }) async {
    // 1. Show the user's message immediately
    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      reportId: reportId,
      senderId: reporterAnonymousId ?? 'user',
      senderType: 'resident',
      content: content,
      timestamp: DateTime.now(),
      messageType: imageUrl != null ? 'image' : 'text',
      imageUrl: imageUrl,
    );
    _messages.add(userMessage);
    _isTyping = true;
    _error = null;
    notifyListeners();

    try {
      // 2. Call the backend /process-message endpoint
      final result = await ApiService.processMessage(
        message: content,
        reporterId: reporterAnonymousId ?? 'ANON-DEV01',
        photoUrl: imageUrl,
        sessionId: _sessionId,
      );

      // 3. Persist the session ID for multi-turn conversation
      if (result['session_id'] != null) {
        _sessionId = result['session_id'] as String;
      }

      // 4. Add the AI response bubble
      final aiText = result['response'] as String? ??
          result['chatbot_response'] as String? ??
          'Salamat sa inyong mensahe!';

      final aiMessage = Message(
        id: '${DateTime.now().millisecondsSinceEpoch}_ai',
        reportId: reportId,
        senderId: 'ai_assistant',
        senderType: 'ai',
        content: aiText,
        timestamp: DateTime.now(),
        messageType: 'text',
      );
      _messages.add(aiMessage);

      // 5. If the report is complete, store extracted data and show a prompt
      final isComplete = result['is_complete'] as bool? ?? false;
      final reportData =
          result['report_data'] as Map<String, dynamic>?;

      if (isComplete && reportData != null) {
        _pendingReportData = reportData;

        // Add a system message nudging the user to confirm
        final systemMessage = Message(
          id: '${DateTime.now().millisecondsSinceEpoch}_sys',
          reportId: reportId,
          senderId: 'system',
          senderType: 'system',
          content:
              '✅ Report details extracted. Tap "Submit Report" to save.',
          timestamp: DateTime.now(),
          messageType: 'system',
        );
        _messages.add(systemMessage);
      }
    } catch (e) {
      _error = e.toString();

      // Show an error bubble in the chat
      _messages.add(Message(
        id: '${DateTime.now().millisecondsSinceEpoch}_err',
        reportId: reportId,
        senderId: 'system',
        senderType: 'system',
        content:
            'Pasensya na, may error sa koneksyon. Subukan ulit.',
        timestamp: DateTime.now(),
        messageType: 'system',
      ));
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  // ── Submit the pending extracted report to Supabase ───────────────────────
  Future<String?> submitPendingReport(String reporterAnonymousId) async {
    if (_pendingReportData == null) return null;

    _isLoading = true;
    notifyListeners();

    try {
      final result = await ApiService.submitReport(
        reportData: _pendingReportData!,
        reporterAnonymousId: reporterAnonymousId,
      );

      final reportId = result['report_id'] as String?;

      if (reportId != null) {
        _pendingReportData = null;
        _sessionId = null;

        _messages.add(Message(
          id: '${DateTime.now().millisecondsSinceEpoch}_saved',
          reportId: reportId,
          senderId: 'system',
          senderType: 'system',
          content: '📋 Report saved! ID: $reportId',
          timestamp: DateTime.now(),
          messageType: 'system',
        ));
      }

      return reportId;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void setTyping(bool typing) {
    _isTyping = typing;
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    _sessionId = null;
    _pendingReportData = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void resetSession() {
    _sessionId = null;
    _pendingReportData = null;
  }

  // ── Real-time subscription ─────────────────────────────────────────────────
  void subscribeToMessages(String reportId) {
    _messagesSubscription?.cancel();
    _messagesSubscription =
        SupabaseService.subscribeToMessages(reportId).listen((data) {
      final incoming =
          data.map((json) => Message.fromJson(json)).toList();
      for (final msg in incoming) {
        if (!_messages.any((m) => m.id == msg.id)) {
          _messages.add(msg);
        }
      }
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      notifyListeners();
    });
  }

  void unsubscribeFromMessages() {
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
  }
}