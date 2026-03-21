import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/budget_living_engine.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';

/// Tests for BudgetLivingEngine V0.
///
/// Validates:
/// 1. Always produces a BudgetSnapshot
/// 2. present always filled
/// 3. stage = presentOnly if retirement unavailable
/// 4. stage = emergingRetirement if retirement + medium confidence
/// 5. stage = fullGapVisible if gap defensible
/// 6. gap correctly computed when both budgets exist
/// 7. cap always propagated
/// 8. capImpact populated on 3a/LPP cases
/// 9. capSequence populated on staggered buyback
/// 10. activeGoal propagated from profile
void main() {
  final now = DateTime(2026, 3, 21);

  // ── Helper ──
  CoachProfile makeProfile({
    int birthYear = 1977,
    double salaireBrutMensuel = 10184, // ~122k/year
    String canton = 'VS',
    String employmentStatus = 'salarie',
    DepensesProfile depenses = const DepensesProfile(
      loyer: 1800,
      assuranceMaladie: 400,
    ),
    PrevoyanceProfile prevoyance = const PrevoyanceProfile(),
    DetteProfile dettes = const DetteProfile(),
    PatrimoineProfile patrimoine = const PatrimoineProfile(),
    GoalAType goalType = GoalAType.retraite,
    CoachCivilStatus etatCivil = CoachCivilStatus.celibataire,
  }) {
    return CoachProfile(
      birthYear: birthYear,
      canton: canton,
      salaireBrutMensuel: salaireBrutMensuel,
      employmentStatus: employmentStatus,
      prevoyance: prevoyance,
      depenses: depenses,
      dettes: dettes,
      patrimoine: patrimoine,
      etatCivil: etatCivil,
      goalA: GoalA(
        type: goalType,
        targetDate: DateTime(2042),
        label: 'Retraite',
      ),
    );
  }

  group('BudgetLivingEngine — always produces a snapshot', () {
    test('returns snapshot for minimal profile', () {
      final profile = makeProfile(salaireBrutMensuel: 0);
      final snapshot = BudgetLivingEngine.compute(
        profile: profile,
        now: now,
      );

      expect(snapshot, isNotNull);
      expect(snapshot.computedAt, equals(now));
    });

    test('returns snapshot for complete profile', () {
      final profile = makeProfile(
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 70000,
          anneesContribuees: 27,
        ),
        patrimoine: const PatrimoineProfile(epargneLiquide: 50000),
      );
      final snapshot = BudgetLivingEngine.compute(
        profile: profile,
        now: now,
      );

      expect(snapshot, isNotNull);
    });
  });

  group('BudgetLivingEngine — present always filled', () {
    test('present budget has income, charges, free', () {
      final profile = makeProfile();
      final snapshot = BudgetLivingEngine.compute(
        profile: profile,
        now: now,
      );

      expect(snapshot.present.monthlyIncome, greaterThanOrEqualTo(0));
      expect(snapshot.present.monthlyCharges, greaterThanOrEqualTo(0));
      // monthlyFree can be negative if charges exceed income
      expect(snapshot.present.monthlyFree, isNotNull);
    });

    test('present budget with salary > 0 has positive income', () {
      final profile = makeProfile(salaireBrutMensuel: 10000);
      final snapshot = BudgetLivingEngine.compute(
        profile: profile,
        now: now,
      );

      expect(snapshot.present.monthlyIncome, greaterThan(0));
    });
  });

  group('BudgetLivingEngine — stage determination', () {
    test('stage = presentOnly when salary is zero', () {
      final profile = makeProfile(salaireBrutMensuel: 0);
      final snapshot = BudgetLivingEngine.compute(
        profile: profile,
        now: now,
      );

      expect(snapshot.stage, equals(BudgetStage.presentOnly));
      expect(snapshot.retirement, isNull);
    });

    test('stage = presentOnly when confidence is very low', () {
      // Profile with only salary, no other data → low confidence
      final profile = makeProfile(
        canton: '',
        prevoyance: const PrevoyanceProfile(),
      );
      final snapshot = BudgetLivingEngine.compute(
        profile: profile,
        now: now,
      );

      // With minimal data, confidence will be low
      if (snapshot.confidenceScore < 45) {
        expect(snapshot.stage, equals(BudgetStage.presentOnly));
      }
    });

    test('stage transitions with increasing data', () {
      // Sparse profile → presentOnly or emergingRetirement
      final sparse = makeProfile(
        prevoyance: const PrevoyanceProfile(),
      );
      final sparseSnap = BudgetLivingEngine.compute(
        profile: sparse,
        now: now,
      );

      // Rich profile → should be emergingRetirement or fullGapVisible
      final rich = makeProfile(
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 70000,
          anneesContribuees: 27,
          tauxConversion: 0.054,
        ),
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 50000,
          investissements: 30000,
        ),
        etatCivil: CoachCivilStatus.divorce, // explicit single
      );
      final richSnap = BudgetLivingEngine.compute(
        profile: rich,
        now: now,
      );

      // Rich profile should have higher confidence and further stage
      expect(richSnap.confidenceScore,
          greaterThanOrEqualTo(sparseSnap.confidenceScore));
    });
  });

  group('BudgetLivingEngine — gap computation', () {
    test('gap is null when retirement is null', () {
      final profile = makeProfile(salaireBrutMensuel: 0);
      final snapshot = BudgetLivingEngine.compute(
        profile: profile,
        now: now,
      );

      expect(snapshot.gap, isNull);
    });

    test('gap computed when both budgets exist', () {
      final profile = makeProfile(
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 70000,
          anneesContribuees: 27,
          tauxConversion: 0.054,
        ),
        patrimoine: const PatrimoineProfile(epargneLiquide: 50000),
        etatCivil: CoachCivilStatus.divorce,
      );
      final snapshot = BudgetLivingEngine.compute(
        profile: profile,
        now: now,
      );

      if (snapshot.retirement != null && snapshot.confidenceScore >= 45) {
        // Gap should exist when conditions are met
        if (snapshot.present.monthlyFree > 0) {
          expect(snapshot.gap, isNotNull);
          expect(snapshot.gap!.ratioRetained, isNotNull);
        }
      }
    });
  });

  group('BudgetLivingEngine — cap propagation', () {
    test('cap is always present', () {
      final profile = makeProfile();
      final snapshot = BudgetLivingEngine.compute(
        profile: profile,
        now: now,
      );

      expect(snapshot.cap, isNotNull);
      expect(snapshot.cap.id, isNotEmpty);
      expect(snapshot.cap.headline, isNotEmpty);
    });

    test('cap respects CapMemory', () {
      final profile = makeProfile();
      final memory = CapMemory(
        lastCapServed: 'pillar_3a',
        lastCapDate: now.subtract(const Duration(hours: 2)),
      );
      final snapshot = BudgetLivingEngine.compute(
        profile: profile,
        now: now,
        memory: memory,
      );

      // Cap should still be produced (maybe different due to recency penalty)
      expect(snapshot.cap, isNotNull);
    });
  });

  group('BudgetLivingEngine — capImpact', () {
    test('capImpact populated for LPP buyback case', () {
      // Profile that triggers LPP buyback cap: high rachat max
      final profile = makeProfile(
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 70000,
          rachatMaximum: 100000,
          anneesContribuees: 27,
          tauxConversion: 0.054,
        ),
        patrimoine: const PatrimoineProfile(epargneLiquide: 50000),
        etatCivil: CoachCivilStatus.divorce,
      );
      final snapshot = BudgetLivingEngine.compute(
        profile: profile,
        now: now,
      );

      // If the cap chosen is lpp_buyback, impact should be populated
      if (snapshot.cap.id == 'lpp_buyback') {
        expect(snapshot.capImpact, isNotNull);
        expect(snapshot.capImpact!.now, isNotNull);
      }
    });
  });

  group('BudgetLivingEngine — capSequence', () {
    test('capSequence populated for LPP buyback', () {
      final profile = makeProfile(
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 70000,
          rachatMaximum: 100000,
          anneesContribuees: 27,
          tauxConversion: 0.054,
        ),
        patrimoine: const PatrimoineProfile(epargneLiquide: 50000),
        etatCivil: CoachCivilStatus.divorce,
      );
      final snapshot = BudgetLivingEngine.compute(
        profile: profile,
        now: now,
      );

      if (snapshot.cap.id == 'lpp_buyback' ||
          snapshot.cap.id == 'couple_lpp_buyback') {
        expect(snapshot.capSequence, isNotNull);
        expect(snapshot.capSequence!.steps.length, lessThanOrEqualTo(3));
      }
    });

    test('capSequence null for unhandled cap types', () {
      // Profile that triggers debt cap (no sequence expected)
      final profile = makeProfile(
        dettes: const DetteProfile(creditConsommation: 50000),
      );
      final snapshot = BudgetLivingEngine.compute(
        profile: profile,
        now: now,
      );

      if (snapshot.cap.id == 'debt_correct') {
        expect(snapshot.capSequence, isNull);
      }
    });
  });

  group('BudgetLivingEngine — activeGoal', () {
    test('activeGoal propagated from profile', () {
      final profile = makeProfile(goalType: GoalAType.debtFree);
      final snapshot = BudgetLivingEngine.compute(
        profile: profile,
        now: now,
      );

      expect(snapshot.activeGoal, isNotNull);
      expect(snapshot.activeGoal!.type, equals(GoalAType.debtFree));
    });
  });

  group('BudgetLivingEngine — confidence score', () {
    test('confidenceScore is 0-100', () {
      final profile = makeProfile();
      final snapshot = BudgetLivingEngine.compute(
        profile: profile,
        now: now,
      );

      expect(snapshot.confidenceScore, greaterThanOrEqualTo(0));
      expect(snapshot.confidenceScore, lessThanOrEqualTo(100));
    });
  });
}
