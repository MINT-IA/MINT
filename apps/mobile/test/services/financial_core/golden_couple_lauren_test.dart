import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/financial_core/avs_thirteenth_pension_calculator.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

import 'avs_couple_test_fixtures.dart';

/// Golden Couple — Lauren tests.
///
/// Lauren: born 1982, age 43, salary 67'000 CHF/an, canton VS,
/// archetype expat_us, LPP avoir 19'620, arrival ~age 22.
/// Ref: CLAUDE.md § 8 GOLDEN TEST COUPLE.
void main() {
  // ═══════════════════════════════════════════════════════════════
  //  Lauren constants
  // ═══════════════════════════════════════════════════════════════
  const laurenAge = 43;
  const laurenSalary = 67000.0;
  const laurenCanton = 'VS';
  const laurenLppAvoir = 19620.0;
  const retirementAge = 65;

  group('Golden Couple — Lauren AVS', () {
    test('2. Lauren + Julien married couple → capped at 3780', () {
      const julienOfficialRente = 2520.0;
      const laurenOfficialRente = 2150.0;
      final couple = officialScale44AvsCouple(
        selfPension: julienOfficialRente,
        partnerPension: laurenOfficialRente,
        legalStatus: AvsCoupleLegalStatus.married,
      );
      // Combined individual rentes > 3780 → married cap applies
      expect(
        couple.rawHouseholdMonthlyPension,
        equals(julienOfficialRente + laurenOfficialRente),
      );
      expect(
        couple.householdMonthlyPension,
        equals(avsRenteCoupleMaxMensuelle),
      );
      expect(couple.householdMonthlyPension, equals(3780));
      // Proportional reduction
      expect(
        couple.self.cappedMonthlyPension,
        lessThan(julienOfficialRente),
      );
      expect(
        couple.partner.cappedMonthlyPension,
        lessThan(laurenOfficialRente),
      );
    });

    test('3. Lauren + Julien concubin → no cap, full individual rentes', () {
      const julienOfficialRente = 2520.0;
      const laurenOfficialRente = 2150.0;
      final couple = officialScale44AvsCouple(
        selfPension: julienOfficialRente,
        partnerPension: laurenOfficialRente,
        legalStatus: AvsCoupleLegalStatus.cohabiting,
      );
      // No married cap → raw and payable household amounts are identical.
      expect(
        couple.rawHouseholdMonthlyPension,
        equals(julienOfficialRente + laurenOfficialRente),
      );
      expect(
        couple.householdMonthlyPension,
        greaterThan(avsRenteCoupleMaxMensuelle),
      );
      expect(couple.self.cappedMonthlyPension, equals(julienOfficialRente));
      expect(
        couple.partner.cappedMonthlyPension,
        equals(laurenOfficialRente),
      );
    });
  });

  group('Golden Couple — Lauren LPP', () {
    test('4. Lauren LPP projection to 65', () {
      // Lauren: 43yo, salary 67k, avoir 19620, standard caisse return ~1.25%
      final annualRente = LppCalculator.projectToRetirement(
        currentBalance: laurenLppAvoir,
        currentAge: laurenAge,
        retirementAge: retirementAge,
        grossAnnualSalary: laurenSalary,
        caisseReturn: lppTauxInteretMin / 100, // 1.25%
        conversionRate: lppTauxConversionMinDecimal, // 6.8%
      );
      // Lauren has 22 years to retirement with 67k salary
      // Salaire coordonne = 67000 - 26460 = 40540, clamped [3780, 64260] = 40540
      // Bonif age 43 = 10% → annual bonif ~4054
      // Rough estimate: 19620 grows + 22 years of bonifications
      // Expected ~153'000 projected balance → ~10'404 annual rente
      expect(annualRente, greaterThan(5000));
      expect(annualRente, lessThan(20000));
      // Cross-check: CLAUDE.md says Lauren projected ~153k balance
      // 153000 * 0.068 ≈ 10404 annual rente
      final impliedBalance = annualRente / lppTauxConversionMinDecimal;
      expect(impliedBalance, greaterThan(100000));
      expect(impliedBalance, lessThan(200000));
    });
  });

  group('Golden Couple — Lauren Tax', () {
    test('5. Lauren capital tax VS unmarried', () {
      // Lauren withdraws ~19620 at current balance (small amount)
      final tax = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: laurenLppAvoir,
        canton: laurenCanton,
        isMarried: false,
      );
      // VS base rate = 6.0%, bracket 0-100k = 1.0x
      // 19620 * 0.06 * 1.0 = 1177.2
      expect(tax, closeTo(19620 * 0.06 * 1.0, 1));
    });

    test('6. Lauren capital tax VS married → ~15% discount', () {
      final taxSingle = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: laurenLppAvoir,
        canton: laurenCanton,
        isMarried: false,
      );
      final taxMarried = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: laurenLppAvoir,
        canton: laurenCanton,
        isMarried: true,
      );
      // Audit 2026-04-18 Q5 : coefficient marié par canton.
      // Lauren = VS → 0.81 (pas 0.85 uniforme).
      expect(
        taxMarried,
        closeTo(taxSingle * marriedCapitalTaxDiscountFor(laurenCanton), 0.01),
      );
      expect(taxMarried, lessThan(taxSingle));
    });

    test('7. Lauren retroactive 3a 1-year deduction tax saving', () {
      // Lauren can deduct 7258 CHF (1 year of 3a with LPP)
      final saving = RetirementTaxCalculator.estimateTaxSaving(
        income: laurenSalary,
        deduction: pilier3aPlafondAvecLpp,
        canton: laurenCanton,
      );
      // VS effective 14.56% × income adj ~0.87 × 1.3 marginal ≈ 16.5%
      // Saving ≈ 7258 * 0.165 ≈ 1'198
      expect(saving, greaterThan(700));
      expect(saving, lessThan(2000));
    });

    test('8. Lauren marginal tax rate VS at 67k', () {
      final rate = RetirementTaxCalculator.estimateMarginalRate(
        laurenSalary,
        laurenCanton,
      );
      // VS effective 14.56% × income adj ~0.87 × 1.3 ≈ 0.165
      expect(rate, greaterThan(0.14));
      expect(rate, lessThan(0.20));
    });
  });

  group('Golden Couple — Lauren Net Income & Annual Rente', () {
    test('9. Lauren net income breakdown at 67k', () {
      final breakdown = NetIncomeBreakdown.compute(
        grossSalary: laurenSalary,
        canton: laurenCanton,
        age: laurenAge,
      );
      // Social charges: 67000 * 0.064 = 4288
      expect(breakdown.socialCharges,
          closeTo(laurenSalary * cotisationsSalarieTotal, 1));
      // LPP employee: salaire coord (40540) * bonif 10% / 2 = 2027
      expect(breakdown.lppEmployee, greaterThan(1500));
      expect(breakdown.lppEmployee, lessThan(3000));
      // Net payslip = gross - social - LPP employee
      expect(breakdown.netPayslip, greaterThan(55000));
      expect(breakdown.netPayslip, lessThan(65000));
      // Net ratio should be ~0.88-0.93 (before income tax)
      expect(breakdown.netRatio, greaterThan(0.85));
      expect(breakdown.netRatio, lessThan(0.95));
    });

    test('10. Typed monthly AVS input keeps the 13th separate', () {
      const scenarioMonthly = ChfAmount.fromCents(213728);
      final supplement = AvsThirteenthPensionCalculator.calculate(
        AvsThirteenthPensionInput.fullYearScenario(
          ownerId: 'golden-lauren',
          calendarYear: 2026,
          determiningMonthlyOldAgePensionChf: scenarioMonthly,
          sourceDate: DateTime.utc(2026, 12, 1),
          calculationDate: DateTime.utc(2026, 12, 15),
          legalYear: AvsThirteenthPensionCalculator.supportedLegalYear,
          ruleVersion: AvsThirteenthPensionCalculator.supportedRuleVersion,
          scenarioRef: 'golden-lauren-full-year',
        ),
      );

      expect(scenarioMonthly.cents, 213728);
      expect(supplement.ownerId, 'golden-lauren');
      expect(
        supplement.readiness,
        AvsThirteenthReadiness.illustrativeOnly,
      );
      expect(supplement.certifiedThirteenthPensionChf, isNull);
      expect(supplement.eligibleOldAgePensionsPaidChf?.cents, 2564736);
      expect(
        supplement.monthlyAccrualPartsChf.map((part) => part?.cents),
        everyElement(17811),
      );
      expect(supplement.educationalEstimateChf?.cents, 213700);
      expect(
        supplement.eligibleOldAgeCashflowWithSupplementChf?.cents,
        2778436,
      );
    });
  });
}
