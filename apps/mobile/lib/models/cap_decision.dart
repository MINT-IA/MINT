/// Cap du jour — decision model for the CapEngine.
///
/// One cap = one priority, one reason, one action.
/// Spec: docs/MINT_CAP_ENGINE_SPEC.md
library;

/// The 5 kinds of cap the engine can produce.
enum CapKind {
  /// Missing data blocks quality — push toward enrichment.
  complete,

  /// Risk or imbalance needs attention — budget, debt, protection.
  correct,

  /// A concrete lever improves the situation — fiscal, retirement.
  optimize,

  /// A protection / compliance / timing risk exists.
  secure,

  /// A life event or horizon justifies preparation.
  prepare,
}

/// How the CTA should be executed.
enum CtaMode {
  /// Navigate to a deterministic flow screen.
  route,

  /// Open coach with an injected prompt.
  coach,

  /// Open a capture / enrichment flow.
  capture,
}

/// A supporting signal shown alongside the main cap.
class CapSignal {
  final String label;
  final String value;
  final String? route;

  const CapSignal({
    required this.label,
    required this.value,
    this.route,
  });
}

/// The single output of CapEngine.compute().
///
/// Represents the most useful thing MINT can propose right now.
class CapDecision {
  /// What kind of cap this is.
  final CapKind kind;

  /// Priority score (higher = more urgent). Used for ranking candidates.
  final double priorityScore;

  /// 4-9 words. The dominant message.
  final String headline;

  /// 1 sentence. Why this matters now.
  final String whyNow;

  /// 3-5 words. The button label.
  final String ctaLabel;

  /// How to execute the CTA.
  final CtaMode ctaMode;

  /// GoRouter route (when ctaMode == route).
  final String? ctaRoute;

  /// Prompt to inject into coach (when ctaMode == coach).
  final String? coachPrompt;

  /// Capture type (when ctaMode == capture).
  final String? captureType;

  /// 2-8 words. What changes if the user acts.
  final String? expectedImpact;

  /// Confidence label (e.g. "confiance 72%").
  final String? confidenceLabel;

  /// Data fields that block a better cap.
  final List<String> blockingData;

  /// Secondary signals shown below the cap.
  final List<CapSignal> supportingSignals;

  /// IDs of ResponseCards that contributed to this cap.
  final List<String> sourceCards;

  const CapDecision({
    required this.kind,
    required this.priorityScore,
    required this.headline,
    required this.whyNow,
    required this.ctaLabel,
    required this.ctaMode,
    this.ctaRoute,
    this.coachPrompt,
    this.captureType,
    this.expectedImpact,
    this.confidenceLabel,
    this.blockingData = const [],
    this.supportingSignals = const [],
    this.sourceCards = const [],
  });
}
