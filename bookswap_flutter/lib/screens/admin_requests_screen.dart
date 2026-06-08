import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ApiClient _apiClient;

  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _completed = [];
  bool _isLoadingPending = false;
  bool _isLoadingCompleted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _apiClient = context.read<ApiClient>();
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadPending(), _loadCompleted()]);
  }

  Future<void> _loadPending() async {
    setState(() => _isLoadingPending = true);
    try {
      final response = await _apiClient.get('/admin/transactions?status=pending');
      final list = _extractList(response);
      if (mounted) setState(() { _pending = list; _isLoadingPending = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Erro: $e'; _isLoadingPending = false; });
    }
  }

  Future<void> _loadCompleted() async {
    setState(() => _isLoadingCompleted = true);
    try {
      final response = await _apiClient.get('/admin/transactions?status=completed');
      final list = _extractList(response);
      if (mounted) setState(() { _completed = list; _isLoadingCompleted = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Erro: $e'; _isLoadingCompleted = false; });
    }
  }

  List<Map<String, dynamic>> _extractList(dynamic response) {
    if (response is Map && response['transactions'] is List) {
      return List<Map<String, dynamic>>.from(
        (response['transactions'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
    }
    return [];
  }

  Future<void> _doAction(int id, String action) async {
    try {
      await _apiClient.post(
        '/admin/transactions/$id/action',
        body: {'action': action},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ação "$action" executada'), backgroundColor: Colors.green),
        );
        await _loadAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmAction(int id, String action, String label) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirmar $label'),
        content: Text('Deseja $label esta transação?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _doAction(id, action); },
            child: Text(label),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerir Transações'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.pending_actions),
              text: 'Pendentes (${_pending.length})',
            ),
            Tab(
              icon: const Icon(Icons.check_circle_outline),
              text: 'Concluídas (${_completed.length})',
            ),
          ],
        ),
      ),
      body: _error != null && _pending.isEmpty && _completed.isEmpty
          ? _buildError()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPendingTab(),
                _buildCompletedTab(),
              ],
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadAll, child: const Text('Tentar Novamente')),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    if (_isLoadingPending) return const Center(child: CircularProgressIndicator());
    if (_pending.isEmpty) return const Center(child: Text('Sem transações pendentes'));
    return RefreshIndicator(
      onRefresh: _loadPending,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _pending.length,
        itemBuilder: (ctx, i) => _buildPendingCard(_pending[i]),
      ),
    );
  }

  Widget _buildCompletedTab() {
    if (_isLoadingCompleted) return const Center(child: CircularProgressIndicator());
    if (_completed.isEmpty) return const Center(child: Text('Sem transações concluídas'));
    return RefreshIndicator(
      onRefresh: _loadCompleted,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _completed.length,
        itemBuilder: (ctx, i) => _buildTransactionCard(_completed[i], showActions: false),
      ),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> t) {
    return _buildTransactionCard(t, showActions: true);
  }

  Widget _buildTransactionCard(Map<String, dynamic> t, {required bool showActions}) {
    final id = t['id'] as int? ?? 0;
    final type = t['type'] as String? ?? '';
    final status = t['status'] as String? ?? '';
    final sender = t['sender'] as Map? ?? {};
    final receiver = t['receiver'] as Map? ?? {};
    final senderName = sender['name'] as String? ?? sender['email'] as String? ?? '?';
    final receiverName = receiver['name'] as String? ?? receiver['email'] as String? ?? '?';
    final createdAt = t['createdAt'] as String? ?? '';
    final bookTitle = t['bookTitle'] as String?;
    final tradeBookTitle = t['tradeBookTitle'] as String?;

    Color statusColor;
    switch (status) {
      case 'Pendente': statusColor = Colors.orange; break;
      case 'Confirmada': statusColor = Colors.green; break;
      case 'Rejeitada': statusColor = Colors.red; break;
      case 'Cancelada': statusColor = Colors.grey; break;
      default: statusColor = Colors.blue;
    }

    String typeIcon;
    switch (type) {
      case 'Compra': typeIcon = '💰'; break;
      case 'Troca': typeIcon = '🔄'; break;
      case 'Requisição': typeIcon = '📖'; break;
      default: typeIcon = '📦';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('$typeIcon $type', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    border: Border.all(color: statusColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (bookTitle != null)
              Text('Livro: $bookTitle', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            if (tradeBookTitle != null)
              Text('Troca com: $tradeBookTitle', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            Text('De: $senderName', style: const TextStyle(fontSize: 13)),
            Text('Para: $receiverName', style: const TextStyle(fontSize: 13)),
            if (t['price'] != null)
              Text('Preço: €${t['price']}', style: const TextStyle(fontSize: 13)),
            if (createdAt.isNotEmpty)
              Text(
                'Em: ${_formatDate(createdAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            if (showActions) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.cancel, color: Colors.grey),
                    label: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                    onPressed: () => _confirmAction(id, 'cancel', 'Cancelar'),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Recusar', style: TextStyle(color: Colors.red)),
                    onPressed: () => _confirmAction(id, 'deny', 'Recusar'),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Aceitar'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    onPressed: () => _confirmAction(id, 'accept', 'Aceitar'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) {
      return iso;
    }
  }
}
