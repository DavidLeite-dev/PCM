import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/book_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/server_config_screen.dart';
import 'screens/connectivity_error_screen.dart';
import 'screens/add_book_isbn_screen.dart';
import 'services/api_config_service.dart';
import 'services/connectivity_service.dart';
import 'services/health_check_service.dart';
import 'services/config_storage_service.dart';
import 'services/api_client.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('Main: Starting app initialization...');

  try {
    await ConfigStorageService.initialize();
    ApiConfigService.initializeAndLog();
    debugPrint('Main: App initialization complete');
    runApp(const MyApp());
  } catch (e, stackTrace) {
    debugPrint('Main: Initialization error: $e');
    debugPrint('Main: Stack trace: $stackTrace');
    runApp(const MyApp());
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  HealthCheckResult? _connectivityResult;
  bool _connectivityChecked = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    debugPrint('🔍 Performing health check at app startup...');
    final result = await HealthCheckService().checkStartupConnectivity();

    if (mounted) {
      setState(() {
        _connectivityResult = result;
        _connectivityChecked = true;
      });

      if (!result.success) {
        debugPrint('❌ Health check failed: ${result.status}');
      } else {
        debugPrint('✅ Health check passed');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => ApiClient()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BookProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
      ],
      child: MaterialApp(
        title: 'BookSwap',
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: _buildHome(),
        routes: {'/add-book-isbn': (context) => const AddBookISBNScreen()},
        builder: (context, child) {
          return ScrollConfiguration(
            behavior: _SmoothScrollBehavior(),
            child: child!,
          );
        },
      ),
    );
  }

  Widget _buildHome() {
    if (!_connectivityChecked) {
      return const _SplashScreen();
    }

    if (!_connectivityResult!.success) {
      return ConnectivityErrorScreen(
        healthCheckResult: _connectivityResult!,
        onRetry: () {
          setState(() {
            _connectivityChecked = false;
          });
          _checkConnectivity();
        },
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (!authProvider.initialized) {
          return const _SplashScreen();
        }

        if (!ConfigStorageService.isServerConfigured) {
          return const ServerConfigScreen();
        }

        return authProvider.isLoggedIn
            ? const HomeScreen()
            : const LoginScreen();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.authGradientTop,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.auth),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo_bookswap.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context2, e, st) => const Icon(
                      Icons.import_contacts,
                      color: AppColors.secondaryLight,
                      size: 40,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'BookSwap',
                style: AppTextStyles.displayMedium.copyWith(
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.secondaryLight.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmoothScrollBehavior extends ScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
