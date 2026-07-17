import 'dart:convert';

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
  var secureWriteCalls = 0;
  var failNextEnvelopeWrite = false;

  setUp(() {
    mockStorage.clear();
    secureWriteCalls = 0;
    failNextEnvelopeWrite = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        switch (call.method) {
          case 'write':
            final key = call.arguments['key'] as String;
            final value = call.arguments['value'] as String?;
            secureWriteCalls++;
            if (key == 'auth_session_v1' && failNextEnvelopeWrite) {
              failNextEnvelopeWrite = false;
              throw PlatformException(code: 'synthetic_write_failure');
            }
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

    test('saving another identity cannot replace the active session', () async {
      await AuthService.saveToken('first-token', 'uid-1', 'a@b.ch');

      await expectLater(
        AuthService.saveToken('second-token', 'uid-2', 'c@d.ch'),
        throwsStateError,
      );

      final token = await AuthService.getToken();
      expect(token, equals('first-token'));
      expect(await AuthService.getUserId(), 'uid-1');
      expect(await AuthService.getUserEmail(), 'a@b.ch');
    });

    test('concurrent first-session writes publish exactly one identity',
        () async {
      final outcomes = await Future.wait([
        AuthService.saveToken('token-a', 'user-a', 'a@mint.test')
            .then((_) => true, onError: (_) => false),
        AuthService.saveToken('token-b', 'user-b', 'b@mint.test')
            .then((_) => true, onError: (_) => false),
      ]);

      expect(outcomes.where((succeeded) => succeeded), hasLength(1));
      final envelope = await AuthService.readSessionEnvelope();
      expect(envelope, isNotNull);
      expect(
        {
          envelope!.userId,
          envelope.email,
          envelope.accessToken,
        },
        anyOf(
          {'user-a', 'a@mint.test', 'token-a'},
          {'user-b', 'b@mint.test', 'token-b'},
        ),
      );
    });

    test('one secure write persists one complete versioned session envelope',
        () async {
      await AuthService.saveToken(
        'atomic-token',
        'atomic-user',
        'atomic@mint.test',
        displayName: 'Atomic User',
        refreshToken: 'atomic-refresh',
      );

      expect(secureWriteCalls, 1);
      expect(mockStorage.keys, ['auth_session_v1']);
      expect(
        jsonDecode(mockStorage['auth_session_v1']!) as Map<String, dynamic>,
        {
          'version': 1,
          'accessToken': 'atomic-token',
          'refreshToken': 'atomic-refresh',
          'userId': 'atomic-user',
          'email': 'atomic@mint.test',
          'displayName': 'Atomic User',
        },
      );
    });

    test('failed envelope replacement leaves the exact prior session',
        () async {
      await AuthService.saveToken(
        'token-a',
        'user-a',
        'a@mint.test',
        refreshToken: 'refresh-a',
      );
      final exactA = mockStorage['auth_session_v1'];
      failNextEnvelopeWrite = true;

      await expectLater(
        AuthService.saveToken(
          'token-b',
          'user-a',
          'a@mint.test',
          refreshToken: 'refresh-b',
        ),
        throwsA(isA<PlatformException>()),
      );

      expect(mockStorage['auth_session_v1'], exactA);
      expect(await AuthService.getToken(), 'token-a');
      expect(await AuthService.getUserId(), 'user-a');
      expect(await AuthService.getUserEmail(), 'a@mint.test');
      expect(await AuthService.getRefreshToken(), 'refresh-a');
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
      await AuthService.clearTokensForSessionTermination();
      final loggedIn = await AuthService.isLoggedIn();
      expect(loggedIn, isFalse);
    });

    test('cold complete legacy credentials migrate once to the envelope',
        () async {
      mockStorage.addAll({
        'jwt_token': 'legacy-token',
        'refresh_token': 'legacy-refresh',
        'user_id': 'legacy-user',
        'user_email': 'legacy@mint.test',
        'display_name': 'Legacy User',
      });

      expect(await AuthService.isLoggedIn(), isTrue);
      expect(await AuthService.getToken(), 'legacy-token');
      expect(mockStorage['auth_session_v1'], isNotNull);
      for (final legacyKey in const [
        'jwt_token',
        'refresh_token',
        'user_id',
        'user_email',
        'display_name',
      ]) {
        expect(mockStorage, isNot(contains(legacyKey)), reason: legacyKey);
      }
    });

    test('partial legacy credentials require durable terminal recovery',
        () async {
      mockStorage['jwt_token'] = 'orphan-token';

      await expectLater(
        AuthService.isLoggedIn(),
        throwsA(_authRecoveryRequired),
      );
      expect(mockStorage['jwt_token'], 'orphan-token');
      expect(mockStorage['auth_session_recovery_required_v1'], '1');

      await expectLater(
        AuthService.getToken(),
        throwsA(_authRecoveryRequired),
      );
      await expectLater(
        AuthService.saveToken('token-b', 'user-b', 'b@mint.test'),
        throwsA(_authRecoveryRequired),
      );
    });

    test('corrupt envelope remains recovery-required across cold reads',
        () async {
      mockStorage.addAll({
        'auth_session_v1': '{broken',
        'jwt_token': 'legacy-token',
        'user_id': 'legacy-user',
        'user_email': 'legacy@mint.test',
      });

      await expectLater(
        AuthService.isLoggedIn(),
        throwsA(_authRecoveryRequired),
      );
      expect(mockStorage['auth_session_v1'], '{broken');
      expect(mockStorage['jwt_token'], 'legacy-token');
      expect(mockStorage['auth_session_recovery_required_v1'], '1');

      // A new read models a cold process: the durable marker, rather than a
      // transient parse result, remains the authority until terminal purge.
      await expectLater(
        AuthService.readSessionEnvelope(),
        throwsA(_authRecoveryRequired),
      );
      await expectLater(
        AuthService.saveToken('token-b', 'user-b', 'b@mint.test'),
        throwsA(_authRecoveryRequired),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Logout
  // ═══════════════════════════════════════════════════════════════════════

  group('AuthService — logout', () {
    test('logout clears the JWT token', () async {
      await AuthService.saveToken('tok', 'uid', 'a@b.ch');
      await AuthService.clearTokensForSessionTermination();
      final token = await AuthService.getToken();
      expect(token, isNull);
    });

    test('logout clears user ID', () async {
      await AuthService.saveToken('tok', 'uid', 'a@b.ch');
      await AuthService.clearTokensForSessionTermination();
      final userId = await AuthService.getUserId();
      expect(userId, isNull);
    });

    test('logout clears email', () async {
      await AuthService.saveToken('tok', 'uid', 'a@b.ch');
      await AuthService.clearTokensForSessionTermination();
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
      await AuthService.clearTokensForSessionTermination();
      final name = await AuthService.getDisplayName();
      expect(name, isNull);
    });

    test('logout is idempotent (calling twice does not throw)', () async {
      await AuthService.saveToken('tok', 'uid', 'a@b.ch');
      await AuthService.clearTokensForSessionTermination();
      // Second logout should not throw
      await AuthService.clearTokensForSessionTermination();
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
}

final Matcher _authRecoveryRequired = predicate<Object>(
  (error) => error.runtimeType.toString() == 'AuthSessionRecoveryRequired',
  'AuthSessionRecoveryRequired',
);
