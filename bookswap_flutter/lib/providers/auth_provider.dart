import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _initialized = false;
  final List<String> _logs = [];

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;
  bool get initialized => _initialized;
  List<String> get logs => _logs;

  AuthProvider() {
    _initializeService();
  }

  void _addLog(String message) {
    _logs.add('[${DateTime.now().toIso8601String()}] $message');
  }

  Future<void> _initializeService() async {
    try {
      _addLog('AuthProvider: initializing...');
      debugPrint('AuthProvider: initializing...');

      // Try auto-login from stored token
      final user = await _authService.init();

      if (user != null) {
        _currentUser = user;
        ApiConfig.currentUserEmail = user.email;
        _addLog('AuthProvider: auto-logged in as ${user.email}');
        debugPrint('AuthProvider: auto-logged in as ${user.email}');
      } else {
        _addLog('AuthProvider: no valid token, login required');
        debugPrint('AuthProvider: no valid token, login required');
      }

      _initialized = true;
      _error = null;
      notifyListeners();
    } catch (e, stackTrace) {
      _addLog('AuthProvider: init error: $e');
      debugPrint('AuthProvider: init error: $e\n$stackTrace');
      _error = 'Failed to initialize auth: $e';
      _initialized = true;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _authService.registerUser(
        name: name,
        email: email,
        password: password,
      );
      _error = success ? null : 'Email já está registado';
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = 'Erro ao registar: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _authService.login(email: email, password: password);

      if (user != null) {
        _currentUser = user;
        ApiConfig.currentUserEmail = user.email;
        _error = null;
      } else {
        _error = 'Email ou senha incorretos';
      }

      _isLoading = false;
      notifyListeners();
      return user != null;
    } catch (e) {
      _error = 'Erro ao fazer login: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({
    String? name,
    String? phone,
    String? address,
  }) async {
    if (_currentUser == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _authService.updateUserProfile(
        userId: _currentUser!.id,
        name: name,
        phone: phone,
        address: address,
      );

      if (success) {
        if (name != null) _currentUser!.name = name;
        if (phone != null) _currentUser!.phone = phone;
        if (address != null) _currentUser!.address = address;
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = 'Erro ao atualizar perfil: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _currentUser = null;
    _error = null;
    notifyListeners();
  }

  bool isAdmin() => _currentUser?.isAdmin ?? false;
}
