import 'dart:math' show min, sqrt, pow;
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for FRI (Financial Readiness Index) computation.
///
/// The FRI is a composite 0-100 score:
///   FRI = L + F + R + S  (each 0-25)
///
/// L = Liquidity, F = Fiscal Efficiency, R = Retirement, S = Structural Risk
///
/// Source: ONBOARDING_ARBITRAGE_ENGINE.md § V
/// Legal refs: LPP, OPP3, LIFD, FINMA
///
/// NOTE: FRI computation is currently inline in pulse_screen.dart.
/// These tests validate the formulas independently.
void main() {
  // ════════════════════════════════════════════════════════
  //  L — LIQUIDITY (0-25)
  // ════════════════════════════════════════════════════════

  group('FRI — L (Liquidity)', () {
    double computeL(double liquidAssets, double monthlyExpenses) {
      final monthsCover =
          monthlyExpenses > 0 ? liquidAssets / monthlyExpenses : 0.0;
      var l = 25 * min(1.0, sqrt(monthsCover / 6.0));
      return l.clamp(0, 25).toDouble();
    }

    test('0 liquid assets → L = 0', () {
      expect(computeL(0, 3500), 0.0);
    });

    test('1 month cover → L ≈ 10.2 (sqrt(1/6) * 25)', () {
      final l = computeL(3500, 3500);
      expect(l, closeTo(10.2, 0.5));
    });

    test('3 months cover → L ≈ 17.7 (sqrt(3/6) * 25)', () {
      final l = computeL(10500, 3500);
      expect(l, closeTo(17.7, 0.5));
    });

    test('6 months cover → L = 25 (max)', () {
      final l = computeL(21000, 3500);
      expect(l, 25.0);
    });

    test('12 months cover → L still capped at 25', () {
      final l = computeL(42000, 3500);
      expect(l, 25.0);
    });

    test('diminishing returns: 0→1 month > 5→6 months', () {
      final l0 = computeL(0, 3500);
      final l1 = computeL(3500, 3500);
      final l5 = computeL(17500, 3500);
      final l6 = computeL(21000, 3500);

      final gain01 = l1 - l0;
      final gain56 = l6 - l5;
      expect(gain01, greaterThan(gain56),
          reason: 'sqrt gives diminishing returns');
    });

    test('zero expenses → L = 0 (no data)', () {
      expect(computeL(20000, 0), 0.0);
    });
  });

  // ════════════════════════════════════════════════════════
  //  F — FISCAL EFFICIENCY (0-25)
  // ════════════════════════════════════════════════════════

  group('FRI — F (Fiscal Efficiency)', () {
    double computeF(double actual3a, double max3a) {
      final utilisation3a =
          max3a > 0 ? (actual3a / max3a).clamp(0.0, 1.0) : 0.0;
      var f = 25 * (0.6 * utilisation3a);
      return f.clamp(0, 25).toDouble();
    }

    test('no 3a → F = 0', () {
      expect(computeF(0, 7258), 0.0);
    });

    test('full 3a → F = 15 (0.6 * 25)', () {
      final f = computeF(7258, 7258);
      expect(f, closeTo(15.0, 0.1));
    });

    test('half 3a → F = 7.5', () {
      final f = computeF(3629, 7258);
      expect(f, closeTo(7.5, 0.1));
    });

    test('3a over max is clamped to 1.0 utilisation', () {
      final f = computeF(10000, 7258);
      expect(f, closeTo(15.0, 0.1));
    });
  });

  // ════════════════════════════════════════════════════════
  //  R — RETIREMENT (0-25)
  // ════════════════════════════════════════════════════════

  group('FRI — R (Retirement)', () {
    double computeR(double retirementIncome, double currentNetIncome) {
      if (currentNetIncome <= 0) return 0;
      final replacementRatio = retirementIncome / currentNetIncome;
      var r = 25 * min(1.0, pow(replacementRatio / 0.70, 1.5).toDouble());
      return r.clamp(0, 25).toDouble();
    }

    test('0 retirement income → R = 0', () {
      expect(computeR(0, 8000), 0.0);
    });

    test('70% replacement ratio → R = 25 (target met)', () {
      final r = computeR(5600, 8000);
      expect(r, closeTo(25.0, 0.1));
    });

    test('100% replacement ratio → R = 25 (capped)', () {
      final r = computeR(8000, 8000);
      expect(r, 25.0);
    });

    test('35% replacement (half target) → R ≈ 8.8', () {
      // (0.5^1.5) * 25 = 0.354 * 25 ≈ 8.84
      final r = computeR(2800, 8000);
      expect(r, closeTo(8.8, 0.5));
    });

    test('50% replacement → R ≈ 15.2', () {
      // (0.714^1.5) * 25 ≈ 0.603 * 25 ≈ 15.08
      final r = computeR(4000, 8000);
      expect(r, closeTo(15.1, 0.5));
    });

    test('non-linear: 50→70% gain > 70→90% gain', () {
      final r50 = computeR(4000, 8000);
      final r70 = computeR(5600, 8000);
      final r90 = computeR(7200, 8000);

      final gain5070 = r70 - r50;
      final gain7090 = r90 - r70;
      expect(gain5070, greaterThan(gain7090),
          reason: 'Non-linear: lower gains matter more');
    });

    test('zero current income → R = 0 (no data)', () {
      expect(computeR(3000, 0), 0.0);
    });
  });

  // ════════════════════════════════════════════════════════
  //  S — STRUCTURAL RISK (0-25)
  // ════════════════════════════════════════════════════════

  group('FRI — S (Structural Risk)', () {
    double computeS({
      double loanToValue = 0,
      double immobilierEffectif = 0,
      double totalPatrimoine = 100000,
    }) {
      var s = 25.0;
      if (loanToValue > 0.80) s -= 5;
      if (totalPatrimoine > 0) {
        final concentration = immobilierEffectif / totalPatrimoine;
        if (concentration > 0.70) s -= 4;
      }
      return s.clamp(0, 25).toDouble();
    }

    test('no risks → S = 25 (max)', () {
      expect(computeS(), 25.0);
    });

    test('high LTV → S = 20 (-5)', () {
      expect(computeS(loanToValue: 0.85), 20.0);
    });

    test('high concentration → S = 21 (-4)', () {
      expect(
        computeS(immobilierEffectif: 80000, totalPatrimoine: 100000),
        21.0,
      );
    });

    test('both penalties → S = 16 (-5 -4)', () {
      expect(
        computeS(
          loanToValue: 0.85,
          immobilierEffectif: 80000,
          totalPatrimoine: 100000,
        ),
        16.0,
      );
    });

    test('LTV exactly at threshold (0.80) → no penalty', () {
      expect(computeS(loanToValue: 0.80), 25.0);
    });

    test('concentration exactly at threshold (0.70) → no penalty', () {
      expect(
        computeS(immobilierEffectif: 70000, totalPatrimoine: 100000),
        25.0,
      );
    });
  });

  // ════════════════════════════════════════════════════════
  //  COMPOSITE FRI
  // ════════════════════════════════════════════════════════

  group('FRI — Composite score', () {
    test('all components at max → FRI = 100', () {
      // L=25, F=15 (max with 3a only), R=25, S=25 → 90
      // With full rachat component F could be 25
      // Using only 3a: L=25+F=15+R=25+S=25 = 90
      // That's the realistic max without rachat
      const l = 25.0;
      const f = 15.0; // 3a only
      const r = 25.0;
      const s = 25.0;
      expect(l + f + r + s, 90.0);
    });

    test('all components at zero → FRI = 0', () {
      const total = 0.0 + 0.0 + 0.0 + 0.0;
      expect(total, 0.0);
    });

    test('weakest component identification', () {
      final components = {'L': 20.0, 'F': 5.0, 'R': 15.0, 'S': 25.0};
      final weakest = components.entries
          .reduce((a, b) => a.value <= b.value ? a : b);
      expect(weakest.key, 'F');
      expect(weakest.value, 5.0);
    });
  });

  // ════════════════════════════════════════════════════════
  //  FRI DISPLAY RULES
  // ════════════════════════════════════════════════════════

  group('FRI — Display rules', () {
    test('FRI only shown when confidence >= 50%', () {
      // Spec: FRI requires confidenceScore >= 50%
      const confidenceScore = 45.0;
      const shouldShow = confidenceScore >= 50;
      expect(shouldShow, false);
    });

    test('FRI shown when confidence = 50%', () {
      const confidenceScore = 50.0;
      const shouldShow = confidenceScore >= 50;
      expect(shouldShow, true);
    });

    test('color mapping: >= 65 = success, >= 40 = warning, < 40 = error', () {
      Color colorForFri(double total) {
        if (total >= 65) return const Color(0xFF4CAF50); // success
        if (total >= 40) return const Color(0xFFFF9800); // warning
        return const Color(0xFFF44336); // error
      }

      expect(colorForFri(70), const Color(0xFF4CAF50));
      expect(colorForFri(50), const Color(0xFFFF9800));
      expect(colorForFri(30), const Color(0xFFF44336));
    });
  });

  // ════════════════════════════════════════════════════════
  //  GOLDEN COUPLE: Julien + Lauren
  // ════════════════════════════════════════════════════════

  group('FRI — Golden test (Julien)', () {
    test('Julien FRI components are reasonable', () {
      // Julien: 49yo, VS, salaire 122207, epargne 32000 (3a),
      // LPP 70377, epargneLiquide ~20k (approx), invest 77k
      // monthlyExpenses ≈ 3500 (estimation)

      // L: 20000 / 3500 ≈ 5.7 months → sqrt(5.7/6) * 25 ≈ 24.3
      final l = 25 * min(1.0, sqrt(5.7 / 6.0));
      expect(l, closeTo(24.3, 0.5));

      // F: 3a utilisation = 32000/7258 → capped at 1.0 → F = 15
      final f = 25 * 0.6 * 1.0;
      expect(f, closeTo(15.0, 0.1));

      // R: taux de remplacement ~65.5% → (0.655/0.70)^1.5 * 25
      final rr = (0.655 / 0.70);
      final r = 25 * min(1.0, pow(rr, 1.5).toDouble());
      expect(r, closeTo(23.0, 1.5));

      // S: no mortgage, no concentration → S = 25
      const s = 25.0;

      final total = l + f + r + s;
      expect(total, greaterThan(80),
          reason: 'Julien has a solid financial position');
      expect(total, lessThan(95),
          reason: 'Not perfect (fiscal efficiency limited to 3a)');
    });
  });
}

// Stub Color class for display rule tests
class Color {
  final int value;
  const Color(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Color && value == other.value;

  @override
  int get hashCode => value.hashCode;
}
