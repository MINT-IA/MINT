/// FRI Calculator — Sprint S38 (Shadow Mode).
///
/// Computes the Financial Resilience Index = L + F + R + S (each 0-25).
///
/// Components:
///   L — Liquidity (non-linear sqrt, diminishing returns)
///   F — Fiscal efficiency (weighted: 3a, rachat, amort indirect)
///   R — Retirement readiness (non-linear pow 1.5)
///   S — Structural risk (penalty-based)
///
/// FRI is computed but NOT displayed to users (shadow mode).
/// Logged in snapshots for calibration.
///
/// References:
///   - ONBOARDING_ARBITRAGE_ENGINE.md § V
///   - LAVS art. 21-29 (rente AVS)
///   - LPP art. 14-16 (taux de conversion)
///   - LIFD art. 38 (imposition du capital)
library;

import 'dart:math';

/// Input data for FRI computation.
///
/// All values should come from financial_core calculators,
/// never from raw user input.
class FriInput {
  // L — Liquidity
  final double liquidAssets;
  final double monthlyFixedCosts;
  final double shortTermDebtRatio;
  final String incomeVolatility; // "low", "medium", "high"

  // F — Fiscal efficiency
  final double actual3a;
  final double max3a;
  final double potentielRachatLpp;
  final double rachatEffectue;
  final double tauxMarginal;
  final bool isPropertyOwner;
  final double amortIndirect;

  // R — Retirement readiness
  final double replacementRatio;

  // S — Structural risk
  final double disabilityGapRatio;
  final bool hasDependents;
  final double deathProtectionGapRatio;
  final double mortgageStressRatio;
  final double concentrationRatio;
  final double employerDependencyRatio;

  // Metadata
  final String archetype;
  final int age;
  final String canton;

  const FriInput({
    this.liquidAssets = 0,
    this.monthlyFixedCosts = 1,
    this.shortTermDebtRatio = 0,
    this.incomeVolatility = 'low',
    this.actual3a = 0,
    this.max3a = 7258,
    this.potentielRachatLpp = 0,
    this.rachatEffectue = 0,
    this.tauxMarginal = 0,
    this.isPropertyOwner = false,
    this.amortIndirect = 0,
    this.replacementRatio = 0,
    this.disabilityGapRatio = 0,
    this.hasDependents = false,
    this.deathProtectionGapRatio = 0,
    this.mortgageStressRatio = 0,
    this.concentrationRatio = 0,
    this.employerDependencyRatio = 0,
    this.archetype = 'swiss_native',
    this.age = 30,
    this.canton = 'VD',
  });
}

/// FRI breakdown result.
class FriBreakdown {
  final double liquidite;
  final double fiscalite;
  final double retraite;
  final double risque;
  final double total;
  final String modelVersion;
  final DateTime computedAt;
  final double confidenceScore;
  final String disclaimer;
  final List<String> sources;

  const FriBreakdown({
    required this.liquidite,
    required this.fiscalite,
    required this.retraite,
    required this.risque,
    required this.total,
    this.modelVersion = '1.0.0',
    required this.computedAt,
    this.confidenceScore = 0,
    this.disclaimer = 'Score de solidité financière à titre éducatif. '
        'Ne constitue pas un conseil financier (LSFin).',
    this.sources = const [
      'LAVS art. 21-29 (rente AVS)',
      'LPP art. 14-16 (taux de conversion)',
      'LIFD art. 38 (imposition du capital)',
      'FINMA circ. 2008/21 (gestion des risques)',
    ],
  });
}

double _clamp(double value, [double lo = 0, double hi = 25]) {
  return value.clamp(lo, hi);
}

/// Computes the Financial Resilience Index.
///
/// FRI = L + F + R + S, each component 0-25, total 0-100.
/// Pure computation, no side effects.
class FriCalculator {
  FriCalculator._();

  static const modelVersion = '1.0.0';

