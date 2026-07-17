import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/biography_provider.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/household_provider.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/biography/biography_repository.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/pending_auth_identity_store.dart';
import 'package:mint_mobile/services/local_data_claim_attempt_store.dart';
import 'package:mint_mobile/services/session_epoch.dart';
import 'package:mint_mobile/services/session_termination_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DelayedTaxPersistence
    with SerializedCanonicalAnswerMutationPersistence
    implements TaxProfilePersistence {
  _DelayedTaxPersistence(this.loadGate, {this.answers = const {}});

  final Completer<void> loadGate;
  final Map<String, dynamic> answers;
  int saveCalls = 0;

  @override
  Future<Map<String, dynamic>> loadAnswers() async {
    await loadGate.future;
    return Map<String, dynamic>.from(answers);
  }

  @override
  Future<void> saveAnswers(Map<String, dynamic> answers) async {
    saveCalls++;
  }
}

class _MemoryPendingAuthPersistence
    implements
        PendingAuthIdentityPersistence,
        LocalDataClaimAttemptPersistence {
  _MemoryPendingAuthPersistence([Map<String, String>? seed])
      : values = {...?seed};

  final Map<String, String> values;
  bool failReads = false;
  bool failDeletes = false;

  @override
  Future<void> delete(String key) async {
    if (failDeletes) throw StateError('synthetic delete failure');
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    if (failReads) throw StateError('synthetic read failure');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _DelayedBiographyDatabase implements BiographyDatabase {
  final queryGate = Completer<List<Map<String, Object?>>>();

  @override
  Future<void> close() async {}

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {}

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async => 0;

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async => 0;

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) =>
      queryGate.future;

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async => 0;
}

class _DelayedDocumentReferenceStore extends DocumentReferenceStore {
  final loadGate = Completer<List<ConfirmedDocumentReference>>();

  @override
  Future<List<ConfirmedDocumentReference>> load() => loadGate.future;
}

class _SequencedDocumentReferenceStore extends DocumentReferenceStore {
  final loadGates = <Completer<List<ConfirmedDocumentReference>>>[
    Completer<List<ConfirmedDocumentReference>>(),
    Completer<List<ConfirmedDocumentReference>>(),
  ];
  int loadCalls = 0;

  @override
  Future<List<ConfirmedDocumentReference>> load() {
    final gate = loadGates[loadCalls];
    loadCalls += 1;
    return gate.future;
  }
}

class _DelayedSecureStorage extends FlutterSecureStorage {
  final readGate = Completer<String?>();
  final values = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (key == 'byok_provider') return readGate.future;
    return values[key];
  }
}

SessionTerminationCoordinator _coordinator(SessionEpoch epoch) {
  var marker = false;
  return SessionTerminationCoordinator(
    sessionEpoch: epoch,
    readTerminationPending: () async => marker,
    writeTerminationPending: () async => marker = true,
    clearTerminationPending: () async => marker = false,
    cancelNotifications: () async {},
    clearAuthTokens: AuthService.clearTokensForSessionTermination,
    purgeDurableSessionData: () async {},
    purgeRemainingLocalData: () async {},
    clearSessionMemory: const [],
  );
}

