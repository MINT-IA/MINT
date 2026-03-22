import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/models/coach_insight.dart';
import 'package:mint_mobile/services/memory/coach_memory_service.dart';
import 'package:mint_mobile/services/coach/memory_reference_service.dart';

// ────────────────────────────────────────────────────────────
//  MemoryReferenceService TESTS
// ────────────────────────────────────────────────────────────
//
// 14 tests covering:
//   01. Returns null when no insights exist.
//   02. Returns null when insight is < 24 h old (same session).
//   03. Returns null when insight is > 180 days old (stale).
//   04. Returns reference for insight in the valid age window.
//   05. Selects most-recent eligible insight (not oldest).
//   06. Empty topic returns null.
//   07. Goal-type insight produces memoryRefGoal key (short summary).
//   08. Goal-type insight with long summary falls back to memoryRefTopic.
//   09. Non-goal insight always produces memoryRefTopic key.
//   10. Topic label mapped correctly (lpp → "2e pilier").
//   11. Unknown topic label passes through raw tag.
//   12. resolve() returns correct string for memoryRefTopic.
//   13. resolve() returns correct string for memoryRefGoal.
//   14. resolve() returns empty string for unknown referenceKey.
// ────────────────────────────────────────────────────────────

void main() {
  final now = DateTime(2026, 3, 22, 10, 0);

  // Helper: create a CoachInsight at a specific age offset.
  CoachInsight makeInsight({
    required String id,
    String topic = 'lpp',
    InsightType type = InsightType.fact,
    String summary = 'Test insight summary',
    required Duration age,
  }) {
    return CoachInsight(
      id: id,
      createdAt: now.subtract(age),
      topic: topic,
      summary: summary,
      type: type,
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ════════════════════════════════════════════════════════════
  //  01. No insights → null
  // ════════════════════════════════════════════════════════════

  test('01 returns null when no insights exist', () async {
    final prefs = await SharedPreferences.getInstance();
    final ref = await MemoryReferenceService.findRelevant(
      currentTopic: 'lpp',
      prefs: prefs,
      now: now,
    );
    expect(ref, isNull);
  });

  // ════════════════════════════════════════════════════════════
  //  02. Insight < 24 h old → null (same session)
  // ════════════════════════════════════════════════════════════

  test('02 returns null when insight is less than 24 hours old', () async {
    final prefs = await SharedPreferences.getInstance();
    final insight = makeInsight(
      id: 'i1',
      topic: 'lpp',
      age: const Duration(hours: 12),
    );
    await CoachMemoryService.saveInsight(insight, prefs: prefs);

    final ref = await MemoryReferenceService.findRelevant(
      currentTopic: 'lpp',
      prefs: prefs,
      now: now,
    );
    expect(ref, isNull);
  });

  // ════════════════════════════════════════════════════════════
  //  03. Insight > 180 days old → null (stale)
  // ════════════════════════════════════════════════════════════

  test('03 returns null when insight is older than 180 days', () async {
    final prefs = await SharedPreferences.getInstance();
    final insight = makeInsight(
      id: 'i1',
      topic: 'lpp',
      age: const Duration(days: 200),
    );
    await CoachMemoryService.saveInsight(insight, prefs: prefs);

    final ref = await MemoryReferenceService.findRelevant(
      currentTopic: 'lpp',
      prefs: prefs,
      now: now,
    );
    expect(ref, isNull);
  });

  // ════════════════════════════════════════════════════════════
  //  04. Valid age window → returns reference
  // ════════════════════════════════════════════════════════════

  test('04 returns reference for insight in valid age window (3 days)', () async {
    final prefs = await SharedPreferences.getInstance();
    final insight = makeInsight(
      id: 'i1',
      topic: 'lpp',
      age: const Duration(days: 3),
    );
    await CoachMemoryService.saveInsight(insight, prefs: prefs);

    final ref = await MemoryReferenceService.findRelevant(
      currentTopic: 'lpp',
      prefs: prefs,
      now: now,
    );
    expect(ref, isNotNull);
    expect(ref!.insightId, equals('i1'));
  });

  // ════════════════════════════════════════════════════════════
  //  05. Multiple insights → most recent eligible
  // ════════════════════════════════════════════════════════════

  test('05 selects most-recent eligible insight when multiple exist', () async {
    final prefs = await SharedPreferences.getInstance();

    // Save in order: oldest first (saveInsight inserts at position 0)
    final old = makeInsight(id: 'old', topic: 'lpp', age: const Duration(days: 30));
    final recent = makeInsight(id: 'recent', topic: 'lpp', age: const Duration(days: 2));
    final tooNew = makeInsight(id: 'tooNew', topic: 'lpp', age: const Duration(hours: 5));

    await CoachMemoryService.saveInsight(old, prefs: prefs);
    await CoachMemoryService.saveInsight(recent, prefs: prefs);
    await CoachMemoryService.saveInsight(tooNew, prefs: prefs);

    final ref = await MemoryReferenceService.findRelevant(
      currentTopic: 'lpp',
      prefs: prefs,
      now: now,
    );
    expect(ref, isNotNull);
    // 'recent' is most-recent eligible (tooNew is < 24h, old is further away)
    expect(ref!.insightId, equals('recent'));
  });

  // ════════════════════════════════════════════════════════════
  //  06. Empty topic → null
  // ════════════════════════════════════════════════════════════

  test('06 returns null for empty currentTopic', () async {
    final prefs = await SharedPreferences.getInstance();
    final insight = makeInsight(id: 'i1', topic: 'lpp', age: const Duration(days: 5));
    await CoachMemoryService.saveInsight(insight, prefs: prefs);

    final ref = await MemoryReferenceService.findRelevant(
      currentTopic: '   ', // blank
      prefs: prefs,
      now: now,
    );
    expect(ref, isNull);
  });

  // ════════════════════════════════════════════════════════════
  //  07. Goal insight with short summary → memoryRefGoal key
  // ════════════════════════════════════════════════════════════

  test('07 goal insight with short summary uses memoryRefGoal key', () async {
    final prefs = await SharedPreferences.getInstance();
    final insight = makeInsight(
      id: 'g1',
      topic: 'retraite',
      type: InsightType.goal,
      summary: 'maximiser mon 3a avant la retraite',
      age: const Duration(days: 7),
    );
    await CoachMemoryService.saveInsight(insight, prefs: prefs);

    final ref = await MemoryReferenceService.findRelevant(
      currentTopic: 'retraite',
      prefs: prefs,
      now: now,
    );
    expect(ref, isNotNull);
    expect(ref!.referenceKey, equals('memoryRefGoal'));
    expect(ref.params['goal'], equals('maximiser mon 3a avant la retraite'));
  });

  // ════════════════════════════════════════════════════════════
  //  08. Goal insight with long summary → falls back to memoryRefTopic
  // ════════════════════════════════════════════════════════════

  test('08 goal insight with summary > 80 chars uses memoryRefTopic', () async {
    final prefs = await SharedPreferences.getInstance();
    final longSummary = 'A' * 81;
    final insight = makeInsight(
      id: 'g2',
      topic: 'retraite',
      type: InsightType.goal,
      summary: longSummary,
      age: const Duration(days: 7),
    );
    await CoachMemoryService.saveInsight(insight, prefs: prefs);

    final ref = await MemoryReferenceService.findRelevant(
      currentTopic: 'retraite',
      prefs: prefs,
      now: now,
    );
    expect(ref, isNotNull);
    expect(ref!.referenceKey, equals('memoryRefTopic'));
  });

  // ════════════════════════════════════════════════════════════
  //  09. Non-goal insight → always memoryRefTopic
  // ════════════════════════════════════════════════════════════

  test('09 fact-type insight always produces memoryRefTopic key', () async {
    final prefs = await SharedPreferences.getInstance();
    final insight = makeInsight(
      id: 'f1',
      topic: 'lpp',
      type: InsightType.fact,
      summary: 'avoir LPP de ~70k CHF',
      age: const Duration(days: 5),
    );
    await CoachMemoryService.saveInsight(insight, prefs: prefs);

    final ref = await MemoryReferenceService.findRelevant(
      currentTopic: 'lpp',
      prefs: prefs,
      now: now,
    );
    expect(ref, isNotNull);
    expect(ref!.referenceKey, equals('memoryRefTopic'));
  });

  // ════════════════════════════════════════════════════════════
  //  10. Topic label mapping
  // ════════════════════════════════════════════════════════════

  test('10 lpp topic maps to "2e pilier" label', () async {
    final prefs = await SharedPreferences.getInstance();
    final insight = makeInsight(
      id: 'l1',
      topic: 'lpp',
      age: const Duration(days: 5),
    );
    await CoachMemoryService.saveInsight(insight, prefs: prefs);

    final ref = await MemoryReferenceService.findRelevant(
      currentTopic: 'lpp',
      prefs: prefs,
      now: now,
    );
    expect(ref, isNotNull);
    expect(ref!.params['topic'], equals('2e pilier'));
  });

  // ════════════════════════════════════════════════════════════
  //  11. Unknown topic → raw tag passthrough
  // ════════════════════════════════════════════════════════════

  test('11 unknown topic tag passes through as-is', () async {
    final prefs = await SharedPreferences.getInstance();
    final insight = makeInsight(
      id: 'u1',
      topic: 'crypto',
      age: const Duration(days: 5),
    );
    await CoachMemoryService.saveInsight(insight, prefs: prefs);

    final ref = await MemoryReferenceService.findRelevant(
      currentTopic: 'crypto',
      prefs: prefs,
      now: now,
    );
    expect(ref, isNotNull);
    expect(ref!.params['topic'], equals('crypto'));
  });

  // ════════════════════════════════════════════════════════════
  //  12. resolve() — memoryRefTopic
  // ════════════════════════════════════════════════════════════

  test('12 resolve memoryRefTopic returns formatted string', () {
    const ref = MemoryReference(
      referenceKey: 'memoryRefTopic',
      params: {'days': 5, 'topic': '2e pilier'},
      insightId: 'x1',
    );
    final result = MemoryReferenceService.resolve(
      ref,
      onTopic: (days, topic) => 'Il y a $days jours, tu m\'avais parlé de $topic.',
      onGoal: (goal) => 'Objectif : $goal',
      onScreen: (screen) => 'Dernier écran : $screen',
    );
    expect(result, equals('Il y a 5 jours, tu m\'avais parlé de 2e pilier.'));
  });

  // ════════════════════════════════════════════════════════════
  //  13. resolve() — memoryRefGoal
  // ════════════════════════════════════════════════════════════

  test('13 resolve memoryRefGoal returns formatted string', () {
    const ref = MemoryReference(
      referenceKey: 'memoryRefGoal',
      params: {'goal': 'maximiser mon 3a'},
      insightId: 'x2',
    );
    final result = MemoryReferenceService.resolve(
      ref,
      onTopic: (days, topic) => 'Il y a $days jours, tu m\'avais parlé de $topic.',
      onGoal: (goal) => 'Objectif\u00a0: $goal. On fait le point\u00a0?',
      onScreen: (screen) => 'Dernier écran : $screen',
    );
    expect(result, contains('maximiser mon 3a'));
    expect(result, contains('On fait le point'));
  });

  // ════════════════════════════════════════════════════════════
  //  14. resolve() — unknown key → empty string
  // ════════════════════════════════════════════════════════════

  test('14 resolve unknown referenceKey returns empty string', () {
    const ref = MemoryReference(
      referenceKey: 'unknownKey',
      params: {},
      insightId: 'x3',
    );
    final result = MemoryReferenceService.resolve(
      ref,
      onTopic: (days, topic) => 'topic',
      onGoal: (goal) => 'goal',
      onScreen: (screen) => 'screen',
    );
    expect(result, isEmpty);
  });
}
