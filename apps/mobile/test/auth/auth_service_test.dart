import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AuthService', () {
    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    test('saveToken and getToken roundtrip', () async {
      const token = 'test_jwt_token_xyz123';
      const userId = 'user_123';
      const email = 'test@example.com';
      const displayName = 'Test User';

      await AuthService.saveToken(
        token,
        userId,
        email,
        displayName: displayName,
      );

      final retrievedToken = await AuthService.getToken();
      final retrievedUserId = await AuthService.getUserId();
      final retrievedEmail = await AuthService.getUserEmail();
      final retrievedDisplayName = await AuthService.getDisplayName();

      expect(retrievedToken, token);
      expect(retrievedUserId, userId);
      expect(retrievedEmail, email);
      expect(retrievedDisplayName, displayName);
    });

    test('isLoggedIn returns false initially', () async {
      final isLoggedIn = await AuthService.isLoggedIn();
      expect(isLoggedIn, false);
    });

    test('isLoggedIn returns true after saveToken', () async {
      await AuthService.saveToken(
        'test_token',
        'user_123',
        'test@example.com',
      );

      final isLoggedIn = await AuthService.isLoggedIn();
      expect(isLoggedIn, true);
    });

    test('logout clears token', () async {
      await AuthService.saveToken(
        'test_token',
        'user_123',
        'test@example.com',
        displayName: 'Test User',
      );

      // Verify token exists
      expect(await AuthService.isLoggedIn(), true);

      // Logout
      await AuthService.logout();

      // Verify token is cleared
      expect(await AuthService.isLoggedIn(), false);
      expect(await AuthService.getToken(), null);
      expect(await AuthService.getUserId(), null);
      expect(await AuthService.getUserEmail(), null);
      expect(await AuthService.getDisplayName(), null);
    });

    test('saveToken without displayName', () async {
      await AuthService.saveToken(
        'test_token',
        'user_123',
        'test@example.com',
      );

      final displayName = await AuthService.getDisplayName();
      expect(displayName, null);
    });

    test('getToken returns null when not logged in', () async {
      final token = await AuthService.getToken();
      expect(token, null);
    });
  });
}
