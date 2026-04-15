import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
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

  /// Compute the per-user storage key. Falls back to an anonymous
  /// namespace if no JWT user_id is available — that data NEVER
  /// crosses into an authenticated account.
  static Future<String> _keyFor() async {
    try {
      final uid = await AuthService.getUserId();
      if (uid != null && uid.isNotEmpty) {
        return '${_baseKey}_$uid';
      }
    } catch (_) {
      // Never block memory ops on auth lookup failure — fall back to anon.
    }
    return '${_baseKey}___anon';
  }

  // Backwards compat alias (used internally; resolves at call time).
  // The constant name is preserved so call sites remain readable.
  static Future<String> get _key => _keyFor();

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
    } catch (_) {
      // Fire-and-forget: sync failure is not user-facing.
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
    } catch (_) {
      // Fire-and-forget: cleanup failure is not user-facing.
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
  static Future<void> clear({SharedPreferences? prefs}) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final k = await _key;
    await sp.remove(k);
    // Also clear the anonymous namespace so logging out of one account
    // and into another can't surface stale anon-era insights.
    await sp.remove('${_baseKey}___anon');
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
