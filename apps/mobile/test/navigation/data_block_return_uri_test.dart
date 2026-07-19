import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/onboarding/data_block_enrichment_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _p0Origins = <String>[
  '/first-job',
  '/hypotheque',
  '/rente-vs-capital',
  '/invalidite',
  '/succession',
  '/segments/frontalier',
];

final _maliciousReturnUris = <String, String>{
  'external URI': 'https://evil.example/steal',
  'scheme-relative URI': '//evil.example/steal',
  'unknown internal route': '/not-registered',
  'auth route': '/auth/login?redirect=%2Fhome',
  'admin route': '/admin/routes',
  'plain traversal': '/first-job/../auth/login',
  'encoded traversal': '/first-job/%2e%2e/auth/login',
  'nested returnUri': Uri(
    path: '/first-job',
    queryParameters: const {'returnUri': 'https://evil.example/steal'},
  ).toString(),
  'sensitive query': Uri(
    path: '/first-job',
    queryParameters: const {'access_token': 'synthetic-secret'},
  ).toString(),
};

class _FakeNotificationsPlatform extends FlutterLocalNotificationsPlatform {
  @override
  Future<NotificationAppLaunchDetails?>
      getNotificationAppLaunchDetails() async => null;
}

class _ThrowingCoachProfileProvider extends CoachProfileProvider {
  int attempts = 0;

  @override
  Future<void> mergeAnswers(Map<String, dynamic> partial) async {
    attempts += 1;
    throw StateError('synthetic persistence failure');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    FlutterLocalNotificationsPlatform.instance = _FakeNotificationsPlatform();
  });

  group('G1-RETURN-01 exact P0 return-to-origin', () {
    for (final origin in _p0Origins) {
      testWidgets('save returns to $origin', (tester) async {
        final router = await _pumpProductionRouter(tester);
        await _openCollector(
          tester,
          router,
          returnUri: origin,
          inputKey: 'q_gender',
        );

        await tester.tap(find.byKey(const Key('gender_f_choice')));
        await tester.tap(find.byKey(const Key('salary_save_cta')));
        await _pumpFrames(tester);

        expect(_currentUri(router).toString(), origin);
      });

      testWidgets('cancel returns to $origin without relying on history',
          (tester) async {
        final router = await _pumpProductionRouter(tester);
        await _openCollector(
          tester,
          router,
          returnUri: origin,
          inputKey: 'q_gender',
        );

        await tester.tap(find.byIcon(Icons.arrow_back));
        await _pumpFrames(tester);

        expect(_currentUri(router).toString(), origin);
      });

      testWidgets('validation-error recovery returns to $origin',
          (tester) async {
        final router = await _pumpProductionRouter(tester);
        await _openCollector(
          tester,
          router,
          returnUri: origin,
          inputKey: 'q_birth_year',
        );

        await tester.enterText(
          find.byKey(const Key('birth_year_input')),
          '1800',
        );
        await tester.tap(find.byKey(const Key('salary_save_cta')));
        await _pumpFrames(tester);

        expect(_currentUri(router).path, '/data-block/revenu');
        final input = tester.widget<TextField>(
          find.byKey(const Key('birth_year_input')),
        );
        expect(input.controller!.text, '1800');

        await tester.tap(find.byIcon(Icons.arrow_back));
        await _pumpFrames(tester);

        expect(_currentUri(router).toString(), origin);
      });
    }

    testWidgets('save preserves an encoded origin query exactly once',
        (tester) async {
      final router = await _pumpProductionRouter(tester);
      final origin = Uri(
        path: '/rente-vs-capital',
        queryParameters: const {
          'tab': 'survivor risk',
          'focus': '3a/cash',
        },
      );
      await _openCollector(
        tester,
        router,
        returnUri: origin.toString(),
        inputKey: 'q_gender',
      );

      await tester.tap(find.byKey(const Key('gender_f_choice')));
      await tester.tap(find.byKey(const Key('salary_save_cta')));
      await _pumpFrames(tester);

      final returned = _currentUri(router);
      expect(returned.path, origin.path);
      expect(returned.queryParameters, origin.queryParameters);
    });
  });

  group('G1-RETURN-01 forged targets fail closed', () {
    for (final entry in _maliciousReturnUris.entries) {
      testWidgets('${entry.key} falls back to /home on save', (tester) async {
        final router = await _pumpProductionRouter(tester);
        await _openCollector(
          tester,
          router,
          returnUri: entry.value,
          inputKey: 'q_gender',
        );

        await tester.tap(find.byKey(const Key('gender_f_choice')));
        await tester.tap(find.byKey(const Key('salary_save_cta')));
        await _pumpFrames(tester);

        expect(_currentUri(router).toString(), '/home');
      });
    }
  });

  testWidgets(
      'provider persistence failure keeps input retryable and can exit to origin',
      (tester) async {
    final provider = _ThrowingCoachProfileProvider();
    final router = _providerFailureRouter();
    addTearDown(provider.dispose);
    addTearDown(router.dispose);

    await tester.pumpWidget(_minimalRouterHarness(provider, router));
    await tester.pump();
    await tester.tap(find.byKey(const Key('open_failing_collector')));
    await _pumpFrames(tester, frames: 2);

    await tester.tap(find.byKey(const Key('gender_f_choice')));
    await tester.tap(find.byKey(const Key('salary_save_cta')));
    await _pumpFrames(tester, frames: 2);

    final unhandled = tester.takeException();
    expect(unhandled, isNull, reason: 'the screen must absorb save failures');
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('gender_f_choice')))
          .selected,
      isTrue,
    );
    expect(find.byKey(const Key('data_block_save_error')), findsOneWidget);

    final retryFinder = find.byKey(const Key('data_block_save_retry_cta'));
    expect(retryFinder, findsOneWidget);
    expect(tester.widget<FilledButton>(retryFinder).onPressed, isNotNull);
    await tester.tap(retryFinder);
    await _pumpFrames(tester, frames: 2);

    expect(tester.takeException(), isNull);
    expect(provider.attempts, 2);
    expect(find.byKey(const Key('data_block_save_error')), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('gender_f_choice')))
          .selected,
      isTrue,
    );

    await tester.tap(find.byIcon(Icons.arrow_back));
    await _pumpFrames(tester, frames: 2);

    expect(_currentUri(router).toString(), '/first-job');
    expect(find.byKey(const Key('provider_error_origin')), findsOneWidget);
  });
}

