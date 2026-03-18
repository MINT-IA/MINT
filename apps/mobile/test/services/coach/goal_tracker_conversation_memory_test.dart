import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/services/coach/goal_tracker_service.dart';
import 'package:mint_mobile/services/coach/conversation_memory_service.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';

// ────────────────────────────────────────────────────────────
//  EDGE CASE TESTS — GoalTracker + ConversationMemory
//  Task 3: boundary tests for summary truncation, goal
//  completion/re-add, and past target dates.
// ────────────────────────────────────────────────────────────

void main() {
  final now = DateTime(2026, 3, 18);

  // ════════════════════════════════════════════════════════════
  //  TASK 3b: Summary truncation — exceed 500 chars
  // ════════════════════════════════════════════════════════════

  group('ConversationMemoryService — Summary truncation', () {
    test('summary exceeding 500 chars is truncated to 500', () async {
      // Build many conversations with long titles and many tags
      // to force the summary text past 500 chars.
      final conversations = List.generate(20, (i) {
        return ConversationMeta(
          id: 'conv_$i',
          title: 'Conversation about a very important financial topic number $i that is quite long and detailed',
          createdAt: now.subtract(Duration(days: i * 2)),
          lastMessageAt: now.subtract(Duration(days: i)),
          messageCount: 15 + i,
          tags: [
            'retirement_planning',
            'lpp_buyback',
            'tax_optimization',
            '3a_maximization',
            'housing_purchase',
          ],
        );
      });

      final memory = await ConversationMemoryService.buildMemory(
        conversationsOverride: conversations,
        now: now,
      );

      // Summary must be <= 500 chars
      expect(memory.summary.length, lessThanOrEqualTo(500));
      // Should end with '...' if truncated
      if (memory.summary.length == 500) {
        expect(memory.summary.endsWith('...'), isTrue);
      }
    });

    test('short summary is NOT truncated', () async {
      final conversations = [
        ConversationMeta(
          id: 'conv_1',
          title: 'Mon 3a',
          createdAt: now.subtract(const Duration(days: 1)),
          lastMessageAt: now,
          messageCount: 3,
          tags: ['3a'],
        ),
      ];

      final memory = await ConversationMemoryService.buildMemory(
        conversationsOverride: conversations,
        now: now,
      );

      // Short summary should be well under 500 chars
      expect(memory.summary.length, lessThan(500));
      expect(memory.summary.endsWith('...'), isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  TASK 3e: Goal completed then re-added with same description
  // ════════════════════════════════════════════════════════════

  group('GoalTrackerService — Goal re-add after completion', () {
    test('completed goal + new goal with same description = both exist', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Add a goal
      final goal1 = UserGoal(
        id: 'g1',
        description: 'Maximiser mon 3a',
        category: '3a',
        createdAt: now.subtract(const Duration(days: 30)),
      );
      await GoalTrackerService.addGoal(goal1, prefs: prefs, now: now);

      // Complete it
      await GoalTrackerService.completeGoal('g1', prefs: prefs, now: now);

      // Re-add with same description (different ID)
      final goal2 = UserGoal(
        id: 'g2',
        description: 'Maximiser mon 3a',
        category: '3a',
        createdAt: now,
      );
      await GoalTrackerService.addGoal(goal2, prefs: prefs, now: now);

      // Both should exist
      final all = await GoalTrackerService.allGoals(prefs: prefs);
      expect(all.length, equals(2));

      // One completed, one active
      final completed = all.where((g) => g.isCompleted).toList();
      final active = all.where((g) => !g.isCompleted).toList();
      expect(completed.length, equals(1));
      expect(active.length, equals(1));
      expect(completed.first.id, equals('g1'));
      expect(active.first.id, equals('g2'));
    });

    test('duplicate active goal with same description is rejected', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final goal1 = UserGoal(
        id: 'g1',
        description: 'Acheter un appartement',
        category: 'housing',
        createdAt: now,
      );
      await GoalTrackerService.addGoal(goal1, prefs: prefs, now: now);

      // Try to add another active goal with same description
      final goal2 = UserGoal(
        id: 'g2',
        description: 'Acheter un appartement',
        category: 'housing',
        createdAt: now,
      );
      await GoalTrackerService.addGoal(goal2, prefs: prefs, now: now);

      // Should still be only 1
      final all = await GoalTrackerService.allGoals(prefs: prefs);
      expect(all.length, equals(1));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  TASK 3f: Past target date on goal → no "echeance" in summary
  // ════════════════════════════════════════════════════════════

  group('GoalTrackerService — Past target date', () {
    test('past target date → no echeance in goal summary', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final goal = UserGoal(
        id: 'g1',
        description: 'Rembourser pret auto',
        category: 'budget',
        createdAt: now.subtract(const Duration(days: 60)),
        targetDate: now.subtract(const Duration(days: 10)), // Past!
      );
      await GoalTrackerService.addGoal(goal, prefs: prefs, now: now);

      final summary = await GoalTrackerService.buildGoalsSummary(
        prefs: prefs,
        now: now,
      );

      // Should NOT contain "echeance" since target date is past
      expect(summary, isNot(contains('échéance')));
    });

    test('future target date → YES echeance in goal summary', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final goal = UserGoal(
        id: 'g1',
        description: 'Acheter un appartement',
        category: 'housing',
        createdAt: now,
        targetDate: now.add(const Duration(days: 365)), // Future
      );
      await GoalTrackerService.addGoal(goal, prefs: prefs, now: now);

      final summary = await GoalTrackerService.buildGoalsSummary(
        prefs: prefs,
        now: now,
      );

      // Should contain "echeance"
      expect(summary, contains('échéance'));
    });
  });
}
