import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/models/coach_insight.dart';
import 'package:mint_mobile/services/memory/coach_memory_service.dart';

// ────────────────────────────────────────────────────────────
//  CoachMemoryService TESTS — S58 / AI Memory
// ────────────────────────────────────────────────────────────
//
// 14 tests covering:
//   - Save and retrieve insight
//   - Multiple insights ordered most-recent-first
//   - Topic filtering (case-insensitive)
//   - Prune keeps only 50 most recent
//   - Clear removes all
//   - JSON serialization roundtrip (via shared_prefs persistence)
//   - Empty state returns empty list
//   - Deduplication by id (upsert)
//   - Corrupted JSON returns empty list
// ────────────────────────────────────────────────────────────

void main() {
  final now = DateTime(2026, 3, 18, 14, 0);

  CoachInsight makeInsight({
    required String id,
    String topic = 'lpp',
    InsightType type = InsightType.fact,
    String summary = 'Test insight',
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ════════════════════════════════════════════════════════════
  //  EMPTY STATE
  // ════════════════════════════════════════════════════════════

  group('CoachMemoryService — empty state', () {
    test('getInsights returns empty list when nothing saved', () async {
      final prefs = await SharedPreferences.getInstance();
      final insights = await CoachMemoryService.getInsights(prefs: prefs);
      expect(insights, isEmpty);
    });

    test('getInsightsForTopic returns empty list when nothing saved', () async {
      final prefs = await SharedPreferences.getInstance();
      final results = await CoachMemoryService.getInsightsForTopic(
        'lpp',
        prefs: prefs,
      );
      expect(results, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  SAVE & RETRIEVE
  // ════════════════════════════════════════════════════════════

  group('CoachMemoryService — save and retrieve', () {
    test('save then retrieve single insight', () async {
      final prefs = await SharedPreferences.getInstance();
      final insight = makeInsight(id: 'i1', topic: 'lpp');

      await CoachMemoryService.saveInsight(insight, prefs: prefs);
      final results = await CoachMemoryService.getInsights(prefs: prefs);

      expect(results.length, equals(1));
      expect(results.first.id, equals('i1'));
      expect(results.first.topic, equals('lpp'));
    });

    test('multiple insights returned most-recent-first', () async {
      final prefs = await SharedPreferences.getInstance();

      // Save oldest first
      await CoachMemoryService.saveInsight(
        makeInsight(id: 'oldest', createdAt: now.subtract(const Duration(days: 7))),
        prefs: prefs,
      );
      await CoachMemoryService.saveInsight(
        makeInsight(id: 'middle', createdAt: now.subtract(const Duration(days: 3))),
        prefs: prefs,
      );
      await CoachMemoryService.saveInsight(
        makeInsight(id: 'newest', createdAt: now),
        prefs: prefs,
      );

      final results = await CoachMemoryService.getInsights(prefs: prefs);

      expect(results.length, equals(3));
      // Most recent saved last → inserted at head each time
      expect(results[0].id, equals('newest'));
      expect(results[1].id, equals('middle'));
      expect(results[2].id, equals('oldest'));
    });

    test('save deduplicates by id (upsert)', () async {
      final prefs = await SharedPreferences.getInstance();

      final original = makeInsight(id: 'dup', topic: 'lpp');
      final updated = makeInsight(id: 'dup', topic: 'retraite');

      await CoachMemoryService.saveInsight(original, prefs: prefs);
      await CoachMemoryService.saveInsight(updated, prefs: prefs);

      final results = await CoachMemoryService.getInsights(prefs: prefs);

      expect(results.length, equals(1));
      expect(results.first.topic, equals('retraite')); // updated version
    });

    test('JSON roundtrip preserves all fields across save/retrieve', () async {
      final prefs = await SharedPreferences.getInstance();

      final original = CoachInsight(
        id: 'rt_test',
        createdAt: DateTime(2026, 1, 15, 9, 30),
        topic: '3a',
        summary: "Décidé de maximiser le 3a — plafond 7'258 CHF",
        type: InsightType.decision,
        metadata: {'amount': 7258},
      );

      await CoachMemoryService.saveInsight(original, prefs: prefs);
      final retrieved = await CoachMemoryService.getInsights(prefs: prefs);

      expect(retrieved.length, equals(1));
      final r = retrieved.first;
      expect(r.id, equals('rt_test'));
      expect(r.createdAt, equals(DateTime(2026, 1, 15, 9, 30)));
      expect(r.topic, equals('3a'));
      expect(r.type, equals(InsightType.decision));
      expect(r.metadata!['amount'], equals(7258));
    });

    test('corrupted SharedPreferences JSON returns empty list', () async {
      SharedPreferences.setMockInitialValues({
        '_coach_insights': 'CORRUPTED {{{{',
      });
      final prefs = await SharedPreferences.getInstance();

      final results = await CoachMemoryService.getInsights(prefs: prefs);
      expect(results, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  TOPIC FILTERING
  // ════════════════════════════════════════════════════════════

  group('CoachMemoryService — topic filtering', () {
    test('getInsightsForTopic returns matching insights only', () async {
      final prefs = await SharedPreferences.getInstance();

      await CoachMemoryService.saveInsight(
        makeInsight(id: 'lpp1', topic: 'lpp'),
        prefs: prefs,
      );
      await CoachMemoryService.saveInsight(
        makeInsight(id: 'ret1', topic: 'retraite'),
        prefs: prefs,
      );
      await CoachMemoryService.saveInsight(
        makeInsight(id: 'lpp2', topic: 'lpp'),
        prefs: prefs,
      );

      final lppInsights = await CoachMemoryService.getInsightsForTopic(
        'lpp',
        prefs: prefs,
      );

      expect(lppInsights.length, equals(2));
      expect(lppInsights.every((i) => i.topic.contains('lpp')), isTrue);
    });

    test('getInsightsForTopic is case-insensitive', () async {
      final prefs = await SharedPreferences.getInstance();

      await CoachMemoryService.saveInsight(
        makeInsight(id: 'case1', topic: 'LPP'),
        prefs: prefs,
      );

      final results = await CoachMemoryService.getInsightsForTopic(
        'lpp',
        prefs: prefs,
      );

      expect(results.length, equals(1));
    });

    test('getInsightsForTopic returns empty when no match', () async {
      final prefs = await SharedPreferences.getInstance();

      await CoachMemoryService.saveInsight(
        makeInsight(id: 'a', topic: 'lpp'),
        prefs: prefs,
      );

      final results = await CoachMemoryService.getInsightsForTopic(
        'housing',
        prefs: prefs,
      );

      expect(results, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  PRUNE
  // ════════════════════════════════════════════════════════════

  group('CoachMemoryService — prune', () {
    test('prune keeps only 50 most recent insights', () async {
      final prefs = await SharedPreferences.getInstance();

      // Save 55 insights
      for (var i = 0; i < 55; i++) {
        await CoachMemoryService.saveInsight(
          makeInsight(
            id: 'i$i',
            createdAt: now.subtract(Duration(days: 55 - i)),
          ),
          prefs: prefs,
        );
      }

      final results = await CoachMemoryService.getInsights(prefs: prefs);
      expect(results.length, equals(50));
    });

    test('prune keeps the most recent 50 (not oldest)', () async {
      final prefs = await SharedPreferences.getInstance();

      for (var i = 0; i < 55; i++) {
        await CoachMemoryService.saveInsight(
          makeInsight(
            id: 'p$i',
            summary: 'Insight $i',
            createdAt: now.subtract(Duration(days: 55 - i)),
          ),
          prefs: prefs,
        );
      }

      final results = await CoachMemoryService.getInsights(prefs: prefs);
      // Most recently saved (i54) should be present
      expect(results.any((i) => i.id == 'p54'), isTrue);
      // Oldest (i0) should have been pruned
      expect(results.any((i) => i.id == 'p0'), isFalse);
    });

    test('prune is a no-op when count <= 50', () async {
      final prefs = await SharedPreferences.getInstance();

      for (var i = 0; i < 10; i++) {
        await CoachMemoryService.saveInsight(
          makeInsight(id: 'pr$i'),
          prefs: prefs,
        );
      }

      await CoachMemoryService.prune(prefs: prefs);

      final results = await CoachMemoryService.getInsights(prefs: prefs);
      // Deduplication: all same topic/summary/type but distinct ids
      expect(results.length, equals(10));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  CLEAR
  // ════════════════════════════════════════════════════════════

  group('CoachMemoryService — clear', () {
    test('clear removes all insights', () async {
      final prefs = await SharedPreferences.getInstance();

      await CoachMemoryService.saveInsight(makeInsight(id: 'c1'), prefs: prefs);
      await CoachMemoryService.saveInsight(makeInsight(id: 'c2'), prefs: prefs);

      await CoachMemoryService.clear(prefs: prefs);

      final results = await CoachMemoryService.getInsights(prefs: prefs);
      expect(results, isEmpty);
    });

    test('clear on empty state is a no-op', () async {
      final prefs = await SharedPreferences.getInstance();
      await CoachMemoryService.clear(prefs: prefs);
      final results = await CoachMemoryService.getInsights(prefs: prefs);
      expect(results, isEmpty);
    });
  });
}
