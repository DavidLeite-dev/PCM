import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/book_provider.dart';
import '../models/book.dart';
import '../services/book_service.dart';
import '../theme/app_theme.dart';
import 'book_detail_screen.dart';

class MyBooksScreen extends StatefulWidget {
  const MyBooksScreen({super.key});

  @override
  State<MyBooksScreen> createState() => _MyBooksScreenState();
}

class _MyBooksScreenState extends State<MyBooksScreen> {
  final BookService _bookService = BookService();
  List<dynamic> _borrowedBooks = [];
  bool _loadingBorrowed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final bookProvider = context.read<BookProvider>();
      final userEmail = authProvider.currentUser?.email ?? '';
      bookProvider.getUserBooks(userEmail);
      _loadBorrowedBooks(userEmail);
    });
  }

  Future<void> _loadBorrowedBooks(String email) async {
    setState(() => _loadingBorrowed = true);
    try {
      final borrowed = await _bookService.getBorrowedBooks(email);
      if (mounted) setState(() => _borrowedBooks = borrowed);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingBorrowed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();
    final authProvider = context.watch<AuthProvider>();
    final userEmail = authProvider.currentUser?.email ?? '';
    final userBooks = bookProvider.userBooks;

    final bool isLoading = bookProvider.isLoading || _loadingBorrowed;
    final bool isEmpty = userBooks.isEmpty && _borrowedBooks.isEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PaperBackground(
        child: Column(
          children: [
            _MyBooksHeader(
              borrowedCount: _borrowedBooks.length,
              ownedCount: userBooks.length,
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : isEmpty
                      ? _EmptyMyBooks()
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: () async {
                            bookProvider.getUserBooks(userEmail);
                            await _loadBorrowedBooks(userEmail);
                          },
                          child: ListView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            children: [
                              if (_borrowedBooks.isNotEmpty) ...[
                                _SectionTitle(
                                  label: 'Requisitados',
                                  count: _borrowedBooks.length,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(height: 8),
                                for (int i = 0; i < _borrowedBooks.length; i++)
                                  AnimatedListItem(
                                    index: i,
                                    child: _buildBookCard(_borrowedBooks[i], isBorrowed: true),
                                  ),
                              ],
                              if (userBooks.isNotEmpty) ...[
                                if (_borrowedBooks.isNotEmpty) const SizedBox(height: 12),
                                _SectionTitle(
                                  label: 'Minha Biblioteca',
                                  count: userBooks.length,
                                  color: AppColors.secondary,
                                ),
                                const SizedBox(height: 8),
                                for (int i = 0; i < userBooks.length; i++)
                                  AnimatedListItem(
                                    index: _borrowedBooks.length + i,
                                    child: _buildBookCard(userBooks[i], isBorrowed: false),
                                  ),
                              ],
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/add-book-isbn'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildBookCard(dynamic item, {required bool isBorrowed}) {
    final String isbn = item['bookData']?['isbn'] ?? '';
    final String title = item['bookData']?['title'] ?? 'Livro desconhecido';
    final String authors = item['bookData']?['authors'] ?? '';
    final String genre = item['bookData']?['genre'] ?? '';
    final String tags = item['bookData']?['tags'] ?? '';
    final String description = item['bookData']?['description'] ?? '';
    final String publisher = item['bookData']?['publisher'] ?? '';
    final int? publicationYear = item['bookData']?['publicationYear'];
    final String coverImageUrl = item['bookData']?['coverImageUrl'] ?? '';
    final String condition = item['condition'] ?? '';
    final int quantity = item['quantity'] ?? 1;
    final bool emprestado = item['emprestado'] == true;
    final int? borrowedTransactionId = item['transactionId'];

    final book = Book(
      isbn: isbn,
      title: title,
      authors: authors,
      genre: genre,
      tags: tags,
      description: description,
      publisher: publisher,
      publicationYear: publicationYear,
      coverImageUrl: coverImageUrl,
    );

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        AppPageRoute(
          child: BookDetailScreen(
            book: book,
            isUserBook: true,
            condition: condition,
            quantity: quantity,
            isBorrowed: isBorrowed,
            borrowedTransactionId: borrowedTransactionId,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.card,
          border: Border.all(
            color: isBorrowed
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.divider,
            width: isBorrowed ? 1.5 : 0.8,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    child: coverImageUrl.isNotEmpty
                        ? Image.network(
                            coverImageUrl,
                            width: 72,
                            height: 108,
                            fit: BoxFit.cover,
                            errorBuilder: (_, e, st) => _coverPlaceholder(),
                          )
                        : _coverPlaceholder(),
                  ),
                  if (isBorrowed)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.88),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(AppRadius.xs),
                            bottomRight: Radius.circular(AppRadius.xs),
                          ),
                        ),
                        child: Text(
                          'Req.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bookTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (authors.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(authors, style: AppTextStyles.bookAuthor, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    if (genre.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          genre,
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (condition.isNotEmpty) ConditionBadge(condition: condition),
                        if (emprestado && !isBorrowed)
                          _StatusPill(
                            label: 'Emprestado',
                            color: AppColors.warning,
                            icon: Icons.person_outline,
                          ),
                      ],
                    ),
                    if (!isBorrowed) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 12, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Text(
                            '$quantity exemplar${quantity != 1 ? 'es' : ''}',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const Icon(Icons.chevron_right, color: AppColors.textHint, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      width: 72,
      height: 108,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceVariant, AppColors.divider],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: const Icon(Icons.menu_book_outlined, color: AppColors.textHint, size: 28),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _MyBooksHeader extends StatelessWidget {
  final int borrowedCount;
  final int ownedCount;

  const _MyBooksHeader({required this.borrowedCount, required this.ownedCount});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      color: AppColors.primary,
      padding: EdgeInsets.fromLTRB(16, top + 10, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Meus Livros',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          if (ownedCount > 0 || borrowedCount > 0) ...[
            _CountChip(label: '$ownedCount', icon: Icons.bookmarks_outlined),
            if (borrowedCount > 0) ...[
              const SizedBox(width: 8),
              _CountChip(
                label: '$borrowedCount',
                icon: Icons.swap_horizontal_circle_outlined,
                color: AppColors.secondaryLight,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _CountChip({
    required this.label,
    required this.icon,
    this.color = Colors.white70,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SectionTitle({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusPill({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _EmptyMyBooks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmarks_outlined, size: 72, color: AppColors.textHint.withValues(alpha: 0.5)),
            const SizedBox(height: 20),
            Text(
              'A sua biblioteca está vazia',
              style: AppTextStyles.headlineMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Adicione o seu primeiro livro\npara começar a trocar!',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
