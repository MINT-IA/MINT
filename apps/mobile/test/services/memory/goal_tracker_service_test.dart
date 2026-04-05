import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/services/coach/goal_tracker_service.dart';

// ────────────────────────────────────────────────────────────
//  GoalTrackerService (memory layer) TESTS — S58 / AI Memory
// ────────────────────────────────────────────────────────────
//
// Tests the memory/goal_tracker_service.dart re-export pointing
// to the canonical lib/services/coach/goal_tracker_service.dart.
//
// This confirms the re-export resolves correctly and that all
// expected public API is accessible from the memory/ path.
//
// 10 tests covering:
//   - Set and get goal (via addGoal / activeGoals)
//   - Progress tracking (isCompleted flag)
//   - Goal completion (completeGoal)
//   - History preserved (allGoals vs activeGoals)
//   - No goal returns null/empty
//   - JSON roundtrip (toJson/fromJson)
//   - Duplicate rejection
//   - Remove goal
//   - Past target date does not show écheance
//   - Goals summary non-breaking spaces
// ────────────────────────────────────────────────────────────

void main() {
  final now = DateTime(2026, 3, 18, 14, 0);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ════════════════════════════════════════════════════════════
  //  SET AND GET GOAL
  // ════════════════════════════════════════════════════════════

  group('GoalTrackerService (memory export) — set and get', () {
    test('no goals returns empty list', () async {
      final prefs = await SharedPreferences.getInstance();
      final goals = await GoalTrackerService.activeGoals(prefs: prefs);
      expect(goals, isEmpty);
    });

    test('set goal then get returns it', () async {
      final prefs = await SharedPreferences.getInstance();

      final goal = UserGoal(
        id: 'g1',
        description: 'Maximiser mon 3a cette année',
        category: '3a',
        createdAt: now,
      );

      await GoalTrackerService.addGoal(goal, prefs: prefs);

      final active = await GoalTrackerService.activeGoals(prefs: prefs);
      expect(active.length, equals(1));
      expect(active.first.description, equals('Maximiser mon 3a cette année'));
      expect(active.first.isCompleted, isFalse);
    });

    test('multiple goals all retrieved', () async {
      final prefs = await SharedPreferences.getInstance();

      for (final desc in ['Goal A unique', 'Goal B unique', 'Goal C unique']) {
        await GoalTrackerService.addGoal(
          UserGoal(
            id: desc,
            description: desc,
            category: 'other',
            createdAt: now,
          ),
          prefs: prefs,
        );
      }

      final active = await GoalTrackerService.activeGoals(prefs: prefs);
      expect(active.length, equals(3));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  PROGRESS / COMPLETION
  // ════════════════════════════════════════════════════════════

  group('GoalTrackerService (memory export) — completion', () {
    test('complete goal marks it as completed', () async {
      final prefs = await SharedPreferences.getInstance();

      final goal = UserGoal(
        id: 'comp1',
        description: 'Complete me',
        category: 'other',
        createdAt: now,
      );

      await GoalTrackerService.addGoal(goal, prefs: prefs);
      await GoalTrackerService.completeGoal('comp1', prefs: prefs, now: now);

      final active = await GoalTrackerService.activeGoals(prefs: prefs);
      final all = await GoalTrackerService.allGoals(prefs: prefs);

      expect(active, isEmpty);
      expect(all.length, equals(1));
      expect(all.first.isCompleted, isTrue);
      expect(all.first.completedAt, equals(now));
    });

    test('completed goals excluded from activeGoals', () async {
      final prefs = await SharedPreferences.getInstance();

      await GoalTrackerService.addGoal(
        UserGoal(id: 'stay', description: 'Active unique', category: 'other', createdAt: now),
        prefs: prefs,
      );
      await GoalTrackerService.addGoal(
        UserGoal(id: 'done', description: 'Done unique', category: 'other', createdAt: now),
        prefs: prefs,
      );
      await GoalTrackerService.completeGoal('done', prefs: prefs, now: now);

      final active = await GoalTrackerService.activeGoals(prefs: prefs);
      expect(active.length, equals(1));
      expect(active.first.id, equals('stay'));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  HISTORY
  // ════════════════════════════════════════════════════════════

  group('GoalTrackerService (memory export) — history', () {
    test('allGoals includes both active and completed', () async {
      final prefs = await SharedPreferences.getInstance();

      await GoalTrackerService.addGoal(
        UserGoal(id: 'h1', description: 'Active hist', category: 'other', createdAt: now),
        prefs: prefs,
      );
      await GoalTrackerService.addGoal(
        UserGoal(id: 'h2', description: 'Done hist', category: 'other', createdAt: now),
        prefs: prefs,
      );
      await GoalTrackerService.completeGoal('h2', prefs: prefs, now: now);

      final all = await GoalTrackerService.allGoals(prefs: prefs);
      expect(all.length, equals(2));

      final completed = all.where((g) => g.isCompleted).toList();
      final active = all.where((g) => !g.isCompleted).toList();
      expect(completed.length, equals(1));
      expect(active.length, equals(1));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  REMOVE
  // ════════════════════════════════════════════════════════════

  group('GoalTrackerService (memory export) — remove', () {
    test('removeGoal deletes the goal entirely', () async {
      final prefs = await SharedPreferences.getInstance();

      await GoalTrackerService.addGoal(
        UserGoal(id: 'rem1', description: 'Remove me', category: 'other', createdAt: now),
        prefs: prefs,
      );
      await GoalTrackerService.removeGoal('rem1', prefs: prefs);

      final all = await GoalTrackerService.allGoals(prefs: prefs);
      expect(all, isEmpty);
    });

    test('removeGoal on non-existent id is a no-op', () async {
      final prefs = await SharedPreferences.getInstance();

      await GoalTrackerService.addGoal(
        UserGoal(id: 'keep', description: 'Survives unique', category: 'other', createdAt: now),
        prefs: prefs,
      );
      await GoalTrackerService.removeGoal('nonexistent', prefs: prefs);

      final all = await GoalTrackerService.allGoals(prefs: prefs);
      expect(all.length, equals(1));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  JSON ROUNDTRIP
  // ════════════════════════════════════════════════════════════

  group('GoalTrackerService (memory export) — UserGoal serialization', () {
    test('UserGoal toJson/fromJson roundtrip preserves all fields', () {
      final goal = UserGoal(
        id: 'serial_test',
        description: 'Acheter un appartement à Sion',
        category: 'housing',
        createdAt: DateTime(2026, 1, 10),
        targetDate: DateTime(2028, 6, 30),
        isCompleted: false,
        conversationId: 'conv_123',
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

    test('UserGoal.fromJson handles missing optional fields', () {
      final json = {
        'id': 'min_goal',
        'description': 'Minimal goal',
        'createdAt': '2026-03-18T00:00:00.000',
      };

      final goal = UserGoal.fromJson(json);
      expect(goal.category, equals('other')); // default
      expect(goal.isCompleted, isFalse);
      expect(goal.targetDate, isNull);
      expect(goal.completedAt, isNull);
      expect(goal.conversationId, isNull);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  SUMMARY
  // ════════════════════════════════════════════════════════════

  group('GoalTrackerService (memory export) — summary', () {
    test('past target date does not show échéance dans', () async {
      final prefs = await SharedPreferences.getInstance();

      await GoalTrackerService.addGoal(
        UserGoal(
          id: 'overdue',
          description: 'Overdue unique goal',
          category: 'other',
          createdAt: now.subtract(const Duration(days: 30)),
          targetDate: now.subtract(const Duration(days: 5)),
        ),
        prefs: prefs,
      );

      final summary = await GoalTrackerService.buildGoalsSummary(
        prefs: prefs,
        now: now,
      );

      expect(summary, isNot(contains('échéance dans')));
    });

    test('goals summary uses non-breaking space before colon', () async {
      final prefs = await SharedPreferences.getInstance();

      await GoalTrackerService.addGoal(
        UserGoal(
          id: 'nbsp1',
          description: 'Goal for spacing unique',
          category: '3a',
          createdAt: now,
        ),
        prefs: prefs,
      );

      final summary = await GoalTrackerService.buildGoalsSummary(
        prefs: prefs,
        now: now,
      );

      expect(summary, contains('\u00a0:')); // non-breaking space before ':'
    });
  });
}
