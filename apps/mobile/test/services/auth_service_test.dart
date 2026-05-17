import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/auth_service.dart';

/// Unit tests for AuthService
///
/// AuthService uses SharedPreferences for JWT token persistence.
/// SharedPreferences provides setMockInitialValues for testing,
/// so all methods are fully testable without platform I/O.
///
/// Tests cover:
/// - Storage key constants
/// - Token save/retrieve lifecycle
/// - User info storage (userId, email, displayName)
/// - isLoggedIn logic
/// - Logout clears all data
/// - Edge cases: empty tokens, missing fields, multiple saves
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, String> mockStorage = {};

  setUp(() {
    mockStorage.clear();
    AuthService.resetMemoryCacheForTest();
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

  // ═══════════════════════════════════════════════════════════════════════
  // Token Storage and Retrieval
  // ═══════════════════════════════════════════════════════════════════════

  group('AuthService — Token save/retrieve', () {
    test('getToken returns null when no token stored', () async {
      final token = await AuthService.getToken();
      expect(token, isNull);
    });

    test('saveToken then getToken returns the saved token', () async {
      await AuthService.saveToken(
        'jwt-token-abc',
        'user-id-1',
        'test@mint.ch',
      );

      final token = await AuthService.getToken();
      expect(token, equals('jwt-token-abc'));
    });

    test('saving a new token overwrites the previous one', () async {
      await AuthService.saveToken('first-token', 'uid-1', 'a@b.ch');
      await AuthService.saveToken('second-token', 'uid-2', 'c@d.ch');

      final token = await AuthService.getToken();
      expect(token, equals('second-token'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // User Info Storage
  // ═══════════════════════════════════════════════════════════════════════

  group('AuthService — User info', () {
    test('getUserId returns null when not stored', () async {
      final userId = await AuthService.getUserId();
      expect(userId, isNull);
    });

    test('getUserId returns stored user ID', () async {
      await AuthService.saveToken('tok', 'user-42', 'u@test.ch');
      final userId = await AuthService.getUserId();
      expect(userId, equals('user-42'));
    });

    test('getUserEmail returns null when not stored', () async {
      final email = await AuthService.getUserEmail();
      expect(email, isNull);
    });

    test('getUserEmail returns stored email', () async {
      await AuthService.saveToken('tok', 'uid', 'marc@swiss.ch');
      final email = await AuthService.getUserEmail();
      expect(email, equals('marc@swiss.ch'));
    });

    test('getDisplayName returns null when not provided', () async {
      await AuthService.saveToken('tok', 'uid', 'a@b.ch');
      final name = await AuthService.getDisplayName();
      expect(name, isNull);
    });

    test('getDisplayName returns stored name when provided', () async {
      await AuthService.saveToken(
        'tok',
        'uid',
        'a@b.ch',
        displayName: 'Marie Fontaine',
      );
      final name = await AuthService.getDisplayName();
      expect(name, equals('Marie Fontaine'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // isLoggedIn
  // ═══════════════════════════════════════════════════════════════════════

  group('AuthService — isLoggedIn', () {
    test('returns false when no token is stored', () async {
      final loggedIn = await AuthService.isLoggedIn();
      expect(loggedIn, isFalse);
    });

    test('returns true after saving a token', () async {
      await AuthService.saveToken('valid-token', 'uid', 'a@b.ch');
      final loggedIn = await AuthService.isLoggedIn();
      expect(loggedIn, isTrue);
    });

    test('returns false after logout', () async {
      await AuthService.saveToken('valid-token', 'uid', 'a@b.ch');
      await AuthService.logout();
      final loggedIn = await AuthService.isLoggedIn();
      expect(loggedIn, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Logout
  // ═══════════════════════════════════════════════════════════════════════

  group('AuthService — logout', () {
    test('logout clears the JWT token', () async {
      await AuthService.saveToken('tok', 'uid', 'a@b.ch');
      await AuthService.logout();
      final token = await AuthService.getToken();
      expect(token, isNull);
    });

    test('logout clears user ID', () async {
      await AuthService.saveToken('tok', 'uid', 'a@b.ch');
      await AuthService.logout();
      final userId = await AuthService.getUserId();
      expect(userId, isNull);
    });

    test('logout clears email', () async {
      await AuthService.saveToken('tok', 'uid', 'a@b.ch');
      await AuthService.logout();
      final email = await AuthService.getUserEmail();
      expect(email, isNull);
    });

    test('logout clears display name', () async {
      await AuthService.saveToken(
        'tok',
        'uid',
        'a@b.ch',
        displayName: 'Test User',
      );
      await AuthService.logout();
      final name = await AuthService.getDisplayName();
      expect(name, isNull);
    });

    test('logout is idempotent (calling twice does not throw)', () async {
      await AuthService.saveToken('tok', 'uid', 'a@b.ch');
      await AuthService.logout();
      // Second logout should not throw
      await AuthService.logout();
      final token = await AuthService.getToken();
      expect(token, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Edge Cases
  // ═══════════════════════════════════════════════════════════════════════

  group('AuthService — edge cases', () {
    test('saveToken rejects empty token (Gate 0 zombie-auth guard)', () async {
      // Gate 0 fix 2026-04-15: saveToken now throws ArgumentError on
      // empty/whitespace token, userId, or email. Previously empty
      // values were silently persisted, producing "logged in" state
      // where every request 401'd.
      expect(
        () => AuthService.saveToken('', 'uid', 'a@b.ch'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('saveToken rejects empty userId', () async {
      expect(
        () => AuthService.saveToken('tok', '', 'a@b.ch'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('saveToken rejects empty email', () async {
      expect(
        () => AuthService.saveToken('tok', 'uid', ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('long JWT token is stored and retrieved correctly', () async {
      // Typical JWT can be 500+ characters
      final longToken = 'eyJ${'a' * 500}.payload.signature';
      await AuthService.saveToken(longToken, 'uid', 'a@b.ch');
      final retrieved = await AuthService.getToken();
      expect(retrieved, equals(longToken));
    });

    test('special characters in email are preserved', () async {
      const email = 'user+mint@swiss-finance.ch';
      await AuthService.saveToken('tok', 'uid', email);
      final retrieved = await AuthService.getUserEmail();
      expect(retrieved, equals(email));
    });

    test('unicode display name is preserved', () async {
      const name = 'Rene Muller';
      await AuthService.saveToken('tok', 'uid', 'a@b.ch', displayName: name);
      final retrieved = await AuthService.getDisplayName();
      expect(retrieved, equals(name));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Keychain failure fallback (MVP-walker 2026-05-08, P0 register blocker)
  // ═══════════════════════════════════════════════════════════════════════
  //
  // Regression for: register flow on iOS sim threw a PlatformException
  // from flutter_secure_storage *after* the backend HTTP 201 had already
  // created the user. saveToken's keychain write was ungated; the
  // exception propagated to AuthProvider.register's catch and surfaced
  // as the generic "Action impossible pour le moment" — leaving the user
  // stuck on the register screen with an orphan account on staging.
  //
  // Fix: keychain writes are wrapped; the in-memory cache is populated
  // first so the session is functional for the rest of its lifetime
  // even when the keychain layer is unavailable.
  group('AuthService — keychain failure fallback', () {
    test(
        'saveToken does NOT throw when keychain write fails (PlatformException)',
        () async {
      // Replace the mock with one that fails every write — emulates the
      // simulator without a passcode / missing entitlement / -34018.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall call) async {
          if (call.method == 'write') {
            throw PlatformException(
              code: 'Unexpected security result code',
              message: 'A required entitlement is not present.',
            );
          }
          return null;
        },
      );

      // Should NOT rethrow; the auth flow must continue.
      await AuthService.saveToken('tok', 'uid', 'a@b.ch');
    });

    test('getToken returns memory token after keychain write failure',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall call) async {
          if (call.method == 'write') {
            throw PlatformException(code: 'kc-write-fail');
          }
          // read returns null (mock storage stays empty because writes failed)
          return null;
        },
      );

      await AuthService.saveToken('jwt-mem-fallback', 'uid-mem', 'mem@mint.ch',
          refreshToken: 'refresh-mem', displayName: 'MemUser');

      expect(await AuthService.getToken(), equals('jwt-mem-fallback'));
      expect(await AuthService.getRefreshToken(), equals('refresh-mem'));
      expect(await AuthService.getUserId(), equals('uid-mem'));
      expect(await AuthService.getUserEmail(), equals('mem@mint.ch'));
      expect(await AuthService.getDisplayName(), equals('MemUser'));
      expect(await AuthService.isLoggedIn(), isTrue);
    });

    test('getToken returns null when keychain read fails AND memory empty',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall call) async {
          throw PlatformException(code: 'kc-everything-fails');
        },
      );

      // No saveToken first — memory cache is empty (setUp resets it).
      expect(await AuthService.getToken(), isNull);
      expect(await AuthService.isLoggedIn(), isFalse);
    });

    test('logout clears memory cache even when keychain delete fails',
        () async {
      // First, save successfully via the default mock (mockStorage works).
      await AuthService.saveToken('logout-tok', 'logout-uid', 'l@b.ch');
      expect(await AuthService.getToken(), equals('logout-tok'));

      // Then swap to a mock that fails every call (including delete).
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall call) async {
          throw PlatformException(code: 'kc-delete-fail');
        },
      );

      // logout must still clear memory and not throw.
      await AuthService.logout();

      // After logout: getToken consults memory (cleared) then keychain
      // (throwing → returns null). Both paths yield null.
      expect(await AuthService.getToken(), isNull);
      expect(await AuthService.isLoggedIn(), isFalse);
    });
  });
}
