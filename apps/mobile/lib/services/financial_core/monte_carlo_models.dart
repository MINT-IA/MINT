/// Data models for Monte Carlo stochastic retirement projection.
///
/// These models represent the output of a Monte Carlo simulation that
/// projects retirement income over 25-30 years with random market returns.
/// Used by the MonteCarloChart widget to display probability bands.
///
/// Ref: outil educatif — ne constitue pas un conseil financier (LSFin).
library;

// ════════════════════════════════════════════════════════════════
//  DATA MODELS
// ════════════════════════════════════════════════════════════════

/// Financial-income boundary covered by a stochastic projection.
enum RetirementIncomeScope {
  /// All household retirement-income sources are available.
  householdComplete,

  /// Only LPP, pillar 3a, and unrestricted capital are projected.
  nonAvsOnly,
}

/// A single year in the Monte Carlo projection with percentile bands.
class MonteCarloPoint {
  /// Calendar year of this data point.
  final int year;

  /// Age of the retiree at this point.
  final int age;

  /// 10th percentile — pessimistic scenario (monthly CHF).
  final double p10;

  /// 25th percentile — below-median scenario (monthly CHF).
  final double p25;

  /// 50th percentile — median scenario (monthly CHF).
  final double p50;

  /// 75th percentile — above-median scenario (monthly CHF).
  final double p75;

  /// 90th percentile — optimistic scenario (monthly CHF).
  final double p90;

  const MonteCarloPoint({
    required this.year,
    required this.age,
    required this.p10,
    required this.p25,
    required this.p50,
    required this.p75,
    required this.p90,
  });
}

/// Complete result of a Monte Carlo simulation.
class MonteCarloResult {
  /// Year-by-year projection with percentile bands.
  final List<MonteCarloPoint> projection;

  /// Median monthly income at retirement start (CHF/mois).
  final double medianAt65;

  /// 10th percentile monthly income at retirement start (CHF/mois).
  final double p10At65;

  /// 90th percentile monthly income at retirement start (CHF/mois).
  final double p90At65;

  /// Probability (0.0-1.0) of capital exhaustion before age 90.
  final double ruinProbability;

  /// Number of simulations run.
  final int numSimulations;

  /// Legal disclaimer text.
  final String disclaimer;

  /// Age de depart a la retraite utilise pour la simulation.
  final int retirementAge;

  /// References legales (LPP, LAVS, LIFD, OPP3).
  final List<String> sources;

  /// Alertes contextuelles basees sur les resultats.
  final List<String> alertes;

  /// Explicit boundary for every numeric percentile in this result.
  final RetirementIncomeScope incomeScope;

  /// Whether an official AVS pension is included in the numeric projection.
  final bool avsIncluded;

  /// Data paths required before a complete household result can be produced.
  final List<String> missingFields;

  const MonteCarloResult({
    required this.projection,
    required this.medianAt65,
    required this.p10At65,
    required this.p90At65,
    required this.ruinProbability,
    required this.numSimulations,
    required this.disclaimer,
    required this.retirementAge,
    required this.incomeScope,
    required this.avsIncluded,
    required this.missingFields,
    this.sources = const [],
    this.alertes = const [],
  });
}