GoRouter _providerFailureRouter() {
  return GoRouter(
    initialLocation: '/first-job',
    routes: [
      GoRoute(
        path: '/first-job',
        builder: (context, state) => Scaffold(
          key: const Key('provider_error_origin'),
          body: Builder(
            builder: (context) => FilledButton(
              key: const Key('open_failing_collector'),
              onPressed: () => context.push(
                Uri(
                  path: '/data-block/revenu',
                  queryParameters: const {
                    'inputKey': 'q_gender',
                    'returnUri': '/first-job',
                  },
                ).toString(),
              ),
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(
          key: Key('provider_error_wrong_fallback'),
        ),
      ),
      GoRoute(
        path: '/data-block/:type',
        builder: (context, state) => DataBlockEnrichmentScreen(
          blockType: state.pathParameters['type']!,
          initialInputKey: state.uri.queryParameters['inputKey'],
        ),
      ),
    ],
  );
}

Widget _minimalRouterHarness(
  CoachProfileProvider provider,
  GoRouter router,
) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>.value(value: provider),
      ChangeNotifierProvider(create: (_) => SlmProvider()),
    ],
    child: MaterialApp.router(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      routerConfig: router,
    ),
  );
}

Future<GoRouter> _pumpProductionRouter(WidgetTester tester) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(() {
    debugDefaultTargetPlatformOverride = null;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(const MintApp());
  await _pumpFrames(tester, frames: 40);

  final scaffold = find.byType(Scaffold);
  expect(scaffold, findsWidgets);
  return GoRouter.of(tester.element(scaffold.last));
}

Future<void> _openCollector(
  WidgetTester tester,
  GoRouter router, {
  required String returnUri,
  required String inputKey,
}) async {
  final collectorUri = Uri(
    path: '/data-block/revenu',
    queryParameters: {
      'inputKey': inputKey,
      'returnUri': returnUri,
    },
  );
  router.go(collectorUri.toString());
  await _pumpFrames(tester);

  expect(find.byType(DataBlockEnrichmentScreen), findsOneWidget);
  expect(_currentUri(router).path, '/data-block/revenu');
}

Uri _currentUri(GoRouter router) => router.routeInformationProvider.value.uri;

Future<void> _pumpFrames(
  WidgetTester tester, {
  int frames = 12,
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
