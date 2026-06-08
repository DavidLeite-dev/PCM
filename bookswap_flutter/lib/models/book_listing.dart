class BookListing {
  final int listingId;
  final String isbn;
  final String condition;
  final bool available;
  final bool emprestado;
  final DateTime dateAdded;
  final int ownerId;
  final String ownerEmail;
  final String ownerName;

  BookListing({
    required this.listingId,
    required this.isbn,
    required this.condition,
    required this.available,
    required this.emprestado,
    required this.dateAdded,
    required this.ownerId,
    required this.ownerEmail,
    required this.ownerName,
  });

  factory BookListing.fromJson(Map<String, dynamic> json) {
    return BookListing(
      listingId: json['listingId'] ?? 0,
      isbn: json['isbn'] ?? '',
      condition: json['condition'] ?? '',
      available: json['available'] ?? false,
      emprestado: json['emprestado'] ?? false,
      dateAdded: json['dateAdded'] != null
          ? DateTime.parse(json['dateAdded'])
          : DateTime.now(),
      ownerId: json['ownerId'] ?? 0,
      ownerEmail: json['ownerEmail'] ?? '',
      ownerName: json['ownerName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'listingId': listingId,
      'isbn': isbn,
      'condition': condition,
      'available': available,
      'emprestado': emprestado,
      'dateAdded': dateAdded.toIso8601String(),
      'ownerId': ownerId,
      'ownerEmail': ownerEmail,
      'ownerName': ownerName,
    };
  }

  String get conditionDisplay {
    switch (condition.toLowerCase()) {
      case 'novo':
        return 'Novo';
      case 'semi-novo':
        return 'Semi-Novo';
      case 'usado':
        return 'Usado';
      default:
        return condition;
    }
  }
}
