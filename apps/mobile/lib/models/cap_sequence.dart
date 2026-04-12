/// CapSequence — visible multi-step plan toward the user's financial goal.
///
/// A CapSequence shows the user where they are in their financial journey:
/// "3/10 étapes clarifiées" — progress visible, not just today's priority.
///
/// Spec: docs/MINT_CAP_ENGINE_SPEC.md §14
library;

// ════════════════════════════════════════════════════════════════
//  ENUMS
// ════════════════════════════════════════════════════════════════

/// Status of a single step in the plan.
enum CapStepStatus {
  /// User has completed this step (data confirmed or flow visited).
  completed,

  /// The step the user should work on now.
  current,

  /// A future step — not yet reachable or relevant.
  upcoming,

  /// A step that cannot be completed until a prerequisite is resolved.
  blocked,
}

// ════════════════════════════════════════════════════════════════
//  STEP MODEL
// ════════════════════════════════════════════════════════════════

/// One step inside a CapSequence.
///
/// Immutable. Pure data — no side effects.
class CapStep {
  /// Stable unique identifier for this step (e.g. "ret_01_salary").
  final String id;

  /// 1-based display order in the sequence.
  final int order;

  /// ARB key for the step title (e.g. "capStepRetirement01Title").
  /// Never hardcoded text — always resolved via S.of(context).
  final String titleKey;

  /// ARB key for the step description. Optional.
  final String? descriptionKey;

  /// Current status of this step.
  final CapStepStatus status;

  /// GoRouter intent tag for the action screen (e.g. "/pilier-3a").
  /// Null for steps that have no direct screen (e.g. "consult specialist").
  final String? intentTag;

  /// Estimated monthly CHF impact if this step is acted on.
  /// Null if impact cannot be estimated without more profile data.
  final double? impactEstimate;

  const CapStep({
    required this.id,
    required this.order,
    required this.titleKey,
    this.descriptionKey,
    required this.status,
    this.intentTag,
    this.impactEstimate,
  });

  /// Returns a copy with a different status.
  CapStep withStatus(CapStepStatus newStatus) => CapStep(
        id: id,
        order: order,
        titleKey: titleKey,
        descriptionKey: descriptionKey,
        status: newStatus,
        intentTag: intentTag,
        impactEstimate: impactEstimate,
      );
}

// ════════════════════════════════════════════════════════════════
//  SEQUENCE MODEL
// ════════════════════════════════════════════════════════════════

/// A visible multi-step plan toward the user's financial goal.
///
/// Immutable. Built by [CapSequenceEngine.build()].
/// Consumed by [CapSequenceCard] in the Pulse screen.
class CapSequence {
  /// Intent tag of the overall goal (e.g. "retirement_choice", "budget_overview").
  final String goalId;

  /// Ordered list of steps (sorted by [CapStep.order]).
  final List<CapStep> steps;

  /// Number of steps with status [CapStepStatus.completed].
  final int completedCount;

  /// Total number of steps in this sequence.
  final int totalCount;

  /// Progress ratio — [completedCount] / [totalCount]. Range: 0.0–1.0.
  final double progressPercent;

  const CapSequence({
    required this.goalId,
    required this.steps,
    required this.completedCount,
    required this.totalCount,
    required this.progressPercent,
  });

  /// True when every step is completed.
  bool get isComplete => completedCount >= totalCount && totalCount > 0;

  /// The step currently marked as [CapStepStatus.current].
  /// Null if no step has that status (e.g. all completed or all blocked).
  CapStep? get currentStep =>
      steps.where((s) => s.status == CapStepStatus.current).firstOrNull;

  /// The first upcoming step (after the current step).
  CapStep? get nextStep =>
      steps.where((s) => s.status == CapStepStatus.upcoming).firstOrNull;

  /// Convenience: true when the sequence has at least one step.
  bool get hasSteps => steps.isNotEmpty;

  /// Factory: build a CapSequence from a raw step list.
  ///
  /// Automatically computes [completedCount], [totalCount], and [progressPercent].
  /// Promotes the first non-completed step to [CapStepStatus.current] if
  /// no step is already marked current.
  factory CapSequence.fromSteps({
    required String goalId,
    required List<CapStep> steps,
  }) {
    if (steps.isEmpty) {
      return CapSequence(
        goalId: goalId,
        steps: const [],
        completedCount: 0,
        totalCount: 0,
        progressPercent: 0.0,
      );
    }

    // Sort by order for deterministic output.
    final sorted = [...steps]..sort((a, b) => a.order.compareTo(b.order));

    final completed = sorted.where((s) => s.status == CapStepStatus.completed).length;
    final total = sorted.length;

    // If no step is already current, promote the first upcoming/blocked step.
    final hasCurrent = sorted.any((s) => s.status == CapStepStatus.current);
    List<CapStep> finalSteps = sorted;
    if (!hasCurrent) {
      final firstNonCompleted =
          sorted.indexWhere((s) => s.status != CapStepStatus.completed);
      if (firstNonCompleted >= 0 &&
          sorted[firstNonCompleted].status != CapStepStatus.blocked) {
        finalSteps = [
          for (int i = 0; i < sorted.length; i++)
            if (i == firstNonCompleted)
              sorted[i].withStatus(CapStepStatus.current)
            else
              sorted[i],
        ];
      }
    }

    return CapSequence(
      goalId: goalId,
      steps: finalSteps,
      completedCount: completed,
      totalCount: total,
      progressPercent: total > 0 ? completed / total : 0.0,
    );
  }
}
