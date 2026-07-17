import 'dart:async';
import 'dart:convert';
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/financial_plan_ledger_inputs.dart';
import 'package:mint_mobile/services/plan_generation_service.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/services/session_epoch.dart';
import 'package:mint_mobile/services/session_termination_coordinator.dart';
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
const _profileOwnerId = '11111111-1111-4111-8111-111111111111';

Future<CoachProfileProvider> _loadedLedger() async {
  final sessionEpoch = SessionEpoch();
  final ledger = CoachProfileProvider(sessionEpoch: sessionEpoch);
  final sessionGuard = sessionEpoch.capture();
  await ledger.mergeBackendUnknownProfile({
    'birthYear': 1986,
    'canton': 'VD',
    'incomeGrossYearly': 96000.0,
  }, sessionGuard: sessionGuard);
  return ledger;
}

FinancialPlan _planFor(CoachProfileProvider ledger) {
  final targetDate = DateTime.now().add(const Duration(days: 730));
  final ownerId = ledger.canonicalProfileOwnerId;
  final inputAsOf = DateTime.now().toUtc();
  final dependency = ownerId == null
      ? null
      : FinancialPlanDependencySnapshot.fromProfile(
          ledger.profile!,
          profileOwnerId: ownerId,
          goalCategory: 'goal_general',
          goalAmount: 24000,
          targetDate: targetDate,
          prospectiveLppReturn: null,
          selfLppSnapshot: null,
          now: inputAsOf,
        );
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
    generatedAt: dependency?.inputAsOf ?? DateTime(2026, 7, 16),
    profileHashAtGeneration: dependency?.fingerprint ??
        'mint-plan-dependency:v3:sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    coachNarrative: _calculatorNarrative,
    confidenceLevel: dependency?.confidenceLevel ?? 50,
    sources: const [_specificSource],
    disclaimer: _mandatoryMintDisclaimer,
    goalAmount: dependency == null ? null : 24000,
    scenarioId:
        dependency == null ? null : '77777777-7777-4777-8777-777777777777',
    confirmedAt: dependency?.inputAsOf,
    inputAsOf: dependency?.inputAsOf,
    profileOwnerId: dependency?.profileOwnerId,
    dependencySchemaVersion: dependency?.schemaVersion,
    dependencyBranch: dependency?.branch.wireName,
    dependencyBasis: dependency?.basis.wireName,
    dependencyHash: dependency?.fingerprint,
    validUntil: dependency?.validUntil,
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
    'profileHashAtGeneration': 'legacy-retirement-record',
    'coachNarrative': _calculatorNarrative,
    'confidenceLevel': confidence,
    'sources': ['LPP art. 8', 'LPP art. 15–16'],
    'disclaimer': _mandatoryMintDisclaimer,
    'dependencyBranch': hasLpp ? 'retirementLpp' : 'retirementNoLpp',
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
      'annualProjectionUsesWholeYears': hasLpp,
      'requiresFundAuthorizationBefore63': hasLpp,
      'assumesPostReferenceGainfulActivity': hasLpp,
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
    'profileHashAtGeneration': 'legacy-general-record',
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
  _CountingFinancialPlanProvider({SessionEpoch? epoch})
      : super(
          timerFactory: (_, __) => _DormantTimer(),
          sessionEpoch: epoch,
        );

  int setPlanCalls = 0;

  @override
  Future<void> setPlan(FinancialPlan plan) {
    setPlanCalls++;
    return super.setPlan(plan);
  }
}

class _DormantTimer implements Timer {
  var _active = true;

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
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
  _TestLedger(
    this._profile, {
    LppEvidenceSnapshot? selfLppSnapshot,
    this.previewError,
  }) : _selfLppSnapshot = selfLppSnapshot;

  CoachProfile _profile;
  final LppEvidenceSnapshot? _selfLppSnapshot;
  final Object? previewError;
  String _owner = _profileOwnerId;
  Completer<void>? _deferredPreview;
  int previewOwnerCalls = 0;
  int commitOwnerCalls = 0;

  @override
  CoachProfile get profile => _profile;

  @override
  bool get isLoaded => true;

  @override
  String get canonicalProfileOwnerId => _owner;

  @override
  Future<String> ensureCanonicalProfileOwner() async => _owner;

  @override
  Future<String> previewCanonicalProfileOwner() async {
    previewOwnerCalls++;
    final error = previewError;
    if (error != null) throw error;
    final deferred = _deferredPreview;
    if (deferred != null) await deferred.future;
    return _owner;
  }

  @override
  Future<String> commitStagedCanonicalProfileOwner(String ownerId) async {
    commitOwnerCalls++;
    if (ownerId != _owner) throw StateError('synthetic owner drift');
    return _owner;
  }

  @override
  LppEvidenceSnapshot? currentLppSnapshot(LppEvidenceOwnerKind ownerKind) =>
      ownerKind == LppEvidenceOwnerKind.self ? _selfLppSnapshot : null;

  void replaceProfile(CoachProfile profile) {
    _profile = profile;
    notifyListeners();
  }

  void replaceOwner(String owner) {
    _owner = owner;
    notifyListeners();
  }

  void deferOwnerPreview() {
    _deferredPreview = Completer<void>();
  }

  void completeOwnerPreview() {
    final deferred = _deferredPreview;
    _deferredPreview = null;
    if (deferred != null && !deferred.isCompleted) deferred.complete();
  }
}

