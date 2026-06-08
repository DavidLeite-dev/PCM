import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../config/api_config.dart';
import 'api_client.dart';
import 'token_storage_service.dart';

/// Handles authentication: login, auto-login via stored token, logout.
class AuthService {
  static final AuthService _instance = AuthService._internal();

  factory AuthService() => _instance;
  AuthService._internal();

  final ApiClient _apiClient = ApiClient();
  User? _currentUser;

  User? get currentUser => _currentUser;
  set currentUser(User? user) => _currentUser = user;

  /// Called at app startup. Attempts to restore the session from a stored token.
  /// Returns the user if the token is still valid, null otherwise.
  Future<User?> init() async {
    debugPrint('AuthService.init(): checking stored token');
    final token = await TokenStorageService.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('AuthService.init(): no token stored');
      return null;
    }

    // Set token so the API client sends it in the Authorization header
    ApiConfig.currentToken = token;

    try {
      final response = await _apiClient.get('${ApiConfig.authEndpoint}/me');
      final user = User.fromJson(response as Map<String, dynamic>);
      _currentUser = user;
      ApiConfig.currentUserEmail = user.email;
      debugPrint('AuthService.init(): auto-login as ${user.email}');
      return user;
    } on ApiException catch (e) {
      debugPrint('AuthService.init(): token invalid (${e.message}), clearing');
      await TokenStorageService.clearToken();
      ApiConfig.currentToken = '';
      ApiConfig.currentUserEmail = '';
      return null;
    }
  }

  /// Login with email/password. Returns User on success, null on failure.
  Future<User?> login({required String email, required String password}) async {
    try {
      debugPrint('AuthService.login(): $email');
      final response = await _apiClient.post(
        '${ApiConfig.authEndpoint}/login',
        body: {'email': email.toLowerCase(), 'password': password},
      );

      final token = response['token'] as String? ?? '';
      if (token.isEmpty) {
        debugPrint('AuthService.login(): no token in response');
        return null;
      }

      await TokenStorageService.saveToken(token);
      ApiConfig.currentToken = token;

      final user = User.fromJson(response);
      _currentUser = user;
      ApiConfig.currentUserEmail = user.email;
      debugPrint('AuthService.login(): success for ${user.email}');
      return user;
    } on ApiException catch (e) {
      debugPrint('AuthService.login(): failed: $e');
      return null;
    }
  }

  /// Register a new user. Returns true on success.
  Future<bool> registerUser({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      await _apiClient.post(
        '${ApiConfig.authEndpoint}/register',
        body: {'name': name, 'email': email.toLowerCase(), 'password': password, 'phone': '', 'address': ''},
      );
      return true;
    } on ApiException {
      return false;
    }
  }

  /// Update the user's profile fields.
  Future<bool> updateUserProfile({
    required String userId,
    String? name,
    String? phone,
    String? address,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (phone != null) body['phone'] = phone;
      if (address != null) body['address'] = address;

      await _apiClient.put('${ApiConfig.authEndpoint}/$userId', body: body);

      if (_currentUser != null) {
        if (name != null) _currentUser!.name = name;
        if (phone != null) _currentUser!.phone = phone;
        if (address != null) _currentUser!.address = address;
      }
      return true;
    } on ApiException {
      return false;
    }
  }

  /// Get user by numeric ID.
  Future<User?> getUserById(String userId) async {
    try {
      final response = await _apiClient.get('${ApiConfig.authEndpoint}/$userId');
      return User.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      return null;
    }
  }

  /// Logout: invalidate token on server and clear local storage.
  Future<void> logout() async {
    debugPrint('AuthService.logout()');
    try {
      await _apiClient.post('${ApiConfig.authEndpoint}/logout', body: {});
    } catch (_) {
      // best-effort — clear locally regardless
    }
    await TokenStorageService.clearToken();
    ApiConfig.currentToken = '';
    ApiConfig.currentUserEmail = '';
    _currentUser = null;
  }

  bool isAuthenticated() => _currentUser != null;

  void dispose() {
    _apiClient.dispose();
  }
}
