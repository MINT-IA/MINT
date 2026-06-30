import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show PlatformException;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:mint_mobile/services/api_service.dart';

typedef AppleSignInFn = Future<Map<String, dynamic>?> Function();

/// Service for Apple Sign-In authentication (iOS only).
///
/// Wraps the `sign_in_with_apple` package with proper nonce handling
/// and backend verification via POST /api/v1/auth/apple/verify.
class AppleSignInService {
  static AppleSignInFn? _signInOverride;
  static bool? _debugLastAllowRecreateAfterDelete;

  @visibleForTesting
  static set signInOverride(AppleSignInFn? fn) => _signInOverride = fn;

  @visibleForTesting
  static bool? get debugLastAllowRecreateAfterDeleteForTest =>
      _debugLastAllowRecreateAfterDelete;

  @visibleForTesting
  static void resetOverrides() {
    _signInOverride = null;
    _debugLastAllowRecreateAfterDelete = null;
  }

  @visibleForTesting
  static Map<String, dynamic> normalizeVerifyResponseForTest(
    Map<String, dynamic> response,
  ) =>
      _normalizeVerifyResponse(response);

  static Map<String, dynamic> _normalizeVerifyResponse(
    Map<String, dynamic> response,
  ) {
    final accessToken = response['accessToken'] ?? response['access_token'];
    final tokenType = response['tokenType'] ?? response['token_type'];
    final userId = response['userId'] ?? response['user_id'];
    final displayName = response['displayName'] ?? response['display_name'];
    final refreshToken = response['refreshToken'] ?? response['refresh_token'];

    return {
      ...response,
      if (accessToken != null) 'accessToken': accessToken,
      if (tokenType != null) 'tokenType': tokenType,
      if (userId != null) 'userId': userId,
      if (displayName != null) 'displayName': displayName,
      if (refreshToken != null) 'refreshToken': refreshToken,
    };
  }

  static bool isCancellation(Object error) {
    if (error is SignInWithAppleAuthorizationException) {
      return error.code == AuthorizationErrorCode.canceled;
    }
    if (error is PlatformException) {
      final raw = [
        error.code,
        error.message,
        error.details,
      ].whereType<Object>().join(' ').toLowerCase();
      final isAppleAuthorizationFailure =
          raw.contains('authenticationservices.authorizationerror') ||
              raw.contains('asauthorizationerror') ||
              raw.contains('com.apple.authenticationservices');
      return isAppleAuthorizationFailure &&
          (raw.contains('error 1001') ||
              raw.contains('canceled') ||
              raw.contains('cancelled'));
    }
    return false;
  }

  /// Check if Apple Sign-In is available on this device.
  ///
  /// Returns `true` only on iOS/macOS where Apple Sign-In is supported.
  /// Returns `false` on Android, web, and test environments.
  static Future<bool> isAvailable() async {
    try {
      return await SignInWithApple.isAvailable();
    } catch (_) {
      // In test environments or unsupported platforms, return false.
      return false;
    }
  }

  /// Trigger the native Apple Sign-In flow.
  ///
  /// Returns the raw backend response on success, or `null` if the user
  /// canceled the flow or Apple Sign-In is not available.
  ///
  /// The response contains `accessToken`, `userId`, and `email`. It is
  /// the caller's responsibility (AuthProvider.completeAppleSignIn) to
  /// persist the token and update auth state — this service does NOT
  /// mutate any global state.
  ///
  /// Throws on unexpected errors (network failure, backend error).
  static Future<Map<String, dynamic>?> signIn({
    bool allowRecreateAfterDelete = false,
  }) async {
    assert(() {
      _debugLastAllowRecreateAfterDelete = allowRecreateAfterDelete;
      return true;
    }());
    final override = _signInOverride;
    if (override != null) return override();

    final available = await isAvailable();
    if (!available) return null;

    final rawNonce = generateNonce();
    final hashedNonce = sha256OfNonce(rawNonce);

    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      rethrow;
    }

    final identityToken = credential.identityToken;
    if (identityToken == null) {
      throw Exception('Apple Sign-In returned no identity token');
    }

    // Send identity token to backend for verification and JWT issuance.
    final response = await ApiService.postAppleVerify(
      identityToken: identityToken,
      nonce: rawNonce,
      allowRecreateAfterDelete: allowRecreateAfterDelete,
    );

    final normalizedResponse = _normalizeVerifyResponse(response);
    final accessToken = normalizedResponse['accessToken'] as String?;
    if (accessToken == null) {
      throw Exception('Backend returned no access token for Apple Sign-In');
    }

    // Do NOT persist the token here — return a response shape that
    // AuthProvider.completeAppleSignIn() can consume as the single state
    // mutation point.
    return normalizedResponse;
  }

  /// Generate a cryptographically secure random nonce (32 characters).
  static String generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  /// Compute SHA-256 hash of a nonce string (hex digest).
  static String sha256OfNonce(String nonce) {
    final bytes = utf8.encode(nonce);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
