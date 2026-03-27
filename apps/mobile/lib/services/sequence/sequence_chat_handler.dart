/// SequenceChatHandler — bridge between coach chat and guided sequences.
///
/// Encapsulates ALL sequence-related logic that the CoachChatScreen needs.
/// The chat screen calls this handler at two injection points:
/// 1. _handleRouteReturn → handleStepReturn()
/// 2. _onRealtimeScreenReturn → handleRealtimeReturn()
///
/// This keeps the 3000+ line chat screen untouched except for 2 calls.
///
/// See: docs/RFC_AGENT_LOOP_STATEFUL.md §3.6, §6.2
library;

import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/models/sequence_run.dart';
import 'package:mint_mobile/models/sequence_template.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/sequence/sequence_coordinator.dart';
import 'package:mint_mobile/services/sequence/sequence_store.dart';

/// Result of handling a step return in a guided sequence.
///
/// The chat screen reads this to decide what to show.
class SequenceHandlerResult {
  /// The action decided by the coordinator.
  final SequenceAction action;

  /// The updated run (after step completion/skip/etc).
  final SequenceRun updatedRun;

  /// The template for label resolution.
  final SequenceTemplate template;

  const SequenceHandlerResult({
    required this.action,
    required this.updatedRun,
    required this.template,
  });
}

/// Handles guided sequence logic for CoachChatScreen.
///
/// Stateless — all state is in SequenceStore (SharedPreferences).
/// Pure bridge: loads state, calls coordinator, saves state, returns result.
class SequenceChatHandler {
  SequenceChatHandler._();

  /// Check if a guided sequence is currently active.
  ///
  /// Cheap check — loads from SharedPreferences.
  static Future<bool> isSequenceActive() async {
    final run = await SequenceStore.load();
    return run != null && run.isActive;
  }

  /// Handle a step return from a RouteSuggestionCard (explicit coach CTA).
  ///
  /// Returns null if no sequence is active — caller should proceed
  /// with normal _handleRouteReturn behavior.
  ///
  /// Returns a [SequenceHandlerResult] if a sequence is active — caller
  /// should use this to render the next step or summary.
  static Future<SequenceHandlerResult?> handleStepReturn(
    ScreenOutcome outcome, {
    Map<String, dynamic>? stepOutputs,
    Map<String, dynamic>? updatedFields,
  }) async {
    final run = await SequenceStore.load();
    if (run == null || !run.isActive) return null;

    final template = SequenceTemplate.templateForIntent(run.templateId);
    // Also try matching by templateId directly (templates use id, not intentTag)
    final resolvedTemplate = template ??
        _templateById(run.templateId);
    if (resolvedTemplate == null) return null;

    // Build a ScreenReturn from the outcome + outputs + updatedFields
    final screenReturn = ScreenReturn(
      route: '', // Route is not needed by coordinator — it uses step ID
      outcome: outcome,
      stepOutputs: stepOutputs,
      updatedFields: updatedFields,
    );

    // Load proposal count for anti-loop
    final capMem = await CapMemoryStore.load();
    final activeStepId = run.activeStepId;
    final proposals = activeStepId != null
        ? capMem.proposalCount(run.runId, activeStepId)
        : 0;

    // Decide next action
    final action = SequenceCoordinator.decide(
      template: resolvedTemplate,
      run: run,
      stepReturn: screenReturn,
      proposalCount: proposals,
    );

    // Apply action + persist + increment proposals for next step
    final updatedRun = _applyAction(action, run, outcome, stepOutputs);
    await _persistAndTrackProposals(action, updatedRun, run.runId, capMem);

    return SequenceHandlerResult(
      action: action,
      updatedRun: updatedRun,
      template: resolvedTemplate,
    );
  }

  /// Handle a realtime ScreenReturn from the stream.
  ///
  /// Returns a [SequenceHandlerResult] if the sequence consumed this event
  /// (caller should NOT proceed with debounced legacy behavior).
  /// Returns null if no sequence is active (caller proceeds normally).
  ///
  /// Unlike handleStepReturn (which receives a simple outcome), this
  /// receives a full ScreenReturn with stepOutputs and updatedFields.
  /// It delegates to the same SequenceCoordinator for consistent decisions.
  static Future<SequenceHandlerResult?> handleRealtimeReturn(
    ScreenReturn ret,
  ) async {
    final run = await SequenceStore.load();
    if (run == null || !run.isActive) return null;

    final template = _templateById(run.templateId);
    if (template == null) return null;

    // Load proposal count for anti-loop
    final capMem = await CapMemoryStore.load();
    final activeStepId = run.activeStepId;
    final proposals = activeStepId != null
        ? capMem.proposalCount(run.runId, activeStepId)
        : 0;

    // Delegate to coordinator
    final action = SequenceCoordinator.decide(
      template: template,
      run: run,
      stepReturn: ret,
      proposalCount: proposals,
    );

    // Apply action + persist + increment proposals for next step
    final updatedRun = _applyAction(action, run, ret.outcome, ret.stepOutputs);
    await _persistAndTrackProposals(action, updatedRun, run.runId, capMem);

    return SequenceHandlerResult(
      action: action,
      updatedRun: updatedRun,
      template: template,
    );
  }

