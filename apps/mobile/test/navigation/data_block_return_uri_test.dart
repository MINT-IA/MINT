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
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/routes/route_metadata.dart';
import 'package:mint_mobile/screens/arbitrage/rente_vs_capital_screen.dart';
import 'package:mint_mobile/screens/coach/succession_patrimoine_screen.dart';
import 'package:mint_mobile/screens/disability/disability_gap_screen.dart';
import 'package:mint_mobile/screens/first_job_screen.dart';
import 'package:mint_mobile/screens/frontalier_screen.dart';
import 'package:mint_mobile/screens/mortgage/affordability_screen.dart';
import 'package:mint_mobile/screens/onboarding/data_block_enrichment_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/widgets/coach/indicatif_banner.dart';
import 'package:mint_mobile/widgets/premium/mint_confidence_notice.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _routedOrigins = <String>[
  '/first-job',
  '/hypotheque',
  '/rente-vs-capital',
  '/invalidite',
  '/succession',
];

final _maliciousReturnUris = <String, List<String>>{
  'external URI': const ['https://evil.example/steal'],
  'scheme-relative URI': const ['//evil.example/steal'],
  'unknown internal route': const ['/not-registered'],
  'auth route': const ['/auth/login?redirect=%2Fhome'],
  'admin route': const ['/admin/routes'],
  'registered settings destination': const ['/settings/langue'],
  'registered report destination': const ['/rapport'],
  'plain traversal': const ['/first-job/../auth/login'],
  'encoded traversal': const ['/first-job/%2e%2e/auth/login'],
  'nested returnUri': [
    Uri(
      path: '/first-job',
      queryParameters: const {'returnUri': 'https://evil.example/steal'},
    ).toString(),
  ],
  'non-allowlisted query keys': [
    Uri(
      path: '/first-job',
      queryParameters: const {'access_token': 'synthetic-secret'},
    ).toString(),
    '/first-job?Access_Token=synthetic-secret',
    '/first-job?access%5Ftoken=synthetic-secret',
    '/first-job?t%61b=encoded-key-variant',
  ],
};

class _FakeNotificationsPlatform extends FlutterLocalNotificationsPlatform {
  @override
  Future<NotificationAppLaunchDetails?>
      getNotificationAppLaunchDetails() async => null;
}

class _ThrowingCoachProfileProvider extends CoachProfileProvider {
  int attempts = 0;
  int failuresRemaining = 1;
  final List<Map<String, dynamic>> writes = <Map<String, dynamic>>[];

  @override
  Future<void> mergeAnswers(Map<String, dynamic> partial) async {
    attempts += 1;
    if (failuresRemaining > 0) {
      failuresRemaining -= 1;
      throw StateError('synthetic persistence failure');
    }
    writes.add(Map<String, dynamic>.from(partial));
  }
}

final class _LiveProfileProvider extends CoachProfileProvider {
  _LiveProfileProvider(Map<String, dynamic> answers)
      : _answers = Map<String, dynamic>.from(answers),
        _profile = CoachProfile.fromWizardAnswers(answers);

  _LiveProfileProvider.fromProfile(CoachProfile profile)
      : _answers = <String, dynamic>{},
        _profile = profile;

  final Map<String, dynamic> _answers;
  CoachProfile _profile;
  final List<Map<String, dynamic>> writes = <Map<String, dynamic>>[];

  @override
  CoachProfile? get profile => _profile;

  @override
  bool get hasProfile => true;

  @override
  bool get isLoaded => true;

  @override
  Future<void> mergeAnswers(Map<String, dynamic> partial) async {
    writes.add(Map<String, dynamic>.from(partial));
    _answers.addAll(partial);
    _profile = CoachProfile.fromWizardAnswers(_answers);
    notifyListeners();
  }
}

enum _ProducerKind { work, housing, disability, succession }

final class _ProducerCase {
  const _ProducerCase({
    required this.kind,
    required this.origin,
    required this.blockType,
    required this.initialAnswers,
    this.inputKey,
  });

  final _ProducerKind kind;
  final String origin;
  final String blockType;
  final String? inputKey;
  final Map<String, dynamic> initialAnswers;
}

