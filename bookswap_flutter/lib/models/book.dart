/// Book conditions — values must match the API's BookConditions class exactly
class BookConditions {
  static const String novo = 'novo';
  static const String semiNovo = 'semi-novo';
  static const String usado = 'usado';

  static List<String> all = [novo, semiNovo, usado];

  static String getLabel(String condition) {
    switch (condition) {
      case novo:
        return 'Novo';
      case semiNovo:
        return 'Semi-Novo';
      case usado:
        return 'Usado';
      default:
        return condition;
    }
  }
}

/// Book from OpenLibrary catalog
class Book {
  final String isbn;
  final String title;
  final String authors; // Comma-separated
  final String genre; // Single primary genre
  final String tags; // Comma-separated list of all subjects/tags
  final String description; // Book description from OpenLibrary
  final String publisher;
  final int? publicationYear;
  final String coverImageUrl;

  Book({
    required this.isbn,
    required this.title,
    required this.authors,
    required this.genre,
    required this.tags,
    required this.description,
    required this.publisher,
    this.publicationYear,
    required this.coverImageUrl,
  });

  /// Create Book from JSON response
  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      isbn: json['isbn'] ?? '',
      title: json['title'] ?? '',
      authors: json['authors'] ?? '',
      genre: json['genre'] ?? '',
      tags: json['tags'] ?? '',
      description: json['description'] ?? '',
      publisher: json['publisher'] ?? '',
      publicationYear: json['publicationYear'],
      coverImageUrl: json['coverImageUrl'] ?? '',
    );
  }

  /// Convert Book to JSON
  Map<String, dynamic> toJson() {
    return {
      'isbn': isbn,
      'title': title,
      'authors': authors,
      'genre': genre,
      'tags': tags,
      'description': description,
      'publisher': publisher,
      'publicationYear': publicationYear,
      'coverImageUrl': coverImageUrl,
    };
  }

  List<String> getAuthorsList() =>
      authors.isEmpty ? [] : authors.split(',').map((a) => a.trim()).toList();

  /// Get genre as a single-item list for consistency
  List<String> getGenreList() => genre.isEmpty ? [] : [genre];

  /// Get all tags as a list
  List<String> getTagsList() =>
      tags.isEmpty ? [] : tags.split(',').map((t) => t.trim()).toList();
}

/// User's book with condition and quantity
class UserBook {
  final String isbn;
  final Book? bookData;
  final String condition; // novo, semi-novo, usado
  final int quantity;
  final DateTime dateAdded;

  UserBook({
    required this.isbn,
    this.bookData,
    required this.condition,
    required this.quantity,
    DateTime? dateAdded,
  }) : dateAdded = dateAdded ?? DateTime.now();

  /// Create UserBook from JSON response
  factory UserBook.fromJson(Map<String, dynamic> json) {
    return UserBook(
      isbn: json['isbn'] ?? '',
      bookData: json['bookData'] != null ? Book.fromJson(json['bookData'] as Map<String, dynamic>) : null,
      condition: json['condition'] ?? BookConditions.novo,
      quantity: json['quantity'] ?? 1,
      dateAdded: json['dateAdded'] != null
          ? DateTime.parse(json['dateAdded'])
          : DateTime.now(),
    );
  }
}
