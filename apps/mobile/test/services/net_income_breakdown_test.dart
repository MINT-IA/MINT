import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/constants/social_insurance.dart';

/// Unit tests for NetIncomeBreakdown — Tax Foundation
///
/// Validates the replacement of hardcoded * 0.87 with dynamic
/// computation using social charges, LPP employee share, and
/// cantonal income tax.
///
/// Legal references: LAVS art. 5, LPP art. 66, LIFD
void main() {
  // ════════════════════════════════════════════════════════════
  //  Factory compute() — basic invariants
  // ════════════════════════════════════════════════════════════

  group('NetIncomeBreakdown.compute() — invariants', () {
    test('zero gross returns zero everything', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 0,
        canton: 'VD',
        age: 45,
      );
      expect(b.grossSalary, 0);
      expect(b.socialCharges, 0);
      expect(b.lppEmployee, 0);
      expect(b.incomeTaxEstimate, 0);
      expect(b.netPayslip, 0);
      expect(b.disposableIncome, 0);
      expect(b.netRatio, 0);
    });

    test('negative gross returns zero everything', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: -50000,
        canton: 'ZH',
        age: 40,
      );
      expect(b.grossSalary, 0);
      expect(b.netPayslip, 0);
    });

    test('netPayslip < grossSalary', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'VD',
        age: 45,
      );
      expect(b.netPayslip, lessThan(b.grossSalary));
      expect(b.netPayslip, greaterThan(0));
    });

    test('disposableIncome <= netPayslip', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'VD',
        age: 45,
      );
      expect(b.disposableIncome, lessThanOrEqualTo(b.netPayslip));
    });

    test('netRatio is between 0 and 1', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 120000,
        canton: 'ZH',
        age: 50,
      );
      expect(b.netRatio, greaterThan(0));
      expect(b.netRatio, lessThan(1));
    });

    test('disposableRatio is between 0 and 1', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 120000,
        canton: 'ZH',
        age: 50,
      );
      expect(b.disposableRatio, greaterThan(0));
      expect(b.disposableRatio, lessThan(1));
    });

    test('monthlyNetPayslip = netPayslip / 12', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 120000,
        canton: 'VS',
        age: 45,
      );
      expect(b.monthlyNetPayslip, closeTo(b.netPayslip / 12, 0.01));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  Social charges — correct rates
  // ════════════════════════════════════════════════════════════

  group('Social charges', () {
    test('social charges = gross * cotisationsSalarieTotal', () {
      const gross = 100000.0;
      final b = NetIncomeBreakdown.compute(
        grossSalary: gross,
        canton: 'ZH',
        age: 45,
      );
      expect(b.socialCharges, closeTo(gross * cotisationsSalarieTotal, 0.01));
    });

    test('social charges scale linearly with salary', () {
      final b1 = NetIncomeBreakdown.compute(
        grossSalary: 50000,
        canton: 'VD',
        age: 40,
      );
      final b2 = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'VD',
        age: 40,
      );
      expect(b2.socialCharges, closeTo(b1.socialCharges * 2, 1));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  LPP employee share
  // ════════════════════════════════════════════════════════════

  group('LPP employee share', () {
    test('no LPP below seuil entree (22680)', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 20000,
        canton: 'ZH',
        age: 40,
      );
      expect(b.lppEmployee, 0);
    });

    test('no LPP before age 25', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 80000,
        canton: 'ZH',
        age: 22,
      );
      expect(b.lppEmployee, 0);
    });

    test('no LPP after age 65', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 80000,
        canton: 'ZH',
        age: 67,
      );
      expect(b.lppEmployee, 0);
    });

    test('LPP uses coordination deduction correctly', () {
      const gross = 80000.0;
      final b = NetIncomeBreakdown.compute(
        grossSalary: gross,
        canton: 'ZH',
        age: 40,
      );
      // salaireCoord = (80000 - 26460).clamp(3780, 64260) = 53540
      final expectedCoord =
          (gross - lppDeductionCoordination).clamp(lppSalaireCoordMin, lppSalaireCoordMax);
      final expectedLpp = expectedCoord * getLppBonificationRate(40) / 2;
      expect(b.lppEmployee, closeTo(expectedLpp, 0.01));
    });

    test('LPP bonification rate increases with age', () {
      final b35 = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'ZH',
        age: 30,
      );
      final b50 = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'ZH',
        age: 50,
      );
      expect(b50.lppEmployee, greaterThan(b35.lppEmployee),
          reason: 'Older workers have higher LPP bonification rates');
    });

    test('LPP coord salary is clamped at max', () {
      // Very high salary: coord should hit lppSalaireCoordMax
      final b = NetIncomeBreakdown.compute(
        grossSalary: 200000,
        canton: 'ZH',
        age: 50,
      );
      final maxLpp = lppSalaireCoordMax * getLppBonificationRate(50) / 2;
      expect(b.lppEmployee, closeTo(maxLpp, 0.01));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  Cantonal variation
  // ════════════════════════════════════════════════════════════

  group('Cantonal variation', () {
    test('high-tax canton has lower disposable income', () {
      final ge = NetIncomeBreakdown.compute(
        grossSalary: 120000,
        canton: 'GE',
        age: 45,
      );
      final zg = NetIncomeBreakdown.compute(
        grossSalary: 120000,
        canton: 'ZG',
        age: 45,
      );
      // Zug is low-tax, Geneva is high-tax
      expect(ge.disposableIncome, lessThan(zg.disposableIncome),
          reason: 'GE should have higher taxes than ZG');
    });

    test('same social charges regardless of canton', () {
      final ge = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'GE',
        age: 45,
      );
      final zg = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'ZG',
        age: 45,
      );
      expect(ge.socialCharges, closeTo(zg.socialCharges, 0.01));
      expect(ge.lppEmployee, closeTo(zg.lppEmployee, 0.01));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  netRatio vs old 0.87 hardcode
  // ════════════════════════════════════════════════════════════

  group('netRatio — replaces 0.87 hardcode', () {
    test('netRatio is in plausible range (0.80 - 0.95) for typical salary', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'VD',
        age: 45,
      );
      // Social charges ~6.4% + LPP ~7.5% => net ~86% (close to 0.87 but dynamic)
      expect(b.netRatio, greaterThan(0.80));
      expect(b.netRatio, lessThan(0.95));
    });

    test('netRatio varies by age (LPP bonification)', () {
      final young = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'ZH',
        age: 30,
      );
      final senior = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'ZH',
        age: 60,
      );
      // Higher LPP at 60 → lower net ratio
      expect(young.netRatio, greaterThan(senior.netRatio));
    });

    test('below LPP seuil, netRatio only reflects social charges', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 20000,
        canton: 'ZH',
        age: 30,
      );
      // Only social charges (6.4%), no LPP
      expect(b.netRatio, closeTo(1 - cotisationsSalarieTotal, 0.01));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  estimateBrutFromNet — Newton-Raphson inverse
  // ════════════════════════════════════════════════════════════

  group('estimateBrutFromNet()', () {
    test('zero net returns zero', () {
      final brut = NetIncomeBreakdown.estimateBrutFromNet(0);
      expect(brut, 0);
    });

    test('round-trip: compute then inverse is accurate', () {
      const original = 100000.0;
      final breakdown = NetIncomeBreakdown.compute(
        grossSalary: original,
        canton: 'VS',
        age: 45,
      );
      final estimated = NetIncomeBreakdown.estimateBrutFromNet(
        breakdown.netPayslip,
        canton: 'VS',
        age: 45,
      );
      expect(estimated, closeTo(original, 500),
          reason: 'Inverse should recover gross within 500 CHF');
    });

    test('higher net produces higher brut estimate', () {
      final brut1 = NetIncomeBreakdown.estimateBrutFromNet(60000, canton: 'ZH');
      final brut2 = NetIncomeBreakdown.estimateBrutFromNet(90000, canton: 'ZH');
      expect(brut2, greaterThan(brut1));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  Golden test: Julien (VS, 49, 122207 brut)
  // ════════════════════════════════════════════════════════════

  group('Golden test — Julien profile', () {
    test('Julien net breakdown is plausible', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 122207,
        canton: 'VS',
        age: 49,
        etatCivil: 'marie',
        nombreEnfants: 0,
      );

      // Social charges: 122207 * 6.4% ≈ 7821
      expect(b.socialCharges, closeTo(122207 * cotisationsSalarieTotal, 1));

      // LPP: coord = (122207 - 26460).clamp(3780, 64260) = 64260
      // Age 49 → bonif 15% → employee share = 64260 * 0.15 / 2 = 4820
      expect(b.lppEmployee, closeTo(64260 * 0.15 / 2, 1));

      // Net payslip: 122207 - 7821 - 4820 ≈ 109567
      expect(b.netPayslip, greaterThan(100000));
      expect(b.netPayslip, lessThan(120000));

      // netRatio should be close to (but not exactly) 0.87
      expect(b.netRatio, greaterThan(0.85));
      expect(b.netRatio, lessThan(0.93));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  toJson
  // ════════════════════════════════════════════════════════════

  group('toJson()', () {
    test('contains all fields', () {
      final b = NetIncomeBreakdown.compute(
        grossSalary: 100000,
        canton: 'ZH',
        age: 45,
      );
      final json = b.toJson();
      expect(json.containsKey('grossSalary'), isTrue);
      expect(json.containsKey('socialCharges'), isTrue);
      expect(json.containsKey('lppEmployee'), isTrue);
      expect(json.containsKey('incomeTaxEstimate'), isTrue);
      expect(json.containsKey('netPayslip'), isTrue);
      expect(json.containsKey('disposableIncome'), isTrue);
      expect(json.containsKey('netRatio'), isTrue);
      expect(json.containsKey('canton'), isTrue);
      expect(json.containsKey('age'), isTrue);
    });
  });
}