final _producerCases = <_ProducerCase>[
  const _ProducerCase(
    kind: _ProducerKind.work,
    origin: '/first-job',
    blockType: 'revenu',
    initialAnswers: <String, dynamic>{},
  ),
  const _ProducerCase(
    kind: _ProducerKind.housing,
    origin: '/hypotheque',
    blockType: 'revenu',
    inputKey: 'q_gross_salary_annual',
    initialAnswers: <String, dynamic>{'q_birth_year': 1985},
  ),
  _ProducerCase(
    kind: _ProducerKind.disability,
    origin: '/invalidite',
    blockType: 'revenu',
    inputKey: 'q_gross_salary_annual',
    initialAnswers: <String, dynamic>{
      'q_birth_year': DateTime.now().year - 45,
      'q_cash_total': 42000,
      'q_housing_cost_period_chf': 2200,
      'q_lamal_premium_monthly_chf': 420,
      'q_employment_status': 'salarie',
    },
  ),
  const _ProducerCase(
    kind: _ProducerKind.succession,
    origin: '/succession',
    blockType: 'patrimoine',
    inputKey: 'q_property_market_value',
    initialAnswers: <String, dynamic>{'q_birth_year': 1955},
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final originalFirstJobFlag = FeatureFlags.enableFirstJobScreen;
    addTearDown(
      () => FeatureFlags.enableFirstJobScreen = originalFirstJobFlag,
    );
    FeatureFlags.enableFirstJobScreen = true;
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    FlutterLocalNotificationsPlatform.instance = _FakeNotificationsPlatform();
  });

  group('G1-RETURN-01 real producer entry contracts', () {
    for (final producer in _producerCases) {
      testWidgets('${producer.kind.name} emits its exact collector intent',
          (tester) async {
        await _pumpRealProducer(tester, producer);
        await _tapRealProducerCta(tester, producer);

        final collector = find.byType(DataBlockEnrichmentScreen);
        expect(collector, findsOneWidget);
        final uri = GoRouterState.of(tester.element(collector)).uri;
        expect(uri.path, '/data-block/${producer.blockType}');
        expect(uri.queryParameters['returnUri'], producer.origin);
        expect(uri.queryParameters['inputKey'], producer.inputKey);
        expect(
          uri.queryParameters.keys,
          unorderedEquals(<String>[
            if (producer.inputKey != null) 'inputKey',
            'returnUri',
          ]),
        );
      });
    }

    testWidgets('retirement IndicatifBanner emits exact LPP return intent',
        (tester) async {
      await _pumpRetirementProducer(tester);

      final banner = find.byType(IndicatifBanner);
      expect(banner, findsOneWidget);
      final cta = find.descendant(
        of: banner,
        matching: find.byType(TextButton),
      );
      expect(cta, findsOneWidget);
      await tester.ensureVisible(cta);
      await tester.tap(cta);
      await _pumpFrames(tester);

      final collector = find.byType(DataBlockEnrichmentScreen);
      expect(collector, findsOneWidget);
      expect(
        GoRouterState.of(tester.element(collector)).uri.queryParameters,
        const <String, String>{'returnUri': '/rente-vs-capital'},
      );
    });

    testWidgets('Frontalier stays in place and emits no DataBlock returnUri',
        (tester) async {
      final fixture = await _pumpFrontalierProducer(tester);

      expect(_currentUri(fixture.router).toString(), '/segments/frontalier');
      expect(find.byType(DataBlockEnrichmentScreen), findsNothing);

      final residence = tester.widget<DropdownButton<String>>(
        find.byKey(const Key('frontier_residence_country_field')),
      );
      residence.onChanged!('FR');
      await _pumpFrames(tester, frames: 2);

      final workCountry = tester.widget<DropdownButton<String>>(
        find.byKey(const Key('frontier_work_country_field')),
      );
      workCountry.onChanged!('CH');
      await _pumpFrames(tester, frames: 2);

      expect(fixture.provider.writes, const <Map<String, dynamic>>[
        <String, dynamic>{'q_residence_country': 'FR'},
        <String, dynamic>{'q_work_country': 'CH'},
      ]);
      expect(_currentUri(fixture.router).toString(), '/segments/frontalier');
      expect(find.byType(DataBlockEnrichmentScreen), findsNothing);
      expect(
        _currentUri(fixture.router).queryParameters.containsKey('returnUri'),
        isFalse,
      );
    });
  });

  group('G1-RETURN-01 exact P0 return-to-origin', () {
    for (final origin in _routedOrigins) {
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
      expect(returned.toString(), origin.toString());
      expect(returned.toString(), isNot(contains('%2520')));
      expect(returned.toString(), isNot(contains('%252F')));
    });
  });

  group('G1-RETURN-01 forged targets fail closed', () {
    for (final entry in _maliciousReturnUris.entries) {
      testWidgets('${entry.key} falls back to /home on save', (tester) async {
        final router = await _pumpProductionRouter(tester);
        for (final returnUri in entry.value) {
          await _openCollector(
            tester,
            router,
            returnUri: returnUri,
            inputKey: 'q_gender',
          );

          await tester.tap(find.byKey(const Key('gender_f_choice')));
          await tester.tap(find.byKey(const Key('salary_save_cta')));
          await _pumpFrames(tester);

          expect(_currentUri(router).toString(), '/home');
        }
      });

      testWidgets('${entry.key} falls back to /home on AppBar cancel',
          (tester) async {
        final router = await _pumpProductionRouter(tester);
        for (final returnUri in entry.value) {
          await _openCollector(
            tester,
            router,
            returnUri: returnUri,
            inputKey: 'q_gender',
          );

          await tester.tap(find.byIcon(Icons.arrow_back));
          await _pumpFrames(tester);

          expect(_currentUri(router).toString(), '/home');
        }
      });

      testWidgets(
          '${entry.key} validation recovery then cancel falls back to /home',
          (tester) async {
        final router = await _pumpProductionRouter(tester);
        for (final returnUri in entry.value) {
          await _openCollector(
            tester,
            router,
            returnUri: returnUri,
            inputKey: 'q_birth_year',
          );
          await tester.enterText(
            find.byKey(const Key('birth_year_input')),
            '1800',
          );
          await tester.tap(find.byKey(const Key('salary_save_cta')));
          await _pumpFrames(tester);

          expect(_currentUri(router).path, '/data-block/revenu');
          expect(
            tester
                .widget<TextField>(find.byKey(const Key('birth_year_input')))
                .controller!
                .text,
            '1800',
          );

          await tester.tap(find.byIcon(Icons.arrow_back));
          await _pumpFrames(tester);
          expect(_currentUri(router).toString(), '/home');
        }
      });

      testWidgets('${entry.key} persistence retry succeeds only to /home',
          (tester) async {
        for (final returnUri in entry.value) {
          final provider = _ThrowingCoachProfileProvider();
          final router = _providerFailureRouter(
            '/first-job',
            returnUri: returnUri,
          );
          addTearDown(provider.dispose);
          addTearDown(router.dispose);
          await tester.pumpWidget(_minimalRouterHarness(provider, router));
          await tester.pump();
          await tester.tap(find.byKey(const Key('open_failing_collector')));
          await _pumpFrames(tester, frames: 2);
          await tester.tap(find.byKey(const Key('gender_f_choice')));
          await tester.tap(find.byKey(const Key('salary_save_cta')));
          await _pumpFrames(tester, frames: 2);

          expect(
              find.byKey(const Key('data_block_save_error')), findsOneWidget);
          expect(
            tester
                .widget<ChoiceChip>(find.byKey(const Key('gender_f_choice')))
                .selected,
            isTrue,
          );
          await tester.tap(find.byKey(const Key('data_block_save_retry_cta')));
          await _pumpFrames(tester, frames: 2);

          expect(provider.attempts, 2);
          expect(_currentUri(router).toString(), '/home');
        }
      });

      testWidgets('${entry.key} persistence failure then cancel goes /home',
          (tester) async {
        for (final returnUri in entry.value) {
          final provider = _ThrowingCoachProfileProvider();
          final router = _providerFailureRouter(
            '/first-job',
            returnUri: returnUri,
          );
          addTearDown(provider.dispose);
          addTearDown(router.dispose);
          await tester.pumpWidget(_minimalRouterHarness(provider, router));
          await tester.pump();
          await tester.tap(find.byKey(const Key('open_failing_collector')));
          await _pumpFrames(tester, frames: 2);
          await tester.tap(find.byKey(const Key('gender_f_choice')));
          await tester.tap(find.byKey(const Key('salary_save_cta')));
          await _pumpFrames(tester, frames: 2);

          expect(
              find.byKey(const Key('data_block_save_error')), findsOneWidget);
          await tester.tap(find.byIcon(Icons.arrow_back));
          await _pumpFrames(tester, frames: 2);

          expect(provider.attempts, 1);
          expect(provider.writes, isEmpty);
          expect(_currentUri(router).toString(), '/home');
        }
      });
    }
  });

  group('G1-RETURN-01 persistence recovery routed matrix', () {
    for (final origin in _routedOrigins) {
      testWidgets('$origin retains input then retry succeeds to exact origin',
          (tester) async {
        final provider = _ThrowingCoachProfileProvider();
        final router = _providerFailureRouter(origin);
        addTearDown(provider.dispose);
        addTearDown(router.dispose);

        await tester.pumpWidget(_minimalRouterHarness(provider, router));
        await tester.pump();
        await tester.tap(find.byKey(const Key('open_failing_collector')));
        await _pumpFrames(tester, frames: 2);

        await tester.tap(find.byKey(const Key('gender_f_choice')));
        await tester.tap(find.byKey(const Key('salary_save_cta')));
        await _pumpFrames(tester, frames: 2);

        expect(tester.takeException(), isNull,
            reason: 'the screen must absorb save failures');
        expect(
          tester
              .widget<ChoiceChip>(find.byKey(const Key('gender_f_choice')))
              .selected,
          isTrue,
        );
        expect(find.byKey(const Key('data_block_save_error')), findsOneWidget);

        final retry = find.byKey(const Key('data_block_save_retry_cta'));
        expect(retry, findsOneWidget);
        await tester.tap(retry);
        await _pumpFrames(tester, frames: 2);

        expect(tester.takeException(), isNull);
        expect(provider.attempts, 2);
        expect(provider.writes, const <Map<String, dynamic>>[
          <String, dynamic>{'q_gender': 'F'},
        ]);
        expect(_currentUri(router).toString(), origin);
        expect(find.byKey(const Key('provider_error_origin')), findsOneWidget);
      });
    }
  });
}

