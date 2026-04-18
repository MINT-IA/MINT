import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'package:mint_mobile/services/api_service.dart';

/// Service for managing JWT authentication tokens and user session.
/// Uses flutter_secure_storage (Keychain on iOS, Keystore on Android).
class AuthService {
  static const _tokenKey = 'jwt_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _userEmailKey = 'user_email';
  static const _displayNameKey = 'display_name';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Store auth tokens after login/register
  ///
  /// Gate 0 P0 (2026-04-15): defensive sanity. Empty / whitespace-only
  /// tokens, userIds, or emails were silently accepted before, producing
  /// "zombie" auth where `isLoggedIn` returned true but every request
  /// 401'd. Now we reject up-front with an explicit error so the caller
  /// can surface it instead of leaving the app in a broken auth state.
  static Future<void> saveToken(
    String token,
    String userId,
    String email, {
    String? displayName,
    String? refreshToken,
  }) async {
    if (token.trim().isEmpty) {
      throw ArgumentError.value(token, 'token', 'must be non-empty');
    }
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'must be non-empty');
    }
    if (email.trim().isEmpty) {
      throw ArgumentError.value(email, 'email', 'must be non-empty');
    }
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);
    await _storage.write(key: _userEmailKey, value: email);
    if (displayName != null) {
      await _storage.write(key: _displayNameKey, value: displayName);
    }
    if (refreshToken != null && refreshToken.trim().isNotEmpty) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  /// Get stored access token (null if not logged in)
  static Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  /// Get stored refresh token
  static Future<String?> getRefreshToken() async {
    return _storage.read(key: _refreshTokenKey);
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

  /// Rotate the access token using the stored refresh token.
  ///
  /// Audit 2026-04-17: the coach (and every other authenticated call) used
  /// to break after JWT expiry because the client stored a refresh token
  /// but never redeemed it. Backend [`/auth/refresh`] rotates: each refresh
  /// token is single-use and returns a fresh pair. On success, we update
  /// both tokens in storage and return the new access token. On any
  /// failure (invalid/expired/reused/network), we return null; the caller
  /// is responsible for prompting re-login.
  ///
  /// Concurrency: the in-flight refresh is deduplicated so parallel
  /// callers (e.g. coach + profile fetch both 401'ing at once) don't burn
  /// the single-use refresh token twice.
  static Future<String?>? _inFlightRefresh;

  static Future<String?> refreshAccessToken() async {
    final existing = _inFlightRefresh;
    if (existing != null) return existing;

    final future = _performRefresh();
    _inFlightRefresh = future;
    try {
      return await future;
    } finally {
      _inFlightRefresh = null;
    }
  }

  static Future<String?> _performRefresh() async {
    final refresh = await getRefreshToken();
    if (refresh == null || refresh.isEmpty) return null;

    try {
      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/auth/refresh'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refresh}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        // 401 = refresh token expired, reused, or revoked. Caller must
        // re-auth. Other codes (5xx) are transient — same outcome for
        // the caller, but worth logging.
        debugPrint(
            '[AuthService] refresh failed: ${response.statusCode}');
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final newAccess = json['access_token'] as String?;
      final newRefresh = json['refresh_token'] as String?;
      if (newAccess == null || newAccess.isEmpty) return null;

      await _storage.write(key: _tokenKey, value: newAccess);
      if (newRefresh != null && newRefresh.isNotEmpty) {
        await _storage.write(key: _refreshTokenKey, value: newRefresh);
      }
      return newAccess;
    } catch (e) {
      debugPrint('[AuthService] refresh exception: $e');
      return null;
    }
  }

  /// Clear all tokens (logout)
  static Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _userEmailKey);
    await _storage.delete(key: _displayNameKey);
  }
}
