import 'dart:async';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/session_epoch.dart';
import 'package:mint_mobile/models/profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    ApiService.debugResetHttpClient();
    ApiService.debugResetSessionTerminationHandler();
  });

  tearDown(() {
    ApiService.debugResetHttpClient();
    ApiService.debugResetSessionTerminationHandler();
  });

  test('all generic terminal 401 branches await the injected session flow',
      () async {
    await AuthService.saveToken(
      'synthetic-access',
      'synthetic-user',
      'synthetic@mint.test',
    );
    final requests = <String>[];
    ApiService.debugUseHttpClient(
      MockClient((request) async {
        requests.add(request.method);
        return http.Response('{"detail":"expired"}', 401);
      }),
    );
    var terminations = 0;
    final binding = ApiService.bindSessionTerminationHandler(
      () async {
        terminations++;
      },
      sessionEpoch: SessionEpoch(),
    );
    addTearDown(binding.dispose);

    final operations = <Future<Object?> Function()>[
      () => ApiService.get('/synthetic-expired'),
      () => ApiService.getText('/synthetic-expired'),
      () => ApiService.post('/synthetic-expired', const {}),
      () => ApiService.put('/synthetic-expired', const {}),
      () => ApiService.delete('/synthetic-expired'),
    ];

    for (final operation in operations) {
      await expectLater(
        operation(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    }

    expect(requests, ['GET', 'GET', 'POST', 'PUT', 'DELETE']);
    expect(terminations, operations.length);
  });

  test('401 does not complete before strict session termination completes',
      () async {
    await AuthService.saveToken(
      'synthetic-access',
      'synthetic-user',
      'synthetic@mint.test',
    );
    ApiService.debugUseHttpClient(
      MockClient((_) async => http.Response('{}', 401)),
    );
    final purgeGate = Completer<void>();
    final binding = ApiService.bindSessionTerminationHandler(
      () => purgeGate.future,
      sessionEpoch: SessionEpoch(),
    );
    addTearDown(binding.dispose);

    var completed = false;
    final request = ApiService.get('/synthetic-expired').then<void>(
      (_) => completed = true,
      onError: (_) => completed = true,
    );
    await Future<void>.delayed(Duration.zero);

    expect(completed, isFalse);
    purgeGate.complete();
    await request;
    expect(completed, isTrue);
  });

  test('unbound terminal handler fails closed instead of token-only logout',
      () async {
    ApiService.debugUseHttpClient(
      MockClient((_) async => http.Response('{}', 401)),
    );

    await expectLater(ApiService.get('/synthetic-expired'), throwsStateError);
  });

  test('source contract centralizes every generic terminal 401', () {
    final source = File('lib/services/api_service.dart').readAsStringSync();

    expect(source, isNot(contains('AuthService.logout()')));
    expect(
      RegExp(r'await _terminateExpiredSession\(\);').allMatches(source).length,
      greaterThanOrEqualTo(1),
    );
  });

  test('every named authenticated endpoint awaits the same 401 primitive',
      () async {
    await AuthService.saveToken(
      'synthetic-access',
      'synthetic-user',
      'synthetic@mint.test',
    );
    ApiService.debugUseHttpClient(
      MockClient((_) async => http.Response('{"detail":"expired"}', 401)),
    );
    var terminations = 0;
    final binding = ApiService.bindSessionTerminationHandler(
      () async {
        terminations++;
      },
      sessionEpoch: SessionEpoch(),
    );
    addTearDown(binding.dispose);

    final operations = <Future<Object?> Function()>[
      ApiService.getMe,
      ApiService.deleteAccount,
      () => ApiService.claimLocalData(
            localDataVersion: 1,
            deviceId: 'synthetic-device',
          ),
      () => ApiService.verifyApplePurchase(
            productId: 'synthetic-product',
            transactionId: 'synthetic-transaction',
          ),
      () => ApiService.createProfile(
            householdType: HouseholdType.single,
            goal: Goal.other,
          ),
    ];

    for (final operation in operations) {
      await expectLater(
        operation(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    }
    expect(terminations, operations.length);
  });

  test('source contract has one authenticated transport primitive', () {
    final source = File('lib/services/api_service.dart').readAsStringSync();
    expect(
      RegExp(r'final headers = _authHeadersForAccessToken\(')
          .allMatches(source)
          .length,
      1,
    );
    for (final method in const [
      'getMe',
      'deleteAccount',
      'claimLocalData',
      'verifyApplePurchase',
      'createProfile',
    ]) {
      final start =
          source.indexOf('static Future', source.indexOf(method) - 80);
      final next = source.indexOf('\n  static Future', start + 1);
      final body = source.substring(start, next < 0 ? source.length : next);
      expect(body, isNot(contains('_authHeaders()')), reason: method);
      expect(body, isNot(contains('http.')), reason: method);
    }
  });

  test('ephemeral getMe resolves identity without publishing credentials',
      () async {
    final requests = <http.Request>[];
    ApiService.debugUseHttpClient(MockClient((request) async {
      requests.add(request);
      expect(await AuthService.getToken(), isNull);
      return http.Response(
        '{"id":"magic-user","email":"magic@mint.test"}',
        200,
      );
    }));
    final binding = ApiService.bindSessionTerminationHandler(
      () async {},
      sessionEpoch: SessionEpoch(),
    );
    addTearDown(binding.dispose);

    final identity = await ApiService.getMeWithEphemeralAccessToken(
      'ephemeral-magic-token',
    );

    expect(identity, {
      'id': 'magic-user',
      'email': 'magic@mint.test',
    });
    expect(requests.single.url.path, '/api/v1/auth/me');
    expect(
      requests.single.headers['authorization'],
      'Bearer ephemeral-magic-token',
    );
    expect(await AuthService.getToken(), isNull);
    expect(await AuthService.isLoggedIn(), isFalse);
  });
}
