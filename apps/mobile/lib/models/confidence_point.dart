/// A dated snapshot of the 4-axis confidence score.
///
/// D5 — North Star « évolution visible ». The confidence score
/// ([EnhancedConfidence]) is recomputed on every render but was never
/// historised, so no « toi d'avant vs toi maintenant » curve was possible.
/// This model is the persisted unit that makes the curve possible: one dated
/// point per day, carrying the combined score and its 4 axes.
///
/// Stored locally by [ConfidenceHistoryService]. Never leaves the device.
library;

/// Immutable dated confidence measurement (all axes on a 0-100 scale).
class ConfidencePoint {
  /// When this measurement was captured (day-granular in the history store).
  final DateTime date;

  /// Combined score: geometric mean of the 4 axes (0-100).
  final double combined;

  /// Completeness axis (0-100): how much profile data is present.
  final double completeness;

  /// Accuracy axis (0-100): quality of the data sources.
  final double accuracy;

  /// Freshness axis (0-100): how recent the data is.
  final double freshness;

  /// Understanding axis (0-100): financial-education engagement.
  final double understanding;

  /// What produced this point (e.g. 'profile_load', 'document_scan',
  /// 'check_in'). Diagnostic only — used to name a milestone on the curve.
  final String trigger;

  const ConfidencePoint({
    required this.date,
    required this.combined,
    required this.completeness,
    required this.accuracy,
    required this.freshness,
    required this.understanding,
    required this.trigger,
  });

  /// Day key `yyyy-MM-dd` used for de-duplication in the history store.
  String get dayKey =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'combined': combined,
        'completeness': completeness,
        'accuracy': accuracy,
        'freshness': freshness,
        'understanding': understanding,
        'trigger': trigger,
      };

  factory ConfidencePoint.fromJson(Map<String, dynamic> json) {
    double axis(String key) => (json[key] as num?)?.toDouble() ?? 0.0;
    return ConfidencePoint(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      combined: axis('combined'),
      completeness: axis('completeness'),
      accuracy: axis('accuracy'),
      freshness: axis('freshness'),
      understanding: axis('understanding'),
      trigger: json['trigger'] as String? ?? 'unknown',
    );
  }
}
