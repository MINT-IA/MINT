import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // In-memory mock for flutter_secure_storage platform channel
  final Map<String, String> mockStorage = {};

  setUp(() {
    mockStorage.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        switch (call.method) {
          case 'write':
            final key = call.arguments['key'] as String;
            final value = call.arguments['value'] as String?;
            if (value != null) {
              mockStorage[key] = value;
            }
            return null;
          case 'read':
            final key = call.arguments['key'] as String;
            return mockStorage[key];
          case 'delete':
            final key = call.arguments['key'] as String;
            mockStorage.remove(key);
            return null;
          case 'deleteAll':
            mockStorage.clear();
            return null;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });

  group('AuthService', () {
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
