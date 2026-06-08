import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/book.dart' show Book, BookConditions;
import '../models/book_listing.dart';
import '../providers/book_provider.dart';
import '../providers/auth_provider.dart';
import '../services/book_service.dart';
import '../services/transaction_service.dart';
import '../services/conversation_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final Book book;
  final bool isUserBook;
  final String? condition;
  final int? quantity;
  final bool isBorrowed;
  final int? borrowedTransactionId;

  const BookDetailScreen({
    super.key,
    required this.book,
    this.isUserBook = false,
    this.condition,
    this.quantity,
    this.isBorrowed = false,
    this.borrowedTransactionId,
  });

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  bool _isDeleting = false;
  bool _isReturning = false;
  bool _isLoadingListings = false;
  List<BookListing> _listings = [];
  int? _expandedListingId;
  final BookService _bookService = BookService();
  final TransactionService _transactionService = TransactionService();
  final ConversationService _conversationService = ConversationService();

  @override
  void initState() {
    super.initState();
    if (!widget.isUserBook) {
      _loadListings();
    }
  }

  Future<void> _returnBook() async {
    final authProvider = context.read<AuthProvider>();
    final bookProvider = context.read<BookProvider>();

    final confirm = await _showConfirmDialog(
      title: 'Devolver Livro?',
      content: 'Tem a certeza que deseja devolver "${widget.book.title}"?',
      confirmLabel: 'Devolver',
      confirmColor: AppColors.primary,
    );

    if (confirm != true || !mounted) return;
    setState(() => _isReturning = true);

    try {
      final userEmail = authProvider.currentUser?.email ?? '';
      final success = await _transactionService.returnBook(
        transactionId: widget.borrowedTransactionId!,
      );
      if (!mounted) return;
      await bookProvider.getUserBooks(userEmail);
      if (!mounted) return;
      _showSnack(
        success ? 'Livro devolvido com sucesso' : 'Erro ao devolver livro',
        success ? AppColors.success : AppColors.error,
      );
      if (success) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showSnack('Erro: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _isReturning = false);
    }
  }

  Future<void> _openChat(BookListing listing, {int? transactionId, String? transactionType}) async {
    final userEmail = context.read<AuthProvider>().currentUser?.email ?? '';
    if (userEmail.isEmpty || !mounted) return;

    final convId = await _conversationService.getOrCreateConversation(
      initiatorEmail: userEmail,
      receiverEmail: listing.ownerEmail,
      bookISBN: widget.book.isbn,
      transactionId: transactionId,
    );

    if (!mounted) return;

    if (convId == null) {
      _showSnack('Não foi possível abrir a conversa', AppColors.error);
      return;
    }

    await Navigator.push(
      context,
      AppPageRoute(
        child: ChatScreen(
          conversationId: convId,
          otherUserName: listing.ownerName,
          otherUserEmail: listing.ownerEmail,
          bookTitle: widget.book.title,
          bookISBN: widget.book.isbn,
          bookCover: widget.book.coverImageUrl,
          transactionId: transactionId,
          transactionType: transactionType,
          transactionStatus: transactionId != null ? 'Pendente' : null,
        ),
      ),
    );
  }

  Future<void> _loadListings() async {
    setState(() => _isLoadingListings = true);
    try {
      final listingsData = await _bookService.getBookListings(widget.book.isbn);
      setState(() {
        _listings = listingsData
            .map((json) => BookListing.fromJson(json as Map<String, dynamic>))
            .toList();
        _isLoadingListings = false;
      });
    } catch (e) {
      debugPrint('Error loading listings: $e');
      setState(() => _isLoadingListings = false);
    }
  }

  Future<void> _editCondition() async {
    if (widget.condition == null) return;
    final authProvider = context.read<AuthProvider>();
    final bookProvider = context.read<BookProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    String selected = widget.condition!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Alterar Condição', style: AppTextStyles.headlineMedium),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: BookConditions.all.map((c) {
              return RadioListTile<String>(
                title: Text(BookConditions.getLabel(c), style: AppTextStyles.bodyMedium),
                value: c,
                // ignore: deprecated_member_use
                groupValue: selected,
                // ignore: deprecated_member_use
                onChanged: (v) {
                  if (v != null) setDialogState(() => selected = v);
                },
                activeColor: AppColors.primary,
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: selected == widget.condition ? null : () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final userEmail = authProvider.currentUser?.email ?? '';
    final success = await _bookService.updateUserBookCondition(
      isbn: widget.book.isbn,
      userEmail: userEmail,
      currentCondition: widget.condition!,
      newCondition: selected,
    );

    if (!mounted) return;
    await bookProvider.getUserBooks(userEmail);
    messenger.showSnackBar(SnackBar(
      content: Text(success
          ? 'Condição atualizada para ${BookConditions.getLabel(selected)}'
          : 'Erro ao atualizar condição'),
      backgroundColor: success ? AppColors.success : AppColors.error,
    ));
    if (success) navigator.pop();
  }

  Future<void> _deleteBook() async {
    final authProvider = context.read<AuthProvider>();
    final bookProvider = context.read<BookProvider>();

    final confirm = await _showConfirmDialog(
      title: 'Eliminar Livro?',
      content: 'Tem a certeza que deseja eliminar este livro?',
      confirmLabel: 'Eliminar',
      confirmColor: AppColors.error,
    );

    if (confirm != true || !mounted) return;
    setState(() => _isDeleting = true);

    try {
      final userEmail = authProvider.currentUser?.email ?? '';
      final success = await _bookService.deleteUserBook(
        isbn: widget.book.isbn,
        userEmail: userEmail,
        condition: widget.condition ?? '',
      );

      if (!mounted) return;

      if (success) {
        await bookProvider.getUserBooks(userEmail);
        if (!mounted) return;
        _showSnack('Livro eliminado com sucesso', AppColors.success);
        Navigator.pop(context);
      } else {
        _showSnack('Erro ao eliminar livro', AppColors.error);
      }
    } catch (e) {
      if (mounted) _showSnack('Erro: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _requestPurchase(BookListing listing) async {
    final priceController = TextEditingController();

    try {
      final price = await showDialog<double>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          String? errorMessage;
          return StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: Text('Propor Compra', style: AppTextStyles.headlineMedium),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(label: 'Livro', value: widget.book.title),
                  _InfoRow(label: 'Proprietário', value: listing.ownerName),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Preço proposto (€)',
                      prefixText: '€ ',
                      errorText: errorMessage,
                      prefixIcon: const Icon(Icons.euro),
                    ),
                    onChanged: (_) {
                      if (errorMessage != null) setState(() => errorMessage = null);
                    },
                    onSubmitted: (value) {
                      final v = double.tryParse(value);
                      if (v != null && v > 0) Navigator.pop(context, v);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final v = double.tryParse(priceController.text);
                    if (v != null && v > 0) {
                      Navigator.pop(context, v);
                    } else {
                      setState(() => errorMessage = 'Por favor insira um preço válido');
                    }
                  },
                  child: const Text('Propor'),
                ),
              ],
            ),
          );
        },
      );

      Future.delayed(const Duration(milliseconds: 100), priceController.dispose);

      if (price == null || !mounted) return;

      final senderEmail = context.read<AuthProvider>().currentUser?.email ?? '';
      final transactionId = await _transactionService.createPurchaseTransaction(
        bookISBN: widget.book.isbn,
        senderEmail: senderEmail,
        receiverEmail: listing.ownerEmail,
        price: price,
        notes: 'Proposta de compra: €${price.toStringAsFixed(2)}',
      );

      if (!mounted) return;

      if (transactionId != null) {
        _conversationService.getOrCreateConversation(
          initiatorEmail: senderEmail,
          receiverEmail: listing.ownerEmail,
          bookISBN: widget.book.isbn,
          transactionId: transactionId,
        );
      }

      await _showResultDialog(
        success: transactionId != null,
        successMessage: 'A sua proposta de compra foi enviada com sucesso!',
        onSeeConversation: transactionId != null
            ? () => _openChat(listing, transactionId: transactionId, transactionType: 'Compra')
            : null,
      );
    } catch (e) {
      if (mounted) _showErrorDialog('Erro: $e');
    }
  }

  Future<void> _requestBorrow(BookListing listing) async {
    final senderEmail = context.read<AuthProvider>().currentUser?.email ?? '';

    try {
      final transactionId = await _transactionService.createBorrowTransaction(
        bookISBN: widget.book.isbn,
        senderEmail: senderEmail,
        receiverEmail: listing.ownerEmail,
        notes: 'Pedido de requisição',
      );

      if (!mounted) return;

      if (transactionId != null) {
        _conversationService.getOrCreateConversation(
          initiatorEmail: senderEmail,
          receiverEmail: listing.ownerEmail,
          bookISBN: widget.book.isbn,
          transactionId: transactionId,
        );
      }

      await _showResultDialog(
        success: transactionId != null,
        successMessage: 'O seu pedido de requisição foi enviado com sucesso!',
        onSeeConversation: transactionId != null
            ? () => _openChat(listing, transactionId: transactionId, transactionType: 'Requisição')
            : null,
      );
    } catch (e) {
      if (mounted) _showErrorDialog('Erro: $e');
    }
  }

  Future<void> _requestTrade(BookListing listing) async {
    final authProvider = context.read<AuthProvider>();
    final bookProvider = context.read<BookProvider>();
    final currentUserEmail = authProvider.currentUser?.email ?? '';

    await bookProvider.getUserBooks(currentUserEmail);
    final userBooks = bookProvider.userBooks;

    if (userBooks.isEmpty) {
      if (!mounted) return;
      _showErrorDialog('Não tem livros disponíveis para trocar.');
      return;
    }

    final selectedBook = await showDialog<Map<String, dynamic>>(
      context: context, // ignore: use_build_context_synchronously
      builder: (context) => AlertDialog(
        title: Text('Selecione um livro para trocar', style: AppTextStyles.headlineMedium),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: userBooks.length,
            itemBuilder: (context, index) {
              final bookEntry = userBooks[index];
              try {
                final bookData = bookEntry['bookData'] as Map<String, dynamic>?;
                if (bookData == null) return const ListTile(title: Text('Erro ao carregar livro'));
                final title = bookData['title'] as String? ?? 'Sem Título';
                final authors = bookData['authors'] as String? ?? '';
                final condition = bookEntry['condition'] as String? ?? '';
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: const Icon(Icons.menu_book, color: AppColors.primary, size: 20),
                  ),
                  title: Text(title, style: AppTextStyles.titleMedium),
                  subtitle: Text(authors, style: AppTextStyles.bodySmall),
                  trailing: ConditionBadge(condition: condition),
                  onTap: () => Navigator.pop(context, bookEntry),
                );
              } catch (e) {
                return const ListTile(title: Text('Erro ao carregar livro'));
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (selectedBook == null || !mounted) return;

    try {
      final bookData = selectedBook['bookData'] as Map<String, dynamic>?;
      if (bookData == null) { _showErrorDialog('Dados do livro inválidos.'); return; }
      final senderBookIsbn = bookData['isbn'] as String?;
      if (senderBookIsbn == null || senderBookIsbn.isEmpty) { _showErrorDialog('ISBN não disponível.'); return; }
      final senderBookTitle = bookData['title'] as String? ?? 'Livro';

      final transactionId = await _transactionService.createTradeTransaction(
        bookISBN: widget.book.isbn,
        senderEmail: currentUserEmail,
        receiverEmail: listing.ownerEmail,
        senderBookISBN: senderBookIsbn,
        notes: 'Proposta de troca por: $senderBookTitle',
      );

      if (!mounted) return;

      if (transactionId != null) {
        _conversationService.getOrCreateConversation(
          initiatorEmail: currentUserEmail,
          receiverEmail: listing.ownerEmail,
          bookISBN: widget.book.isbn,
          transactionId: transactionId,
        );
      }

      await _showResultDialog(
        success: transactionId != null,
        successMessage: 'A sua proposta de troca foi enviada com sucesso!',
        onSeeConversation: transactionId != null
            ? () => _openChat(listing, transactionId: transactionId, transactionType: 'Troca')
            : null,
      );
    } catch (e) {
      if (mounted) _showErrorDialog('Erro: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmLabel,
    required Color confirmColor,
  }) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, style: AppTextStyles.headlineMedium),
      content: Text(content, style: AppTextStyles.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel, style: TextStyle(color: confirmColor)),
        ),
      ],
    ),
  );

  Future<void> _showResultDialog({
    required bool success,
    required String successMessage,
    VoidCallback? onSeeConversation,
  }) => showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(success ? 'Enviado!' : 'Erro', style: AppTextStyles.headlineMedium),
      content: Text(
        success ? successMessage : 'Falha ao enviar. Por favor, tente novamente.',
        style: AppTextStyles.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
        if (success && onSeeConversation != null)
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onSeeConversation();
            },
            icon: const Icon(Icons.chat_bubble_outline, size: 16),
            label: const Text('Ver Conversa'),
          ),
      ],
    ),
  );

  Future<void> _showErrorDialog(String message) => showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Erro', style: AppTextStyles.headlineMedium),
      content: Text(message, style: AppTextStyles.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _BookDetailAppBar(book: widget.book),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Title & author
                Text(widget.book.title, style: AppTextStyles.displayMedium),
                if (widget.book.authors.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.book.authors,
                    style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 16),

                // Metadata chips row
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (widget.book.genre.isNotEmpty) _MetaChip(label: widget.book.genre, icon: Icons.category_outlined),
                    if (widget.book.publicationYear != null)
                      _MetaChip(label: widget.book.publicationYear.toString(), icon: Icons.calendar_today_outlined),
                    if (widget.book.publisher.isNotEmpty)
                      _MetaChip(label: widget.book.publisher, icon: Icons.business_outlined),
                    if (widget.isUserBook && widget.condition != null)
                      ConditionBadge(condition: widget.condition!),
                  ],
                ),

                if (widget.book.description.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionHeader(label: 'Descrição'),
                  const SizedBox(height: 8),
                  Text(widget.book.description, style: AppTextStyles.bodyMedium.copyWith(height: 1.65)),
                ],

                if (widget.book.tags.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionHeader(label: 'Etiquetas'),
                  const SizedBox(height: 8),
                  Text(widget.book.tags, style: AppTextStyles.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
                ],

                const SizedBox(height: 8),
                _SectionHeader(label: 'ISBN'),
                const SizedBox(height: 4),
                Text(widget.book.isbn, style: AppTextStyles.bodyMedium),

                if (widget.isUserBook && widget.quantity != null) ...[
                  const SizedBox(height: 12),
                  _SectionHeader(label: 'Quantidade'),
                  const SizedBox(height: 4),
                  Text('${widget.quantity} exemplar(es)', style: AppTextStyles.bodyMedium),
                ],

                // Listings section
                if (!widget.isUserBook) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  _SectionHeader(label: 'Cópias Disponíveis'),
                  const SizedBox(height: 12),
                  if (_isLoadingListings)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    )
                  else if (_listings.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.textHint, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'Nenhuma cópia disponível no momento.',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _listings.length,
                      itemBuilder: (context, index) {
                        final listing = _listings[index];
                        final isExpanded = _expandedListingId == listing.listingId;
                        return AnimatedListItem(
                          index: index,
                          child: _ListingCard(
                            listing: listing,
                            isExpanded: isExpanded,
                            onToggle: () => setState(() {
                              _expandedListingId = isExpanded ? null : listing.listingId;
                            }),
                            onBuy: () { setState(() => _expandedListingId = null); _requestPurchase(listing); },
                            onBorrow: () { setState(() => _expandedListingId = null); _requestBorrow(listing); },
                            onTrade: () { setState(() => _expandedListingId = null); _requestTrade(listing); },
                            onMessage: () => _openChat(listing),
                          ),
                        );
                      },
                    ),
                ],

                // Owner actions
                if (widget.isUserBook && !widget.isBorrowed) ...[
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _editCondition,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Alterar Condição'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _isDeleting ? null : _deleteBook,
                    icon: _isDeleting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.delete_outline, size: 18),
                    label: Text(_isDeleting ? 'Eliminando...' : 'Eliminar Livro'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],

                if (widget.isBorrowed) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isReturning ? null : _returnBook,
                    icon: _isReturning
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.assignment_return_outlined, size: 18),
                    label: Text(_isReturning ? 'Devolvendo...' : 'Devolver Livro'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sliver AppBar ────────────────────────────────────────────────────────────

class _BookDetailAppBar extends StatelessWidget {
  final Book book;
  const _BookDetailAppBar({required this.book});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppColors.primary,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (book.coverImageUrl.isNotEmpty)
              Hero(
                tag: 'book_cover_${book.isbn}',
                child: Image.network(
                  book.coverImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, e, st) => _FallbackCover(),
                ),
              )
            else
              _FallbackCover(),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.transparent, AppColors.primaryDark],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ],
        ),
        collapseMode: CollapseMode.parallax,
      ),
    );
  }
}

