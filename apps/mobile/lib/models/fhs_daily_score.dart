/// FHS Daily Score Model — Sprint S54.
///
/// Financial Health Score: daily engagement metric wrapping FRI (4-axis: L/F/R/S)
/// with daily freshness, trends, and WHOOP-inspired color gradient.
///
/// FHS = FRI total (0-100), enriched with temporal context:
///   - Level thresholds (critical / needsImprovement / good / excellent)
///   - Trend vs yesterday (up / stable / down)
///   - Delta vs yesterday and vs 7 days ago
///
/// Sources: LAVS art. 21-29, LPP art. 14-16, LIFD art. 38.
/// Outil educatif — ne constitue pas un conseil financier (LSFin).
library;

/// WHOOP-inspired level thresholds for FHS score.
enum FhsLevel { critical, needsImprovement, good, excellent }

/// Trend direction compared to previous day.
enum FhsTrend { up, stable, down }

/// Daily Financial Health Score snapshot.
///
/// Immutable value object. Created by [FinancialHealthScoreService.computeDaily].
class FhsDailyScore {
  /// Overall score 0-100 (same as FRI total).
  final double score;

  /// WHOOP-inspired level derived from [score].
  final FhsLevel level;

  /// Trend vs yesterday: up (+2), stable, down (-2).
  final FhsTrend trend;

  /// Score change vs yesterday (positive = improvement).
  final double deltaVsYesterday;

  /// Score change vs 7 days ago (positive = improvement).
  final double deltaVsWeekAgo;

  /// Timestamp of computation.
  final DateTime computedAt;

  /// Liquidity axis (0-25, from FRI L).
  final double liquidite;

  /// Fiscal efficiency axis (0-25, from FRI F).
  final double fiscalite;

  /// Retirement readiness axis (0-25, from FRI R).
  final double retraite;

  /// Structural risk axis (0-25, from FRI S).
  final double risque;

  const FhsDailyScore({
    required this.score,
    required this.level,
    required this.trend,
    required this.deltaVsYesterday,
    required this.deltaVsWeekAgo,
    required this.computedAt,
    required this.liquidite,
    required this.fiscalite,
    required this.retraite,
    required this.risque,
  });

  /// Derive [FhsLevel] from a score value.
  ///
  /// Thresholds (WHOOP-inspired):
  ///   < 40  → critical
  ///   < 60  → needsImprovement
  ///   < 80  → good
  ///   >= 80 → excellent
  static FhsLevel levelFromScore(double s) {
    if (s < 40) return FhsLevel.critical;
    if (s < 60) return FhsLevel.needsImprovement;
    if (s < 80) return FhsLevel.good;
    return FhsLevel.excellent;
  }

  /// Serialize to JSON-compatible map for SharedPreferences persistence.
  Map<String, dynamic> toJson() => {
        'score': score,
        'level': level.name,
        'trend': trend.name,
        'deltaVsYesterday': deltaVsYesterday,
        'deltaVsWeekAgo': deltaVsWeekAgo,
        'computedAt': computedAt.toIso8601String(),
        'liquidite': liquidite,
        'fiscalite': fiscalite,
        'retraite': retraite,
        'risque': risque,
      };

  /// Deserialize from JSON map.
  factory FhsDailyScore.fromJson(Map<String, dynamic> json) {
    return FhsDailyScore(
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      level: FhsLevel.values.firstWhere(
        (e) => e.name == json['level'],
        orElse: () => FhsLevel.critical,
      ),
      trend: FhsTrend.values.firstWhere(
        (e) => e.name == json['trend'],
        orElse: () => FhsTrend.stable,
      ),
      deltaVsYesterday: (json['deltaVsYesterday'] as num?)?.toDouble() ?? 0.0,
      deltaVsWeekAgo: (json['deltaVsWeekAgo'] as num?)?.toDouble() ?? 0.0,
      computedAt: DateTime.tryParse(json['computedAt'] as String? ?? '') ?? DateTime.now(),
      liquidite: (json['liquidite'] as num?)?.toDouble() ?? 0.0,
      fiscalite: (json['fiscalite'] as num?)?.toDouble() ?? 0.0,
      retraite: (json['retraite'] as num?)?.toDouble() ?? 0.0,
      risque: (json['risque'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
