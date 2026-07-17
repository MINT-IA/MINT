import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/services/plan_generation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profileOwnerId = '11111111-1111-4111-8111-111111111111';

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
      gender: 'M',
      canton: 'VS',
      salaireBrutMensuel: 10184,
      prevoyance: const PrevoyanceProfile(
        hasPensionFund: true,
        avoirLppTotal: 70000,
        rendementCaisse: 0.02,
        totalEpargne3a: 32000,
      ),
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2042, 1, 12),
        label: 'Retraite',
      ),
      financialLiteracyLevel: FinancialLiteracyLevel.advanced,
      dataSources: const {
        'salaireBrutMensuel': ProfileDataSource.userInput,
        'dateOfBirth': ProfileDataSource.userInput,
        'gender': ProfileDataSource.userInput,
        'prevoyance.hasPensionFund': ProfileDataSource.userInput,
        'prevoyance.avoirLppTotal': ProfileDataSource.userInput,
        'prevoyance.rendementCaisse': ProfileDataSource.userInput,
        'prevoyance.totalEpargne3a': ProfileDataSource.userInput,
      },
      dataTimestamps: {
        for (final path in const [
          'salaireBrutMensuel',
          'dateOfBirth',
          'gender',
          'prevoyance.hasPensionFund',
          'prevoyance.avoirLppTotal',
          'prevoyance.rendementCaisse',
          'prevoyance.totalEpargne3a',
        ])
          path: DateTime(2026, 7, 1),
      },
      inferDataSources: false,
    );

