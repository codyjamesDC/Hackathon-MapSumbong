import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/messages_provider.dart';
import '../../models/message.dart';
import '../../theme/app_theme.dart';
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
    _messagesProvider = Provider.of<MessagesProvider>(context, listen: false);
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

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Magdagdag ng Larawan',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _BottomSheetOption(
              icon: Icons.camera_alt_rounded,
              label: 'Kumuha ng Litrato',
              color: AppColors.primary,
              onTap: () { Navigator.pop(ctx); _pickPhoto(ImageSource.camera); },
            ),
            const SizedBox(height: 8),
            _BottomSheetOption(
              icon: Icons.photo_library_rounded,
              label: 'Pumili mula sa Galeri',
              color: AppColors.accent,
              onTap: () { Navigator.pop(ctx); _pickPhoto(ImageSource.gallery); },
            ),
            if (_attachedPhotoUrl != null) ...[
              const SizedBox(height: 8),
              _BottomSheetOption(
                icon: Icons.delete_outline_rounded,
                label: 'Alisin ang Larawan',
                color: AppColors.critical,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _attachedPhotoUrl = null);
                },
              ),
            ],
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

    if (url == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hindi na-upload ang larawan. Subukan ulit.'),
          backgroundColor: AppColors.critical,
        ),
      );
    }
  }

  Future<void> _sendMessage(String content, {String? imageUrl}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) return;

    await _messagesProvider.sendMessageWithAI(
      widget.reportId,
      content,
      imageUrl: imageUrl ?? _attachedPhotoUrl,
      reporterAnonymousId: auth.user!.anonymousId,
    );

    if (_attachedPhotoUrl != null) setState(() => _attachedPhotoUrl = null);
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
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Report $reportId na-submit!'),
            ],
          ),
          backgroundColor: AppColors.low,
        ),
      );
      context.go('/reports/$reportId');
    } else {
      final errorMsg = Provider.of<MessagesProvider>(context, listen: false).error
          ?? 'Hindi na-submit. Subukan ulit.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: AppColors.critical),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final msgs = Provider.of<MessagesProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isNewReport ? 'Bagong Report' : 'Report ${widget.reportId}',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (msgs.isTyping)
              const Text(
                'Nag-titipa ang AI...',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
        actions: [
          if (!_isNewReport)
            IconButton(
              icon: const Icon(Icons.info_outline_rounded,
                  color: AppColors.textSecondary, size: 20),
              onPressed: () => context.go('/reports/${widget.reportId}'),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── New report hint banner ─────────────────────────────────────
          if (_isNewReport) const _HintBanner(),

          // ── Submit report bar ──────────────────────────────────────────
          if (msgs.hasCompletedReport)
            _SubmitBar(
              isLoading: msgs.isLoading,
              onSubmit: _submitReport,
            ),

          // ── Photo preview ──────────────────────────────────────────────
          if (_attachedPhotoUrl != null)
            _PhotoPreview(onRemove: () => setState(() => _attachedPhotoUrl = null)),

          // ── Upload progress ────────────────────────────────────────────
          if (_photoUploading)
            LinearProgressIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.primarySurface,
              minHeight: 2,
            ),

          // ── Message list ───────────────────────────────────────────────
          Expanded(
            child: msgs.isLoading && msgs.messages.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : msgs.messages.isEmpty
                    ? _EmptyChatView(isNewReport: _isNewReport)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: msgs.messages.length,
                        itemBuilder: (context, index) {
                          final msg = msgs.messages[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _MessageBubble(
                              message: msg,
                              isMe: msg.senderType == 'resident',
                            ),
                          );
                        },
                      ),
          ),

          // ── Error banner ───────────────────────────────────────────────
          if (msgs.error != null)
            _ErrorBanner(
              message: msgs.error!,
              onDismiss: msgs.clearError,
            ),

          // ── Input ──────────────────────────────────────────────────────
          if (!msgs.hasCompletedReport)
            _ChatInput(
              onSend: (content) => _sendMessage(content),
              onPhotoTap: _showPhotoOptions,
              hasPhoto: _attachedPhotoUrl != null,
              photoUploading: _photoUploading,
            ),
        ],
      ),
    );
  }
}

