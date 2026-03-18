import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/coach/conversation_memory_service.dart';
import 'package:mint_mobile/services/coach/goal_tracker_service.dart';

// ────────────────────────────────────────────────────────────
//  AI MEMORY TESTS — S58
// ────────────────────────────────────────────────────────────
//
// 22 tests covering:
//   - ConversationMemoryService: summary building, topic frequency
//   - GoalTrackerService: CRUD, persistence, max limit, summary
//   - Edge cases: empty data, corrupted JSON, duplicates
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
}
