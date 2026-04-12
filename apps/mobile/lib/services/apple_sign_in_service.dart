import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';

/// Service for Apple Sign-In authentication (iOS only).
///
/// Wraps the `sign_in_with_apple` package with proper nonce handling
/// and backend verification via POST /api/v1/auth/apple/verify.
class AppleSignInService {
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
  /// Returns a JWT access token on success, or `null` if the user
  /// canceled the flow or Apple Sign-In is not available.
  ///
  /// Throws on unexpected errors (network failure, backend error).
  static Future<String?> signIn() async {
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
    );

    final accessToken = response['accessToken'] as String?;
    final userId = response['userId'] as String? ?? '';
    final email = response['email'] as String? ?? '';

    if (accessToken == null) {
      throw Exception('Backend returned no access token for Apple Sign-In');
    }

    // Store the JWT in secure storage (same as magic link flow).
    await AuthService.saveToken(accessToken, userId, email);

    return accessToken;
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
