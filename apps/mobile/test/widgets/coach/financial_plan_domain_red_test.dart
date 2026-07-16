import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/widgets/coach/plan_preview_card.dart';
import 'package:mint_mobile/widgets/coach/financial_plan_setup_card.dart';
import 'package:mint_mobile/widgets/coach/widget_renderer.dart';
import 'package:mint_mobile/widgets/home/financial_plan_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _calculatorNarrative =
    'Narration calculateur synthétique — aucune donnée LLM.';
const _llmNarrative = 'NARRATION LLM SENTINELLE À NE JAMAIS AFFICHER';
const _specificSource =
    'Calcul MINT synthétique — objectif CHF divisé par mois restants';
const _mandatoryMintDisclaimer =
    'Les résultats présentés sont des estimations à titre indicatif, '
    'basées sur les données fournies et la législation en vigueur. '
    'Ils ne constituent pas un conseil financier personnalisé. '
    'Consultez un·e spécialiste pour votre situation spécifique.';

CoachProfileProvider _loadedLedger() {
  return CoachProfileProvider()
    ..createFromRemoteProfile({
      'birth_year': 1986,
      'canton': 'VD',
      'income_gross_yearly': 96000.0,
    });
}

FinancialPlan _planFor(CoachProfileProvider ledger) {
  final profile = ledger.profile!;
  final targetDate = DateTime.now().add(const Duration(days: 730));
  return FinancialPlan(
    id: 'synthetic-domain-plan',
    goalDescription: 'Objectif synthétique explicite',
    goalCategory: 'goal_general',
    monthlyTarget: 1000,
    milestones: [
      PlanMilestone(
        targetDate: targetDate,
        targetAmount: 24000,
        description: '100% atteint — 24000 CHF',
      ),
    ],
    projectedOutcome: 24000,
    targetDate: targetDate,
    generatedAt: DateTime(2026, 7, 16),
    profileHashAtGeneration: computeProfileHash(profile),
    coachNarrative: _calculatorNarrative,
    confidenceLevel: 50,
    sources: const [_specificSource],
    disclaimer: _mandatoryMintDisclaimer,
  );
}

FinancialPlan _retirementPlan({
  double confidence = 85,
  bool hasLpp = true,
}) {
  final targetDate = DateTime(2051, 7, 16);
  return FinancialPlan.fromJson({
    'id': 'synthetic-retirement-plan',
    'goalDescription': 'Retraite synthétique explicite',
    'goalCategory': 'goal_retirement_plan',
    'monthlyTarget': 500.0,
    'milestones': [
      {
        'targetDate': targetDate.toIso8601String(),
        'targetAmount': 300000.0,
        'description': '100% atteint — 300000 CHF',
      },
    ],
    'projectedOutcome': 300000.0,
    if (hasLpp) 'projectedLow': 250000.0,
    if (hasLpp) 'projectedHigh': 350000.0,
    'targetDate': targetDate.toIso8601String(),
    'generatedAt': DateTime(2026, 7, 16).toIso8601String(),
    'profileHashAtGeneration': 'mint-plan-input:v2:sha256:synthetic',
    'coachNarrative': _calculatorNarrative,
    'confidenceLevel': confidence,
    'sources': ['LPP art. 8', 'LPP art. 15–16'],
    'disclaimer': _mandatoryMintDisclaimer,
    'projectionAssumptions': {
      if (hasLpp) 'caisseReturnBase': 0.02,
      if (hasLpp) 'caisseReturnLow': 0.01,
      if (hasLpp) 'caisseReturnHigh': 0.03,
      'supplementalMonthlySavingsReturn': 0.0,
      'salaryBasis': {
        'kind': hasLpp ? 'monthlySalaryTimesTwelve' : 'notApplicable',
        if (hasLpp) 'annualChf': 96000.0,
      },
      'bonificationBasis': {
        'kind': hasLpp ? 'legalAgeSchedule' : 'notApplicable',
      },
      'projectionAsOf': DateTime(2026, 7, 16).toIso8601String(),
    },
  });
}

FinancialPlan _generalScenarioPlan({
  required List<Map<String, dynamic>> milestones,
  double? goalAmount,
}) {
  final targetDate = DateTime.now().add(const Duration(days: 730));
  return FinancialPlan.fromJson({
    'id': 'synthetic-general-scenario',
    'goalDescription': 'Réserve synthétique explicite',
    'goalCategory': 'goal_general',
    'monthlyTarget': 1000.0,
    'milestones': milestones,
    'projectedOutcome': goalAmount ?? 24000.0,
    'targetDate': targetDate.toIso8601String(),
    'generatedAt': DateTime(2026, 7, 16).toIso8601String(),
    'profileHashAtGeneration': 'mint-plan-input:v2:sha256:stale',
    'coachNarrative': _calculatorNarrative,
    'confidenceLevel': 50.0,
    'sources': const <String>[],
    'disclaimer': _mandatoryMintDisclaimer,
    if (goalAmount != null) 'goalAmount': goalAmount,
    'scenarioId': 'scenario-general-synthetic',
    'confirmedAt': DateTime.utc(2026, 7, 16, 12).toIso8601String(),
    'inputAsOf': DateTime.utc(2026, 7, 15).toIso8601String(),
  });
}

