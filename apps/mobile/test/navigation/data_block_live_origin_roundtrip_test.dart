import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/routes/route_metadata.dart';
import 'package:mint_mobile/screens/coach/succession_patrimoine_screen.dart';
import 'package:mint_mobile/screens/disability/disability_gap_screen.dart';
import 'package:mint_mobile/screens/mortgage/affordability_screen.dart';
import 'package:mint_mobile/screens/onboarding/data_block_enrichment_screen.dart';
import 'package:mint_mobile/widgets/premium/mint_confidence_notice.dart';
import 'package:provider/provider.dart';

final class _MutableProfileProvider extends CoachProfileProvider {
  _MutableProfileProvider(Map<String, dynamic> initialAnswers)
      : _answers = Map<String, dynamic>.from(initialAnswers) {
    _rebuild();
  }

  final Map<String, dynamic> _answers;
  CoachProfile? _current;
  int failuresRemaining = 0;
  int persistenceAttempts = 0;

  @override
  CoachProfile? get profile => _current;

  @override
  bool get hasProfile => true;

  @override
  bool get isLoaded => true;

  @override
  Future<void> mergeAnswers(Map<String, dynamic> partial) async {
    persistenceAttempts += 1;
    if (failuresRemaining > 0) {
      failuresRemaining -= 1;
      throw StateError('synthetic direct-origin persistence failure');
    }
    _answers.addAll(partial);
    _rebuild();
    notifyListeners();
  }

  void _rebuild() {
    _current = CoachProfile.fromWizardAnswers(_answers);
  }
}

enum _OriginKind { mortgage, disability, succession }

final class _LiveOriginCase {
  const _LiveOriginCase({
    required this.name,
    required this.kind,
    required this.origin,
    required this.initialAnswers,
    required this.blockType,
    required this.inputKey,
  });

  final String name;
  final _OriginKind kind;
  final String origin;
  final Map<String, dynamic> initialAnswers;
  final String blockType;
  final String inputKey;
}

final _primaryCases = <_LiveOriginCase>[
  const _LiveOriginCase(
    name: 'Hypotheque revenue notice',
    kind: _OriginKind.mortgage,
    origin: '/hypotheque',
    initialAnswers: <String, dynamic>{'q_birth_year': 1985},
    blockType: 'revenu',
    inputKey: 'q_gross_salary_annual',
  ),
  _LiveOriginCase(
    name: 'Invalidite missing salary',
    kind: _OriginKind.disability,
    origin: '/invalidite',
    initialAnswers: <String, dynamic>{
      'q_birth_year': DateTime.now().year - 45,
      'q_cash_total': 42000,
      'q_housing_cost_period_chf': 2200,
      'q_lamal_premium_monthly_chf': 420,
      'q_employment_status': 'salarie',
    },
    blockType: 'revenu',
    inputKey: 'q_gross_salary_annual',
  ),
  const _LiveOriginCase(
    name: 'Succession missing property',
    kind: _OriginKind.succession,
    origin: '/succession',
    initialAnswers: <String, dynamic>{'q_birth_year': 1955},
    blockType: 'patrimoine',
    inputKey: 'q_property_market_value',
  ),
];

final _branchCases = <_LiveOriginCase>[
  _primaryCases[1],
  const _LiveOriginCase(
    name: 'Invalidite missing birth year',
    kind: _OriginKind.disability,
    origin: '/invalidite',
    initialAnswers: <String, dynamic>{
      'q_gross_salary_annual': 96000,
      'q_cash_total': 42000,
      'q_housing_cost_period_chf': 2200,
      'q_lamal_premium_monthly_chf': 420,
      'q_employment_status': 'salarie',
    },
    blockType: 'revenu',
    inputKey: 'q_birth_year',
  ),
  _LiveOriginCase(
    name: 'Invalidite missing liquid savings',
    kind: _OriginKind.disability,
    origin: '/invalidite',
    initialAnswers: <String, dynamic>{
      'q_gross_salary_annual': 96000,
      'q_birth_year': DateTime.now().year - 45,
      'q_housing_cost_period_chf': 2200,
      'q_lamal_premium_monthly_chf': 420,
      'q_employment_status': 'salarie',
    },
    blockType: 'patrimoine',
    inputKey: 'q_cash_total',
  ),
  _primaryCases[2],
  const _LiveOriginCase(
    name: 'Succession missing mortgage balance',
    kind: _OriginKind.succession,
    origin: '/succession',
    initialAnswers: <String, dynamic>{
      'q_birth_year': 1955,
      'q_property_market_value': 950000,
    },
    blockType: 'patrimoine',
    inputKey: '_coach_dettes_hypotheque',
  ),
];

