import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Sentinel value for "not provided" in copyWith — allows explicit null.
const Object _undefined = _Undefined();

class _Undefined {
  const _Undefined();
}

/// Persistent memory for the CapEngine.
///
/// Tracks which caps were served, completed, or abandoned
/// so the engine can rotate priorities and avoid repetition.
///
/// Stored in SharedPreferences under `_cap_memory`.
/// Isolated from CoachProfileProvider to limit blast radius.
// TODO(P3): Sync CapMemory to backend for cross-device continuity
class CapMemory {
  /// ID of the last cap served.
  final String? lastCapServed;

  /// When the last cap was served.
  final DateTime? lastCapDate;

  /// IDs of actions the user completed (e.g. "pillar_3a_2026").
  final List<String> completedActions;

  /// IDs of flows the user abandoned recently.
  final List<String> abandonedFlows;

  /// Preferred CTA mode deduced from behavior ("route" | "coach" | "capture").
  final String? preferredCtaMode;

  /// Goals the user has declared (e.g. "retraite", "achat_immo").
  final List<String> declaredGoals;

  /// Observable friction context — never a psychological diagnosis.
  /// E.g. "budget_stress", "flow_abandoned", "hesitation_lpp".
  final String? recentFrictionContext;

  /// When the last action was completed (distinct from lastCapDate).
  /// Used by feedback pill to show "Impact recalculé" accurately.
  final DateTime? lastCompletedDate;

  /// ID of the cap that was last completed. Used by success sheet to
  /// celebrate the RIGHT action, not the current _cachedCap.
  final String? lastCompletedCapId;

  /// Headline of the last completed cap — cached so success sheet can
  /// display the right message even if CapEngine recomputes a different cap.
  final String? lastCompletedCapHeadline;

  /// CTA label of the last completed cap — the action text the user actually clicked.
  final String? lastCompletedCapCtaLabel;

  /// Tracks how many times each step was proposed in a guided sequence run.
  /// Key: "{runId}_{stepId}", Value: proposal count.
  /// Cleared when the run completes or is abandoned.
  /// Used by SequenceCoordinator for anti-loop (max 2 proposals per step).
  /// See RFC_AGENT_LOOP_STATEFUL.md §6.3.
  final Map<String, int> stepProposals;

  const CapMemory({
    this.lastCapServed,
    this.lastCapDate,
    this.completedActions = const [],
    this.abandonedFlows = const [],
    this.preferredCtaMode,
    this.declaredGoals = const [],
    this.recentFrictionContext,
    this.lastCompletedDate,
    this.lastCompletedCapId,
    this.lastCompletedCapHeadline,
    this.lastCompletedCapCtaLabel,
    this.stepProposals = const {},
  });

  /// Get the proposal count for a step in a specific run.
  int proposalCount(String runId, String stepId) =>
      stepProposals['${runId}_$stepId'] ?? 0;

  /// Return a copy with an incremented proposal count for a step.
  CapMemory incrementProposal(String runId, String stepId) {
    final key = '${runId}_$stepId';
    final updated = Map<String, int>.from(stepProposals);
    updated[key] = (updated[key] ?? 0) + 1;
    return copyWith(stepProposals: updated);
  }

  /// Return a copy with all step proposals for a given run cleared.
  CapMemory clearProposalsForRun(String runId) {
    final updated = Map<String, int>.from(stepProposals)
      ..removeWhere((key, _) => key.startsWith('${runId}_'));
    return copyWith(stepProposals: updated);
  }

  /// Copy with explicit null clearing support.
  ///
  /// Pass the [_cleared] sentinel to explicitly set a nullable field to null.
  /// Omit a field to keep the current value.
  CapMemory copyWith({
    Object? lastCapServed = _undefined,
    Object? lastCapDate = _undefined,
    List<String>? completedActions,
    List<String>? abandonedFlows,
    Object? preferredCtaMode = _undefined,
    List<String>? declaredGoals,
    Object? recentFrictionContext = _undefined,
    Object? lastCompletedDate = _undefined,
    Object? lastCompletedCapId = _undefined,
    Object? lastCompletedCapHeadline = _undefined,
    Object? lastCompletedCapCtaLabel = _undefined,
    Map<String, int>? stepProposals,
  }) {
    return CapMemory(
      lastCapServed: lastCapServed == _undefined
          ? this.lastCapServed
          : lastCapServed as String?,
      lastCapDate: lastCapDate == _undefined
          ? this.lastCapDate
          : lastCapDate as DateTime?,
      completedActions: completedActions ?? this.completedActions,
      abandonedFlows: abandonedFlows ?? this.abandonedFlows,
      preferredCtaMode: preferredCtaMode == _undefined
          ? this.preferredCtaMode
          : preferredCtaMode as String?,
      declaredGoals: declaredGoals ?? this.declaredGoals,
      recentFrictionContext: recentFrictionContext == _undefined
          ? this.recentFrictionContext
          : recentFrictionContext as String?,
      lastCompletedDate: lastCompletedDate == _undefined
          ? this.lastCompletedDate
          : lastCompletedDate as DateTime?,
      lastCompletedCapId: lastCompletedCapId == _undefined
          ? this.lastCompletedCapId
          : lastCompletedCapId as String?,
      lastCompletedCapHeadline: lastCompletedCapHeadline == _undefined
          ? this.lastCompletedCapHeadline
          : lastCompletedCapHeadline as String?,
      lastCompletedCapCtaLabel: lastCompletedCapCtaLabel == _undefined
          ? this.lastCompletedCapCtaLabel
          : lastCompletedCapCtaLabel as String?,
      stepProposals: stepProposals ?? this.stepProposals,
    );
  }

