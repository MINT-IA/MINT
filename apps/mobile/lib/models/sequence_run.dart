/// SequenceRun — runtime state of an active guided sequence.
///
/// Lightweight, persisted in SharedPreferences. One active run at a time.
/// SequenceStore is the SOLE source of truth for the active run.
///
/// See: docs/RFC_AGENT_LOOP_STATEFUL.md §3.3, §5.6
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

// ════════════════════════════════════════════════════════════════
//  ENUMS
// ════════════════════════════════════════════════════════════════

/// Status of a single step within a run.
enum StepRunState { pending, active, completed, skipped, blocked }

/// Overall status of a sequence run.
enum SequenceRunStatus { active, paused, completed, abandoned }

// ════════════════════════════════════════════════════════════════
//  RUN MODEL
// ════════════════════════════════════════════════════════════════

/// Runtime state of an active guided sequence.
///
/// Created when a sequence starts, updated after each step return,
/// cleared on completion or abandonment.
class SequenceRun {
  /// UUID, created when the sequence starts.
  final String runId;

  /// Template ID (e.g. 'housing_purchase').
  final String templateId;

  /// When the run was started.
  final DateTime startedAt;

  /// Status of each step, keyed by step ID.
  final Map<String, StepRunState> stepStates;

  /// Accumulated outputs from completed steps, keyed by step ID.
  /// Values are JSON-serializable primitives only (see RFC §6.3).
  final Map<String, Map<String, dynamic>> stepOutputs;

  /// Overall run status.
  final SequenceRunStatus status;

  /// Set of event IDs already processed by the sequence handler.
  /// Used for idempotent dedup: if an eventId is in this set, the
  /// handler skips it (no double consumption across realtime + fallback).
  /// Bounded to [maxProcessedEvents] entries (FIFO eviction).
  /// Cleared when the run completes or is abandoned.
  /// See RFC_AGENT_LOOP_STATEFUL.md §6.3 (Phase 2 Completion).
  final Set<String> processedEventIds;

  /// Maximum number of processed event IDs to retain.
  static const int maxProcessedEvents = 20;

  const SequenceRun({
    required this.runId,
    required this.templateId,
    required this.startedAt,
    required this.stepStates,
    this.stepOutputs = const {},
    this.processedEventIds = const {},
    this.status = SequenceRunStatus.active,
  });

  // ── COMPUTED PROPERTIES ────────────────────────────────────────

  /// Number of completed or skipped steps.
  int get completedCount => stepStates.values
      .where((s) => s == StepRunState.completed || s == StepRunState.skipped)
      .length;

  /// Total number of steps.
  int get totalCount => stepStates.length;

  /// Progress fraction (0.0 – 1.0).
  double get progress => totalCount > 0 ? completedCount / totalCount : 0.0;

  /// Whether the run is active (not paused/completed/abandoned).
  bool get isActive => status == SequenceRunStatus.active;

  /// The ID of the currently active step, or null if none.
  String? get activeStepId {
    for (final entry in stepStates.entries) {
      if (entry.value == StepRunState.active) return entry.key;
    }
    return null;
  }

  /// Whether the given [eventId] has already been processed.
  bool isEventProcessed(String? eventId) =>
      eventId != null && processedEventIds.contains(eventId);

  /// Return a copy with [eventId] added to the processed set.
  /// Evicts the oldest entry if the set exceeds [maxProcessedEvents].
  /// CHAOS-5: Use List for deterministic FIFO eviction (Set.first is unordered).
  SequenceRun markEventProcessed(String eventId) {
    final ordered = List<String>.from(processedEventIds);
    if (!ordered.contains(eventId)) {
      ordered.add(eventId);
    }
    // FIFO eviction: remove oldest (first-inserted) entries if over limit.
    while (ordered.length > maxProcessedEvents) {
      ordered.removeAt(0);
    }
    return _copyWith(processedEventIds: ordered.toSet());
  }

  // ── IMMUTABLE UPDATES ──────────────────────────────────────────

  /// Returns a copy with the given step marked as completed + outputs recorded.
  ///
  /// Outputs are validated: only JSON-serializable primitives (double, int,
  /// String, bool) are accepted. Non-primitive values are silently dropped.
  /// Per-step limit: 2KB JSON. Total run limit: 20KB JSON.
  /// See RFC §6.3 for the persistence contract.
  SequenceRun completeStep(String stepId, Map<String, dynamic> outputs) {
    final newStates = Map<String, StepRunState>.from(stepStates);
    newStates[stepId] = StepRunState.completed;
    final newOutputs = Map<String, Map<String, dynamic>>.from(stepOutputs);
    if (outputs.isNotEmpty) {
      final sanitized = _sanitizeOutputs(outputs);
      if (sanitized.isNotEmpty) {
        newOutputs[stepId] = sanitized;
        // Enforce total run size limit (UTF-8 bytes, not chars)
        final totalSize = utf8.encode(jsonEncode(newOutputs)).length;
        if (totalSize > _maxTotalOutputBytes) {
          // Drop this step's outputs to stay within budget
          newOutputs.remove(stepId);
        }
      }
    }
    return _copyWith(stepStates: newStates, stepOutputs: newOutputs);
  }

  /// Maximum serialized size per step outputs (bytes).
  static const int _maxStepOutputBytes = 2048;