final _actionCases = <_LiveOriginCase>[
  _primaryCases[0],
  ..._branchCases,
];

void main() {
  group('G1-RETURN-01 direct live producers', () {
    for (final liveCase in _branchCases) {
      testWidgets('${liveCase.name} emits the exact typed collector URI',
          (tester) async {
        await _pumpOrigin(tester, liveCase);

        await _tapRealOriginCta(tester, liveCase);

        _expectCollectorUri(tester, liveCase);
      });
    }

    for (final liveCase in _actionCases) {
      testWidgets('${liveCase.name} save returns to the live origin',
          (tester) async {
        await _pumpOrigin(tester, liveCase);
        await _tapRealOriginCta(tester, liveCase);
        _expectCollectorUri(tester, liveCase);

        await _enterValidFactAndSave(tester, liveCase.inputKey);

        _expectOriginUri(tester, liveCase);
      });

      testWidgets('${liveCase.name} cancel returns to the live origin',
          (tester) async {
        await _pumpOrigin(tester, liveCase);
        await _tapRealOriginCta(tester, liveCase);
        _expectCollectorUri(tester, liveCase);

        await tester.tap(find.byIcon(Icons.arrow_back));
        await _pumpFrames(tester);

        _expectOriginUri(tester, liveCase);
      });

      testWidgets(
          '${liveCase.name} keeps input retryable after failure then returns',
          (tester) async {
        final fixture = await _pumpOrigin(tester, liveCase);
        fixture.provider.failuresRemaining = 1;
        await _tapRealOriginCta(tester, liveCase);
        _expectCollectorUri(tester, liveCase);

        await _enterValidFact(tester, liveCase.inputKey);
        await tester.tap(_saveCtaFor(liveCase.inputKey));
        await _pumpFrames(tester);

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('data_block_save_error')), findsOneWidget);
        _expectEnteredFactRetained(tester, liveCase.inputKey);

        await tester.tap(
          find.byKey(const Key('data_block_save_retry_cta')),
        );
        await _pumpFrames(tester);

        expect(fixture.provider.persistenceAttempts, 2);
        _expectOriginUri(tester, liveCase);
      });
    }
  });
}

final class _OriginFixture {
  const _OriginFixture(this.provider);

  final _MutableProfileProvider provider;
}

Future<_OriginFixture> _pumpOrigin(
  WidgetTester tester,
  _LiveOriginCase liveCase,
) async {
  tester.view.physicalSize = const Size(1440, 16000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final provider = _MutableProfileProvider(liveCase.initialAnswers);
  final router = GoRouter(
    initialLocation: liveCase.origin,
    routes: <RouteBase>[
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
      GoRoute(
        path: '/data-block/:type',
        builder: (_, state) => DataBlockEnrichmentScreen(
          blockType: state.pathParameters['type']!,
          initialInputKey: state.uri.queryParameters['inputKey'],
          returnTarget: parseDataBlockReturnTarget(
            state.uri.queryParameters['returnUri'],
          ),
        ),
      ),
      GoRoute(
        path: '/budget/setup',
        builder: (_, __) => const Scaffold(body: Text('budget setup')),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Text('wrong fallback')),
      ),
    ],
  );
  addTearDown(provider.dispose);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachProfileProvider>.value(value: provider),
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
    ),
  );
  await _pumpFrames(tester, frames: 20);
  return _OriginFixture(provider);
}

