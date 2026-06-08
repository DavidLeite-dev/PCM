import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/book.dart';
import '../services/book_service.dart';

class BookProvider extends ChangeNotifier {
  final BookService _bookService = BookService();

  List<Book> _searchResults = [];
  List<Book> _nextPageResults = [];
  List<Book> _previousPageResults = [];
  List<dynamic> _userBooks = [];
  bool _isLoading = false;
  String? _error;

  // Pagination state
  int _currentPage = 1;
  final int _pageSize = 4;
  int _totalPages = 0;
  int _totalCount = 0;

  // Advanced filtering state
  Map<String, Set<String>> _selectedFilters = {
    'authors': {},
    'genre': {},
    'tags': {},
  };
  String _searchQuery = '';

  List<Book> get searchResults => _searchResults;
  List<Book> get nextPageResults => _nextPageResults;
  List<Book> get previousPageResults => _previousPageResults;
  List<dynamic> get userBooks => _userBooks;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, Set<String>> get selectedFilters => _selectedFilters;
  String get searchQuery => _searchQuery;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalCount => _totalCount;
  int get pageSize => _pageSize;

  /// Look up a book by ISBN
  Future<Book?> lookupISBN(String isbn) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final book = await _bookService.lookupISBN(isbn);
      _isLoading = false;
      notifyListeners();
      return book;
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('503')) {
        _error =
            'Serviço temporariamente indisponível. Por favor, tente mais tarde.';
      } else if (errorStr.contains('404')) {
        _error = 'Livro não encontrado. Verifique o ISBN.';
      } else if (errorStr.contains('Network') ||
          errorStr.contains('connection')) {
        _error = 'Erro de conexão. Verifique a sua ligação à internet.';
      } else {
        _error = 'Erro ao procurar ISBN. Tente novamente.';
      }
      debugPrint('BookProvider.lookupISBN(): Error: $e');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Register a book for the user
  Future<bool> registerBook({
    required String isbn,
    required String userEmail,
    required String condition,
    int quantity = 1,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _bookService.registerBook(
        isbn: isbn,
        userEmail: userEmail,
        condition: condition,
        quantity: quantity,
      );

      _isLoading = false;
      if (success) {
        _error = null;
        // Refresh user books after successful registration
        await getUserBooks(userEmail);
      } else {
        _error = 'Falha ao registar livro';
      }
      notifyListeners();
      return success;
    } catch (e) {
      _error = 'Erro ao registar livro: $e';
      debugPrint('BookProvider.registerBook(): Error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Get user's books
  Future<void> getUserBooks(String userEmail) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _userBooks = await _bookService.getUserBooks(userEmail);
      _error = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erro ao carregar livros do utilizador: $e';
      debugPrint('BookProvider.getUserBooks(): Error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Search books by title, author, or genre with pagination
  Future<void> searchBooks({
    String? title,
    String? author,
    String? genre,
    int? page,
  }) async {
    _isLoading = true;
    _error = null;

    if (page != null) {
      _currentPage = page;
    }

    notifyListeners();

    try {
      final result = await _bookService.searchBooks(
        title: title,
        author: author,
        genre: genre,
        page: _currentPage,
        pageSize: _pageSize,
      );

      _searchResults = result['books'] as List<Book>;
      _totalCount = result['totalCount'] as int;
      _totalPages = result['totalPages'] as int;
      _currentPage = result['page'] as int;

      // Pre-fetch next page if it exists
      if (_currentPage < _totalPages) {
        try {
          final nextResult = await _bookService.searchBooks(
            title: title,
            author: author,
            genre: genre,
            page: _currentPage + 1,
            pageSize: _pageSize,
          );
          _nextPageResults = nextResult['books'] as List<Book>;
        } catch (e) {
          debugPrint('BookProvider: Failed to pre-fetch next page: $e');
          _nextPageResults = [];
        }
      } else {
        _nextPageResults = [];
      }

      // Pre-fetch previous page if it exists
      if (_currentPage > 1) {
        try {
          final prevResult = await _bookService.searchBooks(
            title: title,
            author: author,
            genre: genre,
            page: _currentPage - 1,
            pageSize: _pageSize,
          );
          _previousPageResults = prevResult['books'] as List<Book>;
        } catch (e) {
          debugPrint('BookProvider: Failed to pre-fetch previous page: $e');
          _previousPageResults = [];
        }
      } else {
        _previousPageResults = [];
      }

      _error = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erro ao pesquisar livros: $e';
      debugPrint('BookProvider.searchBooks(): Error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load initial books (first page)
  Future<void> loadInitialBooks() async {
    _currentPage = 1;
    await searchBooks(title: '');
  }

  /// Go to specific page
  Future<void> goToPage(int page) async {
    if (page < 1 || page > _totalPages) return;
    await searchBooks(
      title: _searchQuery.isNotEmpty ? _searchQuery : null,
      page: page,
    );
  }

  /// Go to next page
  Future<void> nextPage() async {
    if (_currentPage < _totalPages) {
      await goToPage(_currentPage + 1);
    }
  }

  /// Go to previous page
  Future<void> previousPage() async {
    if (_currentPage > 1) {
      await goToPage(_currentPage - 1);
    }
  }

  /// Go to first page
  Future<void> firstPage() async {
    await goToPage(1);
  }

  /// Go to last page
  Future<void> lastPage() async {
    await goToPage(_totalPages);
  }

  /// Get distinct filter options
  Future<List<String>> getDistinctValues(String property) async {
    try {
      return await _bookService.getDistinctValues(property);
    } catch (e) {
      _error = 'Erro ao carregar filtros: $e';
      debugPrint('BookProvider.getDistinctValues(): Error: $e');
      return [];
    }
  }

  /// Clear search results and errors
  void clearSearch() {
    _searchResults = [];
    _error = null;
    notifyListeners();
  }

  /// Get categories (genre) for filtering
  Future<List<String>> getCategories() async {
    return await getDistinctValues('genre');
  }

  /// Get tags for filtering
  Future<List<String>> getTags() async {
    return await getDistinctValues('tags');
  }

  /// Filter by category (genre)
  Future<void> filterByCategory(String category) async {
    _isLoading = true;
    notifyListeners();

    if (category == 'all') {
      // Load all books when 'all' is selected
      await searchBooks(title: '');
    } else {
      await searchBooks(genre: category);
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Delete a user's book
  Future<bool> deleteUserBook({
    required String isbn,
    required String userEmail,
    required String condition,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _bookService.deleteUserBook(
        isbn: isbn,
        userEmail: userEmail,
        condition: condition,
      );

      _isLoading = false;
      if (success) {
        _error = null;
        // Refresh user books after successful deletion
        await getUserBooks(userEmail);
      } else {
        _error = 'Falha ao eliminar livro';
      }
      notifyListeners();
      return success;
    } catch (e) {
      _error = 'Erro ao eliminar livro: $e';
      debugPrint('BookProvider.deleteUserBook(): Error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Apply advanced filters and search with title
  Future<void> applyAdvancedFilters({
    String searchQuery = '',
    Map<String, Set<String>>? filters,
  }) async {
    _isLoading = true;
    _error = null;
    _searchQuery = searchQuery;
    _currentPage = 1; // Reset to first page when filtering

    if (filters != null) {
      _selectedFilters = filters;
    }
    notifyListeners();

    try {
      // Build filter parameters
      String? authorFilter;
      String? genreFilter;

      if (_selectedFilters['authors']?.isNotEmpty ?? false) {
        // Search for any matching author
        authorFilter = _selectedFilters['authors']!.first;
      }

      if (_selectedFilters['genre']?.isNotEmpty ?? false) {
        // Search for any matching genre
        genreFilter = _selectedFilters['genre']!.first;
      }

      // Get matching books with pagination
      final result = await _bookService.searchBooks(
        title: searchQuery.isNotEmpty ? searchQuery : null,
        author: authorFilter,
        genre: genreFilter,
        page: _currentPage,
        pageSize: _pageSize,
      );

      _searchResults = result['books'] as List<Book>;
      _totalCount = result['totalCount'] as int;
      _totalPages = result['totalPages'] as int;
      _currentPage = result['page'] as int;

      // Apply multiple filters locally if needed
      if (_selectedFilters.values.any((set) => set.length > 1)) {
        await _applyLocalFilters();
      }

      _error = null;
    } catch (e) {
      _error = 'Erro ao aplicar filtros: $e';
      debugPrint('BookProvider.applyAdvancedFilters(): Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Apply multiple filters locally to search results
  Future<void> _applyLocalFilters() async {
    List<Book> filtered = List.from(_searchResults);

    // Filter by authors
    if (_selectedFilters['authors']?.isNotEmpty ?? false) {
      filtered = filtered.where((book) {
        final bookAuthors = book.getAuthorsList();
        return bookAuthors.any(
          (author) => _selectedFilters['authors']!.contains(author),
        );
      }).toList();
    }

    // Filter by genre
    if (_selectedFilters['genre']?.isNotEmpty ?? false) {
      filtered = filtered.where((book) {
        return _selectedFilters['genre']!.contains(book.genre);
      }).toList();
    }

    // Filter by tags
    if (_selectedFilters['tags']?.isNotEmpty ?? false) {
      filtered = filtered.where((book) {
        final bookTags = book.getTagsList();
        return bookTags.any((tag) => _selectedFilters['tags']!.contains(tag));
      }).toList();
    }

    _searchResults = filtered;
  }

  /// Clear all filters and search
  Future<void> clearAllFilters() async {
    _searchQuery = '';
    _selectedFilters = {'authors': {}, 'genre': {}, 'tags': {}};
    _error = null;
    notifyListeners();
    // Load initial books after clearing filters
    await loadInitialBooks();
  }

  /// Get all filter categories with their options
  Future<Map<String, List<String>>> getFilterOptions() async {
    try {
      final authors = await getDistinctValues('authors');
      final genres = await getDistinctValues('genres');

      return {'authors': authors, 'genres': genres};
    } catch (e) {
      _error = 'Erro ao carregar opções de filtro: $e';
      debugPrint('BookProvider.getFilterOptions(): Error: $e');
      return {};
    }
  }
}