  Map<String, dynamic> toJson() => {
        if (lastCapServed != null) 'lastCapServed': lastCapServed,
        if (lastCapDate != null)
          'lastCapDate': lastCapDate!.toIso8601String(),
        'completedActions': completedActions,
        'abandonedFlows': abandonedFlows,
        if (preferredCtaMode != null) 'preferredCtaMode': preferredCtaMode,
        'declaredGoals': declaredGoals,
        if (recentFrictionContext != null)
          'recentFrictionContext': recentFrictionContext,
        if (lastCompletedDate != null)
          'lastCompletedDate': lastCompletedDate!.toIso8601String(),
        if (lastCompletedCapId != null)
          'lastCompletedCapId': lastCompletedCapId,
        if (lastCompletedCapHeadline != null)
          'lastCompletedCapHeadline': lastCompletedCapHeadline,
        if (lastCompletedCapCtaLabel != null)
          'lastCompletedCapCtaLabel': lastCompletedCapCtaLabel,
        if (stepProposals.isNotEmpty) 'stepProposals': stepProposals,
      };

  factory CapMemory.fromJson(Map<String, dynamic> json) => CapMemory(
        lastCapServed: json['lastCapServed'] as String?,
        lastCapDate: json['lastCapDate'] != null
            ? DateTime.tryParse(json['lastCapDate'] as String)
            : null,
        completedActions:
            (json['completedActions'] as List<dynamic>?)?.cast<String>() ??
                const [],
        abandonedFlows:
            (json['abandonedFlows'] as List<dynamic>?)?.cast<String>() ??
                const [],
        preferredCtaMode: json['preferredCtaMode'] as String?,
        declaredGoals:
            (json['declaredGoals'] as List<dynamic>?)?.cast<String>() ??
                const [],
        recentFrictionContext: json['recentFrictionContext'] as String?,
        lastCompletedDate: json['lastCompletedDate'] != null
            ? DateTime.tryParse(json['lastCompletedDate'] as String)
            : null,
        lastCompletedCapId: json['lastCompletedCapId'] as String?,
        lastCompletedCapHeadline: json['lastCompletedCapHeadline'] as String?,
        lastCompletedCapCtaLabel: json['lastCompletedCapCtaLabel'] as String?,
        stepProposals:
            (json['stepProposals'] as Map<String, dynamic>?)?.map(
                  (k, v) => MapEntry(k, (v as num).toInt()),
                ) ??
                const {},
      );
}

/// Persistence layer for CapMemory.
///
/// Uses SharedPreferences — same pattern as dataTimestamps.
class CapMemoryStore {
  static const _key = '_cap_memory';

  /// T2-8: Mutex to prevent concurrent writes.
  static Completer<void>? _saveLock;

  CapMemoryStore._();

  /// Load the current memory. Returns empty memory if none stored.
  static Future<CapMemory> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const CapMemory();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return CapMemory.fromJson(json);
    } catch (_) {
      return const CapMemory();
    }
  }

  /// Save memory to disk. Serialized writes to prevent data corruption.
  static Future<void> save(CapMemory memory) async {
    // Wait for any in-flight save to complete before starting a new one.
    if (_saveLock != null && !_saveLock!.isCompleted) {
      await _saveLock!.future;
    }
    _saveLock = Completer<void>();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(memory.toJson()));
    } finally {
      _saveLock!.complete();
    }
  }

  /// Record that a cap was served to the user.
  static Future<CapMemory> markServed(
    CapMemory memory,
    String capId,
  ) async {
    final updated = memory.copyWith(
      lastCapServed: capId,
      lastCapDate: DateTime.now(),
    );
    await save(updated);
    return updated;
  }

  /// Record that the user completed the action from a cap.
  static Future<CapMemory> markCompleted(
    CapMemory memory,
    String actionId, {
    String? headline,
    String? ctaLabel,
  }) async {
    final actions = [...memory.completedActions, actionId];
    // Keep only last 20 to avoid unbounded growth.
    final trimmed = actions.length > 20
        ? actions.sublist(actions.length - 20)
        : actions;
    final updated = memory.copyWith(
      completedActions: trimmed,
      // Clear friction context on success.
      recentFrictionContext: null,
      // Stamp completion time (distinct from lastCapDate).
      lastCompletedDate: DateTime.now(),
      // Store the completed cap ID + headline + ctaLabel for success sheet accuracy
      lastCompletedCapId: actionId,
      lastCompletedCapHeadline: headline,
      lastCompletedCapCtaLabel: ctaLabel,
    );
    await save(updated);
    return updated;
  }

  /// Record that the user abandoned a flow.
  static Future<CapMemory> markAbandoned(
    CapMemory memory,
    String flowId, {
    String? frictionContext,
  }) async {
    final flows = [...memory.abandonedFlows, flowId];
    final trimmed =
        flows.length > 10 ? flows.sublist(flows.length - 10) : flows;
    final updated = memory.copyWith(
      abandonedFlows: trimmed,
      recentFrictionContext: frictionContext,
    );
    await save(updated);
    return updated;
  }

  /// Clear all memory (for testing or reset).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
