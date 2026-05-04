import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

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
  const laurenArrivalAge = 22;
  const retirementAge = 65;

  group('Golden Couple — Lauren AVS', () {
    test('1. Lauren AVS with arrival gap → reduced vs native', () {
      // Lauren arrived at ~22, so she has 43-22 = 21 current years
      // + 22 future years = 43/44 total. Slight gap vs native 44/44.
      final laurenRente = AvsCalculator.computeMonthlyRente(
        currentAge: laurenAge,
        retirementAge: retirementAge,
        arrivalAge: laurenArrivalAge,
        grossAnnualSalary: laurenSalary,
      );
      final nativeRente = AvsCalculator.computeMonthlyRente(
        currentAge: laurenAge,
        retirementAge: retirementAge,
        grossAnnualSalary: laurenSalary,
      );
      // arrivalAge 22 means current years = 43-22 = 21
      // native current years = 43-20 = 23
      // Both have future = 22
      // Lauren total: 21+22 = 43/44 ≈ 97.7%
      // Native total: 23+22 = 44/44 = 100%
      expect(laurenRente, lessThan(nativeRente));
      expect(laurenRente / nativeRente, closeTo(43 / 44, 0.02));
      // Lauren salary 67k is between RAMD min (14700) and max (88200)
      expect(laurenRente, greaterThan(avsRenteMinMensuelle * 0.9));
      expect(laurenRente, lessThan(avsRenteMaxMensuelle));
    });

    test('2. Lauren + Julien married couple → capped at 3780', () {
      final julienRente = AvsCalculator.computeMonthlyRente(
        currentAge: 49,
        retirementAge: retirementAge,
        grossAnnualSalary: 122207,
      );
      final laurenRente = AvsCalculator.computeMonthlyRente(
        currentAge: laurenAge,
        retirementAge: retirementAge,
        arrivalAge: laurenArrivalAge,
        grossAnnualSalary: laurenSalary,
      );
      final couple = AvsCalculator.computeCouple(
        avsUser: julienRente,
        avsConjoint: laurenRente,
        isMarried: true,
      );
      // Combined individual rentes > 3780 → married cap applies
      expect(couple.total, equals(avsRenteCoupleMaxMensuelle));
      expect(couple.total, equals(3780));
      // Proportional reduction
      expect(couple.user, lessThan(julienRente));
      expect(couple.conjoint, lessThan(laurenRente));
    });

    test('3. Lauren + Julien concubin → no cap, full individual rentes', () {
      final julienRente = AvsCalculator.computeMonthlyRente(
        currentAge: 49,
        retirementAge: retirementAge,
        grossAnnualSalary: 122207,
      );
      final laurenRente = AvsCalculator.computeMonthlyRente(
        currentAge: laurenAge,
        retirementAge: retirementAge,
        arrivalAge: laurenArrivalAge,
        grossAnnualSalary: laurenSalary,
      );
      final couple = AvsCalculator.computeCouple(
        avsUser: julienRente,
        avsConjoint: laurenRente,
        isMarried: false,
      );
      // No married cap → full individual rentes
      expect(couple.total, greaterThan(avsRenteCoupleMaxMensuelle));
      expect(couple.user, equals(julienRente));
      expect(couple.conjoint, equals(laurenRente));
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
      expect(breakdown.socialCharges, closeTo(laurenSalary * cotisationsSalarieTotal, 1));
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

    test('10. Lauren annual rente with 13e', () {
      final laurenMonthly = AvsCalculator.computeMonthlyRente(
        currentAge: laurenAge,
        retirementAge: retirementAge,
        arrivalAge: laurenArrivalAge,
        grossAnnualSalary: laurenSalary,
      );
      final annual13 = AvsCalculator.annualRente(laurenMonthly);
      final annual12 = AvsCalculator.annualRente(laurenMonthly, include13eme: false);
      // 13e rente = +8.33% vs 12-month
      expect(annual13, closeTo(annual12 * 13 / 12, 0.01));
      expect(annual13, greaterThan(annual12));
      // Lauren monthly ~2400 (43/44 of ~2460 interpolated from 67k)
      // Annual 13 ≈ ~31200, annual 12 ≈ ~28800
      expect(annual13, greaterThan(20000));
      expect(annual13, lessThan(35000));
    });
  });
}
