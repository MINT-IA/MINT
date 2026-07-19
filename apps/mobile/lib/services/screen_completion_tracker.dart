/// ScreenCompletionTracker — lightweight persistence layer for screen outcomes.
///
/// Records when a user completes or abandons a MINT B/C screen so that the
/// boucle vivante (RouteSuggestionCard, CapEngine, Coach) can react with
/// explicit signal rather than relying solely on heuristics.
///
/// Storage key pattern: `screen_return_<screenId>` → JSON
/// JSON fields: outcome (String), timestamp (ISO-8601), screenId (String)
///
/// Design:
/// - Injectable [SharedPreferences] for hermetic unit tests.
/// - Static methods only — no singleton state.
/// - Silently swallows storage errors (non-critical path).
///
/// See: docs/CHAT_TO_SCREEN_ORCHESTRATION_STRATEGY.md §7
library;

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/models/scenario_session.dart';

/// Storage key prefix for all screen completion entries.
const _kPrefix = 'screen_return_';

/// ScreenCompletionTracker — centralized tracker for screen-level outcomes.
///
/// All methods are static and accept an optional [prefs] parameter so that
/// tests can inject an in-memory [SharedPreferences] instance without touching
/// disk state.
class ScreenCompletionTracker {
  ScreenCompletionTracker._();

  // ════════════════════════════════════════════════════════════════
  //  REALTIME STREAM — coach listens for immediate reaction
  // ════════════════════════════════════════════════════════════════

  static final _controller = StreamController<ScreenReturn>.broadcast();

  /// Realtime stream of ScreenReturn events.
  ///
  /// CoachChatScreen subscribes to this so the LLM can react immediately
  /// when a user completes a simulation — no polling needed.
  static Stream<ScreenReturn> get stream => _controller.stream;

  // ════════════════════════════════════════════════════════════════
  //  WRITE
  // ════════════════════════════════════════════════════════════════

  /// Persist a [ScreenOutcome.completed] entry for [screenId].
  ///
  /// Safe to call from any async context. Silently ignores storage errors.
  static Future<void> markCompleted(
    String screenId, {
    SharedPreferences? prefs,
    DateTime? now,
  }) =>
      _write(screenId, ScreenOutcome.completed, prefs: prefs, now: now);

  /// Persist a full [ScreenReturn] for [screenId].
  ///
  /// Stores the return contract (outcome, updatedFields, confidenceDelta,
  /// nextCapSuggestion) so the boucle vivante can react with rich context.
  /// Safe to call from any async context. Silently ignores storage errors.
  static Future<void> markCompletedWithReturn(
    String screenId,
    ScreenReturn screenReturn, {
    SharedPreferences? prefs,
    DateTime? now,
  }) {
    if (!_hasValidScenarioIdentity(screenReturn)) {
      return Future<void>.value();
    }
    // Emit on realtime stream FIRST — coach reacts immediately.
    if (!_controller.isClosed) {
      _controller.add(screenReturn);
    }
    return _writeReturn(screenId, screenReturn, prefs: prefs, now: now);
  }

  /// Persist a [ScreenOutcome.abandoned] entry for [screenId].
  ///
  /// Safe to call from any async context. Silently ignores storage errors.
  static Future<void> markAbandoned(
    String screenId, {
    SharedPreferences? prefs,
    DateTime? now,
  }) =>
      _write(screenId, ScreenOutcome.abandoned, prefs: prefs, now: now);

  /// Persist a [ScreenOutcome.changedInputs] entry for [screenId].
  ///
  /// Safe to call from any async context. Silently ignores storage errors.
  static Future<void> markChangedInputs(
    String screenId, {
    SharedPreferences? prefs,
    DateTime? now,
  }) =>
      _write(screenId, ScreenOutcome.changedInputs, prefs: prefs, now: now);

  // ════════════════════════════════════════════════════════════════
  //  READ
  // ════════════════════════════════════════════════════════════════

