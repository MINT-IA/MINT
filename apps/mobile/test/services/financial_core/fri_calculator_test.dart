import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/fri_calculator.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════
  //  FriInput defaults
  // ═══════════════════════════════════════════════════════════════

  group('FriInput defaults', () {
    test('default constructor has safe values', () {
      const inp = FriInput();
      expect(inp.liquidAssets, 0);
      expect(inp.monthlyFixedCosts, 1);
      expect(inp.shortTermDebtRatio, 0);
      expect(inp.incomeVolatility, 'low');
      expect(inp.actual3a, 0);
      expect(inp.max3a, 7258.0); // pilier3aPlafondAvecLpp
      expect(inp.replacementRatio, 0);
      expect(inp.archetype, 'swiss_native');
      expect(inp.age, 30);
      expect(inp.canton, 'ZH');
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  L — Liquidity component
  // ═══════════════════════════════════════════════════════════════

  group('computeLiquidity', () {
    test('zero liquid assets → 0', () {
      const inp = FriInput(liquidAssets: 0, monthlyFixedCosts: 5000);
      expect(FriCalculator.computeLiquidity(inp), 0.0);
    });

    test('6 months coverage → 25 (max)', () {
      const inp = FriInput(liquidAssets: 30000, monthlyFixedCosts: 5000);
      // monthsCover = 6.0, sqrt(6/6) = 1.0, 25*1 = 25
      expect(FriCalculator.computeLiquidity(inp), 25.0);
    });

    test('more than 6 months → still capped at 25', () {
      const inp = FriInput(liquidAssets: 100000, monthlyFixedCosts: 5000);
      expect(FriCalculator.computeLiquidity(inp), 25.0);
    });

    test('3 months coverage → diminishing returns (sqrt curve)', () {
      const inp = FriInput(liquidAssets: 15000, monthlyFixedCosts: 5000);
      // monthsCover=3, sqrt(3/6)=sqrt(0.5)~0.707, 25*0.707~17.68
      final l = FriCalculator.computeLiquidity(inp);
      expect(l, closeTo(17.68, 0.1));
    });

    test('high short-term debt ratio → penalty of 4', () {
      const inp = FriInput(
        liquidAssets: 30000,
        monthlyFixedCosts: 5000,
        shortTermDebtRatio: 0.40,
      );
      // Base 25 - 4 = 21
      expect(FriCalculator.computeLiquidity(inp), 21.0);
    });

    test('high income volatility → penalty of 3', () {
      const inp = FriInput(
        liquidAssets: 30000,
        monthlyFixedCosts: 5000,
        incomeVolatility: 'high',
      );
      // Base 25 - 3 = 22
      expect(FriCalculator.computeLiquidity(inp), 22.0);
    });

    test('both penalties → cumulative but clamped at 0', () {
      const inp = FriInput(
        liquidAssets: 5000,
        monthlyFixedCosts: 5000,
        shortTermDebtRatio: 0.50,
        incomeVolatility: 'high',
      );
      // monthsCover=1, sqrt(1/6)~0.408, 25*0.408~10.21, -4-3=3.21
      final l = FriCalculator.computeLiquidity(inp);
      expect(l, greaterThanOrEqualTo(0));
      expect(l, lessThan(10.21));
    });

    test('monthlyFixedCosts < 1 treated as 1 (no division by zero)', () {
      const inp = FriInput(liquidAssets: 6, monthlyFixedCosts: 0);
      // costs floored to 1, monthsCover=6, sqrt(6/6)=1, 25
      expect(FriCalculator.computeLiquidity(inp), 25.0);
    });

    test('debt ratio at exactly 0.30 → no penalty', () {
      const inp = FriInput(
        liquidAssets: 30000,
        monthlyFixedCosts: 5000,
        shortTermDebtRatio: 0.30,
      );
      expect(FriCalculator.computeLiquidity(inp), 25.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  F — Fiscal efficiency component
  // ═══════════════════════════════════════════════════════════════

  group('computeFiscal', () {
    test('zero 3a contribution → amort-only fiscal score (no rachat)', () {
      const inp = FriInput(actual3a: 0, max3a: 7258);
      // 3a=0%, not owner → utilisationAmort=1.0
      // f = 25 * (0.80*0 + 0.20*1.0) = 5.0
      expect(FriCalculator.computeFiscal(inp), closeTo(5.0, 0.01));
    });

    test('full 3a + no rachat applicable → 80% weight on 3a', () {
      const inp = FriInput(
        actual3a: 7258,
        max3a: 7258,
        potentielRachatLpp: 0,
        tauxMarginal: 0.20, // <= 0.25 → rachat not applicable
      );
      // 3a=100%, amort=1.0 (not owner → 1.0)
      // f = 25 * (0.80*1.0 + 0.20*1.0) = 25.0
      expect(FriCalculator.computeFiscal(inp), 25.0);
    });

    test('full 3a + rachat applicable + full rachat → 25', () {
      const inp = FriInput(
        actual3a: 7258,
        max3a: 7258,
        potentielRachatLpp: 100000,
        rachatEffectue: 100000,
        tauxMarginal: 0.30,
      );
      // rachatApplicable = true (potentiel>0, taux>0.25)
      // f = 25 * (0.60*1.0 + 0.25*1.0 + 0.15*1.0) = 25.0
      expect(FriCalculator.computeFiscal(inp), 25.0);
    });

    test('property owner without indirect amort → amort penalty', () {
      const inp = FriInput(
        actual3a: 7258,
        max3a: 7258,
        isPropertyOwner: true,
        amortIndirect: 0,
        potentielRachatLpp: 0,
        tauxMarginal: 0.10,
      );
      // No rachat applicable → 80% 3a + 20% amort
      // amort = 0 (owner + no amort indirect)
      // f = 25 * (0.80*1.0 + 0.20*0.0) = 20.0
      expect(FriCalculator.computeFiscal(inp), 20.0);
    });

    test('property owner with indirect amort → full amort credit', () {
      const inp = FriInput(
        actual3a: 7258,
        max3a: 7258,
        isPropertyOwner: true,
        amortIndirect: 500,
        potentielRachatLpp: 0,
        tauxMarginal: 0.10,
      );
      // f = 25 * (0.80*1.0 + 0.20*1.0) = 25.0
      expect(FriCalculator.computeFiscal(inp), 25.0);
    });

    test('partial 3a contribution → proportional', () {
      const inp = FriInput(actual3a: 3629, max3a: 7258);
      // 3a = 50%, no rachat, not owner → amort=1.0
      // f = 25 * (0.80*0.5 + 0.20*1.0) = 25 * 0.60 = 15.0
      expect(FriCalculator.computeFiscal(inp), closeTo(15.0, 0.01));
    });

    test('max3a < 1 treated as 1 (no division by zero)', () {
      const inp = FriInput(actual3a: 1, max3a: 0);
      // max3a floored to 1, utilisation3a = min(1, 1/1) = 1.0
      final f = FriCalculator.computeFiscal(inp);
      expect(f, greaterThan(0));
    });

    test('rachat weight redistributed when taux marginal <= 25%', () {
      const withRachat = FriInput(
        actual3a: 3629,
        max3a: 7258,
        potentielRachatLpp: 100000,
        rachatEffectue: 0,
        tauxMarginal: 0.30, // rachat applicable
      );
      const withoutRachat = FriInput(
        actual3a: 3629,
        max3a: 7258,
        potentielRachatLpp: 100000,
        rachatEffectue: 0,
        tauxMarginal: 0.20, // rachat NOT applicable
      );
      final fWith = FriCalculator.computeFiscal(withRachat);
      final fWithout = FriCalculator.computeFiscal(withoutRachat);
      // Different weights should yield different scores
      expect(fWith, isNot(equals(fWithout)));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  R — Retirement readiness component
  // ═══════════════════════════════════════════════════════════════

  group('computeRetirement', () {
    test('zero replacement ratio → 0', () {
      const inp = FriInput(replacementRatio: 0);
      expect(FriCalculator.computeRetirement(inp), 0.0);
    });

    test('70% replacement (target) → 25 (max)', () {
      const inp = FriInput(replacementRatio: 0.70);
      expect(FriCalculator.computeRetirement(inp), 25.0);
    });

    test('above target → still capped at 25', () {
      const inp = FriInput(replacementRatio: 1.0);
      expect(FriCalculator.computeRetirement(inp), 25.0);
    });

    test('35% replacement → non-linear (pow 1.5)', () {
      const inp = FriInput(replacementRatio: 0.35);
      // ratio/target = 0.5, pow(0.5, 1.5) ~ 0.3536, 25*0.3536 ~ 8.84
      final r = FriCalculator.computeRetirement(inp);
      expect(r, closeTo(8.84, 0.1));
    });

    test('negative replacement ratio → clamped to 0', () {
      const inp = FriInput(replacementRatio: -0.5);
      expect(FriCalculator.computeRetirement(inp), 0.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  S — Structural risk component
  // ═══════════════════════════════════════════════════════════════

  group('computeStructuralRisk', () {
    test('no risk factors → 25 (max)', () {
      const inp = FriInput();
      expect(FriCalculator.computeStructuralRisk(inp), 25.0);
    });

    test('all risk factors triggered → 0 (clamped)', () {
      const inp = FriInput(
        disabilityGapRatio: 0.50,
        hasDependents: true,
        deathProtectionGapRatio: 0.50,
        mortgageStressRatio: 0.50,
        concentrationRatio: 0.80,
        employerDependencyRatio: 0.90,
      );
      // 25 - 6 - 6 - 5 - 4 - 4 = 0
      expect(FriCalculator.computeStructuralRisk(inp), 0.0);
    });

    test('disability gap only → 25 - 6 = 19', () {
      const inp = FriInput(disabilityGapRatio: 0.30);
      expect(FriCalculator.computeStructuralRisk(inp), 19.0);
    });

    test('death protection gap without dependents → no penalty', () {
      const inp = FriInput(
        hasDependents: false,
        deathProtectionGapRatio: 0.50,
      );
      // No dependents → death protection gap penalty skipped
      expect(FriCalculator.computeStructuralRisk(inp), 25.0);
    });

    test('death protection gap with dependents → penalty of 6', () {
      const inp = FriInput(
        hasDependents: true,
        deathProtectionGapRatio: 0.40,
      );
      expect(FriCalculator.computeStructuralRisk(inp), 19.0);
    });

    test('mortgage stress at exactly 0.36 → no penalty', () {
      const inp = FriInput(mortgageStressRatio: 0.36);
      expect(FriCalculator.computeStructuralRisk(inp), 25.0);
    });

    test('mortgage stress above 0.36 → penalty of 5', () {
      const inp = FriInput(mortgageStressRatio: 0.37);
      expect(FriCalculator.computeStructuralRisk(inp), 20.0);
    });

    test('concentration ratio at boundary 0.70 → no penalty', () {
      const inp = FriInput(concentrationRatio: 0.70);
      expect(FriCalculator.computeStructuralRisk(inp), 25.0);
    });

    test('employer dependency at boundary 0.80 → no penalty', () {
      const inp = FriInput(employerDependencyRatio: 0.80);
      expect(FriCalculator.computeStructuralRisk(inp), 25.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  Full FRI computation
  // ═══════════════════════════════════════════════════════════════

  group('FriCalculator.compute', () {
    test('total is always 0-100', () {
      // Best case: max everything
      const best = FriInput(
        liquidAssets: 50000,
        monthlyFixedCosts: 5000,
        actual3a: 7258,
        max3a: 7258,
        replacementRatio: 0.80,
      );
      final bestResult = FriCalculator.compute(best);
      expect(bestResult.total, lessThanOrEqualTo(100));
      expect(bestResult.total, greaterThanOrEqualTo(0));

      // Worst case: nothing + all penalties
      const worst = FriInput(
        liquidAssets: 0,
        monthlyFixedCosts: 10000,
        shortTermDebtRatio: 0.50,
        incomeVolatility: 'high',
        actual3a: 0,
        replacementRatio: 0,
        disabilityGapRatio: 0.50,
        hasDependents: true,
        deathProtectionGapRatio: 0.50,
        mortgageStressRatio: 0.50,
        concentrationRatio: 0.80,
        employerDependencyRatio: 0.90,
      );
      final worstResult = FriCalculator.compute(worst);
      expect(worstResult.total, greaterThanOrEqualTo(0));
      expect(worstResult.total, lessThanOrEqualTo(100));
    });

    test('each component is 0-25', () {
      const inp = FriInput(
        liquidAssets: 15000,
        monthlyFixedCosts: 5000,
        actual3a: 3629,
        max3a: 7258,
        replacementRatio: 0.35,
        disabilityGapRatio: 0.30,
      );
      final result = FriCalculator.compute(inp);
      expect(result.liquidite, inInclusiveRange(0, 25));
      expect(result.fiscalite, inInclusiveRange(0, 25));
      expect(result.retraite, inInclusiveRange(0, 25));
      expect(result.risque, inInclusiveRange(0, 25));
    });

    test('total equals sum of components', () {
      const inp = FriInput(
        liquidAssets: 20000,
        monthlyFixedCosts: 4000,
        actual3a: 5000,
        max3a: 7258,
        replacementRatio: 0.50,
        mortgageStressRatio: 0.40,
      );
      final result = FriCalculator.compute(inp);
      final expectedTotal = result.liquidite + result.fiscalite +
          result.retraite + result.risque;
      expect(result.total, closeTo(expectedTotal, 0.01));
    });

    test('model version is set', () {
      final result = FriCalculator.compute(const FriInput());
      expect(result.modelVersion, '1.0.0');
    });

    test('computedAt is recent', () {
      final before = DateTime.now();
      final result = FriCalculator.compute(const FriInput());
      final after = DateTime.now();
      expect(result.computedAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(result.computedAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('confidence score is passed through', () {
      final result = FriCalculator.compute(const FriInput(), confidenceScore: 72.5);
      expect(result.confidenceScore, 72.5);
    });

    test('disclaimer and sources are present', () {
      final result = FriCalculator.compute(const FriInput());
      expect(result.disclaimer, contains('ducatif'));
      expect(result.disclaimer, contains('LSFin'));
      expect(result.sources, isNotEmpty);
      expect(result.sources.any((s) => s.contains('LAVS')), isTrue);
      expect(result.sources.any((s) => s.contains('LPP')), isTrue);
      expect(result.sources.any((s) => s.contains('LIFD')), isTrue);
    });

    test('values are rounded to 2 decimal places', () {
      const inp = FriInput(
        liquidAssets: 7777,
        monthlyFixedCosts: 3333,
        actual3a: 1234,
        max3a: 7258,
        replacementRatio: 0.33,
      );
      final result = FriCalculator.compute(inp);
      // Check that values have at most 2 decimal places
      expect(result.liquidite, equals(double.parse(result.liquidite.toStringAsFixed(2))));
      expect(result.fiscalite, equals(double.parse(result.fiscalite.toStringAsFixed(2))));
      expect(result.retraite, equals(double.parse(result.retraite.toStringAsFixed(2))));
      expect(result.risque, equals(double.parse(result.risque.toStringAsFixed(2))));
      expect(result.total, equals(double.parse(result.total.toStringAsFixed(2))));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  Golden couple: Julien (swiss_native, 49 yo, VS)
  // ═══════════════════════════════════════════════════════════════

  group('Golden couple — Julien profile', () {
    test('Julien typical inputs → FRI in reasonable range', () {
      // Julien: 122k salary, 70k LPP, 32k 3a, swiss_native, age 49
      const julien = FriInput(
        liquidAssets: 32000, // 3a as rough proxy for liquidity
        monthlyFixedCosts: 6000,
        shortTermDebtRatio: 0.0,
        incomeVolatility: 'low',
        actual3a: 7258,
        max3a: 7258,
        potentielRachatLpp: 539414,
        rachatEffectue: 0,
        tauxMarginal: 0.30,
        isPropertyOwner: false,
        replacementRatio: 0.655,
        disabilityGapRatio: 0.10,
        hasDependents: true,
        deathProtectionGapRatio: 0.20,
        mortgageStressRatio: 0.0,
        concentrationRatio: 0.30,
        employerDependencyRatio: 0.50,
        archetype: 'swiss_native',
        age: 49,
        canton: 'VS',
      );
      final result = FriCalculator.compute(julien);

      // Julien has good 3a, decent liquidity, good replacement ratio
      // but no rachat effectue → fiscal not perfect
      expect(result.total, greaterThan(40));
      expect(result.total, lessThan(90));
      expect(result.liquidite, greaterThan(15)); // ~5.3 months coverage
      expect(result.risque, equals(25.0)); // no structural risk triggers
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  Edge cases
  // ═══════════════════════════════════════════════════════════════

  group('Edge cases', () {
    test('completely empty profile → FRI = 0 or minimal', () {
      const empty = FriInput(
        liquidAssets: 0,
        monthlyFixedCosts: 0,
        actual3a: 0,
        replacementRatio: 0,
      );
      final result = FriCalculator.compute(empty);
      // L: assets=0, costs floored to 1, monthsCover=0 → 0
      // F: 3a=0 → 0, but not owner → amort=1.0, 25*(0.80*0+0.20*1)=5.0
      // R: 0
      // S: no risk → 25
      expect(result.total, closeTo(30.0, 0.5));
    });

    test('very high debt scenario → low score', () {
      const highDebt = FriInput(
        liquidAssets: 1000,
        monthlyFixedCosts: 8000,
        shortTermDebtRatio: 0.60,
        incomeVolatility: 'high',
        actual3a: 0,
        replacementRatio: 0.10,
        disabilityGapRatio: 0.50,
        hasDependents: true,
        deathProtectionGapRatio: 0.60,
        mortgageStressRatio: 0.50,
        concentrationRatio: 0.90,
        employerDependencyRatio: 0.95,
      );
      final result = FriCalculator.compute(highDebt);
      expect(result.total, lessThan(20));
      expect(result.risque, equals(0.0)); // all penalties triggered
    });

    test('perfect profile → FRI = 100', () {
      const perfect = FriInput(
        liquidAssets: 60000,
        monthlyFixedCosts: 5000,
        actual3a: 7258,
        max3a: 7258,
        potentielRachatLpp: 100000,
        rachatEffectue: 100000,
        tauxMarginal: 0.30,
        replacementRatio: 0.80,
      );
      final result = FriCalculator.compute(perfect);
      expect(result.total, equals(100.0));
    });
  });
}
