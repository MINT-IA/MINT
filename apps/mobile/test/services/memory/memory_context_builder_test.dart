import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/models/coach_insight.dart';
import 'package:mint_mobile/services/coach/goal_tracker_service.dart';
import 'package:mint_mobile/services/memory/coach_memory_service.dart';
import 'package:mint_mobile/services/memory/memory_context_builder.dart';

// ────────────────────────────────────────────────────────────
//  MemoryContextBuilder TESTS — S58 / AI Memory
// ────────────────────────────────────────────────────────────
//
// 15 tests covering:
//   - Empty context when no memory exists
//   - Context contains delimiter markers
//   - Insights section in context
//   - Goals section in context
//   - Both insights and goals together
//   - Privacy: no banned terms in output
//   - Non-breaking spaces in French text
//   - Context truncated to max 1500 chars
//   - Age formatting (today, hier, N jours, N semaines, N mois)
//   - Control characters stripped from summaries
//   - Max 10 insights shown
//   - Max 5 goals shown
//   - Past target date no "échéance"
//   - buildContextFromData pure function
//   - Async buildContext reads from SharedPreferences
// ────────────────────────────────────────────────────────────

void main() {
  final now = DateTime(2026, 3, 18, 14, 0);

  CoachInsight makeInsight({
    required String id,
    String topic = 'lpp',
    String summary = 'Test insight summary',
    InsightType type = InsightType.fact,
    DateTime? createdAt,
  }) {
    return CoachInsight(
      id: id,
      createdAt: createdAt ?? now,
      topic: topic,
      summary: summary,
      type: type,
    );
  }

  UserGoal makeGoal({
    required String id,
    String description = 'Test goal',
    String category = 'other',
    DateTime? createdAt,
    DateTime? targetDate,
  }) {
    return UserGoal(
      id: id,
      description: description,
      category: category,
      createdAt: createdAt ?? now,
      targetDate: targetDate,
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ════════════════════════════════════════════════════════════
  //  EMPTY STATE
  // ════════════════════════════════════════════════════════════

  group('MemoryContextBuilder — empty state', () {
    test('returns empty string when no memory exists', () {
      final context = MemoryContextBuilder.buildContextFromData(
        insights: [],
        goals: [],
        now: now,
      );
      expect(context, isEmpty);
    });

    test('async buildContext returns empty when SharedPreferences empty', () async {
      final prefs = await SharedPreferences.getInstance();
      final context = await MemoryContextBuilder.buildContext(
        prefs: prefs,
        now: now,
      );
      expect(context, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  STRUCTURE
  // ════════════════════════════════════════════════════════════

  group('MemoryContextBuilder — structure', () {
    test('context contains opening and closing delimiters', () {
      final context = MemoryContextBuilder.buildContextFromData(
        insights: [makeInsight(id: 'i1')],
        goals: [],
        now: now,
      );

      expect(context, contains('--- MÉMOIRE CROSS-SESSION ---'));
      expect(context, contains('--- FIN MÉMOIRE CROSS-SESSION ---'));
    });

    test('context contains privacy reminder', () {
      final context = MemoryContextBuilder.buildContextFromData(
        insights: [makeInsight(id: 'i1')],
        goals: [],
        now: now,
      );

      expect(context, contains('Ne jamais mentionner'));
      expect(context, contains('IBAN'));
      expect(context, contains('salaire'));
    });

    test('context uses non-breaking space before colons', () {
      final context = MemoryContextBuilder.buildContextFromData(
        insights: [makeInsight(id: 'i1')],
        goals: [],
        now: now,
      );

      expect(context, contains('\u00a0:'));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  INSIGHTS SECTION
  // ════════════════════════════════════════════════════════════

  group('MemoryContextBuilder — insights section', () {
    test('insights appear in context with topic and summary', () {
      final context = MemoryContextBuilder.buildContextFromData(
        insights: [
          makeInsight(id: 'i1', topic: 'lpp', summary: 'Rachat LPP ~70k'),
        ],
        goals: [],
        now: now,
      );

      expect(context, contains('INSIGHTS CLÉS'));
      expect(context, contains('lpp'));
      expect(context, contains('Rachat LPP ~70k'));
    });

    test('insight type label appears in context', () {
      final context = MemoryContextBuilder.buildContextFromData(
        insights: [
          makeInsight(id: 'i1', type: InsightType.decision, summary: 'Capital retiré'),
        ],
        goals: [],
        now: now,
      );

      expect(context, contains('[decision]'));
    });

    test('max 10 insights shown with overflow message', () {
      final insights = List.generate(
        15,
        (i) => makeInsight(id: 'i$i', summary: 'Insight number $i'),
      );

      final context = MemoryContextBuilder.buildContextFromData(
        insights: insights,
        goals: [],
        now: now,
      );

      // Only shows 10, rest listed as "... et 5 autres"
      expect(context, contains('5 autres insights'));
    });

    test('exactly 10 insights shows no overflow message', () {
      final insights = List.generate(
        10,
        (i) => makeInsight(id: 'e$i', summary: 'Exact insight $i'),
      );

      final context = MemoryContextBuilder.buildContextFromData(
        insights: insights,
        goals: [],
        now: now,
      );

      expect(context, isNot(contains('autres insights')));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  GOALS SECTION
  // ════════════════════════════════════════════════════════════

  group('MemoryContextBuilder — goals section', () {
    test('goals appear in context', () {
      final context = MemoryContextBuilder.buildContextFromData(
        insights: [],
        goals: [makeGoal(id: 'g1', description: 'Acheter un appartement')],
        now: now,
      );

      expect(context, contains('OBJECTIFS ACTIFS'));
      expect(context, contains('Acheter un appartement'));
    });

    test('max 5 goals shown with overflow message', () {
      final goals = List.generate(
        8,
        (i) => makeGoal(id: 'g$i', description: 'Goal number $i unique'),
      );

      final context = MemoryContextBuilder.buildContextFromData(
        insights: [],
        goals: goals,
        now: now,
      );

      expect(context, contains('3 autres objectifs'));
    });

    test('past target date does not show échéance', () {
      final context = MemoryContextBuilder.buildContextFromData(
        insights: [],
        goals: [
          makeGoal(
            id: 'g1',
            description: 'Overdue goal',
            targetDate: now.subtract(const Duration(days: 10)),
          ),
        ],
        now: now,
      );

      expect(context, isNot(contains('échéance dans')));
    });

    test('future target date shows échéance dans', () {
      final context = MemoryContextBuilder.buildContextFromData(
        insights: [],
        goals: [
          makeGoal(
            id: 'g1',
            description: 'Future goal',
            targetDate: now.add(const Duration(days: 30)),
          ),
        ],
        now: now,
      );

      expect(context, contains('échéance dans'));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  AGE FORMATTING
  // ════════════════════════════════════════════════════════════

  group('MemoryContextBuilder — age formatting', () {
    test("insight created today shows aujourd'hui", () {
      final context = MemoryContextBuilder.buildContextFromData(
        insights: [makeInsight(id: 'today', createdAt: now)],
        goals: [],
        now: now,
      );
      expect(context, contains("aujourd'hui"));
    });

    test('insight created yesterday shows hier', () {
      final context = MemoryContextBuilder.buildContextFromData(
        insights: [
          makeInsight(
            id: 'yest',
            createdAt: now.subtract(const Duration(days: 1)),
          ),
        ],
        goals: [],
        now: now,
      );
      expect(context, contains('hier'));
    });

    test('insight created 3 days ago shows il y a 3 jours', () {
      final context = MemoryContextBuilder.buildContextFromData(
        insights: [
          makeInsight(
            id: 'd3',
            createdAt: now.subtract(const Duration(days: 3)),
          ),
        ],
        goals: [],
        now: now,
      );
      expect(context, contains('il y a 3 jours'));
    });

    test('insight created 14 days ago shows weeks', () {
      final context = MemoryContextBuilder.buildContextFromData(
        insights: [
          makeInsight(
            id: 'w2',
            createdAt: now.subtract(const Duration(days: 14)),
          ),
        ],
        goals: [],
        now: now,
      );
      expect(context, contains('semaines'));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  PRIVACY & COMPLIANCE
  // ════════════════════════════════════════════════════════════

  group('MemoryContextBuilder — privacy and compliance', () {
    test('context contains no banned absolute terms', () {
      final context = MemoryContextBuilder.buildContextFromData(
        insights: [makeInsight(id: 'i1', summary: 'Discussed retirement planning')],
        goals: [makeGoal(id: 'g1', description: 'Comprendre la rente')],
        now: now,
      );

      final lower = context.toLowerCase();
      expect(lower, isNot(contains('garanti')));
      expect(lower, isNot(contains('sans risque')));
      expect(lower, isNot(contains('optimal')));
      expect(lower, isNot(contains('meilleur')));
      expect(lower, isNot(contains('parfait')));
    });

    test('control characters in summaries are stripped', () {
      final context = MemoryContextBuilder.buildContextFromData(
        insights: [
          makeInsight(
            id: 'ctrl',
            summary: 'Goal with\nnewline\tand\ttabs',
          ),
        ],
        goals: [],
        now: now,
      );

      // Should not contain raw newlines within the insight line
      expect(context, contains('Goal with'));
      // No double-newlines from control char injection
      final lines = context.split('\n');
      for (final line in lines) {
        // No embedded \t in any line
        expect(line, isNot(contains('\t')));
      }
    });
  });

  // ════════════════════════════════════════════════════════════
  //  TRUNCATION
  // ════════════════════════════════════════════════════════════

  group('MemoryContextBuilder — truncation', () {
    test('context is truncated to 1500 chars max', () {
      // Create many insights with long summaries
      final insights = List.generate(
        10,
        (i) => makeInsight(
          id: 'long$i',
          summary: 'A' * 200, // 200-char summary each
          topic: 'topic_$i',
        ),
      );

      final context = MemoryContextBuilder.buildContextFromData(
        insights: insights,
        goals: [],
        now: now,
      );

      expect(context.length, lessThanOrEqualTo(1500));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  ASYNC — SharedPreferences integration
  // ════════════════════════════════════════════════════════════

  group('MemoryContextBuilder — async integration', () {
    test('async buildContext reads insights from SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();

      await CoachMemoryService.saveInsight(
        makeInsight(id: 'async1', topic: 'retraite', summary: 'Retraite en 2042'),
        prefs: prefs,
      );

      final context = await MemoryContextBuilder.buildContext(
        prefs: prefs,
        now: now,
      );

      expect(context, contains('retraite'));
      expect(context, contains('Retraite en 2042'));
    });

    test('async buildContext reads goals from SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();

      await GoalTrackerService.addGoal(
        makeGoal(id: 'async_g1', description: 'Maximiser mon 3a async'),
        prefs: prefs,
      );

      final context = await MemoryContextBuilder.buildContext(
        prefs: prefs,
        now: now,
      );

      expect(context, contains('Maximiser mon 3a async'));
      expect(context, contains('OBJECTIFS ACTIFS'));
    });
  });
}
