import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/messages_provider.dart';
import '../../models/message.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/message_input.dart';

class ChatScreen extends StatefulWidget {
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

  @override
  void initState() {
    super.initState();
    // Load messages and subscribe to updates
    final messagesProvider = Provider.of<MessagesProvider>(context, listen: false);
    messagesProvider.loadMessages(widget.reportId);
    messagesProvider.subscribeToMessages(widget.reportId);
  }

  @override
  void dispose() {
    Provider.of<MessagesProvider>(context, listen: false).unsubscribeFromMessages();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesProvider = Provider.of<MessagesProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with Authorities'),
        actions: [
          if (messagesProvider.isTyping)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: messagesProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : messagesProvider.messages.isEmpty
                    ? _buildEmptyState()
                    : _buildMessagesList(messagesProvider.messages),
          ),

          // Message input
          MessageInput(
            reportId: widget.reportId,
            onSendMessage: _sendMessage,
            onSendWithAI: _sendMessageWithAI,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a conversation with authorities about your report',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(List<Message> messages) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMe = message.senderId == Provider.of<AuthProvider>(context).user?.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: MessageBubble(
            message: message,
            isMe: isMe,
          ),
        );
      },
    );
  }

  void _sendMessage(String content, {String? imageUrl}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final messagesProvider = Provider.of<MessagesProvider>(context, listen: false);

    if (authProvider.user == null) return;

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  void _sendMessageWithAI(String content, {String? imageUrl}) async {
    final messagesProvider = Provider.of<MessagesProvider>(context, listen: false);

    try {
      await messagesProvider.sendMessageWithAI(widget.reportId, content, imageUrl: imageUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }
}