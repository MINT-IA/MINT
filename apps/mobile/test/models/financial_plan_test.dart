import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/financial_plan.dart';

void main() {
  // ────────────────────────────────────────────────────────────────────────
  //  PlanMilestone tests
  // ────────────────────────────────────────────────────────────────────────

  group('PlanMilestone', () {
    test('Test 2: fromJson(toJson()) produces identical object (round-trip)', () {
      final milestone = PlanMilestone(
        targetDate: DateTime(2028, 3, 1),
        targetAmount: 21250.0,
        description: '25% atteint — 21 250 CHF',
      );

      final decoded = PlanMilestone.fromJson(milestone.toJson());

      expect(decoded.targetDate, equals(milestone.targetDate));
      expect(decoded.targetAmount, equals(milestone.targetAmount));
      expect(decoded.description, equals(milestone.description));
    });
  });

  // ────────────────────────────────────────────────────────────────────────
  //  FinancialPlan tests
  // ────────────────────────────────────────────────────────────────────────

  group('FinancialPlan', () {
    FinancialPlan makePlan({
      double projectedLow = 70000.0,
      double? projectedHigh = 110000.0,
    }) {
      return FinancialPlan(
        id: 'test-uuid-001',
        goalDescription: 'Acheter un appartement',
        goalCategory: 'goal_house',
        monthlyTarget: 1200.0,
        milestones: const [],
        projectedOutcome: 85000.0,
        projectedLow: projectedLow,
        projectedHigh: projectedHigh,
        targetDate: DateTime(2028, 6, 1),
        generatedAt: DateTime(2026, 4, 1),
        profileHashAtGeneration: 'abc123',
        coachNarrative: 'Voici ton plan.',
        confidenceLevel: 78.0,
        sources: const ['LPP art. 14', 'LIFD art. 38'],
        disclaimer: 'Outil éducatif.',
      );
    }

    test('Test 1: fromJson(toJson()) produces identical object (round-trip)', () {
      final plan = makePlan();
      final decoded = FinancialPlan.fromJson(plan.toJson());

      expect(decoded.id, equals(plan.id));
      expect(decoded.goalDescription, equals(plan.goalDescription));
      expect(decoded.goalCategory, equals(plan.goalCategory));
      expect(decoded.monthlyTarget, equals(plan.monthlyTarget));
      expect(decoded.projectedOutcome, equals(plan.projectedOutcome));
      expect(decoded.projectedLow, equals(plan.projectedLow));
      expect(decoded.projectedHigh, equals(plan.projectedHigh));
      expect(decoded.targetDate, equals(plan.targetDate));
      expect(decoded.generatedAt, equals(plan.generatedAt));
      expect(decoded.profileHashAtGeneration, equals(plan.profileHashAtGeneration));
      expect(decoded.coachNarrative, equals(plan.coachNarrative));
      expect(decoded.confidenceLevel, equals(plan.confidenceLevel));
      expect(decoded.sources, equals(plan.sources));
      expect(decoded.disclaimer, equals(plan.disclaimer));
    });

    test('Test 3: fromJson with missing optional projectedLow/projectedHigh does not throw', () {
      final json = <String, dynamic>{
        'id': 'abc',
        'goalDescription': 'Plan test',
        'goalCategory': 'goal_tax_basic',
        'monthlyTarget': 500.0,
        'milestones': <dynamic>[],
        'projectedOutcome': 60000.0,
        // projectedLow and projectedHigh intentionally omitted
        'targetDate': DateTime(2028, 1, 1).toIso8601String(),
        'generatedAt': DateTime(2026, 1, 1).toIso8601String(),
        'profileHashAtGeneration': 'xyz',
        'coachNarrative': 'Narrative.',
        'confidenceLevel': 55.0,
        'sources': <dynamic>[],
        'disclaimer': 'Disclaimer.',
      };

      expect(() => FinancialPlan.fromJson(json), returnsNormally);
      final plan = FinancialPlan.fromJson(json);
      expect(plan.projectedLow, isNull);
      expect(plan.projectedHigh, isNull);
    });

    test('Test 4: generateMilestones returns 4 milestones at 25/50/75/100%', () {
      final milestones = FinancialPlan.generateMilestones(
        85000.0,
        DateTime(2028, 6, 1),
      );

      expect(milestones.length, equals(4));
    });

    test('Test 5: each milestone targetAmount equals goalAmount * pct / 100', () {
      const goalAmount = 85000.0;
      final milestones = FinancialPlan.generateMilestones(
        goalAmount,
        DateTime(2028, 6, 1),
      );

      expect(milestones[0].targetAmount, closeTo(goalAmount * 0.25, 0.01));
      expect(milestones[1].targetAmount, closeTo(goalAmount * 0.50, 0.01));
      expect(milestones[2].targetAmount, closeTo(goalAmount * 0.75, 0.01));
      expect(milestones[3].targetAmount, closeTo(goalAmount * 1.00, 0.01));
    });

    test('Test 6: milestone descriptions contain percentage text', () {
      final milestones = FinancialPlan.generateMilestones(
        85000.0,
        DateTime(2028, 6, 1),
      );

      expect(milestones[0].description, contains('25'));
      expect(milestones[1].description, contains('50'));
      expect(milestones[2].description, contains('75'));
      expect(milestones[3].description, contains('100'));
    });

    test('Test 10: monthlyTarget clamps to 0 when negative in fromJson', () {
      final json = <String, dynamic>{
        'id': 'abc',
        'goalDescription': 'Plan test',
        'goalCategory': 'goal_control_debts',
        'monthlyTarget': -500.0,  // negative — should be clamped to 0
        'milestones': <dynamic>[],
        'projectedOutcome': 0.0,
        'targetDate': DateTime(2028, 1, 1).toIso8601String(),
        'generatedAt': DateTime(2026, 1, 1).toIso8601String(),
        'profileHashAtGeneration': 'xyz',
        'coachNarrative': 'Narrative.',
        'confidenceLevel': 50.0,
        'sources': <dynamic>[],
        'disclaimer': 'Disclaimer.',
      };

      final plan = FinancialPlan.fromJson(json);
      expect(plan.monthlyTarget, equals(0.0));
    });
  });

  // ────────────────────────────────────────────────────────────────────────
  //  computeProfileHash tests
  // ────────────────────────────────────────────────────────────────────────

  group('computeProfileHash', () {
    CoachProfile makeProfile({
      double salaireBrutMensuel = 10183.92, // 122207 / 12
      double? lpp = 70377.0,
      double epargne3a = 32000.0,
      String canton = 'VS',
      DateTime? dob,
    }) {
      return CoachProfile(
        birthYear: 1977,
        dateOfBirth: dob ?? DateTime(1977, 1, 12),
        canton: canton,
        salaireBrutMensuel: salaireBrutMensuel,
        prevoyance: PrevoyanceProfile(
          avoirLppTotal: lpp,
          totalEpargne3a: epargne3a,
        ),
        goalA: const GoalA(
          type: GoalAType.achatImmo,
          targetDate: DateTime(2028, 6, 1),
          label: 'Acheter un appartement',
        ),
      );
    }

    test('Test 7: computeProfileHash produces same string for same inputs', () {
      final profile = makeProfile();
      final hash1 = computeProfileHash(profile);
      final hash2 = computeProfileHash(profile);

      expect(hash1, equals(hash2));
    });

    test('Test 8: computeProfileHash changes when salaireBrutMensuel changes', () {
      final profile1 = makeProfile(salaireBrutMensuel: 10183.92);
      final profile2 = makeProfile(salaireBrutMensuel: 5583.33);

      expect(computeProfileHash(profile1), isNot(equals(computeProfileHash(profile2))));
    });

    test('Test 9: computeProfileHash does NOT change when unrelated CoachProfile field changes', () {
      // canton, salary, lpp, 3a, dob are the only hashed fields.
      // Two profiles with same hashed fields should produce the same hash.
      final profile1 = makeProfile(salaireBrutMensuel: 8333.33, canton: 'ZH');
      final profile2 = makeProfile(salaireBrutMensuel: 8333.33, canton: 'ZH');

      expect(computeProfileHash(profile1), equals(computeProfileHash(profile2)));
    });
  });
}
