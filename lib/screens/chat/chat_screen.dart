import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/messages_provider.dart';
import '../../models/message.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/message_input.dart';
import '../../services/storage_service.dart';

class ChatScreen extends StatefulWidget {
  final String reportId;
  const ChatScreen({super.key, required this.reportId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();
  late final MessagesProvider _messagesProvider;
  bool get _isNewReport => widget.reportId == 'new';

  bool _photoUploading = false;
  String? _attachedPhotoUrl;

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
        // GPS coordinates are already set by LocationPickerScreen
        // before this screen opens — nothing to do here
      }
    });
  }

  @override
  void dispose() {
    _messagesProvider.unsubscribeFromMessages();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Photo upload ──────────────────────────────────────────────────────────

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            if (_attachedPhotoUrl != null)
              ListTile(
                leading:
                    const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove photo',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _attachedPhotoUrl = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) return;

    setState(() => _photoUploading = true);

    final url = await StorageService.pickAndUpload(
      source: source,
      uploaderId: auth.user!.anonymousId,
    );

    if (!mounted) return;
    setState(() {
      _photoUploading = false;
      _attachedPhotoUrl = url;
    });

    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo upload failed. Try again.')),
      );
    }
  }

  // ── Send / submit ─────────────────────────────────────────────────────────

  Future<void> _sendMessage(String content, {String? imageUrl}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) return;

    final effectivePhotoUrl = imageUrl ?? _attachedPhotoUrl;

    await _messagesProvider.sendMessageWithAI(
      widget.reportId,
      content,
      imageUrl: effectivePhotoUrl,
      reporterAnonymousId: auth.user!.anonymousId,
    );

    if (_attachedPhotoUrl != null) {
      setState(() => _attachedPhotoUrl = null);
    }

    _scrollToBottom();
  }

  Future<void> _submitReport() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) return;

    final reportId = await _messagesProvider
        .submitPendingReport(auth.user!.anonymousId);

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

  // ── Build ─────────────────────────────────────────────────────────────────

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
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isNewReport) const _NewReportBanner(),

          if (msgs.hasCompletedReport)
            _SubmitReportBar(
              isLoading: msgs.isLoading,
              onSubmit: _submitReport,
            ),

          if (_attachedPhotoUrl != null)
            _PhotoPreviewBar(
              onRemove: () => setState(() => _attachedPhotoUrl = null),
            ),

          if (_photoUploading) const LinearProgressIndicator(),

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

          if (!msgs.hasCompletedReport)
            MessageInput(
              reportId: widget.reportId,
              onSendMessage: (content, {imageUrl}) =>
                  _sendMessage(content, imageUrl: imageUrl),
              onSendWithAI: (content, {imageUrl}) =>
                  _sendMessage(content, imageUrl: imageUrl),
              onPhotoTap: _showPhotoOptions,
              hasPhoto: _attachedPhotoUrl != null,
              photoUploading: _photoUploading,
            ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _NewReportBanner extends StatelessWidget {
  const _NewReportBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.blue.shade50,
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Describe the issue in Filipino, Taglish, or English. '
              'You can also attach a photo.',
              style: TextStyle(fontSize: 12, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }
}

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

class _PhotoPreviewBar extends StatelessWidget {
  final VoidCallback onRemove;
  const _PhotoPreviewBar({required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          const Icon(Icons.photo, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Photo attached',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
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