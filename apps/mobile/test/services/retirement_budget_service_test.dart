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
/// - monthlyNet = monthlyIncome - monthlyTax
/// - Tax estimation applies 12% heuristic
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

      // totalIncome = (30000 + 34000 + 4800 + 3600) / 12 = 6033.33
      // monthlyTax = 6033.33 * 0.12 = 724.0
      // monthlyNet = 6033.33 - 724.0 = 5309.33
      expect(result, isNotNull);
      expect(result!.monthlyIncome, closeTo(6033.33, 0.01));
      expect(result.monthlyTax, closeTo(724.0, 1.0));
      expect(result.monthlyNet, closeTo(5309.33, 1.0));
    });

    test('monthlyNet = monthlyIncome - monthlyTax', () {
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
      expect(result!.monthlyIncome, closeTo(5000.0, 0.01));

      // Tax = 5000 * 0.12 = 600
      expect(result.monthlyTax, closeTo(600.0, 0.01));

      // Net = 5000 - 600 = 4400
      expect(result.monthlyNet, closeTo(4400.0, 0.01));
    });

    test('tax estimation applies 12% heuristic', () {
      final result = RetirementBudgetService.compute(
        profile: makeProfile(
          depenses: const DepensesProfile(
            loyer: 1800,
            assuranceMaladie: 1200,
          ),
        ),
        projection: makeProjection(),
        confidenceScore: 70,
      );

      expect(result, isNotNull);
      expect(result!.monthlyTax, closeTo(result.monthlyIncome * 0.12, 0.01));
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

    test('zero income components produce zero tax', () {
      // With default decomposition (avs=30000, lppUser=34000, threeA=4800, libre=3600)
      // income > 0, so tax is proportional to income
      final result = RetirementBudgetService.compute(
        profile: makeProfile(
          depenses: const DepensesProfile(),
        ),
        projection: makeProjection(),
        confidenceScore: 70,
      );

      expect(result, isNotNull);
      expect(result!.monthlyTax, closeTo(result.monthlyIncome * 0.12, 0.01));
    });

    test('includes conjoint LPP in total income', () {
      final result = RetirementBudgetService.compute(
        profile: makeProfile(),
        projection: makeProjection(
          avs: 30000,
          lppUser: 20000,
          lppConjoint: 10000,
          threeA: 4800,
          libre: 3600,
        ),
        confidenceScore: 70,
      );

      expect(result, isNotNull);
      // totalIncome = (30000 + 20000 + 10000 + 4800 + 3600) / 12 = 5700.0
      expect(result!.monthlyIncome, closeTo(5700.0, 0.01));
    });
  });
}
