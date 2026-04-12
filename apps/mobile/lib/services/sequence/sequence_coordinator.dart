/// SequenceCoordinator — decides what happens after each step in a guided sequence.
///
/// NOT a pure function — needs profile + readiness context.
/// Integrates with RoutePlanner, not parallel to it.
///
/// See: docs/RFC_AGENT_LOOP_STATEFUL.md §3.5
library;

import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/models/sequence_run.dart';
import 'package:mint_mobile/models/sequence_template.dart';
import 'package:mint_mobile/services/navigation/screen_registry.dart';

// ════════════════════════════════════════════════════════════════
//  ACTION — what the coordinator decides
// ════════════════════════════════════════════════════════════════

/// Result of the coordinator's decision after a step return.
sealed class SequenceAction {
  const SequenceAction();
}

/// Advance to the next step.
class AdvanceAction extends SequenceAction {
  final SequenceStepDef nextStep;
  final String route;
  final Map<String, dynamic> prefill;
  final String progressLabel;

  const AdvanceAction({
    required this.nextStep,
    required this.route,
    required this.prefill,
    required this.progressLabel,
  });
}

/// Sequence is complete — all steps done.
class CompleteAction extends SequenceAction {
  final Map<String, Map<String, dynamic>> allOutputs;

  const CompleteAction({required this.allOutputs});
}

/// User abandoned — pause and offer resumption.
class PauseAction extends SequenceAction {
  final bool canResume;

  const PauseAction({required this.canResume});
}

/// Skip this step (optional, too many attempts).
class SkipAction extends SequenceAction {
  final String stepId;

  const SkipAction({required this.stepId});
}

/// Retry the same step (abandoned once, can try again).
class RetryAction extends SequenceAction {
  final String stepId;

  const RetryAction({required this.stepId});
}

/// Re-evaluate: profile changed, some steps may be invalidated.
class ReEvaluateAction extends SequenceAction {
  final List<String> invalidatedStepIds;

  const ReEvaluateAction({required this.invalidatedStepIds});
}

// ════════════════════════════════════════════════════════════════
//  COORDINATOR
// ════════════════════════════════════════════════════════════════

/// Decides the next action after a step returns in a guided sequence.
///
/// Takes all necessary context (template, run, return, proposals)
/// to make a complete decision. Does NOT read from SharedPreferences
/// or providers — caller passes everything needed.
class SequenceCoordinator {
  SequenceCoordinator._();

  /// Maximum proposals per step before skip/pause.
  static const int maxProposals = 2;

  /// Decide the next action after a step return.
  ///
  /// [template] — the sequence definition.
  /// [run] — current runtime state.
  /// [stepReturn] — what the screen returned.
  /// [proposalCount] — how many times the current step was proposed in this run.
  static SequenceAction decide({
    required SequenceTemplate template,
    required SequenceRun run,
    required ScreenReturn stepReturn,
    required int proposalCount,
  }) {
    final activeStepId = run.activeStepId;
    if (activeStepId == null) {
      return const PauseAction(canResume: false);
    }

    final currentStepDef = template.steps
        .where((s) => s.id == activeStepId)
        .firstOrNull;
    if (currentStepDef == null) {
      return const PauseAction(canResume: false);
    }

    switch (stepReturn.outcome) {
      case ScreenOutcome.completed:
        return _handleCompleted(template, run, currentStepDef, stepReturn);

      case ScreenOutcome.abandoned:
        return _handleAbandoned(currentStepDef, proposalCount);

      case ScreenOutcome.changedInputs:
        return _handleChanged(template, run, stepReturn);
    }
  }

  /// Maps an intent tag → user intent to a sequence template.
  /// Returns null for single-screen intents.
  static SequenceTemplate? templateForIntent(String intentTag) =>
      SequenceTemplate.templateForIntent(intentTag);

  // ── PRIVATE ────────────────────────────────────────────────────

  static SequenceAction _handleCompleted(
    SequenceTemplate template,
    SequenceRun run,
    SequenceStepDef currentStep,
    ScreenReturn stepReturn,
  ) {
    // Merge outputs into run
    final outputs = stepReturn.stepOutputs ?? {};
    final updatedRun = run.completeStep(currentStep.id, outputs);

    // Find next actionable step
    final nextStepDef = _findNextStep(template, updatedRun);
    if (nextStepDef == null) {
      // Either all done, or next step is blocked
      if (_hasBlockedStep(template, updatedRun)) {
        // Blocked → pause, user must resolve the blocker first
        return const PauseAction(canResume: true);
      }
      // All steps done
      return CompleteAction(allOutputs: updatedRun.stepOutputs);
    }

    // Resolve route via ScreenRegistry (fail-safe)
    final entry = MintScreenRegistry.findByIntentStatic(nextStepDef.intentTag);
    if (entry == null) {
      // Unknown intent → pause, never navigate blindly
      return const PauseAction(canResume: true);
    }

    // Build prefill from accumulated outputs
    final prefill = _buildPrefill(template, updatedRun, nextStepDef);
    final completed = updatedRun.completedCount;
    final total = updatedRun.totalCount;

    return AdvanceAction(
      nextStep: nextStepDef,
      route: entry.route,
      prefill: prefill,
      progressLabel: '$completed/$total',
    );
  }

