import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/coach/goal_tracker_service.dart';
import 'package:mint_mobile/services/coach/proactive_trigger_service.dart';

// ────────────────────────────────────────────────────────────
//  PROACTIVE TRIGGER SERVICE TESTS — S62 / Phase 2
// ────────────────────────────────────────────────────────────
//
// 25 tests covering:
//   1. Fresh profile → no trigger (missing stored phase baseline)
//   2. Phase stored same → no trigger
//   3. Phase change → lifecyclePhaseChange fires
//   4. Monday + no recap → weeklyRecapAvailable fires
//   5. Monday + recap seen this week → no recap trigger
//   6. Tuesday → no weeklyRecap trigger
//   7. Goal 45d old → 50% milestone fires
//   8. Goal 90d old → 100% milestone fires
//   9. Goal 10d old → no milestone fires
//  10. Goal with target date at 50% → 50% milestone fires
//  11. Goal with target date at 100% → 100% milestone fires
//  12. Seasonal event starts today → seasonalReminder fires
//  13. Seasonal event NOT starting today → no seasonal trigger
//  14. Inactive 7 days → inactivityReturn fires
//  15. Inactive 6 days → no inactivity trigger
//  16. No activity stored + profile 10 days old → inactivity fires
//  17. Confidence improved 6 pts → confidenceImproved fires
//  18. Confidence improved 4 pts → no confidenceImproved trigger
//  19. No stored confidence → no confidenceImproved trigger
//  20. New cap id differs → newCapAvailable fires
//  21. Cap id same as shown → no newCapAvailable trigger
//  22. Cooldown prevents double trigger same day
//  23. Cooldown allows trigger next day
//  24. Priority order: lifecyclePhaseChange beats weeklyRecap
//  25. Golden couple Julien — consolidation phase, inactivity
// ────────────────────────────────────────────────────────────

// ── Test helpers ────────────────────────────────────────────

/// Build a minimal CoachProfile for testing.
CoachProfile _makeProfile({
  int birthYear = 1985,
  DateTime? createdAt,
  String employmentStatus = 'salarie',
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: 'VS',
    etatCivil: CoachCivilStatus.celibataire,
    nombreEnfants: 0,
    salaireBrutMensuel: 8000,
    nombreDeMois: 12,
    employmentStatus: employmentStatus,
    depenses: const DepensesProfile(),
    prevoyance: const PrevoyanceProfile(),
    patrimoine: const PatrimoineProfile(),
    dettes: const DetteProfile(),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2045, 1, 1),
      label: 'Retraite',
    ),
    goalsB: const [],
    plannedContributions: const [],
    checkIns: const [],
    createdAt: createdAt ?? DateTime(2025, 1, 1),
    updatedAt: DateTime(2026, 3, 1),
  );
}

/// Build Julien profile (golden couple — consolidation phase, 49 ans).
CoachProfile _julienProfile() {
  return CoachProfile(
    birthYear: 1977, // 49 ans in 2026 → consolidation
    canton: 'VS',
    etatCivil: CoachCivilStatus.marie,
    nombreEnfants: 0,
    salaireBrutMensuel: 10184, // 122'207 / 12
    nombreDeMois: 12,
    employmentStatus: 'salarie',
    nationality: 'CH',
    depenses: const DepensesProfile(),
    prevoyance: const PrevoyanceProfile(
      avoirLppTotal: 70377,
      rachatMaximum: 539414,
      anneesContribuees: 24,
    ),
    patrimoine: const PatrimoineProfile(epargneLiquide: 50000),
    dettes: const DetteProfile(),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2042, 1, 1),
      label: 'Retraite',
    ),
    goalsB: const [],
    plannedContributions: const [],
    checkIns: const [],
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2026, 3, 1),
  );
}

/// SharedPreferences with stored phase = construction.
Future<SharedPreferences> _prefsWithPhase(String phaseName) async {
  SharedPreferences.setMockInitialValues({
    '_proactive_stored_phase': phaseName,
  });
  return SharedPreferences.getInstance();
}

