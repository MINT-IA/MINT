import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/observability/mint_http_client.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';

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
    iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  static const _sessionKeys = {
    _tokenKey,
    _refreshTokenKey,
    _userIdKey,
    _userEmailKey,
    _displayNameKey,
  };

  // In-memory fallback cache. Populated by `saveToken` *before* the
  // keychain write is attempted, so the session survives a keychain
  // failure (PlatformException -34018, simulator without passcode,
  // .nosync-mounted dev builds, etc.). Cleared on `logout()`. Lost on
  // cold restart by design — security-conscious tradeoff: a transient
  // keychain failure should not lock the user out of finishing register
  // flow, but it must not silently grant a persistent session either.
  // Mirrors the PR #516 « graceful Keychain fallback » pattern shipped
  // for the biography service on 2026-05-07 (commit 3d7a7559).
  static String? _memToken;
  static String? _memRefreshToken;
  static String? _memUserId;
  static String? _memUserEmail;
  static String? _memDisplayName;

  /// Clear the in-memory token cache. Test-only hook so suites that mock
  /// the keychain channel can guarantee a clean slate per test —
  /// `static` fields otherwise leak across tests.
  @visibleForTesting
  static void resetMemoryCacheForTest() {
    _memToken = null;
    _memRefreshToken = null;
    _memUserId = null;
    _memUserEmail = null;
    _memDisplayName = null;
  }

  /// Store auth tokens after login/register
  ///
  /// Gate 0 P0 (2026-04-15): defensive sanity. Empty / whitespace-only
  /// tokens, userIds, or emails were silently accepted before, producing
  /// "zombie" auth where `isLoggedIn` returned true but every request
  /// 401'd. Now we reject up-front with an explicit error so the caller
  /// can surface it instead of leaving the app in a broken auth state.
  ///
  /// 2026-05-08 walker (P0 register-flow blocker): wrap keychain writes
  /// so a `PlatformException` (e.g. simulator without passcode, missing
  /// entitlement) does NOT abort the auth flow. The session uses the
  /// in-memory cache for the rest of its lifetime; cold restart will
  /// surface as logged-out (caller can re-prompt).
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

    // Populate memory cache FIRST so the session is functional even if
    // the keychain blows up below.
    _memToken = token;
    _memUserId = userId;
    _memUserEmail = email;
    _memDisplayName = displayName;
    _memRefreshToken = (refreshToken != null && refreshToken.trim().isNotEmpty)
        ? refreshToken
        : null;

    try {
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _userIdKey, value: userId);
      await _storage.write(key: _userEmailKey, value: email);
      if (displayName != null) {
        await _storage.write(key: _displayNameKey, value: displayName);
      }
      if (refreshToken != null && refreshToken.trim().isNotEmpty) {
        await _storage.write(key: _refreshTokenKey, value: refreshToken);
      }
    } on PlatformException catch (e) {
      // PlatformException from flutter_secure_storage on iOS simulator
      // / passcode-less devices / entitlement mismatches. The user's
      // session is preserved via the memory cache populated above.
      // We DON'T catch MissingPluginException — that's a test-environment
      // signal (plugin not registered) and other code paths rely on it
      // propagating to fall back to template responses.
      if (kDebugMode) {
        debugPrint('[AuthService] Keychain saveToken failed (memory '
            'fallback active for this session): $e');
      }
    }
    // E2E harness only (no-op hors MINT_E2E_SEAL_FALLBACK) : le keychain
    // re-signé est flaky sur sim — la session est aussi stashée pour
    // survivre au relaunch, sinon l'app retombe sur le portail d'accueil.
    await SecureWizardStore.e2eStashWrite(_tokenKey, token);
    await SecureWizardStore.e2eStashWrite(_userIdKey, userId);
    await SecureWizardStore.e2eStashWrite(_userEmailKey, email);
    if (displayName != null) {
      await SecureWizardStore.e2eStashWrite(_displayNameKey, displayName);
    }
    if (refreshToken != null && refreshToken.trim().isNotEmpty) {
      await SecureWizardStore.e2eStashWrite(_refreshTokenKey, refreshToken);
    }
  }

  /// E2E harness only : session restaurée du stash quand le keychain est
  /// mort ; null hors fallback.
  static Future<String?> _stashedSession(String key) =>
      SecureWizardStore.e2eStashRead(key);

  /// Get stored access token (null if not logged in)
  static Future<String?> getToken() async {
    if (_memToken != null) return _memToken;
    final stashed = await _stashedSession(_tokenKey);
    if (stashed != null && stashed.isNotEmpty) {
      _memToken = stashed;
      return stashed;
    }
    try {
      final v = await _storage.read(key: _tokenKey);
      if (v != null && v.isNotEmpty) _memToken = v;
      return v;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthService] Keychain read(token) failed: $e');
      }
      return null;
    }
  }

  /// Get stored refresh token
  static Future<String?> getRefreshToken() async {
    if (_memRefreshToken != null) return _memRefreshToken;
    final stashed = await _stashedSession(_refreshTokenKey);
    if (stashed != null && stashed.isNotEmpty) {
      _memRefreshToken = stashed;
      return stashed;
    }
    try {
      final v = await _storage.read(key: _refreshTokenKey);
      if (v != null && v.isNotEmpty) _memRefreshToken = v;
      return v;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthService] Keychain read(refresh) failed: $e');
      }
      return null;
    }
  }

  /// Get stored user ID
  static Future<String?> getUserId() async {
    if (_memUserId != null) return _memUserId;
    final stashed = await _stashedSession(_userIdKey);
    if (stashed != null && stashed.isNotEmpty) {
      _memUserId = stashed;
      return stashed;
    }
    try {
      final v = await _storage.read(key: _userIdKey);
      if (v != null && v.isNotEmpty) _memUserId = v;
      return v;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthService] Keychain read(userId) failed: $e');
      }
      return null;
    }
  }

  /// Get stored email
  static Future<String?> getUserEmail() async {
    if (_memUserEmail != null) return _memUserEmail;
    final stashed = await _stashedSession(_userEmailKey);
    if (stashed != null && stashed.isNotEmpty) {
      _memUserEmail = stashed;
      return stashed;
    }
    try {
      final v = await _storage.read(key: _userEmailKey);
      if (v != null && v.isNotEmpty) _memUserEmail = v;
      return v;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthService] Keychain read(email) failed: $e');
      }
      return null;
    }
  }

  /// Get stored display name
  static Future<String?> getDisplayName() async {
    if (_memDisplayName != null) return _memDisplayName;
    final stashed = await _stashedSession(_displayNameKey);
    if (stashed != null && stashed.isNotEmpty) {
      _memDisplayName = stashed;
      return stashed;
    }
    try {
      final v = await _storage.read(key: _displayNameKey);
      if (v != null && v.isNotEmpty) _memDisplayName = v;
      return v;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthService] Keychain read(name) failed: $e');
      }
      return null;
    }
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
      final response = await MintHttpClient.shared
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
        debugPrint('[AuthService] refresh failed: ${response.statusCode}');
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final newAccess = json['access_token'] as String?;
      final newRefresh = json['refresh_token'] as String?;
      if (newAccess == null || newAccess.isEmpty) return null;

      // Update memory first so the rotated token is usable even if the
      // keychain write fails (same fallback contract as `saveToken`).
      _memToken = newAccess;
      if (newRefresh != null && newRefresh.isNotEmpty) {
        _memRefreshToken = newRefresh;
      }
      try {
        await _storage.write(key: _tokenKey, value: newAccess);
        if (newRefresh != null && newRefresh.isNotEmpty) {
          await _storage.write(key: _refreshTokenKey, value: newRefresh);
        }
      } on PlatformException catch (e) {
        if (kDebugMode) {
          debugPrint('[AuthService] Keychain refresh-write failed (memory '
              'fallback active): $e');
        }
      }
      return newAccess;
    } catch (e) {
      debugPrint('[AuthService] refresh exception: $e');
      return null;
    }
  }

  /// Clear all auth tokens and identity keys from memory + secure storage.
  ///
  /// Returns `false` if any known MINT auth key could not be removed. Callers
  /// that are guarding a fresh install should then avoid restoring auth from
  /// Keychain during the same launch.
  static Future<bool> purgeStoredSession() async {
    _memToken = null;
    _memRefreshToken = null;
    _memUserId = null;
    _memUserEmail = null;
    _memDisplayName = null;
    var purged = true;
    await SecureWizardStore.e2eStashDelete(_sessionKeys);
    for (final key in _sessionKeys) {
      try {
        await _storage.delete(key: key);
      } on PlatformException catch (e) {
        if (SecureWizardStore.isTolerableE2eKeychainAbsence(e)) continue;
        purged = false;
        if (kDebugMode) {
          debugPrint('[AuthService] Keychain purge failed for $key: $e');
        }
      }
    }
    return purged;
  }

  /// Clear all tokens (logout)
  static Future<void> logout() async {
    await purgeStoredSession();
  }
}
