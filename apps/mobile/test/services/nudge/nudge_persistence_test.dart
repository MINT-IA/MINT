import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/services/nudge/nudge_persistence.dart';
import 'package:mint_mobile/services/nudge/nudge_trigger.dart';

// ────────────────────────────────────────────────────────────
//  NUDGE PERSISTENCE TESTS — S61 / JITAI Proactive Nudges
// ────────────────────────────────────────────────────────────
//
// 15 tests covering:
//   - dismiss stores key with ISO8601 timestamp
//   - getDismissedIds returns id within cooldown
//   - getDismissedIds excludes expired dismissals
//   - clearExpired removes expired entries
//   - clearExpired keeps valid entries
//   - getLastActivityTime returns null when never set
//   - recordActivity stores timestamp
//   - getLastActivityTime returns correct DateTime after recordActivity
//   - Cooldown days per trigger type
//   - Multiple dismissals tracked independently
// ────────────────────────────────────────────────────────────

void main() {
  group('NudgePersistence', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    // ── 1. dismiss stores key ─────────────────────────────────

    test('dismiss stores ISO8601 timestamp in SharedPreferences', () async {
      final now = DateTime(2026, 3, 15, 12, 0, 0);
      await NudgePersistence.dismiss(
        'taxDeadlineApproach_202603',
        NudgeTrigger.taxDeadlineApproach,
        prefs,
        now: now,
      );

      const key = '_nudge_dismissed_taxDeadlineApproach';
      expect(prefs.getString(key), isNotNull);
      expect(prefs.getString(key), contains('2026'));
    });

    // ── 2. getDismissedIds within cooldown ────────────────────

    test('getDismissedIds returns id within cooldown window', () async {
      final dismissDate = DateTime(2026, 3, 15);
      await NudgePersistence.dismiss(
        'taxDeadlineApproach_202603',
        NudgeTrigger.taxDeadlineApproach,
        prefs,
        now: dismissDate,
      );

      // 3 days later (well within 7-day cooldown)
      final now = DateTime(2026, 3, 18);
      final dismissed = await NudgePersistence.getDismissedIds(prefs, now: now);

      expect(dismissed.any((id) => id.contains('taxDeadlineApproach')), isTrue,
          reason: 'taxDeadlineApproach should be in dismissed list within cooldown');
    });

    // ── 3. getDismissedIds excludes expired ───────────────────

    test('getDismissedIds excludes expired dismissals', () async {
      final dismissDate = DateTime(2026, 3, 1);
      await NudgePersistence.dismiss(
        'taxDeadlineApproach_202603',
        NudgeTrigger.taxDeadlineApproach,
        prefs,
        now: dismissDate,
      );

      // 10 days later — taxDeadlineApproach cooldown is 7 days
      final now = DateTime(2026, 3, 11);
      final dismissed = await NudgePersistence.getDismissedIds(prefs, now: now);

      expect(dismissed.any((id) => id.contains('taxDeadlineApproach')), isFalse,
          reason: 'Expired dismissal should not appear in dismissed list');
    });

    // ── 4. clearExpired removes expired entry ─────────────────

    test('clearExpired removes expired dismiss entries', () async {
      final dismissDate = DateTime(2026, 3, 1);
      await NudgePersistence.dismiss(
        'taxDeadlineApproach_202603',
        NudgeTrigger.taxDeadlineApproach,
        prefs,
        now: dismissDate,
      );

      // Verify it exists
      expect(prefs.getString('_nudge_dismissed_taxDeadlineApproach'), isNotNull);

      // Clear expired (10 days later)
      final now = DateTime(2026, 3, 11);
      await NudgePersistence.clearExpired(prefs, now: now);

      expect(prefs.getString('_nudge_dismissed_taxDeadlineApproach'), isNull,
          reason: 'Expired key should be removed by clearExpired');
    });

    // ── 5. clearExpired keeps valid entry ─────────────────────

    test('clearExpired keeps valid (non-expired) dismiss entries', () async {
      final dismissDate = DateTime(2026, 3, 15);
      await NudgePersistence.dismiss(
        'taxDeadlineApproach_202603',
        NudgeTrigger.taxDeadlineApproach,
        prefs,
        now: dismissDate,
      );

      // 3 days later — still within 7-day cooldown
      final now = DateTime(2026, 3, 18);
      await NudgePersistence.clearExpired(prefs, now: now);

      expect(prefs.getString('_nudge_dismissed_taxDeadlineApproach'), isNotNull,
          reason: 'Non-expired key should be kept by clearExpired');
    });

    // ── 6. getLastActivityTime returns null initially ─────────

    test('getLastActivityTime returns null when no activity recorded', () async {
      final activity = await NudgePersistence.getLastActivityTime(prefs);
      expect(activity, isNull,
          reason: 'No activity recorded — should return null');
    });

    // ── 7. recordActivity stores timestamp ────────────────────

    test('recordActivity stores timestamp in SharedPreferences', () async {
      final now = DateTime(2026, 5, 10, 14, 30);
      await NudgePersistence.recordActivity(prefs, now: now);

      final raw = prefs.getString('_nudge_last_activity');
      expect(raw, isNotNull);
      expect(raw, contains('2026'));
    });

    // ── 8. getLastActivityTime returns correct DateTime ───────

    test('getLastActivityTime returns the stored DateTime', () async {
      final expected = DateTime(2026, 5, 10, 14, 30, 0);
      await NudgePersistence.recordActivity(prefs, now: expected);

      final actual = await NudgePersistence.getLastActivityTime(prefs);
      expect(actual, isNotNull);
      expect(actual!.year, equals(2026));
      expect(actual.month, equals(5));
      expect(actual.day, equals(10));
    });

    // ── 9. Overwrite latest activity ─────────────────────────

    test('recordActivity overwrites previous timestamp', () async {
      final first = DateTime(2026, 5, 1);
      final second = DateTime(2026, 5, 10);

      await NudgePersistence.recordActivity(prefs, now: first);
      await NudgePersistence.recordActivity(prefs, now: second);

      final stored = await NudgePersistence.getLastActivityTime(prefs);
      expect(stored!.day, equals(10),
          reason: 'Second recordActivity should overwrite the first');
    });

    // ── 10. Cooldown days per trigger type ───────────────────

    test('cooldownDays returns correct values per trigger', () {
      expect(NudgePersistence.cooldownDays(NudgeTrigger.salaryReceived), equals(25));
      expect(NudgePersistence.cooldownDays(NudgeTrigger.taxDeadlineApproach), equals(7));
      expect(NudgePersistence.cooldownDays(NudgeTrigger.pillar3aDeadline), equals(7));
      expect(NudgePersistence.cooldownDays(NudgeTrigger.birthdayMilestone), equals(360));
      expect(NudgePersistence.cooldownDays(NudgeTrigger.profileIncomplete), equals(14));
      expect(NudgePersistence.cooldownDays(NudgeTrigger.noActivityWeek), equals(5));
      expect(NudgePersistence.cooldownDays(NudgeTrigger.goalProgress), equals(7));
      expect(NudgePersistence.cooldownDays(NudgeTrigger.lifeEventAnniversary), equals(360));
      expect(NudgePersistence.cooldownDays(NudgeTrigger.lppBuybackWindow), equals(30));
      expect(NudgePersistence.cooldownDays(NudgeTrigger.newYearReset), equals(14));
    });

    // ── 11. Multiple dismissals tracked independently ─────────

    test('multiple triggers dismissed independently', () async {
      final now = DateTime(2026, 3, 15);
      await NudgePersistence.dismiss(
        'taxDeadlineApproach_202603',
        NudgeTrigger.taxDeadlineApproach,
        prefs,
        now: now,
      );
      await NudgePersistence.dismiss(
        'pillar3aDeadline_202612',
        NudgeTrigger.pillar3aDeadline,
        prefs,
        now: now,
      );

      final dismissed = await NudgePersistence.getDismissedIds(prefs, now: now);
      expect(dismissed.any((id) => id.contains('taxDeadlineApproach')), isTrue);
      expect(dismissed.any((id) => id.contains('pillar3aDeadline')), isTrue);
    });

    // ── 12. getDismissedIds returns empty list initially ──────

    test('getDismissedIds returns empty list when nothing dismissed', () async {
      final now = DateTime(2026, 3, 15);
      final dismissed = await NudgePersistence.getDismissedIds(prefs, now: now);
      expect(dismissed, isEmpty);
    });

    // ── 13. clearExpired handles malformed dates gracefully ───

    test('clearExpired handles malformed timestamp gracefully', () async {
      // Manually inject malformed timestamp
      await prefs.setString('_nudge_dismissed_salaryReceived', 'not-a-date');

      final now = DateTime(2026, 3, 15);
      // Should not throw
      await expectLater(
        NudgePersistence.clearExpired(prefs, now: now),
        completes,
      );
      // Malformed entry should be removed
      expect(prefs.getString('_nudge_dismissed_salaryReceived'), isNull);
    });

    // ── 14. Birthday milestone has 360-day cooldown ───────────

    test('birthdayMilestone cooldown prevents annual re-trigger', () async {
      final dismissDate = DateTime(2026, 1, 3);
      await NudgePersistence.dismiss(
        'birthdayMilestone_202601',
        NudgeTrigger.birthdayMilestone,
        prefs,
        now: dismissDate,
      );

      // 6 months later — still within 360-day cooldown
      final sixMonthsLater = DateTime(2026, 7, 3);
      final dismissed = await NudgePersistence.getDismissedIds(
        prefs,
        now: sixMonthsLater,
      );

      expect(dismissed.any((id) => id.contains('birthdayMilestone')), isTrue,
          reason: 'birthdayMilestone has 360-day cooldown — 6 months should still suppress');
    });

    // ── 15. getLastActivityTime handles malformed date ────────

    test('getLastActivityTime returns null for malformed stored date', () async {
      await prefs.setString('_nudge_last_activity', 'invalid-iso');
      final result = await NudgePersistence.getLastActivityTime(prefs);
      expect(result, isNull,
          reason: 'Malformed date string should return null gracefully');
    });
  });
}
