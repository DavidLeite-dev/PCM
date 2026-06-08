import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../config/api_config.dart';
import 'api_client.dart';

class TransactionService {
  static final TransactionService _instance = TransactionService._internal();

  factory TransactionService() {
    return _instance;
  }

  TransactionService._internal();

  final ApiClient _apiClient = ApiClient();

  /// Initialize transaction service - no-op as we're using stateless HTTP API
  Future<void> init() async {
    debugPrint('TransactionService.init(): Service initialized');
  }

  /// Create a new borrow transaction (Requisição)
  /// Returns the new transaction ID on success, null on failure.
  Future<int?> createBorrowTransaction({
    required String senderEmail,
    required String receiverEmail,
    required String bookISBN,
    String notes = '',
  }) async {
    return await _createTransaction(
      type: 'Requisição',
      senderEmail: senderEmail,
      receiverEmail: receiverEmail,
      bookISBN: bookISBN,
      notes: notes,
    );
  }

  /// Create a new purchase transaction (Compra)
  /// Returns the new transaction ID on success, null on failure.
  Future<int?> createPurchaseTransaction({
    required String senderEmail,
    required String receiverEmail,
    required String bookISBN,
    required double price,
    String notes = '',
  }) async {
    return await _createTransaction(
      type: 'Compra',
      senderEmail: senderEmail,
      receiverEmail: receiverEmail,
      bookISBN: bookISBN,
      price: price,
      notes: notes,
    );
  }

  /// Create a new trade transaction (Troca)
  /// Returns the new transaction ID on success, null on failure.
  Future<int?> createTradeTransaction({
    required String senderEmail,
    required String receiverEmail,
    required String bookISBN,
    required String senderBookISBN,
    String notes = '',
  }) async {
    return await _createTransaction(
      type: 'Troca',
      senderEmail: senderEmail,
      receiverEmail: receiverEmail,
      bookISBN: bookISBN,
      senderBookISBN: senderBookISBN,
      notes: notes,
    );
  }

  /// Return a borrowed book (borrower initiates return)
  Future<bool> returnBook({required int transactionId}) async {
    try {
      debugPrint(
        'TransactionService.returnBook(): Returning transaction $transactionId',
      );
      await _apiClient.post(
        '${ApiConfig.transactionsEndpoint}/$transactionId/return',
        body: {},
      );
      return true;
    } on ApiException catch (e) {
      debugPrint('TransactionService.returnBook(): Error: $e');
      return false;
    }
  }

  /// Internal method to create a transaction via HTTP API.
  /// Returns the transaction ID on success, null on failure.
  Future<int?> _createTransaction({
    required String type,
    required String senderEmail,
    required String receiverEmail,
    required String bookISBN,
    String? senderBookISBN,
    double? price,
    String notes = '',
  }) async {
    try {
      debugPrint(
        'TransactionService._createTransaction(): Creating $type transaction for book: $bookISBN',
      );

      final body = {
        'type': type,
        'senderEmail': senderEmail,
        'receiverEmail': receiverEmail,
        'bookISBN': bookISBN,
        if (senderBookISBN != null) 'senderBookISBN': senderBookISBN,
        if (price != null) 'price': price,
        if (notes.isNotEmpty) 'notes': notes,
      };

      final response = await _apiClient.post(
        ApiConfig.transactionsEndpoint,
        body: body,
      );

      final transactionId = response['transactionId'] as int?;
      debugPrint(
        'TransactionService._createTransaction(): Created ID=$transactionId',
      );
      return transactionId;
    } on ApiException catch (e) {
      debugPrint('TransactionService._createTransaction(): Error: $e');
      return null;
    }
  }

  /// Get transactions for a user (both sent and received) via HTTP API
  Future<List<Transaction>> getUserTransactions(String email) async {
    try {
      debugPrint(
        'TransactionService.getUserTransactions(): Getting transactions for: $email',
      );

      final response = await _apiClient.get(
        '${ApiConfig.transactionsEndpoint}/user/$email',
      );
      final transactions = _parseTransactions(response);

      debugPrint(
        'TransactionService.getUserTransactions(): Retrieved ${transactions.length} transactions',
      );
      return transactions;
    } on ApiException catch (e) {
      debugPrint('TransactionService.getUserTransactions(): Error: $e');
      return [];
    }
  }

