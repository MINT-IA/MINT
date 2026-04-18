import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/models/coach_insight.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';

// ────────────────────────────────────────────────────────────
//  COACH MEMORY SERVICE — S58 / AI Memory
// ────────────────────────────────────────────────────────────
//
// Persists key insights extracted from coach conversations so
// Claude has cross-session awareness without replaying full
// conversation history.
//
// Storage: SharedPreferences (Phase 2 — not a vector store yet;
// that is Phase 3 / S63+).
//
// Max capacity: 50 most recent insights (FIFO pruning).
// Key: '_coach_insights'
//
// Privacy rules (CLAUDE.md §7):
//   - summaries must NOT contain exact salary, IBAN, name, SSN
//   - topics / categories only — no verbatim personal data
//   - metadata field is NOT injected into LLM prompts directly
//
// Pure static methods for testability (injectable SharedPreferences).
//
// ACCOUNT ISOLATION (Gate 0 fix 2026-04-15): SharedPreferences key now
// includes the authenticated user_id, so insights persisted under one
// account never leak into another. Anonymous sessions land under the
// '__anon' namespace which is wiped on first authentication.
// ────────────────────────────────────────────────────────────

/// Persists and retrieves [CoachInsight] records across sessions.
class CoachMemoryService {
  CoachMemoryService._();

  /// Base SharedPreferences key. The actual storage key is
  /// `${_baseKey}_$userId` (or `${_baseKey}___anon` when no user is
  /// authenticated). See [_keyFor].
  static const _baseKey = '_coach_insights';

  /// Base SharedPreferences key for [InsightType.event] records. Events
  /// live in a separate namespace from `_baseKey` because they are
  /// durable anchors (scan LPP, life event, major financial action)
  /// that must survive the 50-insight FIFO pruning applied to `fact`
  /// insights. Per panel adversaire 2026-04-18 B5: with the coach's
  /// system prompt ordering `save_insight` "on every key fact", 50 is
  /// exhausted within a week of active coaching and scan anchors get
  /// silently evicted. Events get their own non-pruned list.
  static const _eventsBaseKey = '_coach_events';

  /// Compute the per-user storage key. Falls back to an anonymous
  /// namespace if no JWT user_id is available — that data NEVER
  /// crosses into an authenticated account.
  static Future<String> _keyFor() async {
    try {
      final uid = await AuthService.getUserId();
      if (uid != null && uid.isNotEmpty) {
        return '${_baseKey}_$uid';
      }
    } catch (e) {
      debugPrint('[CoachMemory] auth lookup failed, anon namespace: $e');
    }
    return '${_baseKey}___anon';
  }

  /// Compute the per-user events storage key. Same account-isolation
  /// contract as [_keyFor] but for the non-pruned event namespace.
  static Future<String> _eventsKeyFor() async {
    try {
      final uid = await AuthService.getUserId();
      if (uid != null && uid.isNotEmpty) {
        return '${_eventsBaseKey}_$uid';
      }
    } catch (e) {
      debugPrint('[CoachMemory] auth lookup failed, anon events namespace: $e');
    }
    return '${_eventsBaseKey}___anon';
  }

  // Backwards compat alias (used internally; resolves at call time).
  // The constant name is preserved so call sites remain readable.
  static Future<String> get _key => _keyFor();
  static Future<String> get _eventsKey => _eventsKeyFor();

  /// Maximum number of insights to retain (FIFO pruning).
  static const _maxInsights = 50;

  // ── Write ────────────────────────────────────────────────

