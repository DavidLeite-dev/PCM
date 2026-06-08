import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/conversation_summary.dart';
import '../providers/auth_provider.dart';
import '../services/conversation_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen>
    with SingleTickerProviderStateMixin {
  final ConversationService _service = ConversationService();
  late final TabController _tabController;
  Timer? _refreshTimer;

  List<ConversationSummary> _buyingConversations = [];
  List<ConversationSummary> _sellingConversations = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConversations();
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _loadConversations(),
      );
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    final email = context.read<AuthProvider>().currentUser?.email ?? '';
    if (email.isEmpty) return;
    setState(() => _isLoading = true);
    final all = await _service.getConversations(email);
    if (mounted) {
      setState(() {
        _buyingConversations = all.where((c) => c.isInitiator).toList();
        _sellingConversations = all.where((c) => !c.isInitiator).toList();
        _isLoading = false;
      });
    }
  }

  int get _totalBuyingUnread =>
      _buyingConversations.fold(0, (s, c) => s + c.unreadCount);
  int get _totalSellingUnread =>
      _sellingConversations.fold(0, (s, c) => s + c.unreadCount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PaperBackground(
        child: Column(
          children: [
            _ConversationsHeader(
              tabController: _tabController,
              buyingUnread: _totalBuyingUnread,
              sellingUnread: _totalSellingUnread,
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _loadConversations,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _ConversationList(
                            conversations: _buyingConversations,
                            emptyMessage: 'Sem conversas.\nEnvie uma mensagem a partir\ndo catálogo de livros.',
                            emptyIcon: Icons.shopping_bag_outlined,
                            onRefresh: _loadConversations,
                          ),
                          _ConversationList(
                            conversations: _sellingConversations,
                            emptyMessage: 'Sem mensagens recebidas ainda.\nQuando alguém contactar sobre\nos seus livros, aparecerá aqui.',
                            emptyIcon: Icons.storefront_outlined,
                            onRefresh: _loadConversations,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _ConversationsHeader extends StatelessWidget {
  final TabController tabController;
  final int buyingUnread;
  final int sellingUnread;

  const _ConversationsHeader({
    required this.tabController,
    required this.buyingUnread,
    required this.sellingUnread,
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
                  'Mensagens',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (buyingUnread + sellingUnread > 0) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      '${buyingUnread + sellingUnread}',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          TabBar(
            controller: tabController,
            tabs: [
              _UnreadTab(label: 'A Comprar', icon: Icons.shopping_bag_outlined, unread: buyingUnread),
              _UnreadTab(label: 'A Anunciar', icon: Icons.storefront_outlined, unread: sellingUnread),
            ],
          ),
        ],
      ),
    );
  }
}

class _UnreadTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final int unread;

  const _UnreadTab({required this.label, required this.icon, required this.unread});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 5),
          Text(label),
          if (unread > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                '$unread',
                style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Conversation List ────────────────────────────────────────────────────────

class _ConversationList extends StatelessWidget {
  final List<ConversationSummary> conversations;
  final String emptyMessage;
  final IconData emptyIcon;
  final Future<void> Function() onRefresh;

  const _ConversationList({
    required this.conversations,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (conversations.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(emptyIcon, size: 64, color: AppColors.textHint.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(
                      emptyMessage,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: conversations.length,
      itemBuilder: (context, i) => AnimatedListItem(
        index: i,
        child: Column(
          children: [
            _ConversationTile(conversation: conversations[i], onRefresh: onRefresh),
            if (i < conversations.length - 1)
              Divider(height: 1, indent: 82, endIndent: 16, color: AppColors.divider),
          ],
        ),
      ),
    );
  }
}

// ─── Conversation Tile ────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final ConversationSummary conversation;
  final Future<void> Function() onRefresh;

  const _ConversationTile({required this.conversation, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final userEmail = context.read<AuthProvider>().currentUser?.email ?? '';
    final otherName = conversation.otherUserName(userEmail);
    final otherEmail = conversation.otherUserEmail(userEmail);
    final bookTitle = conversation.bookTitle;
    final bookCover = conversation.bookCover ?? '';
    final bookISBN = conversation.bookISBN;
    final lastContent = conversation.lastMessageContent;
    final unread = conversation.unreadCount;
    final hasUnread = unread > 0;

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          AppPageRoute(
            child: ChatScreen(
              conversationId: conversation.id,
              otherUserName: otherName,
              otherUserEmail: otherEmail,
              bookTitle: bookTitle,
              bookISBN: bookISBN,
              bookCover: bookCover,
            ),
          ),
        );
        onRefresh();
      },
      child: Container(
        color: hasUnread ? AppColors.primaryContainer.withValues(alpha: 0.3) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book cover with unread badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: bookCover.isNotEmpty
                      ? Image.network(
                          bookCover,
                          width: 50,
                          height: 68,
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, st) => _bookPlaceholder(),
                        )
                      : _bookPlaceholder(),
                ),
                if (hasUnread)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherName,
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.lastMessageAt != null)
                        Text(
                          _formatTime(conversation.lastMessageAt!),
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
                            color: hasUnread ? AppColors.primary : AppColors.textHint,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    bookTitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (lastContent.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      lastContent,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: hasUnread ? AppColors.textPrimary : AppColors.textHint,
                        fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookPlaceholder() => Container(
    width: 50,
    height: 68,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.surfaceVariant, AppColors.divider],
      ),
      borderRadius: BorderRadius.circular(AppRadius.xs),
    ),
    child: const Icon(Icons.menu_book_outlined, color: AppColors.textHint, size: 22),
  );

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final diff = now.difference(local);
    if (diff.inDays == 0) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'ontem';
    } else if (diff.inDays < 7) {
      const days = ['', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
      return days[local.weekday];
    } else {
      return '${local.day}/${local.month}';
    }
  }
}
