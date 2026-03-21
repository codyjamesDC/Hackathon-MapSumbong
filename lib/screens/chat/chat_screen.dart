import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/messages_provider.dart';
import '../../models/message.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/message_input.dart';

class ChatScreen extends StatefulWidget {
  /// Pass 'new' to start a new report conversation.
  final String reportId;

  const ChatScreen({super.key, required this.reportId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();
  // Saved reference — safe to call in dispose() without context
  late final MessagesProvider _messagesProvider;
  bool get _isNewReport => widget.reportId == 'new';

  @override
  void initState() {
    super.initState();
    _messagesProvider =
        Provider.of<MessagesProvider>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isNewReport) {
        _messagesProvider.loadMessages(widget.reportId);
        _messagesProvider.subscribeToMessages(widget.reportId);
      } else {
        _messagesProvider.clearMessages();
      }
    });
  }

  @override
  void dispose() {
    _messagesProvider.unsubscribeFromMessages();
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

  Future<void> _sendMessage(String content, {String? imageUrl}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final msgs = Provider.of<MessagesProvider>(context, listen: false);
    if (auth.user == null) return;

    await msgs.sendMessageWithAI(
      widget.reportId,
      content,
      imageUrl: imageUrl,
      reporterAnonymousId: auth.user!.anonymousId,
    );
    _scrollToBottom();
  }

  Future<void> _submitReport() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final msgs = Provider.of<MessagesProvider>(context, listen: false);
    if (auth.user == null) return;

    final reportId =
        await msgs.submitPendingReport(auth.user!.anonymousId);

    if (!mounted) return;

    if (reportId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report $reportId submitted!'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/reports/$reportId');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final msgs = Provider.of<MessagesProvider>(context);
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
              onPressed: () =>
                  context.go('/reports/${widget.reportId}'),
            ),
          if (msgs.isTyping)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isNewReport) const _NewReportBanner(),

          // Green bar + submit button when AI has captured all details
          if (msgs.hasCompletedReport)
            _SubmitReportBar(
              isLoading: msgs.isLoading,
              onSubmit: _submitReport,
            ),

          Expanded(
            child: msgs.isLoading && msgs.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : msgs.messages.isEmpty
                    ? _EmptyChat(isNewReport: _isNewReport)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: msgs.messages.length,
                        itemBuilder: (context, index) {
                          final msg = msgs.messages[index];
                          final isMe =
                              msg.senderType == 'resident';
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: 8),
                            child: MessageBubble(
                                message: msg, isMe: isMe),
                          );
                        },
                      ),
          ),

          if (msgs.error != null)
            _ErrorBanner(
              message: msgs.error!,
              onDismiss: msgs.clearError,
            ),

          // Hide input once report is ready — user just taps Submit
          if (!msgs.hasCompletedReport)
            MessageInput(
              reportId: widget.reportId,
              onSendMessage: (content, {imageUrl}) =>
                  _sendMessage(content, imageUrl: imageUrl),
              onSendWithAI: (content, {imageUrl}) =>
                  _sendMessage(content, imageUrl: imageUrl),
            ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SubmitReportBar extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onSubmit;
  const _SubmitReportBar(
      {required this.isLoading, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.green.shade50,
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              color: Colors.green, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Report details captured! Ready to submit.',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.green,
                  fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: isLoading ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Submit',
                    style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _NewReportBanner extends StatelessWidget {
  const _NewReportBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.blue.shade50,
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Describe the issue in Filipino, Taglish, or English. '
              'Our AI will guide you through the details.',
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
              isNewReport
                  ? Icons.chat_bubble_outline
                  : Icons.mark_chat_read,
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
                  ? 'Describe what\'s happening and our AI will '
                      'extract the report details for you.'
                  : 'Start a conversation with the local authorities.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.grey[600], fontSize: 14),
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
  const _ErrorBanner(
      {required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 12, color: Colors.red)),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close,
                size: 16, color: Colors.red),
          ),
        ],
      ),
    );
  }
}