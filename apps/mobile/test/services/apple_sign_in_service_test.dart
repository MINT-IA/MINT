import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/apple_sign_in_service.dart';

void main() {
  group('AppleSignInService', () {
    test('isAvailable returns a boolean', () async {
      // isAvailable should always return a bool (false in test environment)
      final result = await AppleSignInService.isAvailable();
      expect(result, isA<bool>());
    });

    test('isAvailable returns false in non-iOS test environment', () async {
      // In test environment (not iOS), should return false
      final result = await AppleSignInService.isAvailable();
      expect(result, isFalse);
    });

    test('signIn returns null when not available', () async {
      // When Apple Sign-In is not available (non-iOS), signIn returns null
      final result = await AppleSignInService.signIn();
      expect(result, isNull);
    });

    test('generateNonce returns a non-empty string', () {
      final nonce = AppleSignInService.generateNonce();
      expect(nonce, isNotEmpty);
      expect(nonce.length, equals(32));
    });

    test('sha256OfNonce returns a hex string', () {
      final nonce = 'test-nonce-value';
      final hash = AppleSignInService.sha256OfNonce(nonce);
      expect(hash, isNotEmpty);
      // SHA-256 hex digest is always 64 characters
      expect(hash.length, equals(64));
    });

    test('sha256OfNonce is deterministic', () {
      const nonce = 'deterministic-test';
      final hash1 = AppleSignInService.sha256OfNonce(nonce);
      final hash2 = AppleSignInService.sha256OfNonce(nonce);
      expect(hash1, equals(hash2));
    });

    test('generateNonce produces unique values', () {
      final nonce1 = AppleSignInService.generateNonce();
      final nonce2 = AppleSignInService.generateNonce();
      expect(nonce1, isNot(equals(nonce2)));
    });
  });
}
