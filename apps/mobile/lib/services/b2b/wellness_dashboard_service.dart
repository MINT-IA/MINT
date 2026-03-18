/// Wellness Dashboard Service — Sprint S71-S72.
///
/// HR-facing aggregated wellness metrics. NEVER exposes individual data.
///
/// Privacy rules (NON-NEGOTIABLE):
/// - Minimum 10 participants for ANY aggregate
/// - NO individual data ever exposed to HR
/// - NO department-level breakdown (could identify individuals)
/// - NO names, emails, employee IDs in any output
/// - Opt-in only: employees must explicitly consent
/// - Employee can leave at any time, data immediately excluded
///
/// Sources: nLPD art. 6, 31. Outil éducatif (LSFin).
library;

// ─────────────────────────────────────────────────────────────────────
//  Models
// ─────────────────────────────────────────────────────────────────────

/// Minimum number of participants for privacy-safe aggregation.
const int kMinParticipants = 10;

/// Anonymized data from a single employee (opt-in).
///
/// NEVER contains: name, department, email, employee ID, salary,
/// NPA, employer name, or any PII.
class AnonymizedEmployeeData {
  final double? fhsScore;
  final double? confidenceScore;
  final bool has3a;
  final double? epargneRate;
  final List<String> viewedTopics;

  const AnonymizedEmployeeData({
    this.fhsScore,
    this.confidenceScore,
    this.has3a = false,
    this.epargneRate,
    this.viewedTopics = const [],
  });
}

/// Aggregated wellness metrics for HR dashboard.
///
/// All values are averages/rates across the cohort.
/// No individual data is recoverable from this object.
class AggregatedWellness {
  /// Organization ID for data isolation traceability.
  final String organizationId;
  final int totalParticipants;
  final double avgFhsScore;
  final double avgConfidenceScore;
  final double participation3aRate;
  final double avgEpargneRate;
  final Map<String, int> topTopics;
  final String generatedAt;
  final String disclaimer;

  const AggregatedWellness({
    required this.organizationId,
    required this.totalParticipants,
    required this.avgFhsScore,
    required this.avgConfidenceScore,
    required this.participation3aRate,
    required this.avgEpargneRate,
    required this.topTopics,
    required this.generatedAt,
    required this.disclaimer,
  });
}

// ─────────────────────────────────────────────────────────────────────
//  Service
// ─────────────────────────────────────────────────────────────────────

/// Service to generate anonymized, aggregated wellness dashboards.
///
/// Usage:
/// ```dart
/// final agg = await WellnessDashboardService.generateAggregate(
///   data: employeeList,
/// );
/// if (agg != null) { /* display to HR */ }
/// ```
class WellnessDashboardService {
  WellnessDashboardService._();

  /// Standard disclaimer attached to every aggregate.
  static const String kDisclaimer =
      'Données agrégées et anonymisées\u00a0— aucune donnée individuelle '
      'n\u2019est accessible. Outil éducatif, ne constitue pas un conseil '
      'financier (LSFin). Minimum $kMinParticipants participants requis.';

  /// Check if the participant count meets the privacy threshold.
  static bool isPrivacySafe(int participantCount) =>
      participantCount >= kMinParticipants;

  /// Generate an anonymized aggregate from opted-in employee data.
  ///
  /// [organizationId] is REQUIRED and enforces data isolation.
  /// The caller MUST ensure [data] belongs to the specified org.
  ///
  /// Returns `null` if:
  /// - [data] is empty
  /// - fewer than [minimumParticipants] entries (privacy protection)
  /// - all scores are null (no usable data)
  /// - [organizationId] is empty (data isolation violation)
  static Future<AggregatedWellness?> generateAggregate({
    required String organizationId,
    required List<AnonymizedEmployeeData> data,
    int minimumParticipants = kMinParticipants,
    DateTime? now,
  }) async {
    // Data isolation: refuse to aggregate without an org scope.
    if (organizationId.trim().isEmpty) return null;
    if (data.isEmpty) return null;
    if (data.length < minimumParticipants) return null;

    // ── FHS average ──
    final fhsValues = data
        .where((e) => e.fhsScore != null)
        .map((e) => e.fhsScore!)
        .toList();
    if (fhsValues.isEmpty) return null;
    final avgFhs = fhsValues.reduce((a, b) => a + b) / fhsValues.length;

    // ── Confidence average ──
    final confValues = data
        .where((e) => e.confidenceScore != null)
        .map((e) => e.confidenceScore!)
        .toList();
    final avgConf = confValues.isEmpty
        ? 0.0
        : confValues.reduce((a, b) => a + b) / confValues.length;

    // ── 3a participation rate ──
    final count3a = data.where((e) => e.has3a).length;
    final rate3a = count3a / data.length;

    // ── Epargne rate average ──
    final epargneValues = data
        .where((e) => e.epargneRate != null)
        .map((e) => e.epargneRate!)
        .toList();
    final avgEpargne = epargneValues.isEmpty
        ? 0.0
        : epargneValues.reduce((a, b) => a + b) / epargneValues.length;

    // ── Top topics ──
    final topicCounts = <String, int>{};
    for (final e in data) {
      for (final topic in e.viewedTopics) {
        topicCounts[topic] = (topicCounts[topic] ?? 0) + 1;
      }
    }
    // Sort by count descending, take top 10.
    final sortedTopics = topicCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = Map.fromEntries(sortedTopics.take(10));

    final ts = (now ?? DateTime.now()).toIso8601String();

    return AggregatedWellness(
      organizationId: organizationId,
      totalParticipants: data.length,
      avgFhsScore: _round2(avgFhs),
      avgConfidenceScore: _round2(avgConf),
      participation3aRate: _round2(rate3a * 100),
      avgEpargneRate: _round2(avgEpargne),
      topTopics: top,
      generatedAt: ts,
      disclaimer: kDisclaimer,
    );
  }

  /// Round to 2 decimal places.
  static double _round2(double v) =>
      (v * 100).roundToDouble() / 100;
}
