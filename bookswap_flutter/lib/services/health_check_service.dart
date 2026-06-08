import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class HealthCheckService {
  static final HealthCheckService _instance = HealthCheckService._internal();

  factory HealthCheckService() {
    return _instance;
  }

  HealthCheckService._internal();

  /// Check both API and database connectivity at startup
  /// Returns a detailed status with specific error information
  Future<HealthCheckResult> checkStartupConnectivity() async {
    try {
      debugPrint('🔍 Starting connectivity check...');
      debugPrint('📍 API URL: ${ApiConfig.baseUrl}');

      // First, check if API is reachable (ping)
      debugPrint('📡 Checking API responsiveness...');
      final pingResult = await _checkPing();
      if (!pingResult.success) {
        return HealthCheckResult(
          success: false,
          status: 'API_UNREACHABLE',
          message: 'Cannot reach the API server. The server may be offline.',
          details:
              'No response from ${ApiConfig.baseUrl}/health/ping. '
              'Please ensure the server is running and accessible.',
          errorType: 'SERVER_OFFLINE',
        );
      }

      debugPrint('✅ API is responsive');

      // Now check full health including database
      debugPrint('🔗 Checking database connectivity...');
      final healthResult = await _checkHealth();

      if (!healthResult.success) {
        return healthResult;
      }

      return HealthCheckResult(
        success: true,
        status: 'HEALTHY',
        message: 'All systems operational',
        details: 'API and Database are responding normally',
        errorType: null,
      );
    } catch (e) {
      debugPrint('❌ Unexpected connectivity check error: $e');
      return HealthCheckResult(
        success: false,
        status: 'ERROR',
        message: 'An unexpected error occurred during connectivity check',
        details: e.toString(),
        errorType: 'UNEXPECTED_ERROR',
      );
    }
  }

  /// Check if API is responding to a simple ping
  Future<HealthCheckResult> _checkPing() async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/health/ping'),
            headers: ApiConfig.getHeaders(),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return HealthCheckResult(success: true, status: 'OK');
      } else {
        return HealthCheckResult(
          success: false,
          status: 'API_ERROR',
          message: 'API returned an error',
          details: 'Status code: ${response.statusCode}',
          errorType: 'API_ERROR',
        );
      }
    } on TimeoutException {
      return HealthCheckResult(
        success: false,
        status: 'TIMEOUT',
        message: 'API request timed out',
        details: 'The server took too long to respond (5 seconds timeout)',
        errorType: 'TIMEOUT',
      );
    } catch (e) {
      return HealthCheckResult(
        success: false,
        status: 'CONNECTION_FAILED',
        message: 'Failed to connect to API',
        details: e.toString(),
        errorType: 'CONNECTION_FAILED',
      );
    }
  }

  /// Check full health status including database
  Future<HealthCheckResult> _checkHealth() async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/health/check'),
            headers: ApiConfig.getHeaders(),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        if (data['status'] == 'Healthy') {
          return HealthCheckResult(
            success: true,
            status: 'HEALTHY',
            message: 'All systems operational',
          );
        } else {
          // API is up but health check shows issues
          final errors = List<String>.from(data['errors'] ?? []);
          final errorMessage = errors.isNotEmpty
              ? errors.join(', ')
              : 'Unknown error';

          if (data['databaseStatus'] == 'FAILED' ||
              data['databaseStatus'] == 'ERROR') {
            return HealthCheckResult(
              success: false,
              status: 'DATABASE_ERROR',
              message: 'Database connection failed',
              details: errorMessage,
              errorType: 'DATABASE_ERROR',
            );
          } else {
            return HealthCheckResult(
              success: false,
              status: 'UNHEALTHY',
              message: 'System is in an unhealthy state',
              details: errorMessage,
              errorType: 'SYSTEM_ERROR',
            );
          }
        }
      } else if (response.statusCode == 503) {
        // Service Unavailable - health check endpoint exists but system is unhealthy
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final errors = List<String>.from(data['errors'] ?? []);
          final errorMessage = errors.isNotEmpty
              ? errors.join(', ')
              : 'Service unavailable';

          if (data['databaseStatus'] == 'FAILED' ||
              data['databaseStatus'] == 'ERROR') {
            return HealthCheckResult(
              success: false,
              status: 'DATABASE_ERROR',
              message: 'Cannot connect to the database',
              details: errorMessage,
              errorType: 'DATABASE_ERROR',
            );
          } else {
            return HealthCheckResult(
              success: false,
              status: 'SERVICE_UNAVAILABLE',
              message: 'Server is temporarily unavailable',
              details: errorMessage,
              errorType: 'SERVICE_ERROR',
            );
          }
        } catch (_) {
          return HealthCheckResult(
            success: false,
            status: 'SERVICE_UNAVAILABLE',
            message: 'Server is temporarily unavailable',
            details: 'Status 503 received but unable to parse error details',
            errorType: 'SERVICE_ERROR',
          );
        }
      } else {
        return HealthCheckResult(
          success: false,
          status: 'API_ERROR',
          message: 'API returned an unexpected status',
          details: 'Status code: ${response.statusCode}',
          errorType: 'API_ERROR',
        );
      }
    } on TimeoutException {
      return HealthCheckResult(
        success: false,
        status: 'TIMEOUT',
        message: 'Health check request timed out',
        details: 'The server took too long to respond (5 seconds timeout)',
        errorType: 'TIMEOUT',
      );
    } catch (e) {
      return HealthCheckResult(
        success: false,
        status: 'CONNECTION_FAILED',
        message: 'Failed to connect to API',
        details: e.toString(),
        errorType: 'CONNECTION_FAILED',
      );
    }
  }
}

