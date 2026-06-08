import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/book_provider.dart';
import '../models/book.dart';
import '../widgets/filter_dialog.dart';
import '../widgets/page_flip_widget.dart';
import '../theme/app_theme.dart';
import 'book_detail_screen.dart';

class BookCatalogScreen extends StatefulWidget {
  const BookCatalogScreen({super.key});

  @override
  State<BookCatalogScreen> createState() => _BookCatalogScreenState();
}

class _BookCatalogScreenState extends State<BookCatalogScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  Map<String, List<String>> _filterOptions = {};
  bool _filterOptionsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookProvider>().loadInitialBooks();
    });
  }

  Future<void> _loadFilterOptions() async {
    final options = await context.read<BookProvider>().getFilterOptions();
    if (mounted) {
      setState(() {
        _filterOptions = options;
        _filterOptionsLoaded = true;
      });
    }
  }

  void _openFilterDialog() {
    final bookProvider = context.read<BookProvider>();
    showDialog(
      context: context,
      builder: (context) => FilterDialog(
        filterOptions: _filterOptions,
        selectedFilters: bookProvider.selectedFilters,
        onApplyFilters: (filters) {
          bookProvider.applyAdvancedFilters(
            searchQuery: _searchController.text,
            filters: filters,
          );
        },
      ),
    );
  }

  int _getTotalActiveFilters() {
    int count = 0;
    context.watch<BookProvider>().selectedFilters.forEach((_, values) {
      count += values.length;
    });
    return count;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();
    final activeFiltersCount = _getTotalActiveFilters();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PaperBackground(
        child: Column(
          children: [
            _CatalogHeader(
              searchController: _searchController,
              activeFiltersCount: activeFiltersCount,
              filterOptionsLoaded: _filterOptionsLoaded,
              onFilterTap: _openFilterDialog,
              onSearch: (value) {
                context.read<BookProvider>().applyAdvancedFilters(searchQuery: value);
              },
              onClear: () {
                _searchController.clear();
                context.read<BookProvider>().clearAllFilters();
              },
              activeFilterChips: _buildActiveFilterChips(),
            ),

            Expanded(
              child: bookProvider.searchResults.isEmpty
                  ? bookProvider.isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                              strokeWidth: 2.5,
                            ),
                          )
                        : _EmptyState()
                  : PageFlipWidget(
                      currentPage: _buildBookList(
                        bookProvider.searchResults,
                        bookProvider.currentPage,
                        bookProvider.totalPages,
                        context,
                      ),
                      nextPage: bookProvider.currentPage < bookProvider.totalPages
                          ? _buildBookList(
                              bookProvider.nextPageResults,
                              bookProvider.currentPage + 1,
                              bookProvider.totalPages,
                              context,
                            )
                          : null,
                      previousPage: bookProvider.currentPage > 1
                          ? _buildBookList(
                              bookProvider.previousPageResults,
                              bookProvider.currentPage - 1,
                              bookProvider.totalPages,
                              context,
                            )
                          : null,
                      canFlipNext: bookProvider.currentPage < bookProvider.totalPages,
                      canFlipPrevious: bookProvider.currentPage > 1,
                      isLoading: bookProvider.isLoading,
                      onFlipNext: () => context.read<BookProvider>().nextPage(),
                      onFlipPrevious: () => context.read<BookProvider>().previousPage(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookList(
    List<Book> books,
    int pageNumber,
    int totalPages,
    BuildContext context,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          key: ValueKey(pageNumber),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (int i = 0; i < books.length; i++)
                    Flexible(
                      child: AnimatedListItem(
                        index: i,
                        child: _BookCard(
                          book: books[i],
                          availableHeight:
                              constraints.maxHeight / books.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (totalPages > 1)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: _PageIndicator(
                  currentPage: pageNumber,
                  totalPages: totalPages,
                ),
              ),
          ],
        );
      },
    );
  }

  List<Widget> _buildActiveFilterChips() {
    final bookProvider = context.read<BookProvider>();
    final chips = <Widget>[];
    bookProvider.selectedFilters.forEach((category, values) {
      for (final value in values) {
        chips.add(
          Chip(
            label: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            onDeleted: () {
              final newFilters = Map<String, Set<String>>.from(bookProvider.selectedFilters);
              newFilters[category]?.remove(value);
              bookProvider.applyAdvancedFilters(
                searchQuery: _searchController.text,
                filters: newFilters,
              );
            },
            deleteIcon: const Icon(Icons.close, size: 14),
            backgroundColor: AppColors.primaryContainer,
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3), width: 0.8),
            labelStyle: GoogleFonts.nunito(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            deleteIconColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          ),
        );
      }
    });
    return chips;
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _CatalogHeader extends StatelessWidget {
  final TextEditingController searchController;
  final int activeFiltersCount;
  final bool filterOptionsLoaded;
  final VoidCallback onFilterTap;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;
  final List<Widget> activeFilterChips;

  const _CatalogHeader({
    required this.searchController,
    required this.activeFiltersCount,
    required this.filterOptionsLoaded,
    required this.onFilterTap,
    required this.onSearch,
    required this.onClear,
    required this.activeFilterChips,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      color: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: top + 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Catálogo',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.tune, color: Colors.white),
                      onPressed: filterOptionsLoaded ? onFilterTap : null,
                      tooltip: 'Filtros',
                    ),
                    if (activeFiltersCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: AppColors.secondary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$activeFiltersCount',
                              style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: TextField(
              controller: searchController,
              onChanged: onSearch,
              style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Pesquisar livros, autores, géneros...',
                hintStyle: GoogleFonts.nunito(color: AppColors.textHint, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                suffixIcon: searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: onClear,
                        child: const Icon(Icons.close, color: AppColors.textHint, size: 18),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: const BorderSide(color: AppColors.secondary, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                isDense: true,
              ),
            ),
          ),
          if (activeFiltersCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: activeFilterChips.map((c) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: c,
                )).toList()),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Book Card ────────────────────────────────────────────────────────────────

class _BookCard extends StatefulWidget {
  final Book book;
  final double availableHeight;

  const _BookCard({required this.book, required this.availableHeight});

  @override
  State<_BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<_BookCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final maxCardHeight = widget.availableHeight - 8;
    final maxImageHeight = maxCardHeight - 28;
    final imageHeight = maxImageHeight.clamp(72.0, 130.0);
    final imageWidth = imageHeight / 1.55;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        Navigator.push(
          context,
          AppPageRoute(
            child: BookDetailScreen(book: widget.book, isUserBook: false),
          ),
        );
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: AppDurations.fast,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.card,
            border: Border.all(color: AppColors.divider, width: 0.8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Cover
                Hero(
                  tag: 'book_cover_${widget.book.isbn}',
                  child: _BookCover(
                    url: widget.book.coverImageUrl,
                    width: imageWidth,
                    height: imageHeight,
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: SizedBox(
                    height: imageHeight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.book.title,
                          style: AppTextStyles.bookTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.book.authors.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.book.authors,
                            style: AppTextStyles.bookAuthor,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (widget.book.genre.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _GenreTag(genre: widget.book.genre),
                        ],
                        if (widget.book.publicationYear != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.book.publicationYear.toString(),
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textHint,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookCover extends StatelessWidget {
  final String url;
  final double width;
  final double height;

  const _BookCover({required this.url, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: url.isNotEmpty
          ? Image.network(
              url,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, e, st) => _Placeholder(width: width, height: height),
            )
          : _Placeholder(width: width, height: height),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final double width;
  final double height;

  const _Placeholder({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceVariant, AppColors.divider],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Icon(
        Icons.menu_book_outlined,
        size: width * 0.45,
        color: AppColors.textHint,
      ),
    );
  }
}

class _GenreTag extends StatelessWidget {
  final String genre;
  const _GenreTag({required this.genre});

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books_outlined,
            size: 64,
            color: AppColors.textHint.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum livro encontrado',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tente ajustar os filtros de pesquisa',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ─── Page Indicator ───────────────────────────────────────────────────────────

class _PageIndicator extends StatelessWidget {
  final int currentPage;
  final int totalPages;

  const _PageIndicator({required this.currentPage, required this.totalPages});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primaryDark.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(AppRadius.full),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book, size: 13, color: AppColors.secondaryLight),
            const SizedBox(width: 6),
            Text(
              'Página $currentPage de $totalPages',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.swipe, size: 13, color: AppColors.textOnDarkMuted),
          ],
        ),
      ),
    );
  }
}
