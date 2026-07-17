import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:mint_mobile/models/coach_insight.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/authenticated_transport.dart';
import 'package:mint_mobile/services/session_epoch.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ────────────────────────────────────────────────────────────
//  COACH MEMORY SERVICE — S58 / AI Memory
// ────────────────────────────────────────────────────────────
//
// Local summaries are account-scoped and privacy-minimized. Every public
// operation captures one session epoch and one identity-derived namespace
// before touching SharedPreferences or the authenticated network.
// ────────────────────────────────────────────────────────────

/// Persists and retrieves [CoachInsight] records across sessions.
class CoachMemoryService {
  CoachMemoryService._();

  static const _baseKey = '_coach_insights';
  static const _eventsBaseKey = '_coach_events';
  static const _maxInsights = 50;

  static SessionEpoch _sessionEpoch = SessionEpoch();
  static Future<String?> Function() _userIdReader = AuthService.getUserId;

  /// Composition-root binding. Session termination invalidates every memory
  /// operation through the exact same epoch as providers and API transport.
  static void bindSessionEpoch(SessionEpoch sessionEpoch) {
    _sessionEpoch = sessionEpoch;
  }

  @visibleForTesting
  static void debugConfigureSessionAuthority({
    required SessionEpoch sessionEpoch,
    required Future<String?> Function() userIdReader,
  }) {
    _sessionEpoch = sessionEpoch;
    _userIdReader = userIdReader;
  }

  @visibleForTesting
  static void debugResetSessionAuthority() {
    _sessionEpoch = SessionEpoch();
    _userIdReader = AuthService.getUserId;
  }

  static Future<_CoachMemoryScope> _beginScope() async {
    final epoch = _sessionEpoch;
    final guard = epoch.capture();
    final userId = await _userIdReader();
    guard.assertCurrent();
    final String namespace;
    if (userId == null) {
      namespace = '__anon';
    } else {
      namespace = userId.trim();
      if (namespace.isEmpty) {
        throw StateError('Coach memory identity is malformed');
      }
    }
    return _CoachMemoryScope(
      epoch: epoch,
      guard: guard,
      insightsKey: '${_baseKey}_$namespace',
      eventsKey: '${_eventsBaseKey}_$namespace',
    );
  }

  // ── Insights ──────────────────────────────────────────────

  static Future<void> saveInsight(
    CoachInsight insight, {
    SharedPreferences? prefs,
    AuthenticatedTransport? transport,
  }) async {
    final scope = await _beginScope();
    final sp = prefs ?? await SharedPreferences.getInstance();
    scope.guard.assertCurrent();
    late final List<CoachInsight> removed;

    await scope.epoch.runGuardedPersistence(scope.guard, () async {
      final insights = _read(sp, scope.insightsKey, scope.guard);
      insights.removeWhere((candidate) => candidate.id == insight.id);
      insights.insert(0, insight);
      removed = insights.length <= _maxInsights
          ? const <CoachInsight>[]
          : insights.skip(_maxInsights).toList(growable: false);
      final retained = insights.take(_maxInsights).toList(growable: false);
      await _write(sp, scope.insightsKey, retained);
    });
    scope.guard.assertCurrent();

    final authenticated = transport ?? ApiService.authenticatedTransport;
    for (final stale in removed) {
      unawaited(_syncRemoveToBackend(stale.id, authenticated, scope));
    }
    unawaited(_syncToBackend(insight, authenticated, scope));
  }