_TestLedger _ownedRetirementLedger({
  bool withLppSnapshot = true,
  bool withExactDateOfBirth = true,
  double grossMonthlySalary = 8000,
  Object? previewError,
  String? gender = 'M',
  ProfileDataSource genderSource = ProfileDataSource.userInput,
  ProfileDataSource lppCapitalSource = ProfileDataSource.certificate,
  bool withLppCapitalSourceDate = true,
  DateTime? dateOfBirth,
}) {
  final now = DateTime.now();
  final sourceDate = DateTime(now.year, now.month, 1);
  const factPaths = [
    'salaireBrutMensuel',
    'dateOfBirth',
    'gender',
    'prevoyance.hasPensionFund',
    'prevoyance.avoirLppTotal',
    'prevoyance.avoirLppObligatoire',
    'prevoyance.avoirLppSurobligatoire',
    'prevoyance.rendementCaisse',
    'prevoyance.rendementCaisseConnu',
    'prevoyance.salaireAssure',
    'prevoyance.bonificationRate',
  ];
  final effectiveDateOfBirth = dateOfBirth ?? DateTime(now.year - 40, 1, 1);
  final profile = CoachProfile(
    birthYear: effectiveDateOfBirth.year,
    dateOfBirth: withExactDateOfBirth ? effectiveDateOfBirth : null,
    gender: gender,
    canton: 'VD',
    salaireBrutMensuel: grossMonthlySalary,
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
      for (final path in factPaths)
        if ((path != 'dateOfBirth' || withExactDateOfBirth) &&
            (path != 'gender' || gender != null) &&
            (path != 'salaireBrutMensuel' || grossMonthlySalary > 0))
          path: switch (path) {
            'gender' => genderSource,
            'prevoyance.hasPensionFund' => ProfileDataSource.userInput,
            'prevoyance.avoirLppTotal' ||
            'prevoyance.avoirLppObligatoire' ||
            'prevoyance.avoirLppSurobligatoire' =>
              lppCapitalSource,
            _ => ProfileDataSource.certificate,
          },
    },
    dataTimestamps: {
      for (final path in factPaths)
        if ((path != 'dateOfBirth' || withExactDateOfBirth) &&
            (path != 'gender' || gender != null) &&
            (path != 'salaireBrutMensuel' || grossMonthlySalary > 0))
          path: now,
    },
    dataSourceDates: {
      for (final path in factPaths)
        if ((path != 'dateOfBirth' || withExactDateOfBirth) &&
            (path != 'gender' || gender != null) &&
            (path != 'salaireBrutMensuel' || grossMonthlySalary > 0))
          path: switch (path) {
            'prevoyance.avoirLppTotal' ||
            'prevoyance.avoirLppObligatoire' ||
            'prevoyance.avoirLppSurobligatoire' =>
              withLppCapitalSourceDate ? sourceDate : null,
            _ => sourceDate,
          },
    },
    inferDataSources: false,
  );
  LppEvidenceFact capitalFact(double value) => LppEvidenceFact(
        value: value,
        unit: LppEvidenceUnit.chf,
        profileOwnerId: _profileOwnerId,
        actorProfileOwnerId: _profileOwnerId,
        source: lppCapitalSource.name,
        sourceDate: withLppCapitalSourceDate ? sourceDate : null,
        updatedAt: now,
      );
  return _TestLedger(
    profile,
    previewError: previewError,
    selfLppSnapshot: withLppSnapshot
        ? LppEvidenceSnapshot(
            snapshotId: '22222222-2222-4222-8222-222222222222',
            facts: {
              LppEvidenceFactKey.vestedBenefitsCapitalChf: capitalFact(150000),
              LppEvidenceFactKey.mandatoryVestedBenefitsCapitalChf:
                  capitalFact(100000),
              LppEvidenceFactKey.extraMandatoryVestedBenefitsCapitalChf:
                  capitalFact(50000),
            },
          )
        : null,
  );
}

