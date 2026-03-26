import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/models/coach_insight.dart';

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
// ARCHITECTURAL NOTE (V12-5): SharedPreferences keys are global, not per-account.
// Account isolation relies on purge at logout/deleteAccount (auth_provider.dart).
// TODO: Prefix all keys with user ID for native multi-account isolation.
// ────────────────────────────────────────────────────────────

/// Persists and retrieves [CoachInsight] records across sessions.
class CoachMemoryService {
  CoachMemoryService._();

  /// SharedPreferences key for the insights list.
  static const _key = '_coach_insights';

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
    final insights = _load(sp);

    // Deduplicate: replace existing insight with same id
    insights.removeWhere((i) => i.id == insight.id);
    insights.insert(0, insight);

    await _save(sp, insights);
    await prune(prefs: sp);
  }

  // ── Read ─────────────────────────────────────────────────

  /// Retrieve all stored insights, most recent first.
  ///
  /// Returns an empty list if no insights have been saved.
  static Future<List<CoachInsight>> getInsights({
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    return _load(sp);
  }

  /// Get insights relevant to a specific topic / intent tag.
  ///
  /// Case-insensitive substring match against [CoachInsight.topic].
  static Future<List<CoachInsight>> getInsightsForTopic(
    String intentTag, {
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final all = _load(sp);
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
    final insights = _load(sp);

    if (insights.length <= _maxInsights) return;

    // Already sorted most-recent-first; keep head
    final pruned = insights.take(_maxInsights).toList();
    await _save(sp, pruned);
  }

  /// Clear all stored insights.
  ///
  /// Used for testing, account reset, or GDPR deletion.
  static Future<void> clear({SharedPreferences? prefs}) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    await sp.remove(_key);
  }

  // ── Private helpers ─────────────────────────────────────

  /// Load insights from SharedPreferences (sync decode).
  ///
  /// Returns empty list on missing key or parse error.
  static List<CoachInsight> _load(SharedPreferences sp) {
    final raw = sp.getString(_key);
    if (raw == null) return [];
    return CoachInsight.decodeList(raw);
  }

  /// Persist insights to SharedPreferences.
  static Future<void> _save(
    SharedPreferences sp,
    List<CoachInsight> insights,
  ) async {
    await sp.setString(_key, CoachInsight.encodeList(insights));
  }
}
