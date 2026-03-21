import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/messages_provider.dart';
import '../../providers/reports_provider.dart';
import '../../models/message.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/message_input.dart';

class ChatScreen extends StatefulWidget {
  /// Pass 'new' to start a new report conversation without a pre-existing report.
  final String reportId;

  const ChatScreen({
    super.key,
    required this.reportId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();
  bool get _isNewReport => widget.reportId == 'new';

  @override
  void initState() {
    super.initState();
    if (!_isNewReport) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final messagesProvider =
            Provider.of<MessagesProvider>(context, listen: false);
        messagesProvider.loadMessages(widget.reportId);
        messagesProvider.subscribeToMessages(widget.reportId);
      });
    }
  }

  @override
  void dispose() {
    Provider.of<MessagesProvider>(context, listen: false)
        .unsubscribeFromMessages();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesProvider = Provider.of<MessagesProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    final title =
        _isNewReport ? 'New Report' : 'Report ${widget.reportId}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (!_isNewReport)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Report details',
              onPressed: () => context.go('/reports/${widget.reportId}'),
            ),
          if (messagesProvider.isTyping)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Hint banner for new reports
          if (_isNewReport) const _NewReportBanner(),

          // Messages list
          Expanded(
            child: messagesProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : messagesProvider.messages.isEmpty
                    ? _EmptyChat(isNewReport: _isNewReport)
                    : _buildMessages(
                        messagesProvider.messages, authProvider),
          ),

          // Error banner
          if (messagesProvider.error != null)
            _ErrorBanner(
              message: messagesProvider.error!,
              onDismiss: messagesProvider.clearError,
            ),

          // Input
          MessageInput(
            reportId: widget.reportId,
            onSendMessage: (content, {imageUrl}) =>
                _sendMessage(context, content, imageUrl: imageUrl),
            onSendWithAI: (content, {imageUrl}) =>
                _sendWithAI(context, content, imageUrl: imageUrl),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages(List<Message> messages, AuthProvider auth) {
    _scrollToBottom();
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        final isMe = msg.senderId == auth.user?.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: MessageBubble(message: msg, isMe: isMe),
        );
      },
    );
  }

  Future<void> _sendMessage(
    BuildContext context,
    String content, {
    String? imageUrl,
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final messagesProvider =
        Provider.of<MessagesProvider>(context, listen: false);

    if (authProvider.user == null) return;

    // For new reports, route through AI so the backend creates the report
    if (_isNewReport) {
      await messagesProvider.sendMessageWithAI(
        'new',
        content,
        imageUrl: imageUrl,
      );
      _scrollToBottom();
      return;
    }

    final message = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      reportId: widget.reportId,
      senderId: authProvider.user!.id,
      senderType: 'resident',
      content: content,
      timestamp: DateTime.now(),
      messageType: imageUrl != null ? 'image' : 'text',
      imageUrl: imageUrl,
    );

    try {
      await messagesProvider.sendMessage(message);
      _scrollToBottom();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
  }

  Future<void> _sendWithAI(
    BuildContext context,
    String content, {
    String? imageUrl,
  }) async {
    final messagesProvider =
        Provider.of<MessagesProvider>(context, listen: false);
    try {
      await messagesProvider.sendMessageWithAI(
        widget.reportId,
        content,
        imageUrl: imageUrl,
      );
      _scrollToBottom();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
  }
}

// ── Private helpers ───────────────────────────────────────────────────────────

class _NewReportBanner extends StatelessWidget {
  const _NewReportBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.blue.shade50,
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.blue, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Describe the issue in Filipino, Taglish, or English. '
              'Our AI will extract the report details for you.',
              style: TextStyle(fontSize: 12, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  final bool isNewReport;
  const _EmptyChat({required this.isNewReport});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isNewReport ? Icons.chat_bubble_outline : Icons.mark_chat_read,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isNewReport
                  ? 'Tell us about the issue'
                  : 'No messages yet',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              isNewReport
                  ? 'Type a description and our AI will create a report for you.'
                  : 'Start a conversation with the local authorities.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style:
                    const TextStyle(fontSize: 12, color: Colors.red)),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close, size: 16, color: Colors.red),
          ),
        ],
      ),
    );
  }
}