_TestLedger _ownedNoLppLedger({required int birthYear}) {
  final now = DateTime.now();
  final dateOfBirth = DateTime(birthYear, 1, 1);
  return _TestLedger(
    CoachProfile(
      birthYear: birthYear,
      dateOfBirth: dateOfBirth,
      canton: 'VD',
      salaireBrutMensuel: 8000,
      prevoyance: const PrevoyanceProfile(hasPensionFund: false),
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(birthYear + 65, 7, 1),
        label: 'Retraite sans LPP',
      ),
      inferDataSources: false,
      dataSources: const {
        'prevoyance.hasPensionFund': ProfileDataSource.userInput,
        'dateOfBirth': ProfileDataSource.userInput,
      },
      dataTimestamps: {
        'prevoyance.hasPensionFund': now,
        'dateOfBirth': now,
      },
      dataSourceDates: const {
        'prevoyance.hasPensionFund': null,
        'dateOfBirth': null,
      },
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
            state.uri.toString(),
            key: const Key('financial_plan_enrichment_destination'),
          ),
        ),
      ),
      GoRoute(
        path: '/scan',
        builder: (_, state) => Scaffold(
          body: Text(
            state.uri.toString(),
            key: const Key('financial_plan_scan_destination'),
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

Widget _directSetupWithEnrichmentHarness({
  required CoachProfileProvider ledger,
  required FinancialPlanProvider plans,
  required DateTime Function() clock,
}) {
  return _localizedWithEnrichmentRoute(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachProfileProvider>.value(value: ledger),
        ChangeNotifierProvider<FinancialPlanProvider>.value(value: plans),
      ],
      child: FinancialPlanSetupCard(
        goalHint: 'Constituer une réserve',
        planProvider: plans,
        clock: clock,
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

Future<void> _reachNoLppRetirementConfirmation(
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
  final legacyScope = find.bySemanticsIdentifier(
    'financial_plan_setup_retirement_scope',
  );
  if (legacyScope.evaluate().isNotEmpty) {
    await tester.tap(legacyScope);
  }
  await tester.pumpAndSettle();
  await tester.tap(
    find.bySemanticsIdentifier('financial_plan_setup_retirement_continue'),
  );
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

Future<void> _reachGeneralConfirmation(
  WidgetTester tester, {
  required DateTime targetDate,
  String amount = '24000',
}) async {
  await tester.tap(
    find.bySemanticsIdentifier('financial_plan_setup_category_general'),
  );
  await tester.pumpAndSettle();
  await tester.enterText(
    find.bySemanticsIdentifier('financial_plan_setup_amount'),
    amount,
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

void _expectLocalizedDisclaimerBeforeConfirm(WidgetTester tester) {
  final disclaimer = find.text(_mandatoryMintDisclaimer);
  final confirm = find.bySemanticsIdentifier('financial_plan_setup_confirm');
  expect(disclaimer, findsOneWidget);
  expect(confirm, findsOneWidget);
  expect(
    tester.getTopLeft(disclaimer).dy,
    lessThan(tester.getTopLeft(confirm).dy),
    reason: 'No-advice copy must be visible before final consent.',
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    FeatureFlags.financialPlanSetupEnabled = true;
    FeatureFlags.typedLppEvidence = false;
    FeatureFlags.documentLppEvidenceEnabled = false;
  });

  tearDown(() {
    FeatureFlags.financialPlanSetupEnabled = false;
    FeatureFlags.typedLppEvidence = false;
    FeatureFlags.documentLppEvidenceEnabled = false;
  });

  group('G1-BND-06 domain RED — Coach and Aujourd’hui surfaces', () {
    testWidgets(
      'intent-only plan tool opens setup and ignores every legacy value',
      (tester) async {
        final ledger = await _loadedLedger();
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
        final ledger = _ownedRetirementLedger();
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
                .bySemanticsIdentifier(
                  'financial_plan_setup_retirement_continue',
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
          equals((1, 1, 1, 1, 0, 0, false)),
          reason: 'Retirement needs an explicit capital/horizon scope before '
              'collecting the owned CHF amount and date, and a future return '
              'must be chosen rather than inherited from the certificate.',
        );
      },
    );

    testWidgets(
      'LPP recovery CTA exists only for real typed ingestion and keeps its exact route',
      (tester) async {
        final unavailableLedger =
            _ownedRetirementLedger(withLppSnapshot: false);
        final unavailablePlans = FinancialPlanProvider()
          ..attachProfileProvider(unavailableLedger);
        addTearDown(unavailableLedger.dispose);
        addTearDown(unavailablePlans.dispose);

        await tester.pumpWidget(
          _toolHarness(
            ledger: unavailableLedger,
            plans: unavailablePlans,
            input: const {'goal': 'Préparer ma retraite'},
          ),
        );
        await _pumpAsync(tester);
        await _reachRetirementConfirmation(
          tester,
          targetDate: DateTime.now().add(const Duration(days: 9000)),
        );
        expect(
          find.bySemanticsIdentifier('financial_plan_setup_missing_data'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('financial_plan_setup_enrich_lpp'),
          findsNothing,
        );

        FeatureFlags.typedLppEvidence = true;
        FeatureFlags.documentLppEvidenceEnabled = true;
        addTearDown(() {
          FeatureFlags.typedLppEvidence = false;
          FeatureFlags.documentLppEvidenceEnabled = false;
        });
        final ledger = _ownedRetirementLedger(withLppSnapshot: false);
        final plans = FinancialPlanProvider()..attachProfileProvider(ledger);
        addTearDown(ledger.dispose);
        addTearDown(plans.dispose);
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: FinancialPlanSetupCard(
                  goalHint: 'Préparer ma retraite',
                  planProvider: plans,
                ),
              ),
            ),
            GoRoute(
              path: '/scan',
              builder: (context, state) => Scaffold(
                body: Text(state.uri.toString()),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<CoachProfileProvider>.value(
                value: ledger,
              ),
              ChangeNotifierProvider<FinancialPlanProvider>.value(
                value: plans,
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: const [
                S.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: S.supportedLocales,
              locale: const Locale('fr'),
            ),
          ),
        );
        await _reachRetirementConfirmation(
          tester,
          targetDate: DateTime.now().add(const Duration(days: 9000)),
        );
        final cta =
            find.bySemanticsIdentifier('financial_plan_setup_enrich_lpp');
        expect(cta, findsOneWidget);
        await tester.tap(cta);
        await tester.pumpAndSettle();
        expect(find.text('/scan?type=lppCertificate'), findsOneWidget);
      },
    );

    testWidgets(
      'setup persists exactly one plan only after final confirmation',
      (tester) async {
        final ledger = await _loadedLedger();
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
        _expectLocalizedDisclaimerBeforeConfirm(tester);
        final wizardBytesAfterReview = await _persistedWizardBytes();
        expect(
          wizardBytesAfterReview,
          wizardBytesBefore,
          reason: 'Review may stage an owner in memory but must not mutate '
              'wizard or secure persistence before final consent.',
        );

        final confirm =
            find.bySemanticsIdentifier('financial_plan_setup_confirm');
        await tester.tap(confirm);
        await tester.tap(confirm);
        await _pumpAsync(tester);

        expect((plans.setPlanCalls, plans.hasPlan), equals((1, true)));
        expect(jsonEncode(ledger.profile!.toJson()), profileBytesBefore);
        expect(jsonEncode(ledger.profile!.goalA.toJson()), goalABytesBefore);
        final wizardBytesAfterConfirm = await _persistedWizardBytes();
        expect(wizardBytesAfterConfirm, contains('__secure__'));
        expect(
          wizardBytesAfterConfirm,
          isNot(wizardBytesAfterReview),
          reason: 'Final consent publishes the exact staged owner before the '
              'confirmed calculator result crosses provider.setPlan once.',
        );
      },
    );

    testWidgets(
      'provider failure leaves setup recoverable and never publishes a plan',
      (tester) async {
        final ledger = await _loadedLedger();
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
      'final consent latches before owner preview and rapid taps write once',
      (tester) async {
        final remoteLedger = await _loadedLedger();
        final ledger = _TestLedger(remoteLedger.profile!);
        final plans = _CountingFinancialPlanProvider()
          ..attachProfileProvider(ledger);
        addTearDown(remoteLedger.dispose);
        addTearDown(ledger.dispose);
        addTearDown(plans.dispose);

        await tester.pumpWidget(
          _directSetupHarness(
            ledger: ledger,
            plans: plans,
            clock: () => DateTime(2026, 7, 16, 9),
          ),
        );
        await _reachGeneralConfirmation(
          tester,
          targetDate: DateTime(2028, 7, 16),
        );
        expect(ledger.previewOwnerCalls, 1, reason: 'One draft preview.');

        ledger.deferOwnerPreview();
        final confirm =
            find.bySemanticsIdentifier('financial_plan_setup_confirm');
        await tester.tap(confirm);
        await tester.tap(confirm);
        await tester.pump();

        expect(
          ledger.previewOwnerCalls,
          2,
          reason:
              'The latch must reject the second tap before its first await.',
        );
        ledger.completeOwnerPreview();
        await _pumpAsync(tester);

        expect(
          (
            ledger.previewOwnerCalls,
            ledger.commitOwnerCalls,
            plans.setPlanCalls,
            plans.hasPlan,
          ),
          equals((2, 1, 1, true)),
        );
      },
    );

    testWidgets(
      'old final consent cannot resume after session termination completes',
      (tester) async {
        final epoch = SessionEpoch();
        var marker = false;
        final coordinator = SessionTerminationCoordinator(
          sessionEpoch: epoch,
          readTerminationPending: () async => marker,
          writeTerminationPending: () async => marker = true,
          clearTerminationPending: () async => marker = false,
          cancelNotifications: () async {},
          clearAuthTokens: () async {},
          purgeDurableSessionData: () async {},
          purgeRemainingLocalData: () async {},
          clearSessionMemory: const [],
        );
        final remoteLedger = await _loadedLedger();
        final ledger = _TestLedger(remoteLedger.profile!);
        final plans = _CountingFinancialPlanProvider(epoch: epoch)
          ..attachProfileProvider(ledger);
        addTearDown(coordinator.dispose);
        addTearDown(remoteLedger.dispose);
        addTearDown(ledger.dispose);
        addTearDown(plans.dispose);

        await tester.pumpWidget(
          _directSetupHarness(
            ledger: ledger,
            plans: plans,
            clock: () => DateTime(2026, 7, 16, 9),
          ),
        );
        await _reachGeneralConfirmation(
          tester,
          targetDate: DateTime(2028, 7, 16),
        );
        ledger.deferOwnerPreview();
        await tester.tap(
          find.bySemanticsIdentifier('financial_plan_setup_confirm'),
        );
        await tester.pump();

        await coordinator.terminate();
        ledger.completeOwnerPreview();
        await _pumpAsync(tester);

        expect(ledger.commitOwnerCalls, 0);
        expect(plans.setPlanCalls, 0);
        expect(plans.hasPlan, isFalse);
      },
    );

    testWidgets(
      'old draft review cannot publish a plan or error after termination',
      (tester) async {
        final epoch = SessionEpoch();
        final coordinator = SessionTerminationCoordinator(
          sessionEpoch: epoch,
          readTerminationPending: () async => false,
          writeTerminationPending: () async {},
          clearTerminationPending: () async {},
          cancelNotifications: () async {},
          clearAuthTokens: () async {},
          purgeDurableSessionData: () async {},
          purgeRemainingLocalData: () async {},
          clearSessionMemory: const [],
        );
        final remoteLedger = await _loadedLedger();
        final ledger = _TestLedger(remoteLedger.profile!);
        final plans = _CountingFinancialPlanProvider(epoch: epoch)
          ..attachProfileProvider(ledger);
        addTearDown(coordinator.dispose);
        addTearDown(remoteLedger.dispose);
        addTearDown(ledger.dispose);
        addTearDown(plans.dispose);

        await tester.pumpWidget(
          _directSetupHarness(
            ledger: ledger,
            plans: plans,
            clock: () => DateTime(2026, 7, 16, 9),
          ),
        );
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
        ledger.deferOwnerPreview();
        await tester.tap(
          find.bySemanticsIdentifier('financial_plan_setup_review'),
        );
        await tester.pump();
        expect(ledger.previewOwnerCalls, 1);

        await coordinator.terminate();
        ledger.completeOwnerPreview();
        await _pumpAsync(tester);

        expect(plans.setPlanCalls, 0);
        expect(plans.hasPlan, isFalse);
        expect(
          find.bySemanticsIdentifier('financial_plan_setup_error'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'editing the reviewed goal invalidates the draft with zero plan writes',
      (tester) async {
        final ledger = await _loadedLedger();
        final plans = _CountingFinancialPlanProvider()
          ..attachProfileProvider(ledger);
        addTearDown(ledger.dispose);
        addTearDown(plans.dispose);

        await tester.pumpWidget(
          _directSetupHarness(
            ledger: ledger,
            plans: plans,
            clock: () => DateTime(2026, 7, 16, 9),
          ),
        );
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
        expect(
          find.bySemanticsIdentifier('financial_plan_setup_confirmation'),
          findsOneWidget,
        );

        await tester.enterText(
          find.bySemanticsIdentifier('financial_plan_setup_goal'),
          'Objectif modifié après revue',
        );
        await tester.pumpAndSettle();

        expect(plans.setPlanCalls, 0);
        expect(plans.currentPlan, isNull);
        expect(
          find.bySemanticsIdentifier('financial_plan_setup_confirmation'),
          findsNothing,
        );
        expect(
          find.bySemanticsIdentifier('financial_plan_setup_draft_changed'),
          findsOneWidget,
        );
      },
    );

    testWidgets('target-date validation uses the injected setup clock',
        (tester) async {
      final ledger = await _loadedLedger();
      final plans = _CountingFinancialPlanProvider()
        ..attachProfileProvider(ledger);
      addTearDown(ledger.dispose);
      addTearDown(plans.dispose);

      await tester.pumpWidget(
        _directSetupHarness(
          ledger: ledger,
          plans: plans,
          clock: () => DateTime(2030, 7, 16, 9),
        ),
      );
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
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('financial_plan_setup_confirmation'),
        findsNothing,
      );
      expect(plans.setPlanCalls, 0);
    });

    testWidgets('one review owns one injected timestamp', (tester) async {
      final ledger = await _loadedLedger();
      final plans = _CountingFinancialPlanProvider()
        ..attachProfileProvider(ledger);
      var clockCalls = 0;
      final reviewTime = DateTime(2026, 7, 16, 9);
      addTearDown(ledger.dispose);
      addTearDown(plans.dispose);

      await tester.pumpWidget(
        _directSetupHarness(
          ledger: ledger,
          plans: plans,
          clock: () {
            clockCalls++;
            return reviewTime.add(Duration(seconds: clockCalls - 1));
          },
        ),
      );
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

      expect(clockCalls, 1);
      expect(
        find.bySemanticsIdentifier('financial_plan_setup_confirmation'),
        findsOneWidget,
      );
    });

    testWidgets('Continue semantics mirrors the real enabled tap contract',
        (tester) async {
      final ledger = _ownedNoLppLedger(birthYear: DateTime.now().year - 40);
      final plans = _CountingFinancialPlanProvider()
        ..attachProfileProvider(ledger);
      addTearDown(ledger.dispose);
      addTearDown(plans.dispose);

      await tester.pumpWidget(
        _toolHarness(
          ledger: ledger,
          plans: plans,
          input: const {'goal': 'Préparer ma retraite sans LPP'},
        ),
      );
      await _pumpAsync(tester);
      await tester.tap(
        find.bySemanticsIdentifier('financial_plan_setup_category_retirement'),
      );
      await tester.pumpAndSettle();

      final continueFinder = find.bySemanticsIdentifier(
        'financial_plan_setup_retirement_continue',
      );
      final disabled = tester.getSemantics(continueFinder).getSemanticsData();
      expect(disabled.flagsCollection.isEnabled, Tristate.isFalse);
      expect(disabled.hasAction(SemanticsAction.tap), isFalse);

      await tester.tap(
        find.bySemanticsIdentifier('financial_plan_setup_retirement_horizon'),
      );
      await tester.pumpAndSettle();

      final enabled = tester.getSemantics(continueFinder).getSemanticsData();
      expect(enabled.flagsCollection.isEnabled, Tristate.isTrue);
      expect(enabled.hasAction(SemanticsAction.tap), isTrue);
    });

    testWidgets(
      'final tap owns confirmedAt rather than the earlier draft review',
      (tester) async {
        final ledger = await _loadedLedger();
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

        ledger.replaceOwner('33333333-3333-4333-8333-333333333333');
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
          reason: 'A confirmation must never publish a calculation owned by '
              'a superseded ledger identity.',
        );
      },
    );

    testWidgets(
      'setup confirmation formats amount and date from the active locale',
      (tester) async {
        final ledger = await _loadedLedger();
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
        _expectLocalizedDisclaimerBeforeConfirm(tester);

        final earlyRetirementRule = find.bySemanticsIdentifier(
          'financial_plan_setup_early_retirement_rule',
        );
        await tester.ensureVisible(earlyRetirementRule);
        await tester.tap(earlyRetirementRule);
        await tester.pumpAndSettle();
        final confirm =
            find.bySemanticsIdentifier('financial_plan_setup_confirm');
        await tester.ensureVisible(confirm);
        await tester.tap(confirm);
        await _pumpAsync(tester);
        expect((plans.setPlanCalls, plans.hasPlan), equals((1, true)));
      },
    );

    testWidgets(
      'user-entered LPP without source date never invents updatedAt and salary stays traceable',
      (tester) async {
        final ledger = _ownedRetirementLedger(
          lppCapitalSource: ProfileDataSource.userInput,
          withLppCapitalSourceDate: false,
        );
        final plans = _CountingFinancialPlanProvider()
          ..attachProfileProvider(ledger);
        final now = DateTime.now();
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
        await _reachRetirementConfirmation(
          tester,
          targetDate: DateTime(now.year + 22, 1, 2),
        );

        expect(
          _renderedTextCount(
            tester,
            'Date des faits LPP : non confirmée',
          ),
          1,
        );
        expect(
          _renderedTextCount(tester, 'Source : certificat'),
          1,
          reason: 'The coherent salary basis must expose its own provenance.',
        );
        expect(
          _renderedTextCount(tester, 'Dernière mise à jour il y a 0 jours'),
          1,
          reason: 'Freshness may use updatedAt without presenting it as a '
              'document date.',
        );
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
      'canonical gender drift after review invalidates the AVS21 consent envelope',
      (tester) async {
        final reviewTime = DateTime.now().add(const Duration(seconds: 1));
        final ledger = _ownedRetirementLedger(
          gender: 'M',
          dateOfBirth: DateTime(1963, 12, 31),
        );
        final plans = _CountingFinancialPlanProvider()
          ..attachProfileProvider(ledger);
        addTearDown(ledger.dispose);
        addTearDown(plans.dispose);

        await tester.pumpWidget(
          _directSetupHarness(
            ledger: ledger,
            plans: plans,
            clock: () => reviewTime,
          ),
        );
        await _reachRetirementConfirmation(
          tester,
          targetDate: DateTime(2028, 10, 1),
        );
        expect(
          find.bySemanticsIdentifier(
            'financial_plan_setup_post65_gainful_activity',
          ),
          findsNothing,
          reason: 'A man born in 1963 reaches reference age at 65.',
        );

        ledger.replaceProfile(ledger.profile.copyWith(gender: 'F'));
        await tester.pump();
        final confirm =
            find.bySemanticsIdentifier('financial_plan_setup_confirm');
        await tester.ensureVisible(confirm);
        await tester.tap(confirm);
        await _pumpAsync(tester);

        expect((plans.setPlanCalls, plans.hasPlan), equals((0, false)));
        expect(
          find.bySemanticsIdentifier('financial_plan_setup_draft_changed'),
          findsOneWidget,
        );

        await tester.tap(
          find.bySemanticsIdentifier('financial_plan_setup_review'),
        );
        await _pumpAsync(tester);
        expect(
          find.bySemanticsIdentifier(
            'financial_plan_setup_post65_gainful_activity',
          ),
          findsOneWidget,
          reason: '1 October 2028 is after the female 1963 AVS21 reference '
              'date (30 September) but before the male date (31 December).',
        );
      },
    );

    testWidgets(
      'typed gender blocker survives final confirmation with its exact collector',
      (tester) async {
        final reviewTime = DateTime.now().add(const Duration(seconds: 1));
        final ledger = _ownedRetirementLedger(gender: 'M');
        final plans = _CountingFinancialPlanProvider()
          ..attachProfileProvider(ledger);
        addTearDown(ledger.dispose);
        addTearDown(plans.dispose);

        await tester.pumpWidget(
          _directSetupWithEnrichmentHarness(
            ledger: ledger,
            plans: plans,
            clock: () => reviewTime,
          ),
        );
        await _reachRetirementConfirmation(
          tester,
          targetDate: DateTime(reviewTime.year + 24, 1, 1),
        );
        ledger.replaceProfile(ledger.profile.copyWith(gender: 'malformed'));
        await tester.pump();
        final confirm =
            find.bySemanticsIdentifier('financial_plan_setup_confirm');
        await tester.ensureVisible(confirm);
        await tester.tap(confirm);
        await _pumpAsync(tester);

        expect((plans.setPlanCalls, plans.hasPlan), equals((0, false)));
        expect(
          find.text(
            'Indique un genre AVS canonique (F ou M) et confirme sa source avant de recalculer ce scénario.',
          ),
          findsOneWidget,
        );
        final recovery = find.bySemanticsIdentifier(
          'financial_plan_setup_enrich_gender',
        );
        expect(recovery, findsOneWidget);
        await tester.tap(recovery);
        await tester.pumpAndSettle();
        expect(
          find.text('/data-block/revenu?inputKey=q_gender'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'LPP confirmation discloses CHF bands and annual non-proration',
      (tester) async {
        final ledger = _ownedRetirementLedger();
        final plans = _CountingFinancialPlanProvider()
          ..attachProfileProvider(ledger);
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
        await _reachRetirementConfirmation(
          tester,
          targetDate: DateTime.now().add(const Duration(days: 8000)),
        );

        expect(
          find.bySemanticsIdentifier('financial_plan_setup_projection_band'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier(
            'financial_plan_setup_annual_approximation',
          ),
          findsOneWidget,
        );
        expect(
          _renderedTextCount(
            tester,
            'Projection annuelle simplifiée : les fractions d’année ne sont pas proratisées.',
          ),
          1,
        );
      },
    );

    for (final retirementAge in <int>[60, 67]) {
      testWidgets(
        'no-LPP retirement at age $retirementAge shows no caisse contract and can confirm',
        (tester) async {
          final birthYear = DateTime.now().year - 40;
          final ledger = _ownedNoLppLedger(birthYear: birthYear);
          final plans = _CountingFinancialPlanProvider()
            ..attachProfileProvider(ledger);
          final targetDate = DateTime(birthYear + retirementAge, 7, 1);
          addTearDown(ledger.dispose);
          addTearDown(plans.dispose);

          await tester.pumpWidget(
            _toolHarness(
              ledger: ledger,
              plans: plans,
              input: const {'goal': 'Préparer ma retraite sans LPP'},
            ),
          );
          await _pumpAsync(tester);
          await _reachNoLppRetirementConfirmation(
            tester,
            targetDate: targetDate,
          );

          expect(
            (
              find
                  .bySemanticsIdentifier(
                    'financial_plan_setup_retirement_scope',
                  )
                  .evaluate()
                  .length,
              find
                  .bySemanticsIdentifier(
                    'financial_plan_setup_return_assumption',
                  )
                  .evaluate()
                  .length,
              find
                  .bySemanticsIdentifier(
                    'financial_plan_setup_early_retirement_rule',
                  )
                  .evaluate()
                  .length,
              find
                  .bySemanticsIdentifier(
                    'financial_plan_setup_post65_gainful_activity',
                  )
                  .evaluate()
                  .length,
              _renderedTextCount(tester, 'Capital LPP'),
              _renderedTextCount(tester, 'Socle LPP'),
              _renderedTextCount(tester, 'règlement de ta caisse'),
              _renderedTextCount(tester, 'Source des faits LPP'),
            ),
            equals((0, 0, 0, 0, 0, 0, 0, 0)),
          );
          expect(
            _renderedTextCount(
              tester,
              'AVS, LPP, 3a et impôts exclus',
            ),
            1,
          );
          expect(
            find.bySemanticsIdentifier(
              'financial_plan_setup_savings_return_zero',
            ),
            findsOneWidget,
          );
          _expectLocalizedDisclaimerBeforeConfirm(tester);

          await tester.tap(
            find.bySemanticsIdentifier('financial_plan_setup_confirm'),
          );
          await _pumpAsync(tester);
          expect((plans.setPlanCalls, plans.hasPlan), equals((1, true)));
          expect(plans.currentPlan?.dependencyBranch, 'retirementNoLpp');
        },
      );
    }

    testWidgets(
      'no-LPP confirmation narrates monthly target rather than total goal',
      (tester) async {
        final reviewTime = DateTime.now().add(const Duration(seconds: 1));
        final ledger = _ownedNoLppLedger(
          birthYear: reviewTime.year - 40,
        );
        final plans = _CountingFinancialPlanProvider()
          ..attachProfileProvider(ledger);
        addTearDown(ledger.dispose);
        addTearDown(plans.dispose);

        await tester.pumpWidget(
          _directSetupHarness(
            ledger: ledger,
            plans: plans,
            clock: () => reviewTime,
          ),
        );
        await _reachNoLppRetirementConfirmation(
          tester,
          targetDate: DateTime(reviewTime.year + 20, reviewTime.month, 1),
        );

        expect(
          _renderedTextCount(
            tester,
            'épargne mensuelle confirmée de 12 500 CHF',
          ),
          1,
        );
        expect(
          _renderedTextCount(
            tester,
            'épargne mensuelle confirmée de 3 000 000 CHF',
          ),
          0,
          reason: 'The CHF 3,000,000 goal is not a monthly contribution.',
        );
        expect(
          find.bySemanticsIdentifier('financial_plan_setup_monthly_amount'),
          findsNothing,
          reason: 'The no-LPP narrative already owns the monthly semantic.',
        );
      },
    );

    testWidgets('general confirmation shows the calculated monthly amount',
        (tester) async {
      final ledger = await _loadedLedger();
      final plans = _CountingFinancialPlanProvider()
        ..attachProfileProvider(ledger);
      final reviewTime = DateTime.utc(2026, 7, 16, 12);
      addTearDown(ledger.dispose);
      addTearDown(plans.dispose);
      await tester.pumpWidget(
        _directSetupHarness(
          ledger: ledger,
          plans: plans,
          clock: () => reviewTime,
        ),
      );
      await _reachGeneralConfirmation(
        tester,
        targetDate: DateTime.utc(2028, 7, 16),
      );

      expect(
        find.bySemanticsIdentifier('financial_plan_setup_monthly_amount'),
        findsOneWidget,
      );
      expect(_renderedTextCount(tester, '1 000 CHF / mois'), 1);
    });

    testWidgets(
        'retirement LPP confirmation shows its calculated monthly amount',
        (tester) async {
      final ledger = _ownedRetirementLedger();
      final plans = _CountingFinancialPlanProvider()
        ..attachProfileProvider(ledger);
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
      await _reachRetirementConfirmation(
        tester,
        targetDate: DateTime.now().add(const Duration(days: 8000)),
      );

      expect(
        find.bySemanticsIdentifier('financial_plan_setup_monthly_amount'),
        findsOneWidget,
      );
      final monthly = find.descendant(
        of: find.bySemanticsIdentifier(
          'financial_plan_setup_monthly_amount',
        ),
        matching: find.byType(Text),
      );
      expect(tester.widget<Text>(monthly).data, endsWith('CHF / mois'));
    });

    testWidgets(
        'unknown affiliation blocks retirement context and routes only to the exact revenue fact',
        (tester) async {
      FeatureFlags.typedLppEvidence = true;
      FeatureFlags.documentLppEvidenceEnabled = true;
      final ledger = await _loadedLedger();
      final plans = _CountingFinancialPlanProvider()
        ..attachProfileProvider(ledger);
      addTearDown(ledger.dispose);
      addTearDown(plans.dispose);

      await tester.pumpWidget(
        _directSetupWithEnrichmentHarness(
          ledger: ledger,
          plans: plans,
          clock: DateTime.now,
        ),
      );
      await _pumpAsync(tester);
      await tester.tap(
        find.bySemanticsIdentifier('financial_plan_setup_category_retirement'),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Indique d’abord si tu es affilié·e à une caisse de pension.',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('financial_plan_setup_enrich_lpp'),
        findsNothing,
      );
      final continueButton = tester.widget<FilledButton>(
        find.descendant(
          of: find.bySemanticsIdentifier(
            'financial_plan_setup_retirement_continue',
          ),
          matching: find.byType(FilledButton),
        ),
      );
      expect(continueButton.onPressed, isNull);
      expect(
        find.bySemanticsIdentifier('financial_plan_setup_enrich_revenue'),
        findsOneWidget,
      );
      await tester.tap(
        find.bySemanticsIdentifier('financial_plan_setup_enrich_revenue'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('/data-block/revenu?inputKey=q_has_pension_fund'),
        findsOneWidget,
      );
    });

    for (final blockerCase in <({
      String name,
      _TestLedger ledger,
      String message,
      String? route,
      String? semantics,
    })>[
      (
        name: 'date of birth',
        ledger: _ownedRetirementLedger(withExactDateOfBirth: false),
        message:
            'La date de naissance exacte manque. Ajoute-la à ton profil avant de recalculer ce scénario.',
        route: '/data-block/revenu?inputKey=q_date_of_birth',
        semantics: 'financial_plan_setup_enrich_date_of_birth',
      ),
      (
        name: 'salary',
        ledger: _ownedRetirementLedger(grossMonthlySalary: 0),
        message:
            'Le salaire brut annuel actuel manque ou doit être reconfirmé.',
        route: '/data-block/revenu?inputKey=q_gross_salary_annual',
        semantics: 'financial_plan_setup_enrich_revenue',
      ),
    ]) {
      testWidgets(
        '${blockerCase.name} blocker exposes only its truthful recovery',
        (tester) async {
          final plans = _CountingFinancialPlanProvider()
            ..attachProfileProvider(blockerCase.ledger);
          addTearDown(blockerCase.ledger.dispose);
          addTearDown(plans.dispose);
          await tester.pumpWidget(
            _directSetupWithEnrichmentHarness(
              ledger: blockerCase.ledger,
              plans: plans,
              clock: DateTime.now,
            ),
          );
          await _reachRetirementConfirmation(
            tester,
            targetDate: DateTime.now().add(const Duration(days: 8000)),
          );

          expect(find.text(blockerCase.message), findsOneWidget);
          expect(
            find.bySemanticsIdentifier('financial_plan_setup_confirmation'),
            findsNothing,
          );
          expect(
            find.bySemanticsIdentifier('financial_plan_setup_enrich_lpp'),
            findsNothing,
          );
          final recovery = blockerCase.semantics == null
              ? find.byKey(const Key('missing-recovery'))
              : find.bySemanticsIdentifier(blockerCase.semantics!);
          final route = blockerCase.route;
          if (route != null && blockerCase.semantics != null) {
            expect(recovery, findsOneWidget);
            await tester.tap(recovery);
            await tester.pumpAndSettle();
            expect(find.text(route), findsOneWidget);
          } else {
            expect(recovery, findsNothing);
          }
        },
      );
    }

    testWidgets(
      'expired legal contract blocks before any monthly CHF draft is shown',
      (tester) async {
        final ledger = _ownedRetirementLedger();
        final plans = _CountingFinancialPlanProvider()
          ..attachProfileProvider(ledger);
        final reviewTime = DateTime.utc(2027, 1, 1);
        addTearDown(ledger.dispose);
        addTearDown(plans.dispose);
        await tester.pumpWidget(
          _directSetupHarness(
            ledger: ledger,
            plans: plans,
            clock: () => reviewTime,
          ),
        );
        await _reachRetirementConfirmation(
          tester,
          targetDate: DateTime(2048, 1, 2),
        );

        expect(
          find.text(
            'Le socle légal LPP de ce scénario a expiré. Cette projection est temporairement indisponible jusqu’à sa mise à jour.',
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('financial_plan_setup_confirmation'),
          findsNothing,
        );
        expect(
          find.bySemanticsIdentifier('financial_plan_setup_monthly_amount'),
          findsNothing,
        );
        expect(
          find.bySemanticsIdentifier('financial_plan_setup_enrich_lpp'),
          findsNothing,
        );
        expect(
          find.bySemanticsIdentifier('financial_plan_setup_enrich_revenue'),
          findsNothing,
        );
      },
    );

    for (final errorCase in <({
      String name,
      Object error,
      String message,
    })>[
      (
        name: 'owner authority',
        error: StateError('synthetic owner conflict'),
        message:
            'L’autorité de ce profil ne peut pas être vérifiée. Recharge tes données avant de réessayer.',
      ),
      (
        name: 'unexpected',
        error: const FormatException('synthetic unexpected failure'),
        message:
            'Cette projection est temporairement indisponible. Réessaie plus tard; aucun montant n’a été enregistré.',
      ),
    ]) {
      testWidgets('${errorCase.name} review failure stays honest',
          (tester) async {
        final ledger = _ownedRetirementLedger(previewError: errorCase.error);
        final plans = _CountingFinancialPlanProvider()
          ..attachProfileProvider(ledger);
        final reviewTime = DateTime.utc(2026, 7, 16, 12);
        addTearDown(ledger.dispose);
        addTearDown(plans.dispose);
        await tester.pumpWidget(
          _directSetupHarness(
            ledger: ledger,
            plans: plans,
            clock: () => reviewTime,
          ),
        );
        await _reachGeneralConfirmation(
          tester,
          targetDate: DateTime.utc(2028, 7, 16),
        );

        expect(find.text(errorCase.message), findsOneWidget);
        expect(
          find.bySemanticsIdentifier('financial_plan_setup_enrich_lpp'),
          findsNothing,
        );
        expect(
          find.bySemanticsIdentifier('financial_plan_setup_enrich_revenue'),
          findsNothing,
        );
      });
    }

    testWidgets('strict self LPP blocker alone offers the exact scan recovery',
        (tester) async {
      FeatureFlags.typedLppEvidence = true;
      FeatureFlags.documentLppEvidenceEnabled = true;
      final ledger = _ownedRetirementLedger(withLppSnapshot: false);
      final plans = _CountingFinancialPlanProvider()
        ..attachProfileProvider(ledger);
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
      await _reachRetirementConfirmation(
        tester,
        targetDate: DateTime.now().add(const Duration(days: 9000)),
      );

      final recovery = find.bySemanticsIdentifier(
        'financial_plan_setup_enrich_lpp',
      );
      expect(
        find.text(
          'Un avoir LPP récent et confirmé est nécessaire. La lecture du certificat est proposée uniquement lorsqu’elle est disponible.',
        ),
        findsOneWidget,
      );
      expect(recovery, findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.descendant(of: recovery, matching: find.byType(TextButton)),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets(
      'the LLM goal hint is PII-scrubbed bounded and editable before persistence',
      (tester) async {
        final ledger = await _loadedLedger();
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
        final ledger = await _loadedLedger();
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
      final remoteLedger = await _loadedLedger();
      final ledger = _TestLedger(remoteLedger.profile!);
      final now = DateTime.now();
      final generated = await PlanGenerationService.generate(
        goalDescription: 'Objectif synthétique explicite',
        goalCategory: 'goal_general',
        targetDate: now.add(const Duration(days: 730)),
        profile: ledger.profile,
        profileOwnerId: ledger.canonicalProfileOwnerId,
        selfLppSnapshot: null,
        goalAmount: 24000,
        now: now,
      );
      final plans = _CountingFinancialPlanProvider()
        ..setPlanDirect(
          generated.copyWith(
            coachNarrative: _calculatorNarrative,
            confirmedAt: now,
          ),
        )
        ..attachProfileProvider(ledger);
      addTearDown(remoteLedger.dispose);
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

    testWidgets('fresh Coach and Aujourd’hui amounts have stable semantics IDs',
        (tester) async {
      final ledger = await _loadedLedger();
      final plan = _planFor(ledger);
      addTearDown(ledger.dispose);

      await tester.pumpWidget(_localized(PlanPreviewCard.fromPlan(plan)));
      await tester.pump();
      expect(
        find.bySemanticsIdentifier('financial_plan_coach_fresh_state'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('financial_plan_coach_monthly_amount'),
        findsOneWidget,
      );

      await tester.pumpWidget(
        _localized(
          FinancialPlanCard(
            plan: plan,
            isStale: false,
            onRecalculate: (_) {},
          ),
        ),
      );
      await tester.pump();
      expect(
        find.bySemanticsIdentifier('financial_plan_home_fresh_state'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('financial_plan_home_monthly_amount'),
        findsOneWidget,
      );
    });

    testWidgets('Coach renders the sources carried by the specific plan',
        (tester) async {
      final ledger = await _loadedLedger();
      final plan = _planFor(ledger);
      addTearDown(ledger.dispose);

      await tester.pumpWidget(_localized(PlanPreviewCard.fromPlan(plan)));
      await tester.pump();

      expect(find.text(_specificSource), findsOneWidget);
    });

    testWidgets(
      'Aujourd’hui renders plan sources and not hardcoded ARB citations',
      (tester) async {
        final ledger = await _loadedLedger();
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

    testWidgets(
      'confirmed and restarted cards keep every material retirement condition visible',
      (tester) async {
        final restarted = FinancialPlan.fromJson(_retirementPlan().toJson());

        await tester.pumpWidget(
          _localized(
            Column(
              children: [
                PlanPreviewCard.fromPlan(restarted),
                FinancialPlanCard(
                  plan: restarted,
                  isStale: false,
                  onRecalculate: (_) {},
                ),
              ],
            ),
          ),
        );
        await tester.pump();

        expect(
          (
            _renderedTextCount(
              tester,
              'Projection annuelle simplifiée : les fractions d’année ne sont pas proratisées.',
            ),
            _renderedTextCount(
              tester,
              'Condition : le règlement de la caisse doit autoriser une prestation avant 63 ans.',
            ),
            _renderedTextCount(
              tester,
              'Hypothèse : activité lucrative poursuivie et ajournement possible auprès de la caisse.',
            ),
          ),
          (2, 2, 2),
          reason: 'Coach and Aujourd’hui must replay persisted materiality, '
              'not only the one-time consent dialog.',
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

    testWidgets('Coach LPP low confidence exposes only the exact scan recovery',
        (tester) async {
      FeatureFlags.typedLppEvidence = true;
      FeatureFlags.documentLppEvidenceEnabled = true;
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
      expect(find.text('/scan?type=lppCertificate'), findsOneWidget);
    });

    testWidgets(
      'Aujourd’hui LPP low confidence exposes only the exact scan recovery',
      (tester) async {
        FeatureFlags.typedLppEvidence = true;
        FeatureFlags.documentLppEvidenceEnabled = true;
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
        expect(find.text('/scan?type=lppCertificate'), findsOneWidget);
      },
    );

    testWidgets('no-LPP low confidence exposes no fake enrichment action',
        (tester) async {
      FeatureFlags.typedLppEvidence = true;
      FeatureFlags.documentLppEvidenceEnabled = true;

      await tester.pumpWidget(
        _localized(
          Column(
            children: [
              PlanPreviewCard.fromPlan(
                _retirementPlan(confidence: 55, hasLpp: false),
              ),
              FinancialPlanCard(
                plan: _retirementPlan(confidence: 55, hasLpp: false),
                isStale: false,
                onRecalculate: (_) {},
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('financial_plan_coach_improve_precision'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('financial_plan_home_improve_precision'),
        findsNothing,
      );
    });

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

    testWidgets('retirement presentation trusts dependency branch only',
        (tester) async {
      final noLppWithLppLookingAssumptions = _retirementPlan(hasLpp: true)
          .copyWith(dependencyBranch: 'retirementNoLpp');
      final lppWithNoLppLookingAssumptions = _retirementPlan(hasLpp: false)
          .copyWith(dependencyBranch: 'retirementLpp');

      await tester.pumpWidget(
        _localized(
          Column(
            children: [
              PlanPreviewCard.fromPlan(noLppWithLppLookingAssumptions),
              FinancialPlanCard(
                plan: lppWithNoLppLookingAssumptions,
                isStale: false,
                onRecalculate: (_) {},
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(
        _renderedTextCount(
          tester,
          'AVS, LPP, 3a et impôts exclus',
        ),
        1,
      );
      expect(
        _renderedTextCount(tester, 'AVS, 3a et impôts exclus'),
        1,
      );
    });

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
      'stale recovery carries explicit scenario inputs into standard review',
      (tester) async {
        final ledger = await _loadedLedger();
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
        await tester.pumpAndSettle();

        expect(
          (
            plans.setPlanCalls,
            plans.currentPlan?.toJson()['goalAmount'],
            plans.currentPlan?.milestones.last.targetAmount,
            find
                .bySemanticsIdentifier('financial_plan_setup')
                .evaluate()
                .length,
          ),
          equals((0, 24000.0, 1.0, 1)),
          reason: 'Recalculate is review-only. It preserves the explicit '
              'scenario amount and never treats a milestone as an input.',
        );
      },
    );

    testWidgets(
      'ambiguous legacy 100% milestones stay stale and unregeneratable',
      (tester) async {
        final ledger = await _loadedLedger();
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