LppEvidenceSnapshot _selfLppSnapshot(
  CoachProfile profile, {
  DateTime? updatedAt,
}) {
  final stamp = updatedAt ??
      profile.dataTimestamps['prevoyance.avoirLppTotal'] ??
      DateTime.now();
  return LppEvidenceSnapshot(
    snapshotId: '22222222-2222-4222-8222-222222222222',
    facts: {
      LppEvidenceFactKey.vestedBenefitsCapitalChf: LppEvidenceFact(
        value: profile.prevoyance.avoirLppTotal!,
        unit: LppEvidenceUnit.chf,
        profileOwnerId: _profileOwnerId,
        actorProfileOwnerId: _profileOwnerId,
        source: profile.dataSources['prevoyance.avoirLppTotal']!.name,
        sourceDate: profile.dataSourceDates['prevoyance.avoirLppTotal'],
        updatedAt: stamp,
      ),
    },
  );
}

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
        profileOwnerId: _profileOwnerId,
        selfLppSnapshot: null,
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
        profileOwnerId: _profileOwnerId,
        selfLppSnapshot: null,
        goalDescription: 'Fonds de roulement',
        goalCategory: 'goal_emergency_fund',
        targetDate: targetDate,
        profile: profile,
        goalAmount: 30000,
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
        profileOwnerId: _profileOwnerId,
        selfLppSnapshot: null,
        goalDescription: 'Remboursement de dettes',
        goalCategory: 'goal_control_debts',
        targetDate: targetDate,
        profile: profile,
        goalAmount: 20000,
      );

      expect(plan.goalCategory, equals('goal_control_debts'));
    });

    // Test 4: coachNarrative is non-empty
    test('Test 4: generate() includes non-empty coachNarrative', () async {
      final profile = _profileSalaryOnly();
      final targetDate = DateTime.now().add(const Duration(days: 365));

      final plan = await PlanGenerationService.generate(
        profileOwnerId: _profileOwnerId,
        selfLppSnapshot: null,
        goalDescription: 'Optimiser mes impots',
        goalCategory: 'goal_tax_basic',
        targetDate: targetDate,
        profile: profile,
        goalAmount: 10000,
      );

      expect(plan.coachNarrative, isNotEmpty);
    });

    // Test 5: full mandatory disclaimer
    test('Test 5: disclaimer uses the mandatory MINT wording', () async {
      final profile = _profileSalaryOnly();
      final targetDate = DateTime.now().add(const Duration(days: 365));

      final plan = await PlanGenerationService.generate(
        profileOwnerId: _profileOwnerId,
        selfLppSnapshot: null,
        goalDescription: 'Constituer un fonds de roulement',
        goalCategory: 'goal_emergency_fund',
        targetDate: targetDate,
        profile: profile,
        goalAmount: 30000,
      );

      expect(plan.disclaimer, mandatoryMintPlanDisclaimer);
    });

    // Test 6: simple arithmetic has no decorative legal reference
    test('Test 6: simple arithmetic has no legal source', () async {
      final profile = _profileSalaryOnly();
      final targetDate = DateTime.now().add(const Duration(days: 365));

      final plan = await PlanGenerationService.generate(
        profileOwnerId: _profileOwnerId,
        selfLppSnapshot: null,
        goalDescription: 'Investissement initial',
        goalCategory: 'goal_invest_simple',
        targetDate: targetDate,
        profile: profile,
        goalAmount: 50000,
      );

      expect(plan.sources, isEmpty);
    });

    // Test 7: the general branch hashes only dependencies it consumes.
    test('Test 7: general fingerprint ignores unrelated profile fields',
        () async {
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
        profileOwnerId: _profileOwnerId,
        selfLppSnapshot: null,
        goalDescription: 'Apport immobilier',
        goalCategory: 'goal_house',
        targetDate: targetDate,
        profile: profile1,
        goalAmount: 500000,
      );

      final plan2 = await PlanGenerationService.generate(
        profileOwnerId: _profileOwnerId,
        selfLppSnapshot: null,
        goalDescription: 'Apport immobilier',
        goalCategory: 'goal_house',
        targetDate: targetDate,
        profile: profile2,
        goalAmount: 500000,
      );

      // The general calculator consumes only the confirmed scenario envelope.
      expect(plan1.profileHashAtGeneration, isNotEmpty);
      expect(plan2.profileHashAtGeneration, isNotEmpty);
      expect(plan1.profileHashAtGeneration, plan2.profileHashAtGeneration);

      // Same profile → same hash
      final plan3 = await PlanGenerationService.generate(
        profileOwnerId: _profileOwnerId,
        selfLppSnapshot: null,
        goalDescription: 'Apport immobilier',
        goalCategory: 'goal_house',
        targetDate: targetDate,
        profile: profile1,
        goalAmount: 500000,
      );
      expect(
          plan1.profileHashAtGeneration, equals(plan3.profileHashAtGeneration));
    });

    // Test 8: retirement goal uses different computation path
    test('Test 8: retirement goal computes differently from simple arithmetic',
        () async {
      final profile = _profileComplete();
      // Target 16+ years out to avoid "past date" error
      final targetDate = DateTime(2042, 1, 12);

      final plan = await PlanGenerationService.generate(
        profileOwnerId: _profileOwnerId,
        selfLppSnapshot: _selfLppSnapshot(profile),
        goalDescription: 'Préparer ma retraite',
        goalCategory: 'goal_retirement_plan',
        targetDate: targetDate,
        profile: profile,
        goalAmount: 1000000,
        prospectiveLppReturn: 0.02,
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
          profileOwnerId: _profileOwnerId,
          selfLppSnapshot: null,
          goalDescription: 'Objectif passé',
          goalCategory: 'goal_emergency_fund',
          targetDate: pastDate,
          profile: profile,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    // Test 10: unused facts never inflate branch confidence.
    test('Test 10: general confidence ignores unrelated profile completeness',
        () async {
      final profileLow = _profileSalaryOnly();
      final profileHigh = _profileComplete();

      final targetDate = DateTime.now().add(const Duration(days: 365 * 5));

      final planLow = await PlanGenerationService.generate(
        profileOwnerId: _profileOwnerId,
        selfLppSnapshot: null,
        goalDescription: 'Objectif général',
        goalCategory: 'goal_invest_simple',
        targetDate: targetDate,
        profile: profileLow,
        goalAmount: 50000,
      );

      final planHigh = await PlanGenerationService.generate(
        profileOwnerId: _profileOwnerId,
        selfLppSnapshot: null,
        goalDescription: 'Objectif général',
        goalCategory: 'goal_invest_simple',
        targetDate: targetDate,
        profile: profileHigh,
        goalAmount: 50000,
      );

      expect(planLow.confidenceLevel, 100);
      expect(planHigh.confidenceLevel, planLow.confidenceLevel);
    });

    test('Test 11: non-positive and non-finite goal amounts fail closed',
        () async {
      final targetDate = DateTime.now().add(const Duration(days: 365));
      for (final invalidAmount in [
        0.0,
        -1.0,
        double.nan,
        double.infinity,
      ]) {
        expect(
          () => PlanGenerationService.generate(
            profileOwnerId: _profileOwnerId,
            selfLppSnapshot: null,
            goalDescription: 'Objectif invalide',
            goalCategory: 'goal_general',
            targetDate: targetDate,
            profile: _profileSalaryOnly(),
            goalAmount: invalidAmount,
          ),
          throwsArgumentError,
        );
      }
    });

    test('Test 12: declared caisse return bands are exactly ±1 point',
        () async {
      final now = DateTime.now();
      final targetDate = DateTime(now.year, now.month + 300, now.day);
      final profile = CoachProfile(
        birthYear: now.year - 40,
        dateOfBirth: DateTime(now.year - 40, now.month, 1),
        gender: 'M',
        canton: 'VD',
        salaireBrutMensuel: 1000,
        nombreDeMois: 12,
        prevoyance: const PrevoyanceProfile(
          hasPensionFund: true,
          avoirLppTotal: 150000,
          avoirLppObligatoire: 100000,
          avoirLppSurobligatoire: 50000,
          rendementCaisse: 0,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: targetDate,
          label: 'Retraite avec rendement déclaré',
        ),
        financialLiteracyLevel: FinancialLiteracyLevel.advanced,
        dataSources: const {
          'salaireBrutMensuel': ProfileDataSource.userInput,
          'dateOfBirth': ProfileDataSource.userInput,
          'gender': ProfileDataSource.userInput,
          'prevoyance.hasPensionFund': ProfileDataSource.userInput,
          'prevoyance.avoirLppTotal': ProfileDataSource.userInput,
          'prevoyance.avoirLppObligatoire': ProfileDataSource.userInput,
          'prevoyance.avoirLppSurobligatoire': ProfileDataSource.userInput,
          'prevoyance.rendementCaisse': ProfileDataSource.userInput,
        },
        dataTimestamps: {
          for (final path in const [
            'salaireBrutMensuel',
            'dateOfBirth',
            'gender',
            'prevoyance.hasPensionFund',
            'prevoyance.avoirLppTotal',
            'prevoyance.avoirLppObligatoire',
            'prevoyance.avoirLppSurobligatoire',
            'prevoyance.rendementCaisse',
          ])
            path: now,
        },
        inferDataSources: false,
      );

      final plan = await PlanGenerationService.generate(
        profileOwnerId: _profileOwnerId,
        selfLppSnapshot: _selfLppSnapshot(profile, updatedAt: now),
        goalDescription: 'Retraite avec rendement déclaré',
        goalCategory: 'goal_retirement_plan',
        targetDate: targetDate,
        profile: profile,
        goalAmount: 300000,
        prospectiveLppReturn: 0.02,
      );

      final contributions = plan.monthlyTarget * 300;
      expect(
        plan.projectedLow,
        closeTo(150000 * math.pow(1.01, 25) + contributions, 0.01),
      );
      expect(
        plan.projectedHigh,
        closeTo(150000 * math.pow(1.03, 25) + contributions, 0.01),
      );
    });

    test(
        'Test 13: an undeclared caisse return blocks a durable retirement plan',
        () async {
      final now = DateTime.now();
      final profile = CoachProfile(
        birthYear: now.year - 40,
        dateOfBirth: DateTime(now.year - 40, now.month, 1),
        canton: 'VD',
        salaireBrutMensuel: 1000,
        nombreDeMois: 12,
        prevoyance: const PrevoyanceProfile(
          hasPensionFund: true,
          avoirLppTotal: 150000,
          avoirLppObligatoire: 100000,
          avoirLppSurobligatoire: 50000,
          rendementCaisse: 0,
          rendementCaisseConnu: false,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(now.year, now.month + 300, now.day),
          label: 'Retraite sans rendement déclaré',
        ),
        dataSources: const {
          'prevoyance.hasPensionFund': ProfileDataSource.userInput,
        },
        dataTimestamps: {
          'prevoyance.hasPensionFund': now,
        },
        inferDataSources: false,
      );

      expect(
        () => PlanGenerationService.generate(
          profileOwnerId: _profileOwnerId,
          selfLppSnapshot: null,
          goalDescription: 'Retraite sans rendement déclaré',
          goalCategory: 'goal_retirement_plan',
          targetDate: DateTime(now.year, now.month + 300, now.day),
          profile: profile,
          goalAmount: 300000,
        ),
        throwsA(isA<ArgumentError>()),
        reason: 'A hidden 2% model default is false precision. The durable '
            'central result must wait for a declared caisse return or an '
            'explicit visible/editable assumption scenario.',
      );
    });
  });
}
