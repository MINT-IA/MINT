import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

// ────────────────────────────────────────────────────────────
//  TAX CALCULATOR EXTENDED TESTS — autoresearch-test-generation
// ────────────────────────────────────────────────────────────
//
// 15 tests covering RetirementTaxCalculator + NetIncomeBreakdown:
//   - progressiveTax bracket boundaries
//   - capitalWithdrawalTax married discount
//   - Golden couple: Julien (VS, 122k), Lauren (VS, 67k)
//   - Edge cases (0, negative, very large amounts)
//   - estimateMarginalRate canton tiers
//   - estimateTaxSaving numerical integration
//   - NetIncomeBreakdown.compute golden values
//   - estimateBrutFromNet round-trip
// ────────────────────────────────────────────────────────────

void main() {
  group('RetirementTaxCalculator.progressiveTax', () {
    test('zero amount → zero tax', () {
      expect(RetirementTaxCalculator.progressiveTax(0, 0.065), equals(0));
    });

    test('negative amount → zero tax', () {
      expect(RetirementTaxCalculator.progressiveTax(-50000, 0.065), equals(0));
    });

    test('100k at 6.5% → first bracket only (1.0× multiplier)', () {
      final tax = RetirementTaxCalculator.progressiveTax(100000, 0.065);
      // 100'000 × 0.065 × 1.0 = 6'500
      expect(tax, closeTo(6500, 1));
    });

    test('200k at 6.5% → first two brackets', () {
      final tax = RetirementTaxCalculator.progressiveTax(200000, 0.065);
      // 100k × 0.065 × 1.0 = 6'500
      // 100k × 0.065 × 1.15 = 7'475
      // Total = 13'975
      expect(tax, closeTo(13975, 1));
    });

    test('500k at 6.5% → three brackets', () {
      final tax = RetirementTaxCalculator.progressiveTax(500000, 0.065);
      // 100k × 0.065 × 1.0 = 6'500
      // 100k × 0.065 × 1.15 = 7'475
      // 300k × 0.065 × 1.30 = 25'350
      // Total = 39'325
      expect(tax, closeTo(39325, 1));
    });

    test('1M at 6.5% → four brackets', () {
      final tax = RetirementTaxCalculator.progressiveTax(1000000, 0.065);
      // 100k × 0.065 × 1.0 = 6'500
      // 100k × 0.065 × 1.15 = 7'475
      // 300k × 0.065 × 1.30 = 25'350
      // 500k × 0.065 × 1.50 = 48'750
      // Total = 88'075
      expect(tax, closeTo(88075, 1));
    });

    test('1.5M at 6.5% → all brackets including 1.70× overflow', () {
      final tax = RetirementTaxCalculator.progressiveTax(1500000, 0.065);
      // Brackets 0-1M = 88'075
      // 500k × 0.065 × 1.70 = 55'250
      // Total = 143'325
      expect(tax, closeTo(143325, 1));
    });
  });

  group('RetirementTaxCalculator.capitalWithdrawalTax', () {
    test('zero capital → zero tax', () {
      expect(
        RetirementTaxCalculator.capitalWithdrawalTax(
          capitalBrut: 0,
          canton: 'VS',
        ),
        equals(0),
      );
    });

    test('VS canton — known rate applied', () {
      final tax = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: 100000,
        canton: 'VS',
      );
      expect(tax, greaterThan(0));
    });

    test('married discount reduces tax vs single', () {
      final taxSingle = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: 500000,
        canton: 'ZH',
        isMarried: false,
      );
      final taxMarried = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: 500000,
        canton: 'ZH',
        isMarried: true,
      );
      expect(taxMarried, lessThan(taxSingle));
      // ~15% discount
      expect(taxMarried / taxSingle, closeTo(0.85, 0.05));
    });

    test('unknown canton falls back to default rate', () {
      final tax = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: 100000,
        canton: 'XX',
      );
      // Default 6.5%
      expect(tax, closeTo(6500, 200));
    });
  });

  group('RetirementTaxCalculator.estimateMarginalRate', () {
    test('high income (>200k) → ~38% base', () {
      final rate = RetirementTaxCalculator.estimateMarginalRate(250000, 'ZH');
      expect(rate, closeTo(0.38, 0.05));
    });

    test('low income (<80k) → ~22% base', () {
      final rate = RetirementTaxCalculator.estimateMarginalRate(60000, 'ZH');
      expect(rate, closeTo(0.22, 0.05));
    });

    test('high-tax canton (GE) → +10% surcharge', () {
      final rateZH = RetirementTaxCalculator.estimateMarginalRate(120000, 'ZH');
      final rateGE = RetirementTaxCalculator.estimateMarginalRate(120000, 'GE');
      expect(rateGE, greaterThan(rateZH));
    });

    test('low-tax canton (ZG) → 25% discount', () {
      final rateZH = RetirementTaxCalculator.estimateMarginalRate(120000, 'ZH');
      final rateZG = RetirementTaxCalculator.estimateMarginalRate(120000, 'ZG');
      expect(rateZG, lessThan(rateZH));
    });

    test('Julien golden profile — VS 122k marginal rate', () {
      final rate = RetirementTaxCalculator.estimateMarginalRate(122207, 'VS');
      // VS is high-tax → 0.32 * 1.1 = 0.352
      expect(rate, closeTo(0.352, 0.01));
    });
  });

  group('RetirementTaxCalculator.estimateTaxSaving', () {
    test('zero deduction → zero saving', () {
      expect(
        RetirementTaxCalculator.estimateTaxSaving(
          income: 100000,
          deduction: 0,
          canton: 'ZH',
        ),
        equals(0),
      );
    });

    test('negative deduction → zero saving', () {
      expect(
        RetirementTaxCalculator.estimateTaxSaving(
          income: 100000,
          deduction: -5000,
          canton: 'ZH',
        ),
        equals(0),
      );
    });

    test('7258 CHF 3a deduction at 120k income → saves ~2000-3000', () {
      final saving = RetirementTaxCalculator.estimateTaxSaving(
        income: 120000,
        deduction: 7258,
        canton: 'ZH',
      );
      // ~32% marginal rate on 120k → ~2322 saved
      expect(saving, greaterThan(1500));
      expect(saving, lessThan(4000));
    });

    test('50k LPP buyback at 122k income VS — Julien scenario', () {
      final saving = RetirementTaxCalculator.estimateTaxSaving(
        income: 122207,
        deduction: 50000,
        canton: 'VS',
      );
      // VS high-tax, ~35% marginal → ~17'500 saved
      expect(saving, greaterThan(10000));
      expect(saving, lessThan(25000));
    });
  });

  group('NetIncomeBreakdown.compute', () {
    test('zero salary → all zeros', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 0,
        canton: 'ZH',
        age: 40,
      );
      expect(b.netPayslip, equals(0));
      expect(b.disposableIncome, equals(0));
      expect(b.netRatio, equals(0));
    });

    test('Julien golden profile — 122207 CHF brut VS age 49', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 122207,
        canton: 'VS',
        age: 49,
      );
      // Social charges ~6.4%, LPP ~7.5% of coordinated salary
      expect(b.socialCharges, greaterThan(7000));
      expect(b.socialCharges, lessThan(10000));
      expect(b.lppEmployee, greaterThan(3000));
      expect(b.netPayslip, greaterThan(100000));
      expect(b.netPayslip, lessThan(115000));
      expect(b.netRatio, greaterThan(0.80));
      expect(b.netRatio, lessThan(0.95));
    });

    test('below LPP threshold → no LPP deduction', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 20000,
        canton: 'ZH',
        age: 30,
      );
      expect(b.lppEmployee, equals(0));
    });

    test('age < 25 → no LPP deduction', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 80000,
        canton: 'ZH',
        age: 22,
      );
      expect(b.lppEmployee, equals(0));
    });

    test('monthlyNetPayslip = netPayslip / 12', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 120000,
        canton: 'ZH',
        age: 40,
      );
      expect(b.monthlyNetPayslip, closeTo(b.netPayslip / 12, 0.01));
    });
  });

  group('NetIncomeBreakdown.estimateBrutFromNet', () {
    test('zero net → zero gross', () {
      expect(
        NetIncomeBreakdown.estimateBrutFromNet(0),
        equals(0),
      );
    });

    test('round-trip: compute net → estimate gross → re-compute net ≈ original', () {
      final original = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'ZH',
        age: 40,
      );
      final estimatedGross = NetIncomeBreakdown.estimateBrutFromNet(
        original.netPayslip,
        age: 40,
        canton: 'ZH',
      );
      // Should converge to within ±500 CHF
      expect(estimatedGross, closeTo(100000, 500));
    });

    test('Julien round-trip: 122207 brut VS age 49', () {
      final original = NetIncomeBreakdown.compute(
        grossSalary: 122207,
        canton: 'VS',
        age: 49,
      );
      final estimatedGross = NetIncomeBreakdown.estimateBrutFromNet(
        original.netPayslip,
        age: 49,
        canton: 'VS',
      );
      expect(estimatedGross, closeTo(122207, 1000));
    });
  });
}
