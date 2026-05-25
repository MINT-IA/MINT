import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/data_spine_snapshot.dart';
import 'package:mint_mobile/models/mint_user_state.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/screens/mon_argent/mon_argent_screen.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_phase.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('uses MintState data spine budget before stored budget inputs',
      (tester) async {
    final mintState = MintStateProvider()
      ..injectStateForTest(_stateWithDataSpine());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BudgetProvider>(
            create: (_) => BudgetProvider(),
          ),
          ChangeNotifierProvider<CoachProfileProvider>(
            create: (_) => CoachProfileProvider(),
          ),
          ChangeNotifierProvider<MintStateProvider>.value(value: mintState),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: MonArgentScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Ton libre mensuel'), findsOneWidget);
    expect(find.text('Fiabilité'), findsOneWidget);
    expect(find.text('64%'), findsOneWidget);
    expect(find.text('Estimation crédible.'), findsOneWidget);
    expect(find.text('Situation financière'), findsOneWidget);
    expect(find.text('Revenu brut annuel'), findsOneWidget);
    expect(find.text('Logement'), findsOneWidget);
    expect(find.text('Primes maladie (LAMal)'), findsOneWidget);
    expect(find.text('Liquidités disponibles'), findsOneWidget);
    expect(find.text('Investissements'), findsOneWidget);
    expect(find.text('Extrait AVS'), findsOneWidget);
    expect(find.text('Prévoyance LPP'), findsOneWidget);
    expect(find.text('3e pilier (3a)'), findsOneWidget);
    expect(find.text('Ta trajectoire'), findsOneWidget);
    expect(find.text('Cible'), findsOneWidget);
    expect(find.text('Libre aujourd’hui'), findsOneWidget);
    expect(find.text('Écart mensuel à combler'), findsOneWidget);
    expect(find.text('Prochaine étape'), findsOneWidget);
    expect(find.text("8'000\u00a0CHF"), findsOneWidget);
    expect(find.text("2'100\u00a0CHF"), findsWidgets);
    expect(find.text("120'000\u00a0CHF"), findsWidgets);
    expect(find.text("2'000\u00a0CHF"), findsOneWidget);
    expect(find.text("0\u00a0CHF"), findsOneWidget);
    expect(find.text("108'000\u00a0CHF"), findsOneWidget);
    expect(find.text("2'400\u00a0CHF"), findsOneWidget);
    expect(find.text("390\u00a0CHF"), findsOneWidget);
    expect(find.text("30'000\u00a0CHF"), findsWidgets);
    expect(find.text("12'000\u00a0CHF"), findsOneWidget);
    expect(find.text("32'000\u00a0CHF"), findsWidgets);
    expect(find.text('Manquant'), findsWidgets);
    expect(find.text("172'000\u00a0CHF"), findsNWidgets(2));
  });

  testWidgets('exposes Maestro semantics anchors for central money surfaces',
      (tester) async {
    final mintState = MintStateProvider()
      ..injectStateForTest(_stateWithDataSpine());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BudgetProvider>(
            create: (_) => BudgetProvider(),
          ),
          ChangeNotifierProvider<CoachProfileProvider>(
            create: (_) => CoachProfileProvider(),
          ),
          ChangeNotifierProvider<MintStateProvider>.value(value: mintState),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: MonArgentScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      tester
          .getSemantics(find.byKey(const Key('mon_argent_screen')))
          .identifier,
      'mon_argent_screen',
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('mon_argent_data_spine_summary')))
          .identifier,
      'mon_argent_data_spine_summary',
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('mon_argent_situation_map')))
          .identifier,
      'mon_argent_situation_map',
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('mon_argent_trajectory_map')))
          .identifier,
      'mon_argent_trajectory_map',
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('mon_argent_budget_summary')))
          .identifier,
      'mon_argent_budget_summary',
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('mon_argent_patrimoine_summary')))
          .identifier,
      'mon_argent_patrimoine_summary',
    );
  });
}

MintUserState _stateWithDataSpine() {
  final profile = CoachProfile(
    birthYear: 1988,
    canton: 'VD',
    salaireBrutMensuel: 9000,
    goalA: GoalA(
      type: GoalAType.achatImmo,
      targetDate: DateTime(2030),
      label: 'Logement',
    ),
  );
  final spine = _dataSpine();
  return MintUserState(
    profile: profile,
    lifecyclePhase: LifecyclePhase.construction,
    archetype: FinancialArchetype.swissNative,
    budgetSnapshot: spine.budget,
    dataSpineSnapshot: spine,
    confidenceScore: 64,
    capMemory: const CapMemory(),
    computedAt: DateTime.utc(2026, 5, 24),
  );
}

DataSpineSnapshot _dataSpine() {
  const meta = SpineFieldMeta(
    source: ProfileDataSource.userInput,
    confidence: FieldConfidence.known,
    freshness: FieldFreshness.fresh,
  );

  return DataSpineSnapshot(
    situation: const FinancialSituation(
      firstName: SpineValue(value: 'Julien', meta: meta),
      birthYear: SpineValue(value: 1988, meta: meta),
      canton: SpineValue(value: 'VD', meta: meta),
      commune: SpineValue(value: 'Lausanne', meta: meta),
      grossAnnualIncome: SpineValue(value: 108000, meta: meta),
      employmentStatus: SpineValue(value: 'salarie', meta: meta),
      monthlyHousingCost: SpineValue(value: 2400, meta: meta),
      lamalPremiumMonthly: SpineValue(value: 390, meta: meta),
      liquidSavings: SpineValue(value: 30000, meta: meta),
      investments: SpineValue(value: 12000, meta: meta),
      totalDebt: SpineValue(value: 10000, meta: meta),
      housingStatus: SpineValue(value: 'locataire', meta: meta),
      activeGoalType: SpineValue(value: GoalAType.achatImmo, meta: meta),
    ),
    budget: const BudgetSnapshot(
      present: PresentBudget(
        monthlyNet: 8000,
        monthlyCharges: 5200,
        monthlySavings: 700,
        monthlyFree: 2100,
      ),
      capImpacts: [],
      stage: BudgetStage.presentOnly,
      confidenceScore: 64,
    ),
    pillars: const PillarPosition(
      avs: AvsPosition(
        contributionYears: PillarFact.missing(),
        gaps: PillarFact.missing(),
        estimatedMonthlyPension: PillarFact.missing(),
        ramd: PillarFact.missing(),
      ),
      lpp: LppPosition(
        totalBalance: PillarFact(
          value: 120000,
          state: PillarFactState.known,
          meta: meta,
        ),
        mandatoryBalance: PillarFact.missing(),
        supplementaryBalance: PillarFact.missing(),
        insuredSalary: PillarFact.missing(),
        buybackMax: PillarFact.missing(),
      ),
      pillar3a: Pillar3aPosition(
        totalBalance: PillarFact(
          value: 32000,
          state: PillarFactState.known,
          meta: meta,
        ),
        accountsCount: PillarFact.missing(),
        annualContribution: PillarFact.missing(),
        canContribute: true,
      ),
    ),
    trajectory: const TrajectorySummary(
      status: TrajectoryStatus.onTrack,
      currentMonthlyFree: 2100,
      currentMonthlyCapacity: 2800,
      targetAmount: 120000,
      monthsToTarget: 48,
      monthlyRequired: 2000,
      monthlyGap: -100,
      nextLeverId: 'maintain_plan',
    ),
    computedAt: DateTime.utc(2026, 5, 24),
  );
}
