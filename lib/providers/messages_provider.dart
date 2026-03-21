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

  String? _sessionId;
  Map<String, dynamic>? _pendingReportData;

  // GPS coordinates captured when the report session starts
  double? _capturedLat;
  double? _capturedLng;

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isTyping => _isTyping;
  bool get hasCompletedReport => _pendingReportData != null;

  /// Store GPS fix before starting a new report conversation.
  void setGpsCoordinates(double lat, double lng) {
    _capturedLat = lat;
    _capturedLng = lng;
  }

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

  // ── Send a plain message (authority chat) ─────────────────────────────────
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

  // ── Send through Gemini AI ─────────────────────────────────────────────────
  Future<void> sendMessageWithAI(
    String reportId,
    String content, {
    String? imageUrl,
    String? reporterAnonymousId,
  }) async {
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
      final result = await ApiService.processMessage(
        message: content,
        reporterId: reporterAnonymousId ?? 'ANON-DEV01',
        photoUrl: imageUrl,
        sessionId: _sessionId,
        latitude: _capturedLat,
        longitude: _capturedLng,
      );

      if (result['session_id'] != null) {
        _sessionId = result['session_id'] as String;
      }

      final aiText = result['response'] as String? ??
          result['chatbot_response'] as String? ??
          'Salamat sa inyong mensahe!';

      _messages.add(Message(
        id: '${DateTime.now().millisecondsSinceEpoch}_ai',
        reportId: reportId,
        senderId: 'ai_assistant',
        senderType: 'ai',
        content: aiText,
        timestamp: DateTime.now(),
        messageType: 'text',
      ));

      final isComplete = result['is_complete'] as bool? ?? false;
      final reportData = result['report_data'] as Map<String, dynamic>?;

      if (isComplete && reportData != null) {
        // Inject GPS if available and backend didn't geocode a location
        if (_capturedLat != null && _capturedLng != null) {
          reportData['latitude'] ??= _capturedLat;
          reportData['longitude'] ??= _capturedLng;
        }
        _pendingReportData = reportData;

        _messages.add(Message(
          id: '${DateTime.now().millisecondsSinceEpoch}_sys',
          reportId: reportId,
          senderId: 'system',
          senderType: 'system',
          content: '✅ Report details captured. Tap "Submit Report" to save.',
          timestamp: DateTime.now(),
          messageType: 'system',
        ));
      }
    } catch (e) {
      _error = e.toString();
      _messages.add(Message(
        id: '${DateTime.now().millisecondsSinceEpoch}_err',
        reportId: reportId,
        senderId: 'system',
        senderType: 'system',
        content: 'Pasensya na, may error sa koneksyon. Subukan ulit.',
        timestamp: DateTime.now(),
        messageType: 'system',
      ));
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  // ── Submit pending report ─────────────────────────────────────────────────
  Future<String?> submitPendingReport(String reporterAnonymousId) async {
    if (_pendingReportData == null) return null;
    _isLoading = true;
    notifyListeners();

    try {
      final payload = Map<String, dynamic>.from(_pendingReportData!);
      if (_capturedLat != null) payload['latitude'] ??= _capturedLat;
      if (_capturedLng != null) payload['longitude'] ??= _capturedLng;

      final result = await ApiService.submitReport(
        reportData: payload,
        reporterAnonymousId: reporterAnonymousId,
      );

      // Backend returns success:false with error message on DB failures
      if (result['success'] == false) {
        _error = result['error'] as String? ?? 'Unknown error from server';
        return null;
      }

      final reportId = result['report_id'] as String?;
      if (reportId != null) {
        _pendingReportData = null;
        _sessionId = null;
        _capturedLat = null;
        _capturedLng = null;

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

  // ── Helpers ───────────────────────────────────────────────────────────────
  void clearMessages() {
    _messages.clear();
    _sessionId = null;
    _pendingReportData = null;
    _capturedLat = null;
    _capturedLng = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Real-time ─────────────────────────────────────────────────────────────
  void subscribeToMessages(String reportId) {
    _messagesSubscription?.cancel();
    _messagesSubscription =
        SupabaseService.subscribeToMessages(reportId).listen((data) {
      final incoming = data.map((json) => Message.fromJson(json)).toList();
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