class HealthCheckResult {
  final bool success;
  final String status;
  final String? message;
  final String? details;
  final String? errorType;

  HealthCheckResult({
    required this.success,
    required this.status,
    this.message,
    this.details,
    this.errorType,
  });

  String getDetailedMessage() {
    if (success) return message ?? 'System is healthy';

    String userMessage = '';

    switch (errorType) {
      case 'SERVER_OFFLINE':
        userMessage =
            '⚠️ Server is offline\n\n'
            'The BookSwap server is not responding. This could mean:\n'
            '• The server is not running\n'
            '• Network connectivity issues\n'
            '• The API URL is incorrect\n\n'
            'Please contact support if the problem persists.';
        break;
      case 'DATABASE_ERROR':
        userMessage =
            '⚠️ Database connection failed\n\n'
            'The server cannot connect to the database. This could mean:\n'
            '• SQL Server is not running\n'
            '• Database credentials are incorrect\n'
            '• Database is unreachable\n\n'
            'Please contact support if the problem persists.';
        break;
      case 'TIMEOUT':
        userMessage =
            '⏱️ Connection timeout\n\n'
            'The server is taking too long to respond. This could mean:\n'
            '• Slow network connection\n'
            '• Server is overloaded\n'
            '• Server is unresponsive\n\n'
            'Please try again or contact support.';
        break;
      case 'CONNECTION_FAILED':
        userMessage =
            '🔌 Cannot connect to server\n\n'
            'Unable to reach the API server. This could mean:\n'
            '• Network is unavailable\n'
            '• API URL is incorrect\n'
            '• Server is not accessible\n\n'
            'Please contact support if the problem persists.';
        break;
      case 'SERVICE_ERROR':
      case 'API_ERROR':
      case 'SYSTEM_ERROR':
      case 'UNEXPECTED_ERROR':
      default:
        userMessage =
            '❌ An error occurred\n\n'
            'The server encountered an error while processing your request.\n\n'
            'Please contact support with the following information:\n'
            'Error Type: $errorType\n'
            'Status: $status';
    }

    if (details != null && details!.isNotEmpty) {
      userMessage += '\n\nTechnical Details:\n$details';
    }

    return userMessage;
  }
}
