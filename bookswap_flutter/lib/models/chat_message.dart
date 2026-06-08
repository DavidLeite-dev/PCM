class ChatMessage {
  final int id;
  final int conversationId;
  final String senderEmail;
  final String senderName;
  final String content;
  final DateTime sentAt;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderEmail,
    required this.senderName,
    required this.content,
    required this.sentAt,
    required this.isRead,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] as num).toInt(),
      conversationId: (json['conversationId'] as num? ?? 0).toInt(),
      senderEmail: (json['senderEmail'] ?? '') as String,
      senderName: (json['senderName'] ?? '') as String,
      content: (json['content'] ?? '') as String,
      sentAt: json['sentAt'] != null
          ? DateTime.parse(json['sentAt'] as String)
          : DateTime.now(),
      isRead: (json['isRead'] as bool?) ?? false,
    );
  }
}
