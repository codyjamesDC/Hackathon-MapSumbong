import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/offline_store_service.dart';
import '../services/report_payload_builder.dart';
import '../services/supabase_service.dart';

typedef SendMessageApi = Future<Message> Function(Message message);
typedef GetMessagesApi = Future<List<Message>> Function(String reportId);
typedef SubscribeMessagesApi = Stream<List<Map<String, dynamic>>> Function(
  String reportId,
);

class MessagesProvider with ChangeNotifier {
  List<Message> _messages = [];
  final List<Message> _queuedMessages = [];
  bool _isLoading = false;
  String? _error;
  bool _isTyping = false;
  bool _hasConnectionIssue = false;
  StreamSubscription? _messagesSubscription;
  String? _activeReportId;
  final SendMessageApi _sendMessageApi;
  final GetMessagesApi _getMessagesApi;
  final SubscribeMessagesApi _subscribeMessagesApi;

  String? _sessionId;
  Map<String, dynamic>? _pendingReportData;

  // GPS coordinates captured when the report session starts
  double? _capturedLat;
  double? _capturedLng;

  List<Message> get messages => _messages;
  List<Message> get queuedMessages => List.unmodifiable(_queuedMessages);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isTyping => _isTyping;
  bool get hasConnectionIssue => _hasConnectionIssue;
  int get queuedMessageCount => _queuedMessages.length;
  bool get hasCompletedReport => _pendingReportData != null;

  MessagesProvider({
    SendMessageApi? sendMessageApi,
    GetMessagesApi? getMessagesApi,
    SubscribeMessagesApi? subscribeMessagesApi,
  })  : _sendMessageApi = sendMessageApi ?? ApiService.sendMessage,
        _getMessagesApi = getMessagesApi ?? SupabaseService.getMessagesForReport,
        _subscribeMessagesApi =
            subscribeMessagesApi ?? SupabaseService.subscribeToMessages {
    _initializeOfflineState();
  }

  /// Store GPS fix before starting a new report conversation.
  void setGpsCoordinates(double lat, double lng) {
    _capturedLat = lat;
    _capturedLng = lng;
  }

  void clearGpsCoordinates() {
    _capturedLat = null;
    _capturedLng = null;
  }

