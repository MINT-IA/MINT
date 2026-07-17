import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/coach/coach_chat_api_service.dart';
import 'package:mint_mobile/services/partner_estimate_service.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/services/session_epoch.dart';
import 'package:mint_mobile/services/session_termination_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'local_data_migrated_user-a': true,
      'local_data_migrated_user-b': true,
    });
    FlutterSecureStorage.setMockInitialValues({});
    ApiService.debugResetHttpClient();
    ApiService.debugResetSessionTerminationHandler();
    ApiService.debugResetAuthSessionReader();
    PartnerEstimateService.debugResetLoad();
  });

  tearDown(() {
    PartnerEstimateService.debugResetLoad();
    ApiService.debugResetHttpClient();
    ApiService.debugResetSessionTerminationHandler();
    ApiService.debugResetAuthSessionReader();
  });

  test(
      'CoachChat lease cannot send as B after A partner aggregation was suspended',
      () async {
    final partnerReadStarted = Completer<void>();
    final releasePartnerRead = Completer<void>();
    PartnerEstimateService.debugConfigureLoad(() async {
      if (!partnerReadStarted.isCompleted) partnerReadStarted.complete();
      await releasePartnerRead.future;
      return null;
    });

    final coachAuthorization = <String?>[];
    ApiService.debugUseHttpClient(MockClient((request) async {
      if (request.url.path.endsWith('/coach/chat')) {
        coachAuthorization.add(request.headers['authorization']);
        return http.Response(
          jsonEncode({
            'message': 'Synthetic response',
            'toolCalls': <Object>[],
            'sources': <Object>[],
            'disclaimers': <Object>[],
            'tokensUsed': 1,
          }),
          200,
        );
      }
      return http.Response('{"landmarks":[]}', 200);
    }));

    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    final binding = ApiService.bindSessionTerminationHandler(
      coordinator.terminate,
      sessionEpoch: epoch,
    );
    addTearDown(binding.dispose);
    final provider = _provider(coordinator);
    addTearDown(provider.dispose);

    expect(await provider.login('a@mint.test', 'synthetic'), isTrue);
    final chat = CoachChatApiService().chat(
      message: 'Bonjour',
      profileContext: <String, dynamic>{},
    );
    Object? chatFailure;
    final chatOutcome = chat.then<void>(
      (_) {},
      onError: (Object error) => chatFailure = error,
    );
    await Future.any<void>([
      partnerReadStarted.future,
      chatOutcome,
    ]).timeout(const Duration(seconds: 2));
    if (!partnerReadStarted.isCompleted) {
      fail(
        'CoachChat settled before partner aggregation: '
        '$chatFailure',
      );
    }

    await provider.logout().timeout(
          const Duration(seconds: 2),
          onTimeout: () => throw StateError('A termination did not complete'),
        );
    expect(
      await provider.login('b@mint.test', 'synthetic').timeout(
            const Duration(seconds: 2),
            onTimeout: () => throw StateError('B login did not complete'),
          ),
      isTrue,
    );
    releasePartnerRead.complete();

    await chatOutcome.timeout(
      const Duration(seconds: 2),
      onTimeout: () => throw StateError('stale CoachChat did not settle'),
    );
    expect(chatFailure, isA<SessionEpochInvalidated>());
    expect(
      coachAuthorization.where((value) => value == 'Bearer access-b'),
      isEmpty,
    );
  });

  test('RAG 429 retry cannot cross from account A into account B', () async {
    final firstRagRequest = Completer<void>();
    final ragAuthorization = <String?>[];
    ApiService.debugUseHttpClient(MockClient((request) async {
      if (request.url.path.endsWith('/rag/query')) {
        ragAuthorization.add(request.headers['authorization']);
        if (!firstRagRequest.isCompleted) {
          firstRagRequest.complete();
          return http.Response('{"detail":"rate limited"}', 429);
        }
        return http.Response(
          '{"answer":"B","sources":[],"disclaimers":[],"tokens_used":1}',
          200,
        );
      }
      return http.Response('{"landmarks":[]}', 200);
    }));

    final epoch = SessionEpoch();
    final coordinator = _coordinator(epoch);
    addTearDown(coordinator.dispose);
    final binding = ApiService.bindSessionTerminationHandler(
      coordinator.terminate,
      sessionEpoch: epoch,
    );
    addTearDown(binding.dispose);
    final provider = _provider(coordinator);
    addTearDown(provider.dispose);

    expect(await provider.login('a@mint.test', 'synthetic'), isTrue);
    final query = RagService().query(
      question: 'Question',
      apiKey: 'synthetic-byok',
      provider: 'claude',
    );
    Object? queryFailure;
    final queryOutcome = query.then<void>(
      (_) {},
      onError: (Object error) => queryFailure = error,
    );
    await firstRagRequest.future;

    await provider.logout();
    expect(await provider.login('b@mint.test', 'synthetic'), isTrue);

    await queryOutcome;
    expect(queryFailure, isA<SessionEpochInvalidated>());
    expect(
      ragAuthorization.where((value) => value == 'Bearer access-b'),
      isEmpty,
    );
  });

  test('claim-local-data lease is captured before ledger payload suspension',
      () async {
    final ledgerReadStarted = Completer<void>();
    final releaseLedgerRead = Completer<void>();
    SharedPreferences.setMockInitialValues({
      '_mint_device_id': 'device-synthetic',
      'local_data_migrated_user-b': true,
    });

    final claimAuthorization = <String?>[];
    ApiService.debugUseHttpClient(MockClient((request) async {
      if (request.url.path.endsWith('/sync/claim-local-data')) {
        claimAuthorization.add(request.headers['authorization']);
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
    final provider = _provider(
      coordinator,
      localDataAnswersReader: () async {
        if (!ledgerReadStarted.isCompleted) ledgerReadStarted.complete();
        await releaseLedgerRead.future;
        return const {
          'q_canton': 'VD',
          'q_gross_salary_annual': 96000,
        };
      },
    );
    addTearDown(provider.dispose);

    final loginA = provider.login('a@mint.test', 'synthetic');
    await ledgerReadStarted.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () => throw StateError('A ledger read did not start'),
    );
    await provider.logout();
    expect(await provider.login('b@mint.test', 'synthetic'), isTrue);
    releaseLedgerRead.complete();

    expect(await loginA, isFalse);
    expect(claimAuthorization, isEmpty);
    expect(provider.userId, 'user-b');
    expect(provider.email, 'b@mint.test');
    expect(await AuthService.getToken(), 'access-b');
  });
}

SessionTerminationCoordinator _coordinator(SessionEpoch epoch) {
  return SessionTerminationCoordinator(
    sessionEpoch: epoch,
    cancelNotifications: () async {},
    clearAuthTokens: AuthService.clearTokensForSessionTermination,
    purgeDurableSessionData: () async {},
    purgeRemainingLocalData: () async {},
    clearSessionMemory: const [],
  );
}

AuthProvider _provider(
  SessionTerminationCoordinator coordinator, {
  Future<Map<String, dynamic>> Function()? localDataAnswersReader,
}) {
  return AuthProvider(
    sessionTerminationCoordinator: coordinator,
    loginAction: (email, _) async {
      final suffix = email.startsWith('a@') ? 'a' : 'b';
      return {
        'access_token': 'access-$suffix',
        'refresh_token': 'refresh-$suffix',
        'user_id': 'user-$suffix',
        'email': email,
      };
    },
    profileHydrationAction: () async => const <String, dynamic>{},
    localDataAnswersReader: localDataAnswersReader,
  );
}
