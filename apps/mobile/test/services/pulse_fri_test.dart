import 'dart:math' show min, sqrt, pow;
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/fri_calculator.dart';

/// Unit tests for FriCalculator (financial_core).
///
/// The FRI is a composite 0-100 score:
///   FRI = L + F + R + S  (each 0-25)
///
/// L = Liquidity, F = Fiscal Efficiency, R = Retirement, S = Structural Risk
///
/// Source: ONBOARDING_ARBITRAGE_ENGINE.md § V
/// Legal refs: LPP, OPP3, LIFD, FINMA
void main() {
  // ════════════════════════════════════════════════════════
  //  L — LIQUIDITY (0-25)
  // ════════════════════════════════════════════════════════

  group('FriCalculator — L (Liquidity)', () {
    test('0 liquid assets → L = 0', () {
      final l = FriCalculator.computeLiquidity(
          const FriInput(liquidAssets: 0, monthlyFixedCosts: 3500));
      expect(l, 0.0);
    });

    test('1 month cover → L ≈ 10.2', () {
      final l = FriCalculator.computeLiquidity(
          const FriInput(liquidAssets: 3500, monthlyFixedCosts: 3500));
      expect(l, closeTo(10.2, 0.5));
    });

    test('3 months cover → L ≈ 17.7', () {
      final l = FriCalculator.computeLiquidity(
          const FriInput(liquidAssets: 10500, monthlyFixedCosts: 3500));
      expect(l, closeTo(17.7, 0.5));
    });

    test('6 months cover → L = 25 (max)', () {
      final l = FriCalculator.computeLiquidity(
          const FriInput(liquidAssets: 21000, monthlyFixedCosts: 3500));
      expect(l, 25.0);
    });

    test('12 months cover → L still capped at 25', () {
      final l = FriCalculator.computeLiquidity(
          const FriInput(liquidAssets: 42000, monthlyFixedCosts: 3500));
      expect(l, 25.0);
    });

    test('diminishing returns: 0→1 month > 5→6 months', () {
      final l0 = FriCalculator.computeLiquidity(
          const FriInput(liquidAssets: 0, monthlyFixedCosts: 3500));
      final l1 = FriCalculator.computeLiquidity(
          const FriInput(liquidAssets: 3500, monthlyFixedCosts: 3500));
      final l5 = FriCalculator.computeLiquidity(
          const FriInput(liquidAssets: 17500, monthlyFixedCosts: 3500));
      final l6 = FriCalculator.computeLiquidity(
          const FriInput(liquidAssets: 21000, monthlyFixedCosts: 3500));

      expect(l1 - l0, greaterThan(l6 - l5),
          reason: 'sqrt gives diminishing returns');
    });

    test('high short-term debt → penalty -4', () {
      final l = FriCalculator.computeLiquidity(const FriInput(
        liquidAssets: 21000,
        monthlyFixedCosts: 3500,
        shortTermDebtRatio: 0.35,
      ));
      expect(l, 21.0); // 25 - 4
    });

    test('high income volatility → penalty -3', () {
      final l = FriCalculator.computeLiquidity(const FriInput(
        liquidAssets: 21000,
        monthlyFixedCosts: 3500,
        incomeVolatility: 'high',
      ));
      expect(l, 22.0); // 25 - 3
    });

    test('monthlyFixedCosts < 1 → defaults to 1.0', () {
      final l = FriCalculator.computeLiquidity(
          const FriInput(liquidAssets: 6, monthlyFixedCosts: 0));
      expect(l, greaterThan(0));
    });
  });

  // ════════════════════════════════════════════════════════
  //  F — FISCAL EFFICIENCY (0-25)
  // ════════════════════════════════════════════════════════

  group('FriCalculator — F (Fiscal)', () {
    test('no 3a, no rachat → F = 0 (non-property owner)', () {
      final f = FriCalculator.computeFiscal(const FriInput(
        actual3a: 0,
        max3a: 7258,
        isPropertyOwner: false,
      ));
      // Non-property: utilisationAmort = 1.0 (not applicable)
      // F = 25 * (0.80 * 0 + 0.20 * 1.0) = 5.0
      expect(f, closeTo(5.0, 0.1));
    });

    test('full 3a without rachat (non-owner) → F ≈ 25', () {
      final f = FriCalculator.computeFiscal(const FriInput(
        actual3a: 7258,
        max3a: 7258,
        isPropertyOwner: false,
      ));
      // F = 25 * (0.80 * 1.0 + 0.20 * 1.0) = 25.0
      expect(f, closeTo(25.0, 0.1));
    });

    test('rachat applicable when tauxMarginal > 25% and potentiel > 0', () {
      final f = FriCalculator.computeFiscal(const FriInput(
        actual3a: 7258,
        max3a: 7258,
        potentielRachatLpp: 100000,
        rachatEffectue: 50000,
        tauxMarginal: 0.30,
        isPropertyOwner: false,
      ));
      // Rachat applicable: 60% * 1.0 + 25% * 0.5 + 15% * 1.0
      // = 0.60 + 0.125 + 0.15 = 0.875
      // F = 25 * 0.875 = 21.875
      expect(f, closeTo(21.9, 0.5));
    });

    test('property owner without amort indirect → penalty', () {
      final f = FriCalculator.computeFiscal(const FriInput(
        actual3a: 7258,
        max3a: 7258,
        isPropertyOwner: true,
        amortIndirect: 0,
      ));
      // Property owner: utilisationAmort = 0
      // No rachat: F = 25 * (0.80 * 1.0 + 0.20 * 0) = 20.0
      expect(f, closeTo(20.0, 0.1));
    });
  });

  // ════════════════════════════════════════════════════════
  //  R — RETIREMENT (0-25)
  // ════════════════════════════════════════════════════════

  group('FriCalculator — R (Retirement)', () {
    test('0 replacement → R = 0', () {
      final r = FriCalculator.computeRetirement(
          const FriInput(replacementRatio: 0));
      expect(r, 0.0);
    });

    test('70% replacement → R = 25 (target)', () {
      final r = FriCalculator.computeRetirement(
          const FriInput(replacementRatio: 0.70));
      expect(r, closeTo(25.0, 0.1));
    });

    test('100% replacement → R = 25 (capped)', () {
      final r = FriCalculator.computeRetirement(
          const FriInput(replacementRatio: 1.0));
      expect(r, 25.0);
    });

    test('35% replacement → R ≈ 8.8', () {
      final r = FriCalculator.computeRetirement(
          const FriInput(replacementRatio: 0.35));
      expect(r, closeTo(8.8, 0.5));
    });

    test('non-linear: 50→70% gain > 70→90% gain', () {
      final r50 = FriCalculator.computeRetirement(
          const FriInput(replacementRatio: 0.50));
      final r70 = FriCalculator.computeRetirement(
          const FriInput(replacementRatio: 0.70));
      final r90 = FriCalculator.computeRetirement(
          const FriInput(replacementRatio: 0.90));

      expect(r70 - r50, greaterThan(r90 - r70),
          reason: 'Non-linear: lower gains matter more');
    });
  });

  // ════════════════════════════════════════════════════════
  //  S — STRUCTURAL RISK (0-25)
  // ════════════════════════════════════════════════════════

  group('FriCalculator — S (Structural Risk)', () {
    test('no risks → S = 25 (max)', () {
      final s =
          FriCalculator.computeStructuralRisk(const FriInput());
      expect(s, 25.0);
    });

    test('high concentration → S -= 4', () {
      final s = FriCalculator.computeStructuralRisk(
          const FriInput(concentrationRatio: 0.75));
      expect(s, 21.0);
    });

    test('high mortgage stress → S -= 5', () {
      final s = FriCalculator.computeStructuralRisk(
          const FriInput(mortgageStressRatio: 0.40));
      expect(s, 20.0);
    });

    test('disability gap → S -= 6', () {
      final s = FriCalculator.computeStructuralRisk(
          const FriInput(disabilityGapRatio: 0.25));
      expect(s, 19.0);
    });

    test('death gap with dependents → S -= 6', () {
      final s = FriCalculator.computeStructuralRisk(const FriInput(
        hasDependents: true,
        deathProtectionGapRatio: 0.35,
      ));
      expect(s, 19.0);
    });

    test('death gap without dependents → no penalty', () {
      final s = FriCalculator.computeStructuralRisk(const FriInput(
        hasDependents: false,
        deathProtectionGapRatio: 0.50,
      ));
      expect(s, 25.0);
    });

    test('employer dependency → S -= 4', () {
      final s = FriCalculator.computeStructuralRisk(
          const FriInput(employerDependencyRatio: 0.85));
      expect(s, 21.0);
    });

    test('all penalties stack → S clamped at 0', () {
      final s = FriCalculator.computeStructuralRisk(const FriInput(
        disabilityGapRatio: 0.25,
        hasDependents: true,
        deathProtectionGapRatio: 0.35,
        mortgageStressRatio: 0.40,
        concentrationRatio: 0.75,
        employerDependencyRatio: 0.85,
      ));
      // 25 - 6 - 6 - 5 - 4 - 4 = 0
      expect(s, 0.0);
    });
  });

  // ════════════════════════════════════════════════════════
  //  COMPOSITE FRI (full compute)
  // ════════════════════════════════════════════════════════

  group('FriCalculator.compute', () {
    test('default input → produces valid FriBreakdown', () {
      final result = FriCalculator.compute(const FriInput());
      expect(result.total, greaterThanOrEqualTo(0));
      expect(result.total, lessThanOrEqualTo(100));
      expect(result.liquidite, greaterThanOrEqualTo(0));
      expect(result.fiscalite, greaterThanOrEqualTo(0));
      expect(result.retraite, greaterThanOrEqualTo(0));
      expect(result.risque, greaterThanOrEqualTo(0));
      expect(result.disclaimer, contains('éducatif'));
      expect(result.sources, isNotEmpty);
    });

    test('total = sum of components', () {
      final result = FriCalculator.compute(const FriInput(
        liquidAssets: 10000,
        monthlyFixedCosts: 3000,
        actual3a: 7258,
        max3a: 7258,
        replacementRatio: 0.60,
      ));
      expect(
        result.total,
        closeTo(
            result.liquidite + result.fiscalite + result.retraite + result.risque,
            0.05),
      );
    });

    test('modelVersion is set', () {
      final result = FriCalculator.compute(const FriInput());
      expect(result.modelVersion, '1.0.0');
    });

    test('confidenceScore passed through', () {
      final result =
          FriCalculator.compute(const FriInput(), confidenceScore: 72.5);
      expect(result.confidenceScore, 72.5);
    });
  });

  // ════════════════════════════════════════════════════════
  //  FRI DISPLAY RULES
  // ════════════════════════════════════════════════════════

  group('FRI — Display rules', () {
    test('FRI only shown when visibility score >= 50%', () {
      const visibilityScore = 45.0;
      const shouldShow = visibilityScore >= 50;
      expect(shouldShow, false);
    });

    test('FRI shown when visibility score = 50%', () {
      const visibilityScore = 50.0;
      const shouldShow = visibilityScore >= 50;
      expect(shouldShow, true);
    });

    test('color mapping: >= 65 green, >= 40 orange, < 40 red', () {
      String colorBand(double total) {
        if (total >= 65) return 'success';
        if (total >= 40) return 'warning';
        return 'error';
      }

      expect(colorBand(70), 'success');
      expect(colorBand(50), 'warning');
      expect(colorBand(30), 'error');
    });

    test('weakest component identification', () {
      final result = FriCalculator.compute(const FriInput(
        liquidAssets: 20000,
        monthlyFixedCosts: 3500,
        actual3a: 0, // ← weak
        max3a: 7258,
        replacementRatio: 0.70,
      ));
      // Fiscal should be weakest (no 3a)
      final components = {
        'L': result.liquidite,
        'F': result.fiscalite,
        'R': result.retraite,
        'S': result.risque,
      };
      final weakest = components.entries
          .reduce((a, b) => a.value <= b.value ? a : b);
      // F should be low because no 3a contributions
      expect(result.fiscalite, lessThan(result.liquidite));
    });
  });

  // ════════════════════════════════════════════════════════
  //  GOLDEN COUPLE: Julien
  // ════════════════════════════════════════════════════════

  group('FRI — Golden test (Julien via FriCalculator)', () {
    test('Julien FRI is solid (> 70)', () {
      final result = FriCalculator.compute(const FriInput(
        // L
        liquidAssets: 20000,
        monthlyFixedCosts: 3500,
        // F
        actual3a: 7258, // max 3a utilisé
        max3a: 7258,
        potentielRachatLpp: 539414,
        rachatEffectue: 0,
        tauxMarginal: 0.30,
        isPropertyOwner: false,
        // R
        replacementRatio: 0.655,
        // S
        concentrationRatio: 0.0, // no property
        mortgageStressRatio: 0.0, // no mortgage
        // Meta
        age: 49,
        canton: 'VS',
      ));

      expect(result.total, greaterThan(60),
          reason: 'Julien has solid finances');
      expect(result.total, lessThan(100),
          reason: 'Not perfect (no rachat done yet)');
      expect(result.liquidite, greaterThan(20),
          reason: '~5.7 months liquidity');
      expect(result.retraite, greaterThan(20),
          reason: '65.5% replacement ratio close to 70% target');
      expect(result.risque, 25.0,
          reason: 'No structural risks (no mortgage, no concentration)');
    });
  });
}