  // ═══════════════════════════════════════════════════════════════
  // L — Liquidity (0-25)
  // ═══════════════════════════════════════════════════════════════

  /// Non-linear (sqrt): first months of emergency fund matter most.
  static double computeLiquidity(FriInput inp) {
    final costs = inp.monthlyFixedCosts < 1 ? 1.0 : inp.monthlyFixedCosts;
    final monthsCover = inp.liquidAssets / costs;

    var l = 25.0 * min(1.0, sqrt(monthsCover / 6.0));

    if (inp.shortTermDebtRatio > 0.30) l -= 4.0;
    if (inp.incomeVolatility == 'high') l -= 3.0;

    return _clamp(l);
  }

  // ═══════════════════════════════════════════════════════════════
  // F — Fiscal efficiency (0-25)
  // ═══════════════════════════════════════════════════════════════

  /// Weighted: 60% 3a + 25% rachat LPP + 15% amort indirect.
  /// Rachat only penalized if taux marginal > 25%.
  static double computeFiscal(FriInput inp) {
    final max3a = inp.max3a < 1 ? 1.0 : inp.max3a;
    final utilisation3a = min(1.0, inp.actual3a / max3a);

    var utilisationRachat = 0.0;
    if (inp.potentielRachatLpp > 0 && inp.tauxMarginal > 0.25) {
      utilisationRachat = min(1.0, inp.rachatEffectue / inp.potentielRachatLpp);
    }

    final utilisationAmort = inp.isPropertyOwner
        ? (inp.amortIndirect > 0 ? 1.0 : 0.0)
        : 1.0;

    final f = 25.0 * (
      0.60 * utilisation3a +
      0.25 * utilisationRachat +
      0.15 * utilisationAmort
    );

    return _clamp(f);
  }

  // ═══════════════════════════════════════════════════════════════
  // R — Retirement readiness (0-25)
  // ═══════════════════════════════════════════════════════════════

  /// Non-linear (pow 1.5): 60% replacement much better than 30%,
  /// but 80% vs 70% is marginal.
  static double computeRetirement(FriInput inp) {
    const target = 0.70;
    final ratio = max(0.0, inp.replacementRatio);
    final r = 25.0 * min(1.0, pow(ratio / target, 1.5));

    return _clamp(r.toDouble());
  }

  // ═══════════════════════════════════════════════════════════════
  // S — Structural risk (0-25)
  // ═══════════════════════════════════════════════════════════════

  /// Starts at 25, penalties subtracted for each risk factor.
  static double computeStructuralRisk(FriInput inp) {
    var s = 25.0;

    if (inp.disabilityGapRatio > 0.20) s -= 6.0;
    if (inp.hasDependents && inp.deathProtectionGapRatio > 0.30) s -= 6.0;
    if (inp.mortgageStressRatio > 0.36) s -= 5.0;
    if (inp.concentrationRatio > 0.70) s -= 4.0;
    if (inp.employerDependencyRatio > 0.80) s -= 4.0;

    return _clamp(s);
  }

  // ═══════════════════════════════════════════════════════════════
  // Full FRI computation
  // ═══════════════════════════════════════════════════════════════

  /// Compute full FRI breakdown.
  static FriBreakdown compute(FriInput inp, {double confidenceScore = 0}) {
    final l = computeLiquidity(inp);
    final f = computeFiscal(inp);
    final r = computeRetirement(inp);
    final s = computeStructuralRisk(inp);

    return FriBreakdown(
      liquidite: double.parse(l.toStringAsFixed(2)),
      fiscalite: double.parse(f.toStringAsFixed(2)),
      retraite: double.parse(r.toStringAsFixed(2)),
      risque: double.parse(s.toStringAsFixed(2)),
      total: double.parse((l + f + r + s).toStringAsFixed(2)),
      computedAt: DateTime.now(),
      confidenceScore: confidenceScore,
    );
  }
}
