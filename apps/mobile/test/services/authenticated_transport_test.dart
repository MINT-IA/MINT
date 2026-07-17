import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/authenticated_transport.dart';
import 'package:mint_mobile/services/session_epoch.dart';
import 'package:mint_mobile/services/session_termination_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('JSON and text requests keep their exact payload semantics', () async {
    await AuthService.saveToken('access-old', 'user-1', 'user@mint.test');
    final seen = <http.Request>[];
    ApiService.debugUseHttpClient(MockClient((request) async {
      seen.add(request);
      return http.Response('plain response', 200);
    }));
    final epoch = SessionEpoch();
    final binding = ApiService.bindSessionTerminationHandler(
      () async {},
      sessionEpoch: epoch,
    );
    addTearDown(binding.dispose);

    final jsonResponse =
        await ApiService.authenticatedTransport.beginOperation().send(
              AuthenticatedRequest.json(
                AuthenticatedHttpMethod.post,
                Uri.parse('${ApiService.baseUrl}/synthetic-json'),
                const {'value': 42},
              ),
            );
    final textResponse =
        await ApiService.authenticatedTransport.beginOperation().send(
              AuthenticatedRequest.text(
                AuthenticatedHttpMethod.put,
                Uri.parse('${ApiService.baseUrl}/synthetic-text'),
                'exact text',
                contentType: 'text/plain; charset=utf-8',
              ),
            );

    expect(jsonResponse.body, 'plain response');
    expect(textResponse.body, 'plain response');
    expect(seen[0].method, 'POST');
    expect(jsonDecode(seen[0].body), {'value': 42});
    expect(seen[0].headers['authorization'], 'Bearer access-old');
    expect(seen[1].method, 'PUT');
    expect(seen[1].body, 'exact text');
    expect(seen[1].headers['content-type'], contains('text/plain'));
  });

  test(
      'missing session is rejected before network without terminal-session purge',
      () async {
    var networkRequests = 0;
    var terminations = 0;
    ApiService.debugUseHttpClient(MockClient((_) async {
      networkRequests++;
      return http.Response('{"detail":"missing"}', 401);
    }));
    final binding = ApiService.bindSessionTerminationHandler(
      () async => terminations++,
      sessionEpoch: SessionEpoch(),
    );
    addTearDown(binding.dispose);

    Object? failure;
    try {
      await ApiService.authenticatedTransport.beginOperation().send(
            AuthenticatedRequest.get(
              Uri.parse('${ApiService.baseUrl}/synthetic-requires-session'),
            ),
          );
    } catch (error) {
      failure = error;
    }

    expect(failure, isA<ApiException>());
    final apiFailure = failure! as ApiException;
    expect(apiFailure.statusCode, 401);
    expect(apiFailure.errorCode, ApiErrorCode.authenticationRequired);
    expect(networkRequests, 0);
    expect(terminations, 0);
  });

  test('multipart refresh rebuild preserves fields files and idempotency',
      () async {
    await AuthService.saveToken(
      'access-old',
      'user-1',
      'user@mint.test',
      refreshToken: 'refresh-old',
    );
    final directory = await Directory.systemTemp.createTemp('mint-transport');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/proof.bin');
    const fileBytes = <int>[0, 1, 2, 3, 254, 255];
    await file.writeAsBytes(fileBytes);

    final uploads = <http.Request>[];
    ApiService.debugUseHttpClient(MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        return http.Response(
          jsonEncode({
            'access_token': 'access-new',
            'refresh_token': 'refresh-new',
            'user_id': 'user-1',
            'email': 'user@mint.test',
          }),
          200,
        );
      }
      uploads.add(request);
      return http.Response(
        uploads.length == 1 ? '{"detail":"expired"}' : '{"ok":true}',
        uploads.length == 1 ? 401 : 201,
      );
    }));
    final epoch = SessionEpoch();
    final binding = ApiService.bindSessionTerminationHandler(
      () async {},
      sessionEpoch: epoch,
    );
    addTearDown(binding.dispose);

    final response =
        await ApiService.authenticatedTransport.beginOperation().send(
              AuthenticatedRequest.multipart(
                Uri.parse('${ApiService.baseUrl}/documents/upload'),
                fields: const {'document_type': 'lpp_certificate'},
                files: [
                  AuthenticatedFilePart.fromPath(
                    field: 'file',
                    path: file.path,
                    filename: 'proof.bin',
                  ),
                ],
                headers: const {'Idempotency-Key': 'stable-operation-id'},
              ),
            );

    expect(response.statusCode, 201);
    expect(uploads, hasLength(2));
    for (final request in uploads) {
      expect(request.headers['idempotency-key'], 'stable-operation-id');
      expect(
          request.headers['content-type'], startsWith('multipart/form-data'));
      final multipartText = latin1.decode(request.bodyBytes);
      expect(multipartText, contains('document_type'));
      expect(multipartText, contains('lpp_certificate'));
      expect(multipartText, contains('proof.bin'));
      expect(_containsBytes(request.bodyBytes, fileBytes), isTrue);
    }
    expect(uploads[0].headers['authorization'], 'Bearer access-old');
    expect(uploads[1].headers['authorization'], 'Bearer access-new');
  });

  test('stream request factory is replayable across one refresh', () async {
    await AuthService.saveToken(
      'access-old',
      'user-1',
      'user@mint.test',
      refreshToken: 'refresh-old',
    );
    var streamBuilds = 0;
    final bodies = <List<int>>[];
    ApiService.debugUseHttpClient(MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        return http.Response(
          '{"access_token":"new","refresh_token":"new-r","user_id":"user-1","email":"user@mint.test"}',
          200,
        );
      }
      bodies.add(request.bodyBytes);
      return http.Response('{}', bodies.length == 1 ? 401 : 200);
    }));
    final epoch = SessionEpoch();
    final binding = ApiService.bindSessionTerminationHandler(
      () async {},
      sessionEpoch: epoch,
    );
    addTearDown(binding.dispose);

    await ApiService.authenticatedTransport.beginOperation().send(
          AuthenticatedRequest.stream(
            AuthenticatedHttpMethod.post,
            Uri.parse('${ApiService.baseUrl}/synthetic-stream'),
            contentLength: 4,
            streamFactory: () {
              streamBuilds++;
              return Stream<List<int>>.value(const [4, 3, 2, 1]);
            },
          ),
        );

    expect(streamBuilds, 2);
    expect(bodies, [
      const [4, 3, 2, 1],
      const [4, 3, 2, 1]
    ]);
  });

  test('simultaneous terminal 401s coalesce and await one purge', () async {
    await AuthService.saveToken('access-old', 'user-1', 'user@mint.test');
    ApiService.debugUseHttpClient(
      MockClient((_) async => http.Response('{"detail":"expired"}', 401)),
    );
    final purgeGate = Completer<void>();
    var purgeCalls = 0;
    final epoch = SessionEpoch();
    final binding = ApiService.bindSessionTerminationHandler(
      () {
        purgeCalls++;
        return purgeGate.future;
      },
      sessionEpoch: epoch,
    );
    addTearDown(binding.dispose);

    var completions = 0;
    Future<void> call(String suffix) => ApiService.authenticatedTransport
        .beginOperation()
        .send(
          AuthenticatedRequest.get(
            Uri.parse('${ApiService.baseUrl}/synthetic-$suffix'),
          ),
        )
        .then<void>((_) => completions++, onError: (_) => completions++);
    final first = call('one');
    final second = call('two');
    await Future<void>.delayed(Duration.zero);

    expect(purgeCalls, 1);
    expect(completions, 0);
    purgeGate.complete();
    await Future.wait([first, second]);
    expect(completions, 2);
  });

  test('old epoch response is ignored before consumer publication', () async {
    await AuthService.saveToken('access-old', 'user-1', 'user@mint.test');
    final responseGate = Completer<http.Response>();
    ApiService.debugUseHttpClient(MockClient((_) => responseGate.future));
    final epoch = SessionEpoch();
    final binding = ApiService.bindSessionTerminationHandler(
      () async {},
      sessionEpoch: epoch,
    );
    addTearDown(binding.dispose);

    final request = ApiService.authenticatedTransport.beginOperation().send(
          AuthenticatedRequest.get(
            Uri.parse('${ApiService.baseUrl}/synthetic-delayed'),
          ),
        );
    await Future<void>.delayed(Duration.zero);
    epoch.beginTermination();
    responseGate.complete(http.Response('{"old":true}', 200));

    await expectLater(request, throwsA(isA<SessionEpochInvalidated>()));
  });

  test(
      'logout during delayed credential read performs no authenticated network request',
      () async {
    await AuthService.saveToken(
      'access-old',
      'user-1',
      'user@mint.test',
      refreshToken: 'refresh-old',
    );
    final captured = await AuthService.readSessionEnvelope();
    final credentialReadStarted = Completer<void>();
    final releaseCredentialRead = Completer<void>();
    ApiService.debugUseAuthSessionReader(() async {
      credentialReadStarted.complete();
      await releaseCredentialRead.future;
      return captured;
    });
    var networkRequests = 0;
    ApiService.debugUseHttpClient(MockClient((_) async {
      networkRequests++;
      return http.Response('{}', 200);
    }));
    final epoch = SessionEpoch();
    final coordinator = SessionTerminationCoordinator(
      sessionEpoch: epoch,
      clearAuthTokens: AuthService.clearTokensForSessionTermination,
      purgeDurableSessionData: () async {},
      purgeRemainingLocalData: () async {},
      clearSessionMemory: const [],
    );
    addTearDown(coordinator.dispose);
    final binding = ApiService.bindSessionTerminationHandler(
      coordinator.terminate,
      sessionEpoch: epoch,
    );
    addTearDown(binding.dispose);

    final request = ApiService.authenticatedTransport.beginOperation().send(
          AuthenticatedRequest.get(
            Uri.parse('${ApiService.baseUrl}/synthetic-delayed-credentials'),
          ),
        );
    await credentialReadStarted.future;
    await coordinator.terminate();
    releaseCredentialRead.complete();

    await expectLater(request, throwsA(isA<SessionEpochInvalidated>()));
    expect(networkRequests, 0);
    expect(await AuthService.readSessionEnvelope(), isNull);
  });

  test('logout invalidates a delayed transport credential availability check',
      () async {
    const captured = AuthSessionEnvelope(
      accessToken: 'access-old',
      userId: 'user-a',
      email: 'a@mint.test',
    );
    final credentialReadStarted = Completer<void>();
    final releaseCredentialRead = Completer<void>();
    ApiService.debugUseAuthSessionReader(() async {
      credentialReadStarted.complete();
      await releaseCredentialRead.future;
      return captured;
    });
    final epoch = SessionEpoch();
    final binding = ApiService.bindSessionTerminationHandler(
      () async {},
      sessionEpoch: epoch,
    );
    addTearDown(binding.dispose);

    final availability =
        ApiService.authenticatedTransport.beginOperation().requireSession();
    await Future<void>.delayed(Duration.zero);
    expect(credentialReadStarted.isCompleted, isTrue);
    epoch.beginTermination();
    epoch.completeTermination();
    releaseCredentialRead.complete();

    await expectLater(
      availability,
      throwsA(isA<SessionEpochInvalidated>()),
    );
  });

  test(
      'logout during replay credential read suppresses the post-refresh replay',
      () async {
    await AuthService.saveToken(
      'access-old',
      'user-1',
      'user@mint.test',
      refreshToken: 'refresh-old',
    );
    final replayCredentialReadStarted = Completer<void>();
    final releaseReplayCredentialRead = Completer<void>();
    ApiService.debugUseAuthSessionReader(() async {
      final envelope = await AuthService.readSessionEnvelope();
      if (envelope?.accessToken == 'access-new') {
        replayCredentialReadStarted.complete();
        await releaseReplayCredentialRead.future;
      }
      return envelope;
    });
    var endpointRequests = 0;
    var refreshRequests = 0;
    ApiService.debugUseHttpClient(MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        refreshRequests++;
        return http.Response(
          '{"access_token":"access-new","refresh_token":"refresh-new","user_id":"user-1","email":"user@mint.test"}',
          200,
        );
      }
      endpointRequests++;
      return http.Response('{"detail":"expired"}', 401);
    }));
    final epoch = SessionEpoch();
    final coordinator = SessionTerminationCoordinator(
      sessionEpoch: epoch,
      clearAuthTokens: AuthService.clearTokensForSessionTermination,
      purgeDurableSessionData: () async {},
      purgeRemainingLocalData: () async {},
      clearSessionMemory: const [],
    );
    addTearDown(coordinator.dispose);
    final binding = ApiService.bindSessionTerminationHandler(
      coordinator.terminate,
      sessionEpoch: epoch,
    );
    addTearDown(binding.dispose);

    final request = ApiService.authenticatedTransport.beginOperation().send(
          AuthenticatedRequest.get(
            Uri.parse('${ApiService.baseUrl}/synthetic-replay-race'),
          ),
        );
    await replayCredentialReadStarted.future;
    await coordinator.terminate();
    releaseReplayCredentialRead.complete();

    await expectLater(request, throwsA(isA<SessionEpochInvalidated>()));
    expect(endpointRequests, 1);
    expect(refreshRequests, 1);
    expect(await AuthService.readSessionEnvelope(), isNull);
  });

  test('delayed refresh cannot recreate a token after invalidation', () async {
    await AuthService.saveToken(
      'access-old',
      'user-1',
      'user@mint.test',
      refreshToken: 'refresh-old',
    );
    final refreshStarted = Completer<void>();
    final refreshGate = Completer<http.Response>();
    ApiService.debugUseHttpClient(MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        refreshStarted.complete();
        return refreshGate.future;
      }
      return http.Response('{}', 401);
    }));
    final epoch = SessionEpoch();
    final binding = ApiService.bindSessionTerminationHandler(
      () async {},
      sessionEpoch: epoch,
    );
    addTearDown(binding.dispose);

    final request = ApiService.authenticatedTransport.beginOperation().send(
          AuthenticatedRequest.get(
            Uri.parse('${ApiService.baseUrl}/synthetic-delayed-refresh'),
          ),
        );
    await refreshStarted.future;
    epoch.beginTermination();
    refreshGate.complete(http.Response(
      '{"access_token":"resurrected","refresh_token":"resurrected-r","user_id":"user-1","email":"user@mint.test"}',
      200,
    ));

    await expectLater(request, throwsA(isA<SessionEpochInvalidated>()));
    expect(await AuthService.getToken(), 'access-old');
    expect(await AuthService.getRefreshToken(), 'refresh-old');
  });

  test('refresh identity switch A to B terminates once and never persists B',
      () async {
    await AuthService.saveToken(
      'access-a',
      'user-a',
      'a@mint.test',
      displayName: 'Session A',
      refreshToken: 'refresh-a',
    );
    var endpointRequests = 0;
    var refreshRequests = 0;
    ApiService.debugUseHttpClient(MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        refreshRequests++;
        return http.Response(
          '{"access_token":"access-b","refresh_token":"refresh-b","user_id":"user-b","email":"b@mint.test"}',
          200,
        );
      }
      endpointRequests++;
      return http.Response(
        endpointRequests == 1 ? '{"detail":"expired"}' : '{"ok":true}',
        endpointRequests == 1 ? 401 : 200,
      );
    }));
    final epoch = SessionEpoch();
    var purges = 0;
    final coordinator = SessionTerminationCoordinator(
      sessionEpoch: epoch,
      clearAuthTokens: () async {
        purges++;
        await AuthService.clearTokensForSessionTermination();
      },
      purgeDurableSessionData: () async {},
      purgeRemainingLocalData: () async {},
      clearSessionMemory: const [],
    );
    addTearDown(coordinator.dispose);
    final binding = ApiService.bindSessionTerminationHandler(
      coordinator.terminate,
      sessionEpoch: epoch,
    );
    addTearDown(binding.dispose);

    await expectLater(
      ApiService.authenticatedTransport.beginOperation().send(
            AuthenticatedRequest.get(
              Uri.parse('${ApiService.baseUrl}/synthetic-identity-switch'),
            ),
          ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.errorCode,
          'errorCode',
          ApiErrorCode.sessionExpired,
        ),
      ),
    );

    expect(endpointRequests, 1);
    expect(refreshRequests, 1);
    expect(purges, 1);
    expect(await AuthService.readSessionEnvelope(), isNull);
  });

  for (final invalidIdentity in const <String, String>{
    'missing required user id':
        '{"access_token":"access-new","refresh_token":"refresh-new","email":"a@mint.test"}',
    'malformed required email':
        '{"access_token":"access-new","refresh_token":"refresh-new","user_id":"user-a","email":42}',
  }.entries) {
    test(
        'refresh ${invalidIdentity.key} is terminal and leaves no credential envelope',
        () async {
      await AuthService.saveToken(
        'access-a',
        'user-a',
        'a@mint.test',
        refreshToken: 'refresh-a',
      );
      var endpointRequests = 0;
      var purges = 0;
      ApiService.debugUseHttpClient(MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          return http.Response(invalidIdentity.value, 200);
        }
        endpointRequests++;
        return http.Response('{"detail":"expired"}', 401);
      }));
      final epoch = SessionEpoch();
      final coordinator = SessionTerminationCoordinator(
        sessionEpoch: epoch,
        clearAuthTokens: () async {
          purges++;
          await AuthService.clearTokensForSessionTermination();
        },
        purgeDurableSessionData: () async {},
        purgeRemainingLocalData: () async {},
        clearSessionMemory: const [],
      );
      addTearDown(coordinator.dispose);
      final binding = ApiService.bindSessionTerminationHandler(
        coordinator.terminate,
        sessionEpoch: epoch,
      );
      addTearDown(binding.dispose);

      await expectLater(
        ApiService.authenticatedTransport.beginOperation().send(
              AuthenticatedRequest.get(
                Uri.parse('${ApiService.baseUrl}/synthetic-invalid-identity'),
              ),
            ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.errorCode,
            'errorCode',
            ApiErrorCode.sessionExpired,
          ),
        ),
      );

      expect(endpointRequests, 1);
      expect(purges, 1);
      expect(await AuthService.readSessionEnvelope(), isNull);
    });
  }

  for (final status in const [400, 401, 403]) {
    test('initial 401 plus explicit refresh $status terminates the session',
        () async {
      await AuthService.saveToken(
        'access-old',
        'user-1',
        'user@mint.test',
        refreshToken: 'refresh-old',
      );
      ApiService.debugUseHttpClient(MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          return http.Response('{"detail":"invalid refresh"}', status);
        }
        return http.Response('{"detail":"expired"}', 401);
      }));
      var terminations = 0;
      final binding = ApiService.bindSessionTerminationHandler(
        () async => terminations++,
        sessionEpoch: SessionEpoch(),
      );
      addTearDown(binding.dispose);

      await expectLater(
        ApiService.authenticatedTransport.beginOperation().send(
              AuthenticatedRequest.get(
                Uri.parse('${ApiService.baseUrl}/synthetic-expired'),
              ),
            ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.errorCode,
            'errorCode',
            ApiErrorCode.sessionExpired,
          ),
        ),
      );
      expect(terminations, 1);
    });
  }

  final transientRefreshCases = <({
    String name,
    Future<http.Response> Function() response,
    ApiErrorCode errorCode,
  })>[
    (
      name: 'network failure',
      response: () => throw const SocketException('synthetic offline'),
      errorCode: ApiErrorCode.offline,
    ),
    (
      name: 'timeout',
      response: () => throw TimeoutException('synthetic timeout'),
      errorCode: ApiErrorCode.timeout,
    ),
    (
      name: 'server 500',
      response: () async => http.Response('{"detail":"temporary"}', 500),
      errorCode: ApiErrorCode.serverError,
    ),
    (
      name: 'malformed technical response',
      response: () async => http.Response('<html>temporary</html>', 200),
      errorCode: ApiErrorCode.serverError,
    ),
  ];
  for (final refreshCase in transientRefreshCases) {
    test(
        'initial 401 plus refresh ${refreshCase.name} preserves the complete session',
        () async {
      await AuthService.saveToken(
        'access-old',
        'user-1',
        'user@mint.test',
        displayName: 'Session A',
        refreshToken: 'refresh-old',
      );
      ApiService.debugUseHttpClient(MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          return refreshCase.response();
        }
        return http.Response('{"detail":"expired"}', 401);
      }));
      var terminations = 0;
      final binding = ApiService.bindSessionTerminationHandler(
        () async => terminations++,
        sessionEpoch: SessionEpoch(),
      );
      addTearDown(binding.dispose);

      await expectLater(
        ApiService.authenticatedTransport.beginOperation().send(
              AuthenticatedRequest.get(
                Uri.parse('${ApiService.baseUrl}/synthetic-transient'),
              ),
            ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.errorCode,
            'errorCode',
            refreshCase.errorCode,
          ),
        ),
      );

      expect(terminations, 0);
      expect(await AuthService.isLoggedIn(), isTrue);
      expect(await AuthService.getToken(), 'access-old');
      expect(await AuthService.getRefreshToken(), 'refresh-old');
      expect(await AuthService.getUserId(), 'user-1');
      expect(await AuthService.getUserEmail(), 'user@mint.test');
      expect(await AuthService.getDisplayName(), 'Session A');
    });
  }
}

bool _containsBytes(List<int> haystack, List<int> needle) {
  for (var offset = 0; offset <= haystack.length - needle.length; offset++) {
    var matches = true;
    for (var i = 0; i < needle.length; i++) {
      if (haystack[offset + i] != needle[i]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
}
