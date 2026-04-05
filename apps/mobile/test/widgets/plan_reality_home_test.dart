import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/services/plan_tracking_service.dart';
import 'package:mint_mobile/services/streak_service.dart';
import 'package:mint_mobile/widgets/coach/first_check_in_cta_card.dart';
import 'package:mint_mobile/widgets/coach/plan_reality_card.dart';
import 'package:mint_mobile/widgets/coach/streak_badge.dart';

// ────────────────────────────────────────────────────────────
//  PLAN REALITY HOME TEST — Phase 5 / SUI-03, SUI-05
//
//  Tests:
//  1. CoachProfile has 0 checkIns and hasPlan=true → FirstCheckInCtaCard
//  2. CoachProfile has 0 checkIns and hasPlan=false → SizedBox.shrink
//  3. CoachProfile has >=1 checkIn and >=1 plannedContribution → PlanRealityCard
//  4. StreakBadgeWidget is rendered INSIDE PlanRealityCard (as descendant)
// ────────────────────────────────────────────────────────────

Widget _buildTestApp({
  required CoachProfileProvider coachProvider,
  required FinancialPlanProvider planProvider,
  required Widget Function(BuildContext) sectionBuilder,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr')],
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachProfileProvider>.value(value: coachProvider),
        ChangeNotifierProvider<FinancialPlanProvider>.value(value: planProvider),
      ],
      child: Builder(
        builder: (ctx) => Scaffold(
          body: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: sectionBuilder(ctx),
          ),
        ),
      ),
    ),
  );
}

CoachProfile _profileWithData({
  List<MonthlyCheckIn> checkIns = const [],
  List<PlannedMonthlyContribution> contributions = const [],
}) {
  return CoachProfile(
    birthYear: 1985,
    canton: 'VS',
    salaireBrutMensuel: 8000.0,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2050),
      label: 'Retraite',
    ),
    checkIns: checkIns,
    plannedContributions: contributions,
  );
}

CoachProfileProvider _providerWithProfile(CoachProfile profile) {
  final provider = CoachProfileProvider();
  provider.createFromRemoteProfile({'birth_year': 1985, 'canton': 'VS'});
  for (final ci in profile.checkIns) {
    provider.addCheckIn(ci);
  }
  if (profile.plannedContributions.isNotEmpty) {
    provider.updateContributions(profile.plannedContributions);
  }
  return provider;
}

FinancialPlanProvider _planProviderWithPlan() {
  final provider = FinancialPlanProvider();
  provider.setPlanDirect(FinancialPlan(
    id: 'test-plan-01',
    goalDescription: 'Plan test',
    goalCategory: 'retraite',
    monthlyTarget: 500.0,
    milestones: const [],
    projectedOutcome: 200000.0,
    targetDate: DateTime(2050),
    generatedAt: DateTime(2026, 3, 1),
    profileHashAtGeneration: 'test-hash',
    coachNarrative: 'Narrative',
    confidenceLevel: 70.0,
    sources: const [],
    disclaimer: 'Outil educatif.',
  ));
  return provider;
}

