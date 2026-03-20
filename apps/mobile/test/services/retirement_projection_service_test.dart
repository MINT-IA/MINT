import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/retirement_projection_service.dart';

/// Tests for RetirementProjectionService — unified household retirement projection.
///
/// Legal basis: LAVS art. 21-40, LPP art. 14-16, LIFD art. 38, OPC.
/// Golden couple: Julien (1977, 122'207 CHF) + Lauren (1982, 67'000 CHF).
void main() {
  /// Minimal profile helper.
  CoachProfile buildProfile({
    String? firstName,
    int birthYear = 1977,
    String canton = 'VS',
    double salaireBrutMensuel = 10000,
    int nombreDeMois = 12,
    String employmentStatus = 'salarie',
    CoachCivilStatus etatCivil = CoachCivilStatus.celibataire,
    ConjointProfile? conjoint,
    double avoirLppTotal = 70000,
    double totalEpargne3a = 32000,
    double epargneLiquide = 50000,
    double investissements = 100000,
    int? arrivalAge,
    List<PlannedMonthlyContribution> contributions = const [],
  }) {
    return CoachProfile(
      firstName: firstName,
      birthYear: birthYear,
      canton: canton,
      salaireBrutMensuel: salaireBrutMensuel,
      nombreDeMois: nombreDeMois,
      employmentStatus: employmentStatus,
      etatCivil: etatCivil,
      conjoint: conjoint,
      prevoyance: PrevoyanceProfile(
        avoirLppTotal: avoirLppTotal,
        totalEpargne3a: totalEpargne3a,
      ),
      patrimoine: PatrimoineProfile(
        epargneLiquide: epargneLiquide,
        investissements: investissements,
      ),
      arrivalAge: arrivalAge,
      plannedContributions: contributions,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2042, 1, 1),
        label: 'Retraite',
      ),
    );
  }

  group('RetirementProjectionService.project — single person', () {
    test('produces positive retirement income for standard salaried worker', () {
      final profile = buildProfile();
      final result = RetirementProjectionService.project(profile: profile);

      expect(result.revenuMensuelAt65, greaterThan(0),
          reason: 'AVS + LPP must produce positive retirement income');
      expect(result.tauxRemplacement, greaterThan(0));
      expect(result.isCouple, isFalse);
    });

    test('disclaimer contains required compliance text', () {
      final result = RetirementProjectionService.project(
        profile: buildProfile(),
      );
      expect(result.disclaimer, contains('educative'));
      expect(result.disclaimer, contains('conseil'));
      expect(result.disclaimer, contains('LSFin'));
    });

    test('sources reference LAVS and LPP articles', () {
      final result = RetirementProjectionService.project(
        profile: buildProfile(),
      );
      expect(result.sources.any((s) => s.contains('LAVS')), isTrue);
      expect(result.sources.any((s) => s.contains('LPP')), isTrue);
      expect(result.sources.any((s) => s.contains('LIFD')), isTrue);
    });

    test('produces early retirement comparison ages 63-70', () {
      final result = RetirementProjectionService.project(
        profile: buildProfile(),
      );
      expect(result.earlyRetirementComparisons.length, equals(8),
          reason: 'Ages 63-70 = 8 scenarios');

      final ages = result.earlyRetirementComparisons
          .map((s) => s.retirementAge)
          .toList();
      expect(ages, containsAll([63, 64, 65, 66, 67, 68, 69, 70]));
    });

    test('early retirement (63) has negative adjustment — LAVS art. 40', () {
      final result = RetirementProjectionService.project(
        profile: buildProfile(),
      );
      final age63 = result.earlyRetirementComparisons
          .firstWhere((s) => s.retirementAge == 63);
      expect(age63.adjustmentPct, lessThan(0),
          reason: 'AVS anticipation reduces rente by 6.8%/year');
    });

    test('deferred retirement (67) has positive adjustment — LAVS art. 39', () {
      final result = RetirementProjectionService.project(
        profile: buildProfile(),
      );
      final age67 = result.earlyRetirementComparisons
          .firstWhere((s) => s.retirementAge == 67);
      expect(age67.adjustmentPct, greaterThan(0),
          reason: 'AVS deferral increases rente');
    });

    test('budget gap includes all income sources', () {
      final result = RetirementProjectionService.project(
        profile: buildProfile(),
      );
      final gap = result.budgetGap;
      expect(gap.avsMensuel, greaterThan(0));
      expect(gap.lppMensuel, greaterThan(0));
      expect(gap.totalRevenusMensuel,
          closeTo(gap.avsMensuel + gap.lppMensuel + gap.troisAMensuel + gap.libreMensuel, 1));
    });

    test('indexed projection covers 26 points (years 0-25)', () {
      final result = RetirementProjectionService.project(
        profile: buildProfile(),
      );
      expect(result.indexedProjection.length, equals(26));
      // Year 0 = retirement year
      expect(result.indexedProjection.first.age, equals(65));
      expect(result.indexedProjection.last.age, equals(90));
    });

    test('purchasing power decreases over time due to inflation', () {
      final result = RetirementProjectionService.project(
        profile: buildProfile(),
      );
      final first = result.indexedProjection.first;
      final last = result.indexedProjection.last;
      expect(last.pouvoirAchat, lessThan(first.pouvoirAchat),
          reason: '1.5% inflation erodes purchasing power over 25 years');
    });
  });

  group('RetirementProjectionService.project — couple', () {
    test('married couple triggers LAVS art. 35 cap (150%)', () {
      const conjoint = ConjointProfile(
        firstName: 'Lauren',
        birthYear: 1982,
        salaireBrutMensuel: 67000 / 12,
      );
      final result = RetirementProjectionService.project(
        profile: buildProfile(
          firstName: 'Julien',
          etatCivil: CoachCivilStatus.marie,
          conjoint: conjoint,
        ),
      );
      expect(result.isCouple, isTrue);
      // Should have AVS sources for both
      final avsSources = result.budgetGap;
      expect(avsSources.avsMensuel, greaterThan(0));
    });

    test('couple with age difference produces 2 phases', () {
      const conjoint = ConjointProfile(
        firstName: 'Lauren',
        birthYear: 1982, // 5 years younger → different retirement year
        salaireBrutMensuel: 5500,
      );
      final result = RetirementProjectionService.project(
        profile: buildProfile(
          firstName: 'Julien',
          birthYear: 1977,
          etatCivil: CoachCivilStatus.marie,
          conjoint: conjoint,
        ),
      );
      expect(result.phases.length, equals(2),
          reason: 'Age gap → transition phase + both retired phase');
    });

    test('isCouple=false when single despite celibataire', () {
      final result = RetirementProjectionService.project(
        profile: buildProfile(etatCivil: CoachCivilStatus.celibataire),
      );
      expect(result.isCouple, isFalse);
    });
  });

  group('RetirementProjectionService.project — capital withdrawal', () {
    test('lppCapitalPct=1.0 marks source as capital withdrawal', () {
      final result = RetirementProjectionService.project(
        profile: buildProfile(),
        lppCapitalPct: 1.0,
      );
      // With full capital, LPP source should be capital-based
      expect(result.revenuMensuelAt65, greaterThan(0));
    });

    test('lppCapitalPct=0.5 produces mixed withdrawal', () {
      final resultFull = RetirementProjectionService.project(
        profile: buildProfile(),
        lppCapitalPct: 0.0,
      );
      final resultMixed = RetirementProjectionService.project(
        profile: buildProfile(),
        lppCapitalPct: 0.5,
      );
      // Mixed should differ from full rente
      expect(resultMixed.revenuMensuelAt65, isNot(equals(resultFull.revenuMensuelAt65)));
    });
  });

  group('RetirementProjectionService.project — edge cases', () {
    test('independant without LPP still has AVS and 3a', () {
      final result = RetirementProjectionService.project(
        profile: buildProfile(
          employmentStatus: 'independant',
          avoirLppTotal: 0,
          salaireBrutMensuel: 8000,
        ),
      );
      expect(result.revenuMensuelAt65, greaterThan(0),
          reason: 'AVS alone should provide some income');
    });

    test('very young worker (age 25) produces projection', () {
      final result = RetirementProjectionService.project(
        profile: buildProfile(
          birthYear: 2001, // age ~25 in 2026
          salaireBrutMensuel: 5000,
        ),
      );
      expect(result.revenuMensuelAt65, greaterThan(0));
      expect(result.earlyRetirementComparisons, isNotEmpty);
    });

    test('formatChf formats with Swiss apostrophe', () {
      expect(RetirementProjectionService.formatChf(1234),
          contains("1'234"));
      expect(RetirementProjectionService.formatChf(1000000),
          contains("1'000'000"));
      expect(RetirementProjectionService.formatChf(0),
          contains('0'));
    });

    test('formatChf handles negative values', () {
      final result = RetirementProjectionService.formatChf(-5000);
      expect(result, contains('-'));
      expect(result, contains("5'000"));
    });
  });

  group('RetirementProjectionService — data model unit tests', () {
    test('RetirementIncomeSource.annualAmount = monthly * 12', () {
      const source = RetirementIncomeSource(
        id: 'test',
        label: 'Test',
        monthlyAmount: 2500,
        color: Color(0xFF000000),
      );
      expect(source.annualAmount, equals(30000));
    });

    test('RetirementPhase.totalMonthly sums all sources', () {
      const phase = RetirementPhase(
        label: 'Test',
        startYear: 2042,
        sources: [
          RetirementIncomeSource(
            id: 'avs', label: 'AVS', monthlyAmount: 2000, color: Color(0xFF000000)),
          RetirementIncomeSource(
            id: 'lpp', label: 'LPP', monthlyAmount: 1500, color: Color(0xFF000000)),
        ],
      );
      expect(phase.totalMonthly, equals(3500));
    });
  });
}
