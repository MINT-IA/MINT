/// ReturnContract — standardized callback when user returns from a screen.
///
/// When a user navigates back from any orchestrated surface (B or C type),
/// the RoutePlanner receives this contract so the Coach can react accordingly.
///
/// See docs/CHAT_TO_SCREEN_ORCHESTRATION_STRATEGY.md §7
library;

// ════════════════════════════════════════════════════════════════
//  OUTCOME ENUM
// ════════════════════════════════════════════════════════════════

/// The outcome of a user's interaction with an orchestrated screen.
///
/// - [completed]: user finished the flow or simulation (all steps done).
/// - [abandoned]: user navigated away without completing.
/// - [changedInputs]: user modified profile fields / hypothesis values.
enum ScreenOutcome {
  /// User completed the surface — simulation run, flow acknowledged, etc.
  completed,

  /// User left the surface without completing. Coach may propose alternative.
  abandoned,

  /// User changed hypothesis inputs or profile fields mid-screen.
  /// Triggers profile update + confidence recalculation.
  changedInputs,
}

// ════════════════════════════════════════════════════════════════
//  RETURN CONTRACT
// ════════════════════════════════════════════════════════════════

/// Standardized return value from any orchestrated MINT surface.
///
/// Produced by the screen and consumed by [RoutePlanner] / CapMemory loop.
///
/// Rules:
/// - [route] MUST match the canonical GoRouter route string.
/// - [updatedFields] keys use the same dotted-path convention as
///   [CoachProfile.dataSources] (e.g. 'prevoyance.avoirLppTotal').
/// - [confidenceDelta] is a signed value in [-1.0, 1.0]. Positive means
///   the interaction raised data confidence (new certificate imported).
///   Negative means the user corrected assumptions downward.
/// - [nextCapSuggestion] is an optional CapEngine cap identifier string
///   (e.g. 'lpp_rachat', 'objectif_3a') that the Coach should surface next.
class ScreenReturn {
  /// The canonical GoRouter route of the screen that was navigated.
  /// Example: '/rente-vs-capital', '/divorce', '/budget'.
  final String route;

  /// How the user left the screen.
  final ScreenOutcome outcome;

  /// Profile fields that were updated during the session, if any.
  ///
  /// Keys follow the CoachProfile dotted-path convention.
  /// Example: {'prevoyance.avoirLppTotal': 70377.0, 'canton': 'VS'}
  final Map<String, dynamic>? updatedFields;

  /// Signed change in confidence score caused by this interaction.
  ///
  /// Range [-1.0, 1.0]. Null if no confidence change occurred.
  /// Positive: user provided validated data (e.g. scanned LPP certificate).
  /// Negative: user corrected an over-estimated assumption.
  final double? confidenceDelta;

  /// Identifier of the next CapEngine cap to suggest, if any.
  ///
  /// Set by the screen when it detects a natural follow-up action.
  /// Example: after completing '/3a-deep/staggered-withdrawal', suggest
  /// 'lpp_rachat' if rachat data is missing.
  final String? nextCapSuggestion;

  const ScreenReturn({
    required this.route,
    required this.outcome,
    this.updatedFields,
    this.confidenceDelta,
    this.nextCapSuggestion,
  });

  /// Convenience constructor for a completed return with no side effects.
  const ScreenReturn.completed({
    required String route,
    Map<String, dynamic>? updatedFields,
    double? confidenceDelta,
    String? nextCapSuggestion,
  }) : this(
          route: route,
          outcome: ScreenOutcome.completed,
          updatedFields: updatedFields,
          confidenceDelta: confidenceDelta,
          nextCapSuggestion: nextCapSuggestion,
        );

  /// Convenience constructor for an abandoned return.
  const ScreenReturn.abandoned({required String route})
      : this(
          route: route,
          outcome: ScreenOutcome.abandoned,
        );

  /// Convenience constructor when user only changed inputs (no completion).
  const ScreenReturn.changedInputs({
    required String route,
    required Map<String, dynamic> updatedFields,
    double? confidenceDelta,
  }) : this(
          route: route,
          outcome: ScreenOutcome.changedInputs,
          updatedFields: updatedFields,
          confidenceDelta: confidenceDelta,
        );

  /// Whether any profile fields were updated during this session.
  bool get hasUpdates => updatedFields != null && updatedFields!.isNotEmpty;

  /// Whether a confidence change should be applied.
  bool get hasConfidenceDelta =>
      confidenceDelta != null && confidenceDelta != 0.0;

  /// Whether a follow-up cap is suggested.
  bool get hasNextCap =>
      nextCapSuggestion != null && nextCapSuggestion!.isNotEmpty;

  @override
  String toString() => 'ScreenReturn('
      'route: $route, '
      'outcome: $outcome, '
      'updatedFields: $updatedFields, '
      'confidenceDelta: $confidenceDelta, '
      'nextCapSuggestion: $nextCapSuggestion'
      ')';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScreenReturn &&
        other.route == route &&
        other.outcome == outcome &&
        other.confidenceDelta == confidenceDelta &&
        other.nextCapSuggestion == nextCapSuggestion;
  }

  @override
  int get hashCode => Object.hash(
        route,
        outcome,
        confidenceDelta,
        nextCapSuggestion,
      );
}
