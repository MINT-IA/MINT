import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for managing JWT authentication tokens and user session.
/// Uses flutter_secure_storage (Keychain on iOS, Keystore on Android).
class AuthService {
  static const _tokenKey = 'jwt_token';
  static const _userIdKey = 'user_id';
  static const _userEmailKey = 'user_email';
  static const _displayNameKey = 'display_name';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Store auth token after login/register
  static Future<void> saveToken(
    String token,
    String userId,
    String email, {
    String? displayName,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);
    await _storage.write(key: _userEmailKey, value: email);
    if (displayName != null) {
      await _storage.write(key: _displayNameKey, value: displayName);
    }
  }

  /// Get stored token (null if not logged in)
  static Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  /// Get stored user ID
  static Future<String?> getUserId() async {
    return _storage.read(key: _userIdKey);
  }

  /// Get stored email
  static Future<String?> getUserEmail() async {
    return _storage.read(key: _userEmailKey);
  }

  /// Get stored display name
  static Future<String?> getDisplayName() async {
    return _storage.read(key: _displayNameKey);
  }

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Clear token (logout)
  static Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _userEmailKey);
    await _storage.delete(key: _displayNameKey);
  }
}