  static Future<void> _syncToBackend(
    CoachInsight insight,
    AuthenticatedTransport transport,
    _CoachMemoryScope scope,
  ) async {
    try {
      final operation = transport.beginOperation();
      scope.guard.assertCurrent();
      await operation.requireSession();
      scope.guard.assertCurrent();
      await operation.send(
        AuthenticatedRequest.json(
          AuthenticatedHttpMethod.post,
          Uri.parse('${ApiService.baseUrl}/coach/sync-insight'),
          <String, dynamic>{
            'insight_id': insight.id,
            'topic': insight.topic,
            'summary': insight.summary,
            'insight_type': insight.type.name,
            if (insight.metadata != null)
              'metadata': _filterMetadata(insight.metadata!),
            'created_at': insight.createdAt.toUtc().toIso8601String(),
          },
        ),
      );
      scope.guard.assertCurrent();
    } catch (_) {
      debugPrint('[CoachMemory] backend_sync_failed');
    }
  }

  @visibleForTesting
  static Future<void> debugSyncInsightToBackend(
    CoachInsight insight, {
    required AuthenticatedTransport transport,
  }) async {
    final scope = await _beginScope();
    await _syncToBackend(insight, transport, scope);
  }

  static Future<void> _syncRemoveToBackend(
    String insightId,
    AuthenticatedTransport transport,
    _CoachMemoryScope scope,
  ) async {
    try {
      final operation = transport.beginOperation();
      scope.guard.assertCurrent();
      await operation.requireSession();
      scope.guard.assertCurrent();
      await operation.send(
        AuthenticatedRequest.empty(
          AuthenticatedHttpMethod.delete,
          Uri.parse('${ApiService.baseUrl}/coach/sync-insight/$insightId'),
        ),
      );
      scope.guard.assertCurrent();
    } catch (_) {
      debugPrint('[CoachMemory] backend_remove_failed');
    }
  }

  static Map<String, dynamic> _filterMetadata(Map<String, dynamic> metadata) {
    const safeKeys = {'templateId', 'stepCount', 'documentType', 'sequenceId'};
    return Map.fromEntries(
      metadata.entries.where((entry) => safeKeys.contains(entry.key)),
    );
  }

  static Future<List<CoachInsight>> getInsights({
    SharedPreferences? prefs,
  }) async {
    final scope = await _beginScope();
    final sp = prefs ?? await SharedPreferences.getInstance();
    scope.guard.assertCurrent();
    final insights = _read(sp, scope.insightsKey, scope.guard);
    scope.guard.assertCurrent();
    return insights;
  }

  static Future<List<CoachInsight>> getInsightsForTopic(
    String intentTag, {
    SharedPreferences? prefs,
  }) async {
    final scope = await _beginScope();
    final sp = prefs ?? await SharedPreferences.getInstance();
    scope.guard.assertCurrent();
    final all = _read(sp, scope.insightsKey, scope.guard);
    final tag = intentTag.toLowerCase().trim();
    final matching = all
        .where((insight) => insight.topic.toLowerCase().contains(tag))
        .toList(growable: false);
    scope.guard.assertCurrent();
    return matching;
  }

  // ── Events (non-pruned durable anchors) ──────────────────

  static Future<void> saveEvent(
    String topic,
    String summary, {
    DateTime? date,
    Map<String, dynamic>? metadata,
    SharedPreferences? prefs,
  }) async {
    final scope = await _beginScope();
    final sp = prefs ?? await SharedPreferences.getInstance();
    scope.guard.assertCurrent();
    final nowLocal = (date ?? DateTime.now()).toLocal();
    final day = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final entry = CoachInsight(
      id: 'event_${topic}_${day.toIso8601String().substring(0, 10)}',
      createdAt: nowLocal,
      topic: topic,
      summary: summary,
      type: InsightType.event,
      metadata: metadata,
    );

    try {
      await scope.epoch.runGuardedPersistence(scope.guard, () async {
        final events = _read(sp, scope.eventsKey, scope.guard);
        events.removeWhere((event) {
          final local = event.createdAt.toLocal();
          final eventDay = DateTime(local.year, local.month, local.day);
          return event.topic == topic && eventDay == day;
        });
        events.insert(0, entry);
        await _write(sp, scope.eventsKey, events);
      });
      scope.guard.assertCurrent();
    } on SessionEpochInvalidated {
      rethrow;
    } catch (_) {
      // Event persistence remains best-effort for scan callers, but session
      // invalidation above is never swallowed.
      debugPrint('[CoachMemory] event_persist_failed');
    }
  }

