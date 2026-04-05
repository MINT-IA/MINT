import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/retirement_budget_service.dart';

/// Tests for RetirementBudgetService V0.
///
/// Validates:
/// - Returns null when projection is absent
/// - Returns null when confidence < 45
/// - Returns null when salary is zero
/// - Computes a simple budget with AVS + LPP + 3a
/// - monthlyFree = total income - charges
/// - Charges use 0.80 heuristic on current expenses
/// - Remains prudent when certificate absent
void main() {
  // ── Helper to build a profile ──
  CoachProfile makeProfile({
    int birthYear = 1977,
    double salaireBrutMensuel = 10184, // ~122k/year
    String canton = 'VS',
    DepensesProfile depenses = const DepensesProfile(),
    PrevoyanceProfile prevoyance = const PrevoyanceProfile(),
  }) {
    return CoachProfile(
      birthYear: birthYear,
      canton: canton,
      salaireBrutMensuel: salaireBrutMensuel,
      employmentStatus: 'salarie',
      prevoyance: prevoyance,
      depenses: depenses,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2042),
        label: 'Retraite',
      ),
    );
  }

  /// Build a minimal ProjectionResult with known decomposition.
  ProjectionResult makeProjection({
    double avs = 30000,
    double lppUser = 34000,
    double lppConjoint = 0,
    double threeA = 4800,
    double libre = 3600,
  }) {
    final decomposition = {
      'avs': avs,
      'lpp_user': lppUser,
      'lpp_conjoint': lppConjoint,
      '3a': threeA,
      'libre': libre,
    };
    return ProjectionResult(
      prudent: ProjectionScenario(
        label: 'Prudent',
        points: const [],
        capitalFinal: 500000,
        revenuAnnuelRetraite: 60000,
        decomposition: decomposition,
      ),
      base: ProjectionScenario(
        label: 'Base',
        points: const [],
        capitalFinal: 700000,
        revenuAnnuelRetraite: 72400,
        decomposition: decomposition,
      ),
      optimiste: ProjectionScenario(
        label: 'Optimiste',
        points: const [],
        capitalFinal: 900000,
        revenuAnnuelRetraite: 85000,
        decomposition: decomposition,
      ),
      tauxRemplacementBase: 65.0,
      milestones: const [],
      disclaimer: 'test',
      sources: const [],
      confidenceScore: 70,
    );
  }

  group('RetirementBudgetService — null guards', () {
    test('returns null when projection is null', () {
      final result = RetirementBudgetService.compute(
        profile: makeProfile(),
        projection: null,
        confidenceScore: 80,
      );
      expect(result, isNull);
    });

    test('returns null when confidence < 45', () {
      final result = RetirementBudgetService.compute(
        profile: makeProfile(),
        projection: makeProjection(),
        confidenceScore: 30,
      );
      expect(result, isNull);
    });

    test('returns null when salary is zero', () {
      final result = RetirementBudgetService.compute(
        profile: makeProfile(salaireBrutMensuel: 0),
        projection: makeProjection(),
        confidenceScore: 80,
      );
      expect(result, isNull);
    });
  });

  group('RetirementBudgetService — budget computation', () {
    test('computes simple budget with AVS + LPP + 3a', () {
      final result = RetirementBudgetService.compute(
        profile: makeProfile(),
        projection: makeProjection(
          avs: 30000,
          lppUser: 34000,
          lppConjoint: 0,
          threeA: 4800,
          libre: 3600,
        ),
        confidenceScore: 70,
      );

      expect(result, isNotNull);
      expect(result!.avsMonthly, closeTo(2500.0, 0.01)); // 30000/12
      expect(result.lppMonthly, closeTo(2833.33, 0.01)); // 34000/12
      expect(result.pillar3aMonthly, closeTo(400.0, 0.01)); // 4800/12
      expect(result.otherMonthly, closeTo(300.0, 0.01)); // 3600/12
    });

    test('monthlyFree = total income - charges', () {
      final result = RetirementBudgetService.compute(
        profile: makeProfile(
          depenses: const DepensesProfile(
            loyer: 1800,
            assuranceMaladie: 400,
          ),
        ),
        projection: makeProjection(
          avs: 30000,
          lppUser: 24000,
          threeA: 3600,
          libre: 2400,
        ),
        confidenceScore: 70,
      );

      expect(result, isNotNull);

      // Total income = (30000 + 24000 + 3600 + 2400) / 12 = 5000
      final totalIncome = result!.avsMonthly +
          result.lppMonthly +
          result.pillar3aMonthly +
          result.otherMonthly;
      expect(totalIncome, closeTo(5000.0, 0.01));

      // Charges = (1800 + 400) * 0.80 = 1760
      expect(result.monthlyCharges, closeTo(1760.0, 0.01));

      // Free = 5000 - 1760 = 3240
      expect(result.monthlyFree, closeTo(3240.0, 0.01));
    });

    test('applies 0.80 heuristic on current charges', () {
      const currentCharges = 3000.0;
      final result = RetirementBudgetService.compute(
        profile: makeProfile(
          depenses: const DepensesProfile(
            loyer: 1800, // currentCharges * 0.6
            assuranceMaladie: 1200, // currentCharges * 0.4
          ),
        ),
        projection: makeProjection(),
        confidenceScore: 70,
      );

      expect(result, isNotNull);
      expect(result!.monthlyCharges, closeTo(currentCharges * 0.80, 0.01));
    });

    test('confidence at threshold 45 still computes', () {
      final result = RetirementBudgetService.compute(
        profile: makeProfile(),
        projection: makeProjection(),
        confidenceScore: 45,
      );
      expect(result, isNotNull);
    });

    test('confidence at 44 returns null', () {
      final result = RetirementBudgetService.compute(
        profile: makeProfile(),
        projection: makeProjection(),
        confidenceScore: 44,
      );
      expect(result, isNull);
    });

    test('zero current charges produces zero retirement charges', () {
      final result = RetirementBudgetService.compute(
        profile: makeProfile(
          depenses: const DepensesProfile(),
        ),
        projection: makeProjection(),
        confidenceScore: 70,
      );

      expect(result, isNotNull);
      expect(result!.monthlyCharges, equals(0.0));
    });

    test('includes conjoint LPP in total', () {
      final result = RetirementBudgetService.compute(
        profile: makeProfile(),
        projection: makeProjection(
          avs: 30000,
          lppUser: 20000,
          lppConjoint: 10000,
        ),
        confidenceScore: 70,
      );

      expect(result, isNotNull);
      // lppMonthly = (20000 + 10000) / 12 = 2500
      expect(result!.lppMonthly, closeTo(2500.0, 0.01));
    });
  });
}
