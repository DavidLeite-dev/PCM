import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../providers/auth_provider.dart';
import '../services/conversation_service.dart';
import '../services/transaction_service.dart';

class ChatScreen extends StatefulWidget {
  final int conversationId;
  final String otherUserName;
  final String otherUserEmail;
  final String bookTitle;
  final String bookISBN;
  final String bookCover;

  // Optional linked transaction state (refreshed on each open)
  final int? transactionId;
  final String? transactionType;
  final String? transactionStatus;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    required this.otherUserEmail,
    required this.bookTitle,
    required this.bookISBN,
    required this.bookCover,
    this.transactionId,
    this.transactionType,
    this.transactionStatus,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final ConversationService _conversationService = ConversationService();
  final TransactionService _transactionService = TransactionService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  int? _lastMessageId;
  bool _isSending = false;
  bool _isLoadingInitial = true;
  bool _connectionError = false;
  int _consecutiveErrors = 0;
  Timer? _pollTimer;

  String get _userEmail =>
      context.read<AuthProvider>().currentUser?.email ?? '';

  // Local transaction state (may update after proposing from chat)
  int? _transactionId;
  String? _transactionType;
  String? _transactionStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _transactionId = widget.transactionId;
    _transactionType = widget.transactionType;
    _transactionStatus = widget.transactionStatus;
    _loadInitialMessages();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
    } else {
      _pollTimer?.cancel();
    }
  }

  Future<void> _loadInitialMessages() async {
    setState(() => _isLoadingInitial = true);
    final msgs = await _conversationService.getMessages(
      widget.conversationId,
      _userEmail,
    );
    if (mounted) {
      setState(() {
        _messages = msgs;
        _lastMessageId = msgs.isNotEmpty ? msgs.last.id : null;
        _isLoadingInitial = false;
        _consecutiveErrors = 0;
        _connectionError = false;
      });
      _scrollToBottom();
      _startPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollNewMessages(),
    );
  }

  Future<void> _pollNewMessages() async {
    if (!mounted) return;
    try {
      final newMsgs = await _conversationService.getMessages(
        widget.conversationId,
        _userEmail,
        afterId: _lastMessageId,
      );
      if (!mounted) return;
      if (_consecutiveErrors > 0 || _connectionError) {
        setState(() {
          _consecutiveErrors = 0;
          _connectionError = false;
        });
      }
      if (newMsgs.isEmpty) return;
      setState(() {
        _messages.addAll(newMsgs);
        _lastMessageId = newMsgs.last.id;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      _consecutiveErrors++;
      if (_consecutiveErrors >= 3) {
        setState(() => _connectionError = true);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    final success = await _conversationService.sendMessage(
      conversationId: widget.conversationId,
      senderEmail: _userEmail,
      content: text,
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (success) {
      // Immediately poll to get the sent message back with its server ID
      await _pollNewMessages();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao enviar mensagem'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _scrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animated) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
  }

  // ── Transaction proposal from within chat ─────────────────────
  void _showProposeMenu() {
    if (_transactionId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Já existe uma transação (${_transactionType ?? ""}) ligada a esta conversa.',
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'O que pretende propor?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.shopping_bag, color: Colors.green),
              title: const Text('Comprar'),
              onTap: () {
                Navigator.pop(ctx);
                _proposeCompra();
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: Colors.purple),
              title: const Text('Trocar'),
              onTap: () {
                Navigator.pop(ctx);
                _proposeTroca();
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark, color: Colors.blue),
              title: const Text('Requisitar'),
              onTap: () {
                Navigator.pop(ctx);
                _proposeRequisicao();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _proposeCompra() async {
    final priceController = TextEditingController();
    String? errorMessage;

    final price = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Propor Compra'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Livro: ${widget.bookTitle}'),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Preço proposto (€)',
                  prefixText: '€ ',
                  errorText: errorMessage,
                ),
                onChanged: (_) {
                  if (errorMessage != null) {
                    setDialogState(() => errorMessage = null);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                final v = double.tryParse(priceController.text);
                if (v != null && v > 0) {
                  Navigator.pop(ctx, v);
                } else {
                  setDialogState(() => errorMessage = 'Preço inválido');
                }
              },
              child: const Text('Propor'),
            ),
          ],
        ),
      ),
    );

    priceController.dispose();
    if (price == null || !mounted) return;

    final txId = await _transactionService.createPurchaseTransaction(
      senderEmail: _userEmail,
      receiverEmail: widget.otherUserEmail,
      bookISBN: widget.bookISBN,
      price: price,
      notes: 'Proposta de compra: €${price.toStringAsFixed(2)}',
    );

    if (!mounted) return;

    if (txId != null) {
      await _conversationService.linkTransaction(
        conversationId: widget.conversationId,
        transactionId: txId,
      );
      setState(() {
        _transactionId = txId;
        _transactionType = 'Compra';
        _transactionStatus = 'Pendente';
      });
      // Poll immediately to show the auto-message from API
      await _pollNewMessages();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao criar proposta de compra'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _proposeRequisicao() async {
    final txId = await _transactionService.createBorrowTransaction(
      senderEmail: _userEmail,
      receiverEmail: widget.otherUserEmail,
      bookISBN: widget.bookISBN,
      notes: 'Pedido de requisição via chat',
    );

    if (!mounted) return;

    if (txId != null) {
      await _conversationService.linkTransaction(
        conversationId: widget.conversationId,
        transactionId: txId,
      );
      setState(() {
        _transactionId = txId;
        _transactionType = 'Requisição';
        _transactionStatus = 'Pendente';
      });
      await _pollNewMessages();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao criar pedido de requisição'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _proposeTroca() async {
    // Simplified: ask for book ISBN via text field
    final isbnController = TextEditingController();
    await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Propor Troca'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Livro do outro utilizador: ${widget.bookTitle}'),
            const SizedBox(height: 12),
            const Text(
              'Para propor uma troca, aceda ao detalhe do livro no catálogo e use "Propor Troca".',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    isbnController.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            // Book cover thumbnail
            if (widget.bookCover.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    widget.bookCover,
                    width: 36,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.book, size: 36),
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.bookTitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey[300]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Propose transaction button
          if (_transactionId == null)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Propor transação',
              onPressed: _showProposeMenu,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Connection error indicator ─────────────────────────
          if (_connectionError)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Colors.orange.shade100,
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Sem ligação ao servidor. A tentar reconectar...',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadInitialMessages,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Reconectar',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          // ── Transaction status banner ──────────────────────────
          if (_transactionId != null) _buildTransactionBanner(),

          // ── Messages list ──────────────────────────────────────
          Expanded(
            child: _isLoadingInitial
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sem mensagens ainda.\nDiga olá a ${widget.otherUserName}!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) =>
                        _buildMessageBubble(_messages[i]),
                  ),
          ),

          // ── Input bar ─────────────────────────────────────────
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildTransactionBanner() {
    Color bannerColor;
    IconData bannerIcon;

    switch (_transactionStatus) {
      case 'Aceita':
        bannerColor = Colors.green;
        bannerIcon = Icons.check_circle;
        break;
      case 'Confirmada':
        bannerColor = Colors.teal;
        bannerIcon = Icons.done_all;
        break;
      case 'Rejeitada':
      case 'Cancelada':
        bannerColor = Colors.red;
        bannerIcon = Icons.cancel;
        break;
      default: // Pendente
        bannerColor = Colors.orange;
        bannerIcon = Icons.hourglass_top;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: bannerColor.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(bannerIcon, size: 18, color: bannerColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_transactionType ?? "Transação"} · ${_transactionStatus ?? "Pendente"}',
              style: TextStyle(
                color: bannerColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isMine = msg.senderEmail == _userEmail;
    final content = msg.content;
    final senderName = msg.senderName;
    final sentAt = msg.sentAt.toLocal();

    final isSystemMessage =
        content.startsWith('💰') ||
        content.startsWith('📚') ||
        content.startsWith('🔄');

    if (isSystemMessage) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              content,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.blue.shade100,
              child: Text(
                senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMine ? Colors.blue[600] : Colors.grey[100],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content,
                    style: TextStyle(
                      color: isMine ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${sentAt.hour.toString().padLeft(2, '0')}:${sentAt.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: isMine ? Colors.white70 : Colors.grey[500],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMine) const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Escreva uma mensagem...',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 6),
            CircleAvatar(
              backgroundColor: Colors.blue[600],
              child: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: _sendMessage,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
