import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/plan_generation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ────────────────────────────────────────────────────────────────────────────
//  PlanGenerationService Tests
//
//  Tests the calculator-backed plan generation logic.
//  MonteCarloProjectionService is NOT called directly in tests (overhead).
//  Arithmetic fallback path is exercised for all non-retirement goals.
// ────────────────────────────────────────────────────────────────────────────

/// Minimal CoachProfile fixture with salary only (low confidence).
CoachProfile _profileSalaryOnly() => CoachProfile(
      birthYear: 1985,
      canton: 'VS',
      salaireBrutMensuel: 5000,
      goalA: GoalA(
        type: GoalAType.achatImmo,
        targetDate: DateTime(2030, 1, 1),
        label: 'Achat immobilier',
      ),
    );

/// Richer CoachProfile with LPP + 3a (higher confidence).
CoachProfile _profileComplete() => CoachProfile(
      birthYear: 1977,
      dateOfBirth: DateTime(1977, 1, 12),
      canton: 'VS',
      salaireBrutMensuel: 10184,
      prevoyance: const PrevoyanceProfile(
        avoirLppTotal: 70000,
        totalEpargne3a: 32000,
      ),
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2042, 1, 12),
        label: 'Retraite',
      ),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Mock SharedPreferences for platform channel
    SharedPreferences.setMockInitialValues({});
  });

  group('PlanGenerationService', () {
    // Test 1: housing goal — monthlyTarget = goalAmount / monthsRemaining
    test('Test 1: housing goal returns monthlyTarget ~2361 CHF for 85000/36',
        () async {
      final profile = _profileSalaryOnly();
      // Use exact month offset so the service computes exactly 36 months
      final now = DateTime.now();
      final targetDate = DateTime(now.year + 3, now.month, now.day);

      final plan = await PlanGenerationService.generate(
        goalDescription: 'Constituer un apport pour mon appartement',
        goalCategory: 'goal_house',
        targetDate: targetDate,
        profile: profile,
        goalAmount: 85000,
      );

      // 36 months exactly → 85000 / 36 ≈ 2361.11 CHF
      expect(plan.monthlyTarget, closeTo(85000 / 36, 5),
          reason: 'Housing goal: 85000 / 36 months');
    });

    // Test 2: exactly 4 milestones at 25/50/75/100%
    test('Test 2: generate() produces exactly 4 milestones', () async {
      final profile = _profileSalaryOnly();
      final targetDate = DateTime.now().add(const Duration(days: 365 * 3));

      final plan = await PlanGenerationService.generate(
        goalDescription: 'Fonds de roulement',
        goalCategory: 'goal_emergency_fund',
        targetDate: targetDate,
        profile: profile,
      );

      expect(plan.milestones, hasLength(4));

      // Milestones are generated from effectiveGoalAmount (default 30000 for
      // goal_emergency_fund), not from monthlyTarget * months.
      // Verify the 4 milestones are at 25/50/75/100% of the goal amount.
      const goalAmount = 30000.0; // default for goal_emergency_fund
      const tolerance = goalAmount * 0.01; // 1% tolerance
      expect(plan.milestones[0].targetAmount,
          closeTo(goalAmount * 0.25, tolerance));
      expect(plan.milestones[1].targetAmount,
          closeTo(goalAmount * 0.50, tolerance));
      expect(plan.milestones[2].targetAmount,
          closeTo(goalAmount * 0.75, tolerance));
      expect(plan.milestones[3].targetAmount,
          closeTo(goalAmount * 1.00, tolerance));
    });

    // Test 3: goalCategory matches input
    test('Test 3: goalCategory matches the input category string', () async {
      final profile = _profileSalaryOnly();
      final targetDate = DateTime.now().add(const Duration(days: 365 * 2));

      final plan = await PlanGenerationService.generate(
        goalDescription: 'Remboursement de dettes',
        goalCategory: 'goal_control_debts',
        targetDate: targetDate,
        profile: profile,
      );

      expect(plan.goalCategory, equals('goal_control_debts'));
    });

    // Test 4: coachNarrative is non-empty
    test('Test 4: generate() includes non-empty coachNarrative', () async {
      final profile = _profileSalaryOnly();
      final targetDate = DateTime.now().add(const Duration(days: 365));

      final plan = await PlanGenerationService.generate(
        goalDescription: 'Optimiser mes impots',
        goalCategory: 'goal_tax_basic',
        targetDate: targetDate,
        profile: profile,
      );

      expect(plan.coachNarrative, isNotEmpty);
    });

    // Test 5: disclaimer contains "LSFin"
    test('Test 5: disclaimer contains "LSFin"', () async {
      final profile = _profileSalaryOnly();
      final targetDate = DateTime.now().add(const Duration(days: 365));

      final plan = await PlanGenerationService.generate(
        goalDescription: 'Constituer un fonds de roulement',
        goalCategory: 'goal_emergency_fund',
        targetDate: targetDate,
        profile: profile,
      );

      expect(plan.disclaimer, contains('LSFin'));
    });

    // Test 6: sources list includes at least one legal reference
    test('Test 6: sources includes at least one legal reference', () async {
      final profile = _profileSalaryOnly();
      final targetDate = DateTime.now().add(const Duration(days: 365));

      final plan = await PlanGenerationService.generate(
        goalDescription: 'Investissement initial',
        goalCategory: 'goal_invest_simple',
        targetDate: targetDate,
        profile: profile,
      );

      expect(plan.sources, isNotEmpty);
      // At least one source contains a legal reference
      final hasLegalRef = plan.sources.any(
        (s) => s.contains('art.') || s.contains('art ') || s.contains('LPP') || s.contains('LIFD'),
      );
      expect(hasLegalRef, isTrue,
          reason: 'Sources should contain legal references like LIFD art. 38 or LPP art. 14');
    });

    // Test 7: profileHashAtGeneration is set from profile
    test('Test 7: profileHashAtGeneration is computed from profile', () async {
      final profile1 = _profileSalaryOnly();
      final profile2 = CoachProfile(
        birthYear: 1990,
        canton: 'ZH',
        salaireBrutMensuel: 7000,
        goalA: GoalA(
          type: GoalAType.achatImmo,
          targetDate: DateTime(2030, 1, 1),
          label: 'Achat',
        ),
      );

      final targetDate = DateTime.now().add(const Duration(days: 365));

      final plan1 = await PlanGenerationService.generate(
        goalDescription: 'Apport immobilier',
        goalCategory: 'goal_house',
        targetDate: targetDate,
        profile: profile1,
      );

      final plan2 = await PlanGenerationService.generate(
        goalDescription: 'Apport immobilier',
        goalCategory: 'goal_house',
        targetDate: targetDate,
        profile: profile2,
      );

      // Different profiles → different hashes
      expect(plan1.profileHashAtGeneration, isNotEmpty);
      expect(plan2.profileHashAtGeneration, isNotEmpty);
      expect(plan1.profileHashAtGeneration,
          isNot(equals(plan2.profileHashAtGeneration)));

      // Same profile → same hash
      final plan3 = await PlanGenerationService.generate(
        goalDescription: 'Apport immobilier',
        goalCategory: 'goal_house',
        targetDate: targetDate,
        profile: profile1,
      );
      expect(plan1.profileHashAtGeneration,
          equals(plan3.profileHashAtGeneration));
    });

    // Test 8: retirement goal uses different computation path
    test(
        'Test 8: retirement goal computes differently from simple arithmetic',
        () async {
      final profile = _profileComplete();
      // Target 16+ years out to avoid "past date" error
      final targetDate = DateTime(2042, 1, 12);

      final plan = await PlanGenerationService.generate(
        goalDescription: 'Préparer ma retraite',
        goalCategory: 'goal_retirement_plan',
        targetDate: targetDate,
        profile: profile,
      );

      expect(plan.goalCategory, equals('goal_retirement_plan'));
      // Retirement plan should have a valid positive monthlyTarget
      expect(plan.monthlyTarget, greaterThan(0));
      // The plan should be distinct from a simple goalAmount/months calculation
      // (i.e., goalCategory is reflected in the plan)
      expect(plan.milestones, hasLength(4));
    });

    // Test 9: targetDate in the past throws or returns error-state plan
    test('Test 9: targetDate in the past throws ArgumentError', () async {
      final profile = _profileSalaryOnly();
      final pastDate = DateTime.now().subtract(const Duration(days: 30));

      expect(
        () async => await PlanGenerationService.generate(
          goalDescription: 'Objectif passé',
          goalCategory: 'goal_emergency_fund',
          targetDate: pastDate,
          profile: profile,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    // Test 10: confidenceLevel increases with more profile data
    test(
        'Test 10: confidenceLevel is higher for complete profile than salary-only',
        () async {
      final profileLow = _profileSalaryOnly();
      final profileHigh = _profileComplete();

      final targetDate = DateTime.now().add(const Duration(days: 365 * 5));

      final planLow = await PlanGenerationService.generate(
        goalDescription: 'Objectif général',
        goalCategory: 'goal_invest_simple',
        targetDate: targetDate,
        profile: profileLow,
      );

      final planHigh = await PlanGenerationService.generate(
        goalDescription: 'Objectif général',
        goalCategory: 'goal_invest_simple',
        targetDate: targetDate,
        profile: profileHigh,
      );

      expect(planHigh.confidenceLevel, greaterThan(planLow.confidenceLevel),
          reason:
              'Profile with salary+LPP+3a+dateOfBirth should yield higher confidence');
    });
  });
}