  @visibleForTesting
  static Future<List<CoachInsight>> debugGetEvents({
    SharedPreferences? prefs,
  }) async {
    final scope = await _beginScope();
    final sp = prefs ?? await SharedPreferences.getInstance();
    scope.guard.assertCurrent();
    final events = _read(sp, scope.eventsKey, scope.guard);
    scope.guard.assertCurrent();
    return events;
  }

  // ── Maintenance ──────────────────────────────────────────

  static Future<void> prune({
    SharedPreferences? prefs,
    AuthenticatedTransport? transport,
  }) async {
    final scope = await _beginScope();
    final sp = prefs ?? await SharedPreferences.getInstance();
    scope.guard.assertCurrent();
    var removed = const <CoachInsight>[];

    await scope.epoch.runGuardedPersistence(scope.guard, () async {
      final insights = _read(sp, scope.insightsKey, scope.guard);
      if (insights.length <= _maxInsights) return;
      removed = insights.skip(_maxInsights).toList(growable: false);
      await _write(
        sp,
        scope.insightsKey,
        insights.take(_maxInsights).toList(growable: false),
      );
    });
    scope.guard.assertCurrent();

    final authenticated = transport ?? ApiService.authenticatedTransport;
    for (final insight in removed) {
      unawaited(_syncRemoveToBackend(insight.id, authenticated, scope));
    }
  }

  /// Clears the current identity plus anonymous fallback namespaces.
  static Future<void> clear({SharedPreferences? prefs}) async {
    final scope = await _beginScope();
    final sp = prefs ?? await SharedPreferences.getInstance();
    scope.guard.assertCurrent();
    await scope.epoch.runGuardedPersistence(scope.guard, () async {
      await _removeExisting(sp, <String>{
        scope.insightsKey,
        scope.eventsKey,
        '${_baseKey}___anon',
        '${_eventsBaseKey}___anon',
      });
    });
    scope.guard.assertCurrent();
  }

  /// Coordinator-only purge after synchronous epoch invalidation and drain.
  /// It deliberately removes every account namespace rather than resolving an
  /// identity while termination is blocked.
  static Future<void> clearForSessionTermination({
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final keys = sp
        .getKeys()
        .where(
          (key) =>
              key.startsWith('${_baseKey}_') ||
              key.startsWith('${_eventsBaseKey}_'),
        )
        .toSet();
    await _removeExisting(sp, keys);
  }

  static List<CoachInsight> _read(
    SharedPreferences prefs,
    String key,
    SessionEpochGuard guard,
  ) {
    guard.assertCurrent();
    final raw = prefs.getString(key);
    guard.assertCurrent();
    return raw == null ? <CoachInsight>[] : CoachInsight.decodeList(raw);
  }

  static Future<void> _write(
    SharedPreferences prefs,
    String key,
    List<CoachInsight> insights,
  ) async {
    final stored =
        await prefs.setString(key, CoachInsight.encodeList(insights));
    if (!stored || prefs.getString(key) == null) {
      await prefs.reload();
      throw StateError('Coach memory persistence failed');
    }
  }

  static Future<void> _removeExisting(
    SharedPreferences prefs,
    Set<String> keys,
  ) async {
    for (final key in keys) {
      if (!prefs.containsKey(key)) continue;
      final removed = await prefs.remove(key);
      if (!removed || prefs.containsKey(key)) {
        await prefs.reload();
        throw StateError('Coach memory purge failed');
      }
    }
  }
}

final class _CoachMemoryScope {
  const _CoachMemoryScope({
    required this.epoch,
    required this.guard,
    required this.insightsKey,
    required this.eventsKey,
  });

  final SessionEpoch epoch;
  final SessionEpochGuard guard;
  final String insightsKey;
  final String eventsKey;
}
