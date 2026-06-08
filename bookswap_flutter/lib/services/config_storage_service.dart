import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Service for managing application configuration persistence
class ConfigStorageService {
  static const String _isServerConfiguredKey = 'is_server_configured';
  static const String _isLocalhostKey = 'is_localhost';
  static const String _ngrokUrlKey = 'ngrok_url';

  static late SharedPreferences _prefs;

  /// Initialize the service - call this in main() before runApp()
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Check if server has been configured
  static bool get isServerConfigured {
    return _prefs.getBool(_isServerConfiguredKey) ?? false;
  }

  /// Check if using localhost
  static bool get isLocalhost {
    return _prefs.getBool(_isLocalhostKey) ?? true;
  }

  /// Get saved ngrok URL
  static String get ngrokUrl {
    return _prefs.getString(_ngrokUrlKey) ?? '';
  }

  /// Save server configuration
  static Future<bool> saveServerConfig({
    required bool isLocalhost,
    required String ngrokUrl,
  }) async {
    try {
      await _prefs.setBool(_isServerConfiguredKey, true);
      await _prefs.setBool(_isLocalhostKey, isLocalhost);
      if (!isLocalhost && ngrokUrl.isNotEmpty) {
        await _prefs.setString(_ngrokUrlKey, ngrokUrl);
      }
      return true;
    } catch (e) {
      debugPrint('ConfigStorageService: Error saving config - $e');
      return false;
    }
  }

  /// Clear server configuration (for testing/resetting)
  static Future<bool> clearServerConfig() async {
    try {
      await _prefs.remove(_isServerConfiguredKey);
      await _prefs.remove(_isLocalhostKey);
      await _prefs.remove(_ngrokUrlKey);
      return true;
    } catch (e) {
      debugPrint('ConfigStorageService: Error clearing config - $e');
      return false;
    }
  }

  /// Get current configuration summary
  static String getConfigSummary() {
    if (!isServerConfigured) {
      return 'Server not configured';
    }
    if (isLocalhost) {
      return 'Using localhost (Local Network)';
    }
    return 'Using ngrok: $ngrokUrl';
  }
}
