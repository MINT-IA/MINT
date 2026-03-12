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

  // ═══════════════════════════════════════════════════════════════
  //  PHASE 2: Survivor Pension (LPP art. 19-20)
  // ═══════════════════════════════════════════════════════════════

  group('LppCalculator.computeSurvivorPension', () {
    test('married 50yo, 10y marriage, 2 children → conjoint 60% + orphan 20%', () {
      final result = LppCalculator.computeSurvivorPension(
        projectedAnnualRente: 36000,
        isMarried: true,
        numberOfChildren: 2,
        conjointAge: 50,
        marriageDurationYears: 10,
      );
      expect(result.conjointGetsRente, isTrue);
      // Total uncapped: 60% + 2×20% = 100% → no cap needed
      expect(result.conjointMonthly, closeTo(1800, 1));
      expect(result.orphanMonthlyPerChild, closeTo(600, 1));
      expect(result.orphanMonthlyTotal, closeTo(1200, 1));
      expect(result.totalMonthly, closeTo(3000, 1));
      expect(result.conjointLumpSum, equals(0));
    });

    test('concubin → no conjoint pension (LPP art. 19)', () {
      final result = LppCalculator.computeSurvivorPension(
        projectedAnnualRente: 36000,
        isMarried: false,
        numberOfChildren: 1,
      );
      expect(result.conjointMonthly, equals(0));
      expect(result.conjointLumpSum, equals(0));
      expect(result.orphanMonthlyPerChild, closeTo(600, 1));
      expect(result.totalMonthly, closeTo(600, 1));
    });

    test('concubin no children → all zeros', () {
      final result = LppCalculator.computeSurvivorPension(
        projectedAnnualRente: 36000,
        isMarried: false,
        numberOfChildren: 0,
      );
      expect(result.totalMonthly, equals(0));
      expect(result.conjointLumpSum, equals(0));
      expect(result.orphanMonthlyPerChild, equals(0));
    });

    test('married no children, age 50, 10y → conjoint rente', () {
      final result = LppCalculator.computeSurvivorPension(
        projectedAnnualRente: 24000,
        isMarried: true,
        numberOfChildren: 0,
        conjointAge: 50,
        marriageDurationYears: 10,
      );
      expect(result.conjointGetsRente, isTrue);
      expect(result.conjointMonthly, closeTo(1200, 1));
      expect(result.orphanMonthlyPerChild, equals(0));
      expect(result.totalMonthly, closeTo(1200, 1));
    });

    test('LPP art. 19 al. 2: young spouse, short marriage, no children → lump sum', () {
      final result = LppCalculator.computeSurvivorPension(
        projectedAnnualRente: 36000,
        isMarried: true,
        numberOfChildren: 0,
        conjointAge: 35, // < 45
        marriageDurationYears: 2, // < 5
      );
      expect(result.conjointGetsRente, isFalse);
      expect(result.conjointMonthly, equals(0));
      // Lump sum = 3× annual conjoint pension = 3 × 36000 × 0.60 = 64800
      expect(result.conjointLumpSum, closeTo(64800, 1));
      expect(result.totalMonthly, equals(0));
    });

    test('LPP art. 19 al. 2: young spouse BUT has children → rente (exception)', () {
      final result = LppCalculator.computeSurvivorPension(
        projectedAnnualRente: 36000,
        isMarried: true,
        numberOfChildren: 1,
        conjointAge: 30,
        marriageDurationYears: 1,
      );
      expect(result.conjointGetsRente, isTrue);
      expect(result.conjointMonthly, greaterThan(0));
    });

    test('LPP art. 19 al. 3: 1 conjoint + 3 orphans → capped at 100%', () {
      // 60% + 3×20% = 120% → must be scaled to 100%
      final result = LppCalculator.computeSurvivorPension(
        projectedAnnualRente: 36000,
        isMarried: true,
        numberOfChildren: 3,
        conjointAge: 50,
        marriageDurationYears: 10,
      );
      // Total capped at 36000/12 = 3000/mois
      expect(result.totalMonthly, closeTo(3000, 1));
      // Scale factor = 100/120 = 0.8333
      expect(result.conjointMonthly, closeTo(1800 * 100 / 120, 1));
      expect(result.orphanMonthlyPerChild, closeTo(600 * 100 / 120, 1));
    });

    test('zero rente → zero survivor pensions', () {
      final result = LppCalculator.computeSurvivorPension(
        projectedAnnualRente: 0,
        isMarried: true,
        numberOfChildren: 3,
      );
      expect(result.totalMonthly, equals(0));
    });

    test('golden couple Julien → Lauren at 43, 15y marriage → lump sum (age < 45)', () {
      // Lauren is 43 < 45: does NOT meet art. 19 al. 2 age condition
      // despite 15y marriage. No children → lump sum, not rente.
      final result = LppCalculator.computeSurvivorPension(
        projectedAnnualRente: 33892,
        isMarried: true,
        numberOfChildren: 0,
        conjointAge: 43,
        marriageDurationYears: 15,
      );
      expect(result.conjointGetsRente, isFalse);
      expect(result.conjointMonthly, equals(0));
      // Lump sum = 3 × 33892 × 0.60 = 61005.6
      expect(result.conjointLumpSum, closeTo(61005.6, 1));
    });

    test('golden couple Julien → Lauren at 46, 15y marriage → rente', () {
      // In a few years, Lauren turns 46 → meets age condition
      final result = LppCalculator.computeSurvivorPension(
        projectedAnnualRente: 33892,
        isMarried: true,
        numberOfChildren: 0,
        conjointAge: 46,
        marriageDurationYears: 18,
      );
      expect(result.conjointGetsRente, isTrue);
      expect(result.conjointMonthly, closeTo(1694.6, 5));
    });

    test('default conjointAge/marriageDuration → meets conditions (backward compat)', () {
      // When not provided, defaults are 45 and 5 → meets art. 19 al. 2
      final result = LppCalculator.computeSurvivorPension(
        projectedAnnualRente: 36000,
        isMarried: true,
        numberOfChildren: 0,
      );
      expect(result.conjointGetsRente, isTrue);
      expect(result.conjointMonthly, closeTo(1800, 1));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  PHASE 2: EPL Repayment Impact (LPP art. 30d)
  // ═══════════════════════════════════════════════════════════════

  group('LppCalculator.computeEplImpact', () {
    test('EPL creates gap between with/without rente', () {
      final result = LppCalculator.computeEplImpact(
        currentBalance: 200000,
        eplAmount: 50000,
        eplRepaid: 0,
        currentAge: 45,
        retirementAge: 65,
        grossAnnualSalary: 100000,
        caisseReturn: 0.02,
        conversionRate: 0.068,
      );
      expect(result.renteWithoutEpl, greaterThan(result.renteWithEplOutstanding));
      expect(result.monthlyGapFromEpl, greaterThan(0));
    });

    test('fully repaid EPL → gap is zero', () {
      final result = LppCalculator.computeEplImpact(
        currentBalance: 250000,
        eplAmount: 50000,
        eplRepaid: 50000,
        currentAge: 45,
        retirementAge: 65,
        grossAnnualSalary: 100000,
        caisseReturn: 0.02,
        conversionRate: 0.068,
      );
      expect(result.renteWithoutEpl, closeTo(result.renteWithEplOutstanding, 0.01));
      expect(result.monthlyGapFromEpl, closeTo(0, 0.01));
    });

    test('partial repayment reduces gap', () {
      final noRepay = LppCalculator.computeEplImpact(
        currentBalance: 200000,
        eplAmount: 50000,
        eplRepaid: 0,
        currentAge: 45,
        retirementAge: 65,
        grossAnnualSalary: 100000,
        caisseReturn: 0.02,
        conversionRate: 0.068,
      );
      final halfRepay = LppCalculator.computeEplImpact(
        currentBalance: 200000,
        eplAmount: 50000,
        eplRepaid: 25000,
        currentAge: 45,
        retirementAge: 65,
        grossAnnualSalary: 100000,
        caisseReturn: 0.02,
        conversionRate: 0.068,
      );
      expect(halfRepay.monthlyGapFromEpl, lessThan(noRepay.monthlyGapFromEpl));
      expect(halfRepay.monthlyGapFromEpl, greaterThan(0));
    });

    test('C1 fix: with eplAge, renteIfFullyRepaid < renteWithoutEpl', () {
      // EPL taken 10 years ago → compound interest lost
      final result = LppCalculator.computeEplImpact(
        currentBalance: 200000,
        eplAmount: 50000,
        eplRepaid: 0,
        currentAge: 50,
        retirementAge: 65,
        grossAnnualSalary: 80000,
        caisseReturn: 0.02,
        conversionRate: 0.068,
        eplAge: 40, // taken 10 years ago
      );
      // renteWithoutEpl includes 10y compound growth on 50k
      // renteIfFullyRepaid only adds 50k nominal (no compound from gap)
      expect(result.renteWithoutEpl, greaterThan(result.renteIfFullyRepaid));
    });

    test('no eplAge → renteIfFullyRepaid == renteWithoutEpl (backward compat)', () {
      final result = LppCalculator.computeEplImpact(
        currentBalance: 200000,
        eplAmount: 50000,
        eplRepaid: 0,
        currentAge: 50,
        retirementAge: 65,
        grossAnnualSalary: 80000,
        caisseReturn: 0.015,
        conversionRate: 0.068,
        // no eplAge → defaults to currentAge → no compound gap
      );
      expect(result.renteIfFullyRepaid, closeTo(result.renteWithoutEpl, 0.01));
    });

    test('zero EPL → no impact', () {
      final result = LppCalculator.computeEplImpact(
        currentBalance: 300000,
        eplAmount: 0,
        eplRepaid: 0,
        currentAge: 50,
        retirementAge: 65,
        grossAnnualSalary: 100000,
        caisseReturn: 0.02,
        conversionRate: 0.068,
      );
      expect(result.monthlyGapFromEpl, closeTo(0, 0.01));
    });

    test('eplRepaid > eplAmount → clamped to 0 outstanding', () {
      final result = LppCalculator.computeEplImpact(
        currentBalance: 300000,
        eplAmount: 50000,
        eplRepaid: 60000, // overpaid
        currentAge: 50,
        retirementAge: 65,
        grossAnnualSalary: 100000,
        caisseReturn: 0.02,
        conversionRate: 0.068,
      );
      expect(result.monthlyGapFromEpl, closeTo(0, 0.01));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  PHASE 2: Couple Retirement Sequencing (LIFD art. 38)
  // ═══════════════════════════════════════════════════════════════

  group('LppCalculator.compareRetirementSequencing', () {
    test('staggered < same year tax (progressive brackets)', () {
      final result = LppCalculator.compareRetirementSequencing(
        userCapital: 500000,
        conjointCapital: 300000,
        canton: 'VS',
        isMarried: true,
      );
      expect(result.taxStaggered, lessThanOrEqualTo(result.taxSameYear));
      expect(result.taxSaving, greaterThanOrEqualTo(0));
    });

    test('large capitals → significant tax saving + recommendation', () {
      final result = LppCalculator.compareRetirementSequencing(
        userCapital: 700000,
        conjointCapital: 400000,
        canton: 'ZH',
        isMarried: true,
      );
      expect(result.taxSaving, greaterThan(1000));
      expect(result.recommendation, contains('Étaler'));
      expect(result.recommendation, contains('LIFD art. 38'));
    });

    test('small capitals → minimal saving', () {
      final result = LppCalculator.compareRetirementSequencing(
        userCapital: 50000,
        conjointCapital: 30000,
        canton: 'GE',
        isMarried: true,
      );
      expect(result.taxSaving, lessThan(1000));
    });

    test('equal capitals → staggered still better due to progressivity', () {
      final result = LppCalculator.compareRetirementSequencing(
        userCapital: 400000,
        conjointCapital: 400000,
        canton: 'VD',
        isMarried: true,
      );
      expect(result.taxStaggered, lessThanOrEqualTo(result.taxSameYear));
    });

    test('married discount applied', () {
      final single = LppCalculator.compareRetirementSequencing(
        userCapital: 500000,
        conjointCapital: 300000,
        canton: 'ZH',
        isMarried: false,
      );
      final married = LppCalculator.compareRetirementSequencing(
        userCapital: 500000,
        conjointCapital: 300000,
        canton: 'ZH',
        isMarried: true,
      );
      expect(married.taxSameYear, lessThan(single.taxSameYear));
    });

    test('M2 fix: zero capital → early return, no recommendation', () {
      final result = LppCalculator.compareRetirementSequencing(
        userCapital: 0,
        conjointCapital: 0,
        canton: 'ZH',
        isMarried: true,
      );
      expect(result.taxSameYear, equals(0));
      expect(result.taxStaggered, equals(0));
      expect(result.taxSaving, equals(0));
      expect(result.recommendation, contains('Aucun capital'));
    });

    test('one spouse zero capital → still computes correctly', () {
      final result = LppCalculator.compareRetirementSequencing(
        userCapital: 500000,
        conjointCapital: 0,
        canton: 'ZH',
        isMarried: true,
      );
      // Staggered: only user pays tax = same as sameYear (conjoint adds 0)
      expect(result.taxSameYear, closeTo(result.taxStaggered, 1));
    });

    test('golden couple Julien+Lauren VS → staggering saves tax', () {
      final result = LppCalculator.compareRetirementSequencing(
        userCapital: 677847,
        conjointCapital: 153000,
        canton: 'VS',
        isMarried: true,
      );
      expect(result.taxSaving, greaterThan(0));
      expect(result.taxSameYear, greaterThan(result.taxStaggered));
    });
  });
}
