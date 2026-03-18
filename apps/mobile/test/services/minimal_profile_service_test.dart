import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/minimal_profile_service.dart';

/// Tests for MinimalProfileService (Sprint S31 — Onboarding Redesign).
///
/// Validates parity with backend compute_minimal_profile():
/// - Clamp: totalMonthlyRetirement >= 0 when debt > AVS+LPP
/// - Replacement ratio: retirement / grossMonthlySalary (not expenses)
/// - Retirement gap: grossMonthlySalary - retirement (not expenses)
/// - Debt priority: monthlyDebtService wins over totalDebts
/// - Employment archetypes: independant, sans_emploi
/// - LPP seuil d'entree (LPP art. 7): below threshold → no LPP
///
/// Golden profile: Julien (49, 122'207 CHF, VS).
void main() {
  group('MinimalProfileService — existing tests', () {
    test('clamp: totalMonthlyRetirement >= 0 when debt exceeds AVS+LPP', () {
      final result = MinimalProfileService.compute(
        age: 30,
        grossSalary: 50000,
        canton: 'ZH',
        monthlyDebtService: 5000,
      );

      expect(result.totalMonthlyRetirement, greaterThanOrEqualTo(0.0),
          reason: 'Retirement income must be clamped to >= 0 (parity backend)');
      expect(result.replacementRate, greaterThanOrEqualTo(0.0));
      expect(result.retirementGapMonthly, greaterThanOrEqualTo(0.0));
      if (result.totalMonthlyRetirement == 0.0) {
        expect(result.retirementGapMonthly, closeTo(50000 / 12, 0.01));
      }
    });

    test('replacementRate uses grossMonthlySalary as denominator', () {
      final result = MinimalProfileService.compute(
        age: 50,
        grossSalary: 100000,
        canton: 'ZH',
      );
      final expectedRate =
          result.totalMonthlyRetirement / result.grossMonthlySalary;
      expect(result.replacementRate, closeTo(expectedRate, 0.001));
    });

    test('retirementGapMonthly = grossMonthlySalary - retirement', () {
      final result = MinimalProfileService.compute(
        age: 45,
        grossSalary: 80000,
        canton: 'VD',
      );
      final expectedGap =
          result.grossMonthlySalary - result.totalMonthlyRetirement;
      expect(result.retirementGapMonthly,
          closeTo(expectedGap < 0 ? 0 : expectedGap, 0.01));
    });

    test('monthlyDebtImpact reflects debt subtracted from retirement', () {
      final withDebt = MinimalProfileService.compute(
        age: 45,
        grossSalary: 60000,
        canton: 'ZH',
        monthlyDebtService: 500,
      );
      final withoutDebt = MinimalProfileService.compute(
        age: 45,
        grossSalary: 60000,
        canton: 'ZH',
        monthlyDebtService: 0,
      );

      expect(withDebt.monthlyDebtImpact, equals(500.0));
      expect(withoutDebt.monthlyDebtImpact, equals(0.0));
      expect(
        withoutDebt.totalMonthlyRetirement - withDebt.totalMonthlyRetirement,
        closeTo(500.0, 0.01),
      );
    });

    test('debt priority: monthlyDebtService wins over totalDebts', () {
      final result = MinimalProfileService.compute(
        age: 50,
        grossSalary: 100000,
        canton: 'ZH',
        totalDebts: 100000,
        monthlyDebtService: 200,
      );
      final resultOnlyTotal = MinimalProfileService.compute(
        age: 50,
        grossSalary: 100000,
        canton: 'ZH',
        totalDebts: 100000,
      );

      expect(
        result.totalMonthlyRetirement,
        greaterThan(resultOnlyTotal.totalMonthlyRetirement),
        reason: 'monthlyDebtService=200 < totalDebts estimate=500',
      );
    });
  });

  group('MinimalProfileService — new tests', () {
    test('golden profile Julien: VS, 49yo, 122207 CHF annual', () {
      final result = MinimalProfileService.compute(
        age: 49,
        grossSalary: 122207,
        canton: 'VS',
      );

      expect(result.avsMonthlyRente, greaterThan(0));
      expect(result.lppMonthlyRente, greaterThan(0));
      expect(result.totalMonthlyRetirement, greaterThan(0));
      // Replacement rate for high earner should be below 100%
      expect(result.replacementRate, lessThan(1.0));
      expect(result.replacementRate, greaterThan(0.2),
          reason: 'Should have meaningful replacement rate');
      expect(result.canton, 'VS');
      expect(result.age, 49);
    });

    test('independant sans LPP: LPP rente = 0, 3a plafond = min(20% revenu, 36288) (OPP3 art. 7)', () {
      // With 200k salary: 20% = 40k > 36288 → capped at 36288
      final resultHigh = MinimalProfileService.compute(
        age: 45,
        grossSalary: 200000,
        canton: 'GE',
        employmentStatus: 'independant',
      );
      expect(resultHigh.lppMonthlyRente, equals(0.0),
          reason: 'Independant sans LPP has no LPP rente');
      expect(resultHigh.plafond3a, equals(pilier3aPlafondSansLpp),
          reason: 'High earner independant capped at 36288 CHF');

      // With 100k salary: 20% = 20k < 36288 → plafond = 20k
      final resultLow = MinimalProfileService.compute(
        age: 45,
        grossSalary: 100000,
        canton: 'GE',
        employmentStatus: 'independant',
      );
      expect(resultLow.lppMonthlyRente, equals(0.0));
      expect(resultLow.plafond3a, closeTo(20000, 0.01),
          reason: '20% of 100k = 20000 < 36288');
      expect(resultLow.employmentStatus, 'independant');
    });

    test('salaried worker: 3a plafond = 7258 (OPP3 art. 7)', () {
      final result = MinimalProfileService.compute(
        age: 40,
        grossSalary: 80000,
        canton: 'ZH',
        employmentStatus: 'salarie',
      );
      expect(result.plafond3a, equals(pilier3aPlafondAvecLpp));
    });

    test('sans_emploi: reduced AVS, no LPP contributions', () {
      final result = MinimalProfileService.compute(
        age: 50,
        grossSalary: 50000,
        canton: 'BE',
        employmentStatus: 'sans_emploi',
      );

      expect(result.lppMonthlyRente, equals(0.0),
          reason: 'Unemployed has no LPP');
      expect(result.avsMonthlyRente, greaterThan(0),
          reason: 'Even unemployed gets minimum AVS');
    });

    test('below LPP seuil: no LPP rente (LPP art. 7)', () {
      final result = MinimalProfileService.compute(
        age: 45,
        grossSalary: 20000, // Below lppSeuilEntree (22'680)
        canton: 'ZH',
      );
      expect(result.existingLpp, equals(0.0),
          reason: 'Below LPP seuil = 0 estimated LPP');
      expect(result.lppMonthlyRente, equals(0.0));
    });

    test('estimatedFields tracks which fields were estimated', () {
      final result = MinimalProfileService.compute(
        age: 40,
        grossSalary: 80000,
        canton: 'VD',
      );
      // With only 3 required fields, several should be estimated
      expect(result.estimatedFields, contains('householdType'));
      expect(result.estimatedFields, contains('isPropertyOwner'));
      expect(result.estimatedFields, contains('currentSavings'));
      expect(result.estimatedFields, contains('existing3a'));
      expect(result.estimatedFields, contains('existingLpp'));
    });

    test('provided fields reduce estimatedFields count', () {
      final result = MinimalProfileService.compute(
        age: 40,
        grossSalary: 80000,
        canton: 'VD',
        currentSavings: 50000,
        existingLpp: 100000,
        existing3a: 20000,
      );
      expect(result.estimatedFields, isNot(contains('currentSavings')));
      expect(result.estimatedFields, isNot(contains('existingLpp')));
      expect(result.estimatedFields, isNot(contains('existing3a')));
    });

    test('household type affects expense estimation', () {
      final single = MinimalProfileService.compute(
        age: 40,
        grossSalary: 100000,
        canton: 'ZH',
        householdType: 'single',
      );
      final family = MinimalProfileService.compute(
        age: 40,
        grossSalary: 100000,
        canton: 'ZH',
        householdType: 'family',
      );
      expect(family.estimatedMonthlyExpenses,
          greaterThan(single.estimatedMonthlyExpenses),
          reason: 'Family expenses > single');
    });

    test('couple household has lower expense ratio than family', () {
      final couple = MinimalProfileService.compute(
        age: 40,
        grossSalary: 100000,
        canton: 'ZH',
        householdType: 'couple',
      );
      final family = MinimalProfileService.compute(
        age: 40,
        grossSalary: 100000,
        canton: 'ZH',
        householdType: 'family',
      );
      expect(couple.estimatedMonthlyExpenses,
          lessThan(family.estimatedMonthlyExpenses));
    });

    test('targetRetirementAge affects LPP projection duration', () {
      final at65 = MinimalProfileService.compute(
        age: 45,
        grossSalary: 100000,
        canton: 'ZH',
        targetRetirementAge: 65,
      );
      final at63 = MinimalProfileService.compute(
        age: 45,
        grossSalary: 100000,
        canton: 'ZH',
        targetRetirementAge: 63,
      );
      // Less time to accumulate → lower LPP
      expect(at63.lppAnnualRente, lessThan(at65.lppAnnualRente),
          reason: '2 fewer years of LPP accumulation');
    });

    test('complementaire caisse type uses 5.8% conversion rate', () {
      final standard = MinimalProfileService.compute(
        age: 50,
        grossSalary: 100000,
        canton: 'ZH',
        existingLpp: 200000,
      );
      final complementaire = MinimalProfileService.compute(
        age: 50,
        grossSalary: 100000,
        canton: 'ZH',
        existingLpp: 200000,
        lppCaisseType: 'complementaire',
      );
      expect(complementaire.lppAnnualRente, lessThan(standard.lppAnnualRente),
          reason: 'Complementaire uses 5.8% vs 6.8% conversion');
    });
  });
}
