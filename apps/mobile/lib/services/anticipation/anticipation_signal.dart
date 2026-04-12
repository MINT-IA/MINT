// ────────────────────────────────────────────────────────────
//  ANTICIPATION SIGNAL — Phase 04 / Moteur d'Anticipation
// ────────────────────────────────────────────────────────────
//
// Immutable data model for a proactive anticipation alert.
//
// Each signal is produced by AnticipationEngine.evaluate()
// and follows the ANT-03 educational format:
//   title + fact + legal source + simulator link
//
// Design: Pure data model, zero LLM, zero async (ANT-08).
// Pattern: Follows Nudge model from S61.
// ────────────────────────────────────────────────────────────

/// Educational alert template type (ANT-03).
///
/// Each template maps 1:1 to an [AnticipationTrigger] and defines
/// the alert format: title + fact + source reference + simulator link.
enum AlertTemplate {
  /// 3a versement deadline (December).
  fiscal3aDeadline,

  /// Cantonal tax declaration deadline.
  cantonalTaxDeadline,

  /// LPP rachat (buyback) window in Q4.
  lppRachatWindow,

  /// Salary increase detected — recalculate 3a.
  salaryIncrease3aRecalc,

  /// LPP bonification bracket boundary crossed.
  ageMilestoneLppBonification,
}

/// A single proactive anticipation signal.
///
/// Immutable value object produced by [AnticipationEngine.evaluate()].
/// Contains all data needed to render an educational alert card.
///
/// All text fields reference ARB keys (i18n via AppLocalizations).
/// [params] provides interpolation values for parameterised ARB strings.
///
/// Equality is based on [id] only (same trigger+date = same signal).
class AnticipationSignal {
  /// Unique identifier: `{trigger.name}_{yyyyMMdd}`.
  final String id;

  /// Alert template type determining the educational format.
  final AlertTemplate template;

  /// ARB key for the alert title.
  final String titleKey;

  /// ARB key for the educational fact text.
  final String factKey;

  /// Legal reference (e.g., "OPP3 art.\u00a07", "LPP art.\u00a079b").
  final String sourceRef;

  /// GoRouter path to the relevant simulator (e.g., "/pilier-3a").
  final String simulatorLink;

  /// Priority score (0-100) computed during ranking (Plan 02).
  /// Default 0.0, set via [copyWith] during ranking phase.
  final double priorityScore;

  /// Auto-dismiss after this datetime.
  final DateTime expiresAt;

  /// Optional i18n interpolation parameters for ARB strings.
  /// Key = ARB placeholder name, value = resolved string.
  final Map<String, String>? params;

  const AnticipationSignal({
    required this.id,
    required this.template,
    required this.titleKey,
    required this.factKey,
    required this.sourceRef,
    required this.simulatorLink,
    required this.priorityScore,
    required this.expiresAt,
    this.params,
  });

  /// Create a copy with updated [priorityScore] for ranking.
  AnticipationSignal copyWith({double? priorityScore}) {
    return AnticipationSignal(
      id: id,
      template: template,
      titleKey: titleKey,
      factKey: factKey,
      sourceRef: sourceRef,
      simulatorLink: simulatorLink,
      priorityScore: priorityScore ?? this.priorityScore,
      expiresAt: expiresAt,
      params: params,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnticipationSignal && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'AnticipationSignal(id: $id, template: ${template.name}, '
      'priority: $priorityScore)';
}
