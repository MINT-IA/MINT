import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/observability/mint_http_client.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _verifyPath = '/api/v1/auth/magic-link/verify';
const _mePath = '/api/v1/auth/me';
const _claimPath = '/api/v1/sync/claim-local-data';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late bool previousWedgeFlag;

  setUp(() {
    previousWedgeFlag = FeatureFlags.enableMvpWedgeOnboarding;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ApiService.setHttpClientForTesting(null);
  });

  tearDown(() {
    FeatureFlags.enableMvpWedgeOnboarding = previousWedgeFlag;
    ApiService.setHttpClientForTesting(null);
  });

  Widget buildVerifyScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CoachProfileProvider()),
      ],
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: const [S.delegate],
        routerConfig: GoRouter(
          initialLocation: '/verify',
          routes: [
            GoRoute(
              path: '/verify',
              builder: (_, __) =>
                  testOnlyMagicLinkVerifyScreen(token: 'magic-code'),
            ),
            GoRoute(
              path: '/coach/chat',
              builder: (_, __) =>
                  const Scaffold(body: Text('coach-chat-target')),
            ),
            GoRoute(
              path: '/onb',
              builder: (_, __) => const Scaffold(body: Text('onb-target')),
            ),
          ],
        ),
      ),
    );
  }

  void installMagicLinkMock(List<String> paths) {
    ApiService.setHttpClientForTesting(MintHttpClient(
      MockClient((request) async {
        paths.add(request.url.path);
        final body = switch (request.url.path) {
          _verifyPath => '{"accessToken":"magic-token","tokenType":"bearer"}',
          _mePath => '{"id":"magic-user","email":"magic@example.ch"}',
          '/api/v1/profiles/me' => '{}',
          _ => '{"detail":"not found"}',
        };
        return http.Response(
          body,
          body.contains('not found') ? 404 : 200,
          headers: {'content-type': 'application/json'},
        );
      }),
    ));
  }

  Future<List<String>> pumpHandoffGate(WidgetTester tester) async {
    FeatureFlags.enableMvpWedgeOnboarding = true;
    final paths = <String>[];
    installMagicLinkMock(paths);
    await ReportPersistenceService.saveMint2AxisHandoff({
      'onb_axis_v2': 'lpp_rente_capital',
      'onb_axis_schema_version': 2,
    });

    await tester.pumpWidget(buildVerifyScreen());
    await tester.pumpAndSettle();

    expect(paths, isEmpty);
    expect(find.text('Local data'), findsOneWidget);
    return paths;
  }

  testWidgets(
      'magic-link verifier offers handoff choice and waits before network call',
      (tester) async {
    final paths = await pumpHandoffGate(tester);

    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();

    expect(paths, containsAll([_verifyPath, _mePath]));
    expect(paths, isNot(contains(_claimPath)));
    expect(find.text('onb-target'), findsOneWidget);
  });

  testWidgets('magic-link verifier honors start-over choice before auth',
      (tester) async {
    final paths = await pumpHandoffGate(tester);
    expect(await ReportPersistenceService.loadMint2AxisHandoff(), isNotEmpty);

    await tester.tap(find.text('Start over'));
    await tester.pumpAndSettle();

    expect(paths, containsAll([_verifyPath, _mePath]));
    expect(paths, isNot(contains(_claimPath)));
    expect(await ReportPersistenceService.loadMint2AxisHandoff(), isEmpty);
    expect(find.text('onb-target'), findsOneWidget);
  });
}
