import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction.dart';
import '../providers/auth_provider.dart';
import '../services/transaction_service.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  final TransactionService _transactionService = TransactionService();
  late TabController _tabController;
  List<Transaction> _allSentTransactions = [];
  List<Transaction> _allReceivedTransactions = [];
  bool _isLoading = true;
  late String _currentUserEmail;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTransactions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();
    final email = authProvider.currentUser?.email ?? '';
    _currentUserEmail = email;

    if (email.isEmpty) { setState(() => _isLoading = false); return; }

    try {
      final sent = await _transactionService.getSentTransactions(email);
      final received = await _transactionService.getReceivedTransactions(email);
      if (mounted) {
        setState(() {
          _allSentTransactions = sent;
          _allReceivedTransactions = received;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar transações: $e')),
        );
      }
    }
  }

  List<Transaction> get _pendingSent => _allSentTransactions.where((t) => t.isPending).toList();
  List<Transaction> get _pendingReceived => _allReceivedTransactions.where((t) => t.isPending).toList();
  List<Transaction> get _history {
    final history = <Transaction>[];
    history.addAll(_allSentTransactions.where((t) => !t.isPending));
    history.addAll(_allReceivedTransactions.where((t) => !t.isPending));
    history.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return history;
  }

  Future<void> _acceptTransaction(Transaction t) async {
    final confirm = await _confirmDialog(
      'Aceitar Transação?',
      _getAcceptMessage(t),
      'Aceitar',
      AppColors.success,
    );
    if (confirm != true) return;
    final success = await _transactionService.acceptTransaction(t.id);
    if (!mounted) return;
    _showSnack(
      success ? 'Transação aceite com sucesso!' : 'Erro ao aceitar transação',
      success ? AppColors.success : AppColors.error,
    );
    if (success) _loadTransactions();
  }

  Future<void> _rejectTransaction(Transaction t) async {
    final confirm = await _confirmDialog(
      'Rejeitar Transação?',
      'Tem a certeza que deseja rejeitar esta transação?',
      'Rejeitar',
      AppColors.error,
    );
    if (confirm != true) return;
    final success = await _transactionService.rejectTransaction(t.id);
    if (!mounted) return;
    _showSnack(
      success ? 'Transação rejeitada' : 'Erro ao rejeitar transação',
      success ? AppColors.warning : AppColors.error,
    );
    if (success) _loadTransactions();
  }

  Future<void> _cancelTransaction(Transaction t) async {
    final confirm = await _confirmDialog(
      'Cancelar Transação?',
      'Tem a certeza que deseja cancelar esta transação?',
      'Cancelar',
      AppColors.error,
    );
    if (confirm != true) return;
    final success = await _transactionService.cancelTransaction(t.id);
    if (!mounted) return;
    _showSnack(
      success ? 'Transação cancelada' : 'Erro ao cancelar transação',
      success ? AppColors.warning : AppColors.error,
    );
    if (success) _loadTransactions();
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  Future<bool?> _confirmDialog(String title, String content, String confirmLabel, Color color) =>
      showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title, style: AppTextStyles.headlineMedium),
          content: Text(content, style: AppTextStyles.bodyMedium),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

  String _getAcceptMessage(Transaction t) {
    switch (t.type) {
      case 'Compra':
        return 'Aceitar venda de "${t.bookTitle}" para ${t.senderName} por €${t.price?.toStringAsFixed(2)}?';
      case 'Requisição':
        return 'Aceitar empréstimo de "${t.bookTitle}" para ${t.senderName}?';
      case 'Troca':
        return 'Aceitar troca de "${t.bookTitle}" por "${t.tradeBookTitle}" com ${t.senderName}?';
      default:
        return 'Aceitar esta transação?';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PaperBackground(
        child: Column(
          children: [
            _TransactionsHeader(
              tabController: _tabController,
              pendingSentCount: _pendingSent.length,
              pendingReceivedCount: _pendingReceived.length,
              historyCount: _history.length,
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildList(_pendingSent, isSent: true, isPending: true),
                        _buildList(_pendingReceived, isSent: false, isPending: true),
                        _buildList(_history, isHistory: true),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Transaction> transactions, {
    bool isSent = false,
    bool isPending = false,
    bool isHistory = false,
  }) {
    if (transactions.isEmpty) {
      return _EmptyTransactions(
        icon: isHistory ? Icons.history : isSent ? Icons.send : Icons.inbox,
        message: isHistory
            ? 'Sem transações completas'
            : isSent
                ? 'Sem transações pendentes enviadas'
                : 'Sem transações pendentes recebidas',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadTransactions,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final t = transactions[index];
          final sentForHistory = isHistory ? t.senderEmail == _currentUserEmail : isSent;
          return AnimatedListItem(
            index: index,
            child: _TransactionCard(
              transaction: t,
              isSent: sentForHistory,
              isPending: isPending,
              isHistory: isHistory,
              onAccept: !isSent && isPending ? () => _acceptTransaction(t) : null,
              onReject: !isSent && isPending ? () => _rejectTransaction(t) : null,
              onCancel: isSent && isPending ? () => _cancelTransaction(t) : null,
            ),
          );
        },
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _TransactionsHeader extends StatelessWidget {
  final TabController tabController;
  final int pendingSentCount;
  final int pendingReceivedCount;
  final int historyCount;

  const _TransactionsHeader({
    required this.tabController,
    required this.pendingSentCount,
    required this.pendingReceivedCount,
    required this.historyCount,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      color: AppColors.primary,
      child: Column(
        children: [
          SizedBox(height: top + 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Transações',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          TabBar(
            controller: tabController,
            tabs: [
              _TabLabel('Enviadas', pendingSentCount),
              _TabLabel('Recebidas', pendingReceivedCount),
              _TabLabel('Histórico', historyCount),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  final String label;
  final int count;
  const _TabLabel(this.label, this.count);

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Transaction Card ─────────────────────────────────────────────────────────

class _TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final bool isSent;
  final bool isPending;
  final bool isHistory;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;

  const _TransactionCard({
    required this.transaction,
    required this.isSent,
    required this.isPending,
    required this.isHistory,
    this.onAccept,
    this.onReject,
    this.onCancel,
  });

  static Color _typeColor(String type) {
    switch (type) {
      case 'Compra': return AppColors.success;
      case 'Requisição': return AppColors.primary;
      case 'Troca': return AppColors.secondary;
      default: return AppColors.textHint;
    }
  }

  static IconData _typeIcon(String type) {
    switch (type) {
      case 'Compra': return Icons.shopping_cart_outlined;
      case 'Requisição': return Icons.library_books_outlined;
      case 'Troca': return Icons.swap_horiz;
      default: return Icons.receipt_long_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('dd/MM/yy HH:mm');
    final otherUser = isSent ? transaction.receiverName : transaction.senderName;
    final typeColor = _typeColor(transaction.type);

    Color statusColor;
    IconData statusIcon;
    if (transaction.isAccepted) {
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle_outline;
    } else if (transaction.isRejected) {
      statusColor = AppColors.error;
      statusIcon = Icons.cancel_outlined;
    } else {
      statusColor = AppColors.warning;
      statusIcon = Icons.pending_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.divider, width: 0.8),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_typeIcon(transaction.type), color: typeColor, size: 20),
          ),
          title: Text(
            transaction.bookTitle,
            style: AppTextStyles.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            isHistory
                ? '${isSent ? "Para" : "De"} $otherUser · ${transaction.typeDisplay}'
                : '${transaction.typeDisplay} · $otherUser',
            style: AppTextStyles.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(color: statusColor.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusColor, size: 12),
                const SizedBox(width: 4),
                Text(
                  transaction.statusDisplay,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          children: [
            const Divider(),
            const SizedBox(height: 8),
            _DetailRow('Livro', transaction.bookTitle),
            _DetailRow('Autor', transaction.bookAuthor),
            _DetailRow('Tipo', transaction.typeDisplay),
            if (transaction.type == 'Compra' && transaction.price != null)
              _DetailRow('Preço', '€${transaction.price!.toStringAsFixed(2)}'),
            if (transaction.type == 'Troca' && transaction.tradeBookTitle != null)
              _DetailRow('Livro oferecido', transaction.tradeBookTitle!),
            _DetailRow(isSent ? 'Para' : 'De', otherUser),
            _DetailRow('Data', dateFormatter.format(transaction.createdAt)),
            _DetailRow('Estado', transaction.statusDisplay),
            if (transaction.notes.isNotEmpty &&
                !transaction.notes.contains('PRICE:') &&
                !transaction.notes.contains('TRADE_BOOK_ISBN:'))
              _DetailRow('Notas', transaction.notes),
            const SizedBox(height: 12),
            if (onAccept != null && onReject != null)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Aceitar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Rejeitar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            if (onCancel != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Cancelar Transação'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: BorderSide(color: AppColors.warning.withValues(alpha: 0.7)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyTransactions({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.textHint.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
