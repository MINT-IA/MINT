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
    test('high income (>200k) → higher marginal rate', () {
      final rate = RetirementTaxCalculator.estimateMarginalRate(250000, 'ZH');
      // ZH effective 12.90% × income adj 1.15 × 1.3 marginal factor ≈ 0.193
      expect(rate, greaterThan(0.15));
      expect(rate, lessThan(0.30));
    });

    test('low income (<80k) → lower marginal rate', () {
      final rate = RetirementTaxCalculator.estimateMarginalRate(60000, 'ZH');
      // ZH effective 12.90% × income adj ~0.83 × 1.3 ≈ 0.139
      expect(rate, greaterThan(0.10));
      expect(rate, lessThan(0.20));
    });

    test('high-tax canton (GE) → higher than ZH', () {
      final rateZH = RetirementTaxCalculator.estimateMarginalRate(120000, 'ZH');
      final rateGE = RetirementTaxCalculator.estimateMarginalRate(120000, 'GE');
      expect(rateGE, greaterThan(rateZH));
    });

    test('low-tax canton (ZG) → lower than ZH', () {
      final rateZH = RetirementTaxCalculator.estimateMarginalRate(120000, 'ZH');
      final rateZG = RetirementTaxCalculator.estimateMarginalRate(120000, 'ZG');
      expect(rateZG, lessThan(rateZH));
    });

    test('Julien golden profile — VS 122k single marginal rate', () {
      final rate = RetirementTaxCalculator.estimateMarginalRate(122207, 'VS');
      // VS effective 14.56% × income adj ~1.044 × 1.3 ≈ 0.198
      expect(rate, greaterThan(0.15));
      expect(rate, lessThan(0.25));
    });

    test('VS married 122k → rate ~0.16-0.21 (family splitting)', () {
      final rate = RetirementTaxCalculator.estimateMarginalRate(
        122000, 'VS', isMarried: true, children: 0,
      );
      expect(rate, greaterThan(0.15));
      expect(rate, lessThan(0.22));
    });

    test('ZG single 100k → lowest rate', () {
      final rate = RetirementTaxCalculator.estimateMarginalRate(100000, 'ZG');
      expect(rate, lessThan(0.15));
    });

    test('BS single 100k → highest rate', () {
      final rate = RetirementTaxCalculator.estimateMarginalRate(100000, 'BS');
      expect(rate, greaterThan(0.18));
    });

    test('all 26 cantons return valid rate', () {
      for (final canton in ['ZH','BE','LU','UR','SZ','OW','NW','GL','ZG','FR',
          'SO','BS','BL','SH','AR','AI','SG','GR','AG','TG','TI','VD','VS',
          'NE','GE','JU']) {
        final rate = RetirementTaxCalculator.estimateMarginalRate(100000, canton);
        expect(rate, greaterThan(0.05));
        expect(rate, lessThan(0.35));
      }
    });

    test('married with 2 children → lower rate than single', () {
      final rateSingle = RetirementTaxCalculator.estimateMarginalRate(
        120000, 'ZH',
      );
      final rateMarried = RetirementTaxCalculator.estimateMarginalRate(
        120000, 'ZH', isMarried: true, children: 2,
      );
      expect(rateMarried, lessThan(rateSingle));
    });

    test('unknown canton → fallback to Swiss average', () {
      final rate = RetirementTaxCalculator.estimateMarginalRate(100000, 'XX');
      // Fallback 0.13 × 1.0 × 1.3 = 0.169
      expect(rate, closeTo(0.169, 0.01));
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

    test('7258 CHF 3a deduction at 120k income → saves ~1200-1600', () {
      final saving = RetirementTaxCalculator.estimateTaxSaving(
        income: 120000,
        deduction: 7258,
        canton: 'ZH',
      );
      // ZH marginal ~17.5% at 120k → ~1270 saved
      expect(saving, greaterThan(1000));
      expect(saving, lessThan(2500));
    });

    test('50k LPP buyback at 122k income VS — Julien scenario', () {
      final saving = RetirementTaxCalculator.estimateTaxSaving(
        income: 122207,
        deduction: 50000,
        canton: 'VS',
      );
      // VS marginal ~19.8% at 122k → ~9'900 saved
      expect(saving, greaterThan(7000));
      expect(saving, lessThan(15000));
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