  /// Get transactions sent by a user via HTTP API
  Future<List<Transaction>> getSentTransactions(String email) async {
    try {
      debugPrint(
        'TransactionService.getSentTransactions(): Getting sent transactions from: $email',
      );

      final response = await _apiClient.get(
        '${ApiConfig.transactionsEndpoint}/sent/$email',
      );
      final transactions = _parseTransactions(response);

      debugPrint(
        'TransactionService.getSentTransactions(): Retrieved ${transactions.length} transactions',
      );
      return transactions;
    } on ApiException catch (e) {
      debugPrint('TransactionService.getSentTransactions(): Error: $e');
      return [];
    }
  }

  /// Get transactions received by a user via HTTP API
  Future<List<Transaction>> getReceivedTransactions(String email) async {
    try {
      debugPrint(
        'TransactionService.getReceivedTransactions(): Getting received transactions for: $email',
      );

      final response = await _apiClient.get(
        '${ApiConfig.transactionsEndpoint}/received/$email',
      );
      final transactions = _parseTransactions(response);

      debugPrint(
        'TransactionService.getReceivedTransactions(): Retrieved ${transactions.length} transactions',
      );
      return transactions;
    } on ApiException catch (e) {
      debugPrint('TransactionService.getReceivedTransactions(): Error: $e');
      return [];
    }
  }

  /// Get pending transactions received by a user (for approval)
  Future<List<Transaction>> getPendingTransactions(String email) async {
    try {
      debugPrint(
        'TransactionService.getPendingTransactions(): Getting pending transactions for: $email',
      );

      final response = await _apiClient.get(
        '${ApiConfig.transactionsEndpoint}/pending/$email',
      );
      final transactions = _parseTransactions(response);

      debugPrint(
        'TransactionService.getPendingTransactions(): Retrieved ${transactions.length} pending transactions',
      );
      return transactions;
    } on ApiException catch (e) {
      debugPrint('TransactionService.getPendingTransactions(): Error: $e');
      return [];
    }
  }

  /// Accept a transaction
  Future<bool> acceptTransaction(int transactionId) async {
    try {
      debugPrint(
        'TransactionService.acceptTransaction(): Accepting transaction: $transactionId',
      );

      await _apiClient.post(
        '${ApiConfig.transactionsEndpoint}/$transactionId/accept',
        body: {},
      );

      debugPrint(
        'TransactionService.acceptTransaction(): Transaction accepted successfully',
      );
      return true;
    } on ApiException catch (e) {
      debugPrint('TransactionService.acceptTransaction(): Error: $e');
      return false;
    }
  }

  /// Reject a transaction
  Future<bool> rejectTransaction(int transactionId) async {
    try {
      debugPrint(
        'TransactionService.rejectTransaction(): Rejecting transaction: $transactionId',
      );

      await _apiClient.post(
        '${ApiConfig.transactionsEndpoint}/$transactionId/reject',
        body: {},
      );

      debugPrint(
        'TransactionService.rejectTransaction(): Transaction rejected successfully',
      );
      return true;
    } on ApiException catch (e) {
      debugPrint('TransactionService.rejectTransaction(): Error: $e');
      return false;
    }
  }

  /// Cancel a transaction (sender cancels their own pending transaction)
  Future<bool> cancelTransaction(int transactionId) async {
    try {
      debugPrint(
        'TransactionService.cancelTransaction(): Cancelling transaction: $transactionId',
      );

      await _apiClient.post(
        '${ApiConfig.transactionsEndpoint}/$transactionId/cancel',
        body: {},
      );

      debugPrint(
        'TransactionService.cancelTransaction(): Transaction cancelled successfully',
      );
      return true;
    } on ApiException catch (e) {
      debugPrint('TransactionService.cancelTransaction(): Error: $e');
      return false;
    }
  }

  /// Parse transactions from API response
  List<Transaction> _parseTransactions(dynamic response) {
    List<dynamic> transactionList = [];

    // Handle two possible response formats:
    // 1. Direct list: [{ ... }, { ... }]
    // 2. Wrapped object: { "value": [{ ... }, { ... }], "count": 2 }
    if (response is List) {
      transactionList = response;
    } else if (response is Map<String, dynamic> &&
        response.containsKey('value')) {
      final value = response['value'];
      if (value is List) {
        transactionList = value;
      } else {
        debugPrint(
          'TransactionService._parseTransactions(): "value" is not a list',
        );
        return [];
      }
    } else {
      debugPrint(
        'TransactionService._parseTransactions(): Invalid response format: $response',
      );
      return [];
    }

    return transactionList
        .map((json) {
          try {
            return Transaction.fromJson(json as Map<String, dynamic>);
          } catch (e) {
            debugPrint(
              'TransactionService._parseTransactions(): Error parsing transaction: $e',
            );
            return null;
          }
        })
        .whereType<Transaction>()
        .toList();
  }
}