  /// Start a new guided sequence from an intent tag.
  ///
  /// Returns the created run, or null if no template matches.
  static Future<SequenceRun?> startSequence(String intentTag) async {
    final template = SequenceTemplate.templateForIntent(intentTag);
    if (template == null) return null;

    final run = SequenceRun.start(
      runId: '${template.id}_${DateTime.now().millisecondsSinceEpoch}',
      templateId: template.id,
      stepIds: template.steps.map((s) => s.id).toList(),
    );

    await SequenceStore.save(run);

    // Record first step proposal
    final capMem = await CapMemoryStore.load();
    final firstStepId = template.steps.first.id;
    final updated = capMem.incrementProposal(run.runId, firstStepId);
    await CapMemoryStore.save(updated);

    return run;
  }

  /// Quit the active sequence (user explicitly chose to leave).
  static Future<void> quitSequence() async {
    final run = await SequenceStore.load();
    if (run == null) return;
    final capMem = await CapMemoryStore.load();
    final clearedMem = capMem.clearProposalsForRun(run.runId);
    await CapMemoryStore.save(clearedMem);
    await SequenceStore.clear();
  }

  // ── PRIVATE ────────────────────────────────────────────────────

  /// Apply a coordinator action to the run, returning the updated run.
  static SequenceRun _applyAction(
    SequenceAction action,
    SequenceRun run,
    ScreenOutcome outcome,
    Map<String, dynamic>? stepOutputs,
  ) {
    final activeStepId = run.activeStepId;

    switch (action) {
      case AdvanceAction(:final nextStep):
        // Complete current step, activate next
        var updated = run;
        if (activeStepId != null) {
          updated = updated.completeStep(activeStepId, stepOutputs ?? {});
        }
        return updated.activateStep(nextStep.id);

      case CompleteAction():
        // Complete current step, mark run as complete
        var updated = run;
        if (activeStepId != null) {
          updated = updated.completeStep(activeStepId, stepOutputs ?? {});
        }
        return updated.withStatus(SequenceRunStatus.completed);

      case PauseAction():
        return run.withStatus(SequenceRunStatus.paused);

      case SkipAction(:final stepId):
        return run.skipStep(stepId);

      case RetryAction():
        // Keep current state — no change needed
        return run;

      case ReEvaluateAction(:final invalidatedStepIds):
        return run.invalidateSteps(invalidatedStepIds);
    }
  }

  /// Persist the run state and increment proposals for the next step.
  ///
  /// Called after BOTH handleStepReturn and handleRealtimeReturn.
  static Future<void> _persistAndTrackProposals(
    SequenceAction action,
    SequenceRun updatedRun,
    String runId,
    CapMemory capMem,
  ) async {
    if (updatedRun.status == SequenceRunStatus.completed ||
        updatedRun.status == SequenceRunStatus.abandoned) {
      // Clear run + proposals
      await SequenceStore.clear();
      final clearedMem = capMem.clearProposalsForRun(runId);
      await CapMemoryStore.save(clearedMem);
    } else {
      await SequenceStore.save(updatedRun);

      // Increment proposal count for the next step (anti-loop tracking)
      var updatedMem = capMem;
      switch (action) {
        case AdvanceAction(:final nextStep):
          updatedMem = updatedMem.incrementProposal(runId, nextStep.id);
        case RetryAction(:final stepId):
          updatedMem = updatedMem.incrementProposal(runId, stepId);
        default:
          break;
      }
      if (updatedMem != capMem) {
        await CapMemoryStore.save(updatedMem);
      }
    }
  }

  /// Look up template by ID (not intent tag).
  static SequenceTemplate? _templateById(String id) {
    const templates = [
      SequenceTemplate.housingPurchase,
      SequenceTemplate.optimize3a,
      SequenceTemplate.retirementPrep,
    ];
    for (final t in templates) {
      if (t.id == id) return t;
    }
    return null;
  }
}