  // ── Load messages for an existing report ──────────────────────────────────
  Future<void> loadMessages(String reportId) async {
    _activeReportId = reportId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _messages = await _getMessagesApi(reportId);
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      await OfflineStoreService.saveReportMessages(reportId, _messages);
      _hasConnectionIssue = false;
    } catch (e) {
      _error = e.toString();
      final cached = await OfflineStoreService.loadReportMessages(reportId);
      if (cached.isNotEmpty) {
        _messages = cached;
      }
      _hasConnectionIssue = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Send a plain message (authority chat) ─────────────────────────────────
  Future<void> sendMessage(Message message) async {
    if (!_messages.any((m) => m.id == message.id)) {
      _messages.add(message);
    }
    _error = null;
    notifyListeners();

    try {
      // Opportunistically flush older queued messages first to preserve order.
      if (_queuedMessages.isNotEmpty) {
        await retryQueuedMessages();
      }

      final sent = await _sendMessageApi(message);

      _hasConnectionIssue = false;
      _queuedMessages.removeWhere((m) => m.id == message.id);
      await OfflineStoreService.saveQueuedMessages(_queuedMessages);

      final byExactId = _messages.indexWhere((m) => m.id == message.id);
      if (byExactId != -1) {
        _messages[byExactId] = sent;
      } else {
        _mergeIncomingMessage(sent);
      }
      await _persistActiveReportMessages();
      notifyListeners();
    } catch (e) {
      _hasConnectionIssue = true;
      _error = 'Hindi naisend ang mensahe. Ika-queue muna at ire-retry kapag may koneksyon.';
      if (!_queuedMessages.any((m) => m.id == message.id)) {
        _queuedMessages.add(message);
        await OfflineStoreService.saveQueuedMessages(_queuedMessages);
      }
      await _persistActiveReportMessages();
      notifyListeners();
    }
  }

  Future<void> sendAuthorityMessage({
    required String reportId,
    required String senderId,
    required String senderType,
    required String content,
    String? imageUrl,
  }) async {
    final optimistic = Message(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      reportId: reportId,
      senderId: senderId,
      senderType: senderType,
      content: content,
      messageType: imageUrl != null ? 'image' : 'text',
      imageUrl: imageUrl,
      timestamp: DateTime.now(),
    );
    await sendMessage(optimistic);
  }

  Future<void> retryQueuedMessages() async {
    if (_queuedMessages.isEmpty) return;
    final pending = List<Message>.from(_queuedMessages);
    _queuedMessages.clear();
    for (final msg in pending) {
      await sendMessage(msg);
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
    _activeReportId = reportId;
    await _persistActiveReportMessages();
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

      if (result['success'] == false) {
        final err = result['error']?.toString() ?? 'AI error';
        throw Exception(err);
      }

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
      _hasConnectionIssue = false;
      await _persistActiveReportMessages();
    } catch (e) {
      _hasConnectionIssue = true;
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
      await _persistActiveReportMessages();
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  // ── Submit pending report ─────────────────────────────────────────────────
  Future<String?> submitPendingReport(
    String reporterAnonymousId, {
    String? photoUrl,
  }) async {
    if (_pendingReportData == null) return null;
    _isLoading = true;
    notifyListeners();

    try {
      final raw = Map<String, dynamic>.from(_pendingReportData!);
      if (_capturedLat != null) raw['latitude'] ??= _capturedLat;
      if (_capturedLng != null) raw['longitude'] ??= _capturedLng;

      final payload = ReportPayloadBuilder.fromExtraction(
        extracted: raw,
        photoUrl: photoUrl,
      );

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
  void clearMessages({bool preserveGps = false}) {
    _messages.clear();
    _queuedMessages.clear();
    _sessionId = null;
    _pendingReportData = null;
    if (!preserveGps) {
      _capturedLat = null;
      _capturedLng = null;
    }
    _hasConnectionIssue = false;
    _activeReportId = null;
    OfflineStoreService.saveQueuedMessages(_queuedMessages);
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
      _subscribeMessagesApi(reportId).listen((data) {
      final incoming = data.map((json) => Message.fromJson(json)).toList();
      for (final msg in incoming) {
        _mergeIncomingMessage(msg);
      }
      _hasConnectionIssue = false;
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _persistActiveReportMessages();
      notifyListeners();
    }, onError: (Object e) {
      _hasConnectionIssue = true;
      _error = 'Realtime disconnected. Subukang i-retry ang queued messages.';
      notifyListeners();
    }, onDone: () {
      _hasConnectionIssue = true;
      notifyListeners();
    });
  }

  void unsubscribeFromMessages() {
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
  }

  void _mergeIncomingMessage(Message incoming) {
    if (_messages.any((m) => m.id == incoming.id)) {
      return;
    }

    final optimisticIndex = _messages.indexWhere(
      (m) =>
          m.id.startsWith('local-') &&
          m.reportId == incoming.reportId &&
          m.senderId == incoming.senderId &&
          m.senderType == incoming.senderType &&
          m.content == incoming.content &&
          m.imageUrl == incoming.imageUrl &&
          m.timestamp.difference(incoming.timestamp).inMinutes.abs() <= 2,
    );

    if (optimisticIndex != -1) {
      _messages[optimisticIndex] = incoming;
      _queuedMessages.removeWhere(
        (m) =>
            m.id == _messages[optimisticIndex].id ||
            (m.content == incoming.content &&
                m.senderId == incoming.senderId &&
                m.reportId == incoming.reportId),
      );
      return;
    }

    _messages.add(incoming);
  }

  Future<void> _initializeOfflineState() async {
    final queued = await OfflineStoreService.loadQueuedMessages();
    if (queued.isNotEmpty) {
      _queuedMessages
        ..clear()
        ..addAll(queued);
      _hasConnectionIssue = true;
      notifyListeners();
    }
  }

  Future<void> _persistActiveReportMessages() async {
    if (_activeReportId == null) return;
    await OfflineStoreService.saveReportMessages(_activeReportId!, _messages);
  }
}