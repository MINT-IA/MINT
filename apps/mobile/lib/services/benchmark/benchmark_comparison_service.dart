// benchmark_comparison_service.dart — S60 Cantonal Benchmarks
//
// Compares a user profile against their canton's aggregated OFS benchmark.
//
// COMPLIANCE (NON-NEGOTIABLE — CLAUDE.md §6):
// - ZERO percentile / ranking output
// - ZERO social comparison language ("mieux que", "pire que", "top X%")
// - ALL differences expressed as ABSOLUTE factual observations
// - Conditional language ONLY ("se situe", "semble", "environ")
// - Disclaimer ALWAYS present in every output object
// - Source ALWAYS cited (OFS)
//
// Framing: "Dans ton canton, un profil similaire épargne environ X% de son revenu"
// NEVER: "Tu es au-dessus de la médiane cantonale" — too close to social comparison.
// ALWAYS: "Ton taux d'épargne ({userRate}%) diffère de la médiane cantonale ({medianRate}%)"

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/benchmark/cantonal_benchmark_data.dart';

// ════════════════════════════════════════════════════════════════════════
//  MODELS
// ════════════════════════════════════════════════════════════════════════

/// Dimensions that can be compared against cantonal benchmarks.
enum BenchmarkDimension {
  income,
  savings,
  taxBurden,
  housing,
  pillar3a,
  lppCoverage,
}

/// A single insight comparing the user's situation to a cantonal median.
///
/// COMPLIANCE: No ranking. No social comparison. Factual + educational only.
class BenchmarkInsight {
  /// Which financial dimension this insight covers.
  final BenchmarkDimension dimension;

  /// The user's computed value (in appropriate units for the dimension).
  final double userValue;

  /// The canton's aggregated median value (same units as [userValue]).
  final double cantonMedian;

  /// Absolute difference: userValue - cantonMedian.
  /// Positive = user is above median. Negative = below.
  /// Use for display only — NEVER as a ranking signal.
  final double difference;

  /// ARB key for the observation text displayed to the user.
  /// Must resolve to a compliant, non-comparative educational string.
  final String observationKey;

  /// Optional i18n parameters to substitute into [observationKey].
  final Map<String, String>? params;

  const BenchmarkInsight({
    required this.dimension,
    required this.userValue,
    required this.cantonMedian,
    required this.difference,
    required this.observationKey,
    this.params,
  });
}

/// Full comparison result for a user profile against their canton's benchmark.
///
/// Always includes a [disclaimer] — it is MANDATORY to display it.
class BenchmarkComparison {
  final String cantonCode;
  final List<BenchmarkInsight> insights;

  /// Educational disclaimer — ALWAYS display to the user.
  /// References LSFin and OFS source. Non-negotiable.
  final String disclaimer;

  const BenchmarkComparison({
    required this.cantonCode,
    required this.insights,
    required this.disclaimer,
  });
}

// ════════════════════════════════════════════════════════════════════════
//  SERVICE
// ════════════════════════════════════════════════════════════════════════

/// Compares a [CoachProfile] against their canton's [CantonalBenchmark].
///
/// All output is educational and non-comparative.
/// Returns null if canton data is unavailable.
class BenchmarkComparisonService {
  BenchmarkComparisonService._();

  static const String _disclaimer =
      'Données agrégées OFS — outil éducatif, pas un classement. '
      'Ne constitue pas un conseil au sens de la LSFin\u00a0(art.\u00a03). '
      'Aucune donnée personnelle n\'est comparée à d\'autres utilisateurs.';

