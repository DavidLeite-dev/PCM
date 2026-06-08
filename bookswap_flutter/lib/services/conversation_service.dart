import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/conversation_summary.dart';
import '../models/chat_message.dart';
import 'api_client.dart';

class ConversationService {
  static final ConversationService _instance = ConversationService._internal();
  factory ConversationService() => _instance;
  ConversationService._internal();

  final ApiClient _apiClient = ApiClient();

  /// Returns all active conversations for the given user email.
  Future<List<ConversationSummary>> getConversations(String email) async {
    try {
      final response = await _apiClient.get(
        '${ApiConfig.conversationsEndpoint}/user/$email',
      );
      if (response['success'] == true && response['conversations'] != null) {
        return (response['conversations'] as List)
            .map(
              (e) => ConversationSummary.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('ConversationService.getConversations: $e');
      return [];
    }
  }

  /// Returns the total unread message count across all conversations.
  Future<int> getUnreadCount(String email) async {
    try {
      final response = await _apiClient.get(
        '${ApiConfig.conversationsEndpoint}/unread/$email',
      );
      return (response['count'] as int?) ?? 0;
    } on ApiException {
      return 0;
    }
  }

  /// Gets an existing Active conversation or creates a new one.
  /// Returns the conversationId, or null on failure.
  Future<int?> getOrCreateConversation({
    required String initiatorEmail,
    required String receiverEmail,
    required String bookISBN,
    int? transactionId,
  }) async {
    try {
      final body = <String, dynamic>{
        'initiatorEmail': initiatorEmail,
        'receiverEmail': receiverEmail,
        'bookISBN': bookISBN,
        if (transactionId != null) 'transactionId': transactionId,
      };
      final response = await _apiClient.post(
        ApiConfig.conversationsEndpoint,
        body: body,
      );
      if (response['success'] == true) {
        return response['conversationId'] as int?;
      }
      return null;
    } on ApiException catch (e) {
      debugPrint('ConversationService.getOrCreateConversation: $e');
      return null;
    }
  }

  /// Returns all messages in a conversation.
  /// Pass [afterId] to only fetch new messages (polling).
  /// Automatically marks received messages as read.
  Future<List<ChatMessage>> getMessages(
    int conversationId,
    String userEmail, {
    int? afterId,
  }) async {
    try {
      var endpoint =
          '${ApiConfig.conversationsEndpoint}/$conversationId/messages?userEmail=${Uri.encodeComponent(userEmail)}';
      if (afterId != null) endpoint += '&afterId=$afterId';

      final response = await _apiClient.get(endpoint);
      if (response['success'] == true && response['messages'] != null) {
        return (response['messages'] as List)
            .map(
              (e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('ConversationService.getMessages: $e');
      return [];
    }
  }

  /// Sends a message in a conversation.
  Future<bool> sendMessage({
    required int conversationId,
    required String senderEmail,
    required String content,
  }) async {
    try {
      final response = await _apiClient.post(
        '${ApiConfig.conversationsEndpoint}/$conversationId/messages',
        body: {'senderEmail': senderEmail, 'content': content},
      );
      return response['success'] == true;
    } on ApiException catch (e) {
      debugPrint('ConversationService.sendMessage: $e');
      return false;
    }
  }

  /// Links a transaction to a conversation (used when user proposes
  /// a transaction from within the chat screen).
  Future<bool> linkTransaction({
    required int conversationId,
    required int transactionId,
  }) async {
    try {
      final response = await _apiClient.post(
        '${ApiConfig.conversationsEndpoint}/$conversationId/link-transaction',
        body: {'transactionId': transactionId},
      );
      return response['success'] == true;
    } on ApiException catch (e) {
      debugPrint('ConversationService.linkTransaction: $e');
      return false;
    }
  }
}
