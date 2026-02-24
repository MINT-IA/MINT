/// Data models for arbitrage comparisons (rente vs capital, allocation annuelle).
///
/// Sprint S32 — Arbitrage Phase 1.
/// These models hold year-by-year trajectories and comparison results.
/// Used by ArbitrageEngine and displayed by arbitrage screens.
library;

/// A single year snapshot in a trajectory projection.
class YearlySnapshot {
  final int year;
  final double netPatrimony;
  final double annualCashflow;
  final double cumulativeTaxDelta;

  const YearlySnapshot({
    required this.year,
    required this.netPatrimony,
    required this.annualCashflow,
    required this.cumulativeTaxDelta,
  });
}

/// One option (trajectory) in an arbitrage comparison.
class TrajectoireOption {
  /// Unique ID: "full_rente", "full_capital", "mixed", "3a", "rachat_lpp",
  /// "amort_indirect", "invest_libre".
  final String id;

  /// User-facing label (French).
  final String label;

  /// Year-by-year trajectory snapshots.
  final List<YearlySnapshot> trajectory;

  /// Net patrimony at end of horizon.
  final double terminalValue;

  /// Cumulative tax impact over the horizon.
  final double cumulativeTaxImpact;

  const TrajectoireOption({
    required this.id,
    required this.label,
    required this.trajectory,
    required this.terminalValue,
    required this.cumulativeTaxImpact,
  });
}

/// Full result of an arbitrage comparison.
class ArbitrageResult {
  /// Available options (2-4 trajectories).
  final List<TrajectoireOption> options;

  /// Year when trajectories cross (null if they never cross within horizon).
  final int? breakevenYear;

  /// One impactful number with context.
  final String chiffreChoc;

  /// Summary text for display.
  final String displaySummary;

  /// List of assumptions used in the simulation.
  final List<String> hypotheses;

  /// Legal disclaimer (always present).
  final String disclaimer;

  /// Legal source references.
  final List<String> sources;

  /// Confidence score (0-100).
  final double confidenceScore;

  /// Sensitivity analysis: key → delta value.
  final Map<String, double> sensitivity;

  const ArbitrageResult({
    required this.options,
    required this.breakevenYear,
    required this.chiffreChoc,
    required this.displaySummary,
    required this.hypotheses,
    required this.disclaimer,
    required this.sources,
    required this.confidenceScore,
    required this.sensitivity,
  });
}