  static SequenceAction _handleAbandoned(
    SequenceStepDef currentStep,
    int proposalCount,
  ) {
    if (proposalCount >= maxProposals) {
      // Too many attempts
      if (currentStep.isOptional) {
        return SkipAction(stepId: currentStep.id);
      }
      return const PauseAction(canResume: true);
    }
    return RetryAction(stepId: currentStep.id);
  }

  static SequenceAction _handleChanged(
    SequenceTemplate template,
    SequenceRun run,
    ScreenReturn stepReturn,
  ) {
    final hasChanges = stepReturn.updatedFields?.isNotEmpty ?? false;
    if (!hasChanges) {
      return const PauseAction(canResume: true);
    }

    // V1: conservatively invalidate ALL completed steps when profile changes.
    // We don't have a reverse mapping (profile field → step dependency),
    // so any profile change could affect any step's outputs.
    // This is safe but coarse — may force unnecessary reruns in long sequences.
    // TODO(P2): add inputDependencies to SequenceStepDef for targeted invalidation.
    // This is safe: re-running a step with updated profile data is always
    // better than silently using stale outputs.
    final invalidated = <String>[];
    for (final step in template.steps) {
      if (run.stepStates[step.id] == StepRunState.completed &&
          run.stepOutputs.containsKey(step.id)) {
        invalidated.add(step.id);
      }
    }

    if (invalidated.isEmpty) {
      // Profile changed but no step had outputs → just pause for user decision
      return const PauseAction(canResume: true);
    }

    return ReEvaluateAction(invalidatedStepIds: invalidated);
  }

  /// Find the next actionable step (pending, not completed/skipped/blocked).
  ///
  /// Returns null in two cases:
  /// - All steps are done → sequence complete
  /// - Next step is blocked → caller should pause (returned via _blockedStepId)
  ///
  /// Blocked steps are NEVER skipped silently — they require prerequisite
  /// resolution. The caller must check [_isNextStepBlocked] to differentiate
  /// "complete" from "blocked".
  static SequenceStepDef? _findNextStep(
    SequenceTemplate template,
    SequenceRun run,
  ) {
    for (final step in template.steps) {
      final state = run.stepStates[step.id];
      if (state == StepRunState.blocked) {
        // A blocked step means the sequence cannot proceed — return null
        // so the caller pauses. Never silently skip a required blocked step.
        return null;
      }
      if (state == StepRunState.pending) {
        // Skip inline summary steps (no screen to route to)
        if (step.intentTag == '_inline_summary') continue;
        return step;
      }
    }
    // Check if there's an inline summary as the last step
    final lastStep = template.steps.lastOrNull;
    if (lastStep != null &&
        lastStep.intentTag == '_inline_summary' &&
        run.stepStates[lastStep.id] != StepRunState.completed) {
      return null; // Signal completion — summary handled by coach inline
    }
    return null;
  }

  /// Whether any remaining step (not completed/skipped) is blocked.
  static bool _hasBlockedStep(SequenceTemplate template, SequenceRun run) {
    for (final step in template.steps) {
      if (run.stepStates[step.id] == StepRunState.blocked) return true;
    }
    return false;
  }

  /// Build prefill map for the next step from accumulated outputs.
  ///
  /// Walks through all completed steps' outputs and maps them via
  /// the step's outputMapping to build the prefill keys expected
  /// by the next step's screen.
  static Map<String, dynamic> _buildPrefill(
    SequenceTemplate template,
    SequenceRun run,
    SequenceStepDef nextStep,
  ) {
    final prefill = <String, dynamic>{};

    // Collect ALL outputs from completed steps
    for (final step in template.steps) {
      final stepOutputs = run.stepOutputs[step.id];
      if (stepOutputs == null) continue;

      // Apply output mapping: source key → target key
      for (final mapping in step.outputMapping.entries) {
        final sourceKey = mapping.key;
        final targetKey = mapping.value;
        if (stepOutputs.containsKey(sourceKey)) {
          prefill[targetKey] = stepOutputs[sourceKey];
        }
      }
    }

    return prefill;
  }
}
