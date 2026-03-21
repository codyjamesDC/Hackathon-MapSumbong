class Message {
  final String id;
  final String reportId;
  final String senderId;
  final String senderType; // 'resident', 'authority', 'ai', 'system'
  final String content;
  final String messageType; // 'text', 'image', 'system'
  final String? imageUrl;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.reportId,
    required this.senderId,
    required this.senderType,
    required this.content,
    required this.messageType,
    this.imageUrl,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      reportId: json['report_id'],
      senderId: json['sender_id'],
      senderType: json['sender_type'],
      content: json['content'],
      messageType: json['message_type'],
      imageUrl: json['image_url'],
      timestamp: DateTime.parse(json['timestamp'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'report_id': reportId,
      'sender_id': senderId,
      'sender_type': senderType,
      'content': content,
      'message_type': messageType,
      'image_url': imageUrl,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // Helper getters
  bool get isFromUser => senderType == 'resident';
  bool get isFromAuthority => senderType == 'authority';
  bool get isFromAI => senderType == 'ai';
  bool get isSystemMessage => senderType == 'system';
}