import 'package:flutter/material.dart';

class MessageInput extends StatefulWidget {
  final String reportId;
  final void Function(String content, {String? imageUrl}) onSendMessage;
  final void Function(String content, {String? imageUrl}) onSendWithAI;

  // Phase 3: photo support wired from parent
  final VoidCallback? onPhotoTap;
  final bool hasPhoto;
  final bool photoUploading;

  const MessageInput({
    super.key,
    required this.reportId,
    required this.onSendMessage,
    required this.onSendWithAI,
    this.onPhotoTap,
    this.hasPhoto = false,
    this.photoUploading = false,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSending = false;

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final content = _textController.text.trim();
    if (content.isEmpty) return;
    if (_isSending) return;

    setState(() => _isSending = true);

    try {
      widget.onSendMessage(content);
      _textController.clear();
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Photo button
          if (widget.onPhotoTap != null)
            IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.attach_file,
                    color: widget.hasPhoto
                        ? Theme.of(context).primaryColor
                        : Colors.grey,
                  ),
                  if (widget.hasPhoto)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: widget.photoUploading
                  ? null
                  : widget.onPhotoTap,
              tooltip: 'Attach photo',
            ),

          // Text field
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Describe the issue…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),

          const SizedBox(width: 6),

          // Send button
          _isSending
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: Icon(
                    Icons.send,
                    color: Theme.of(context).primaryColor,
                  ),
                  onPressed: _sendMessage,
                ),
        ],
      ),
    );
  }
}