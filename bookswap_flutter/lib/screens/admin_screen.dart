import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'admin_users_screen.dart';
import 'admin_books_screen.dart';
import 'admin_statistics_screen.dart';
import 'system_configuration_screen.dart';
import 'admin_requests_screen.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      _AdminItem(
        title: 'Utilizadores',
        subtitle: 'Gerir utilizadores do sistema',
        icon: Icons.people_outline,
        accentColor: AppColors.primary,
        index: 0,
      ),
      _AdminItem(
        title: 'Livros',
        subtitle: 'Ver todos os livros registados',
        icon: Icons.library_books_outlined,
        accentColor: AppColors.secondary,
        index: 1,
      ),
      _AdminItem(
        title: 'Transações',
        subtitle: 'Rever todas as transações',
        icon: Icons.receipt_long_outlined,
        accentColor: AppColors.success,
        index: 2,
      ),
      _AdminItem(
        title: 'Estatísticas',
        subtitle: 'Métricas e gráficos do sistema',
        icon: Icons.bar_chart_rounded,
        accentColor: Color(0xFF6A3DE8),
        index: 3,
      ),
      _AdminItem(
        title: 'Configuração',
        subtitle: 'Gerir configurações globais',
        icon: Icons.settings_outlined,
        accentColor: AppColors.textSecondary,
        index: 4,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PaperBackground(
        child: Column(
          children: [
            _AdminHeader(),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: items.length,
                itemBuilder: (context, i) => AnimatedListItem(
                  index: i,
                  child: _AdminCard(
                    item: items[i],
                    onTap: () => _navigate(context, items[i].index),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigate(BuildContext context, int index) {
    final destinations = [
      const AdminUsersScreen(),
      const AdminBooksScreen(),
      const AdminRequestsScreen(),
      const AdminStatisticsScreen(),
      const SystemConfigurationScreen(),
    ];
    Navigator.of(context).push(AppPageRoute(child: destinations[index]));
  }
}

class _AdminItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final int index;

  const _AdminItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.index,
  });
}

class _AdminHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      color: AppColors.primary,
      padding: EdgeInsets.fromLTRB(16, top + 10, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: AppColors.secondaryLight,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Administração',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Gerencie o sistema BookSwap',
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: AppColors.textOnDarkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends StatefulWidget {
  final _AdminItem item;
  final VoidCallback onTap;

  const _AdminCard({required this.item, required this.onTap});

  @override
  State<_AdminCard> createState() => _AdminCardState();
}

class _AdminCardState extends State<_AdminCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: AppDurations.fast,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.card,
            border: Border.all(color: AppColors.divider, width: 0.8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: item.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: item.accentColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(item.icon, color: item.accentColor, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: AppTextStyles.titleLarge),
                      const SizedBox(height: 3),
                      Text(item.subtitle, style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: item.accentColor.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: item.accentColor,
                    size: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