class _CountingFinancialPlanProvider extends FinancialPlanProvider {
  int setPlanCalls = 0;

  @override
  Future<void> setPlan(FinancialPlan plan) {
    setPlanCalls++;
    return super.setPlan(plan);
  }
}

class _ThrowingFinancialPlanProvider extends FinancialPlanProvider {
  int setPlanCalls = 0;

  @override
  Future<void> setPlan(FinancialPlan plan) async {
    setPlanCalls++;
    throw StateError('synthetic provider write failure');
  }
}

class _TestLedger extends CoachProfileProvider {
  _TestLedger(this._profile);

  CoachProfile _profile;

  @override
  CoachProfile get profile => _profile;

  @override
  bool get isLoaded => true;

  void replaceProfile(CoachProfile profile) {
    _profile = profile;
    notifyListeners();
  }
}

_TestLedger _ownedRetirementLedger() {
  final now = DateTime.now();
  final sourceDate = DateTime(now.year, now.month, 1);
  const factPaths = [
    'salaireBrutMensuel',
    'dateOfBirth',
    'prevoyance.hasPensionFund',
    'prevoyance.avoirLppTotal',
    'prevoyance.avoirLppObligatoire',
    'prevoyance.avoirLppSurobligatoire',
    'prevoyance.rendementCaisse',
    'prevoyance.rendementCaisseConnu',
    'prevoyance.salaireAssure',
    'prevoyance.bonificationRate',
  ];
  return _TestLedger(
    CoachProfile(
      birthYear: now.year - 40,
      dateOfBirth: DateTime(now.year - 40, 1, 1),
      canton: 'VD',
      salaireBrutMensuel: 8000,
      prevoyance: const PrevoyanceProfile(
        hasPensionFund: true,
        avoirLppTotal: 150000,
        avoirLppObligatoire: 100000,
        avoirLppSurobligatoire: 50000,
        rendementCaisse: 0.02,
        rendementCaisseConnu: true,
        salaireAssure: 90000,
        bonificationRate: 0.18,
        totalEpargne3a: 30000,
      ),
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(now.year + 25, 1, 1),
        label: 'Retraite synthétique',
      ),
      financialLiteracyLevel: FinancialLiteracyLevel.advanced,
      dataSources: {
        for (final path in factPaths) path: ProfileDataSource.certificate,
      },
      dataTimestamps: {
        for (final path in factPaths) path: now,
      },
      dataSourceDates: {
        for (final path in factPaths) path: sourceDate,
      },
      inferDataSources: false,
    ),
  );
}

Widget _localized(Widget child, {Locale locale = const Locale('fr')}) {
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    locale: locale,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

Widget _localizedWithEnrichmentRoute(
  Widget child, {
  Locale locale = const Locale('fr'),
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
      GoRoute(
        path: '/data-block/:type',
        builder: (_, state) => Scaffold(
          body: Text(
            'data-block:${state.pathParameters['type']}',
            key: const Key('financial_plan_enrichment_destination'),
          ),
        ),
      ),
    ],
  );
  return MaterialApp.router(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    locale: locale,
    routerConfig: router,
  );
}

Widget _toolHarness({
  required CoachProfileProvider ledger,
  required FinancialPlanProvider plans,
  required Map<String, dynamic> input,
  Locale locale = const Locale('fr'),
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>.value(value: ledger),
      ChangeNotifierProvider<FinancialPlanProvider>.value(value: plans),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      locale: locale,
      home: Scaffold(
        body: Builder(
          builder: (context) => WidgetRenderer.build(
            context,
            RagToolCall(name: 'generate_financial_plan', input: input),
          )!,
        ),
      ),
    ),
  );
}

Widget _directSetupHarness({
  required CoachProfileProvider ledger,
  required FinancialPlanProvider plans,
  required DateTime Function() clock,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>.value(value: ledger),
      ChangeNotifierProvider<FinancialPlanProvider>.value(value: plans),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      locale: const Locale('fr'),
      home: Scaffold(
        body: FinancialPlanSetupCard(
          goalHint: 'Constituer une réserve',
          planProvider: plans,
          clock: clock,
        ),
      ),
    ),
  );
}

