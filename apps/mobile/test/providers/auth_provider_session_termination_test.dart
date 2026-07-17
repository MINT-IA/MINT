import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/session_termination_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('explicit logout and terminal 401 await one termination transaction',
      () async {
    final gate = Completer<void>();
    var durableCalls = 0;
    final coordinator = SessionTerminationCoordinator(
      clearAuthTokens: () async {},
      purgeDurableSessionData: () async {
        durableCalls++;
        await gate.future;
      },
      purgeRemainingLocalData: () async {},
      clearSessionMemory: const [],
    );
    final provider = AuthProvider(sessionTerminationCoordinator: coordinator);
    addTearDown(provider.dispose);

    final explicit = provider.logout();
    final terminal401 = provider.handleTerminalSessionExpiry();
    await Future<void>.delayed(Duration.zero);

    expect(provider.isSessionTerminationBlocked, isTrue);
    expect(provider.isLoading, isTrue);
    expect(durableCalls, 1);

    gate.complete();
    await Future.wait([explicit, terminal401]);

    expect(provider.isLoggedIn, isFalse);
    expect(provider.isLocalMode, isFalse);
    expect(provider.isSessionTerminationBlocked, isFalse);
    expect(provider.isLoading, isFalse);
    expect(durableCalls, 1);
  });

  test('purge failure blocks local mode and never reports logout success',
      () async {
    final coordinator = SessionTerminationCoordinator(
      clearAuthTokens: () async {},
      purgeDurableSessionData: () async {
        throw StateError('synthetic financial purge failure');
      },
      purgeRemainingLocalData: () async {},
      clearSessionMemory: const [],
    );
    final provider = AuthProvider(sessionTerminationCoordinator: coordinator);
    addTearDown(provider.dispose);

    await expectLater(provider.logout(), throwsStateError);

    expect(provider.isLoggedIn, isFalse);
    expect(provider.isLocalMode, isFalse);
    expect(provider.isSessionTerminationBlocked, isTrue);
    await expectLater(provider.enableLocalMode(), throwsStateError);
  });

  test('purge failure retains seeded credentials and authenticated identity',
      () async {
    SharedPreferences.setMockInitialValues({
      'local_data_migrated_user-retained': true,
    });
    final coordinator = SessionTerminationCoordinator(
      clearAuthTokens: AuthService.clearTokensForSessionTermination,
      clearAuthRecoveryRequired:
          AuthService.clearRecoveryRequiredForSessionTermination,
      purgeDurableSessionData: () async {
        throw StateError('synthetic retained-session purge failure');
      },
      purgeRemainingLocalData: () async {},
      clearSessionMemory: const [],
    );
    final provider = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      loginAction: (_, __) async => {
        'access_token': 'retained-access-token',
        'refresh_token': 'retained-refresh-token',
        'user_id': 'user-retained',
        'email': 'retained@example.test',
      },
      profileHydrationAction: () async => const <String, dynamic>{},
    );
    addTearDown(provider.dispose);

    expect(await provider.login('retained@example.test', 'synthetic'), isTrue);
    expect(provider.isLoggedIn, isTrue);
    expect(provider.userId, 'user-retained');
    expect(await AuthService.getToken(), 'retained-access-token');

    await expectLater(provider.logout(), throwsStateError);

    expect(provider.isLoggedIn, isTrue);
    expect(provider.userId, 'user-retained');
    expect(provider.email, 'retained@example.test');
    expect(await AuthService.getToken(), 'retained-access-token');
    expect(provider.isSessionTerminationBlocked, isTrue);
    expect(provider.isLocalMode, isFalse);
  });

  test('completion after provider dispose does not notify disposed listeners',
      () async {
    final gate = Completer<void>();
    final coordinator = SessionTerminationCoordinator(
      clearAuthTokens: () async {},
      purgeDurableSessionData: () => gate.future,
      purgeRemainingLocalData: () async {},
      clearSessionMemory: const [],
    );
    final provider = AuthProvider(sessionTerminationCoordinator: coordinator);
    var notifications = 0;
    provider.addListener(() => notifications++);

    final termination = provider.handleTerminalSessionExpiry();
    await Future<void>.delayed(Duration.zero);
    expect(notifications, 1);
    provider.dispose();
    gate.complete();

    await expectLater(termination, throwsStateError);
    expect(notifications, 1);
  });

  test(
      'authenticated account A rejects every identity entry without purge or ledger loss',
      () async {
    SharedPreferences.setMockInitialValues({
      'local_data_migrated_user-a': true,
    });
    var purgeCalls = 0;
    var loginCalls = 0;
    var registerCalls = 0;
    var magicVerifyCalls = 0;
    var magicProfileCalls = 0;
    final coordinator = SessionTerminationCoordinator(
      clearAuthTokens: AuthService.clearTokensForSessionTermination,
      purgeDurableSessionData: () async => purgeCalls++,
      purgeRemainingLocalData: () async {},
      clearSessionMemory: const [],
    );
    final provider = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      loginAction: (email, _) async {
        loginCalls++;
        final isA = email == 'a@mint.test';
        return {
          'access_token': isA ? 'access-a' : 'access-b',
          'refresh_token': isA ? 'refresh-a' : 'refresh-b',
          'user_id': isA ? 'user-a' : 'user-b',
          'email': email,
        };
      },
      registerAction: (email, _, {displayName}) async {
        registerCalls++;
        return {
          'access_token': 'access-b',
          'refresh_token': 'refresh-b',
          'user_id': 'user-b',
          'email': email,
        };
      },
      verifyMagicLinkAction: (_) async {
        magicVerifyCalls++;
        return const {
          'access_token': 'access-b',
          'refresh_token': 'refresh-b',
        };
      },
      magicLinkProfileAction: (_) async {
        magicProfileCalls++;
        return const {'id': 'user-b', 'email': 'b@mint.test'};
      },
      profileHydrationAction: () async => const <String, dynamic>{},
    );
    addTearDown(provider.dispose);

    expect(await provider.login('a@mint.test', 'synthetic-a'), isTrue);
    await ReportPersistenceService.saveAnswers({
      'q_birth_year': 1980,
      'g1_ledger_marker': 'belongs-to-a',
    });
    final beforeAttempt = await ReportPersistenceService.loadAnswers();

    expect(await provider.login('b@mint.test', 'synthetic-b'), isFalse);
    expect(
      await provider.register('b@mint.test', 'synthetic-b'),
      isFalse,
    );
    expect(
      await provider.completeAppleSignIn(const {
        'accessToken': 'access-b',
        'refreshToken': 'refresh-b',
        'userId': 'user-b',
        'email': 'b@mint.test',
      }),
      isFalse,
    );
    expect(await provider.verifyMagicLink('synthetic-b'), isFalse);

    expect(loginCalls, 1);
    expect(registerCalls, 0);
    expect(magicVerifyCalls, 0);
    expect(magicProfileCalls, 0);
    expect(purgeCalls, 0);
    expect(provider.isLoggedIn, isTrue);
    expect(provider.userId, 'user-a');
    expect(await AuthService.getUserId(), 'user-a');
    expect(await AuthService.getToken(), 'access-a');
    expect(await ReportPersistenceService.loadAnswers(), beforeAttempt);
  });

  test(
      'cold corrupt A authority purges before auth-ready and refuses B while blocked',
      () async {
    await ReportPersistenceService.saveAnswers({
      'q_birth_year': 1980,
      'g1_ledger_marker': 'belongs-to-a',
    });
    final ledgerA = await ReportPersistenceService.loadAnswers();
    const secureStorage = FlutterSecureStorage();
    await secureStorage.write(key: 'auth_session_v1', value: '{broken');

    final purgeGate = Completer<void>();
    var loginCalls = 0;
    final coordinator = SessionTerminationCoordinator(
      clearAuthTokens: AuthService.clearTokensForSessionTermination,
      clearAuthRecoveryRequired:
          AuthService.clearRecoveryRequiredForSessionTermination,
      purgeDurableSessionData: () async {
        await purgeGate.future;
        await ReportPersistenceService.clear();
      },
      purgeRemainingLocalData: () async {},
      clearSessionMemory: const [],
    );
    addTearDown(coordinator.dispose);
    final provider = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      loginAction: (_, __) async {
        loginCalls++;
        return const {
          'access_token': 'access-b',
          'refresh_token': 'refresh-b',
          'user_id': 'user-b',
          'email': 'b@mint.test',
        };
      },
      profileHydrationAction: () async => const <String, dynamic>{},
    );
    addTearDown(provider.dispose);

    var coldCheckCompleted = false;
    final coldCheck = provider.checkAuth().whenComplete(() {
      coldCheckCompleted = true;
    });
    await _waitFor(
      () => provider.isSessionTerminationBlocked || coldCheckCompleted,
    );

    final loginB = await provider.login('b@mint.test', 'synthetic');
    expect(provider.isSessionTerminationBlocked, isTrue);
    expect(provider.hasCompletedInitialAuthCheck, isFalse);
    expect(loginB, isFalse);
    expect(loginCalls, 0);
    expect(await ReportPersistenceService.loadAnswers(), ledgerA);
    expect(
      await secureStorage.read(key: 'auth_session_recovery_required_v1'),
      '1',
    );

    purgeGate.complete();
    await coldCheck;

    expect(provider.isSessionTerminationBlocked, isFalse);
    expect(provider.isLoggedIn, isFalse);
    expect(await AuthService.readSessionEnvelope(), isNull);
    expect(await ReportPersistenceService.loadAnswers(), isEmpty);
    expect(
      await secureStorage.read(key: 'auth_session_recovery_required_v1'),
      isNull,
    );
  });
}

Future<void> _waitFor(bool Function() predicate) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('Timed out waiting for cold auth recovery boundary');
}