void main() {
  // ── Fixed test date: Monday 2026-03-23 ──────────────────────
  //   Monday → weeklyRecap can fire.
  //   Julien (born 1977) is 48 → consolidation phase.
  final monday = DateTime(2026, 3, 23);
  final tuesday = DateTime(2026, 3, 24);

  group('ProactiveTriggerService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    // ── Test 1: Fresh profile with recent activity → no phase change trigger

    test('1. No stored phase → lifecyclePhaseChange does NOT fire', () async {
      // No stored phase means no baseline to compare against.
      // Even with other conditions absent, lifecyclePhaseChange specifically
      // should not fire. Here we isolate by using a fresh profile with
      // recent activity (to suppress inactivity) and a non-Monday date.
      final recentCreatedAt = tuesday.subtract(const Duration(days: 1));
      SharedPreferences.setMockInitialValues({
        '_nudge_last_activity': tuesday.subtract(const Duration(days: 1)).toIso8601String(),
      });
      final prefs = await SharedPreferences.getInstance();
      final trigger = await ProactiveTriggerService.evaluate(
        profile: _makeProfile(createdAt: recentCreatedAt),
        prefs: prefs,
        now: tuesday,
      );
      // lifecyclePhaseChange must NOT fire without stored baseline.
      expect(trigger?.type == ProactiveTriggerType.lifecyclePhaseChange, isFalse,
          reason: 'No stored phase means no lifecycle baseline — phase change cannot be detected');
    });

    // ── Test 2: Phase stored same → no trigger ───────────────

    test('2. Same phase stored as current → no lifecyclePhaseChange', () async {
      // Profile born 1985 → at 2026 age 41 → acceleration.
      final prefs = await _prefsWithPhase('acceleration');
      final trigger = await ProactiveTriggerService.evaluate(
        profile: _makeProfile(birthYear: 1985),
        prefs: prefs,
        now: tuesday,
      );
      expect(trigger?.type == ProactiveTriggerType.lifecyclePhaseChange, isFalse,
          reason: 'Phase is unchanged — no phase change trigger');
    });

    // ── Test 3: Phase change → triggers ─────────────────────

    test('3. Phase changed from construction to consolidation → lifecyclePhaseChange fires', () async {
      // Profile born 1977 → age 49 → consolidation.
      // Stored phase = construction → change detected.
      final prefs = await _prefsWithPhase('construction');
      final trigger = await ProactiveTriggerService.evaluate(
        profile: _makeProfile(birthYear: 1977),
        prefs: prefs,
        now: tuesday,
      );
      expect(trigger, isNotNull);
      expect(trigger!.type, ProactiveTriggerType.lifecyclePhaseChange);
      expect(trigger.messageKey, 'proactiveLifecycleChange');
    });

    // ── Test 4: Monday + no recap → weeklyRecapAvailable ────

    test('4. Monday with no recap seen fires weeklyRecapAvailable', () async {
      // Phase matches so lifecyclePhaseChange doesn't fire first.
      final prefs = await _prefsWithPhase('acceleration');
      final trigger = await ProactiveTriggerService.evaluate(
        profile: _makeProfile(birthYear: 1985), // age 41 → acceleration
        prefs: prefs,
        now: monday,
      );
      expect(trigger, isNotNull);
      expect(trigger!.type, ProactiveTriggerType.weeklyRecapAvailable);
      expect(trigger.messageKey, 'proactiveWeeklyRecap');
    });

    // ── Test 5: Monday + recap seen this week → no trigger ──

    test('5. Monday with recap already seen this week → no weeklyRecap', () async {
      // Mark recap as seen this Monday.
      SharedPreferences.setMockInitialValues({
        '_proactive_stored_phase': 'acceleration',
        '_proactive_last_recap_seen': monday.toIso8601String(),
      });
      final prefs = await SharedPreferences.getInstance();
      final trigger = await ProactiveTriggerService.evaluate(
        profile: _makeProfile(birthYear: 1985),
        prefs: prefs,
        now: monday,
      );
      expect(trigger?.type == ProactiveTriggerType.weeklyRecapAvailable, isFalse,
          reason: 'Recap already seen this week');
    });

    // ── Test 6: Tuesday → no weeklyRecap trigger ────────────

    test('6. Tuesday → weeklyRecapAvailable does NOT fire', () async {
      final prefs = await _prefsWithPhase('acceleration');
      final trigger = await ProactiveTriggerService.evaluate(
        profile: _makeProfile(birthYear: 1985),
        prefs: prefs,
        now: tuesday,
      );
      expect(trigger?.type == ProactiveTriggerType.weeklyRecapAvailable, isFalse,
          reason: 'weeklyRecap only fires on Monday');
    });

    // ── Test 7: Goal 45 days old → 50% milestone ────────────

    test('7. Goal 45 days old → goalMilestone fires at 50%', () async {
      final goalCreatedAt = tuesday.subtract(const Duration(days: 45));
      SharedPreferences.setMockInitialValues({
        '_proactive_stored_phase': 'acceleration',
      });
      final prefs = await SharedPreferences.getInstance();

      // Add a goal 45 days old (no target date).
      await GoalTrackerService.addGoal(
        UserGoal(
          id: 'goal_test_50',
          description: 'Maximiser mon 3a',
          category: '3a',
          createdAt: goalCreatedAt,
        ),
        prefs: prefs,
        now: tuesday,
      );

      final trigger = await ProactiveTriggerService.evaluate(
        profile: _makeProfile(birthYear: 1985),
        prefs: prefs,
        now: tuesday,
      );
      expect(trigger, isNotNull);
      expect(trigger!.type, ProactiveTriggerType.goalMilestone);
      expect(trigger.params?['progress'], '50');
    });

    // ── Test 8: Goal 90 days old → 100% milestone ───────────

    test('8. Goal 90 days old → goalMilestone fires at 100%', () async {
      final goalCreatedAt = tuesday.subtract(const Duration(days: 90));
      SharedPreferences.setMockInitialValues({
        '_proactive_stored_phase': 'acceleration',
      });
      final prefs = await SharedPreferences.getInstance();

      await GoalTrackerService.addGoal(
        UserGoal(
          id: 'goal_test_100',
          description: 'Comprendre la rente vs capital',
          category: 'retraite',
          createdAt: goalCreatedAt,
        ),
        prefs: prefs,
        now: tuesday,
      );

      final trigger = await ProactiveTriggerService.evaluate(
        profile: _makeProfile(birthYear: 1985),
        prefs: prefs,
        now: tuesday,
      );
      expect(trigger, isNotNull);
      expect(trigger!.type, ProactiveTriggerType.goalMilestone);
      expect(trigger.params?['progress'], '100');
    });

    // ── Test 9: Goal 10 days old → no milestone ─────────────

    test('9. Goal 10 days old → no goalMilestone trigger', () async {
      final goalCreatedAt = tuesday.subtract(const Duration(days: 10));
      SharedPreferences.setMockInitialValues({
        '_proactive_stored_phase': 'acceleration',
      });
      final prefs = await SharedPreferences.getInstance();

      await GoalTrackerService.addGoal(
        UserGoal(
          id: 'goal_test_fresh',
          description: 'Premier objectif',
          category: 'other',
          createdAt: goalCreatedAt,
        ),
        prefs: prefs,
        now: tuesday,
      );

      final trigger = await ProactiveTriggerService.evaluate(
        profile: _makeProfile(birthYear: 1985),
        prefs: prefs,
        now: tuesday,
      );
      expect(trigger?.type == ProactiveTriggerType.goalMilestone, isFalse,
          reason: 'Goal too recent for milestone');
    });

    // ── Test 10: Goal with target date at 50% ───────────────

    test('10. Goal with target date at 50% elapsed → 50% milestone fires', () async {
      // Target date 200 days from creation, and 100 days elapsed.
      final createdAt = tuesday.subtract(const Duration(days: 100));
      final targetDate = tuesday.add(const Duration(days: 100));
      SharedPreferences.setMockInitialValues({
        '_proactive_stored_phase': 'acceleration',
      });
      final prefs = await SharedPreferences.getInstance();

      await GoalTrackerService.addGoal(
        UserGoal(
          id: 'goal_half',
          description: 'Racheter LPP',
          category: 'lpp',
          createdAt: createdAt,
          targetDate: targetDate,
        ),
        prefs: prefs,
        now: tuesday,
      );

      final trigger = await ProactiveTriggerService.evaluate(
        profile: _makeProfile(birthYear: 1985),
        prefs: prefs,
        now: tuesday,
      );
      expect(trigger, isNotNull);
      expect(trigger!.type, ProactiveTriggerType.goalMilestone);
      expect(trigger.params?['progress'], '50');
    });

    // ── Test 11: Goal with target date at 100% ───────────────

    test('11. Goal target date passed → 100% milestone fires', () async {
      // Goal created 100 days ago, target was yesterday.
      final createdAt = tuesday.subtract(const Duration(days: 100));
      final targetDate = tuesday.subtract(const Duration(days: 1));
      SharedPreferences.setMockInitialValues({
        '_proactive_stored_phase': 'acceleration',
      });
      final prefs = await SharedPreferences.getInstance();

      await GoalTrackerService.addGoal(
        UserGoal(
          id: 'goal_done',
          description: 'Acheter appartement',
          category: 'housing',
          createdAt: createdAt,
          targetDate: targetDate,
        ),
        prefs: prefs,
        now: tuesday,
      );

      final trigger = await ProactiveTriggerService.evaluate(
        profile: _makeProfile(birthYear: 1985),
        prefs: prefs,
        now: tuesday,
      );
      expect(trigger, isNotNull);
      expect(trigger!.type, ProactiveTriggerType.goalMilestone);
      expect(trigger.params?['progress'], '100');
    });

    // ── Test 12: Seasonal event starts today ────────────────
    // February 1 is the start of taxSeason.

    test('12. Seasonal event starts today → seasonalReminder fires', () async {
      final feb1 = DateTime(2026, 2, 1); // taxSeason starts Feb 1
      SharedPreferences.setMockInitialValues({
        '_proactive_stored_phase': 'acceleration',
      });
      final prefs = await SharedPreferences.getInstance();

      final trigger = await ProactiveTriggerService.evaluate(
        profile: _makeProfile(birthYear: 1985),
        prefs: prefs,
        now: feb1,
      );
      expect(trigger, isNotNull);
      expect(trigger!.type, ProactiveTriggerType.seasonalReminder);
      expect(trigger.messageKey, 'proactiveSeasonalReminder');
    });

    // ── Test 13: Seasonal event mid-window → no trigger ─────

    test('13. Mid-season (not start day) → no seasonalReminder', () async {
      final feb15 = DateTime(2026, 2, 15); // taxSeason active but not start
      SharedPreferences.setMockInitialValues({
        '_proactive_stored_phase': 'acceleration',
      });
      final prefs = await SharedPreferences.getInstance();

      final trigger = await ProactiveTriggerService.evaluate(
        profile: _makeProfile(birthYear: 1985),
        prefs: prefs,
        now: feb15,
      );
      expect(trigger?.type == ProactiveTriggerType.seasonalReminder, isFalse,
          reason: 'Seasonal reminder only fires on event start day');
    });

    // ── Test 14: Inactive 7+ days → inactivityReturn ────────

    test('14. Last activity 8 days ago → inactivityReturn fires', () async {
      final lastActivity = tuesday.subtract(const Duration(days: 8));
      SharedPreferences.setMockInitialValues({
        '_proactive_stored_phase': 'acceleration',
        '_nudge_last_activity': lastActivity.toIso8601String(),
      });
      final prefs = await SharedPreferences.getInstance();

      final trigger = await ProactiveTriggerService.evaluate(
        profile: _makeProfile(birthYear: 1985),
        prefs: prefs,
        now: tuesday,
      );
      expect(trigger, isNotNull);
      expect(trigger!.type, ProactiveTriggerType.inactivityReturn);
      expect(trigger.params?['days'], '8');
    });

    // ── Test 15: Inactive 6 days → no trigger ───────────────

    test('15. Last activity 6 days ago → no inactivityReturn', () async {
      final lastActivity = tuesday.subtract(const Duration(days: 6));
      SharedPreferences.setMockInitialValues({
        '_proactive_stored_phase': 'acceleration',
        '_nudge_last_activity': lastActivity.toIso8601String(),
      });
      final prefs = await SharedPreferences.getInstance();

      final trigger = await ProactiveTriggerService.evaluate(
        profile: _makeProfile(birthYear: 1985),
        prefs: prefs,
        now: tuesday,
      );
      expect(trigger?.type == ProactiveTriggerType.inactivityReturn, isFalse,
          reason: 'Threshold is 7 days, not 6');
    });

    // ── Test 16: No activity stored + 10d old profile ───────

    test('16. No activity stored, profile 10 days old → inactivityReturn fires', () async {
      final createdAt = tuesday.subtract(const Duration(days: 10));
      SharedPreferences.setMockInitialValues({
        '_proactive_stored_phase': 'acceleration',
        // No _nudge_last_activity key.
      });
      final prefs = await SharedPreferences.getInstance();

      final trigger = await ProactiveTriggerService.evaluate(
        profile: _makeProfile(birthYear: 1985, createdAt: createdAt),
        prefs: prefs,
        now: tuesday,
      );
      expect(trigger, isNotNull);
      expect(trigger!.type, ProactiveTriggerType.inactivityReturn);
    });

    // ── Test 17: Confidence improved 6 pts ──────────────────

    test('17. Confidence improved 6 pts → confidenceImproved fires', () async {
      // Profile has enough data to score higher than stored value.
      // Stored = 55, current will be higher due to LPP data.
      final profileWithData = CoachProfile(
        birthYear: 1985,
        canton: 'VS',
        etatCivil: CoachCivilStatus.celibataire,
        nombreEnfants: 0,
        salaireBrutMensuel: 8000,
        nombreDeMois: 12,
        employmentStatus: 'salarie',
        depenses: const DepensesProfile(),
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 50000,
          anneesContribuees: 15,
          totalEpargne3a: 20000,
        ),
        patrimoine: const PatrimoineProfile(epargneLiquide: 30000),
        dettes: const DetteProfile(),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2045, 1, 1),
          label: 'Retraite',
        ),
        goalsB: const [],
        plannedContributions: const [],
        checkIns: const [],
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      // Store a low score so the delta is > 5.
      SharedPreferences.setMockInitialValues({
        '_proactive_stored_phase': 'acceleration',
        '_proactive_stored_confidence': '30.0',
        '_nudge_last_activity': tuesday.subtract(const Duration(days: 1)).toIso8601String(),
      });
      final prefs = await SharedPreferences.getInstance();

      final trigger = await ProactiveTriggerService.evaluate(
        profile: profileWithData,
        prefs: prefs,
        now: tuesday,
      );
      expect(trigger, isNotNull);
      expect(trigger!.type, ProactiveTriggerType.confidenceImproved);
      expect(trigger.messageKey, 'proactiveConfidenceUp');
    });

    // ── Test 18: Confidence improved < 5 pts → no trigger ───

    test('18. Confidence improved only 3 pts → no confidenceImproved', () async {
      // Get the actual score for a minimal profile then store score - 3.
      final profile = _makeProfile(birthYear: 1985);
      SharedPreferences.setMockInitialValues({
        '_proactive_stored_phase': 'acceleration',
        // Store a value close to what ConfidenceScorer returns for minimal profile.
        // Minimal profile = ~55 pts. Store 53 → delta = 2 < 5.
        '_proactive_stored_confidence': '53.0',
        '_nudge_last_activity': tuesday.subtract(const Duration(days: 1)).toIso8601String(),
      });
      final prefs = await SharedPreferences.getInstance();

      final trigger = await ProactiveTriggerService.evaluate(
        profile: profile,
        prefs: prefs,
        now: tuesday,
      );
      expect(trigger?.type == ProactiveTriggerType.confidenceImproved, isFalse,
          reason: 'Delta must be >= 5 pts');
    });

    // ── Test 19: No stored confidence → no trigger ───────────

    test('19. No stored confidence → no confidenceImproved trigger', () async {
      SharedPreferences.setMockInitialValues({
        '_proactive_stored_phase': 'acceleration',
        // No _proactive_stored_confidence key.
        '_nudge_last_activity': tuesday.subtract(const Duration(days: 1)).toIso8601String(),
      });
      final prefs = await SharedPreferences.getInstance();

      final trigger = await ProactiveTriggerService.evaluate(
        profile: _makeProfile(birthYear: 1985),
        prefs: prefs,
        now: tuesday,
      );
      expect(trigger?.type == ProactiveTriggerType.confidenceImproved, isFalse,
          reason: 'Cannot compute delta without stored baseline');
    });

    // ── Test 20: New cap id → newCapAvailable fires ──────────
    // CapMemoryStore.load() reads from SharedPreferences.

    test('20. New cap id differs from shown → newCapAvailable fires', () async {
      // Simulate: CapMemory has lastCapServed = 'debt_correct',
      // but our stored last-shown cap is 'lpp_buyback'.
      SharedPreferences.setMockInitialValues({
        '_proactive_stored_phase': 'acceleration',
        '_proactive_stored_confidence': '55.0',
        '_proactive_last_cap_id': 'lpp_buyback',
        '_nudge_last_activity': tuesday.subtract(const Duration(days: 1)).toIso8601String(),
        '_cap_memory': '{"completedActions":[],"abandonedFlows":[],"declaredGoals":[],"lastCapServed":"debt_correct"}',
      });
      final prefs = await SharedPreferences.getInstance();

      final trigger = await ProactiveTriggerService.evaluate(
        profile: _makeProfile(birthYear: 1985),
        prefs: prefs,
        now: tuesday,
      );
      expect(trigger, isNotNull);
      expect(trigger!.type, ProactiveTriggerType.newCapAvailable);
      expect(trigger.messageKey, 'proactiveNewCap');
    });

    // ── Test 21: Cap id same → no newCapAvailable ────────────

    test('21. Same cap id as shown → no newCapAvailable trigger', () async {
      SharedPreferences.setMockInitialValues({
        '_proactive_stored_phase': 'acceleration',
        '_proactive_stored_confidence': '55.0',
        '_proactive_last_cap_id': 'debt_correct',
        '_nudge_last_activity': tuesday.subtract(const Duration(days: 1)).toIso8601String(),
        '_cap_memory': '{"completedActions":[],"abandonedFlows":[],"declaredGoals":[],"lastCapServed":"debt_correct"}',
      });
      final prefs = await SharedPreferences.getInstance();

      final trigger = await ProactiveTriggerService.evaluate(
        profile: _makeProfile(birthYear: 1985),
        prefs: prefs,
        now: tuesday,
      );
      expect(trigger?.type == ProactiveTriggerType.newCapAvailable, isFalse,
          reason: 'Cap has not changed');
    });

    // ── Test 22: Cooldown prevents double trigger same day ───

    test('22. Two evaluations same day → second returns null (cooldown)', () async {
      // First evaluation with phase change to trigger something.
      SharedPreferences.setMockInitialValues({
        '_proactive_stored_phase': 'construction',
      });
      final prefs = await SharedPreferences.getInstance();

      final first = await ProactiveTriggerService.evaluate(
        profile: _makeProfile(birthYear: 1977), // consolidation
        prefs: prefs,
        now: tuesday,
      );
      expect(first, isNotNull, reason: 'First evaluation should trigger');

      // Second evaluation same day — cooldown active.
      final second = await ProactiveTriggerService.evaluate(
        profile: _makeProfile(birthYear: 1977),
        prefs: prefs,
        now: tuesday,
      );
      expect(second, isNull, reason: 'Cooldown prevents same-day double trigger');
    });

    // ── Test 23: Cooldown allows trigger next day ────────────

    test('23. Previous trigger yesterday → new trigger fires today', () async {
      final yesterday = tuesday.subtract(const Duration(days: 1));
      SharedPreferences.setMockInitialValues({
        '_proactive_stored_phase': 'construction',
        '_proactive_last_trigger_date': yesterday.toIso8601String(),
      });
      final prefs = await SharedPreferences.getInstance();

      final trigger = await ProactiveTriggerService.evaluate(
        profile: _makeProfile(birthYear: 1977), // consolidation
        prefs: prefs,
        now: tuesday,
      );
      expect(trigger, isNotNull, reason: 'Cooldown expired — new trigger is allowed');
    });

    // ── Test 24: Priority order ──────────────────────────────

    test('24. Phase change has higher priority than weeklyRecap', () async {
      // Monday + phase changed: lifecyclePhaseChange fires first.
      final prefs = await _prefsWithPhase('construction');
      final trigger = await ProactiveTriggerService.evaluate(
        profile: _makeProfile(birthYear: 1977), // consolidation
        prefs: prefs,
        now: monday,
      );
      expect(trigger, isNotNull);
      // lifecyclePhaseChange has priority 1 over weeklyRecap (priority 2).
      expect(trigger!.type, ProactiveTriggerType.lifecyclePhaseChange,
          reason: 'Phase change fires before weeklyRecap');
    });

    // ── Test 25: Golden couple Julien ────────────────────────

    test('25. Julien — 10 days inactive → inactivityReturn fires', () async {
      // Julien (born 1977) → consolidation at 2026.
      // Phase stored as consolidation → no change.
      // Inactive 10 days → inactivityReturn fires.
      final lastActivity = tuesday.subtract(const Duration(days: 10));
      SharedPreferences.setMockInitialValues({
        '_proactive_stored_phase': 'consolidation',
        '_proactive_stored_confidence': '55.0',
        '_nudge_last_activity': lastActivity.toIso8601String(),
      });
      final prefs = await SharedPreferences.getInstance();

      final trigger = await ProactiveTriggerService.evaluate(
        profile: _julienProfile(),
        prefs: prefs,
        now: tuesday,
      );
      expect(trigger, isNotNull);
      expect(trigger!.type, ProactiveTriggerType.inactivityReturn);
      expect(trigger.params?['days'], '10');
      expect(trigger.intentTag, '/pulse');
    });

    // ── Helper: estimateGoalProgress unit tests ──────────────

    group('estimateGoalProgress', () {
      test('Goal 44 days old (no target) → 0', () {
        final goal = UserGoal(
          id: 'g1',
          description: 'test',
          category: 'other',
          createdAt: tuesday.subtract(const Duration(days: 44)),
        );
        expect(ProactiveTriggerService.estimateGoalProgress(goal, tuesday), 0);
      });

      test('Goal 45 days old (no target) → 50', () {
        final goal = UserGoal(
          id: 'g2',
          description: 'test',
          category: 'other',
          createdAt: tuesday.subtract(const Duration(days: 45)),
        );
        expect(
            ProactiveTriggerService.estimateGoalProgress(goal, tuesday), 50);
      });

      test('Goal 89 days old (no target) → 50', () {
        final goal = UserGoal(
          id: 'g3',
          description: 'test',
          category: 'other',
          createdAt: tuesday.subtract(const Duration(days: 89)),
        );
        expect(
            ProactiveTriggerService.estimateGoalProgress(goal, tuesday), 50);
      });

      test('Goal 90 days old (no target) → 100', () {
        final goal = UserGoal(
          id: 'g4',
          description: 'test',
          category: 'other',
          createdAt: tuesday.subtract(const Duration(days: 90)),
        );
        expect(
            ProactiveTriggerService.estimateGoalProgress(goal, tuesday), 100);
      });

      test('Goal with target date, same day as target → 100', () {
        final created = tuesday.subtract(const Duration(days: 100));
        final goal = UserGoal(
          id: 'g5',
          description: 'test',
          category: 'other',
          createdAt: created,
          targetDate: tuesday,
        );
        expect(
            ProactiveTriggerService.estimateGoalProgress(goal, tuesday), 100);
      });

      test('Goal with 0-day target span → 100', () {
        final goal = UserGoal(
          id: 'g6',
          description: 'test',
          category: 'other',
          createdAt: tuesday,
          targetDate: tuesday,
        );
        expect(
            ProactiveTriggerService.estimateGoalProgress(goal, tuesday), 100);
      });

      test('storeCurrentPhase writes phase to prefs', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        await ProactiveTriggerService.storeCurrentPhase(
          _makeProfile(birthYear: 1985), // acceleration
          prefs,
          now: tuesday,
        );
        expect(prefs.getString('_proactive_stored_phase'), 'acceleration');
      });

      test('markRecapSeen stores ISO8601 date', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        await ProactiveTriggerService.markRecapSeen(prefs, now: tuesday);
        final stored = prefs.getString('_proactive_last_recap_seen');
        expect(stored, isNotNull);
        expect(DateTime.parse(stored!), tuesday);
      });
    });
  });
}
