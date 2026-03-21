import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class MessageInput extends StatefulWidget {
  final String reportId;
  final Function(String content, {String? imageUrl}) onSendMessage;
  final Function(String content, {String? imageUrl}) onSendWithAI;

  const MessageInput({
    super.key,
    required this.reportId,
    required this.onSendMessage,
    required this.onSendWithAI,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  File? _selectedImage;
  bool _isSending = false;

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Column(
        children: [
          // Selected image preview
          if (_selectedImage != null) _buildImagePreview(),

          // Input row
          Row(
            children: [
              // Image picker button
              IconButton(
                icon: const Icon(Icons.photo_camera),
                onPressed: _isSending ? null : _pickImage,
                color: Theme.of(context).primaryColor,
              ),

              // Text input field
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),

              const SizedBox(width: 8),

              // Send button
              _isSending
                  ? const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendMessage,
                      color: Theme.of(context).primaryColor,
                    ),
            ],
          ),

          const SizedBox(height: 8),

          // AI processing hint
          Text(
            'Messages are processed by AI to extract disaster information',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _selectedImage!,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Image attached',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  _selectedImage!.path.split('/').last,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _selectedImage = null),
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  void _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _sendMessage() async {
    final content = _textController.text.trim();
    if (content.isEmpty && _selectedImage == null) return;

    setState(() => _isSending = true);

    try {
      // For now, we'll use the regular send method
      // In the future, we could add logic to detect if AI processing is needed
      if (_selectedImage != null) {
        // TODO: Upload image and get URL
        // For now, we'll just send the text
        widget.onSendMessage(content);
      } else {
        widget.onSendMessage(content);
      }

      // Clear input
      _textController.clear();
      setState(() => _selectedImage = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }
}