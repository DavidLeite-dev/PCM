import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Palette ─────────────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF8B1A2F);
  static const Color primaryDark = Color(0xFF5C0A1A);
  static const Color primaryLight = Color(0xFFB5344E);
  static const Color primaryContainer = Color(0xFFF7CDD5);
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color secondary = Color(0xFFC8941A);
  static const Color secondaryLight = Color(0xFFDEAA2A);
  static const Color secondaryContainer = Color(0xFFFAEDD0);
  static const Color onSecondary = Color(0xFFFFFFFF);

  // Backgrounds
  static const Color background = Color(0xFFFAF7F0);
  static const Color surface = Color(0xFFFFF9EE);
  static const Color surfaceVariant = Color(0xFFF5EDD9);
  static const Color cardBg = Color(0xFFFEFBF3);

  // Text
  static const Color textPrimary = Color(0xFF1C0A05);
  static const Color textSecondary = Color(0xFF6B5045);
  static const Color textHint = Color(0xFF9E8070);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textOnDarkMuted = Color(0xFFE8D4B8);

  // Semantic
  static const Color success = Color(0xFF2D7A4F);
  static const Color successContainer = Color(0xFFCCEFDC);
  static const Color error = Color(0xFFC62828);
  static const Color errorContainer = Color(0xFFFFD6D6);
  static const Color warning = Color(0xFFF57C00);
  static const Color warningContainer = Color(0xFFFFF3CC);
  static const Color info = Color(0xFF1565C0);
  static const Color infoContainer = Color(0xFFD1E4FF);

  // Borders / Dividers
  static const Color divider = Color(0xFFE8DCC8);
  static const Color border = Color(0xFFD4C5A9);
  static const Color borderFocus = Color(0xFFB5344E);

  // Auth-screen gradient stops
  static const Color authGradientTop = Color(0xFF1A0508);
  static const Color authGradientMid = Color(0xFF4A1020);
  static const Color authGradientBottom = Color(0xFF8B1A2F);
}

// ─── Gradients ────────────────────────────────────────────────────────────────

class AppGradients {
  AppGradients._();

  static const LinearGradient auth = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.authGradientTop, AppColors.authGradientMid, AppColors.authGradientBottom],
    stops: [0.0, 0.45, 1.0],
  );

  static const LinearGradient primaryHorizontal = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.primaryDark, AppColors.primary],
  );

  static const LinearGradient warmCream = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5F1E8), Color(0xFFECE5D3), Color(0xFFF5F1E8)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient goldShimmer = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.secondary, AppColors.secondaryLight, AppColors.secondary],
  );
}

// ─── Radii ────────────────────────────────────────────────────────────────────

class AppRadius {
  AppRadius._();
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double full = 999;
}

// ─── Shadows ─────────────────────────────────────────────────────────────────

class AppShadows {
  AppShadows._();