class _FallbackCover extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.primaryHorizontal),
      child: const Center(
        child: Icon(Icons.menu_book, size: 80, color: Colors.white30),
      ),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.nunito(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textHint,
        letterSpacing: 1.2,
      ).copyWith(decoration: TextDecoration.none),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _MetaChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
          Expanded(child: Text(value, style: AppTextStyles.bodySmall)),
        ],
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final BookListing listing;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onBuy;
  final VoidCallback onBorrow;
  final VoidCallback onTrade;
  final VoidCallback onMessage;

  const _ListingCard({
    required this.listing,
    required this.isExpanded,
    required this.onToggle,
    required this.onBuy,
    required this.onBorrow,
    required this.onTrade,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.divider, width: 0.8),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        listing.ownerName.isNotEmpty ? listing.ownerName[0].toUpperCase() : '?',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(listing.ownerName, style: AppTextStyles.titleMedium),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            ConditionBadge(condition: listing.condition),
                            if (listing.emprestado) ...[
                              const SizedBox(width: 6),
                              _StatusTag(label: 'Emprestado', color: AppColors.warning),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: AppDurations.fast,
                    child: const Icon(Icons.keyboard_arrow_down, color: AppColors.textHint),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppDurations.normal,
            curve: Curves.easeInOut,
            child: isExpanded
                ? Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(AppRadius.md),
                        bottomRight: Radius.circular(AppRadius.md),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Divider(height: 1),
                        _ActionTile(
                          icon: Icons.shopping_cart_outlined,
                          label: 'Comprar',
                          color: AppColors.success,
                          onTap: onBuy,
                        ),
                        _ActionTile(
                          icon: Icons.library_books_outlined,
                          label: 'Requisitar',
                          color: AppColors.primary,
                          onTap: onBorrow,
                        ),
                        _ActionTile(
                          icon: Icons.swap_horiz,
                          label: 'Propor Troca',
                          color: AppColors.secondary,
                          onTap: onTrade,
                        ),
                        _ActionTile(
                          icon: Icons.chat_bubble_outline,
                          label: 'Enviar Mensagem',
                          color: AppColors.info,
                          onTap: onMessage,
                          isLast: true,
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isLast;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.only(
              bottomLeft: Radius.circular(AppRadius.md),
              bottomRight: Radius.circular(AppRadius.md),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Text(label, style: AppTextStyles.titleMedium),
            const Spacer(),
            Icon(Icons.chevron_right, color: AppColors.textHint, size: 18),
          ],
        ),
      ),
    );
  }
}