  /// Maximum total serialized size for all step outputs (bytes).
  static const int _maxTotalOutputBytes = 20480;

  /// Maximum string value length in outputs.
  static const int _maxStringLength = 200;

  /// Filter outputs to only JSON-serializable primitives within size bounds.
  /// Enforces RFC §6.3 persistence contract.
  static Map<String, dynamic> _sanitizeOutputs(Map<String, dynamic> raw) {
    final sanitized = <String, dynamic>{};
    for (final entry in raw.entries) {
      final v = entry.value;
      if (v is double || v is int || v is bool) {
        sanitized[entry.key] = v;
      } else if (v is String) {
        // Truncate strings exceeding max length
        sanitized[entry.key] =
            v.length > _maxStringLength ? v.substring(0, _maxStringLength) : v;
      }
      // Silently drop non-primitive values (Lists, Maps, objects)
    }

    // Enforce per-step size limit (measured as UTF-8 bytes)
    final encoded = utf8.encode(jsonEncode(sanitized));
    if (encoded.length > _maxStepOutputBytes) {
      // Drop outputs exceeding budget rather than corrupting persistence
      return {};
    }

    return sanitized;
  }

  /// Returns a copy with the given step marked as skipped.
  SequenceRun skipStep(String stepId) {
    final newStates = Map<String, StepRunState>.from(stepStates);
    newStates[stepId] = StepRunState.skipped;
    return _copyWith(stepStates: newStates);
  }

  /// Returns a copy with the given step marked as active.
  SequenceRun activateStep(String stepId) {
    final newStates = Map<String, StepRunState>.from(stepStates);
    // Deactivate any currently active step
    for (final key in newStates.keys) {
      if (newStates[key] == StepRunState.active) {
        newStates[key] = StepRunState.pending;
      }
    }
    newStates[stepId] = StepRunState.active;
    return _copyWith(stepStates: newStates);
  }

  /// Returns a copy with updated overall status.
  SequenceRun withStatus(SequenceRunStatus newStatus) =>
      _copyWith(status: newStatus);

  /// Returns a copy with specified steps reset to pending.
  SequenceRun invalidateSteps(List<String> stepIds) {
    final newStates = Map<String, StepRunState>.from(stepStates);
    final newOutputs = Map<String, Map<String, dynamic>>.from(stepOutputs);
    for (final id in stepIds) {
      if (newStates.containsKey(id)) {
        newStates[id] = StepRunState.pending;
        newOutputs.remove(id);
      }
    }
    return _copyWith(stepStates: newStates, stepOutputs: newOutputs);
  }

  SequenceRun _copyWith({
    Map<String, StepRunState>? stepStates,
    Map<String, Map<String, dynamic>>? stepOutputs,
    SequenceRunStatus? status,
    Set<String>? processedEventIds,
  }) {
    return SequenceRun(
      runId: runId,
      templateId: templateId,
      startedAt: startedAt,
      stepStates: stepStates ?? this.stepStates,
      stepOutputs: stepOutputs ?? this.stepOutputs,
      status: status ?? this.status,
      processedEventIds: processedEventIds ?? this.processedEventIds,
    );
  }

  // ── FACTORY ────────────────────────────────────────────────────

  /// Create a new run from a template. All steps start as pending,
  /// first step is activated.
  factory SequenceRun.start({
    required String runId,
    required String templateId,
    required List<String> stepIds,
  }) {
    if (stepIds.isEmpty) {
      throw ArgumentError('Cannot start a run with no steps');
    }
    final states = <String, StepRunState>{};
    for (int i = 0; i < stepIds.length; i++) {
      states[stepIds[i]] = i == 0 ? StepRunState.active : StepRunState.pending;
    }
    return SequenceRun(
      runId: runId,
      templateId: templateId,
      startedAt: DateTime.now(),
      stepStates: states,
    );
  }

  // ── SERIALIZATION (SharedPreferences) ──────────────────────────

  Map<String, dynamic> toJson() => {
        'runId': runId,
        'templateId': templateId,
        'startedAt': startedAt.toIso8601String(),
        'stepStates': stepStates.map((k, v) => MapEntry(k, v.name)),
        'stepOutputs': stepOutputs,
        'status': status.name,
        if (processedEventIds.isNotEmpty)
          'processedEventIds': processedEventIds.toList(),
      };

  factory SequenceRun.fromJson(Map<String, dynamic> json) {
    return SequenceRun(
      runId: json['runId'] as String,
      templateId: json['templateId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      stepStates: (json['stepStates'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, StepRunState.values.byName(v as String)),
      ),
      stepOutputs: (json['stepOutputs'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
          ) ??
          const {},
      status: SequenceRunStatus.values.byName(json['status'] as String),
      processedEventIds:
          (json['processedEventIds'] as List<dynamic>?)
              ?.cast<String>()
              .toSet() ??
          const {},
    );
  }

  /// Serialize to JSON string for SharedPreferences.
  String serialize() => jsonEncode(toJson());

  /// Deserialize from JSON string.
  static SequenceRun? deserialize(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return SequenceRun.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      // STAB-16 (07-04): corrupt sequence state — log and return null so the
      // caller can reset to a fresh run rather than silently losing history.
      debugPrint('[sequence_run] deserialize failed: $e');
      return null;
    }
  }
}