FinancialPlan _plan() => FinancialPlan(
      id: 'synthetic-old-session',
      goalDescription: 'Synthetic',
      goalCategory: 'goal_other',
      monthlyTarget: 100,
      milestones: const [],
      projectedOutcome: 1000,
      targetDate: DateTime.utc(2030),
      generatedAt: DateTime.utc(2026),
      profileHashAtGeneration: 'synthetic',
      coachNarrative: 'Synthetic',
      confidenceLevel: 50,
      sources: const [],
      disclaimer: 'Synthetic',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ApiService.debugResetHttpClient();
    ApiService.debugResetSessionTerminationHandler();
    ApiService.debugResetAuthSessionReader();
  });

  tearDown(() {
    ApiService.debugResetHttpClient();
    ApiService.debugResetSessionTerminationHandler();
    ApiService.debugResetAuthSessionReader();
  });

  test('pending identity uses installation-local HMAC without raw identifiers',
      () async {
    final persistence = _MemoryPendingAuthPersistence();
    final store = PendingAuthIdentityStore(persistence: persistence);
    final first = await store.bind(
      email: 'Alice@Example.test',
      userId: 'backend-user-a',
    );
    final encoded = persistence.values[PendingAuthIdentityStore.markerKey]!;

    expect(encoded, isNot(contains('alice@example.test')));
    expect(encoded, isNot(contains('backend-user-a')));
    expect(
      await PendingAuthIdentityStore(persistence: persistence).matches(
        first,
        email: 'alice@example.test',
        userId: 'backend-user-a',
      ),
      isTrue,
    );

    final otherPersistence = _MemoryPendingAuthPersistence();
    await PendingAuthIdentityStore(persistence: otherPersistence).bind(
      email: 'alice@example.test',
      userId: 'backend-user-a',
    );
    expect(
      otherPersistence.values[PendingAuthIdentityStore.markerKey],
      isNot(encoded),
    );
  });

  test('claim attempt reuses exact stamp and advances changed payload',
      () async {
    final persistence = _MemoryPendingAuthPersistence();
    final instant = DateTime.utc(2026, 7, 17, 8);
    final store = LocalDataClaimAttemptStore(
      persistence: persistence,
      now: () => instant,
    );
    final first = await store.resolve(
      deviceId: 'device-a',
      payload: const {
        'local_data_version': 1,
        'wizard_answers': {'q_canton': 'VD', 'q_gross_salary_annual': 96000},
      },
    );
    final retry = await store.resolve(
      deviceId: 'device-a',
      payload: const {
        'wizard_answers': {'q_gross_salary_annual': 96000, 'q_canton': 'VD'},
        'local_data_version': 1,
      },
    );
    final changed = await store.resolve(
      deviceId: 'device-a',
      payload: const {
        'local_data_version': 1,
        'wizard_answers': {'q_canton': 'VD', 'q_gross_salary_annual': 108000},
      },
    );

    expect(retry.payloadFingerprint, first.payloadFingerprint);
    expect(retry.updatedAt, first.updatedAt);
    expect(changed.payloadFingerprint, isNot(first.payloadFingerprint));
    expect(
      changed.updatedAt,
      first.updatedAt.add(const Duration(microseconds: 1)),
    );
    final encoded = persistence.values[LocalDataClaimAttemptStore.markerKey]!;
    expect(encoded, isNot(contains('q_gross_salary_annual')));
    expect(encoded, isNot(contains('108000')));
    await store.clear();
    expect(persistence.values[LocalDataClaimAttemptStore.markerKey], isNull);
    expect(persistence.values[LocalDataClaimAttemptStore.secretKey], isNull);
  });

  test('pending identity corruption and failed purge stay fail closed',
      () async {
    final persistence = _MemoryPendingAuthPersistence();
    final store = PendingAuthIdentityStore(persistence: persistence);
    await store.bind(email: 'a@example.test');
    persistence.values[PendingAuthIdentityStore.markerKey] = '{corrupt';
    await expectLater(store.load(), throwsStateError);

    persistence.failDeletes = true;
    await expectLater(store.clear(), throwsStateError);
    expect(
      persistence.values[PendingAuthIdentityStore.markerKey],
      isNotNull,
    );
  });

  test('cold corrupt pending marker purges to an auth-ready safe state',
      () async {
    final persistence = _MemoryPendingAuthPersistence();
    final pendingStore = PendingAuthIdentityStore(persistence: persistence);
    await pendingStore.bind(email: 'a@example.test');
    persistence.values[PendingAuthIdentityStore.markerKey] = '{corrupt';
    await AuthService.saveToken(
      'token-a',
      'user-a',
      'a@example.test',
      refreshToken: 'refresh-a',
    );
    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    var localReads = 0;
    var hydrationCalls = 0;
    final auth = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      pendingAuthIdentityStore: pendingStore,
      localDataAnswersReader: () async {
        localReads++;
        return const <String, dynamic>{};
      },
      profileHydrationAction: () async {
        hydrationCalls++;
        return const <String, dynamic>{};
      },
    );
    addTearDown(auth.dispose);

    await auth.checkAuth();

    expect(auth.hasCompletedInitialAuthCheck, isTrue);
    expect(auth.isSessionTerminationBlocked, isFalse);
    expect(auth.isLoggedIn, isFalse);
    expect(localReads, 0);
    expect(hydrationCalls, 0);
    expect(await AuthService.getToken(), isNull);
    expect(await pendingStore.load(), isNull);
  });

  test('cold stored B beside pending A purges before any ledger read',
      () async {
    await ReportPersistenceService.saveAnswers(const {
      'q_firstname': 'Alice',
      'q_date_of_birth': '1988-04-02',
      'q_birth_year': 1988,
    });
    final persistence = _MemoryPendingAuthPersistence();
    final pendingStore = PendingAuthIdentityStore(persistence: persistence);
    await pendingStore.bind(
      email: 'a@example.test',
      userId: 'user-a',
    );
    await AuthService.saveToken(
      'token-b',
      'user-b',
      'b@example.test',
      refreshToken: 'refresh-b',
    );
    final epoch = SessionEpoch();
    var terminationPending = false;
    final coordinator = SessionTerminationCoordinator(
      sessionEpoch: epoch,
      readTerminationPending: () async => terminationPending,
      writeTerminationPending: () async => terminationPending = true,
      clearTerminationPending: () async => terminationPending = false,
      cancelNotifications: () async {},
      clearAuthTokens: AuthService.clearTokensForSessionTermination,
      purgeDurableSessionData: ReportPersistenceService.clear,
      purgeRemainingLocalData: () async {},
      clearSessionMemory: const [],
    );
    addTearDown(coordinator.dispose);
    var localReads = 0;
    var hydrationCalls = 0;
    final auth = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      pendingAuthIdentityStore: pendingStore,
      localDataAnswersReader: () async {
        localReads++;
        return const <String, dynamic>{};
      },
      profileHydrationAction: () async {
        hydrationCalls++;
        return const <String, dynamic>{};
      },
    );
    addTearDown(auth.dispose);

    await auth.checkAuth();

    expect(auth.isLoggedIn, isFalse);
    expect(auth.hasCompletedInitialAuthCheck, isTrue);
    expect(auth.isSessionTerminationBlocked, isFalse);
    expect(localReads, 0);
    expect(hydrationCalls, 0);
    expect(await AuthService.getToken(), isNull);
    expect(await pendingStore.load(), isNull);
    expect(await ReportPersistenceService.loadAnswers(), isEmpty);
  });

  test('pending marker purge failure blocks every later identity entry',
      () async {
    final persistence = _MemoryPendingAuthPersistence();
    final pendingStore = PendingAuthIdentityStore(persistence: persistence);
    await pendingStore.bind(email: 'a@example.test', userId: 'user-a');
    await AuthService.saveToken(
      'token-b',
      'user-b',
      'b@example.test',
      refreshToken: 'refresh-b',
    );
    persistence.failDeletes = true;
    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    var loginCalls = 0;
    final auth = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      pendingAuthIdentityStore: pendingStore,
      loginAction: (email, _) async {
        loginCalls++;
        return {
          'access_token': 'token-b',
          'user_id': 'user-b',
          'email': email,
        };
      },
    );
    addTearDown(auth.dispose);

    await auth.checkAuth();

    expect(auth.isSessionTerminationBlocked, isTrue);
    expect(auth.isLoggedIn, isFalse);
    expect(
      await auth.login('b@example.test', 'synthetic-b'),
      isFalse,
    );
    expect(loginCalls, 0);
    expect(
      persistence.values[PendingAuthIdentityStore.markerKey],
      isNotNull,
    );
  });

  test('claim attempt purge failure blocks every later identity entry',
      () async {
    final persistence = _MemoryPendingAuthPersistence();
    final claimStore = LocalDataClaimAttemptStore(persistence: persistence);
    await claimStore.resolve(
      deviceId: 'device-a',
      payload: const {
        'wizard_answers': {'q_canton': 'VD'}
      },
    );
    persistence.failDeletes = true;
    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    var loginCalls = 0;
    final auth = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      localDataClaimAttemptStore: claimStore,
      loginAction: (email, _) async {
        loginCalls++;
        return {
          'access_token': 'token-b',
          'user_id': 'user-b',
          'email': email,
        };
      },
    );
    addTearDown(auth.dispose);

    await expectLater(auth.logout(), throwsStateError);

    expect(auth.isSessionTerminationBlocked, isTrue);
    expect(await auth.login('b@example.test', 'synthetic-b'), isFalse);
    expect(loginCalls, 0);
    expect(
      persistence.values[LocalDataClaimAttemptStore.markerKey],
      isNotNull,
    );
  });

  test('cold stored A releases its exact pending marker only after migration',
      () async {
    SharedPreferences.setMockInitialValues({
      'local_data_migrated_user-a': true,
    });
    final persistence = _MemoryPendingAuthPersistence();
    final pendingStore = PendingAuthIdentityStore(persistence: persistence);
    await pendingStore.bind(
      email: 'a@example.test',
      userId: 'user-a',
    );
    await AuthService.saveToken(
      'token-a',
      'user-a',
      'a@example.test',
      refreshToken: 'refresh-a',
    );
    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    final auth = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      pendingAuthIdentityStore: pendingStore,
      profileHydrationAction: () async => const <String, dynamic>{},
    );
    addTearDown(auth.dispose);

    await auth.checkAuth();

    expect(auth.isLoggedIn, isTrue);
    expect(auth.userId, 'user-a');
    expect(await pendingStore.load(), isNull);
  });

  test('failed claim reserves A and cold A retries the identical payload',
      () async {
    SharedPreferences.setMockInitialValues({});
    final persistence = _MemoryPendingAuthPersistence();
    final pendingStore = PendingAuthIdentityStore(persistence: persistence);
    await pendingStore.bind(email: 'a@example.test');
    final claimBodies = <String>[];
    var claimCalls = 0;
    ApiService.debugUseHttpClient(MockClient((request) async {
      if (request.url.path.endsWith('/sync/claim-local-data')) {
        claimCalls++;
        claimBodies.add(request.body);
        if (claimCalls == 1) {
          return http.Response('{"detail":"synthetic failure"}', 500);
        }
        return http.Response('{"claimed":true}', 200);
      }
      return http.Response('{}', 200);
    }));
    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    final binding = ApiService.bindSessionTerminationHandler(
      coordinator.terminate,
      sessionEpoch: epoch,
    );
    addTearDown(binding.dispose);
    final ledger = <String, dynamic>{
      'q_canton': 'VD',
      'q_gross_salary_annual': 96000,
    };
    Future<Map<String, dynamic>> loginA(String _, String __) async => const {
          'access_token': 'token-a',
          'refresh_token': 'refresh-a',
          'user_id': 'user-a',
          'email': 'a@example.test',
        };
    final first = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      pendingAuthIdentityStore: pendingStore,
      loginAction: loginA,
      localDataAnswersReader: () async => Map<String, dynamic>.from(ledger),
      profileHydrationAction: () async => const <String, dynamic>{},
    );
    expect(await first.login('a@example.test', 'synthetic-a'), isTrue);
    final afterFailure = await SharedPreferences.getInstance();
    expect(afterFailure.getString('local_data_owner'), 'user-a');
    expect(afterFailure.getBool('local_data_migrated_user-a'), isNot(true));
    expect(await pendingStore.load(), isNotNull);
    first.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 5));

    var bLoginCalls = 0;
    final coldB = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      pendingAuthIdentityStore: pendingStore,
      loginAction: (email, _) async {
        bLoginCalls++;
        return {
          'access_token': 'token-b',
          'user_id': 'user-b',
          'email': email,
        };
      },
    );
    expect(await coldB.login('b@example.test', 'synthetic-b'), isFalse);
    expect(bLoginCalls, 0);
    coldB.dispose();

    final coldA = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      pendingAuthIdentityStore: pendingStore,
      localDataAnswersReader: () async => Map<String, dynamic>.from(ledger),
      profileHydrationAction: () async => const <String, dynamic>{},
    );
    addTearDown(coldA.dispose);
    await coldA.checkAuth();

    final afterRetry = await SharedPreferences.getInstance();
    expect(claimCalls, 2);
    expect(jsonDecode(claimBodies[1]), jsonDecode(claimBodies[0]));
    expect(afterRetry.getBool('local_data_migrated_user-a'), isTrue);
    expect(await pendingStore.load(), isNull);
  });

  test('ledger change during claim requires a newer acknowledged attempt',
      () async {
    SharedPreferences.setMockInitialValues({});
    final persistence = _MemoryPendingAuthPersistence();
    final pendingStore = PendingAuthIdentityStore(persistence: persistence);
    final claimStore = LocalDataClaimAttemptStore(persistence: persistence);
    await pendingStore.bind(email: 'a@example.test');
    final claimStarted = Completer<void>();
    final releaseFirstClaim = Completer<void>();
    final claimBodies = <Map<String, dynamic>>[];
    ApiService.debugUseHttpClient(MockClient((request) async {
      if (request.url.path.endsWith('/sync/claim-local-data')) {
        claimBodies.add(
          Map<String, dynamic>.from(jsonDecode(request.body) as Map),
        );
        if (claimBodies.length == 1) {
          claimStarted.complete();
          await releaseFirstClaim.future;
        }
        return http.Response('{"claimed":true}', 200);
      }
      return http.Response('{}', 200);
    }));
    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    final binding = ApiService.bindSessionTerminationHandler(
      coordinator.terminate,
      sessionEpoch: epoch,
    );
    addTearDown(binding.dispose);
    final ledger = <String, dynamic>{'q_gross_salary_annual': 96000};
    final first = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      pendingAuthIdentityStore: pendingStore,
      localDataClaimAttemptStore: claimStore,
      loginAction: (email, _) async => {
        'access_token': 'token-a',
        'refresh_token': 'refresh-a',
        'user_id': 'user-a',
        'email': email,
      },
      localDataAnswersReader: () async => Map<String, dynamic>.from(ledger),
      profileHydrationAction: () async => const <String, dynamic>{},
    );
    final login = first.login('a@example.test', 'synthetic-a');
    await claimStarted.future;
    ledger['q_gross_salary_annual'] = 108000;
    releaseFirstClaim.complete();
    expect(await login, isTrue);

    final afterFirstAck = await SharedPreferences.getInstance();
    expect(afterFirstAck.getBool('local_data_migrated_user-a'), isNot(true));
    expect(await pendingStore.load(), isNotNull);
    first.dispose();

    final cold = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      pendingAuthIdentityStore: pendingStore,
      localDataClaimAttemptStore: claimStore,
      localDataAnswersReader: () async => Map<String, dynamic>.from(ledger),
      profileHydrationAction: () async => const <String, dynamic>{},
    );
    addTearDown(cold.dispose);
    await cold.checkAuth();

    expect(claimBodies, hasLength(2));
    final firstStamp = DateTime.parse(claimBodies[0]['updated_at'] as String);
    final secondStamp = DateTime.parse(claimBodies[1]['updated_at'] as String);
    expect(secondStamp.isAfter(firstStamp), isTrue);
    expect(
      (claimBodies[0]['wizard_answers'] as Map)['q_gross_salary_annual'],
      96000,
    );
    expect(
      (claimBodies[1]['wizard_answers'] as Map)['q_gross_salary_annual'],
      108000,
    );
    final afterSecondAck = await SharedPreferences.getInstance();
    expect(afterSecondAck.getBool('local_data_migrated_user-a'), isTrue);
    expect(await pendingStore.load(), isNull);
  });

  test('claim device id is verified durably before any network claim', () {
    final source = File('lib/providers/auth_provider.dart').readAsStringSync();
    final start = source.indexOf("prefs.getString('_mint_device_id')");
    final end = source.indexOf('await ApiService.claimLocalData', start);
    final block = source.substring(start, end);

    expect(block, contains('final deviceIdWritten ='));
    expect(block, contains("await prefs.setString('_mint_device_id'"));
    expect(block, contains("prefs.getString('_mint_device_id') != deviceId"));
    expect(
        block, contains("throw StateError('Claim device id commit failed')"));
  });

  test('delayed old login cannot restore tokens after termination', () async {
    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    final loginGate = Completer<Map<String, dynamic>>();
    final auth = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      loginAction: (_, __) => loginGate.future,
    );
    addTearDown(auth.dispose);

    final login = auth.login('old@example.test', 'synthetic');
    await Future<void>.delayed(Duration.zero);
    await auth.logout();
    loginGate.complete({
      'access_token': 'late-old-token',
      'refresh_token': 'late-old-refresh',
      'user_id': 'old-user',
      'email': 'old@example.test',
    });

    expect(await login, isFalse);
    expect(await AuthService.getToken(), isNull);
    expect(auth.isLoggedIn, isFalse);
  });

  test('late login failure cannot publish an old-session auth error', () async {
    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    final gate = Completer<Map<String, dynamic>>();
    final auth = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      loginAction: (_, __) => gate.future,
    );
    addTearDown(auth.dispose);
    var notifications = 0;
    auth.addListener(() => notifications++);

    final login = auth.login('old@example.test', 'synthetic');
    await Future<void>.delayed(Duration.zero);
    await coordinator.terminate();
    final beforeLateFailure = notifications;
    gate.completeError(StateError('late old login failure'));

    expect(await login, isFalse);
    expect(auth.error, isNull);
    expect(notifications, beforeLateFailure);
  });

  test('late register failure cannot publish an old-session auth error',
      () async {
    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    final gate = Completer<Map<String, dynamic>>();
    final auth = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      registerAction: (_, __, {displayName}) => gate.future,
    );
    addTearDown(auth.dispose);

    final register = auth.register('old@example.test', 'synthetic');
    await Future<void>.delayed(Duration.zero);
    await coordinator.terminate();
    gate.completeError(StateError('late old register failure'));

    expect(await register, isFalse);
    expect(auth.error, isNull);
  });

  test('identity entry admission blocks login during tokenless registration',
      () async {
    SharedPreferences.setMockInitialValues({
      'local_data_migrated_user-a': true,
      'local_data_migrated_user-b': true,
    });
    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    final registration = Completer<Map<String, dynamic>>();
    var loginCalls = 0;
    final auth = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      registerAction: (_, __, {displayName}) => registration.future,
      loginAction: (_, __) async {
        loginCalls++;
        return {
          'access_token': 'token-b',
          'refresh_token': 'refresh-b',
          'user_id': 'user-b',
          'email': 'b@example.test',
        };
      },
      profileHydrationAction: () async => const <String, dynamic>{},
    );
    addTearDown(auth.dispose);

    final register = auth.register(
      'a@example.test',
      'synthetic-a',
      displayName: 'Alice',
    );
    await Future<void>.delayed(Duration.zero);

    expect(await auth.login('b@example.test', 'synthetic-b'), isFalse);
    expect(loginCalls, 0);

    registration.complete({
      'requires_email_verification': true,
      'user_id': 'user-a',
      'email': 'a@example.test',
      'display_name': 'Alice',
    });
    expect(await register, isTrue);
    expect(auth.userId, 'user-a');
  });

  test('new epoch replaces a hung identity lease without old finally release',
      () async {
    SharedPreferences.setMockInitialValues({
      'local_data_migrated_user-b': true,
    });
    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    final loginA = Completer<Map<String, dynamic>>();
    final loginB = Completer<Map<String, dynamic>>();
    var registerCalls = 0;
    final auth = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      loginAction: (email, _) =>
          email.startsWith('a@') ? loginA.future : loginB.future,
      registerAction: (_, __, {displayName}) async {
        registerCalls++;
        return const <String, dynamic>{};
      },
      profileHydrationAction: () async => const <String, dynamic>{},
    );
    addTearDown(auth.dispose);

    final oldLogin = auth.login('a@example.test', 'synthetic-a');
    await Future<void>.delayed(Duration.zero);
    await auth.logout();

    final newLogin = auth.login('b@example.test', 'synthetic-b');
    await Future<void>.delayed(Duration.zero);
    loginA.complete({
      'access_token': 'token-a',
      'refresh_token': 'refresh-a',
      'user_id': 'user-a',
      'email': 'a@example.test',
    });
    expect(await oldLogin, isFalse);

    expect(
      await auth.register('c@example.test', 'synthetic-c'),
      isFalse,
    );
    expect(registerCalls, 0);

    loginB.complete({
      'access_token': 'token-b',
      'refresh_token': 'refresh-b',
      'user_id': 'user-b',
      'email': 'b@example.test',
    });
    expect(await newLogin, isTrue);
    expect(auth.userId, 'user-b');
  });

  test('tokenless registration writes identity through the guarded ledger',
      () async {
    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    Map<String, dynamic>? written;
    AuthProfileAnswerTrust? writtenTrust;
    final auth = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      registerAction: (_, __, {displayName}) async => {
        'requires_email_verification': true,
        'user_id': 'user-a',
        'email': 'a@example.test',
        'display_name': displayName,
      },
      profileAnswerWriter: (answers, trust, _) async {
        written = Map<String, dynamic>.from(answers);
        writtenTrust = trust;
      },
    );
    addTearDown(auth.dispose);

    expect(
      await auth.register(
        'a@example.test',
        'synthetic-a',
        displayName: 'Alice',
        dateOfBirth: DateTime(1988, 4, 2),
      ),
      isTrue,
    );

    expect(writtenTrust, AuthProfileAnswerTrust.userInput);
    expect(written, {
      'q_firstname': 'Alice',
      'q_birth_year': 1988,
      'q_date_of_birth': '1988-04-02',
    });
  });

  test('registration persists explicit identity before any backend call',
      () async {
    SharedPreferences.setMockInitialValues({
      'local_data_migrated_user-b': true,
    });
    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    var backendCalls = 0;
    final events = <String>[];
    final possiblyDurableAnswers = <String, dynamic>{};
    final auth = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      registerAction: (_, __, {displayName}) async {
        backendCalls++;
        events.add('backend');
        return const <String, dynamic>{};
      },
      profileAnswerWriter: (answers, _, __) async {
        events.add('ledger');
        possiblyDurableAnswers.addAll(answers);
        throw StateError('synthetic canonical writer failure');
      },
    );
    addTearDown(auth.dispose);

    expect(
      await auth.register(
        'a@example.test',
        'synthetic-a',
        displayName: 'Alice',
        dateOfBirth: DateTime(1988, 4, 2),
      ),
      isFalse,
    );

    expect(events, ['ledger']);
    expect(backendCalls, 0);
    expect(auth.isLoggedIn, isFalse);
    expect(await AuthService.getToken(), isNull);
    expect(possiblyDurableAnswers['q_firstname'], 'Alice');
    expect(possiblyDurableAnswers['q_date_of_birth'], '1988-04-02');

    auth.dispose();
    var loginCalls = 0;
    final cold = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      initialAuthAction: () async => false,
      loginAction: (email, _) async {
        loginCalls++;
        final suffix = email.startsWith('a@') ? 'a' : 'b';
        return {
          'access_token': 'token-$suffix',
          'refresh_token': 'refresh-$suffix',
          'user_id': 'user-$suffix',
          'email': email,
        };
      },
      profileHydrationAction: () async => const <String, dynamic>{},
    );
    addTearDown(cold.dispose);
    await cold.checkAuth();
    expect(await cold.login('b@example.test', 'synthetic-b'), isFalse);
    expect(loginCalls, 0);
    expect(await cold.login('a@example.test', 'synthetic-a'), isTrue);
    expect(loginCalls, 1);
  });

  test('backend failure leaves a cold durable identity guard for retry',
      () async {
    SharedPreferences.setMockInitialValues({
      'local_data_migrated_user-a': true,
      'local_data_migrated_user-b': true,
    });
    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    final events = <String>[];
    final coach = CoachProfileProvider(sessionEpoch: epoch);
    addTearDown(coach.dispose);
    final first = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      registerAction: (_, __, {displayName}) async {
        events.add('backend');
        throw StateError('synthetic backend failure');
      },
      profileAnswerWriter: (answers, trust, sessionGuard) async {
        expect(trust, AuthProfileAnswerTrust.userInput);
        events.add('ledger');
        await coach.mergeAnswersWithProvenance(
          answers,
          source: ProfileDataSource.userInput,
          sessionGuard: sessionGuard,
        );
      },
    );

    expect(
      await first.register(
        'a@example.test',
        'synthetic-a',
        displayName: 'Alice',
        dateOfBirth: DateTime(1988, 4, 2),
      ),
      isFalse,
    );
    expect(events, ['ledger', 'backend']);
    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted['q_firstname'], 'Alice');
    expect(persisted['q_birth_year'], 1988);
    expect(persisted['q_date_of_birth'], '1988-04-02');
    final provenance = Map<String, dynamic>.from(
      persisted['__provenance'] as Map,
    );
    expect(provenance['firstName'], containsPair('source', 'userInput'));
    expect(provenance['birthYear'], containsPair('source', 'userInput'));
    expect(provenance['dateOfBirth'], containsPair('source', 'userInput'));

    final coldProfile = CoachProfileProvider(sessionEpoch: epoch);
    addTearDown(coldProfile.dispose);
    await coldProfile.loadFromWizard();
    expect(coldProfile.profile?.firstName, 'Alice');
    expect(coldProfile.profile?.birthYear, 1988);
    expect(coldProfile.profile?.dateOfBirth, DateTime(1988, 4, 2));
    first.dispose();

    var loginCalls = 0;
    final cold = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      initialAuthAction: () async => false,
      loginAction: (email, _) async {
        loginCalls++;
        return {
          'access_token': 'token-a',
          'refresh_token': 'refresh-a',
          'user_id': 'user-a',
          'email': email,
        };
      },
      profileHydrationAction: () async => const <String, dynamic>{},
    );
    addTearDown(cold.dispose);
    await cold.checkAuth();

    expect(await cold.login('b@example.test', 'synthetic-b'), isFalse);
    expect(loginCalls, 0);
    expect(await AuthService.getToken(), isNull);

    expect(await cold.login('a@example.test', 'synthetic-a'), isTrue);
    expect(loginCalls, 1);
    expect(cold.userId, 'user-a');
  });

  test('tokenless A blocks cold login B before read/network then admits A',
      () async {
    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    final first = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      registerAction: (_, __, {displayName}) async => {
        'requires_email_verification': true,
        'user_id': 'user-a',
        'email': 'a@example.test',
        'display_name': displayName,
      },
      profileAnswerWriter: (_, __, ___) async {},
    );
    expect(
      await first.register(
        'a@example.test',
        'synthetic-a',
        displayName: 'Alice',
      ),
      isTrue,
    );
    first.dispose();

    var loginCalls = 0;
    var localReads = 0;
    final cold = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      initialAuthAction: () async => false,
      loginAction: (email, _) async {
        loginCalls++;
        return {
          'access_token': 'token-a',
          'refresh_token': 'refresh-a',
          'user_id': 'user-a',
          'email': email,
        };
      },
      localDataAnswersReader: () async {
        localReads++;
        return const <String, dynamic>{};
      },
      profileHydrationAction: () async => const <String, dynamic>{},
    );
    addTearDown(cold.dispose);
    await cold.checkAuth();

    expect(await cold.login('b@example.test', 'synthetic-b'), isFalse);
    expect(loginCalls, 0);
    expect(localReads, 0);
    expect(await AuthService.getToken(), isNull);

    expect(await cold.login('a@example.test', 'synthetic-a'), isTrue);
    expect(loginCalls, 1);
    // The claim transport is deliberately unbound in this provider-only test,
    // so same-operation validation fails before the ledger reader runs.
    expect(localReads, 0);
    expect(cold.userId, 'user-a');
  });

  for (final backendBirthYear in <int>[1988, 1975]) {
    test(
        'registration exact DOB survives ${backendBirthYear == 1988 ? 'identical' : 'discordant'} backend birth year warm and cold',
        () async {
      SharedPreferences.setMockInitialValues({
        'local_data_migrated_user-a': true,
      });
      final epoch = SessionEpoch();
      final coordinator = _coordinator(epoch);
      addTearDown(coordinator.dispose);
      final coach = CoachProfileProvider(sessionEpoch: epoch);
      addTearDown(coach.dispose);
      final events = <String>[];
      Map<String, dynamic>? beforeBackend;
      final auth = AuthProvider(
        sessionTerminationCoordinator: coordinator,
        registerAction: (_, __, {displayName}) async {
          beforeBackend = await ReportPersistenceService.loadAnswers();
          events.add('backend');
          return {
            'access_token': 'token-a',
            'refresh_token': 'refresh-a',
            'user_id': 'user-a',
            'email': 'a@example.test',
            'display_name': displayName,
          };
        },
        profileHydrationAction: () async {
          events.add('hydrate');
          return {
            'data': {'birthYear': backendBirthYear},
          };
        },
        profileAnswerWriter: (answers, trust, sessionGuard) async {
          events.add(
            trust == AuthProfileAnswerTrust.userInput
                ? 'ledger:userInput'
                : 'ledger:backendUnknown',
          );
          switch (trust) {
            case AuthProfileAnswerTrust.userInput:
              await coach.mergeAnswersWithProvenance(
                answers,
                source: ProfileDataSource.userInput,
                sessionGuard: sessionGuard,
              );
            case AuthProfileAnswerTrust.backendUnknown:
              await coach.mergeBackendUnknownProfile(
                answers,
                sessionGuard: sessionGuard,
              );
          }
        },
      );
      addTearDown(auth.dispose);

      expect(
        await auth.register(
          'a@example.test',
          'synthetic-a',
          displayName: 'Alice',
          dateOfBirth: DateTime(1988, 4, 2),
        ),
        isTrue,
      );
      expect(events, [
        'ledger:userInput',
        'backend',
        'hydrate',
        'ledger:backendUnknown',
      ]);
      expect(beforeBackend?['q_birth_year'], 1988);
      expect(beforeBackend?['q_date_of_birth'], '1988-04-02');

      final persisted = await ReportPersistenceService.loadAnswers();
      expect(persisted['q_birth_year'], 1988);
      expect(persisted['q_date_of_birth'], '1988-04-02');
      expect(
        persisted[coachBackendUnknownPathsKey] as List? ?? const <String>[],
        isNot(contains('birthYear')),
      );
      expect(coach.profile?.birthYear, 1988);
      expect(coach.profile?.dateOfBirth, DateTime(1988, 4, 2));
      expect(coach.profile?.userProvidedFields, contains('age'));
      expect(
        coach.profile?.dataSources['birthYear'],
        ProfileDataSource.userInput,
      );
      expect(
        coach.profile?.dataSources['dateOfBirth'],
        ProfileDataSource.userInput,
      );

      final cold = CoachProfileProvider(sessionEpoch: epoch);
      addTearDown(cold.dispose);
      await cold.loadFromWizard();
      expect(cold.profile?.birthYear, 1988);
      expect(cold.profile?.dateOfBirth, DateTime(1988, 4, 2));
      expect(cold.profile?.userProvidedFields, contains('age'));
      expect(
        cold.profile?.dataSources['dateOfBirth'],
        ProfileDataSource.userInput,
      );
    });
  }

  test('tokenless identity guard survives cold start and blocks Apple B',
      () async {
    SharedPreferences.setMockInitialValues({
      'local_data_migrated_user-b': true,
    });
    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    final first = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      registerAction: (_, __, {displayName}) async => {
        'requires_email_verification': true,
        'user_id': 'user-a',
        'email': 'a@example.test',
        'display_name': displayName,
      },
      profileAnswerWriter: (_, __, ___) async {},
    );
    expect(
      await first.register(
        'a@example.test',
        'synthetic-a',
        displayName: 'Alice',
      ),
      isTrue,
    );
    first.dispose();

    final cold = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      initialAuthAction: () async => false,
      profileHydrationAction: () async => const <String, dynamic>{},
    );
    addTearDown(cold.dispose);
    await cold.checkAuth();

    expect(
      await cold.completeAppleSignIn({
        'accessToken': 'token-b',
        'refreshToken': 'refresh-b',
        'userId': 'user-b',
        'email': 'b@example.test',
      }),
      isFalse,
    );
    expect(await AuthService.getToken(), isNull);
    expect(cold.isLoggedIn, isFalse);
  });

  test('tokenless identity guard post-validates magic-link B before save',
      () async {
    SharedPreferences.setMockInitialValues({
      'local_data_migrated_user-b': true,
    });
    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    final first = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      registerAction: (_, __, {displayName}) async => {
        'requires_email_verification': true,
        'user_id': 'user-a',
        'email': 'a@example.test',
        'display_name': displayName,
      },
      profileAnswerWriter: (_, __, ___) async {},
    );
    expect(
      await first.register(
        'a@example.test',
        'synthetic-a',
        displayName: 'Alice',
      ),
      isTrue,
    );
    first.dispose();

    final cold = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      initialAuthAction: () async => false,
      verifyMagicLinkAction: (_) async => {
        'accessToken': 'magic-token-b',
        'refreshToken': 'magic-refresh-b',
      },
      magicLinkProfileAction: (_) async => {
        'id': 'user-b',
        'email': 'b@example.test',
      },
      profileHydrationAction: () async => const <String, dynamic>{},
    );
    addTearDown(cold.dispose);
    await cold.checkAuth();

    expect(await cold.verifyMagicLink('synthetic-magic-b'), isFalse);
    expect(await AuthService.getToken(), isNull);
    expect(cold.isLoggedIn, isFalse);
  });

  test('late Apple hydration failure cannot publish old-session state',
      () async {
    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    final hydration = Completer<Map<String, dynamic>>();
    final auth = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      profileHydrationAction: () => hydration.future,
    );
    addTearDown(auth.dispose);

    final apple = auth.completeAppleSignIn({
      'accessToken': 'old-apple-token',
      'userId': 'old-apple-user',
      'email': 'old-apple@example.test',
    });
    await Future<void>.delayed(Duration.zero);
    await auth.logout();
    hydration.completeError(StateError('late old Apple failure'));

    expect(await apple, isFalse);
    expect(auth.error, isNull);
    expect(auth.isLoggedIn, isFalse);
    expect(await AuthService.getToken(), isNull);
  });

  test('late magic-link send failure cannot publish old-session error',
      () async {
    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    final gate = Completer<void>();
    final auth = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      sendMagicLinkAction: (_) => gate.future,
    );
    addTearDown(auth.dispose);

    final send = auth.sendMagicLink('old@example.test');
    await Future<void>.delayed(Duration.zero);
    await coordinator.terminate();
    gate.completeError(StateError('late old magic-link failure'));

    expect(await send, isFalse);
    expect(auth.error, isNull);
  });

  test('late magic-link verify failure cannot publish old-session error',
      () async {
    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    final gate = Completer<Map<String, dynamic>>();
    final auth = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      verifyMagicLinkAction: (_) => gate.future,
    );
    addTearDown(auth.dispose);

    final verify = auth.verifyMagicLink('old-token');
    await Future<void>.delayed(Duration.zero);
    await coordinator.terminate();
    gate.completeError(StateError('late old magic-link failure'));

    expect(await verify, isFalse);
    expect(auth.error, isNull);
  });

  test('magic-link persists only one complete identity after ephemeral getMe',
      () async {
    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    var ephemeralReads = 0;
    final auth = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      verifyMagicLinkAction: (_) async => {
        'accessToken': 'magic-access',
        'refreshToken': 'magic-refresh',
      },
      magicLinkProfileAction: (accessToken) async {
        ephemeralReads++;
        expect(accessToken, 'magic-access');
        expect(await AuthService.getToken(), isNull);
        expect(await AuthService.isLoggedIn(), isFalse);
        return {
          'id': 'magic-user',
          'email': 'magic@mint.test',
          'display_name': 'Magic User',
        };
      },
      profileHydrationAction: () async => const <String, dynamic>{},
    );
    addTearDown(auth.dispose);

    expect(await auth.verifyMagicLink('synthetic-magic-token'), isTrue);

    expect(ephemeralReads, 1);
    expect(auth.isLoggedIn, isTrue);
    expect(auth.userId, 'magic-user');
    expect(auth.email, 'magic@mint.test');
    expect(await AuthService.getToken(), 'magic-access');
    expect(await AuthService.getRefreshToken(), 'magic-refresh');
    expect(await AuthService.getUserId(), 'magic-user');
    expect(await AuthService.getUserEmail(), 'magic@mint.test');
  });

  test('delayed magic-link identity cannot persist after epoch invalidation',
      () async {
    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    final identityGate = Completer<Map<String, dynamic>>();
    final auth = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      verifyMagicLinkAction: (_) async => {'accessToken': 'late-magic-access'},
      magicLinkProfileAction: (_) => identityGate.future,
    );
    addTearDown(auth.dispose);

    final verify = auth.verifyMagicLink('synthetic-magic-token');
    await Future<void>.delayed(Duration.zero);
    expect(await AuthService.getToken(), isNull);
    await coordinator.terminate();
    identityGate.complete({
      'id': 'late-magic-user',
      'email': 'late-magic@mint.test',
    });

    expect(await verify, isFalse);
    expect(auth.isLoggedIn, isFalse);
    expect(auth.userId, isNull);
    expect(await AuthService.getToken(), isNull);
    expect(await AuthService.isLoggedIn(), isFalse);
  });

  test('late initial auth failure cannot publish after session invalidation',
      () async {
    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    final gate = Completer<bool>();
    final auth = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      initialAuthAction: () => gate.future,
    );
    addTearDown(auth.dispose);
    var notifications = 0;
    auth.addListener(() => notifications++);

    final check = auth.checkAuth();
    await Future<void>.delayed(Duration.zero);
    await coordinator.terminate();
    final beforeLateFailure = notifications;
    gate.completeError(StateError('late old checkAuth failure'));
    await check;

    expect(auth.error, isNull);
    expect(notifications, beforeLateFailure);
  });

  test('delayed old coach load cannot publish after termination', () async {
    final epoch = SessionEpoch();
    final gate = Completer<void>();
    final persistence = _DelayedTaxPersistence(gate, answers: {
      'q_birth_year': 1976,
      'q_canton': 'VD',
    });
    final coach = CoachProfileProvider(
      taxProfilePersistence: persistence,
      sessionEpoch: epoch,
    );
    addTearDown(coach.dispose);
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);

    final load = coach.loadFromWizard();
    await Future<void>.delayed(Duration.zero);
    final termination = coordinator.terminate();
    gate.complete();
    await termination;
    await load;

    expect(coach.profile, isNull);
    expect(coach.canonicalProfileOwnerId, isNull);
  });

  test('delayed high-stakes owner mutation performs no late write', () async {
    final epoch = SessionEpoch();
    final gate = Completer<void>();
    final persistence = _DelayedTaxPersistence(gate);
    final coach = CoachProfileProvider(
      taxProfilePersistence: persistence,
      sessionEpoch: epoch,
    );
    addTearDown(coach.dispose);
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);

    final owner = coach.ensureCanonicalProfileOwner();
    final ownerExpectation =
        expectLater(owner, throwsA(isA<SessionEpochInvalidated>()));
    await Future<void>.delayed(Duration.zero);
    final termination = coordinator.terminate();
    gate.complete();

    await termination;

    await ownerExpectation;
    expect(persistence.saveCalls, 0);
    expect(coach.canonicalProfileOwnerId, isNull);
  });

  test('delayed old financial-plan load cannot publish after termination',
      () async {
    final epoch = SessionEpoch();
    final gate = Completer<FinancialPlan?>();
    final plans = FinancialPlanProvider(
      sessionEpoch: epoch,
      loadAction: () => gate.future,
    );
    addTearDown(plans.dispose);
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);

    final load = plans.loadFromPersistence();
    await Future<void>.delayed(Duration.zero);
    await coordinator.terminate();
    gate.complete(_plan());
    await load;

    expect(plans.currentPlan, isNull);
  });

  test('delayed document hydration cannot publish after termination', () async {
    final epoch = SessionEpoch();
    final store = _DelayedDocumentReferenceStore();
    final documents = DocumentProvider(
      sessionEpoch: epoch,
      referenceStore: store,
    );
    addTearDown(documents.dispose);
    final coordinator = SessionTerminationCoordinator(
      sessionEpoch: epoch,
      readTerminationPending: () async => false,
      writeTerminationPending: () async {},
      clearTerminationPending: () async {},
      cancelNotifications: () async {},
      clearAuthTokens: () async {},
      purgeDurableSessionData: () async {},
      purgeRemainingLocalData: () async {},
      clearSessionMemory: [documents.clearLocalState],
    );
    addTearDown(coordinator.dispose);

    final hydrate = documents.hydrateReferences();
    await Future<void>.delayed(Duration.zero);
    await coordinator.terminate();
    store.loadGate.complete(const []);
    await hydrate;

    expect(
      documents.referenceHydrationState,
      DocumentReferenceHydrationState.idle,
    );
    expect(documents.currentReferences, isEmpty);
  });

  test('new session document hydration never joins the invalidated load',
      () async {
    final epoch = SessionEpoch();
    final store = _SequencedDocumentReferenceStore();
    final documents = DocumentProvider(
      sessionEpoch: epoch,
      referenceStore: store,
    );
    addTearDown(documents.dispose);
    final reference = ConfirmedDocumentReference(
      referenceId: '11111111-1111-4111-8111-111111111111',
      kind: ConfirmedDocumentReference.lppKind,
      snapshotId: '22222222-2222-4222-8222-222222222222',
      ownerKind: LppEvidenceOwnerKind.self,
      confirmedAt: DateTime.utc(2026, 7, 17, 8),
    );

    final sessionAHydration = documents.hydrateReferences();
    final sameSessionAHydration = documents.hydrateReferences();
    await Future<void>.delayed(Duration.zero);
    expect(store.loadCalls, 1, reason: 'one generation hydrates exactly once');

    epoch.beginTermination();
    documents.clearLocalState();
    epoch.completeTermination();
    final sessionBHydration = documents.hydrateReferences();
    await Future<void>.delayed(Duration.zero);

    try {
      expect(
        store.loadCalls,
        2,
        reason: 'session B must own a fresh reference-store read',
      );
      store.loadGates[1].complete(<ConfirmedDocumentReference>[reference]);
      await sessionBHydration;
      expect(documents.referenceHydrationState,
          DocumentReferenceHydrationState.ready);
      expect(documents.hasStoredReference(reference.referenceId), isTrue);
    } finally {
      if (!store.loadGates[0].isCompleted) {
        store.loadGates[0].complete(const <ConfirmedDocumentReference>[]);
      }
      if (!store.loadGates[1].isCompleted) {
        store.loadGates[1].complete(const <ConfirmedDocumentReference>[]);
      }
      await Future.wait(<Future<void>>[
        sessionAHydration,
        sameSessionAHydration,
        sessionBHydration,
      ]);
    }
  });

  test('delayed household load cannot restore old members or error', () async {
    final epoch = SessionEpoch();
    final loadGate = Completer<Map<String, dynamic>?>();
    final household = HouseholdProvider(
      sessionEpoch: epoch,
      loadAction: () => loadGate.future,
    );
    addTearDown(household.dispose);
    final coordinator = SessionTerminationCoordinator(
      sessionEpoch: epoch,
      readTerminationPending: () async => false,
      writeTerminationPending: () async {},
      clearTerminationPending: () async {},
      cancelNotifications: () async {},
      clearAuthTokens: () async {},
      purgeDurableSessionData: () async {},
      purgeRemainingLocalData: () async {},
      clearSessionMemory: [household.clearSessionMemoryAfterPurge],
    );
    addTearDown(coordinator.dispose);

    final load = household.loadHousehold();
    await Future<void>.delayed(Duration.zero);
    await coordinator.terminate();
    loadGate.complete({
      'household': {'id': 'old-household'},
      'members': [
        {'id': 'old-member', 'status': 'active'},
      ],
      'role': 'owner',
    });
    await load;

    expect(household.household, isNull);
    expect(household.members, isEmpty);
    expect(household.error, isNull);
  });

  test('delayed BYOK read cannot restore an old account key', () async {
    final epoch = SessionEpoch();
    final storage = _DelayedSecureStorage()
      ..values['byok_api_key'] = 'synthetic-old-key';
    final byok = ByokProvider(sessionEpoch: epoch, storage: storage);
    addTearDown(byok.dispose);
    final coordinator = SessionTerminationCoordinator(
      sessionEpoch: epoch,
      readTerminationPending: () async => false,
      writeTerminationPending: () async {},
      clearTerminationPending: () async {},
      cancelNotifications: () async {},
      clearAuthTokens: () async {},
      purgeDurableSessionData: () async {},
      purgeRemainingLocalData: () async => storage.values.clear(),
      clearSessionMemory: [byok.clearSessionMemoryAfterPurge],
    );
    addTearDown(coordinator.dispose);

    final load = byok.loadSavedKey();
    await Future<void>.delayed(Duration.zero);
    await coordinator.terminate();
    storage.readGate.complete('openai');
    await load;

    expect(byok.provider, isNull);
    expect(byok.apiKey, isNull);
    expect(byok.isConfigured, isFalse);
    expect(storage.values, isEmpty);
  });

  test('scan mutations are rejected while session termination is blocked',
      () async {
    final epoch = SessionEpoch();
    final scans = ScanSessionProvider(sessionEpoch: epoch);
    addTearDown(scans.dispose);
    epoch.beginTermination();

    expect(
      () => scans.retainExtraction(
        const ExtractionResult(
          documentType: DocumentType.taxDeclaration,
          fields: [],
          overallConfidence: 0,
          confidenceDelta: 0,
          warnings: [],
          disclaimer: '',
          sources: [],
        ),
      ),
      throwsA(isA<SessionEpochInvalidated>()),
    );
    expect(scans.retainedSessionCount, 0);
  });

  test('backend hydration preserves resolved local canonical answers',
      () async {
    SharedPreferences.setMockInitialValues({
      'local_data_migrated_user-2': true,
    });
    await ReportPersistenceService.saveAnswers({
      'q_birth_year': 1980,
      'q_gender': 'M',
      'q_gross_salary_annual': 90000.0,
      '__provenance': {
        'birthYear': {
          'source': 'userInput',
          'updatedAt': '2026-07-01T00:00:00.000Z',
          'sourceDate': null,
        },
        'gender': {
          'source': 'userInput',
          'updatedAt': '2026-07-01T00:00:00.000Z',
          'sourceDate': null,
        },
        'salaireBrutMensuel': {
          'source': 'userInput',
          'updatedAt': '2026-07-01T00:00:00.000Z',
          'sourceDate': null,
        },
      },
      '_coach_data_timestamps': {
        'birthYear': '2026-07-01T00:00:00.000Z',
        'gender': '2026-07-01T00:00:00.000Z',
        'salaireBrutMensuel': '2026-07-01T00:00:00.000Z',
      },
    });
    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    final coach = CoachProfileProvider(sessionEpoch: epoch);
    addTearDown(coach.dispose);
    await coach.loadFromWizard();
    final auth = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      loginAction: (_, __) async => {
        'access_token': 'new-token',
        'refresh_token': 'new-refresh',
        'user_id': 'user-2',
        'email': 'new@example.test',
      },
      profileHydrationAction: () async => {
        'data': {
          'birthYear': 1975,
          'gender': 'F',
          'incomeGrossYearly': 120000,
        },
      },
      profileAnswerWriter: (answers, trust, sessionGuard) => switch (trust) {
        AuthProfileAnswerTrust.userInput => coach.mergeAnswersWithProvenance(
            answers,
            source: ProfileDataSource.userInput,
            sessionGuard: sessionGuard,
          ),
        AuthProfileAnswerTrust.backendUnknown =>
          coach.mergeBackendUnknownProfile(
            answers,
            sessionGuard: sessionGuard,
          ),
      },
    );
    addTearDown(auth.dispose);

    expect(await auth.login('new@example.test', 'synthetic'), isTrue);
    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted['q_birth_year'], 1980);
    expect(persisted['q_gender'], 'M');
    expect(persisted['q_gross_salary_annual'], 90000.0);
    final provenance = persisted['__provenance'] as Map? ?? const {};
    for (final path in const {
      'birthYear',
      'gender',
      'salaireBrutMensuel',
    }) {
      expect(provenance, contains(path));
    }
    final timestamps = persisted['_coach_data_timestamps'] as Map? ?? const {};
    expect(timestamps, contains('birthYear'));
    expect(timestamps, contains('gender'));
    expect(timestamps, contains('salaireBrutMensuel'));
    expect(
      persisted[coachBackendUnknownPathsKey] as List? ?? const <String>[],
      isNot(contains(anyOf('birthYear', 'gender', 'salaireBrutMensuel'))),
    );
  });

  test(
      'remote profile identity and finance use one durable backend-unknown merge',
      () async {
    final coach = CoachProfileProvider(now: () => DateTime.utc(2026, 7, 17));
    addTearDown(coach.dispose);

    await coach.mergeBackendUnknownProfile(const {
      'birthYear': 1987,
      'canton': 'GE',
      'gender': 'F',
      'incomeGrossYearly': 120000,
      'employmentStatus': 'salarie',
      'avoirLpp': 41000,
      'lppInsuredSalary': 88200,
      'lppBuybackMax': 15000,
      'pillar3aBalance': 23000,
    });

    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted, containsPair('q_birth_year', 1987));
    expect(persisted, containsPair('q_canton', 'GE'));
    expect(persisted, containsPair('q_gender', 'F'));
    expect(persisted, containsPair('q_gross_salary_annual', 120000.0));
    expect(persisted, containsPair('q_employment_status', 'salarie'));
    expect(persisted, containsPair('_coach_avoir_lpp', 41000.0));
    expect(persisted, containsPair('_coach_salaire_assure', 88200.0));
    expect(persisted, containsPair('_coach_rachat_maximum', 15000.0));
    expect(persisted, containsPair('q_3a_total', 23000.0));
    const paths = <String>{
      'birthYear',
      'canton',
      'gender',
      'salaireBrutMensuel',
      'employmentStatus',
      'prevoyance.avoirLppTotal',
      'prevoyance.salaireAssure',
      'prevoyance.rachatMaximum',
      'prevoyance.totalEpargne3a',
    };
    expect(
      (persisted[coachBackendUnknownPathsKey] as List).toSet(),
      paths,
    );
    for (final envelopeKey in const {
      '__provenance',
      '_coach_data_sources',
      '_coach_data_timestamps',
      '_coach_data_source_dates',
    }) {
      final envelope = persisted[envelopeKey] as Map? ?? const {};
      for (final path in paths) {
        expect(envelope, isNot(contains(path)), reason: '$envelopeKey $path');
      }
    }
    for (final profile in <CoachProfile>[coach.profile!]) {
      expect(profile.dataSources.keys, isNot(contains(anyOf(paths))));
      expect(profile.dataTimestamps.keys, isNot(contains(anyOf(paths))));
      expect(profile.dataSourceDates.keys, isNot(contains(anyOf(paths))));
      expect(
        profile.userProvidedFields,
        isNot(contains(anyOf(
          'age',
          'canton',
          'gender',
          'salary',
          'grossSalaryAnnual',
          'employmentStatus',
        ))),
      );
    }

    final cold = CoachProfileProvider(now: () => DateTime.utc(2026, 7, 17));
    addTearDown(cold.dispose);
    await cold.loadFromWizard();
    expect(cold.profile?.birthYear, coach.profile?.birthYear);
    expect(cold.profile?.canton, coach.profile?.canton);
    expect(cold.profile?.gender, coach.profile?.gender);
    expect(cold.profile?.salaireBrutMensuel, coach.profile?.salaireBrutMensuel);
    expect(cold.profile?.employmentStatus, coach.profile?.employmentStatus);
    expect(cold.profile?.prevoyance, coach.profile?.prevoyance);
    expect(cold.profile?.dataSources, coach.profile?.dataSources);
    expect(cold.profile?.dataTimestamps, coach.profile?.dataTimestamps);
    expect(cold.profile?.dataSourceDates, coach.profile?.dataSourceDates);
    expect(cold.profile?.userProvidedFields, coach.profile?.userProvidedFields);
  });

  test('typed LPP root and explicit local zero reject opaque remote fill',
      () async {
    const ownerId = '11111111-1111-4111-8111-111111111111';
    final stamp = DateTime.utc(2026, 7, 1);
    final root = LppEvidenceRoot(
      self: LppEvidenceSnapshot(
        snapshotId: '22222222-2222-4222-8222-222222222222',
        facts: {
          LppEvidenceFactKey.vestedBenefitsCapitalChf: LppEvidenceFact(
            value: 0,
            unit: LppEvidenceFactKey.vestedBenefitsCapitalChf.unit,
            profileOwnerId: ownerId,
            actorProfileOwnerId: ownerId,
            source: 'userInput',
            sourceDate: null,
            updatedAt: stamp,
          ),
        },
      ),
    ).toJsonString();
    await ReportPersistenceService.saveAnswers({
      'q_gross_salary_annual': 0.0,
      'q_3a_total': 0.0,
      '_coach_lpp_evidence_v1': root,
      '__provenance': {
        'salaireBrutMensuel': {
          'source': 'userInput',
          'updatedAt': stamp.toIso8601String(),
          'sourceDate': null,
        },
        'prevoyance.totalEpargne3a': {
          'source': 'userInput',
          'updatedAt': stamp.toIso8601String(),
          'sourceDate': null,
        },
      },
    });
    final coach = CoachProfileProvider(now: () => DateTime.utc(2026, 7, 17));
    addTearDown(coach.dispose);
    await coach.loadFromWizard();

    await coach.mergeBackendUnknownProfile(const {
      'incomeGrossYearly': 120000,
      'avoirLpp': 41000,
      'lppInsuredSalary': 88200,
      'lppBuybackMax': 15000,
      'pillar3aBalance': 23000,
    });

    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted['q_gross_salary_annual'], 0.0);
    expect(persisted['q_3a_total'], 0.0);
    expect(persisted, isNot(contains('_coach_avoir_lpp')));
    expect(persisted, isNot(contains('_coach_salaire_assure')));
    expect(persisted, isNot(contains('_coach_rachat_maximum')));
    expect(coach.profile?.prevoyance.avoirLppTotal, 0.0);
    expect(coach.profile?.prevoyance.salaireAssure, isNull);
    expect(coach.profile?.prevoyance.rachatMaximum, isNull);
  });

  test('opaque remote may refresh until an explicit local zero takes authority',
      () async {
    final coach = CoachProfileProvider(now: () => DateTime.utc(2026, 7, 17));
    addTearDown(coach.dispose);

    await coach.mergeBackendUnknownProfile(
      const {'incomeGrossYearly': 90000},
    );
    await coach.mergeBackendUnknownProfile(
      const {'incomeGrossYearly': 120000},
    );
    expect(
      (await ReportPersistenceService.loadAnswers())['q_gross_salary_annual'],
      120000.0,
    );

    await coach.mergeAnswersWithProvenance(
      const {'q_gross_salary_annual': 0.0},
      source: ProfileDataSource.userInput,
    );
    await coach.mergeBackendUnknownProfile(
      const {'incomeGrossYearly': 150000},
    );
    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted['q_gross_salary_annual'], 0.0);
    expect(
      persisted[coachBackendUnknownPathsKey] as List? ?? const <String>[],
      isNot(contains('salaireBrutMensuel')),
    );
    expect(
      coach.profile?.dataSources['salaireBrutMensuel'],
      ProfileDataSource.userInput,
    );
  });

  test('remote financial zeros suppress estimates without gaining provenance',
      () async {
    final coach = CoachProfileProvider(now: () => DateTime.utc(2026, 7, 17));
    addTearDown(coach.dispose);
    await coach.mergeBackendUnknownProfile(const {
      'incomeGrossYearly': 0,
      'avoirLpp': 0,
      'lppInsuredSalary': 0,
      'lppBuybackMax': 0,
      'pillar3aBalance': 0,
    });

    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted['q_gross_salary_annual'], 0.0);
    expect(persisted['_coach_avoir_lpp'], 0.0);
    expect(persisted['_coach_salaire_assure'], 0.0);
    expect(persisted['_coach_rachat_maximum'], 0.0);
    expect(persisted['q_3a_total'], 0.0);
    const paths = <String>{
      'salaireBrutMensuel',
      'prevoyance.avoirLppTotal',
      'prevoyance.salaireAssure',
      'prevoyance.rachatMaximum',
      'prevoyance.totalEpargne3a',
    };
    expect(
      (persisted[coachBackendUnknownPathsKey] as List).toSet(),
      paths,
    );
    expect(coach.profile?.salaireBrutMensuel, 0.0);
    expect(coach.profile?.prevoyance.avoirLppTotal, 0.0);
    expect(coach.profile?.prevoyance.salaireAssure, 0.0);
    expect(coach.profile?.prevoyance.rachatMaximum, 0.0);
    expect(coach.profile?.prevoyance.totalEpargne3a, 0.0);
    expect(coach.profile?.dataSources.keys, isNot(contains(anyOf(paths))));
    expect(coach.profile?.dataTimestamps.keys, isNot(contains(anyOf(paths))));

    final cold = CoachProfileProvider(now: () => DateTime.utc(2026, 7, 17));
    addTearDown(cold.dispose);
    await cold.loadFromWizard();
    expect(cold.profile?.salaireBrutMensuel, 0.0);
    expect(cold.profile?.prevoyance, coach.profile?.prevoyance);
    expect(cold.profile?.dataSources, coach.profile?.dataSources);
    expect(cold.profile?.dataTimestamps, coach.profile?.dataTimestamps);
  });

  test('direct auth hydration rejects malformed opaque profile values',
      () async {
    final logs = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) logs.add(message);
    };
    addTearDown(() => debugPrint = previousDebugPrint);
    SharedPreferences.setMockInitialValues({
      'local_data_migrated_user-malformed': true,
    });
    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    final coach = CoachProfileProvider(sessionEpoch: epoch);
    addTearDown(coach.dispose);
    final auth = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      loginAction: (_, __) async => const {
        'access_token': 'malformed-token',
        'refresh_token': 'malformed-refresh',
        'user_id': 'user-malformed',
        'email': 'malformed@example.test',
      },
      profileHydrationAction: () async => const {
        'birthYear': 9999,
        'canton': 'victim@example.test',
        'gender': 'invalid',
        'incomeGrossYearly': -1,
        'employmentStatus': 'wizard',
        'avoirLpp': -1,
        'lppInsuredSalary': -1,
        'lppBuybackMax': -1,
        'pillar3aBalance': -1,
      },
      profileAnswerWriter: (answers, trust, sessionGuard) => switch (trust) {
        AuthProfileAnswerTrust.userInput => coach.mergeAnswersWithProvenance(
            answers,
            source: ProfileDataSource.userInput,
            sessionGuard: sessionGuard,
          ),
        AuthProfileAnswerTrust.backendUnknown =>
          coach.mergeBackendUnknownProfile(
            answers,
            sessionGuard: sessionGuard,
          ),
      },
    );
    addTearDown(auth.dispose);

    expect(await auth.login('malformed@example.test', 'synthetic'), isTrue);
    expect(await ReportPersistenceService.loadAnswers(), isEmpty);
    expect(coach.profile, isNull);
    expect(logs.join('\n'), isNot(contains('victim@example.test')));
  });

  test('delayed remote profile cannot recapture a post-termination epoch',
      () async {
    final epoch = SessionEpoch();
    final gate = Completer<void>();
    final persistence = _DelayedTaxPersistence(gate);
    final coach = CoachProfileProvider(
      taxProfilePersistence: persistence,
      sessionEpoch: epoch,
    );
    addTearDown(coach.dispose);
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);

    final merge = coach.mergeBackendUnknownProfile(
      const {'incomeGrossYearly': 120000},
    );
    final expectation =
        expectLater(merge, throwsA(isA<SessionEpochInvalidated>()));
    await Future<void>.delayed(Duration.zero);
    final termination = coordinator.terminate();
    gate.complete();
    await termination;
    await expectation;

    expect(persistence.saveCalls, 0);
    expect(coach.profile, isNull);
  });

  test('backend birth year is a no-op under coherent exact DOB authority',
      () async {
    final gate = Completer<void>()..complete();
    const envelope = <String, dynamic>{
      'source': 'userInput',
      'updatedAt': '2026-07-17T00:00:00.000Z',
      'sourceDate': null,
    };
    final persistence = _DelayedTaxPersistence(
      gate,
      answers: const {
        'q_birth_year': 1988,
        'q_date_of_birth': '1988-04-02',
        '__provenance': {
          'birthYear': envelope,
          'dateOfBirth': envelope,
        },
      },
    );
    final coach = CoachProfileProvider(taxProfilePersistence: persistence);
    addTearDown(coach.dispose);

    await coach.mergeBackendUnknownAnswers(const {'q_birth_year': 1975});

    expect(persistence.saveCalls, 0);
    expect(coach.profile?.birthYear, 1988);
    expect(coach.profile?.dateOfBirth, DateTime(1988, 4, 2));
    expect(
        coach.profile?.dataSources['birthYear'], ProfileDataSource.userInput);
  });

  test('backend hydration publishes disk and Coach memory in one writer',
      () async {
    SharedPreferences.setMockInitialValues({
      'local_data_migrated_user-2': true,
    });
    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    final coach = CoachProfileProvider(sessionEpoch: epoch);
    addTearDown(coach.dispose);
    final auth = AuthProvider(
      sessionTerminationCoordinator: coordinator,
      loginAction: (_, __) async => {
        'access_token': 'new-token',
        'refresh_token': 'new-refresh',
        'user_id': 'user-2',
        'email': 'new@example.test',
      },
      profileHydrationAction: () async => {
        'birthYear': 1975,
        'canton': 'GE',
        'incomeGrossYearly': 120000,
      },
      profileAnswerWriter: (answers, trust, sessionGuard) => switch (trust) {
        AuthProfileAnswerTrust.userInput => coach.mergeAnswersWithProvenance(
            answers,
            source: ProfileDataSource.userInput,
            sessionGuard: sessionGuard,
          ),
        AuthProfileAnswerTrust.backendUnknown =>
          coach.mergeBackendUnknownProfile(
            answers,
            sessionGuard: sessionGuard,
          ),
      },
    );
    addTearDown(auth.dispose);

    expect(await auth.login('new@example.test', 'synthetic'), isTrue);

    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted['q_canton'], 'GE');
    expect(persisted['q_gross_salary_annual'], 120000.0);
    for (final envelopeKey in const {
      '__provenance',
      '_coach_data_sources',
      '_coach_data_timestamps',
      '_coach_data_source_dates',
    }) {
      final envelope = persisted[envelopeKey] as Map? ?? const {};
      expect(envelope, isNot(contains('canton')));
      expect(envelope, isNot(contains('salaireBrutMensuel')));
    }
    expect(coach.profile?.canton, 'GE');
    expect(coach.profile?.salaireBrutMensuel, 10000);
    expect(coach.profile?.dataSources, isNot(contains('canton')));
    expect(
      coach.profile?.dataSources,
      isNot(contains('salaireBrutMensuel')),
    );
    expect(coach.profile?.dataTimestamps, isNot(contains('canton')));
    expect(
      coach.profile?.dataTimestamps,
      isNot(contains('salaireBrutMensuel')),
    );
  });

  test('all asynchronous coach persistence paths cross the session barrier',
      () {
    final source = File(
      'lib/providers/coach_profile_provider.dart',
    ).readAsStringSync();
    const methodMarkers = <String>[
      'Future<void> updateFromSmartFlow(',
      'Future<void> updatePrimaryFocus(',
      'Future<void> addCheckIn(',
      'Future<void> updateContributions(',
      'Future<void> saveCurrentScore(',
      'Future<void> updateFromRefresh(',
      'Future<void> updateFromAvsExtraction(',
      'Future<void> updateFromSalaryExtraction(',
      'Future<void> updateInline(',
      'Future<void> updateFromOpenBanking(',
    ];

    for (var index = 0; index < methodMarkers.length; index++) {
      final marker = methodMarkers[index];
      final start = source.indexOf(marker);
      final end = index + 1 < methodMarkers.length
          ? source.indexOf(methodMarkers[index + 1], start + marker.length)
          : source.indexOf('static double? _safeExpense(', start);
      expect(start, greaterThanOrEqualTo(0), reason: marker);
      expect(end, greaterThan(start), reason: marker);
      final body = source.substring(start, end);
      expect(
        body,
        contains('final sessionGuard = _sessionEpoch.capture();'),
        reason: marker,
      );
      expect(
        body,
        contains('_sessionEpoch.runGuardedPersistence('),
        reason: marker,
      );
      expect(
        body,
        contains('sessionGuard.assertCurrent();'),
        reason: marker,
      );
    }
  });

  test('auth and coach source never interpolate exceptions or identifiers', () {
    final coachSource =
        File('lib/providers/coach_profile_provider.dart').readAsStringSync();
    final authSource =
        File('lib/providers/auth_provider.dart').readAsStringSync();
    final rawInterpolation = RegExp(r'\$(?:e|error)\b');
    expect(rawInterpolation.hasMatch(coachSource), isFalse);
    expect(rawInterpolation.hasMatch(authSource), isFalse);
    expect(authSource, isNot(contains('ownerTag')));
    final mapperStart = coachSource.indexOf(
      'Future<void> _mergeBackendUnknownProfile(',
    );
    final mapperEnd = coachSource.indexOf(
      'int? _validRemoteBirthYear(',
      mapperStart,
    );
    expect(mapperStart, greaterThanOrEqualTo(0));
    expect(mapperEnd, greaterThan(mapperStart));
    expect(
      coachSource.substring(mapperStart, mapperEnd),
      isNot(contains('resolveCanton(')),
    );
  });

  test('delayed biography failure cannot restore an old-session error',
      () async {
    final epoch = SessionEpoch();
    final database = _DelayedBiographyDatabase();
    final repository = await BiographyRepository.withDatabase(database);
    final biography = BiographyProvider(
      repository: repository,
      sessionEpoch: epoch,
    );
    addTearDown(biography.dispose);
    final coordinator = SessionTerminationCoordinator(
      sessionEpoch: epoch,
      readTerminationPending: () async => false,
      writeTerminationPending: () async {},
      clearTerminationPending: () async {},
      cancelNotifications: () async {},
      clearAuthTokens: () async {},
      purgeDurableSessionData: () async {},
      purgeRemainingLocalData: () async {},
      clearSessionMemory: [biography.clearSessionMemoryAfterPurge],
    );
    addTearDown(coordinator.dispose);

    final load = biography.loadFacts();
    await Future<void>.delayed(Duration.zero);
    await coordinator.terminate();
    database.queryGate.completeError(StateError('late old-session failure'));
    await load;

    expect(biography.facts, isEmpty);
    expect(biography.error, isNull);
    expect(biography.isLoading, isFalse);
  });
}
