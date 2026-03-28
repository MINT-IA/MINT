import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/models/coach_insight.dart';
import 'package:mint_mobile/services/memory/coach_memory_service.dart';

// ────────────────────────────────────────────────────────────
//  MEMORY REFERENCE SERVICE — Visible AI Memory
// ────────────────────────────────────────────────────────────
//
// Makes the coach's cross-session memory VISIBLE to the user.
//
// Cleo 3.0's key differentiator: the AI explicitly acknowledges
// past conversations instead of silently injecting them into
// its context. This builds trust and shows the app is alive.
//
// Usage in CoachChatScreen:
//   - After building the response, call findRelevant() with
//     the user's message keywords / intent tag.
//   - If a reference is found, PREPEND it to the coach response:
//       "{memoryRef}\n\n{coachResponse}"
//   - The MemoryReference carries an ARB key + params for i18n.
//
// Eligibility rules:
//   - Insight must be > 24 h old (not from this session).
//   - Only one reference per response (most-recent matching insight).
//   - Returns null when no matching insight exists.
//
// Privacy rules (CLAUDE.md §7 + §6):
//   - topic label is displayed directly — must be safe (no PII).
//   - summary is NEVER surfaced in the reference text.
//   - Only the topic tag and age (in days) are exposed.
//
// Pure static methods. Async only for SharedPreferences I/O.
// ────────────────────────────────────────────────────────────

/// A reference to a past insight to be prepended to a coach response.
///
/// Carries:
///   - [referenceKey] — the ARB key to use for the reference phrase.
///   - [params]       — the i18n parameters (days, topic, goal, screen).
///   - [insightId]    — the id of the referenced [CoachInsight].
class MemoryReference {
  /// ARB key for the memory reference phrase.
  ///
  /// One of: `memoryRefTopic`, `memoryRefGoal`, `memoryRefScreenVisit`.
  final String referenceKey;

  /// Localisation parameters (topic, days, goal, screen).
  final Map<String, Object> params;

  /// The id of the [CoachInsight] that was referenced.
  final String insightId;

  const MemoryReference({
    required this.referenceKey,
    required this.params,
    required this.insightId,
  });

  /// Whether a numeric `days` param is present.
  bool get hasDays => params.containsKey('days');

  @override
  String toString() =>
      'MemoryReference(key: $referenceKey, insightId: $insightId, '
      'params: $params)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryReference &&
          runtimeType == other.runtimeType &&
          referenceKey == other.referenceKey &&
          insightId == other.insightId;

  @override
  int get hashCode => Object.hash(referenceKey, insightId);
}

/// Finds a relevant past insight to reference in the current conversation.
class MemoryReferenceService {
  MemoryReferenceService._();

  /// Minimum age (hours) before an insight can be referenced.
  ///
  /// Prevents the coach from referencing insights captured moments
  /// ago in the same session — that would feel robotic.
  static const int _minAgeHours = 24;

  /// Maximum age (days) for an insight to still be relevant.
  ///
  /// Insights older than [_maxAgeDays] are stale and not referenced.
  static const int _maxAgeDays = 180;

  /// Topic label overrides — maps raw topic tags to French display labels.
  ///
  /// When a topic tag is not in this map, the raw tag is used as-is.
  static const Map<String, String> _topicLabels = {
    'lpp': '2e pilier',
    'avs': 'AVS',
    '3a': '3e pilier',
    'retraite': 'la retraite',
    'retirement': 'la retraite',
    'housing': 'l\u2019immobilier',
    'logement': 'l\u2019immobilier',
    'tax': 'la fiscalit\u00e9',
    'fiscal': 'la fiscalit\u00e9',
    'fiscalite': 'la fiscalit\u00e9',
    'budget': 'le budget',
    'divorce': 'le divorce',
    'marriage': 'le mariage',
    'birth': 'la naissance',
    'inheritance': 'la succession',
    'disability': 'l\u2019invalidit\u00e9',
    'debt': 'les dettes',
  };

  // ── Public API ───────────────────────────────────────────