  /// Compare a [CoachProfile] to its canton's benchmark.
  ///
  /// [cantonCode] should be the 2-letter ISO code (e.g., 'VS', 'ZH').
  /// Returns null if no benchmark data is found for [cantonCode].
  ///
  /// COMPLIANCE: The returned [BenchmarkComparison] MUST display its
  /// [BenchmarkComparison.disclaimer] to the user.
  static BenchmarkComparison? compare({
    required CoachProfile profile,
    required String cantonCode,
  }) {
    final benchmark = CantonalBenchmarkData.forCanton(cantonCode);
    if (benchmark == null) return null;

    final insights = <BenchmarkInsight>[];

    // ── Income ───────────────────────────────────────────────────────────
    final annualIncome = profile.revenuBrutAnnuel;
    insights.add(BenchmarkInsight(
      dimension: BenchmarkDimension.income,
      userValue: annualIncome,
      cantonMedian: benchmark.medianIncome,
      difference: annualIncome - benchmark.medianIncome,
      observationKey: 'benchmarkInsightIncome',
      params: {
        'canton': benchmark.cantonName,
        'amount': _fmtCHF(benchmark.medianIncome),
      },
    ));

    // ── Savings rate ─────────────────────────────────────────────────────
    final monthlyContributions = profile.totalContributionsMensuelles;
    final userSavingsRate = annualIncome > 0
        ? (monthlyContributions * 12 / annualIncome)
        : 0.0;
    final cantonSavingsRatePct =
        (benchmark.savingsRateTypical * 100).roundToDouble();
    insights.add(BenchmarkInsight(
      dimension: BenchmarkDimension.savings,
      userValue: userSavingsRate * 100, // expressed as percentage
      cantonMedian: cantonSavingsRatePct,
      difference: (userSavingsRate * 100) - cantonSavingsRatePct,
      observationKey: 'benchmarkInsightSavings',
      params: {
        'rate': cantonSavingsRatePct.toStringAsFixed(0),
      },
    ));

    // ── Tax burden ───────────────────────────────────────────────────────
    final taxLevel = _taxLevel(benchmark.taxBurdenIndex);
    insights.add(BenchmarkInsight(
      dimension: BenchmarkDimension.taxBurden,
      userValue: benchmark.taxBurdenIndex,
      cantonMedian: 100, // Swiss average = 100
      difference: benchmark.taxBurdenIndex - 100,
      observationKey: 'benchmarkInsightTax',
      params: {
        'canton': benchmark.cantonName,
        'level': taxLevel,
      },
    ));

    // ── Housing ──────────────────────────────────────────────────────────
    insights.add(BenchmarkInsight(
      dimension: BenchmarkDimension.housing,
      userValue: benchmark.medianRent,
      cantonMedian: benchmark.medianRent,
      difference: 0, // static benchmark — no user comparison
      observationKey: 'benchmarkInsightHousing',
      params: {
        'amount': _fmtCHF(benchmark.medianRent),
      },
    ));

    // ── Pillar 3a participation ───────────────────────────────────────────
    final participation3aPct =
        (benchmark.pillar3aParticipation * 100).roundToDouble();
    insights.add(BenchmarkInsight(
      dimension: BenchmarkDimension.pillar3a,
      userValue: participation3aPct,
      cantonMedian: participation3aPct,
      difference: 0, // static benchmark — no user comparison
      observationKey: 'benchmarkInsight3a',
      params: {
        'rate': participation3aPct.toStringAsFixed(0),
      },
    ));

    // ── LPP coverage ─────────────────────────────────────────────────────
    final lppRatePct = (benchmark.lppCoverageRate * 100).roundToDouble();
    insights.add(BenchmarkInsight(
      dimension: BenchmarkDimension.lppCoverage,
      userValue: lppRatePct,
      cantonMedian: lppRatePct,
      difference: 0, // static benchmark — no user comparison
      observationKey: 'benchmarkInsightLpp',
      params: {
        'rate': lppRatePct.toStringAsFixed(0),
      },
    ));

    return BenchmarkComparison(
      cantonCode: benchmark.cantonCode,
      insights: insights,
      disclaimer: _disclaimer,
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Classify the tax burden index relative to Swiss average (100).
  /// Returns an ARB key suffix: 'benchmarkTaxLevelBelow', 'benchmarkTaxLevelAverage',
  /// or 'benchmarkTaxLevelAbove'.
  ///
  /// COMPLIANCE: These are factual classifications, not evaluative rankings.
  static String _taxLevel(double index) {
    if (index < 85) return 'benchmarkTaxLevelBelow';
    if (index > 115) return 'benchmarkTaxLevelAbove';
    return 'benchmarkTaxLevelAverage';
  }

  /// Format a CHF amount with Swiss apostrophe thousand separator.
  static String _fmtCHF(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write("'");
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
