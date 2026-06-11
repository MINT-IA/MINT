import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
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

    test('replacementRate uses NET income as denominator (canonical, W1 lock)',
        () {
      const age = 50;
      const gross = 100000.0;
      const canton = 'ZH';
      final result = MinimalProfileService.compute(
        age: age,
        grossSalary: gross,
        canton: canton,
      );
      // Dénominateur canonique = revenu NET (NetIncomeBreakdown), plus le brut.
      // Champ conservé en fraction (0-1) — percent / 100.
      final net = NetIncomeBreakdown.compute(
        grossSalary: gross,
        canton: canton,
        age: age,
      ).monthlyNetPayslip;
      final expectedFraction =
          result.totalMonthlyRetirement / net; // NET, pas grossMonthlySalary
      expect(result.replacementRate, closeTo(expectedFraction, 0.001));
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

    test('monthlyDebtImpact surfaced but NOT subtracted from retirement (W1)',
        () {
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

      // Le service de dette reste exposé pour l'affichage budget…
      expect(withDebt.monthlyDebtImpact, equals(500.0));
      expect(withoutDebt.monthlyDebtImpact, equals(0.0));
      // …mais n'est PLUS soustrait du revenu de retraite (composition canonique
      // AVS + LPP). Le revenu de retraite est identique avec ou sans dette.
      expect(
        withDebt.totalMonthlyRetirement,
        closeTo(withoutDebt.totalMonthlyRetirement, 0.01),
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

      // Le service de dette explicite (200) prime sur l'estimation depuis
      // totalDebts (100000 × 0.005 = 500). La priorité s'observe désormais sur
      // monthlyDebtImpact (donnée budget surfacée), plus sur le revenu de
      // retraite : la dette n'est plus soustraite du revenu de retraite (W1).
      expect(result.monthlyDebtImpact, closeTo(200.0, 0.01));
      expect(resultOnlyTotal.monthlyDebtImpact, closeTo(500.0, 0.01));
      expect(
        result.monthlyDebtImpact,
        lessThan(resultOnlyTotal.monthlyDebtImpact),
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

    test('independant sans LPP: LPP rente = 0, 3a plafond = min(20% NET, 36288) (OPP3 art. 7 al. 2)', () {
      // OPP3 art. 7 al. 2 : le plafond porte sur le revenu professionnel NET,
      // PAS sur le brut nu (finding independent_no_lpp-1). Base nette canonique
      // = NetIncomeBreakdown (canton + âge aware).
      double expectedCeiling(double gross, int age) {
        final net = NetIncomeBreakdown.compute(
          grossSalary: gross,
          canton: 'GE',
          age: age,
        ).netPayslip;
        return (net * pilier3aTauxRevenuSansLpp)
            .clamp(0.0, pilier3aPlafondSansLpp);
      }

      // With 200k gross: 20% du NET reste > 36288 → capped at 36288.
      final resultHigh = MinimalProfileService.compute(
        age: 45,
        grossSalary: 200000,
        canton: 'GE',
        employmentStatus: 'independant',
      );
      expect(resultHigh.lppMonthlyRente, equals(0.0),
          reason: 'Independant sans LPP has no LPP rente');
      expect(resultHigh.plafond3a, closeTo(expectedCeiling(200000, 45), 0.01),
          reason: 'High earner independant : 20% du NET, capped 36288 CHF');

      // With 100k gross: 20% du NET < 36288 → plafond = 20% du NET (< 20000).
      final resultLow = MinimalProfileService.compute(
        age: 45,
        grossSalary: 100000,
        canton: 'GE',
        employmentStatus: 'independant',
      );
      expect(resultLow.lppMonthlyRente, equals(0.0));
      expect(resultLow.plafond3a, closeTo(expectedCeiling(100000, 45), 0.01),
          reason: '20% du NET de 100k brut (< 20000 = 20% du brut)');
      // Régression : le plafond ne doit plus être 20% du BRUT (20000).
      expect(resultLow.plafond3a, isNot(closeTo(20000, 0.01)),
          reason: 'plus jamais sur le brut nu (independent_no_lpp-1)');
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

    test('taxSaving3a uses canonical 3a tax-impact estimate', () {
      final result = MinimalProfileService.compute(
        age: 40,
        grossSalary: 80000,
        canton: 'VD',
        employmentStatus: 'salarie',
      );
      final expected = RetirementTaxCalculator.estimate3aTaxImpact(
        grossAnnualSalary: 80000,
        canton: 'VD',
      );

      expect(result.taxSaving3a, closeTo(expected.estimatedTaxSaving, 0.01));
      expect(result.marginalTaxRate, closeTo(expected.marginalRate, 0.0001));
    });

    test('taxSaving3a is suppressed when canton or salary is invalid', () {
      for (final canton in ['', 'CH', 'ZZ']) {
        final result = MinimalProfileService.compute(
          age: 40,
          grossSalary: 80000,
          canton: canton,
          employmentStatus: 'salarie',
        );

        expect(result.taxSaving3a, 0);
        expect(result.marginalTaxRate, 0);
      }

      final noSalary = MinimalProfileService.compute(
        age: 40,
        grossSalary: 0,
        canton: 'VD',
        employmentStatus: 'salarie',
      );
      expect(noSalary.taxSaving3a, 0);
      expect(noSalary.marginalTaxRate, 0);
    });

    test('independent no-LPP taxSaving3a uses 20% NET income ceiling (OPP3 art. 7 al. 2)', () {
      const gross = 50000.0;
      const canton = 'VD';
      const age = 45;
      final result = MinimalProfileService.compute(
        age: age,
        grossSalary: gross,
        canton: canton,
        employmentStatus: 'independant',
      );

      // Base nette canonique = NetIncomeBreakdown (plus le brut nu).
      final net = NetIncomeBreakdown.compute(
        grossSalary: gross,
        canton: canton,
        age: age,
      ).netPayslip;
      // minimal_profile passe ce NET dérivé à estimate3aTaxImpact.
      final expected = RetirementTaxCalculator.estimate3aTaxImpact(
        grossAnnualSalary: gross,
        canton: canton,
        hasLpp: false,
        netProfessionalIncome: net,
        age: age,
      );
      final expectedCeiling =
          (net * pilier3aTauxRevenuSansLpp).clamp(0.0, pilier3aPlafondSansLpp);

      expect(result.plafond3a, closeTo(expectedCeiling, 0.01),
          reason: 'plafond = 20% du NET, plus 20% du brut (10000)');
      // Régression : le plafond ne doit plus être 20% du BRUT (10000).
      expect(result.plafond3a, isNot(closeTo(10000, 0.01)),
          reason: 'plus jamais sur le brut nu (independent_no_lpp-1)');
      expect(result.taxSaving3a, closeTo(expected.estimatedTaxSaving, 0.01));
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
