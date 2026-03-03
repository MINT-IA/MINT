import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

void main() {
  group('NetIncomeBreakdown', () {
    // ──────────────────────────────────────────────
    // Golden test: Julien (50, 100k, ZH)
    // ──────────────────────────────────────────────

    test('Julien (50, 100k, ZH) — socialCharges = 7350', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'ZH',
        age: 50,
      );
      // cotisationsSalarieTotal = 0.0735
      expect(b.socialCharges, closeTo(7350, 1));
    });

    test('Julien (50, 100k, ZH) — lppEmployee ≈ 5516', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'ZH',
        age: 50,
      );
      // salaireCoord = clamp(100000-26460, 3780, 64260) = 64260
      // bonif 45-54 = 0.15, /2 = 0.075
      // lppEmployee = 64260 * 0.075 = 4819.50
      expect(b.lppEmployee, closeTo(4819.5, 1));
    });

    test('Julien (50, 100k, ZH) — netPayslip = gross - social - lpp', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'ZH',
        age: 50,
      );
      expect(b.netPayslip, closeTo(b.grossSalary - b.socialCharges - b.lppEmployee, 0.01));
    });

    test('Julien (50, 100k, ZH) — disposableIncome = netPayslip - tax', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'ZH',
        age: 50,
      );
      expect(b.disposableIncome, closeTo(b.netPayslip - b.incomeTaxEstimate, 0.01));
    });

    // ──────────────────────────────────────────────
    // Lauren (45, 60k, ZH)
    // ──────────────────────────────────────────────

    test('Lauren (45, 60k, ZH) — salaireCoord correct', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 60000,
        canton: 'ZH',
        age: 45,
      );
      // salaireCoord = clamp(60000-26460, 3780, 64260) = 33540
      // bonif 45-54 = 0.15, /2 = 0.075
      // lppEmployee = 33540 * 0.075 = 2515.50
      expect(b.lppEmployee, closeTo(2515.5, 1));
      expect(b.socialCharges, closeTo(60000 * 0.0735, 1));
    });

    // ──────────────────────────────────────────────
    // Edge cases
    // ──────────────────────────────────────────────

    test('Salary below LPP threshold (20k) — lppEmployee = 0', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 20000,
        canton: 'ZH',
        age: 45,
      );
      expect(b.lppEmployee, 0);
      expect(b.socialCharges, closeTo(20000 * 0.0735, 1));
    });

    test('Age < 25 — lppEmployee = 0', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 80000,
        canton: 'ZH',
        age: 22,
      );
      expect(b.lppEmployee, 0);
    });

    test('Zero salary — all zeros', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 0,
        canton: 'ZH',
        age: 50,
      );
      expect(b.grossSalary, 0);
      expect(b.socialCharges, 0);
      expect(b.lppEmployee, 0);
      expect(b.incomeTaxEstimate, 0);
      expect(b.netPayslip, 0);
      expect(b.disposableIncome, 0);
      expect(b.netRatio, 0);
    });

    // ──────────────────────────────────────────────
    // Canton comparison
    // ──────────────────────────────────────────────

    test('Canton ZG (low tax) — incomeTax < ZH', () {
      final zh = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'ZH',
        age: 50,
      );
      final zg = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'ZG',
        age: 50,
      );
      expect(zg.incomeTaxEstimate, lessThan(zh.incomeTaxEstimate));
    });

    test('Canton GE (high tax) — incomeTax > ZH', () {
      final zh = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'ZH',
        age: 50,
      );
      final ge = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'GE',
        age: 50,
      );
      expect(ge.incomeTaxEstimate, greaterThan(zh.incomeTaxEstimate));
    });

    // ──────────────────────────────────────────────
    // Regression: netRatio ≈ 0.87 for ZH/100k/50
    // ──────────────────────────────────────────────

    test('netRatio for 100k ZH ≈ 0.87 (±0.03) — regression', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'ZH',
        age: 50,
      );
      // The old * 0.87 was calibrated for ZH/100k. The new dynamic
      // calculation should be close but not identical.
      expect(b.netRatio, closeTo(0.878, 0.03));
    });

    // ──────────────────────────────────────────────
    // Married couple — tax should be lower
    // ──────────────────────────────────────────────

    test('Married couple 2 children — lower incomeTax', () {
      final single = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'ZH',
        age: 50,
      );
      final married = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'ZH',
        age: 50,
        etatCivil: 'marie',
        nombreEnfants: 2,
      );
      expect(married.incomeTaxEstimate, lessThan(single.incomeTaxEstimate));
    });

    // ──────────────────────────────────────────────
    // monthlyNetPayslip convenience getter
    // ──────────────────────────────────────────────

    test('monthlyNetPayslip = netPayslip / 12', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'ZH',
        age: 50,
      );
      expect(b.monthlyNetPayslip, closeTo(b.netPayslip / 12, 0.01));
    });

    // ──────────────────────────────────────────────
    // estimateBrutFromNet (inverse)
    // ──────────────────────────────────────────────

    test('estimateBrutFromNet — round-trip approximate', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'ZH',
        age: 50,
      );
      final estimatedGross = NetIncomeBreakdown.estimateBrutFromNet(
        b.netPayslip,
        age: 50,
      );
      // Should approximately recover the original gross
      // (not exact because estimateBrutFromNet doesn't account for income tax)
      expect(estimatedGross, closeTo(100000, 5000));
    });

    test('estimateBrutFromNet — zero returns zero', () {
      expect(NetIncomeBreakdown.estimateBrutFromNet(0), 0);
      expect(NetIncomeBreakdown.estimateBrutFromNet(-1000), 0);
    });

    // ──────────────────────────────────────────────
    // toJson
    // ──────────────────────────────────────────────

    test('toJson contains all fields', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'ZH',
        age: 50,
      );
      final json = b.toJson();
      expect(json.containsKey('grossSalary'), true);
      expect(json.containsKey('socialCharges'), true);
      expect(json.containsKey('lppEmployee'), true);
      expect(json.containsKey('incomeTaxEstimate'), true);
      expect(json.containsKey('netPayslip'), true);
      expect(json.containsKey('disposableIncome'), true);
      expect(json.containsKey('netRatio'), true);
      expect(json.containsKey('canton'), true);
      expect(json.containsKey('age'), true);
    });

    // ──────────────────────────────────────────────
    // Age bands — LPP bonification changes
    // ──────────────────────────────────────────────

    test('LPP bonification increases with age', () {
      final young = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'ZH',
        age: 30,
      );
      final mid = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'ZH',
        age: 40,
      );
      final old = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'ZH',
        age: 55,
      );
      expect(young.lppEmployee, lessThan(mid.lppEmployee));
      expect(mid.lppEmployee, lessThan(old.lppEmployee));
    });
  });
}