  /// Save a key insight from the current conversation.
  ///
  /// Inserts at position 0 (most recent first). Prunes automatically
  /// when the total exceeds [_maxInsights].
  ///
  /// [prefs] — injectable SharedPreferences for testing.
  static Future<void> saveInsight(
    CoachInsight insight, {
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final insights = await _load(sp);

    // Deduplicate: replace existing insight with same id
    insights.removeWhere((i) => i.id == insight.id);
    insights.insert(0, insight);

    await _save(sp, insights);
    await prune(prefs: sp);

    // Sync to backend RAG vector store (fire-and-forget, Phase 3.1).
    // Embeds the insight so the coach can retrieve it semantically.
    _syncToBackend(insight).catchError((e) { debugPrint('[CoachMemory] Sync failed: $e'); });
  }

  /// Sync insight to backend for RAG embedding (fire-and-forget).
  static Future<void> _syncToBackend(CoachInsight insight) async {
    try {
      final baseUrl = ApiService.baseUrl;
      final token = await AuthService.getToken();
      if (token == null) return;

      await http.post(
        Uri.parse('$baseUrl/coach/sync-insight'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'insight_id': insight.id,
          'topic': insight.topic,
          'summary': insight.summary,
          'insight_type': insight.type.name,
          if (insight.metadata != null) 'metadata': _filterMetadata(insight.metadata!),
          'created_at': insight.createdAt.toUtc().toIso8601String(),
        }),
      );
    } catch (e, st) {
      // Fire-and-forget: sync failure is not user-facing, but Gate 0 #10
      // requires observability — silent catches were hiding flaky network
      // and stale-token bugs for weeks. Log so it shows up in Sentry /
      // device console without breaking the user flow.
      debugPrint('[CoachMemory] _syncToBackend failed: $e\n$st');
    }
  }