  /// Return the last recorded [ScreenOutcome] for [screenId], or null if
  /// no record exists or the stored value is malformed.
  static Future<ScreenOutcome?> lastOutcome(
    String screenId, {
    SharedPreferences? prefs,
  }) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      final raw = p.getString('$_kPrefix$screenId');
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return _outcomeFromString(map['outcome'] as String?);
    } catch (_) {
      return null;
    }
  }

  /// Return the full stored entry for [screenId] as a [Map], or null.
  ///
  /// Keys: `outcome` (String), `timestamp` (ISO-8601 String), `screenId` (String).
  static Future<Map<String, dynamic>?> lastEntry(
    String screenId, {
    SharedPreferences? prefs,
  }) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      final raw = p.getString('$_kPrefix$screenId');
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  DELETE
  // ════════════════════════════════════════════════════════════════

  /// Remove the stored record for [screenId].
  static Future<void> clear(
    String screenId, {
    SharedPreferences? prefs,
  }) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      await p.remove('$_kPrefix$screenId');
    } catch (_) {
      // Silently ignore.
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  INTERNAL HELPERS
  // ════════════════════════════════════════════════════════════════

  /// Return the last stored [ScreenReturn] for [screenId], or null if
  /// no full return was persisted (legacy entries only have outcome).
  static Future<ScreenReturn?> lastReturn(
    String screenId, {
    SharedPreferences? prefs,
  }) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      final raw = p.getString('$_kPrefix$screenId');
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final outcome = _outcomeFromString(map['outcome'] as String?);
      if (outcome == null) return null;
      final route = map['route'] as String? ?? '';
      final confidenceDelta = (map['confidenceDelta'] as num?)?.toDouble();
      final nextCap = map['nextCapSuggestion'] as String?;
      final updatedFieldsRaw = map['updatedFields'];
      Map<String, dynamic>? updatedFields;
      if (updatedFieldsRaw is Map) {
        updatedFields = Map<String, dynamic>.from(updatedFieldsRaw);
      }
      // Rehydrate stepOutputs if present.
      final stepOutputsRaw = map['stepOutputs'];
      Map<String, dynamic>? stepOutputs;
      if (stepOutputsRaw is Map) {
        stepOutputs = Map<String, dynamic>.from(stepOutputsRaw);
      }
      final scenarioId = map['scenarioId'] as String?;
      final scenarioStatus = _scenarioStatusFromString(
        map['scenarioStatus'] as String?,
      );
      if ((scenarioId != null || scenarioStatus != null) &&
          (scenarioId == null ||
              scenarioStatus == null ||
              !isOpaqueScenarioId(scenarioId))) {
        return null;
      }

      return ScreenReturn(
        route: route,
        outcome: outcome,
        updatedFields: updatedFields,
        confidenceDelta: confidenceDelta,
        nextCapSuggestion: nextCap,
        stepOutputs: stepOutputs,
        scenarioId: scenarioId,
        scenarioStatus: scenarioStatus,
        runId: map['runId'] as String?,
        stepId: map['stepId'] as String?,
        eventId: map['eventId'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _write(
    String screenId,
    ScreenOutcome outcome, {
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    try {
      final timestamp = (now ?? DateTime.now()).toIso8601String();
      final p = prefs ?? await SharedPreferences.getInstance();
      await p.setString(
        '$_kPrefix$screenId',
        jsonEncode({
          'outcome': _outcomeToString(outcome),
          'timestamp': timestamp,
          'screenId': screenId,
        }),
      );
    } catch (_) {
      // Non-critical — silently ignore storage failures.
    }
  }

  static Future<void> _writeReturn(
    String screenId,
    ScreenReturn screenReturn, {
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    try {
      final timestamp = (now ?? DateTime.now()).toIso8601String();
      final p = prefs ?? await SharedPreferences.getInstance();
      await p.setString(
        '$_kPrefix$screenId',
        jsonEncode({
          'outcome': _outcomeToString(screenReturn.outcome),
          'timestamp': timestamp,
          'screenId': screenId,
          'route': screenReturn.route,
          if (screenReturn.updatedFields != null)
            'updatedFields': screenReturn.updatedFields,
          if (screenReturn.confidenceDelta != null)
            'confidenceDelta': screenReturn.confidenceDelta,
          if (screenReturn.nextCapSuggestion != null)
            'nextCapSuggestion': screenReturn.nextCapSuggestion,
          if (screenReturn.stepOutputs != null)
            'stepOutputs': screenReturn.stepOutputs,
          if (screenReturn.scenarioId != null)
            'scenarioId': screenReturn.scenarioId,
          if (screenReturn.scenarioStatus != null)
            'scenarioStatus': screenReturn.scenarioStatus!.name,
          if (screenReturn.runId != null) 'runId': screenReturn.runId,
          if (screenReturn.stepId != null) 'stepId': screenReturn.stepId,
          if (screenReturn.eventId != null) 'eventId': screenReturn.eventId,
        }),
      );
    } catch (_) {
      // Non-critical — silently ignore storage failures.
    }
  }

  static String _outcomeToString(ScreenOutcome outcome) {
    switch (outcome) {
      case ScreenOutcome.completed:
        return 'completed';
      case ScreenOutcome.abandoned:
        return 'abandoned';
      case ScreenOutcome.changedInputs:
        return 'changedInputs';
    }
  }

  static ScreenOutcome? _outcomeFromString(String? value) {
    switch (value) {
      case 'completed':
        return ScreenOutcome.completed;
      case 'abandoned':
        return ScreenOutcome.abandoned;
      case 'changedInputs':
        return ScreenOutcome.changedInputs;
      default:
        return null;
    }
  }

  static bool _hasValidScenarioIdentity(ScreenReturn screenReturn) {
    final id = screenReturn.scenarioId;
    final status = screenReturn.scenarioStatus;
    if (id == null && status == null) return true;
    return id != null && status != null && isOpaqueScenarioId(id);
  }

  static ScenarioStatus? _scenarioStatusFromString(String? value) {
    return switch (value) {
      'draft' => ScenarioStatus.draft,
      'calculated' => ScenarioStatus.calculated,
      'completed' => ScenarioStatus.completed,
      'abandoned' => ScenarioStatus.abandoned,
      _ => null,
    };
  }
}
