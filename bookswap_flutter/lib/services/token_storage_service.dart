import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the session token on-device using the OS keychain / keystore.
/// On Android this uses EncryptedSharedPreferences (AES-256).
/// On iOS this uses the Keychain.
class TokenStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyToken = 'session_token';

  /// Save the raw token returned by the server.
  static Future<void> saveToken(String token) =>
      _storage.write(key: _keyToken, value: token);

  /// Read the stored token, or null if none.
  static Future<String?> getToken() => _storage.read(key: _keyToken);

  /// Delete the stored token (logout).
  static Future<void> clearToken() => _storage.delete(key: _keyToken);
}
