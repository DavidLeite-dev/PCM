import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'book_catalog_screen.dart';
import 'my_books_screen.dart';
import 'transactions_screen.dart';
import 'conversations_screen.dart';
import 'profile_screen.dart';
import 'admin_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _navAnimController;

  @override
  void initState() {
    super.initState();
    _navAnimController = AnimationController(
      vsync: this,
      duration: AppDurations.fast,
    );
    _navAnimController.forward();
  }

  @override
  void dispose() {
    _navAnimController.dispose();
    super.dispose();
  }

  void _onTabTap(int index, int maxIndex) {
    if (index < 0 || index >= maxIndex || index == _selectedIndex) return;
    setState(() => _selectedIndex = index.clamp(0, maxIndex - 1));
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.currentUser == null) {
      return const LoginScreen();
    }

    final isAdmin = authProvider.isAdmin();

    final screens = [
      const BookCatalogScreen(),
      const MyBooksScreen(),
      const TransactionsScreen(),
      const ConversationsScreen(),
      const ProfileScreen(),
      if (isAdmin) const AdminScreen(),
    ];

    if (_selectedIndex >= screens.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      body: AnimatedSwitcher(
        duration: AppDurations.normal,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_selectedIndex),
          child: screens[_selectedIndex],
        ),
      ),
      bottomNavigationBar: _BookSwapNavBar(
        selectedIndex: _selectedIndex,
        isAdmin: isAdmin,
        onTap: (i) => _onTabTap(i, screens.length),
      ),
    );
  }
}

// ─── Custom Bottom Nav ────────────────────────────────────────────────────────

class _BookSwapNavBar extends StatelessWidget {
  final int selectedIndex;
  final bool isAdmin;
  final void Function(int) onTap;

  const _BookSwapNavBar({
    required this.selectedIndex,
    required this.isAdmin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(icon: Icons.library_books_outlined, activeIcon: Icons.library_books, label: 'Catálogo'),
      _NavItem(icon: Icons.bookmarks_outlined, activeIcon: Icons.bookmarks, label: 'Meus Livros'),
      _NavItem(icon: Icons.swap_horiz_outlined, activeIcon: Icons.swap_horiz, label: 'Transações'),
      _NavItem(icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, label: 'Mensagens'),
      _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Perfil'),
      if (isAdmin)
        _NavItem(icon: Icons.admin_panel_settings_outlined, activeIcon: Icons.admin_panel_settings, label: 'Admin'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              return _NavBarItem(
                item: items[i],
                isSelected: selectedIndex == i,
                onTap: () => onTap(i),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _NavBarItem extends StatefulWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _indicatorWidth;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.fast,
    );
    _scale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _indicatorWidth = Tween<double>(begin: 0, end: 24).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    if (widget.isSelected) _controller.forward();
  }

  @override
  void didUpdateWidget(_NavBarItem old) {
    super.didUpdateWidget(old);
    if (widget.isSelected != old.isSelected) {
      if (widget.isSelected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Icon(
                widget.isSelected ? widget.item.activeIcon : widget.item.icon,
                color: widget.isSelected
                    ? AppColors.secondaryLight
                    : AppColors.onPrimary.withValues(alpha: 0.45),
                size: 24,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              widget.item.label,
              style: GoogleFonts.nunito(
                fontSize: 10,
                fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w400,
                color: widget.isSelected
                    ? AppColors.secondaryLight
                    : AppColors.onPrimary.withValues(alpha: 0.45),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            AnimatedBuilder(
              animation: _indicatorWidth,
              builder: (context, child) => Container(
                height: 2.5,
                width: _indicatorWidth.value,
                decoration: BoxDecoration(
                  color: AppColors.secondaryLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
