import 'package:flutter/foundation.dart';
import '../models/book.dart';
import 'api_client.dart';

class BookService {
  static final BookService _instance = BookService._internal();

  factory BookService() {
    return _instance;
  }

  BookService._internal();

  final ApiClient _apiClient = ApiClient();

  /// Look up a book by ISBN
  Future<Book?> lookupISBN(String isbn) async {
    try {
      debugPrint('BookService.lookupISBN(): Looking up ISBN: $isbn');

      final response = await _apiClient.post(
        '/books/lookup',
        body: {'isbn': isbn},
      );

      if (response['success'] == true && response['book'] != null) {
        final book = Book.fromJson(response['book']);
        debugPrint('BookService.lookupISBN(): Found book: ${book.title}');
        return book;
      }

      return null;
    } on ApiException catch (e) {
      debugPrint('BookService.lookupISBN(): Error: $e');
      return null;
    }
  }

  /// Register a book for the current user
  Future<bool> registerBook({
    required String isbn,
    required String userEmail,
    required String condition,
    int quantity = 1,
  }) async {
    try {
      debugPrint(
        'BookService.registerBook(): Registering ISBN: $isbn, Condition: $condition',
      );

      final response = await _apiClient.post(
        '/books/register',
        body: {
          'isbn': isbn,
          'userEmail': userEmail,
          'condition': condition,
          'quantity': quantity,
        },
      );

      final success = response['success'] == true;
      debugPrint(
        'BookService.registerBook(): ${success ? "Book registered successfully" : "Failed to register book"}',
      );
      return success;
    } on ApiException catch (e) {
      debugPrint('BookService.registerBook(): Error: $e');
      return false;
    }
  }

  /// Get user's books grouped by ISBN and condition
  Future<List<dynamic>> getUserBooks(String email) async {
    try {
      debugPrint('BookService.getUserBooks(): Fetching books for: $email');

      final response = await _apiClient.get('/books/user/$email');

      if (response['success'] == true && response['books'] != null) {
        final books = response['books'] as List;
        debugPrint(
          'BookService.getUserBooks(): Retrieved ${books.length} book groups',
        );
        return books;
      }

      return [];
    } on ApiException catch (e) {
      debugPrint('BookService.getUserBooks(): Error: $e');
      return [];
    }
  }

  /// Search books in catalog with pagination
  Future<Map<String, dynamic>> searchBooks({
    String? title,
    String? author,
    String? genre,
    int page = 1,
    int pageSize = 25,
  }) async {
    try {
      debugPrint('BookService.searchBooks(): Searching books (page $page)');

      final queryParams = <String>[];
      if (title != null && title.isNotEmpty) queryParams.add('title=$title');
      if (author != null && author.isNotEmpty) {
        queryParams.add('author=$author');
      }
      if (genre != null && genre.isNotEmpty) queryParams.add('genre=$genre');
      queryParams.add('page=$page');
      queryParams.add('pageSize=$pageSize');

      final query = '?${queryParams.join("&")}';

      final response = await _apiClient.get('/books/search$query');

      if (response['success'] == true && response['books'] != null) {
        final booksList = (response['books'] as List)
            .map((b) => Book.fromJson(b as Map<String, dynamic>))
            .toList();

        debugPrint(
          'BookService.searchBooks(): Found ${booksList.length} books (page $page of ${response['totalPages']})',
        );

        return {
          'books': booksList,
          'totalCount': response['totalCount'] ?? 0,
          'page': response['page'] ?? page,
          'pageSize': response['pageSize'] ?? pageSize,
          'totalPages': response['totalPages'] ?? 1,
        };
      }

      return {
        'books': <Book>[],
        'totalCount': 0,
        'page': 1,
        'pageSize': pageSize,
        'totalPages': 0,
      };
    } on ApiException catch (e) {
      debugPrint('BookService.searchBooks(): Error: $e');
      return {
        'books': <Book>[],
        'totalCount': 0,
        'page': 1,
        'pageSize': pageSize,
        'totalPages': 0,
      };
    }
  }

  /// Get distinct values for filtering (authors, genres, conditions)
  Future<List<String>> getDistinctValues(String property) async {
    try {
      debugPrint('BookService.getDistinctValues(): Getting $property');

      final response = await _apiClient.get(
        '/books/distinct?property=$property',
      );

      if (response['success'] == true && response['values'] != null) {
        final values = (response['values'] as List)
            .map((v) => v.toString())
            .toList();

        debugPrint(
          'BookService.getDistinctValues(): Found ${values.length} $property',
        );
        return values;
      }

      return [];
    } on ApiException catch (e) {
      debugPrint('BookService.getDistinctValues(): Error: $e');
      return [];
    }
  }

  /// Update the condition of a user's book listing
  Future<bool> updateUserBookCondition({
    required String isbn,
    required String userEmail,
    required String currentCondition,
    required String newCondition,
  }) async {
    try {
      final response = await _apiClient.patch(
        '/books/user/$userEmail/$isbn/$currentCondition',
        body: {'newCondition': newCondition},
      );
      return response['success'] == true;
    } on ApiException catch (e) {
      debugPrint('BookService.updateUserBookCondition(): Error: $e');
      return false;
    }
  }

  /// Delete a user's book by ISBN and condition
  Future<bool> deleteUserBook({
    required String isbn,
    required String userEmail,
    required String condition,
  }) async {
    try {
      debugPrint(
        'BookService.deleteUserBook(): Deleting ISBN: $isbn, Email: $userEmail, Condition: $condition',
      );

      final response = await _apiClient.delete(
        '/books/user/$userEmail/$isbn/$condition',
      );

      final success = response['success'] == true;
      debugPrint(
        'BookService.deleteUserBook(): ${success ? "Book deleted successfully" : "Failed to delete book"}',
      );
      return success;
    } on ApiException catch (e) {
      debugPrint('BookService.deleteUserBook(): Error: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _apiClient.dispose();
  }

  /// Get books currently borrowed by the user (Requisição active loans)
  Future<List<dynamic>> getBorrowedBooks(String email) async {
    try {
      debugPrint(
        'BookService.getBorrowedBooks(): Fetching borrowed books for: $email',
      );
      final response = await _apiClient.get('/transactions/borrowed/$email');
      if (response['success'] == true && response['books'] != null) {
        return response['books'] as List;
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('BookService.getBorrowedBooks(): Error: $e');
      return [];
    }
  }

  /// Get all available listings for a specific book ISBN
  Future<List<dynamic>> getBookListings(String isbn) async {
    try {
      debugPrint(
        'BookService.getBookListings(): Getting listings for ISBN: $isbn',
      );

      final response = await _apiClient.get('/books/$isbn/listings');

      if (response['success'] == true && response['listings'] != null) {
        final listings = response['listings'] as List;
        debugPrint(
          'BookService.getBookListings(): Found ${listings.length} listings',
        );
        return listings;
      }

      return [];
    } on ApiException catch (e) {
      debugPrint('BookService.getBookListings(): Error: $e');
      return [];
    }
  }
}