Future<void> _pumpAsync(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _reachRetirementConfirmation(
  WidgetTester tester, {
  required DateTime targetDate,
}) async {
  await tester.tap(
    find.bySemanticsIdentifier('financial_plan_setup_category_retirement'),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.bySemanticsIdentifier('financial_plan_setup_retirement_horizon'),
  );
  await tester.tap(
    find.bySemanticsIdentifier('financial_plan_setup_retirement_scope'),
  );
  await tester.tap(
    find.bySemanticsIdentifier('financial_plan_setup_return_assumption_2'),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continuer'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.bySemanticsIdentifier('financial_plan_setup_amount'),
    '3000000',
  );
  await tester.enterText(
    find.bySemanticsIdentifier('financial_plan_setup_target_date'),
    DateFormat('yyyy-MM-dd').format(targetDate),
  );
  await tester.tap(
    find.bySemanticsIdentifier('financial_plan_setup_review'),
  );
  await _pumpAsync(tester);
}

Future<String> _persistedWizardBytes() async {
  final preferences = await SharedPreferences.getInstance();
  final keys = preferences
      .getKeys()
      .where((key) => key != 'financial_plan_v1')
      .toList()
    ..sort();
  return jsonEncode({
    for (final key in keys)
      key: switch (preferences.get(key)) {
        final Set<String> value => value.toList()..sort(),
        final value => value,
      },
  });
}

int _renderedTextCount(WidgetTester tester, String fragment) {
  final normalizedFragment =
      fragment.replaceAll('\u00a0', ' ').replaceAll('\u202f', ' ');
  return tester.widgetList<Text>(find.byType(Text)).where((text) {
    return (text.data ?? '')
        .replaceAll('\u00a0', ' ')
        .replaceAll('\u202f', ' ')
        .contains(normalizedFragment);
  }).length;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FeatureFlags.financialPlanSetupEnabled = true;
  });

  tearDown(() => FeatureFlags.financialPlanSetupEnabled = false);

  group('G1-BND-06 domain RED — Coach and Aujourd’hui surfaces', () {
    testWidgets(
      'intent-only plan tool opens setup and ignores every legacy value',
      (tester) async {
        final ledger = _loadedLedger();
        final plans = FinancialPlanProvider()..attachProfileProvider(ledger);
        addTearDown(ledger.dispose);
        addTearDown(plans.dispose);

        await tester.pumpWidget(
          _toolHarness(
            ledger: ledger,
            plans: plans,
            input: const {
              'goal': 'Préparer ma retraite',
              'goal_category': 'goal_retirement_plan',
              'monthly_amount': 999999,
              'goal_amount': 1,
              'target_date': '2027-01-01',
              'narrative': _llmNarrative,
            },
          ),
        );
        await _pumpAsync(tester);

        expect(
          (
            find
                .bySemanticsIdentifier('financial_plan_setup')
                .evaluate()
                .length,
            find
                .bySemanticsIdentifier('financial_plan_setup_category')
                .evaluate()
                .length,
            find
                .bySemanticsIdentifier('financial_plan_generation_error')
                .evaluate()
                .length,
            plans.hasPlan,
          ),
          equals((1, 1, 0, false)),
          reason: 'The backend/BYOK tool owns only a display hint. Legacy '
              'numeric, date, category, and narrative values must not skip the '
              'Flutter-owned progressive setup or render as an error.',
        );
      },
    );

    testWidgets(
      'retirement setup asks horizon and scope before amount and target date',
      (tester) async {
        final ledger = _loadedLedger();
        final plans = FinancialPlanProvider()..attachProfileProvider(ledger);
        addTearDown(ledger.dispose);
        addTearDown(plans.dispose);

        await tester.pumpWidget(
          _toolHarness(
            ledger: ledger,
            plans: plans,
            input: const {'goal': 'Préparer ma retraite'},
          ),
        );
        await _pumpAsync(tester);

        final retirementCategory = find.bySemanticsIdentifier(
          'financial_plan_setup_category_retirement',
        );
        expect(
          retirementCategory,
          findsOneWidget,
          reason: 'The first setup step requires user-owned category choice.',
        );
        await tester.tap(retirementCategory);
        await tester.pumpAndSettle();

        expect(
          (
            find
                .bySemanticsIdentifier(
                    'financial_plan_setup_retirement_horizon')
                .evaluate()
                .length,
            find
                .bySemanticsIdentifier('financial_plan_setup_retirement_scope')
                .evaluate()
                .length,
            find
                .bySemanticsIdentifier(
                  'financial_plan_setup_return_assumption',
                )
                .evaluate()
                .length,
            find
                .bySemanticsIdentifier('financial_plan_setup_amount')
                .evaluate()
                .length,
            find
                .bySemanticsIdentifier('financial_plan_setup_target_date')
                .evaluate()
                .length,
            plans.hasPlan,
          ),
          equals((1, 1, 1, 0, 0, false)),
          reason: 'Retirement needs an explicit capital/horizon scope before '
              'collecting the owned CHF amount and date, and a future return '
              'must be chosen rather than inherited from the certificate.',
        );
      },
    );

    testWidgets(
      'setup persists exactly one plan only after final confirmation',
      (tester) async {
        final ledger = _loadedLedger();
        final plans = _CountingFinancialPlanProvider()
          ..attachProfileProvider(ledger);
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString(
          '_coach_g1_bnd06_wizard_sentinel',
          'unchanged',
        );
        final profileBytesBefore = jsonEncode(ledger.profile!.toJson());
        final goalABytesBefore = jsonEncode(ledger.profile!.goalA.toJson());
        final wizardBytesBefore = await _persistedWizardBytes();
        addTearDown(ledger.dispose);
        addTearDown(plans.dispose);

        await tester.pumpWidget(
          _toolHarness(
            ledger: ledger,
            plans: plans,
            input: const {'goal': 'Constituer une réserve'},
          ),
        );
        await _pumpAsync(tester);

        final generalCategory = find.bySemanticsIdentifier(
          'financial_plan_setup_category_general',
        );
        expect(
          generalCategory,
          findsOneWidget,
          reason: 'The first setup step requires user-owned category choice.',
        );
        await tester.tap(generalCategory);
        await tester.pumpAndSettle();
        expect(plans.setPlanCalls, 0);

        await tester.enterText(
          find.bySemanticsIdentifier('financial_plan_setup_amount'),
          '24,000',
        );
        await tester.enterText(
          find.bySemanticsIdentifier('financial_plan_setup_target_date'),
          '2028-07-16',
        );
        await tester.tap(
          find.bySemanticsIdentifier('financial_plan_setup_review'),
        );
        await tester.pumpAndSettle();

        expect(
          (
            find
                .bySemanticsIdentifier('financial_plan_setup_confirmation')
                .evaluate()
                .length,
            plans.setPlanCalls,
            plans.hasPlan,
          ),
          equals((1, 0, false)),
          reason: 'The summary is a confirmation boundary, not a persistence '
              'side effect.',
        );

        final confirm =
            find.bySemanticsIdentifier('financial_plan_setup_confirm');
        await tester.tap(confirm);
        await tester.tap(confirm);
        await _pumpAsync(tester);

        expect(
          (
            plans.setPlanCalls,
            plans.hasPlan,
            jsonEncode(ledger.profile!.toJson()),
            jsonEncode(ledger.profile!.goalA.toJson()),
            await _persistedWizardBytes(),
          ),
          equals((
            1,
            true,
            profileBytesBefore,
            goalABytesBefore,
            wizardBytesBefore,
          )),
          reason: 'The confirmed calculator result crosses provider.setPlan '
              'exactly once and never rewrites CoachProfile, GoalA, or wizard '
              'persistence.',
        );
      },
    );

    testWidgets(
      'provider failure leaves setup recoverable and never publishes a plan',
      (tester) async {
        final ledger = _loadedLedger();
        final plans = _ThrowingFinancialPlanProvider()
          ..attachProfileProvider(ledger);
        addTearDown(ledger.dispose);
        addTearDown(plans.dispose);

        await tester.pumpWidget(
          _toolHarness(
            ledger: ledger,
            plans: plans,
            input: const {'goal': 'Constituer une réserve'},
          ),
        );
        await _pumpAsync(tester);

        final generalCategory = find.bySemanticsIdentifier(
          'financial_plan_setup_category_general',
        );
        expect(generalCategory, findsOneWidget);
        await tester.tap(generalCategory);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.bySemanticsIdentifier('financial_plan_setup_amount'),
          '24,000',
        );
        await tester.enterText(
          find.bySemanticsIdentifier('financial_plan_setup_target_date'),
          '2028-07-16',
        );
        await tester.tap(
          find.bySemanticsIdentifier('financial_plan_setup_review'),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.bySemanticsIdentifier('financial_plan_setup_confirm'),
        );
        await _pumpAsync(tester);

        expect(
          (
            plans.setPlanCalls,
            plans.hasPlan,
            find
                .bySemanticsIdentifier('financial_plan_setup_error')
                .evaluate()
                .length,
            find
                .bySemanticsIdentifier('financial_plan_setup')
                .evaluate()
                .length,
          ),
          equals((1, false, 1, 1)),
          reason: 'A failed atomic provider write must keep the confirmed '
              'inputs available for a localized retry and publish no plan.',
        );
      },
    );

    testWidgets(
      'final tap owns confirmedAt rather than the earlier draft review',
      (tester) async {
        final ledger = _loadedLedger();
        final plans = _CountingFinancialPlanProvider()
          ..attachProfileProvider(ledger);
        var clock = DateTime(2026, 7, 16, 9);
        addTearDown(ledger.dispose);
        addTearDown(plans.dispose);

        await tester.pumpWidget(
          _directSetupHarness(
            ledger: ledger,
            plans: plans,
            clock: () => clock,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.bySemanticsIdentifier('financial_plan_setup_category_general'),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.bySemanticsIdentifier('financial_plan_setup_amount'),
          '24000',
        );
        await tester.enterText(
          find.bySemanticsIdentifier('financial_plan_setup_target_date'),
          '2028-07-16',
        );
        await tester.tap(
          find.bySemanticsIdentifier('financial_plan_setup_review'),
        );
        await _pumpAsync(tester);

        expect((plans.setPlanCalls, plans.hasPlan), equals((0, false)));
        clock = DateTime(2026, 7, 16, 9, 5);
        await tester.tap(
          find.bySemanticsIdentifier('financial_plan_setup_confirm'),
        );
        await _pumpAsync(tester);

        expect(plans.currentPlan?.generatedAt, DateTime(2026, 7, 16, 9));
        expect(plans.currentPlan?.confirmedAt, DateTime(2026, 7, 16, 9, 5));
        expect(
          plans.currentPlan!.confirmedAt!.isAfter(
            plans.currentPlan!.generatedAt,
          ),
          isTrue,
          reason: 'Review prepares an exact draft; only the final tap owns '
              'the persisted consent timestamp.',
        );
      },
    );

    testWidgets(
      'ledger mutation between review and confirmation forces a fresh review',
      (tester) async {
        final ledger = _ownedRetirementLedger();
        final plans = _CountingFinancialPlanProvider()
          ..attachProfileProvider(ledger);
        final clock = DateTime(2026, 7, 16, 9);
        addTearDown(ledger.dispose);
        addTearDown(plans.dispose);

        await tester.pumpWidget(
          _directSetupHarness(
            ledger: ledger,
            plans: plans,
            clock: () => clock,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.bySemanticsIdentifier('financial_plan_setup_category_general'),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.bySemanticsIdentifier('financial_plan_setup_amount'),
          '24000',
        );
        await tester.enterText(
          find.bySemanticsIdentifier('financial_plan_setup_target_date'),
          '2028-07-16',
        );
        await tester.tap(
          find.bySemanticsIdentifier('financial_plan_setup_review'),
        );
        await _pumpAsync(tester);

        ledger.replaceProfile(
          ledger.profile.copyWith(salaireBrutMensuel: 9000),
        );
        await tester.pump();
        await tester.tap(
          find.bySemanticsIdentifier('financial_plan_setup_confirm'),
        );
        await tester.pumpAndSettle();

        expect(
          (
            plans.setPlanCalls,
            plans.hasPlan,
            find
                .bySemanticsIdentifier('financial_plan_setup_confirmation')
                .evaluate()
                .length,
            find
                .bySemanticsIdentifier('financial_plan_setup_draft_changed')
                .evaluate()
                .length,
          ),
          equals((0, false, 0, 1)),
          reason: 'A confirmation must never publish a calculation built from '
              'a superseded ledger snapshot.',
        );
      },
    );

    testWidgets(
      'setup confirmation formats amount and date from the active locale',
      (tester) async {
        final ledger = _loadedLedger();
        final plans = FinancialPlanProvider()..attachProfileProvider(ledger);
        addTearDown(ledger.dispose);
        addTearDown(plans.dispose);

        await tester.pumpWidget(
          _toolHarness(
            ledger: ledger,
            plans: plans,
            input: const {'goal': 'Build an emergency reserve'},
            locale: const Locale('en'),
          ),
        );
        await _pumpAsync(tester);
        await tester.tap(
          find.bySemanticsIdentifier('financial_plan_setup_category_general'),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.bySemanticsIdentifier('financial_plan_setup_amount'),
          '24,000',
        );
        await tester.enterText(
          find.bySemanticsIdentifier('financial_plan_setup_target_date'),
          '2028-07-16',
        );
        await tester.tap(
          find.bySemanticsIdentifier('financial_plan_setup_review'),
        );
        await tester.pumpAndSettle();

        expect(
          (
            _renderedTextCount(tester, 'CHF 24,000'),
            _renderedTextCount(tester, '7/16/2028'),
            _renderedTextCount(tester, '16.07.2028'),
          ),
          equals((1, 1, 0)),
          reason: 'The confirmation must follow the active locale; fr_CH is '
              'not a formatting authority for English users.',
        );
      },
    );

    testWidgets(
      'retirement confirmation exposes consumed assumptions before persistence and requires the under-63 fund rule',
      (tester) async {
        final ledger = _ownedRetirementLedger();
        final plans = _CountingFinancialPlanProvider()
          ..attachProfileProvider(ledger);
        final now = DateTime.now();
        final targetDate = DateTime(now.year + 22, 1, 2);
        addTearDown(ledger.dispose);
        addTearDown(plans.dispose);

        await tester.pumpWidget(
          _toolHarness(
            ledger: ledger,
            plans: plans,
            input: const {'goal': 'Préparer ma retraite'},
          ),
        );
        await _pumpAsync(tester);
        await _reachRetirementConfirmation(tester, targetDate: targetDate);

        expect(
          (
            plans.setPlanCalls,
            plans.hasPlan,
            _renderedTextCount(tester, 'Capital LPP utilisé : 150 000 CHF'),
            _renderedTextCount(
              tester,
              'Rendement annuel du scénario : 2,0 %',
            ),
            _renderedTextCount(tester, 'Scénario bas : 1,0 %'),
            _renderedTextCount(tester, 'Scénario haut : 3,0 %'),
            _renderedTextCount(
              tester,
              'Épargne mensuelle complémentaire : rendement supposé 0 %',
            ),
            _renderedTextCount(
              tester,
              'Salaire de base : salaire brut mensuel confirmé × 12 = 96 000 CHF/an',
            ),
            _renderedTextCount(
              tester,
              'Bonifications selon le barème légal LPP par âge',
            ),
            _renderedTextCount(
              tester,
              'Salaire assuré déclaré par la caisse',
            ),
            _renderedTextCount(
              tester,
              'Taux de bonification déclaré par la caisse',
            ),
            _renderedTextCount(tester, 'Source des faits LPP : certificat'),
            _renderedTextCount(tester, 'Confiance des données :'),
            _renderedTextCount(
              tester,
              'Nominal. AVS, 3a et impôts exclus.',
            ),
            find
                .bySemanticsIdentifier(
                  'financial_plan_setup_early_retirement_rule',
                )
                .evaluate()
                .length,
          ),
          equals((0, false, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1)),
          reason: 'The exact calculator draft and its Swiss scope must be '
              'visible before the provider persistence boundary.',
        );

        await tester.tap(
          find.bySemanticsIdentifier(
            'financial_plan_setup_early_retirement_rule',
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.bySemanticsIdentifier('financial_plan_setup_confirm'),
        );
        await _pumpAsync(tester);
        expect((plans.setPlanCalls, plans.hasPlan), equals((1, true)));
      },
    );

    testWidgets(
      'retirement after 65 requires explicit continued gainful activity',
      (tester) async {
        final ledger = _ownedRetirementLedger();
        final plans = _CountingFinancialPlanProvider()
          ..attachProfileProvider(ledger);
        final now = DateTime.now();
        final targetDate = DateTime(now.year + 27, 1, 2);
        addTearDown(ledger.dispose);
        addTearDown(plans.dispose);

        await tester.pumpWidget(
          _toolHarness(
            ledger: ledger,
            plans: plans,
            input: const {'goal': 'Préparer ma retraite'},
          ),
        );
        await _pumpAsync(tester);
        await _reachRetirementConfirmation(tester, targetDate: targetDate);

        expect(
          find.bySemanticsIdentifier(
            'financial_plan_setup_post65_gainful_activity',
          ),
          findsOneWidget,
        );
        expect(plans.setPlanCalls, 0);
      },
    );

    testWidgets(
      'the LLM goal hint is PII-scrubbed bounded and editable before persistence',
      (tester) async {
        final ledger = _loadedLedger();
        final plans = _CountingFinancialPlanProvider()
          ..attachProfileProvider(ledger);
        addTearDown(ledger.dispose);
        addTearDown(plans.dispose);

        await tester.pumpWidget(
          _toolHarness(
            ledger: ledger,
            plans: plans,
            input: {
              'goal':
                  'Écrire à julien@example.com ${List.filled(180, 'x').join()}',
            },
          ),
        );
        await _pumpAsync(tester);

        final goalField = find.bySemanticsIdentifier(
          'financial_plan_setup_goal',
        );
        final controller = tester
            .widget<TextField>(
              find.descendant(of: goalField, matching: find.byType(TextField)),
            )
            .controller!;
        expect(controller.text, isNot(contains('julien@example.com')));
        expect(controller.text.length, lessThanOrEqualTo(100));

        await tester.enterText(goalField, 'Ma réserve choisie');
        await tester.tap(
          find.bySemanticsIdentifier('financial_plan_setup_category_general'),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.bySemanticsIdentifier('financial_plan_setup_amount'),
          '24000',
        );
        final future = DateTime.now().add(const Duration(days: 730));
        await tester.enterText(
          find.bySemanticsIdentifier('financial_plan_setup_target_date'),
          DateFormat('yyyy-MM-dd').format(future),
        );
        await tester.tap(
          find.bySemanticsIdentifier('financial_plan_setup_review'),
        );
        await _pumpAsync(tester);
        await tester.tap(
          find.bySemanticsIdentifier('financial_plan_setup_confirm'),
        );
        await _pumpAsync(tester);

        expect(plans.currentPlan?.goalDescription, 'Ma réserve choisie');
      },
    );

    testWidgets(
      'Coach does not invent a CHF plan without user-owned amount and date',
      (tester) async {
        final ledger = _loadedLedger();
        final plans = FinancialPlanProvider()..attachProfileProvider(ledger);
        addTearDown(ledger.dispose);
        addTearDown(plans.dispose);

        await tester.pumpWidget(
          _toolHarness(
            ledger: ledger,
            plans: plans,
            input: const {'goal': 'Objectif conversationnel sans paramètres'},
          ),
        );
        await _pumpAsync(tester);

        expect(
          plans.hasPlan,
          isFalse,
          reason:
              'The LLM goal label does not own a CHF amount or target date.',
        );
      },
    );

    testWidgets('a fresh plan keeps calculator narrative over LLM narrative',
        (tester) async {
      final ledger = _loadedLedger();
      final plans = FinancialPlanProvider()
        ..setPlanDirect(_planFor(ledger))
        ..attachProfileProvider(ledger);
      addTearDown(ledger.dispose);
      addTearDown(plans.dispose);

      await tester.pumpWidget(
        _toolHarness(
          ledger: ledger,
          plans: plans,
          input: const {
            'goal': 'Objectif synthétique explicite',
            'narrative': _llmNarrative,
          },
        ),
      );
      await tester.pump();

      final card = tester.widget<PlanPreviewCard>(find.byType(PlanPreviewCard));
      expect(card.coachNarrative, _calculatorNarrative);
      expect(find.text(_llmNarrative), findsNothing);
    });

    testWidgets('Coach renders the sources carried by the specific plan',
        (tester) async {
      final ledger = _loadedLedger();
      final plan = _planFor(ledger);
      addTearDown(ledger.dispose);

      await tester.pumpWidget(_localized(PlanPreviewCard.fromPlan(plan)));
      await tester.pump();

      expect(find.text(_specificSource), findsOneWidget);
    });

    testWidgets(
      'Aujourd’hui renders plan sources and not hardcoded ARB citations',
      (tester) async {
        final ledger = _loadedLedger();
        final plan = _planFor(ledger);
        addTearDown(ledger.dispose);

        await tester.pumpWidget(
          _localized(
            FinancialPlanCard(
              plan: plan,
              isStale: false,
              onRecalculate: (_) {},
            ),
          ),
        );
        await tester.tap(
          find.bySemanticsIdentifier('financial_plan_home_details'),
        );
        await tester.pumpAndSettle();

        expect(
          (
            _renderedTextCount(tester, _specificSource),
            _renderedTextCount(tester, _mandatoryMintDisclaimer),
            _renderedTextCount(tester, 'LIFD art. 38'),
            _renderedTextCount(tester, 'LPP art. 14'),
          ),
          (1, 1, 0, 0),
          reason: 'The card must render plan.sources and plan.disclaimer, not '
              'generic citations embedded in translations.',
        );
      },
    );

    testWidgets(
      'Coach keeps economic bands and explicit assumptions at high data confidence',
      (tester) async {
        await tester.pumpWidget(
          _localized(PlanPreviewCard.fromPlan(_retirementPlan())),
        );
        await tester.pump();

        expect(
          (
            _renderedTextCount(tester, 'Bas : 250 000 CHF'),
            _renderedTextCount(tester, 'Rendement annuel du scénario : 2,0 %'),
            _renderedTextCount(tester, 'Scénario bas : 1,0 %'),
            _renderedTextCount(tester, 'Scénario haut : 3,0 %'),
            _renderedTextCount(
              tester,
              'Épargne mensuelle complémentaire : rendement supposé 0 %',
            ),
          ),
          equals((1, 1, 1, 1, 1)),
          reason: 'Data confidence and ±1-point economic sensitivity are '
              'different dimensions; neither hides the declared assumptions.',
        );
      },
    );

    testWidgets(
      'Aujourd’hui keeps economic bands and explicit assumptions at high data confidence',
      (tester) async {
        await tester.pumpWidget(
          _localized(
            FinancialPlanCard(
              plan: _retirementPlan(),
              isStale: false,
              onRecalculate: (_) {},
            ),
          ),
        );
        await tester.tap(
          find.bySemanticsIdentifier('financial_plan_home_details'),
        );
        await tester.pumpAndSettle();

        expect(
          (
            _renderedTextCount(tester, 'Bas : 250 000 CHF'),
            _renderedTextCount(tester, 'Rendement annuel du scénario : 2,0 %'),
            _renderedTextCount(tester, 'Scénario bas : 1,0 %'),
            _renderedTextCount(tester, 'Scénario haut : 3,0 %'),
            _renderedTextCount(
              tester,
              'Épargne mensuelle complémentaire : rendement supposé 0 %',
            ),
          ),
          equals((1, 1, 1, 1, 1)),
        );
      },
    );

    testWidgets('Coach always renders the canonical data confidence score',
        (tester) async {
      await tester.pumpWidget(
        _localized(PlanPreviewCard.fromPlan(_retirementPlan())),
      );
      await tester.pump();

      expect(
        _renderedTextCount(tester, 'Confiance des données : 85 %'),
        1,
      );
    });

    testWidgets(
        'Aujourd’hui always renders the canonical data confidence score',
        (tester) async {
      await tester.pumpWidget(
        _localized(
          FinancialPlanCard(
            plan: _retirementPlan(),
            isStale: false,
            onRecalculate: (_) {},
          ),
        ),
      );
      await tester.tap(
        find.bySemanticsIdentifier('financial_plan_home_details'),
      );
      await tester.pumpAndSettle();

      expect(
        _renderedTextCount(tester, 'Confiance des données : 85 %'),
        1,
      );
    });

    testWidgets('Coach low confidence adds a localized enrichment action',
        (tester) async {
      await tester.pumpWidget(
        _localizedWithEnrichmentRoute(
          PlanPreviewCard.fromPlan(_retirementPlan(confidence: 55)),
        ),
      );
      await tester.pump();

      expect(
        (
          _renderedTextCount(tester, 'Confiance des données : 55 %'),
          _renderedTextCount(tester, 'Améliorer la précision'),
        ),
        equals((1, 1)),
      );

      await tester.tap(
        find.bySemanticsIdentifier('financial_plan_coach_improve_precision'),
      );
      await tester.pumpAndSettle();
      expect(find.text('data-block:lpp'), findsOneWidget);
    });

    testWidgets(
      'Aujourd’hui low confidence adds a localized enrichment action',
      (tester) async {
        await tester.pumpWidget(
          _localizedWithEnrichmentRoute(
            FinancialPlanCard(
              plan: _retirementPlan(confidence: 55),
              isStale: false,
              onRecalculate: (_) {},
            ),
          ),
        );

        expect(
          (
            _renderedTextCount(tester, 'Confiance des données : 55 %'),
            _renderedTextCount(tester, 'Améliorer la précision'),
          ),
          equals((1, 1)),
        );

        await tester.tap(
          find.bySemanticsIdentifier('financial_plan_home_improve_precision'),
        );
        await tester.pumpAndSettle();
        expect(find.text('data-block:lpp'), findsOneWidget);
      },
    );

    testWidgets(
      'no-LPP retirement copy never claims a combined pension capital',
      (tester) async {
        await tester.pumpWidget(
          _localized(PlanPreviewCard.fromPlan(_retirementPlan(hasLpp: false))),
        );
        await tester.pump();

        expect(
          (
            _renderedTextCount(
              tester,
              'Ce scénario repose uniquement sur l’épargne mensuelle confirmée',
            ),
            _renderedTextCount(tester, 'combine ton capital LPP'),
            _renderedTextCount(
              tester,
              'AVS, LPP, 3a et impôts exclus',
            ),
          ),
          equals((1, 0, 1)),
        );
      },
    );

    testWidgets(
      'Aujourd’hui shows bands confidence assumptions and scope without fake progress or expansion',
      (tester) async {
        await tester.pumpWidget(
          _localized(
            FinancialPlanCard(
              plan: _retirementPlan(),
              isStale: false,
              onRecalculate: (_) {},
            ),
          ),
        );
        await tester.pump();

        expect(
          (
            _renderedTextCount(tester, 'Bas : 250 000 CHF'),
            _renderedTextCount(tester, 'Confiance des données : 85 %'),
            _renderedTextCount(
              tester,
              'Épargne mensuelle complémentaire : rendement supposé 0 %',
            ),
            _renderedTextCount(
              tester,
              'AVS, 3a et impôts exclus',
            ),
            _renderedTextCount(tester, '0 % atteint'),
          ),
          equals((1, 1, 1, 1, 0)),
        );
      },
    );

    testWidgets(
      'Coach localizes the mandatory disclaimer instead of replaying persisted French',
      (tester) async {
        await tester.pumpWidget(
          _localized(
            PlanPreviewCard.fromPlan(_retirementPlan()),
            locale: const Locale('en'),
          ),
        );
        await tester.pump();

        expect(
          (
            _renderedTextCount(
              tester,
              'The results shown are indicative estimates based on the data provided and current legislation.',
            ),
            _renderedTextCount(tester, _mandatoryMintDisclaimer),
            _renderedTextCount(tester, 'CHF 500 / month'),
            _renderedTextCount(tester, '100% of target'),
            _renderedTextCount(tester, _calculatorNarrative),
          ),
          equals((1, 0, 1, 1, 0)),
          reason: 'Persisted French disclaimer, milestone and calculator '
              'narrative are not localization authority.',
        );
      },
    );

    testWidgets(
      'Aujourd’hui localizes the mandatory disclaimer instead of replaying persisted French',
      (tester) async {
        await tester.pumpWidget(
          _localized(
            FinancialPlanCard(
              plan: _retirementPlan(),
              isStale: false,
              onRecalculate: (_) {},
            ),
            locale: const Locale('en'),
          ),
        );
        await tester.tap(
          find.bySemanticsIdentifier('financial_plan_home_details'),
        );
        await tester.pumpAndSettle();

        expect(
          (
            _renderedTextCount(
              tester,
              'The results shown are indicative estimates based on the data provided and current legislation.',
            ),
            _renderedTextCount(tester, _mandatoryMintDisclaimer),
            _renderedTextCount(tester, 'CHF 500 / month'),
            _renderedTextCount(tester, '100% of target'),
            _renderedTextCount(tester, '100% atteint'),
          ),
          equals((1, 0, 1, 1, 0)),
        );
      },
    );

    testWidgets(
      'stale regeneration uses explicit goalAmount and never the last milestone',
      (tester) async {
        final ledger = _loadedLedger();
        final targetDate = DateTime.now().add(const Duration(days: 730));
        final plan = _generalScenarioPlan(
          goalAmount: 24000,
          milestones: [
            {
              'targetDate': targetDate.toIso8601String(),
              'targetAmount': 1.0,
              'description': '100% atteint — valeur sentinelle invalide',
            },
          ],
        );
        final plans = _CountingFinancialPlanProvider()
          ..setPlanDirect(plan)
          ..attachProfileProvider(ledger);
        addTearDown(ledger.dispose);
        addTearDown(plans.dispose);

        await tester.pumpWidget(
          _toolHarness(
            ledger: ledger,
            plans: plans,
            input: const {'goal': 'Réserve synthétique'},
          ),
        );
        await tester.pump();
        final recalculate = find.bySemanticsIdentifier(
          'financial_plan_stale_recalculate',
        );
        expect(recalculate, findsOneWidget);

        await tester.tap(recalculate);
        await _pumpAsync(tester);

        final regenerated = plans.currentPlan!;
        expect(
          (
            plans.setPlanCalls,
            regenerated.toJson()['goalAmount'],
            regenerated.milestones.last.targetAmount,
          ),
          equals((1, 24000.0, 24000.0)),
          reason: 'Milestones are outputs. Only the confirmed scenario amount '
              'may feed regeneration.',
        );
      },
    );

    testWidgets(
      'ambiguous legacy 100% milestones stay stale and unregeneratable',
      (tester) async {
        final ledger = _loadedLedger();
        final targetDate = DateTime.now().add(const Duration(days: 730));
        final plan = _generalScenarioPlan(
          milestones: [
            {
              'targetDate': targetDate.toIso8601String(),
              'targetAmount': 24000.0,
              'description': '100% atteint — 24000 CHF',
            },
            {
              'targetDate': targetDate.toIso8601String(),
              'targetAmount': 25000.0,
              'description': '100% atteint — 25000 CHF',
            },
          ],
        );
        final plans = _CountingFinancialPlanProvider()
          ..setPlanDirect(plan)
          ..attachProfileProvider(ledger);
        addTearDown(ledger.dispose);
        addTearDown(plans.dispose);

        await tester.pumpWidget(
          _toolHarness(
            ledger: ledger,
            plans: plans,
            input: const {'goal': 'Réserve synthétique'},
          ),
        );
        await tester.pump();
        final recalculate = find.bySemanticsIdentifier(
          'financial_plan_stale_recalculate',
        );
        expect(recalculate, findsOneWidget);

        await tester.tap(recalculate);
        await _pumpAsync(tester);

        expect(
          (plans.setPlanCalls, plans.isPlanStale),
          equals((0, true)),
          reason: 'Multiple candidate 100% outputs are not a recoverable '
              'user-owned scenario amount.',
        );
      },
    );
  });
}
