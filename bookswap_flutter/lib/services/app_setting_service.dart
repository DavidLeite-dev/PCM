import 'package:flutter/foundation.dart';
import 'api_client.dart';

class AppSettingService {
  final ApiClient _apiClient;

  AppSettingService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Get a specific setting value
  Future<String> getSetting(String key) async {
    try {
      debugPrint('AppSettingService.getSetting(): Fetching setting: $key');

      final response = await _apiClient.get('/appsettings/$key');

      debugPrint(
        'AppSettingService.getSetting(): Setting value: ${response['value']}',
      );
      return response['value'] ?? '';
    } catch (e) {
      debugPrint('AppSettingService.getSetting(): Failed to fetch setting: $e');
      rethrow;
    }
  }

  /// Get all settings
  Future<Map<String, String>> getAllSettings() async {
    try {
      debugPrint('AppSettingService.getAllSettings(): Fetching all settings');

      final response = await _apiClient.get('/appsettings');

      final settings = <String, String>{};

      // API returns response with 'settings' key containing the array
      if (response.containsKey('settings')) {
        final settingsArray = response['settings'];
        if (settingsArray is List) {
          for (var setting in settingsArray.cast<Map<String, dynamic>>()) {
            settings[setting['key'] ?? ''] = setting['value'] ?? '';
          }
        }
      }

      debugPrint(
        'AppSettingService.getAllSettings(): Got ${settings.length} settings',
      );
      return settings;
    } catch (e) {
      debugPrint(
        'AppSettingService.getAllSettings(): Failed to fetch settings: $e',
      );
      rethrow;
    }
  }

  /// Update a setting value
  Future<bool> updateSetting(String key, String value) async {
    try {
      debugPrint('AppSettingService.updateSetting(): Updating $key = $value');

      final body = {'key': key, 'value': value};

      await _apiClient.post('/appsettings', body: body);

      debugPrint(
        'AppSettingService.updateSetting(): Setting updated successfully',
      );
      return true;
    } catch (e) {
      debugPrint(
        'AppSettingService.updateSetting(): Failed to update setting: $e',
      );
      rethrow;
    }
  }

  /// Toggle a boolean setting
  Future<bool> toggleSetting(String key, bool currentValue) async {
    try {
      final newValue = (!currentValue).toString();
      await updateSetting(key, newValue);
      return !currentValue;
    } catch (e) {
      debugPrint(
        'AppSettingService.toggleSetting(): Failed to toggle setting: $e',
      );
      rethrow;
    }
  }

  /// Get AllowDuplicateBooks setting
  Future<bool> getAllowDuplicateBooks() async {
    try {
      final value = await getSetting('AllowDuplicateBooks');
      return value.toLowerCase() == 'true';
    } catch (e) {
      debugPrint('AppSettingService.getAllowDuplicateBooks(): Failed: $e');
      return false;
    }
  }

  /// Get ShowSingleBookCondition setting
  Future<bool> getShowSingleBookCondition() async {
    try {
      final value = await getSetting('ShowSingleBookCondition');
      return value.toLowerCase() == 'true';
    } catch (e) {
      debugPrint('AppSettingService.getShowSingleBookCondition(): Failed: $e');
      return false;
    }
  }
}
