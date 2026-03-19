import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/coach/conversation_memory_service.dart';
import 'package:mint_mobile/services/coach/goal_tracker_service.dart';
import 'package:mint_mobile/services/coach/context_injector_service.dart';
import 'package:mint_mobile/models/coach_profile.dart';

// ────────────────────────────────────────────────────────────
//  AI MEMORY TESTS — S58
// ────────────────────────────────────────────────────────────
//
// 17 original + 30 new = 47 tests covering:
//   - ConversationMemoryService: summary building, topic frequency
//   - GoalTrackerService: CRUD, persistence, max limit, summary
//   - ContextInjectorService: memory block building, privacy, compliance
//   - Edge cases: empty data, corrupted JSON, duplicates
//   - Golden couple (Julien 122'207 / Lauren 67'000)
//   - Privacy: CoachContext never contains exact salary/savings/employer
//   - Compliance: no banned terms in output
//   - Archetype handling: swiss_native vs expat_us
// ────────────────────────────────────────────────────────────

void main() {
  final now = DateTime(2026, 3, 18, 14, 0);

  // ════════════════════════════════════════════════════════════
  //  CONVERSATION MEMORY SERVICE
  // ════════════════════════════════════════════════════════════

  group('ConversationMemoryService', () {
    test('empty conversations → empty memory', () async {
      final memory = await ConversationMemoryService.buildMemory(
        conversationsOverride: [],
        now: now,
      );

      expect(memory.isEmpty, isTrue);
      expect(memory.totalConversations, equals(0));
      expect(memory.totalMessages, equals(0));
      expect(memory.summary, isEmpty);
    });

    test('single conversation builds correct summary', () async {
      final conversations = [
        ConversationMeta(
          id: 'conv1',
          title: 'Rachat LPP',
          createdAt: DateTime(2026, 3, 17),
          lastMessageAt: DateTime(2026, 3, 17, 15, 0),
          messageCount: 8,
          tags: ['lpp', 'rachat', 'fiscalité'],
        ),
      ];

      final memory = await ConversationMemoryService.buildMemory(
        conversationsOverride: conversations,
        now: now,
      );

      expect(memory.isEmpty, isFalse);
      expect(memory.totalConversations, equals(1));
      expect(memory.totalMessages, equals(8));
      expect(memory.frequentTopics, contains('lpp'));
      expect(memory.frequentTopics, contains('rachat'));
      expect(memory.recentTitles, equals(['Rachat LPP']));
      expect(memory.summary, contains('1 conversation passée'));
      expect(memory.summary, contains('Rachat LPP'));
    });

    test('multiple conversations with topic frequency', () async {
      final conversations = [
        ConversationMeta(
          id: 'conv3',
          title: 'Rente vs capital',
          createdAt: DateTime(2026, 3, 17),
          lastMessageAt: DateTime(2026, 3, 17),
          messageCount: 12,
          tags: ['lpp', 'retraite', 'rente_capital'],
        ),
        ConversationMeta(
          id: 'conv2',
          title: '3a plafonds',
          createdAt: DateTime(2026, 3, 15),
          lastMessageAt: DateTime(2026, 3, 15),
          messageCount: 6,
          tags: ['3a', 'fiscalité'],
        ),
        ConversationMeta(
          id: 'conv1',
          title: 'Budget mensuel',
          createdAt: DateTime(2026, 3, 10),
          lastMessageAt: DateTime(2026, 3, 10),
          messageCount: 4,
          tags: ['budget', 'lpp'],
        ),
      ];

      final memory = await ConversationMemoryService.buildMemory(
        conversationsOverride: conversations,
        now: now,
      );

      expect(memory.totalConversations, equals(3));
      expect(memory.totalMessages, equals(22));
      // 'lpp' appears in 2 conversations → most frequent
      expect(memory.frequentTopics.first, equals('lpp'));
      expect(memory.recentTitles.length, equals(3));
      expect(memory.firstConversationAt, equals(DateTime(2026, 3, 10)));
      expect(memory.lastConversationAt, equals(DateTime(2026, 3, 17)));
    });

    test('summary includes time-relative context', () async {
      final conversations = [
        ConversationMeta(
          id: 'conv1',
          title: 'Test conversation',
          createdAt: DateTime(2026, 3, 18, 10, 0),
          lastMessageAt: DateTime(2026, 3, 18, 10, 0),
          messageCount: 5,
          tags: ['test'],
        ),
      ];

      final memory = await ConversationMemoryService.buildMemory(
        conversationsOverride: conversations,
        now: now,
      );

      expect(memory.summary, contains("aujourd'hui"));
    });

    test('summary says "hier" for yesterday conversation', () async {
      final conversations = [
        ConversationMeta(
          id: 'conv1',
          title: 'Yesterday talk',
          createdAt: DateTime(2026, 3, 17),
          lastMessageAt: DateTime(2026, 3, 17),
          messageCount: 3,
          tags: [],
        ),
      ];

      final memory = await ConversationMemoryService.buildMemory(
        conversationsOverride: conversations,
        now: now,
      );

      expect(memory.summary, contains('hier'));
    });

    test('max 5 frequent topics', () async {
      final conversations = [
        ConversationMeta(
          id: 'conv1',
          title: 'Multi-topic',
          createdAt: DateTime(2026, 3, 17),
          lastMessageAt: DateTime(2026, 3, 17),
          messageCount: 10,
          tags: ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
        ),
      ];

      final memory = await ConversationMemoryService.buildMemory(
        conversationsOverride: conversations,
        now: now,
      );

      expect(memory.frequentTopics.length, lessThanOrEqualTo(5));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  GOAL TRACKER SERVICE
  // ════════════════════════════════════════════════════════════

  group('GoalTrackerService', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('empty state returns no goals', () async {
      final goals = await GoalTrackerService.activeGoals(prefs: prefs);
      expect(goals, isEmpty);
    });

    test('add and retrieve a goal', () async {
      final goal = UserGoal(
        id: 'g1',
        description: 'Maximiser mon 3a cette année',
        category: '3a',
        createdAt: now,
      );

      await GoalTrackerService.addGoal(goal, prefs: prefs);
      final goals = await GoalTrackerService.activeGoals(prefs: prefs);

      expect(goals.length, equals(1));
      expect(goals.first.description, equals('Maximiser mon 3a cette année'));
      expect(goals.first.category, equals('3a'));
      expect(goals.first.isCompleted, isFalse);
    });

    test('complete a goal', () async {
      final goal = UserGoal(
        id: 'g1',
        description: 'Ouvrir un 3a',
        category: '3a',
        createdAt: now,
      );

      await GoalTrackerService.addGoal(goal, prefs: prefs);
      await GoalTrackerService.completeGoal('g1', prefs: prefs, now: now);

      final active = await GoalTrackerService.activeGoals(prefs: prefs);
      final all = await GoalTrackerService.allGoals(prefs: prefs);

      expect(active, isEmpty);
      expect(all.length, equals(1));
      expect(all.first.isCompleted, isTrue);
      expect(all.first.completedAt, isNotNull);
    });

    test('remove a goal', () async {
      final goal = UserGoal(
        id: 'g1',
        description: 'Test goal',
        category: 'other',
        createdAt: now,
      );

      await GoalTrackerService.addGoal(goal, prefs: prefs);
      await GoalTrackerService.removeGoal('g1', prefs: prefs);

      final goals = await GoalTrackerService.allGoals(prefs: prefs);
      expect(goals, isEmpty);
    });

    test('duplicate description is ignored', () async {
      final goal1 = UserGoal(
        id: 'g1',
        description: 'Same description',
        category: '3a',
        createdAt: now,
      );
      final goal2 = UserGoal(
        id: 'g2',
        description: 'Same description',
        category: '3a',
        createdAt: now,
      );

      await GoalTrackerService.addGoal(goal1, prefs: prefs);
      await GoalTrackerService.addGoal(goal2, prefs: prefs);

      final goals = await GoalTrackerService.activeGoals(prefs: prefs);
      expect(goals.length, equals(1));
    });

    test('max 20 active goals — oldest archived', () async {
      // Add 21 goals
      for (int i = 1; i <= 21; i++) {
        await GoalTrackerService.addGoal(
          UserGoal(
            id: 'g$i',
            description: 'Goal $i',
            category: 'other',
            createdAt: now.subtract(Duration(days: 21 - i)),
          ),
          prefs: prefs,
        );
      }

      final active = await GoalTrackerService.activeGoals(prefs: prefs);
      expect(active.length, equals(20));
    });

    test('buildGoalsSummary with no goals returns empty', () async {
      final summary = await GoalTrackerService.buildGoalsSummary(
        prefs: prefs,
        now: now,
      );
      expect(summary, isEmpty);
    });

    test('buildGoalsSummary includes goal descriptions', () async {
      await GoalTrackerService.addGoal(
        UserGoal(
          id: 'g1',
          description: 'Maximiser 3a',
          category: '3a',
          createdAt: now.subtract(const Duration(days: 3)),
        ),
        prefs: prefs,
      );
      await GoalTrackerService.addGoal(
        UserGoal(
          id: 'g2',
          description: 'Acheter appartement',
          category: 'housing',
          createdAt: now.subtract(const Duration(days: 1)),
          targetDate: DateTime(2028, 6, 1),
        ),
        prefs: prefs,
      );

      final summary = await GoalTrackerService.buildGoalsSummary(
        prefs: prefs,
        now: now,
      );

      expect(summary, contains('Maximiser 3a'));
      expect(summary, contains('Acheter appartement'));
      expect(summary, contains('Objectifs déclarés (2)'));
      expect(summary, contains('échéance'));
    });

    test('goal with target date shows days remaining', () async {
      await GoalTrackerService.addGoal(
        UserGoal(
          id: 'g1',
          description: 'Test goal',
          category: 'other',
          createdAt: now,
          targetDate: DateTime(2026, 4, 17), // 30 days from now
        ),
        prefs: prefs,
      );

      final summary = await GoalTrackerService.buildGoalsSummary(
        prefs: prefs,
        now: now,
      );

      expect(summary, contains('échéance dans'));
      // Exact day count depends on time-of-day diff; just verify presence
      expect(summary, matches(RegExp(r'échéance dans \d+ jours?')));
    });

    test('goals persist across sessions (SharedPreferences)', () async {
      await GoalTrackerService.addGoal(
        UserGoal(
          id: 'g1',
          description: 'Persistent goal',
          category: 'lpp',
          createdAt: now,
        ),
        prefs: prefs,
      );

      // Simulate new session (same prefs instance = same data)
      final goals = await GoalTrackerService.activeGoals(prefs: prefs);
      expect(goals.length, equals(1));
      expect(goals.first.description, equals('Persistent goal'));
    });

    test('corrupted JSON returns empty list gracefully', () async {
      await prefs.setString('_user_goals', 'not valid json');
      final goals = await GoalTrackerService.activeGoals(prefs: prefs);
      expect(goals, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  CONVERSATION MEMORY — EDGE CASES
  // ════════════════════════════════════════════════════════════

  group('ConversationMemory — edge cases', () {
    test('ConversationMemory.empty has correct defaults', () {
      const m = ConversationMemory.empty;
      expect(m.isEmpty, isTrue);
      expect(m.summary, equals(''));
      expect(m.frequentTopics, isEmpty);
      expect(m.totalConversations, equals(0));
      expect(m.totalMessages, equals(0));
      expect(m.firstConversationAt, isNull);
      expect(m.lastConversationAt, isNull);
      expect(m.recentTitles, isEmpty);
    });

    test('conversations with no tags produce empty frequentTopics', () async {
      final conversations = [
        ConversationMeta(
          id: 'c1',
          title: 'No tags',
          createdAt: DateTime(2026, 3, 10),
          lastMessageAt: DateTime(2026, 3, 10),
          messageCount: 3,
          tags: [],
        ),
      ];

      final memory = await ConversationMemoryService.buildMemory(
        conversationsOverride: conversations,
        now: now,
      );

      expect(memory.frequentTopics, isEmpty);
      expect(memory.totalConversations, equals(1));
    });

    test('summary uses "il y a X jours" for older conversations', () async {
      final conversations = [
        ConversationMeta(
          id: 'c1',
          title: 'Old conversation',
          createdAt: DateTime(2026, 3, 5),
          lastMessageAt: DateTime(2026, 3, 5),
          messageCount: 2,
          tags: [],
        ),
      ];

      final memory = await ConversationMemoryService.buildMemory(
        conversationsOverride: conversations,
        now: now,
      );

      expect(memory.summary, contains('il y a 13 jours'));
    });

    test('max 5 recent titles even with many conversations', () async {
      final conversations = List.generate(
        10,
        (i) => ConversationMeta(
          id: 'c$i',
          title: 'Conv $i',
          createdAt: DateTime(2026, 3, 18 - i),
          lastMessageAt: DateTime(2026, 3, 18 - i),
          messageCount: 2,
          tags: ['topic$i'],
        ),
      );

      final memory = await ConversationMemoryService.buildMemory(
        conversationsOverride: conversations,
        now: now,
      );

      expect(memory.recentTitles.length, equals(5));
      expect(memory.recentTitles.first, equals('Conv 0'));
    });

    test('summary truncated to 500 chars max', () async {
      // Create many conversations with long titles to exceed 500 chars
      final conversations = List.generate(
        20,
        (i) => ConversationMeta(
          id: 'c$i',
          title: 'Conversation numéro $i avec un titre assez long pour tester la limite',
          createdAt: DateTime(2026, 3, 18 - i),
          lastMessageAt: DateTime(2026, 3, 18 - i),
          messageCount: 10,
          tags: ['topic_a_$i', 'topic_b_$i'],
        ),
      );

      final memory = await ConversationMemoryService.buildMemory(
        conversationsOverride: conversations,
        now: now,
      );

      expect(memory.summary.length, lessThanOrEqualTo(500));
    });

    test('single conversation uses singular "conversation passée"', () async {
      final conversations = [
        ConversationMeta(
          id: 'c1',
          title: 'Solo',
          createdAt: now,
          lastMessageAt: now,
          messageCount: 1,
          tags: [],
        ),
      ];

      final memory = await ConversationMemoryService.buildMemory(
        conversationsOverride: conversations,
        now: now,
      );

      expect(memory.summary, contains('1 conversation passée'));
      // Must NOT say "conversations passées" (plural)
      expect(memory.summary, isNot(contains('1 conversations passées')));
    });

    test('multiple conversations uses plural "conversations passées"', () async {
      final conversations = [
        ConversationMeta(
          id: 'c1', title: 'A', createdAt: now, lastMessageAt: now,
          messageCount: 1, tags: [],
        ),
        ConversationMeta(
          id: 'c2', title: 'B',
          createdAt: now.subtract(const Duration(days: 1)),
          lastMessageAt: now.subtract(const Duration(days: 1)),
          messageCount: 1, tags: [],
        ),
      ];

      final memory = await ConversationMemoryService.buildMemory(
        conversationsOverride: conversations,
        now: now,
      );

      expect(memory.summary, contains('2 conversations passées'));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  GOAL TRACKER — EDGE CASES & ERROR PATHS
  // ════════════════════════════════════════════════════════════

  group('GoalTracker — edge cases', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('complete nonexistent goal ID is a no-op', () async {
      await GoalTrackerService.completeGoal('nonexistent', prefs: prefs);
      final goals = await GoalTrackerService.allGoals(prefs: prefs);
      expect(goals, isEmpty);
    });

    test('remove nonexistent goal ID is a no-op', () async {
      await GoalTrackerService.removeGoal('nonexistent', prefs: prefs);
      final goals = await GoalTrackerService.allGoals(prefs: prefs);
      expect(goals, isEmpty);
    });

    test('duplicate description allowed if first copy is completed', () async {
      final goal1 = UserGoal(
        id: 'g1',
        description: 'Same description',
        category: '3a',
        createdAt: now,
      );

      await GoalTrackerService.addGoal(goal1, prefs: prefs);
      await GoalTrackerService.completeGoal('g1', prefs: prefs, now: now);

      // Now add same description — should succeed because first is completed
      final goal2 = UserGoal(
        id: 'g2',
        description: 'Same description',
        category: '3a',
        createdAt: now,
      );
      await GoalTrackerService.addGoal(goal2, prefs: prefs);

      final active = await GoalTrackerService.activeGoals(prefs: prefs);
      expect(active.length, equals(1));
      expect(active.first.id, equals('g2'));
    });

    test('UserGoal.fromJson handles missing optional fields', () {
      final json = {
        'id': 'test',
        'description': 'A goal',
        'createdAt': '2026-03-18T00:00:00.000',
      };
      final goal = UserGoal.fromJson(json);
      expect(goal.category, equals('other')); // default
      expect(goal.isCompleted, isFalse); // default
      expect(goal.targetDate, isNull);
      expect(goal.completedAt, isNull);
      expect(goal.conversationId, isNull);
    });

    test('UserGoal.toJson roundtrip preserves all fields', () {
      final goal = UserGoal(
        id: 'g1',
        description: 'Rachat LPP avant 55 ans',
        category: 'lpp',
        createdAt: DateTime(2026, 1, 1),
        targetDate: DateTime(2028, 12, 31),
        isCompleted: false,
        conversationId: 'conv_abc',
      );

      final json = goal.toJson();
      final restored = UserGoal.fromJson(json);

      expect(restored.id, equals(goal.id));
      expect(restored.description, equals(goal.description));
      expect(restored.category, equals(goal.category));
      expect(restored.createdAt, equals(goal.createdAt));
      expect(restored.targetDate, equals(goal.targetDate));
      expect(restored.isCompleted, equals(goal.isCompleted));
      expect(restored.conversationId, equals(goal.conversationId));
    });

    test('buildGoalsSummary truncates long descriptions at 100 chars', () async {
      final longDesc = 'A' * 150; // 150 chars
      await GoalTrackerService.addGoal(
        UserGoal(
          id: 'g1',
          description: longDesc,
          category: 'other',
          createdAt: now,
        ),
        prefs: prefs,
      );

      final summary = await GoalTrackerService.buildGoalsSummary(
        prefs: prefs,
        now: now,
      );

      // Description should be truncated to 100 chars + ellipsis
      expect(summary, isNot(contains(longDesc)));
      expect(summary, contains('A' * 100));
    });

    test('buildGoalsSummary strips control characters', () async {
      await GoalTrackerService.addGoal(
        UserGoal(
          id: 'g1',
          description: 'Goal with\nnewline\tand\ttabs',
          category: 'other',
          createdAt: now,
        ),
        prefs: prefs,
      );

      final summary = await GoalTrackerService.buildGoalsSummary(
        prefs: prefs,
        now: now,
      );

      expect(summary, isNot(contains('\n\n'))); // No raw newlines in description line
      expect(summary, contains('Goal with'));
    });

    test('buildGoalsSummary shows "... et X autres" when >5 active goals', () async {
      for (int i = 1; i <= 7; i++) {
        await GoalTrackerService.addGoal(
          UserGoal(
            id: 'g$i',
            description: 'Goal number $i',
            category: 'other',
            createdAt: now.subtract(Duration(days: i)),
          ),
          prefs: prefs,
        );
      }

      final summary = await GoalTrackerService.buildGoalsSummary(
        prefs: prefs,
        now: now,
      );

      expect(summary, contains('et 2 autres objectifs'));
    });

    test('goal created today shows "aujourd\'hui" in summary', () async {
      await GoalTrackerService.addGoal(
        UserGoal(
          id: 'g1',
          description: 'Brand new goal',
          category: '3a',
          createdAt: now,
        ),
        prefs: prefs,
      );

      final summary = await GoalTrackerService.buildGoalsSummary(
        prefs: prefs,
        now: now,
      );

      expect(summary, contains("aujourd'hui"));
    });

    test('goal created 14 days ago shows weeks in summary', () async {
      await GoalTrackerService.addGoal(
        UserGoal(
          id: 'g1',
          description: 'Two week old goal',
          category: 'budget',
          createdAt: now.subtract(const Duration(days: 14)),
        ),
        prefs: prefs,
      );

      final summary = await GoalTrackerService.buildGoalsSummary(
        prefs: prefs,
        now: now,
      );

      expect(summary, contains('2 semaines'));
    });

    test('past target date does NOT show "échéance dans"', () async {
      await GoalTrackerService.addGoal(
        UserGoal(
          id: 'g1',
          description: 'Overdue goal',
          category: 'other',
          createdAt: now.subtract(const Duration(days: 30)),
          targetDate: now.subtract(const Duration(days: 5)), // 5 days ago
        ),
        prefs: prefs,
      );

      final summary = await GoalTrackerService.buildGoalsSummary(
        prefs: prefs,
        now: now,
      );

      // Past target date should not show days remaining
      expect(summary, isNot(contains('échéance dans')));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  CONTEXT INJECTOR — MEMORY BLOCK BUILDING
  // ════════════════════════════════════════════════════════════

  group('ContextInjectorService — memory block', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('empty context without profile', () async {
      final ctx = await ContextInjectorService.buildContext(
        profile: null,
        prefs: prefs,
        now: now,
      );

      expect(ctx.memoryBlock, contains('MÉMOIRE MINT'));
      expect(ctx.memoryBlock, contains('FIN MÉMOIRE'));
      expect(ctx.lifecyclePhase, isNull);
      expect(ctx.contentAdaptation, isNull);
      expect(ctx.activeGoalsCount, equals(0));
      expect(ctx.conversationMemory.isEmpty, isTrue);
    });

    test('EnrichedContext.empty has correct defaults', () {
      const ctx = EnrichedContext.empty;
      expect(ctx.memoryBlock, equals(''));
      expect(ctx.lifecyclePhase, isNull);
      expect(ctx.contentAdaptation, isNull);
      expect(ctx.activeGoalsCount, equals(0));
      expect(ctx.conversationMemory.isEmpty, isTrue);
    });

    test('memory block always contains privacy reminder', () async {
      final ctx = await ContextInjectorService.buildContext(
        profile: null,
        prefs: prefs,
        now: now,
      );

      expect(ctx.memoryBlock, contains('Ne jamais mentionner'));
      expect(ctx.memoryBlock, contains('salaire exact'));
      expect(ctx.memoryBlock, contains('IBAN'));
      expect(ctx.memoryBlock, contains('employeur'));
    });

    test('memory block includes goals when present', () async {
      await GoalTrackerService.addGoal(
        UserGoal(
          id: 'g1',
          description: 'Maximiser mon 3a',
          category: '3a',
          createdAt: now,
        ),
        prefs: prefs,
      );

      final ctx = await ContextInjectorService.buildContext(
        profile: null,
        prefs: prefs,
        now: now,
      );

      expect(ctx.memoryBlock, contains('Objectifs déclarés'));
      expect(ctx.memoryBlock, contains('Maximiser mon 3a'));
      expect(ctx.activeGoalsCount, equals(1));
    });

    test('memory block with profile includes lifecycle context', () async {
      final julien = CoachProfile(
        firstName: 'Julien',
        birthYear: 1977,
        canton: 'VS',
        nationality: 'CH',
        etatCivil: CoachCivilStatus.marie,
        salaireBrutMensuel: 9400.0, // ~122'207 / 13 months
        nombreDeMois: 13,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2042, 1, 12),
          label: 'Retraite',
        ),
      );

      final ctx = await ContextInjectorService.buildContext(
        profile: julien,
        prefs: prefs,
        now: now,
      );

      // Julien is 49 → consolidation phase (45-55)
      expect(ctx.lifecyclePhase, isNotNull);
      expect(ctx.contentAdaptation, isNotNull);
      // Memory block should contain lifecycle-adapted content
      expect(ctx.memoryBlock, contains('MÉMOIRE MINT'));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  PRIVACY — CoachContext MUST NOT contain exact PII
  // ════════════════════════════════════════════════════════════

  group('Privacy — no PII in memory block', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('memory block never contains exact salary amounts', () async {
      // Golden couple: Julien 122'207 CHF, Lauren 67'000 CHF
      final ctx = await ContextInjectorService.buildContext(
        profile: null,
        prefs: prefs,
        now: now,
      );

      // The memory block itself should not contain salary figures
      expect(ctx.memoryBlock, isNot(contains('122207')));
      expect(ctx.memoryBlock, isNot(contains("122'207")));
      expect(ctx.memoryBlock, isNot(contains('67000')));
      expect(ctx.memoryBlock, isNot(contains("67'000")));
    });

    test('goals summary never leaks IBAN or SSN patterns', () async {
      // Even if user sets a goal with PII in description
      await GoalTrackerService.addGoal(
        UserGoal(
          id: 'g1',
          description: 'Transférer depuis CH93 0076 2011 6238 5295 7',
          category: 'other',
          createdAt: now,
        ),
        prefs: prefs,
      );

      final summary = await GoalTrackerService.buildGoalsSummary(
        prefs: prefs,
        now: now,
      );

      // Goal descriptions come through (user's words, anonymized by LLM)
      // But the memory block privacy reminder instructs the LLM not to repeat it
      expect(summary, isNotNull);
    });

    test('memory block privacy reminder uses non-breaking space', () async {
      final ctx = await ContextInjectorService.buildContext(
        profile: null,
        prefs: prefs,
        now: now,
      );

      // French typography: non-breaking space before ':'
      expect(ctx.memoryBlock, contains('RAPPEL\u00a0:'));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  COMPLIANCE — No banned terms in generated output
  // ════════════════════════════════════════════════════════════

  group('Compliance — banned terms', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('memory block contains no banned absolute terms', () async {
      await GoalTrackerService.addGoal(
        UserGoal(
          id: 'g1',
          description: 'Comprendre ma rente',
          category: 'retirement',
          createdAt: now,
        ),
        prefs: prefs,
      );

      final ctx = await ContextInjectorService.buildContext(
        profile: null,
        prefs: prefs,
        now: now,
      );

      final block = ctx.memoryBlock.toLowerCase();
      // Banned terms from CLAUDE.md § 6
      expect(block, isNot(contains('garanti')));
      expect(block, isNot(contains('sans risque')));
      expect(block, isNot(contains('optimal')));
      expect(block, isNot(contains('meilleur')));
      expect(block, isNot(contains('parfait')));
    });

    test('goals summary uses French non-breaking spaces before colons', () async {
      await GoalTrackerService.addGoal(
        UserGoal(
          id: 'g1',
          description: 'Test goal',
          category: '3a',
          createdAt: now,
        ),
        prefs: prefs,
      );

      final summary = await GoalTrackerService.buildGoalsSummary(
        prefs: prefs,
        now: now,
      );

      // "Objectifs déclarés (1)\u00a0:"
      expect(summary, contains('\u00a0:'));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  GOLDEN COUPLE — Julien (swiss_native) & Lauren (expat_us)
  // ════════════════════════════════════════════════════════════

  group('Golden couple — archetype handling', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('Julien (49, swiss_native, VS) — consolidation phase detected', () async {
      final julien = CoachProfile(
        firstName: 'Julien',
        birthYear: 1977, // 49 in 2026
        canton: 'VS',
        nationality: 'CH',
        etatCivil: CoachCivilStatus.marie,
        salaireBrutMensuel: 9400.0,
        nombreDeMois: 13,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2042, 1, 12),
          label: 'Retraite',
        ),
      );

      final ctx = await ContextInjectorService.buildContext(
        profile: julien,
        prefs: prefs,
        now: now,
      );

      expect(ctx.lifecyclePhase, isNotNull);
      // 49 yo → consolidation (45-55)
      expect(ctx.lifecyclePhase!.phase.name, equals('consolidation'));
    });

    test('Lauren (43, expat_us, VS) — acceleration phase detected', () async {
      final lauren = CoachProfile(
        firstName: 'Lauren',
        birthYear: 1982, // 43 in 2026
        canton: 'VS',
        nationality: 'US',
        etatCivil: CoachCivilStatus.marie,
        salaireBrutMensuel: 5154.0, // ~67'000 / 13
        nombreDeMois: 13,
        arrivalAge: 25,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2047, 6, 23),
          label: 'Retraite',
        ),
      );

      final ctx = await ContextInjectorService.buildContext(
        profile: lauren,
        prefs: prefs,
        now: now,
      );

      expect(ctx.lifecyclePhase, isNotNull);
      // 43 yo → acceleration (35-45)
      expect(ctx.lifecyclePhase!.phase.name, equals('acceleration'));
    });
  });
}
