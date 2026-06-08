import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';

/// Exception class for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException({required this.message, this.statusCode});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

/// HTTP client service for API communication
/// Implements singleton pattern and best practices for API calls
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal();

  final http.Client _client = http.Client();

  /// Performs a GET request - can return either a Map or a List
  Future<dynamic> get(String endpoint) async {
    try {
      debugPrint('API GET: ${ApiConfig.baseUrl}$endpoint');

      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}$endpoint'),
            headers: ApiConfig.getHeaders(),
          )
          .timeout(ApiConfig.requestTimeout);

      return _handleResponseDynamic(response);
    } catch (e) {
      debugPrint('API GET Error: $e');
      throw ApiException(message: 'Network error: $e');
    }
  }

  /// Performs a POST request
  Future<Map<String, dynamic>> post(
    String endpoint, {
    required Map<String, dynamic> body,
  }) async {
    try {
      debugPrint('API POST: ${ApiConfig.baseUrl}$endpoint');
      debugPrint('Payload: $body');

      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}$endpoint'),
            headers: ApiConfig.getHeaders(),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      debugPrint('API POST Error: $e');
      throw ApiException(message: 'Network error: $e');
    }
  }

  /// Performs a PUT request
  Future<Map<String, dynamic>> put(
    String endpoint, {
    required Map<String, dynamic> body,
  }) async {
    try {
      debugPrint('API PUT: ${ApiConfig.baseUrl}$endpoint');
      debugPrint('Payload: $body');

      final response = await _client
          .put(
            Uri.parse('${ApiConfig.baseUrl}$endpoint'),
            headers: ApiConfig.getHeaders(),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      debugPrint('API PUT Error: $e');
      throw ApiException(message: 'Network error: $e');
    }
  }

  /// Performs a PATCH request
  Future<Map<String, dynamic>> patch(
    String endpoint, {
    required Map<String, dynamic> body,
  }) async {
    try {
      debugPrint('API PATCH: ${ApiConfig.baseUrl}$endpoint');

      final response = await _client
          .patch(
            Uri.parse('${ApiConfig.baseUrl}$endpoint'),
            headers: ApiConfig.getHeaders(),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      debugPrint('API PATCH Error: $e');
      throw ApiException(message: 'Network error: $e');
    }
  }

  /// Performs a DELETE request
  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      debugPrint('API DELETE: ${ApiConfig.baseUrl}$endpoint');

      final response = await _client
          .delete(
            Uri.parse('${ApiConfig.baseUrl}$endpoint'),
            headers: ApiConfig.getHeaders(),
          )
          .timeout(ApiConfig.requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      debugPrint('API DELETE Error: $e');
      throw ApiException(message: 'Network error: $e');
    }
  }

  /// Handles HTTP response and converts to JSON
  Map<String, dynamic> _handleResponse(http.Response response) {
    debugPrint('API Response: ${response.statusCode}');

    final statusCode = response.statusCode;

    // Parse response
    Map<String, dynamic> responseData = {};
    try {
      if (response.bodyBytes.isNotEmpty) {
        responseData = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error parsing response: $e');
      throw ApiException(
        message: 'Invalid response format',
        statusCode: statusCode,
      );
    }

    // Handle status codes
    if (statusCode >= 200 && statusCode < 300) {
      return responseData;
    } else if (statusCode == 400) {
      throw ApiException(
        message: responseData['message'] ?? 'Bad request',
        statusCode: statusCode,
      );
    } else if (statusCode == 401) {
      throw ApiException(message: 'Unauthorized', statusCode: statusCode);
    } else if (statusCode == 404) {
      throw ApiException(
        message: responseData['message'] ?? 'Not found',
        statusCode: statusCode,
      );
    } else if (statusCode >= 500) {
      throw ApiException(message: 'Server error', statusCode: statusCode);
    } else {
      throw ApiException(
        message: responseData['message'] ?? 'Request failed',
        statusCode: statusCode,
      );
    }
  }

  /// Handles HTTP response and converts to JSON - returns dynamic (Map or List)
  dynamic _handleResponseDynamic(http.Response response) {
    debugPrint('API Response: ${response.statusCode}');

    final statusCode = response.statusCode;

    // Parse response - can be either a Map or a List
    dynamic responseData;
    try {
      if (response.bodyBytes.isNotEmpty) {
        responseData = jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        responseData = {};
      }
    } catch (e) {
      debugPrint('Error parsing response: $e');
      throw ApiException(
        message: 'Invalid response format',
        statusCode: statusCode,
      );
    }

    // Handle status codes
    if (statusCode >= 200 && statusCode < 300) {
      return responseData;
    } else if (statusCode == 400) {
      final message = responseData is Map
          ? (responseData['message'] ?? 'Bad request')
          : 'Bad request';
      throw ApiException(message: message, statusCode: statusCode);
    } else if (statusCode == 401) {
      throw ApiException(message: 'Unauthorized', statusCode: statusCode);
    } else if (statusCode == 404) {
      final message = responseData is Map
          ? (responseData['message'] ?? 'Not found')
          : 'Not found';
      throw ApiException(message: message, statusCode: statusCode);
    } else if (statusCode >= 500) {
      throw ApiException(message: 'Server error', statusCode: statusCode);
    } else {
      final message = responseData is Map
          ? (responseData['message'] ?? 'Request failed')
          : 'Request failed';
      throw ApiException(message: message, statusCode: statusCode);
    }
  }

  /// Dispose resources
  void dispose() {
    _client.close();
  }
}