Future<void> _tapRealOriginCta(
  WidgetTester tester,
  _LiveOriginCase liveCase,
) async {
  final Finder cta;
  switch (liveCase.kind) {
    case _OriginKind.mortgage:
      final notice = find.byType(MintConfidenceNotice);
      expect(notice, findsOneWidget);
      cta = find.descendant(
        of: notice,
        matching: find.byType(GestureDetector),
      );
    case _OriginKind.disability:
      cta = find.byKey(const Key('disability_gap_enrich_cta'));
    case _OriginKind.succession:
      final cardKey = liveCase.inputKey == 'q_property_market_value'
          ? const Key('succession_property_missing')
          : const Key('succession_mortgage_missing');
      cta = find.descendant(
        of: find.byKey(cardKey),
        matching: find.byType(FilledButton),
      );
  }
  expect(cta, findsOneWidget);
  await tester.ensureVisible(cta);
  await tester.tap(cta);
  await _pumpFrames(tester);
}

void _expectCollectorUri(WidgetTester tester, _LiveOriginCase liveCase) {
  final collector = find.byType(DataBlockEnrichmentScreen);
  expect(collector, findsOneWidget);
  final uri = GoRouterState.of(tester.element(collector)).uri;
  expect(uri.path, '/data-block/${liveCase.blockType}');
  expect(uri.queryParameters['inputKey'], liveCase.inputKey);
  expect(uri.queryParameters['returnUri'], liveCase.origin);
  expect(
    uri.queryParameters.keys,
    unorderedEquals(const <String>['inputKey', 'returnUri']),
  );
}

void _expectOriginUri(WidgetTester tester, _LiveOriginCase liveCase) {
  final origin = switch (liveCase.kind) {
    _OriginKind.mortgage => find.byType(AffordabilityScreen),
    _OriginKind.disability => find.byType(DisabilityGapScreen),
    _OriginKind.succession => find.byType(SuccessionPatrimoineScreen),
  };
  expect(origin, findsOneWidget);
  expect(
    GoRouterState.of(tester.element(origin)).uri.toString(),
    liveCase.origin,
  );
}

Future<void> _enterValidFactAndSave(
  WidgetTester tester,
  String inputKey,
) async {
  await _enterValidFact(tester, inputKey);
  await tester.tap(_saveCtaFor(inputKey));
  await _pumpFrames(tester);
}

Future<void> _enterValidFact(
  WidgetTester tester,
  String inputKey,
) async {
  final (fieldKey, value) = switch (inputKey) {
    'q_gross_salary_annual' => (const Key('salary_input'), '96000'),
    'q_birth_year' => (const Key('birth_year_input'), '1980'),
    'q_cash_total' => (const Key('savings_input'), '42000'),
    'q_property_market_value' => (
        const Key('property_market_value_input'),
        '950000'
      ),
    '_coach_dettes_hypotheque' => (
        const Key('mortgage_balance_input'),
        '320000'
      ),
    _ => throw StateError('unsupported inputKey $inputKey'),
  };
  await tester.enterText(find.byKey(fieldKey), value);
}

Finder _saveCtaFor(String inputKey) => find.byKey(
      Key(
        inputKey == 'q_gross_salary_annual' || inputKey == 'q_birth_year'
            ? 'salary_save_cta'
            : 'patrimoine_save_cta',
      ),
    );

void _expectEnteredFactRetained(WidgetTester tester, String inputKey) {
  final fieldKey = switch (inputKey) {
    'q_gross_salary_annual' => const Key('salary_input'),
    'q_birth_year' => const Key('birth_year_input'),
    'q_cash_total' => const Key('savings_input'),
    'q_property_market_value' => const Key('property_market_value_input'),
    '_coach_dettes_hypotheque' => const Key('mortgage_balance_input'),
    _ => throw StateError('unsupported inputKey $inputKey'),
  };
  expect(tester.widget<TextField>(find.byKey(fieldKey)).controller!.text,
      isNotEmpty);
}

Future<void> _pumpFrames(
  WidgetTester tester, {
  int frames = 12,
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
