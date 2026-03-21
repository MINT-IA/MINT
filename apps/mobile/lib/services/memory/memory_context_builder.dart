import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/models/coach_insight.dart';
import 'package:mint_mobile/services/memory/coach_memory_service.dart';
import 'package:mint_mobile/services/coach/goal_tracker_service.dart';

// ────────────────────────────────────────────────────────────
//  MEMORY CONTEXT BUILDER — S58 / AI Memory
// ────────────────────────────────────────────────────────────
//
// Builds a structured context string from persisted memory for
// injection into the LLM system prompt.
//
// Context combines:
//   1. CoachInsights (goals, decisions, concerns, facts)
//   2. Active UserGoals (from GoalTrackerService)
//
// Format:
//   --- MÉMOIRE CROSS-SESSION ---
//   [Privacy reminder]
//   INSIGHTS CLÉS (N) :
//     - [goal] topic: summary (date)
//     ...
//   OBJECTIFS ACTIFS (N) :
//     - description (depuis X jours)
//     ...
//   --- FIN MÉMOIRE CROSS-SESSION ---
//
// Privacy rules (CLAUDE.md §7 + §6):
//   - NEVER include exact salary, IBAN, name, SSN, employer
//   - Use ranges only ("revenu ~120k CHF" not "122'207 CHF")
//   - metadata from CoachInsight is NEVER injected verbatim
//   - Max 1500 chars total to keep LLM token cost low
//
// Pure static methods. Async only for SharedPreferences I/O.
// ────────────────────────────────────────────────────────────

/// Builds a context string for LLM system prompt injection
/// from all persisted memory (insights + goals).
class MemoryContextBuilder {
  MemoryContextBuilder._();

  /// Maximum total length of the generated context block (chars).
  static const _maxLength = 1500;

  /// Build a context string from all saved memory sources.
  ///
  /// This string is injected into the coach AI system prompt to
  /// give Claude cross-session awareness.
  ///
  /// Returns an empty string when no memory exists.
  ///
  /// [prefs] — injectable SharedPreferences for testing.
  /// [now]   — override for deterministic tests.
  static Future<String> buildContext({
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final currentDate = now ?? DateTime.now();

    // Load memory sources in parallel
    final results = await Future.wait([
      CoachMemoryService.getInsights(prefs: sp),
      GoalTrackerService.activeGoals(prefs: sp),
    ]);

    final insights = results[0] as List<CoachInsight>;
    final goals = results[1] as List<UserGoal>;

    if (insights.isEmpty && goals.isEmpty) return '';

    final block = _buildBlock(
      insights: insights,
      goals: goals,
      now: currentDate,
    );

    return block;
  }

  /// Build context from pre-loaded data (pure function — no I/O).
  ///
  /// Exposed for unit testing without SharedPreferences.
  static String buildContextFromData({
    required List<CoachInsight> insights,
    required List<UserGoal> goals,
    required DateTime now,
  }) {
    if (insights.isEmpty && goals.isEmpty) return '';
    return _buildBlock(insights: insights, goals: goals, now: now);
  }

  // ── Private ──────────────────────────────────────────────

  static String _buildBlock({
    required List<CoachInsight> insights,
    required List<UserGoal> goals,
    required DateTime now,
  }) {
    final parts = <String>[];

    parts.add('--- MÉMOIRE CROSS-SESSION ---');
    parts.add(
      'RAPPEL\u00a0: Utilise ce contexte pour personnaliser ta réponse. '
      'Ne jamais mentionner de données personnelles exactes '
      '(salaire, IBAN, nom, employeur). Approximations uniquement.',
    );

    // Insights block
    if (insights.isNotEmpty) {
      final topInsights = insights.take(10).toList();
      parts.add('');
      parts.add('INSIGHTS CLÉS (${topInsights.length})\u00a0:');
      for (final insight in topInsights) {
        final daysSince = now.difference(insight.createdAt).inDays;
        final ageText = _ageText(daysSince);
        final sanitized = _sanitize(insight.summary, maxLen: 120);
        parts.add(
          '  - [${insight.type.name}] ${insight.topic}\u00a0: '
          '$sanitized ($ageText)',
        );
      }
      if (insights.length > 10) {
        parts.add('  ... et ${insights.length - 10} autres insights.');
      }
    }

    // Goals block
    if (goals.isNotEmpty) {
      final topGoals = goals.take(5).toList();
      parts.add('');
      parts.add('OBJECTIFS ACTIFS (${topGoals.length})\u00a0:');
      for (final goal in topGoals) {
        final daysSince = now.difference(goal.createdAt).inDays;
        final ageText = _ageText(daysSince);
        final sanitized = _sanitize(goal.description, maxLen: 100);
        String line = '  - "$sanitized" (depuis $ageText';
        if (goal.targetDate != null) {
          final daysLeft = goal.targetDate!.difference(now).inDays;
          if (daysLeft > 0) {
            line += ', échéance dans $daysLeft '
                '${daysLeft == 1 ? 'jour' : 'jours'}';
          }
        }
        line += ')';
        parts.add(line);
      }
      if (goals.length > 5) {
        parts.add('  ... et ${goals.length - 5} autres objectifs.');
      }
    }

    parts.add('--- FIN MÉMOIRE CROSS-SESSION ---');

    final full = parts.join('\n');
    return full.length > _maxLength
        ? '${full.substring(0, _maxLength - 3)}...'
        : full;
  }

  /// Format a day count as a human-readable French string.
  static String _ageText(int days) {
    if (days == 0) return "aujourd'hui";
    if (days == 1) return 'hier';
    if (days < 7) return 'il y a $days jours';
    final weeks = (days / 7).round();
    if (weeks == 1) return 'il y a 1 semaine';
    if (weeks < 5) return 'il y a $weeks semaines';
    final months = (days / 30).round();
    if (months == 1) return 'il y a 1 mois';
    return 'il y a $months mois';
  }

  /// Sanitize user-provided text: strip control chars, truncate.
  ///
  /// Strips newlines, tabs, and control characters.
  /// Truncates to [maxLen] chars with ellipsis.
  static String _sanitize(String text, {required int maxLen}) {
    var s = text
        .replaceAll(RegExp(r'[\n\r\t\x00-\x1F]'), ' ')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();
    return s.length > maxLen ? '${s.substring(0, maxLen)}…' : s;
  }
}