/// Build a minimal PlanStatus for testing.
PlanStatus _testStatus() {
  return const PlanStatus(
    score: 0.5,
    completedActions: 1,
    totalActions: 2,
    nextActions: ['Verser 3a'],
  );
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MintHomeScreen Section 1c — Plan Reality + Streak', () {
    testWidgets(
        'hasPlan=true + 0 checkIns → FirstCheckInCtaCard is rendered',
        (tester) async {
      final coachProvider = _providerWithProfile(_profileWithData());
      final planProvider = _planProviderWithPlan(); // hasPlan=true

      await tester.pumpWidget(_buildTestApp(
        coachProvider: coachProvider,
        planProvider: planProvider,
        sectionBuilder: (ctx) {
          final profile = ctx.watch<CoachProfileProvider>().profile;
          final hasPlan = ctx.watch<FinancialPlanProvider>().hasPlan;

          if (profile == null) return const SizedBox.shrink();

          if (profile.checkIns.isEmpty ||
              profile.plannedContributions.isEmpty) {
            if (!hasPlan) return const SizedBox.shrink();
            return FirstCheckInCtaCard(onTap: () {});
          }
          return const SizedBox.shrink();
        },
      ));
      await tester.pump();

      expect(find.byType(FirstCheckInCtaCard), findsOneWidget);
    });

    testWidgets(
        'hasPlan=false + 0 checkIns → neither card rendered (SizedBox.shrink)',
        (tester) async {
      final coachProvider = _providerWithProfile(_profileWithData());
      final planProvider = FinancialPlanProvider(); // hasPlan=false

      await tester.pumpWidget(_buildTestApp(
        coachProvider: coachProvider,
        planProvider: planProvider,
        sectionBuilder: (ctx) {
          final profile = ctx.watch<CoachProfileProvider>().profile;
          final hasPlan = ctx.watch<FinancialPlanProvider>().hasPlan;

          if (profile == null) return const SizedBox.shrink();
          if (profile.checkIns.isEmpty ||
              profile.plannedContributions.isEmpty) {
            if (!hasPlan) return const SizedBox.shrink();
            return FirstCheckInCtaCard(onTap: () {});
          }
          return const SizedBox.shrink();
        },
      ));
      await tester.pump();

      expect(find.byType(FirstCheckInCtaCard), findsNothing);
      expect(find.byType(PlanRealityCard), findsNothing);
    });

    testWidgets(
        'checkIns >= 1 and plannedContributions >= 1 → PlanRealityCard rendered',
        (tester) async {
      final checkIn = MonthlyCheckIn(
        month: DateTime(2026, 3, 1),
        versements: {'3a': 500.0},
        completedAt: DateTime(2026, 3, 5),
      );
      final contribution = PlannedMonthlyContribution(
        id: '3a',
        label: '3a Julien',
        amount: 500.0,
        category: '3a',
      );
      final profile = _profileWithData(
        checkIns: [checkIn],
        contributions: [contribution],
      );
      final coachProvider = _providerWithProfile(profile);
      final planProvider = FinancialPlanProvider();

      await tester.pumpWidget(_buildTestApp(
        coachProvider: coachProvider,
        planProvider: planProvider,
        sectionBuilder: (ctx) {
          final p = ctx.watch<CoachProfileProvider>().profile;
          if (p == null) return const SizedBox.shrink();

          if (p.checkIns.isEmpty || p.plannedContributions.isEmpty) {
            return const SizedBox.shrink();
          }

          return PlanRealityCard(
            status: _testStatus(),
            compoundImpact: 50000.0,
            monthsToRetirement: 240,
          );
        },
      ));
      await tester.pump();

      expect(find.byType(PlanRealityCard), findsOneWidget);
    });

    testWidgets(
        'StreakBadgeWidget is rendered INSIDE PlanRealityCard (as descendant)',
        (tester) async {
      final checkIn = MonthlyCheckIn(
        month: DateTime(2026, 3, 1),
        versements: {'3a': 500.0},
        completedAt: DateTime(2026, 3, 5),
      );
      final contribution = PlannedMonthlyContribution(
        id: '3a',
        label: '3a Julien',
        amount: 500.0,
        category: '3a',
      );
      final profile = _profileWithData(
        checkIns: [checkIn],
        contributions: [contribution],
      );
      final coachProvider = _providerWithProfile(profile);
      final planProvider = FinancialPlanProvider();
      final streak = StreakService.compute(profile);

      await tester.pumpWidget(_buildTestApp(
        coachProvider: coachProvider,
        planProvider: planProvider,
        sectionBuilder: (ctx) {
          return PlanRealityCard(
            status: _testStatus(),
            compoundImpact: 50000.0,
            monthsToRetirement: 240,
            streakBadge: StreakBadgeWidget(streak: streak),
          );
        },
      ));
      await tester.pump();

      final planRealityFinder = find.byType(PlanRealityCard);
      final streakBadgeFinder = find.byType(StreakBadgeWidget);

      expect(planRealityFinder, findsOneWidget);
      expect(
        find.descendant(
          of: planRealityFinder,
          matching: streakBadgeFinder,
        ),
        findsOneWidget,
        reason: 'StreakBadgeWidget must be INSIDE PlanRealityCard, not above it',
      );
    });
  });
}
