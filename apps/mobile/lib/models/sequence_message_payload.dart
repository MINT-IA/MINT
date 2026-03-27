/// Lightweight UI payload for rendering a SequenceProgressCard in the chat.
///
/// Decoupled from service types (SequenceHandlerResult, SequenceRun) —
/// contains only what the renderer needs.
///
/// See: docs/RFC_AGENT_LOOP_STATEFUL.md §7
library;

/// Payload attached to a ChatMessage for rendering a SequenceProgressCard.
class SequenceMessagePayload {
  /// Template ID (e.g. 'housing_purchase').
  final String templateId;

  /// Current step ID (e.g. 'housing_02_epl').
  final String? currentStepId;

  /// Progress label (e.g. '2/4').
  final String progressLabel;

  /// Overall status: 'advance', 'complete', 'pause', 'skip', 'retry', 're_evaluate'.
  final String status;

  /// Whether the user can tap "Continue" to advance.
  final bool canAdvance;

  /// Whether the user can tap "Quit" to leave the sequence.
  final bool canQuit;

  /// Goal label key (ARB key for the goal name).
  final String goalLabelKey;

  const SequenceMessagePayload({
    required this.templateId,
    this.currentStepId,
    required this.progressLabel,
    required this.status,
    required this.canAdvance,
    required this.canQuit,
    required this.goalLabelKey,
  });
}
