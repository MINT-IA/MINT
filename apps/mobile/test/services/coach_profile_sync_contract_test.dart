import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/session_epoch.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ApiService.debugResetHttpClient();
    ApiService.debugResetSessionTerminationHandler();
  });

  tearDown(() {
    ApiService.debugResetHttpClient();
    ApiService.debugResetSessionTerminationHandler();
  });

  test('authenticated product-ledger mutations remain local', () async {
    await AuthService.saveToken(
      'synthetic-access',
      'synthetic-user',
      'synthetic@mint.test',
    );
    final requestedPaths = <String>[];
    ApiService.debugUseHttpClient(MockClient((request) async {
      requestedPaths.add(request.url.path);
      return http.Response('{"claimed":true}', 200);
    }));
    final epoch = SessionEpoch();
    final binding = ApiService.bindSessionTerminationHandler(
      () async {},
      sessionEpoch: epoch,
    );
    addTearDown(binding.dispose);
    final provider = CoachProfileProvider(sessionEpoch: epoch);
    addTearDown(provider.dispose);

    await provider.mergeAnswersWithProvenance(
      const {'q_canton': 'VD'},
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(requestedPaths, isEmpty);
  });

  test('Coach ledger has no outbound claim facade and keeps inbound refresh',
      () {
    final provider =
        File('lib/providers/coach_profile_provider.dart').readAsStringSync();
    final app = File('lib/app.dart').readAsStringSync();

    for (final forbidden in const {
      '/sync/claim-local-data',
      '_syncToBackend',
      'triggerBackendSync',
      'syncToBackend',
    }) {
      expect(provider, isNot(contains(forbidden)), reason: forbidden);
    }
    expect(app, isNot(contains('syncToBackend:')));
    expect(provider, contains('Future<void> syncFromBackend() async'));
    expect(
      File('lib/screens/coach/coach_chat_screen.dart').readAsStringSync(),
      contains('read<CoachProfileProvider>().syncFromBackend()'),
    );
  });

  test('anonymous-to-account claim keeps its exact authenticated operation',
      () {
    final auth = File('lib/providers/auth_provider.dart').readAsStringSync();
    final migration = _between(
      auth,
      'Future<void> _migrateLocalDataIfNeeded(SessionEpochGuard guard) async',
      'Future<void> _hydrateProfileFromBackend(SessionEpochGuard guard) async',
    );
    expect(
      migration,
      contains('ApiService.authenticatedTransport.beginOperation()'),
    );
    expect(migration, contains('await operation.requireSession()'));
    expect(migration, contains('await ApiService.claimLocalData('));
    expect(migration, contains('operation: operation'));

    final api = File('lib/services/api_service.dart').readAsStringSync();
    final claim = _between(
      api,
      'static Future<Map<String, dynamic>> claimLocalData({',
      'static Future<Map<String, dynamic>> verifyApplePurchase({',
    );
    expect(claim, contains('await operation.send('));
    expect(claim, contains('AuthenticatedHttpMethod.post'));
    expect(
      claim,
      contains("Uri.parse('\$baseUrl/sync/claim-local-data')"),
    );
  });
}

String _between(String source, String startMarker, String endMarker) {
  final start = source.indexOf(startMarker);
  final end = source.indexOf(endMarker, start + startMarker.length);
  expect(start, greaterThanOrEqualTo(0), reason: 'missing $startMarker');
  expect(end, greaterThan(start), reason: 'missing $endMarker');
  return source.substring(start, end);
}
