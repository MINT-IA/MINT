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

  const CapMemory({
    this.lastCapServed,
    this.lastCapDate,
    this.completedActions = const [],
    this.abandonedFlows = const [],
    this.preferredCtaMode,
    this.declaredGoals = const [],
    this.recentFrictionContext,
  });

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
      );
}

/// Persistence layer for CapMemory.
///
/// Uses SharedPreferences — same pattern as dataTimestamps.
class CapMemoryStore {
  static const _key = '_cap_memory';

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

  /// Save memory to disk.
  static Future<void> save(CapMemory memory) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(memory.toJson()));
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
    String actionId,
  ) async {
    final actions = [...memory.completedActions, actionId];
    // Keep only last 20 to avoid unbounded growth.
    final trimmed = actions.length > 20
        ? actions.sublist(actions.length - 20)
        : actions;
    final updated = memory.copyWith(
      completedActions: trimmed,
      // Clear friction context on success.
      recentFrictionContext: null,
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
