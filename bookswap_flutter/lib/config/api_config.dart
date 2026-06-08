import '../services/config_storage_service.dart';

/// API configuration constants
///
/// NGROK SETUP:
/// 1. Visit: https://dashboard.ngrok.com/signup (free account)
/// 2. Get your authtoken: https://dashboard.ngrok.com/get-started/your-authtoken
/// 3. Run: ngrok config add-authtoken YOUR_TOKEN
/// 4. Run: ngrok http 5003
/// 5. Copy the HTTPS URL (e.g., https://xxxxx-xx-xxx.eu.ngrok.io)
/// 6. Update NGROK_BASE_URL below with your ngrok URL
class ApiConfig {
  // ==========================================
  // 🌐 NGROK CONFIGURATION
  // ==========================================

  /// Set your ngrok URL here (from `ngrok http 5003`)
  /// Example: 'https://abc123-xx-xxx-xx.eu.ngrok.io'
  /// Leave empty to use localhost
  static const String ngrokUrl =
      'https://generic-purely-bankbook.ngrok-free.dev';

  /// Enable/Disable ngrok (set to true to use ngrok)
  static const bool useNgrok = true;

  // ==========================================
  // 🖥️ LOCALHOST CONFIGURATION
  // ==========================================

  /// Local API server (for development)
  static const String localhostUrl = 'http://10.55.13.150:5003/api';

  // ==========================================
  // 🚀 ACTIVE CONFIGURATION
  // ==========================================

  /// Base URL for the API server
  /// Uses configuration from ConfigStorageService if available,
  /// otherwise falls back to static constants
  static String get baseUrl {
    // Check if configuration has been saved
    if (ConfigStorageService.isServerConfigured) {
      // Use saved configuration
      if (!ConfigStorageService.isLocalhost &&
          ConfigStorageService.ngrokUrl.isNotEmpty) {
        final url = ConfigStorageService.ngrokUrl.endsWith('/')
            ? ConfigStorageService.ngrokUrl.substring(
                0,
                ConfigStorageService.ngrokUrl.length - 1,
              )
            : ConfigStorageService.ngrokUrl;
        return '$url/api';
      }
      // Fall back to localhost if using localhost mode
      return localhostUrl;
    }

    // Use static configuration if nothing saved yet
    if (useNgrok && ngrokUrl.isNotEmpty) {
      final url = ngrokUrl.endsWith('/')
          ? ngrokUrl.substring(0, ngrokUrl.length - 1)
          : ngrokUrl;
      return '$url/api';
    }
    return localhostUrl;
  }

  /// Request timeout in seconds
  static const Duration requestTimeout = Duration(seconds: 30);

  /// API endpoints
  static const String authEndpoint = '/auth';
  static const String booksEndpoint = '/books';
  static const String transactionsEndpoint = '/transactions';
  static const String conversationsEndpoint = '/conversations';

  /// Get full API base URL for debugging
  static String get fullUrl {
    if (ConfigStorageService.isServerConfigured) {
      if (!ConfigStorageService.isLocalhost &&
          ConfigStorageService.ngrokUrl.isNotEmpty) {
        return 'Using NGROK: $baseUrl (${ConfigStorageService.ngrokUrl})';
      }
      return 'Using LOCALHOST: $baseUrl';
    }

    if (useNgrok && ngrokUrl.isNotEmpty) {
      return 'Using NGROK: $baseUrl ($ngrokUrl)';
    }
    return 'Using LOCALHOST: $baseUrl';
  }

  /// Headers for HTTP requests.
  /// Automatically includes X-User-Email when a user is logged in,
  /// which the API uses for server-side admin authorization checks.
  static Map<String, String> getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Add ngrok bypass header when using ngrok
    if (useNgrok ||
        (ConfigStorageService.isServerConfigured &&
            !ConfigStorageService.isLocalhost &&
            ConfigStorageService.ngrokUrl.isNotEmpty)) {
      headers['ngrok-skip-browser-warning'] = 'true';
      headers['User-Agent'] = 'BookSwapApp';
    }

    // Include the current user's email so the API can verify admin status
    if (currentUserEmail.isNotEmpty) {
      headers['X-User-Email'] = currentUserEmail;
    }

    // Include the session token for authenticated requests
    if (currentToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $currentToken';
    }

    return headers;
  }

  /// The email of the currently logged-in user.
  /// Set by AuthProvider on login; cleared on logout.
  static String currentUserEmail = '';

  /// The raw session token. Set after login, cleared on logout.
  static String currentToken = '';
}
