enum TransactionType {
  compra, // Compra (Buy)
  requisicao, // Requisição (Borrow)
  troca, // Troca (Trade)
}

enum TransactionStatus {
  pendente, // Pendente
  aceita, // Aceita
  confirmada, // Confirmada
  rejeitada, // Rejeitada
  cancelada, // Cancelada
}

class Transaction {
  final int id;
  final String type; // "Compra", "Requisição", "Troca"
  final String
  status; // "Pendente", "Aceita", "Confirmada", "Rejeitada", "Cancelada"
  final String notes;
  final String bookId; // ISBN as string
  final String bookTitle;
  final String bookAuthor;
  final String bookISBN;
  final String senderEmail;
  final String senderName;
  final String receiverEmail;
  final String receiverName;
  final double? price; // For purchases
  final String? tradeBookTitle; // For trades
  final String? tradeBookAuthor; // For trades
  final String? tradeBookISBN; // For trades
  final DateTime createdAt;
  final DateTime updatedAt;

  Transaction({
    required this.id,
    required this.type,
    required this.status,
    required this.notes,
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    required this.bookISBN,
    required this.senderEmail,
    required this.senderName,
    required this.receiverEmail,
    required this.receiverName,
    this.price,
    this.tradeBookTitle,
    this.tradeBookAuthor,
    this.tradeBookISBN,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create Transaction from JSON response
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] ?? 0,
      type: json['type'] ?? '',
      status: json['status'] ?? '',
      notes: json['notes'] ?? '',
      bookId: json['bookId']?.toString() ?? '',
      bookTitle: json['bookTitle'] ?? '',
      bookAuthor: json['bookAuthor'] ?? '',
      bookISBN: json['bookISBN'] ?? '',
      senderEmail: json['senderEmail'] ?? '',
      senderName: json['senderName'] ?? '',
      receiverEmail: json['receiverEmail'] ?? '',
      receiverName: json['receiverName'] ?? '',
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      tradeBookTitle: json['tradeBookTitle'],
      tradeBookAuthor: json['tradeBookAuthor'],
      tradeBookISBN: json['tradeBookISBN'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  /// Convert Transaction to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'status': status,
      'notes': notes,
      'bookId': bookId,
      'bookTitle': bookTitle,
      'bookAuthor': bookAuthor,
      'bookISBN': bookISBN,
      'senderEmail': senderEmail,
      'senderName': senderName,
      'receiverEmail': receiverEmail,
      'receiverName': receiverName,
      'price': price,
      'tradeBookTitle': tradeBookTitle,
      'tradeBookAuthor': tradeBookAuthor,
      'tradeBookISBN': tradeBookISBN,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Get display text for transaction type
  String get typeDisplay {
    switch (type) {
      case 'Compra':
        return 'Compra';
      case 'Requisição':
        return 'Requisição';
      case 'Troca':
        return 'Troca';
      default:
        return type;
    }
  }

  /// Get display text for transaction status
  String get statusDisplay {
    switch (status) {
      case 'Pendente':
        return 'Pendente';
      case 'Aceita':
        return 'Aceita';
      case 'Confirmada':
        return 'Confirmada';
      case 'Rejeitada':
        return 'Rejeitada';
      case 'Cancelada':
        return 'Cancelada';
      default:
        return status;
    }
  }

  /// Check if transaction is pending
  bool get isPending => status == 'Pendente';

  /// Check if transaction is accepted or confirmed
  bool get isAccepted => status == 'Aceita' || status == 'Confirmada';

  /// Check if transaction is rejected or cancelled
  bool get isRejected => status == 'Rejeitada' || status == 'Cancelada';
}
