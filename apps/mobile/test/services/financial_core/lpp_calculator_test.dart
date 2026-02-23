import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';

void main() {
  group('LppCalculator.projectToRetirement', () {
    test('standard projection 45→65 with bonifications', () {
      final annualRente = LppCalculator.projectToRetirement(
        currentBalance: 200000,
        currentAge: 45,
        retirementAge: 65,
        grossAnnualSalary: 100000,
        caisseReturn: 0.02,
        conversionRate: 0.068,
      );
      // 20 years of return + bonifications on coordonne salary
      expect(annualRente, greaterThan(200000 * 0.068)); // More than just current balance
      expect(annualRente, greaterThan(0));
    });

    test('below seuil entree → no bonifications', () {
      final annualRente = LppCalculator.projectToRetirement(
        currentBalance: 50000,
        currentAge: 45,
        retirementAge: 65,
        grossAnnualSalary: 20000, // Below 22680
        caisseReturn: 0.02,
        conversionRate: 0.068,
      );
      // Only compound return on 50k, no bonifications
      // 50000 * (1.02)^20 * 0.068 ≈ 5050
      expect(annualRente, closeTo(50000 * 1.4859 * 0.068, 500));
    });

    test('at seuil entree → bonifications apply', () {
      final below = LppCalculator.projectToRetirement(
        currentBalance: 50000,
        currentAge: 45,
        retirementAge: 65,
        grossAnnualSalary: 22000,
        caisseReturn: 0.02,
        conversionRate: 0.068,
      );
      final above = LppCalculator.projectToRetirement(
        currentBalance: 50000,
        currentAge: 45,
        retirementAge: 65,
        grossAnnualSalary: 23000,
        caisseReturn: 0.02,
        conversionRate: 0.068,
      );
      expect(above, greaterThan(below));
    });

    test('buyback respects cap', () {
      final noBuyback = LppCalculator.projectToRetirement(
        currentBalance: 200000,
        currentAge: 50,
        retirementAge: 65,
        grossAnnualSalary: 100000,
        caisseReturn: 0.02,
        conversionRate: 0.068,
      );
      final withBuyback = LppCalculator.projectToRetirement(
        currentBalance: 200000,
        currentAge: 50,
        retirementAge: 65,
        grossAnnualSalary: 100000,
        caisseReturn: 0.02,
        conversionRate: 0.068,
        monthlyBuyback: 500,
        buybackCap: 50000,
      );
      expect(withBuyback, greaterThan(noBuyback));
    });

    test('zero balance zero salary → zero rente', () {
      final rente = LppCalculator.projectToRetirement(
        currentBalance: 0,
        currentAge: 45,
        retirementAge: 65,
        grossAnnualSalary: 0,
        caisseReturn: 0.02,
        conversionRate: 0.068,
      );
      expect(rente, equals(0));
    });
  });

  group('LppCalculator.projectOneMonth', () {
    test('adds bonification for age 30 (7%)', () {
      final result = LppCalculator.projectOneMonth(
        currentBalance: 100000,
        age: 30,
        grossAnnualSalary: 80000,
        monthlyReturn: 0.02 / 12,
      );
      // Return: 100000 * (1 + 0.02/12) ≈ 100166.67
      // Bonif: (80000-26460).clamp(3780,inf) = 53540 * 0.07 / 12 ≈ 312.32
      // Total ≈ 100479
      expect(result, greaterThan(100000));
      expect(result, closeTo(100479, 10));
    });

    test('below seuil → no bonification, only return', () {
      final result = LppCalculator.projectOneMonth(
        currentBalance: 50000,
        age: 30,
        grossAnnualSalary: 20000, // Below 22680
        monthlyReturn: 0.02 / 12,
      );
      // Only return: 50000 * (1 + 0.02/12) ≈ 50083
      expect(result, closeTo(50083, 5));
    });

    test('age 55 gets 18% bonification rate', () {
      final at30 = LppCalculator.projectOneMonth(
        currentBalance: 100000,
        age: 30,
        grossAnnualSalary: 80000,
        monthlyReturn: 0.02 / 12,
      );
      final at55 = LppCalculator.projectOneMonth(
        currentBalance: 100000,
        age: 55,
        grossAnnualSalary: 80000,
        monthlyReturn: 0.02 / 12,
      );
      // Age 55 → 18% vs age 30 → 7%: higher bonification
      expect(at55, greaterThan(at30));
    });
  });

  group('LppCalculator.blendedMonthly', () {
    test('100% rente → annualRente / 12', () {
      final monthly = LppCalculator.blendedMonthly(
        annualRente: 24000,
        conversionRate: 0.068,
        lppCapitalPct: 0,
        canton: 'ZH',
      );
      expect(monthly, closeTo(2000, 1));
    });

    test('100% capital < 100% rente (tax + 4% SWR < 6.8%)', () {
      final rente = LppCalculator.blendedMonthly(
        annualRente: 24000,
        conversionRate: 0.068,
        lppCapitalPct: 0,
        canton: 'ZH',
      );
      final capital = LppCalculator.blendedMonthly(
        annualRente: 24000,
        conversionRate: 0.068,
        lppCapitalPct: 1.0,
        canton: 'ZH',
      );
      expect(capital, lessThan(rente));
    });

    test('50% mixte is between rente and capital', () {
      final rente = LppCalculator.blendedMonthly(
        annualRente: 24000,
        conversionRate: 0.068,
        lppCapitalPct: 0,
        canton: 'ZH',
      );
      final capital = LppCalculator.blendedMonthly(
        annualRente: 24000,
        conversionRate: 0.068,
        lppCapitalPct: 1.0,
        canton: 'ZH',
      );
      final mixte = LppCalculator.blendedMonthly(
        annualRente: 24000,
        conversionRate: 0.068,
        lppCapitalPct: 0.5,
        canton: 'ZH',
      );
      expect(mixte, greaterThan(capital));
      expect(mixte, lessThan(rente));
    });

    test('married gets capital tax discount', () {
      final single = LppCalculator.blendedMonthly(
        annualRente: 24000,
        conversionRate: 0.068,
        lppCapitalPct: 1.0,
        canton: 'ZH',
        isMarried: false,
      );
      final married = LppCalculator.blendedMonthly(
        annualRente: 24000,
        conversionRate: 0.068,
        lppCapitalPct: 1.0,
        canton: 'ZH',
        isMarried: true,
      );
      // Married pays less tax → higher net capital → higher monthly
      expect(married, greaterThan(single));
    });
  });

  group('LppCalculator.computeSalaireCoordonne', () {
    test('below seuil → 0', () {
      expect(LppCalculator.computeSalaireCoordonne(20000), equals(0));
    });

    test('at seuil → minimum coordonne', () {
      final coord = LppCalculator.computeSalaireCoordonne(lppSeuilEntree);
      // 22680 - 26460 = -3780, clamped to 3780
      expect(coord, equals(lppSalaireCoordMin));
    });

    test('standard salary → correct coordonne', () {
      final coord = LppCalculator.computeSalaireCoordonne(80000);
      // 80000 - 26460 = 53540, clamped between 3780 and 64260
      expect(coord, equals(53540));
    });
  });
}