  static List<BoxShadow> get card => [
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: 0.07),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: AppColors.secondary.withValues(alpha: 0.04),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get cardElevated => [
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: AppColors.secondary.withValues(alpha: 0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get button => [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.4),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get goldButton => [
    BoxShadow(
      color: AppColors.secondary.withValues(alpha: 0.45),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}

// ─── Animations ──────────────────────────────────────────────────────────────

class AppDurations {
  AppDurations._();
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration verySlow = Duration(milliseconds: 750);
}

// ─── Text Styles ─────────────────────────────────────────────────────────────

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get displayLarge => GoogleFonts.playfairDisplay(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle get displayMedium => GoogleFonts.playfairDisplay(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle get headlineLarge => GoogleFonts.playfairDisplay(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle get headlineMedium => GoogleFonts.playfairDisplay(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get titleLarge => GoogleFonts.nunito(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 0.1,
  );

  static TextStyle get titleMedium => GoogleFonts.nunito(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyLarge => GoogleFonts.nunito(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.6,
  );

  static TextStyle get bodyMedium => GoogleFonts.nunito(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static TextStyle get bodySmall => GoogleFonts.nunito(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textHint,
  );

  static TextStyle get labelLarge => GoogleFonts.nunito(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  static TextStyle get labelSmall => GoogleFonts.nunito(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    color: AppColors.textHint,
  );

  static TextStyle get bookTitle => GoogleFonts.playfairDisplay(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static TextStyle get bookAuthor => GoogleFonts.nunito(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
}

// ─── Decorations ─────────────────────────────────────────────────────────────

class AppDecorations {
  AppDecorations._();

  static BoxDecoration get card => BoxDecoration(
    color: AppColors.cardBg,
    borderRadius: BorderRadius.circular(AppRadius.md),
    boxShadow: AppShadows.card,
    border: Border.all(color: AppColors.divider, width: 0.8),
  );

  static BoxDecoration get authCard => BoxDecoration(
    color: const Color(0xFF3D1220).withValues(alpha: 0.92),
    borderRadius: BorderRadius.circular(AppRadius.xl),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.35),
        blurRadius: 32,
        offset: const Offset(0, 16),
      ),
    ],
    border: Border.all(
      color: AppColors.secondary.withValues(alpha: 0.25),
      width: 1,
    ),
  );

  static InputDecoration authInputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) => InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.nunito(
      color: AppColors.textOnDarkMuted,
      fontWeight: FontWeight.w500,
    ),
    prefixIcon: Icon(icon, color: AppColors.textOnDarkMuted, size: 20),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.07),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.secondaryLight, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: Color(0xFFFF8A80)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: Color(0xFFFF8A80), width: 2),
    ),
    errorStyle: GoogleFonts.nunito(color: const Color(0xFFFF8A80), fontSize: 12),
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
  );

  static InputDecoration lightInputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
    String? hint,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: GoogleFonts.nunito(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w500,
    ),
    hintStyle: GoogleFonts.nunito(color: AppColors.textHint),
    prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.error, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
  );
}

// ─── Page Route ──────────────────────────────────────────────────────────────

class AppPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  AppPageRoute({required this.child, super.settings})
      : super(
          pageBuilder: (ctx, a1, a2) => child,
          transitionDuration: AppDurations.normal,
          reverseTransitionDuration: AppDurations.fast,
          transitionsBuilder: (context, animation, secondary, page) {
            final fadeIn = CurvedAnimation(parent: animation, curve: Curves.easeOut);
            final fadeOut = CurvedAnimation(parent: secondary, curve: Curves.easeIn);
            final slide = Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

            return FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(fadeIn),
              child: FadeTransition(
                opacity: Tween<double>(begin: 1.0, end: 0.0).animate(fadeOut),
                child: SlideTransition(position: slide, child: page),
              ),
            );
          },
        );
}

// ─── ThemeData ────────────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.primaryDark,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.textPrimary,
        tertiary: AppColors.success,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.successContainer,
        onTertiaryContainer: AppColors.textPrimary,
        error: AppColors.error,
        onError: Colors.white,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.textPrimary,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.border,
        outlineVariant: AppColors.divider,
        shadow: AppColors.textPrimary.withValues(alpha: 0.1),
        scrim: Colors.black.withValues(alpha: 0.5),
        inverseSurface: AppColors.textPrimary,
        onInverseSurface: AppColors.background,
        inversePrimary: AppColors.primaryLight,
        surfaceTint: AppColors.primary.withValues(alpha: 0.05),
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      cardColor: AppColors.cardBg,
      dividerColor: AppColors.divider,

