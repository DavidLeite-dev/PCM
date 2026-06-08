import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_client.dart';

class AdminStatisticsScreen extends StatefulWidget {
  const AdminStatisticsScreen({super.key});

  @override
  State<AdminStatisticsScreen> createState() => _AdminStatisticsScreenState();
}

class _AdminStatisticsScreenState extends State<AdminStatisticsScreen> {
  late ApiClient _apiClient;
  Map<String, dynamic> _stats = {};
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _apiClient = context.read<ApiClient>();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await _apiClient.get('/admin/statistics');
      final raw = response is Map && response.containsKey('statistics')
          ? Map<String, dynamic>.from(response['statistics'] as Map)
          : Map<String, dynamic>.from(response as Map);

      setState(() {
        _stats = raw;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar estatísticas: $e';
        _isLoading = false;
      });
    }
  }

  // ─── helpers ───────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _asList(String key) {
    final raw = _stats[key];
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(
      (raw as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  double _completionRate() {
    final v = _stats['completionRate'];
    if (v == null) return 0.0;
    return (v as num).toDouble();
  }

  double _avgResolutionDays() {
    final v = _stats['avgResolutionDays'];
    if (v == null) return 0.0;
    return (v as num).toDouble();
  }

  // ─── pie chart: transaction types ─────────────────────────────────────────

  static const _typeColors = [
    Color(0xFF6C63FF),
    Color(0xFF43C59E),
    Color(0xFFFFA040),
    Color(0xFFE05555),
    Color(0xFF5599FF),
  ];

  Widget _buildTypePieChart() {
    final data = _asList('byType');
    if (data.isEmpty) return const _EmptyChart(label: 'Sem dados de tipo');

    final total = data.fold<int>(0, (s, e) => s + (e['count'] as int));
    final sections = data.asMap().entries.map((entry) {
      final i = entry.key;
      final item = entry.value;
      final count = (item['count'] as int);
      final pct = total > 0 ? count / total * 100 : 0.0;
      return PieChartSectionData(
        value: count.toDouble(),
        title: '${pct.toStringAsFixed(0)}%',
        color: _typeColors[i % _typeColors.length],
        radius: 70,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(icon: Icons.pie_chart, label: 'Transações por Tipo'),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: Row(
            children: [
              Expanded(
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 32,
                    sectionsSpace: 2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: data.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _typeColors[i % _typeColors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${item['type']} (${item['count']})',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── bar chart: monthly activity ──────────────────────────────────────────

  Widget _buildMonthlyBarChart() {
    final data = _asList('monthlyActivity');
    if (data.isEmpty) return const _EmptyChart(label: 'Sem actividade recente');

    final maxY =
        data
            .map((e) => (e['count'] as int).toDouble())
            .fold<double>(0, (a, b) => a > b ? a : b)
            .ceilToDouble() +
        1;

    final bars = data.asMap().entries.map((entry) {
      final i = entry.key;
      final item = entry.value;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: (item['count'] as int).toDouble(),
            color: const Color(0xFF6C63FF),
            width: 18,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          icon: Icons.bar_chart,
          label: 'Actividade Mensal (últimos 6 meses)',
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              barGroups: bars,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4 < 1 ? 1 : maxY / 4,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withValues(alpha: 0.25),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= data.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          data[idx]['label'] as String,
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                    reservedSize: 28,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── completion rate ───────────────────────────────────────────────────────

  Widget _buildCompletionRate() {
    final rate = _completionRate();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          icon: Icons.check_circle_outline,
          label: 'Taxa de Conclusão',
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Transações Confirmadas'),
                    Text(
                      '${rate.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: rate >= 50 ? Colors.green : Colors.orange,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: rate / 100,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      rate >= 50 ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── books by category ─────────────────────────────────────────────────────

  Widget _buildBooksByCategory() {
    final data = _asList('booksByCategory');
    if (data.isEmpty) return const SizedBox.shrink();
    final maxCount = data
        .map((e) => (e['count'] as int).toDouble())
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(icon: Icons.category, label: 'Livros por Categoria'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Column(
              children: data.map((item) {
                final frac = maxCount > 0
                    ? (item['count'] as int) / maxCount
                    : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          '${item['category']}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: frac,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF43C59E),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${item['count']}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ─── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estatísticas do Sistema'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadStatistics,
                    child: const Text('Tentar Novamente'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Summary cards ──────────────────────────────
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.7,
                    children: [
                      _StatCard(
                        title: 'Utilizadores',
                        value: '${_stats['totalUsers'] ?? 0}',
                        icon: Icons.people,
                        color: Colors.blue,
                      ),
                      _StatCard(
                        title: 'Livros',
                        value: '${_stats['totalBooks'] ?? 0}',
                        icon: Icons.library_books,
                        color: Colors.green,
                      ),
                      _StatCard(
                        title: 'Transações',
                        value: '${_stats['totalTransactions'] ?? 0}',
                        icon: Icons.swap_horiz,
                        color: Colors.purple,
                      ),
                      _StatCard(
                        title: 'Dias (Ø resolução)',
                        value: '${_avgResolutionDays().toStringAsFixed(1)}d',
                        icon: Icons.timer,
                        color: Colors.orange,
                      ),
                      _StatCard(
                        title: 'Livros/Utilizador',
                        value: (_stats['avgBooksPerUser'] as num? ?? 0).toStringAsFixed(1),
                        icon: Icons.person_outline,
                        color: Colors.teal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // ── Completion rate ────────────────────────────
                  _buildCompletionRate(),
                  const SizedBox(height: 20),
                  // ── Pie chart ──────────────────────────────────
                  _buildTypePieChart(),
                  const SizedBox(height: 20),
                  // ── Bar chart ──────────────────────────────────
                  _buildMonthlyBarChart(),
                  const SizedBox(height: 20),
                  // ── Books by category ──────────────────────────
                  _buildBooksByCategory(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

// ─── helper widgets ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _EmptyChart extends StatelessWidget {
  final String label;
  const _EmptyChart({required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Center(
        child: Text(label, style: TextStyle(color: Colors.grey.shade500)),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
