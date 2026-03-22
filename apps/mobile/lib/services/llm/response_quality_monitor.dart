/// Response Quality Monitor — Sprint S64 (Multi-LLM Redundancy).
///
/// Scores and tracks LLM response quality across providers without
/// requiring an additional LLM call.
///
/// Scoring axes:
///   - relevance:   keyword overlap between user message and response (0-1)
///   - compliance:  absence of banned terms + presence of disclaimer (0-1)
///   - length:      appropriate response length — 50-500 chars = 1.0 (0-1)
///   - composite:   0.4×relevance + 0.4×compliance + 0.2×length
///
/// All scoring functions are pure (no side effects).
/// [record] and [averageByProvider] own SharedPreferences I/O.
///
/// References:
///   - LSFin art. 3/8 (qualité de l'information financière)
///   - CLAUDE.md § 6: banned terms
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

// ════════════════════════════════════════════════════════════════
//  BANNED TERMS (mirror of ComplianceGuard)
// ════════════════════════════════════════════════════════════════

/// Terms banned from user-facing responses (CLAUDE.md § 6).
///
/// Presence of any term reduces the compliance axis score.
const _bannedTerms = <String>[
  'garanti',
  'garantis',
  'garantie',
  'certain',
  'certaine',
  'assur\u00e9',
  'assur\u00e9e',
  'sans risque',
  'optimal',
  'optimale',
  'optimaux',
  'meilleur',
  'meilleure',
  'meilleurs',
  'meilleures',
  'parfait',
  'parfaite',
];

/// Disclaimer fragments that indicate compliance awareness.
const _disclaimerFragments = <String>[
  '\u00e9ducatif',
  'conseil financier',
  'lsfin',
  'sp\u00e9cialiste',
  'consult',
];

// ════════════════════════════════════════════════════════════════
//  DATA TYPES
// ════════════════════════════════════════════════════════════════

/// Quality score for a single LLM response.
class QualityScore {
  /// Provider that produced the response (e.g., "claude", "openai").
  final String provider;

  /// 0-1: does the response address the user's question?
  ///
  /// Computed as Jaccard-like overlap between user message keywords
  /// and response words.
  final double relevance;

  /// 0-1: absence of banned terms and presence of disclaimer.
  final double compliance;

  /// 0-1: appropriate response length.
  ///
  /// 50-500 chars → 1.0; < 20 chars or > 2000 chars → 0.5; < 5 chars → 0.0.
  final double length;

  /// Weighted composite: 0.4×relevance + 0.4×compliance + 0.2×length.
  final double composite;

  /// When this score was recorded.
  final DateTime timestamp;

  const QualityScore({
    required this.provider,
    required this.relevance,
    required this.compliance,
    required this.length,
    required this.composite,
    required this.timestamp,
  });