GoRouter _providerFailureRouter(String origin, {String? returnUri}) {
  return GoRouter(
    initialLocation: origin,
    routes: [
      for (final routedOrigin in _routedOrigins)
        GoRoute(
          path: routedOrigin,
          builder: (context, state) => Scaffold(
            key: const Key('provider_error_origin'),
            body: Builder(
              builder: (context) => FilledButton(
                key: const Key('open_failing_collector'),
                onPressed: () => context.push(
                  Uri(
                    path: '/data-block/revenu',
                    queryParameters: {
                      'inputKey': 'q_gender',
                      'returnUri': returnUri ?? routedOrigin,
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
        path: '/settings/langue',
        builder: (context, state) => const Scaffold(
          key: Key('inappropriate_settings_destination'),
        ),
      ),
      GoRoute(
        path: '/rapport',
        builder: (context, state) => const Scaffold(
          key: Key('inappropriate_report_destination'),
        ),
      ),
      GoRoute(
        path: '/data-block/:type',
        builder: (context, state) {
          final returnTarget = parseDataBlockReturnTarget(
            state.uri.queryParameters['returnUri'],
          );
          return DataBlockEnrichmentScreen(
            blockType: state.pathParameters['type']!,
            initialInputKey: state.uri.queryParameters['inputKey'],
            returnTarget: returnTarget,
          );
        },
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

Future<void> _pumpRealProducer(
  WidgetTester tester,
  _ProducerCase producer,
) async {
  _configureLargeTestView(tester);
  final provider = _LiveProfileProvider(producer.initialAnswers);
  final router = GoRouter(
    initialLocation: producer.origin,
    routes: <RouteBase>[
      GoRoute(path: '/first-job', builder: (_, __) => const FirstJobScreen()),
      GoRoute(
        path: '/hypotheque',
        builder: (_, __) => const AffordabilityScreen(),
      ),
      GoRoute(
        path: '/invalidite',
        builder: (_, __) => const DisabilityGapScreen(),
      ),
      GoRoute(
        path: '/succession',
        builder: (_, __) => const SuccessionPatrimoineScreen(),
      ),
      _dataBlockTestRoute(),
      GoRoute(path: '/home', builder: (_, __) => const Scaffold()),
      GoRoute(
        path: '/budget/setup',
        builder: (_, __) => const Scaffold(),
      ),
    ],
  );
  addTearDown(provider.dispose);
  addTearDown(router.dispose);
  await tester.pumpWidget(_producerHarness(provider, router));
  await _pumpFrames(tester, frames: 20);
}

Future<void> _tapRealProducerCta(
  WidgetTester tester,
  _ProducerCase producer,
) async {
  final Finder cta;
  switch (producer.kind) {
    case _ProducerKind.work:
      cta = find.descendant(
        of: find.byKey(const Key('first_job_enrich_profile_cta')),
        matching: find.byType(TextButton),
      );
    case _ProducerKind.housing:
      final notice = find.byKey(const Key('mortgage_enrich_profile_cta'));
      expect(notice, findsOneWidget);
      expect(tester.widget(notice), isA<MintConfidenceNotice>());
      cta = find.descendant(
        of: notice,
        matching: find.byType(GestureDetector),
      );
    case _ProducerKind.disability:
      cta = find.byKey(const Key('disability_gap_enrich_cta'));
    case _ProducerKind.succession:
      cta = find.descendant(
        of: find.byKey(const Key('succession_property_missing')),
        matching: find.byType(FilledButton),
      );
  }
  expect(cta, findsOneWidget);
  await tester.ensureVisible(cta);
  await tester.tap(cta);
  await _pumpFrames(tester);
}

Future<void> _pumpRetirementProducer(WidgetTester tester) async {
  _configureLargeTestView(tester);
  final provider = _LiveProfileProvider.fromProfile(
    CoachProfile(
      birthYear: 1976,
      canton: 'VD',
      salaireBrutMensuel: 9000,
      prevoyance: const PrevoyanceProfile(
        avoirLppTotal: 350000,
        tauxConversion: 0.06,
      ),
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2041),
        label: 'Retraite',
      ),
    ),
  );
  final router = GoRouter(
    initialLocation: '/rente-vs-capital',
    routes: <RouteBase>[
      GoRoute(
        path: '/rente-vs-capital',
        builder: (_, __) => const RenteVsCapitalScreen(),
      ),
      _dataBlockTestRoute(),
      GoRoute(path: '/home', builder: (_, __) => const Scaffold()),
    ],
  );
  addTearDown(provider.dispose);
  addTearDown(router.dispose);
  await tester.pumpWidget(_producerHarness(provider, router));
  await _pumpFrames(tester, frames: 30);
}

final class _FrontalierFixture {
  const _FrontalierFixture(this.provider, this.router);

  final _LiveProfileProvider provider;
  final GoRouter router;
}

Future<_FrontalierFixture> _pumpFrontalierProducer(
  WidgetTester tester,
) async {
  _configureLargeTestView(tester);
  final provider = _LiveProfileProvider(const <String, dynamic>{
    'q_birth_year': 1985,
    'q_residence_permit': 'G',
  });
  final router = GoRouter(
    initialLocation: '/segments/frontalier',
    routes: <RouteBase>[
      GoRoute(
        path: '/segments/frontalier',
        builder: (_, __) => const FrontalierScreen(),
      ),
      GoRoute(path: '/coach/chat', builder: (_, __) => const Scaffold()),
      _dataBlockTestRoute(),
      GoRoute(path: '/home', builder: (_, __) => const Scaffold()),
    ],
  );
  addTearDown(provider.dispose);
  addTearDown(router.dispose);
  await tester.pumpWidget(_producerHarness(provider, router));
  await _pumpFrames(tester, frames: 10);
  return _FrontalierFixture(provider, router);
}

GoRoute _dataBlockTestRoute() => GoRoute(
      path: '/data-block/:type',
      builder: (_, state) => DataBlockEnrichmentScreen(
        blockType: state.pathParameters['type']!,
        initialInputKey: state.uri.queryParameters['inputKey'],
        returnTarget: parseDataBlockReturnTarget(
          state.uri.queryParameters['returnUri'],
        ),
      ),
    );

Widget _producerHarness(CoachProfileProvider provider, GoRouter router) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>.value(value: provider),
      ChangeNotifierProvider<ScanSessionProvider>(
        create: (_) => ScanSessionProvider(),
      ),
      ChangeNotifierProvider<DocumentProvider>(
        create: (_) => DocumentProvider(),
      ),
      ChangeNotifierProvider<ByokProvider>(create: (_) => ByokProvider()),
      ChangeNotifierProvider<SlmProvider>(create: (_) => SlmProvider()),
    ],
    child: MaterialApp.router(
      locale: const Locale('fr'),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
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

void _configureLargeTestView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 16000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<GoRouter> _pumpProductionRouter(WidgetTester tester) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  try {
    await tester.pumpWidget(const MintApp());
    await _pumpFrames(tester, frames: 40);
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }

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