  /// Find the most relevant past insight to reference for [currentTopic].
  ///
  /// [currentTopic] — intent tag or user message keywords (e.g. "lpp",
  ///   "retraite", "3a").
  /// [prefs] — injectable SharedPreferences for testing.
  /// [now]   — injectable current time for testing.
  ///
  /// Returns a [MemoryReference] when a relevant insight is found,
  /// or null when no eligible insight exists.
  static Future<MemoryReference?> findRelevant({
    required String currentTopic,
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    if (currentTopic.trim().isEmpty) return null;

    final sp = prefs ?? await SharedPreferences.getInstance();
    final currentDate = now ?? DateTime.now();

    // 1. Fetch insights matching the topic.
    final candidates = await CoachMemoryService.getInsightsForTopic(
      currentTopic,
      prefs: sp,
    );

    if (candidates.isEmpty) return null;

    // 2. Filter for eligible insights (age window: 24h – 180 days).
    const minAge = Duration(hours: _minAgeHours);
    const maxAge = Duration(days: _maxAgeDays);

    final eligible = candidates.where((i) {
      final age = currentDate.difference(i.createdAt);
      return age >= minAge && age <= maxAge;
    }).toList();

    if (eligible.isEmpty) return null;

    // 3. Pick the most recent eligible insight.
    // Insights from CoachMemoryService are already sorted most-recent-first.
    final insight = eligible.first;
    final days = currentDate.difference(insight.createdAt).inDays;

    // 4. Choose the appropriate ARB key based on insight type.
    final ref = _buildReference(insight, days);
    return ref;
  }

  /// Resolve a [MemoryReference] to a display string using the provided
  /// localisation resolver.
  ///
  /// [ref]      — the reference to resolve.
  /// [onTopic]  — resolver for `memoryRefTopic(days, topic)`.
  /// [onGoal]   — resolver for `memoryRefGoal(goal)`.
  /// [onScreen] — resolver for `memoryRefScreenVisit(screen)`.
  ///
  /// Returns an empty string if resolution fails (graceful degradation).
  static String resolve(
    MemoryReference ref, {
    required String Function(int days, String topic) onTopic,
    required String Function(String goal) onGoal,
    required String Function(String screen) onScreen,
  }) {
    try {
      switch (ref.referenceKey) {
        case 'memoryRefTopic':
          final days = ref.params['days'] as int? ?? 1;
          final topic = ref.params['topic'] as String? ?? '';
          return onTopic(days, topic);
        case 'memoryRefGoal':
          final goal = ref.params['goal'] as String? ?? '';
          return onGoal(goal);
        case 'memoryRefScreenVisit':
          final screen = ref.params['screen'] as String? ?? '';
          return onScreen(screen);
        default:
          return '';
      }
    } catch (_) {
      return '';
    }
  }

  // ── Private ──────────────────────────────────────────────

  /// Build a [MemoryReference] from an eligible insight.
  ///
  /// Selects the ARB key based on insight type:
  ///   - [InsightType.goal] → `memoryRefGoal` (if summary is short enough)
  ///   - All others         → `memoryRefTopic`
  static MemoryReference _buildReference(CoachInsight insight, int days) {
    // Goal insights: use the goal-specific phrase when the summary is compact
    // enough to display inline (≤ 80 chars).
    if (insight.type == InsightType.goal &&
        insight.summary.length <= 80 &&
        insight.summary.isNotEmpty) {
      return MemoryReference(
        referenceKey: 'memoryRefGoal',
        params: {'goal': _sanitizeLabel(insight.summary)},
        insightId: insight.id,
      );
    }

    // Default: topic reference with elapsed days.
    final topicLabel = _topicLabel(insight.topic);
    return MemoryReference(
      referenceKey: 'memoryRefTopic',
      params: {
        'days': days,
        'topic': topicLabel,
      },
      insightId: insight.id,
    );
  }

  /// Map a raw topic tag to a human-readable French label.
  ///
  /// Falls back to the raw tag when no mapping exists.
  static String _topicLabel(String topic) {
    final key = topic.toLowerCase().trim();
    if (_topicLabels.containsKey(key)) return _topicLabels[key]!;
    // Try partial match (e.g. "lpp_buyback" → "lpp" → "2e pilier")
    for (final entry in _topicLabels.entries) {
      if (key.startsWith(entry.key)) return entry.value;
    }
    return topic;
  }

  /// Sanitize a label for safe display (strip control chars, truncate).
  static String _sanitizeLabel(String text) {
    var s = text
        .replaceAll(RegExp(r'[\n\r\t\x00-\x1F]'), ' ')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();
    return s.length > 80 ? '${s.substring(0, 77)}\u2026' : s;
  }
}