  /// Serialise to a JSON-compatible map for SharedPreferences storage.
  Map<String, dynamic> toJson() => {
        'provider': provider,
        'relevance': relevance,
        'compliance': compliance,
        'length': length,
        'composite': composite,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Deserialise from a JSON map.
  factory QualityScore.fromJson(Map<String, dynamic> json) => QualityScore(
        provider: json['provider'] as String,
        relevance: (json['relevance'] as num).toDouble(),
        compliance: (json['compliance'] as num).toDouble(),
        length: (json['length'] as num).toDouble(),
        composite: (json['composite'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

// ════════════════════════════════════════════════════════════════
//  MONITOR
// ════════════════════════════════════════════════════════════════

/// Scores and tracks LLM response quality per provider.
///
/// All scoring methods are pure functions (no side effects).
/// Storage is owned by [record] and [averageByProvider].
class ResponseQualityMonitor {
  ResponseQualityMonitor._();

  // ── Storage keys ────────────────────────────────────────────

  static const _scoresKeyPrefix = '_llm_quality_scores_';

  /// Maximum scores retained per provider (sliding window).
  static const int maxScoresPerProvider = 50;

  // ══════════════════════════════════════════════════════════════
  //  PUBLIC API — pure scoring
  // ══════════════════════════════════════════════════════════════

  /// Score an LLM response on quality dimensions.
  ///
  /// Pure function — no side effects.
  ///
  /// [response] is the response text to score.
  /// [userMessage] is the original user question.
  /// [provider] is the provider identifier (e.g., "claude").
  static QualityScore score(
    String response,
    String userMessage, {
    required String provider,
  }) {
    final rel = _scoreRelevance(response, userMessage);
    final comp = _scoreCompliance(response);
    final len = _scoreLength(response);
    final composite = _composite(rel, comp, len);

    return QualityScore(
      provider: provider,
      relevance: rel,
      compliance: comp,
      length: len,
      composite: composite,
      timestamp: DateTime.now(),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PUBLIC API — persistence
  // ══════════════════════════════════════════════════════════════

  /// Record a quality score for future aggregation.
  ///
  /// Stores scores in SharedPreferences keyed by provider.
  /// Keeps a sliding window of [maxScoresPerProvider] per provider.
  static Future<void> record(
    QualityScore score,
    SharedPreferences prefs,
  ) async {
    final key = _scoresKeyPrefix + score.provider;
    final existing = _loadScores(prefs, score.provider);
    existing.add(score);

    // Trim to sliding window.
    final trimmed = existing.length > maxScoresPerProvider
        ? existing.sublist(existing.length - maxScoresPerProvider)
        : existing;

    final encoded =
        jsonEncode(trimmed.map((s) => s.toJson()).toList());
    await prefs.setString(key, encoded);
  }

  /// Get the average composite quality score per provider.
  ///
  /// Returns an empty map if no scores have been recorded.
  static Future<Map<String, double>> averageByProvider(
    SharedPreferences prefs,
  ) async {
    // Collect all provider keys from prefs.
    final allKeys = prefs.getKeys();
    final result = <String, double>{};

    for (final key in allKeys) {
      if (!key.startsWith(_scoresKeyPrefix)) continue;
      final provider = key.substring(_scoresKeyPrefix.length);
      final scores = _loadScores(prefs, provider);
      if (scores.isEmpty) continue;
      final avg = scores.map((s) => s.composite).reduce((a, b) => a + b) /
          scores.length;
      result[provider] = avg;
    }

    return result;
  }

  /// Load all stored [QualityScore]s for a provider.
  ///
  /// Returns an empty list if none found or on parse error.
  static List<QualityScore> loadScoresForProvider(
    SharedPreferences prefs,
    String provider,
  ) {
    return _loadScores(prefs, provider);
  }

  /// Clear all stored quality scores (testing/reset).
  static Future<void> clearAll(SharedPreferences prefs) async {
    final keys =
        prefs.getKeys().where((k) => k.startsWith(_scoresKeyPrefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  INTERNAL — scoring axes (pure functions)
  // ══════════════════════════════════════════════════════════════

  /// Relevance: keyword overlap between user message and response.
  ///
  /// Extracts content words (≥ 4 chars) from both strings.
  /// Returns Jaccard-like score: |intersection| / |userKeywords|.
  /// Returns 0.5 when user message has no content words (open-ended).
  static double _scoreRelevance(String response, String userMessage) {
    if (response.isEmpty) return 0.0;

    final userWords = _contentWords(userMessage);
    if (userWords.isEmpty) return 0.5; // open-ended question

    final responseWords = _contentWords(response);
    if (responseWords.isEmpty) return 0.0;

    final intersection =
        userWords.where((w) => responseWords.contains(w)).length;
    final relevance = intersection / userWords.length;

    return relevance.clamp(0.0, 1.0);
  }

  /// Compliance: penalise banned terms, reward disclaimer presence.
  ///
  /// Starts at 1.0.
  /// Each banned term found: -0.15.
  /// No disclaimer found: -0.20.
  /// Clamped to [0.0, 1.0].
  static double _scoreCompliance(String response) {
    if (response.isEmpty) return 0.0;

    var score = 1.0;
    final lower = response.toLowerCase();

    for (final term in _bannedTerms) {
      if (lower.contains(term)) {
        score -= 0.15;
      }
    }

    // Reward disclaimer presence.
    final hasDisclaimer =
        _disclaimerFragments.any((f) => lower.contains(f));
    if (!hasDisclaimer) {
      score -= 0.20;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Length score.
  ///
  /// < 5 chars      → 0.0 (essentially empty)
  /// < 20 chars     → 0.5 (very short)
  /// 20-49 chars    → 0.75 (borderline)
  /// 50-500 chars   → 1.0 (ideal range)
  /// 501-2000 chars → 0.75 (long but acceptable)
  /// > 2000 chars   → 0.5 (excessively long)
  static double _scoreLength(String response) {
    final len = response.length;
    if (len < 5) return 0.0;
    if (len < 20) return 0.5;
    if (len < 50) return 0.75;
    if (len <= 500) return 1.0;
    if (len <= 2000) return 0.75;
    return 0.5;
  }

  /// Composite: 0.4×relevance + 0.4×compliance + 0.2×length.
  static double _composite(
    double relevance,
    double compliance,
    double length,
  ) {
    final composite = 0.4 * relevance + 0.4 * compliance + 0.2 * length;
    return composite.clamp(0.0, 1.0);
  }

  /// Extract content words (≥ 4 chars, lowercased, alphanumeric).
  static Set<String> _contentWords(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'[^\w\u00c0-\u024f]+'))
        .where((w) => w.length >= 4)
        .toSet();
  }

  // ══════════════════════════════════════════════════════════════
  //  INTERNAL — storage
  // ══════════════════════════════════════════════════════════════

  static List<QualityScore> _loadScores(
    SharedPreferences prefs,
    String provider,
  ) {
    final key = _scoresKeyPrefix + provider;
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => QualityScore.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  EXPOSED INTERNALS (for testing)
  // ══════════════════════════════════════════════════════════════

  /// Relevance scoring (exposed for unit testing).
  static double scoreRelevance(String response, String userMessage) =>
      _scoreRelevance(response, userMessage);

  /// Compliance scoring (exposed for unit testing).
  static double scoreCompliance(String response) =>
      _scoreCompliance(response);

  /// Length scoring (exposed for unit testing).
  static double scoreLength(String response) => _scoreLength(response);

  /// Composite scoring (exposed for unit testing).
  static double computeComposite(
    double relevance,
    double compliance,
    double length,
  ) =>
      _composite(relevance, compliance, length);

}
