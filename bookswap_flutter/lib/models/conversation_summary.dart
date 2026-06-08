class ConversationSummary {
  final int id;
  final String bookISBN;
  final String bookTitle;
  final String? bookCover;
  final String initiatorEmail;
  final String initiatorName;
  final String receiverEmail;
  final String receiverName;
  final String lastMessageContent;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isInitiator;
  final String status;

  const ConversationSummary({
    required this.id,
    required this.bookISBN,
    required this.bookTitle,
    this.bookCover,
    required this.initiatorEmail,
    required this.initiatorName,
    required this.receiverEmail,
    required this.receiverName,
    required this.lastMessageContent,
    this.lastMessageAt,
    required this.unreadCount,
    required this.isInitiator,
    required this.status,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    return ConversationSummary(
      id: (json['id'] as num).toInt(),
      bookISBN: (json['bookISBN'] ?? json['bookIsbn'] ?? '') as String,
      bookTitle: (json['bookTitle'] ?? '') as String,
      bookCover: json['bookCover'] as String?,
      initiatorEmail: (json['initiatorEmail'] ?? '') as String,
      initiatorName: (json['initiatorName'] ?? '') as String,
      receiverEmail: (json['receiverEmail'] ?? '') as String,
      receiverName: (json['receiverName'] ?? '') as String,
      lastMessageContent: (json['lastMessageContent'] ?? '') as String,
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'] as String)
          : null,
      unreadCount: (json['unreadCount'] as num? ?? 0).toInt(),
      isInitiator: (json['isInitiator'] as bool?) ?? false,
      status: (json['status'] ?? 'Active') as String,
    );
  }

  /// The name of the other participant from the perspective of [currentEmail].
  String otherUserName(String currentEmail) =>
      currentEmail == initiatorEmail ? receiverName : initiatorName;

  /// The email of the other participant.
  String otherUserEmail(String currentEmail) =>
      currentEmail == initiatorEmail ? receiverEmail : initiatorEmail;
}