  /// FIX-068: Notify backend to remove orphaned embedding after local prune.
  static Future<void> _syncRemoveToBackend(String insightId) async {
    try {
      final baseUrl = ApiService.baseUrl;
      final token = await AuthService.getToken();
      if (token == null) return;
      await http.delete(
        Uri.parse('$baseUrl/coach/sync-insight/$insightId'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (e, st) {
      debugPrint('[CoachMemory] _syncRemoveToBackend($insightId) failed: $e\n$st');
    }
  }

  /// Filter metadata before sending to backend (defense-in-depth).
  /// Only safe keys are transmitted — PII never leaves the device.
  static Map<String, dynamic> _filterMetadata(Map<String, dynamic> meta) {
    const safeKeys = {'templateId', 'stepCount', 'documentType', 'sequenceId'};
    return Map.fromEntries(
      meta.entries.where((e) => safeKeys.contains(e.key)),
    );
  }

  // ── Read ─────────────────────────────────────────────────

  /// Retrieve all stored insights, most recent first.
  ///
  /// Returns an empty list if no insights have been saved.
  static Future<List<CoachInsight>> getInsights({
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    return await _load(sp);
  }

  /// Get insights relevant to a specific topic / intent tag.
  ///
  /// Case-insensitive substring match against [CoachInsight.topic].
  static Future<List<CoachInsight>> getInsightsForTopic(
    String intentTag, {
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final all = await _load(sp);
    final tag = intentTag.toLowerCase().trim();
    return all
        .where((i) => i.topic.toLowerCase().contains(tag))
        .toList();
  }

  // ── Events (non-pruned durable anchors) ────────────────
  // Wave A-MINIMAL 2026-04-18. Events are stored in a separate
  // namespace from regular `fact`/`goal`/etc insights so they survive
  // the 50-insight FIFO pruning. Examples: scan LPP, life event,
  // major financial action. Events are local-only (NOT synced to
  // backend RAG) for v1 — panel archi AJ-2 2026-04-18 — because the
  // coach_tools enum + tests have been widened but backend extractor
  // and embedder have not been reviewed for `event` fidelity.
  // ──────────────────────────────────────────────────────

  /// Persist a durable event anchor. Dedup by (topic + date-day):
  /// calling saveEvent twice for the same topic on the same calendar
  /// day replaces the previous entry instead of creating a duplicate.
  static Future<void> saveEvent(
    String topic,
    String summary, {
    DateTime? date,
    Map<String, dynamic>? metadata,
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final events = await _loadEvents(sp);
    // A2-fix (2026-04-18) post-exec audit panel bugs BUG #4:
    // Dedup MUST use the user's LOCAL day, not UTC. A Swiss user
    // scanning at 01h30 local (CEST) creates an event at 23h30 UTC
    // the previous day; if they re-scan at 23h30 local (21h30 UTC
    // same day) the old logic would treat it as a different UTC day
    // and skip dedup, while the user saw two same-day scans. The
    // inverse also happened in winter. Compare local calendar days.
    final nowLocal = (date ?? DateTime.now()).toLocal();
    final dayKey = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    events.removeWhere((e) {
      final eLocal = e.createdAt.toLocal();
      final eDay = DateTime(eLocal.year, eLocal.month, eLocal.day);
      return e.topic == topic && eDay == dayKey;
    });

    final entry = CoachInsight(
      // Deterministic id per (topic, local day) so the dedup is
      // idempotent — repeated saveEvent calls on the same day
      // produce identical ids and the removeWhere above collapses
      // them before insertion.
      id: 'event_${topic}_${dayKey.toIso8601String().substring(0, 10)}',
      createdAt: nowLocal,
      topic: topic,
      summary: summary,
      type: InsightType.event,
      metadata: metadata,
    );
    events.insert(0, entry);
    try {
      await _saveEvents(sp, events);
    } catch (e, st) {
      // A2-fix (panel façade #6): _saveEvents can throw synchronously
      // on SharedPreferences write failures. Surface the error via
      // debugPrint so Sentry/device console can pick it up, but never
      // break the caller's flow — scans continue working even if the
      // memory persistence fails for this one entry.
      debugPrint('[CoachMemory] saveEvent($topic) persist failed: $e\n$st');
    }
  }

  /// Visible-for-testing inspection of the events list. Not part of
  /// the production API — callers that need to read events in prod
  /// should re-introduce a purposeful getter in the same commit that
  /// wires the consumer (façade-sans-câblage hard-stop, 2026-04-18).
  @visibleForTesting
  static Future<List<CoachInsight>> debugGetEvents({
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    return _loadEvents(sp);
  }

  static Future<List<CoachInsight>> _loadEvents(SharedPreferences sp) async {
    final k = await _eventsKey;
    final raw = sp.getString(k);
    if (raw == null) return [];
    return CoachInsight.decodeList(raw);
  }

  static Future<void> _saveEvents(
    SharedPreferences sp,
    List<CoachInsight> events,
  ) async {
    final k = await _eventsKey;
    await sp.setString(k, CoachInsight.encodeList(events));
  }

  // ── Maintenance ──────────────────────────────────────────

  /// Prune old insights — keeps the [_maxInsights] most recent.
  ///
  /// Called automatically by [saveInsight]; can also be called
  /// manually on app startup.
  static Future<void> prune({SharedPreferences? prefs}) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final insights = await _load(sp);

    if (insights.length <= _maxInsights) return;

    // FIX-068: Identify pruned insights for backend cleanup.
    final pruned = insights.take(_maxInsights).toList();
    final removed = insights.skip(_maxInsights).toList();
    await _save(sp, pruned);

    // Fire-and-forget: notify backend to remove orphaned embeddings.
    for (final insight in removed) {
      _syncRemoveToBackend(insight.id).catchError((e) { debugPrint('[CoachMemory] Remove sync failed: $e'); });
    }
  }

  /// Clear all stored insights.
  ///
  /// Used for testing, account reset, or GDPR deletion.
  /// Wave A-MINIMAL 2026-04-18: also clears the events namespace so
  /// logout/reset wipes durable anchors alongside regular insights.
  static Future<void> clear({SharedPreferences? prefs}) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final k = await _key;
    await sp.remove(k);
    // Also clear the anonymous namespace so logging out of one account
    // and into another can't surface stale anon-era insights.
    await sp.remove('${_baseKey}___anon');
    // Events namespace (non-pruned durable anchors).
    final ek = await _eventsKey;
    await sp.remove(ek);
    await sp.remove('${_eventsBaseKey}___anon');
  }

  // ── Private helpers ─────────────────────────────────────

  /// Load insights from SharedPreferences (per-user namespaced).
  ///
  /// Returns empty list on missing key or parse error.
  static Future<List<CoachInsight>> _load(SharedPreferences sp) async {
    final k = await _key;
    final raw = sp.getString(k);
    if (raw == null) return [];
    return CoachInsight.decodeList(raw);
  }

  /// Persist insights to SharedPreferences (per-user namespaced).
  static Future<void> _save(
    SharedPreferences sp,
    List<CoachInsight> insights,
  ) async {
    final k = await _key;
    await sp.setString(k, CoachInsight.encodeList(insights));
  }
}