      textTheme: GoogleFonts.nunitoTextTheme(base.textTheme).copyWith(
        displayLarge: AppTextStyles.displayLarge,
        displayMedium: AppTextStyles.displayMedium,
        headlineLarge: AppTextStyles.headlineLarge,
        headlineMedium: AppTextStyles.headlineMedium,
        headlineSmall: GoogleFonts.playfairDisplay(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleLarge: AppTextStyles.titleLarge,
        titleMedium: AppTextStyles.titleMedium,
        titleSmall: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.labelLarge,
        labelMedium: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        labelSmall: AppTextStyles.labelSmall,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.onPrimary,
          letterSpacing: 0.2,
        ),
        iconTheme: const IconThemeData(color: AppColors.onPrimary),
        actionsIconTheme: const IconThemeData(color: AppColors.onPrimary),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.primaryDark,
        selectedItemColor: AppColors.secondaryLight,
        unselectedItemColor: AppColors.onPrimary.withValues(alpha: 0.5),
        selectedLabelStyle: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
        elevation: 16,
        type: BottomNavigationBarType.fixed,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.secondary,
        unselectedLabelColor: AppColors.onPrimary.withValues(alpha: 0.6),
        indicatorColor: AppColors.secondary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w500),
        dividerColor: Colors.transparent,
      ),

      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.divider, width: 0.8),
        ),
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
        clipBehavior: Clip.antiAlias,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: AppTextStyles.labelLarge.copyWith(
            color: AppColors.onPrimary,
            fontSize: 15,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 6,
        shape: CircleBorder(),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        labelStyle: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
        side: const BorderSide(color: AppColors.border, width: 0.8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: GoogleFonts.nunito(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: GoogleFonts.nunito(color: AppColors.textHint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: AppTextStyles.headlineMedium,
        contentTextStyle: AppTextStyles.bodyMedium,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: GoogleFonts.nunito(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(16),
      ),

      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: AppColors.textSecondary,
        titleTextStyle: AppTextStyles.titleMedium,
        subtitleTextStyle: AppTextStyles.bodySmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 0.8,
        space: 0,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
    );
  }
}

// ─── Paper Texture Background ─────────────────────────────────────────────────

class _PaperTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(3141);
    final linePaint = Paint()
      ..strokeWidth = 0.35
      ..isAntiAlias = false;
    final dotPaint = Paint()..style = PaintingStyle.fill;

    // Faint horizontal micro-fibers (paper grain direction)
    for (double y = 1.5; y < size.height; y += 2.8) {
      if (rng.nextDouble() > 0.48) continue;
      linePaint.color = const Color(0xFF7A5C2E).withValues(alpha: rng.nextDouble() * 0.055 + 0.015);
      final x0 = rng.nextDouble() * size.width * 0.25;
      final x1 = size.width * (0.55 + rng.nextDouble() * 0.45);
      canvas.drawLine(
        Offset(x0, y),
        Offset(x1, y + (rng.nextDouble() - 0.5) * 0.6),
        linePaint,
      );
    }

    // Fine grain specks
    for (int i = 0; i < 500; i++) {
      dotPaint.color = const Color(0xFF5C3A1E)
          .withValues(alpha: rng.nextDouble() * 0.09 + 0.01);
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        rng.nextDouble() * 0.65 + 0.15,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class PaperBackground extends StatelessWidget {
  final Widget child;
  const PaperBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.warmCream),
      child: CustomPaint(
        painter: _PaperTexturePainter(),
        child: child,
      ),
    );
  }
}

// ─── Reusable Widgets ─────────────────────────────────────────────────────────

class WarmScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool useGradient;

  const WarmScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.useGradient = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: useGradient ? PaperBackground(child: body) : body,
    );
  }
}

class _AnimatedListItem extends StatefulWidget {
  final Widget child;
  final int index;

  const _AnimatedListItem({
    required this.child,
    required this.index,
  });

  @override
  State<_AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<_AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.slow,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    final delay = Duration(milliseconds: widget.index * 55);
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class AnimatedListItem extends StatelessWidget {
  final Widget child;
  final int index;

  const AnimatedListItem({super.key, required this.child, required this.index});

  @override
  Widget build(BuildContext context) {
    return _AnimatedListItem(index: index, child: child);
  }
}

// ─── Condition Badge ─────────────────────────────────────────────────────────

class ConditionBadge extends StatelessWidget {
  final String condition;
  const ConditionBadge({super.key, required this.condition});

  static Color colorFor(String c) {
    switch (c.toLowerCase()) {
      case 'novo': return AppColors.success;
      case 'semi-novo': return AppColors.secondary;
      case 'bom': return AppColors.secondary;
      case 'usado': return AppColors.warning;
      default: return AppColors.textHint;
    }
  }

  static String labelFor(String c) {
    switch (c.toLowerCase()) {
      case 'novo': return 'Novo';
      case 'semi-novo': return 'Semi-Novo';
      case 'bom': return 'Bom';
      case 'usado': return 'Usado';
      default: return c;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(condition);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        labelFor(condition),
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