// ── Message Bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    if (message.isSystemMessage) {
      return _SystemBubble(content: message.content);
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Sender label for AI
            if (!isMe && message.senderType == 'ai')
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFF2E63E8)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome,
                          color: Colors.white, size: 10),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'MapSumbong AI',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

            // Bubble
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.userBubble : AppColors.aiBubble,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.lg),
                  topRight: const Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(isMe ? AppRadius.lg : 4),
                  bottomRight: Radius.circular(isMe ? 4 : AppRadius.lg),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  height: 1.45,
                  color: isMe ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Timestamp
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
              child: Text(
                _formatTime(message.timestamp),
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }
}

class _SystemBubble extends StatelessWidget {
  final String content;

  const _SystemBubble({required this.content});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.systemBubble,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AppColors.medium.withOpacity(0.2)),
        ),
        child: Text(
          content,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.medium,
          ),
        ),
      ),
    );
  }
}

// ── Chat Input ────────────────────────────────────────────────────────────────

class _ChatInput extends StatefulWidget {
  final void Function(String) onSend;
  final VoidCallback onPhotoTap;
  final bool hasPhoto;
  final bool photoUploading;

  const _ChatInput({
    required this.onSend,
    required this.onPhotoTap,
    required this.hasPhoto,
    required this.photoUploading,
  });

  @override
  State<_ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<_ChatInput> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() => _hasText = _controller.text.trim().isNotEmpty);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Photo button
          GestureDetector(
            onTap: widget.photoUploading ? null : widget.onPhotoTap,
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 8, bottom: 1),
              decoration: BoxDecoration(
                color: widget.hasPhoto
                    ? AppColors.primarySurface
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                widget.hasPhoto
                    ? Icons.image_rounded
                    : Icons.attach_file_rounded,
                color: widget.hasPhoto ? AppColors.primary : AppColors.textMuted,
                size: 20,
              ),
            ),
          ),

          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _controller,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  hintText: 'Ilarawan ang problema...',
                  hintStyle: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Send button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(bottom: 1),
            decoration: BoxDecoration(
              gradient: _hasText
                  ? const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                    )
                  : null,
              color: _hasText ? null : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: _hasText ? AppShadows.button : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _hasText ? _send : null,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Icon(
                  Icons.send_rounded,
                  color: _hasText ? Colors.white : AppColors.textMuted,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _HintBanner extends StatelessWidget {
  const _HintBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.primarySurface,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 14),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Ilarawan ang problema sa Filipino, Taglish, o English. Maaari ring mag-attach ng larawan.',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onSubmit;

  const _SubmitBar({required this.isLoading, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.lowLight,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.low.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_outline_rounded,
                color: AppColors.low, size: 16),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Nakuha na ang detalye! Handa nang i-submit.',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                color: AppColors.low,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: isLoading ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.low,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
              textStyle: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text('I-submit'),
          ),
        ],
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  final VoidCallback onRemove;

  const _PhotoPreview({required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surfaceVariant,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.low,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.image_rounded,
              size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          const Text(
            'Larawan na attached',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded,
                size: 16, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _EmptyChatView extends StatelessWidget {
  final bool isNewReport;

  const _EmptyChatView({required this.isNewReport});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.primaryLight.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNewReport
                    ? Icons.chat_bubble_outline_rounded
                    : Icons.mark_chat_read_outlined,
                size: 36,
                color: AppColors.primary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isNewReport ? 'Sabihin ang problema' : 'Walang mensahe pa',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isNewReport
                  ? 'Mag-type sa kahon sa ibaba at tutulungan ka ng AI na mag-file ng report.'
                  : 'Magsimula ng usapan sa mga lokal na opisyal.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.5,
              ),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.criticalLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.critical.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.critical, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                color: AppColors.critical,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded,
                size: 15, color: AppColors.critical),
          ),
        ],
      ),
    );
  }
}

class _BottomSheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _BottomSheetOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}