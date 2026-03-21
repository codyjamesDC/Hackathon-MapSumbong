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

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isTyping => _isTyping;

  // Get messages for a specific report
  List<Message> getMessagesForReport(String reportId) {
    return _messages.where((message) => message.reportId == reportId).toList();
  }

  Future<void> loadMessages(String reportId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _messages = await SupabaseService.getMessagesForReport(reportId);
      // Sort messages by timestamp
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(Message message) async {
    try {
      // Add message locally first for immediate UI update
      _messages.add(message);
      notifyListeners();

      // Send to backend
      final sentMessage = await ApiService.sendMessage(message);

      // Update with server response
      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        _messages[index] = sentMessage;
        notifyListeners();
      }
    } catch (e) {
      // Remove failed message
      _messages.removeWhere((m) => m.id == message.id);
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> sendMessageWithAI(String reportId, String content, {String? imageUrl}) async {
    _isTyping = true;
    notifyListeners();

    try {
      final response = await ApiService.sendMessageWithAI(reportId, content, imageUrl: imageUrl);

      // Add AI response to messages
      if (response.containsKey('ai_response')) {
        final aiMessage = Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          reportId: reportId,
          senderId: 'ai_assistant',
          senderType: 'ai',
          content: response['ai_response'],
          timestamp: DateTime.now(),
          messageType: 'text',
        );
        _messages.add(aiMessage);
      }

      // Add any extracted issues as system messages
      if (response.containsKey('issues') && response['issues'].isNotEmpty) {
        final issuesMessage = Message(
          id: DateTime.now().millisecondsSinceEpoch.toString() + '_issues',
          reportId: reportId,
          senderId: 'system',
          senderType: 'system',
          content: 'Issues detected: ${response['issues'].join(', ')}',
          timestamp: DateTime.now(),
          messageType: 'system',
        );
        _messages.add(issuesMessage);
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  void setTyping(bool typing) {
    _isTyping = typing;
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Real-time subscription for new messages
  void subscribeToMessages(String reportId) {
    _messagesSubscription?.cancel();
    _messagesSubscription = SupabaseService.subscribeToMessages(reportId).listen((data) {
      final newMessages = data.map((json) => Message.fromJson(json)).toList();
      for (final message in newMessages) {
        // Only add if not already in the list
        if (!_messages.any((m) => m.id == message.id)) {
          _messages.add(message);
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