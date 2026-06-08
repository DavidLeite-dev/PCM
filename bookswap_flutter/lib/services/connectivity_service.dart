import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Service to monitor API connectivity in real-time
class ConnectivityService extends ChangeNotifier {
  bool _isConnected = false;
  bool _isChecking = false;
  String _lastError = '';

  bool get isConnected => _isConnected;
  bool get isChecking => _isChecking;
  String get lastError => _lastError;

  /// Check API connectivity
  Future<bool> checkConnectivity({
    String? customUrl,
  }) async {
    _isChecking = true;
    notifyListeners();

    try {
      final baseUrl = customUrl ?? ApiConfig.baseUrl;

      if (baseUrl.isEmpty) {
        _isConnected = false;
        _lastError = 'URL vazia';
        _isChecking = false;
        notifyListeners();
        return false;
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/swagger/index.html'),
            headers: ApiConfig.getHeaders(),
          )
          .timeout(const Duration(seconds: 5));

      _isConnected = response.statusCode == 200;
      _lastError = _isConnected
          ? 'Conectado'
          : 'Status: ${response.statusCode}';
      
      _isChecking = false;
      notifyListeners();
      return _isConnected;
    } catch (e) {
      _isConnected = false;
      _lastError = e.toString();
      _isChecking = false;
      notifyListeners();
      return false;
    }
  }

  /// Get API status message for UI
  String getStatusMessage() {
    if (_isChecking) return '🔄 Verificando...';
    if (_isConnected) return '✅ API Ativa';
    return '❌ Sem Conexão';
  }
}
