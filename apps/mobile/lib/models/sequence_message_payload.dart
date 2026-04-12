/// Lightweight UI payload for rendering a SequenceProgressCard in the chat.
///
/// Decoupled from service types (SequenceHandlerResult, SequenceRun) —
/// contains only what the renderer needs to display progress AND navigate.
///
/// See: docs/RFC_AGENT_LOOP_STATEFUL.md §7
library;

import 'package:flutter/material.dart';

/// One line in the sequence completion summary.
class SequenceSummaryItem {
  final IconData icon;
  final String label;
  final String value;

  const SequenceSummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}

/// Payload attached to a ChatMessage for rendering a SequenceProgressCard.
class SequenceMessagePayload {
  /// Template ID (e.g. 'housing_purchase').
  final String templateId;

  /// Current step ID (e.g. 'housing_02_epl').
  final String? currentStepId;

  /// Progress label (e.g. '2/4').
  final String progressLabel;

  /// Overall status: 'step_completed', 'completed', 'paused', etc.
  final String status;

  /// Whether the user can tap "Continue" to advance.
  final bool canAdvance;

  /// Whether the user can tap "Quit" to leave the sequence.
  final bool canQuit;

  /// Resolved goal label (human-readable, already localized).
  final String goalLabel;

  // ── NAVIGATION DATA (populated when canAdvance == true) ────────

  /// GoRouter route for the next step (e.g. '/epl').
  /// Non-null when canAdvance is true.
  final String? nextRoute;

  /// Step ID for the next step (e.g. 'housing_02_epl').
  /// Passed in GoRouter.extra so the screen emits Tier A ScreenReturn.
  final String? nextStepId;

  /// Prefill data from accumulated step outputs.
  /// Passed in GoRouter.extra so the screen initializes with prior results.
  final Map<String, dynamic>? prefill;

  /// Run ID of the active sequence.
  /// Passed in GoRouter.extra for Tier A identification.
  final String? runId;

  /// Completion summary items (populated only when status == 'completed').
  /// Each item shows one key result from the completed sequence.
  final List<SequenceSummaryItem>? summaryItems;

  const SequenceMessagePayload({
    required this.templateId,
    this.currentStepId,
    required this.progressLabel,
    required this.status,
    required this.canAdvance,
    required this.canQuit,
    required this.goalLabel,
    this.nextRoute,
    this.nextStepId,
    this.prefill,
    this.runId,
    this.summaryItems,
  });
}
