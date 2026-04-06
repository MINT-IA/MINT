import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/services/anticipation/anticipation_persistence.dart';
import 'package:mint_mobile/services/anticipation/anticipation_trigger.dart';

// ────────────────────────────────────────────────────────────
//  ANTICIPATION PERSISTENCE TESTS — Phase 04 Plan 02
// ────────────────────────────────────────────────────────────
//
// Tests weekly frequency cap, dismiss cooldown, and snooze logic
// for anticipation signals.
//
// Uses SharedPreferences.setMockInitialValues({}) for hermetic tests.
// All DateTime values are injected for deterministic results.
// ────────────────────────────────────────────────────────────

void main() {
  // ═══════════════════════════════════════════════════════════
  // Weekly frequency cap
  // ═══════════════════════════════════════════════════════════

  group('Weekly frequency cap', () {
    test('signalsShownThisWeek returns 0 at start', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime(2026, 4, 6); // Monday

      final count = await AnticipationPersistence.signalsShownThisWeek(
        prefs,
        now: now,
      );
      expect(count, 0);
    });

    test('recordSignalShown increments weekly counter', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime(2026, 4, 6); // Monday

      await AnticipationPersistence.recordSignalShown(prefs, now: now);
      var count = await AnticipationPersistence.signalsShownThisWeek(
        prefs,
        now: now,
      );
      expect(count, 1);

      await AnticipationPersistence.recordSignalShown(prefs, now: now);
      count = await AnticipationPersistence.signalsShownThisWeek(
        prefs,
        now: now,
      );
      expect(count, 2);
    });

    test('signalsShownThisWeek resets on new ISO week', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final monday = DateTime(2026, 4, 6); // Monday
      final nextMonday = DateTime(2026, 4, 13); // Next Monday

      await AnticipationPersistence.recordSignalShown(prefs, now: monday);
      await AnticipationPersistence.recordSignalShown(prefs, now: monday);

      // Same week
      var count = await AnticipationPersistence.signalsShownThisWeek(
        prefs,
        now: monday,
      );
      expect(count, 2);

      // Next week — should reset
      count = await AnticipationPersistence.signalsShownThisWeek(
        prefs,
        now: nextMonday,
      );
      expect(count, 0);
    });

    test('counter persists within same ISO week across days', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final monday = DateTime(2026, 4, 6); // Monday
      final wednesday = DateTime(2026, 4, 8); // Wednesday same week

      await AnticipationPersistence.recordSignalShown(prefs, now: monday);

      final count = await AnticipationPersistence.signalsShownThisWeek(
        prefs,
        now: wednesday,
      );
      expect(count, 1);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Dismiss cooldown
  // ═══════════════════════════════════════════════════════════

  group('Dismiss cooldown', () {
    test('dismiss suppresses trigger for cooldown duration', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime(2026, 4, 6);

      await AnticipationPersistence.dismiss(
        prefs,
        AnticipationTrigger.cantonalTaxDeadline,
        now: now,
      );

      // Within cooldown (30 days for cantonalTaxDeadline)
      final during = DateTime(2026, 4, 20); // 14 days later
      final dismissed = await AnticipationPersistence.getDismissedTriggers(
        prefs,
        now: during,
      );
      expect(dismissed, contains(AnticipationTrigger.cantonalTaxDeadline));
    });

    test('dismiss expires after cooldown period', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime(2026, 4, 6);

      await AnticipationPersistence.dismiss(
        prefs,
        AnticipationTrigger.cantonalTaxDeadline,
        now: now,
      );

      // After cooldown (30 days + 1 for cantonalTaxDeadline)
      final after = DateTime(2026, 5, 7); // 31 days later
      final dismissed = await AnticipationPersistence.getDismissedTriggers(
        prefs,
        now: after,
      );
      expect(dismissed, isNot(contains(AnticipationTrigger.cantonalTaxDeadline)));
    });

    test('fiscal3aDeadline has 365-day cooldown', () {
      expect(
        AnticipationPersistence.dismissCooldownDays(
          AnticipationTrigger.fiscal3aDeadline,
        ),
        365,
      );
    });

    test('lppRachatWindow has 60-day cooldown', () {
      expect(
        AnticipationPersistence.dismissCooldownDays(
          AnticipationTrigger.lppRachatWindow,
        ),
        60,
      );
    });

    test('salaryIncrease3aRecalc has 90-day cooldown', () {
      expect(
        AnticipationPersistence.dismissCooldownDays(
          AnticipationTrigger.salaryIncrease3aRecalc,
        ),
        90,
      );
    });

    test('ageMilestoneLppBonification has 365-day cooldown', () {
      expect(
        AnticipationPersistence.dismissCooldownDays(
          AnticipationTrigger.ageMilestoneLppBonification,
        ),
        365,
      );
    });

    test('getDismissedTriggers returns only non-expired', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime(2026, 4, 6);

      // Dismiss two triggers
      await AnticipationPersistence.dismiss(
        prefs,
        AnticipationTrigger.cantonalTaxDeadline, // 30 days
        now: now,
      );
      await AnticipationPersistence.dismiss(
        prefs,
        AnticipationTrigger.fiscal3aDeadline, // 365 days
        now: now,
      );

      // 31 days later: cantonalTax expired, fiscal3a still active
      final later = DateTime(2026, 5, 7);
      final dismissed = await AnticipationPersistence.getDismissedTriggers(
        prefs,
        now: later,
      );
      expect(dismissed, isNot(contains(AnticipationTrigger.cantonalTaxDeadline)));
      expect(dismissed, contains(AnticipationTrigger.fiscal3aDeadline));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Snooze logic
  // ═══════════════════════════════════════════════════════════

  group('Snooze logic', () {
    test('snooze suppresses trigger for snooze duration', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime(2026, 4, 6);

      await AnticipationPersistence.snooze(
        prefs,
        AnticipationTrigger.fiscal3aDeadline,
        now: now,
      );

      // Within snooze (7 days for fiscal3aDeadline)
      final during = DateTime(2026, 4, 10); // 4 days later
      final snoozed = await AnticipationPersistence.getSnoozedTriggers(
        prefs,
        now: during,
      );
      expect(snoozed, contains(AnticipationTrigger.fiscal3aDeadline));
    });

    test('snooze expires after snooze period', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime(2026, 4, 6);

      await AnticipationPersistence.snooze(
        prefs,
        AnticipationTrigger.fiscal3aDeadline,
        now: now,
      );

      // After snooze (7 days + 1)
      final after = DateTime(2026, 4, 14); // 8 days later
      final snoozed = await AnticipationPersistence.getSnoozedTriggers(
        prefs,
        now: after,
      );
      expect(snoozed, isNot(contains(AnticipationTrigger.fiscal3aDeadline)));
    });

    test('snooze durations per trigger type', () {
      expect(
        AnticipationPersistence.snoozeDays(AnticipationTrigger.fiscal3aDeadline),
        7,
      );
      expect(
        AnticipationPersistence.snoozeDays(AnticipationTrigger.cantonalTaxDeadline),
        7,
      );
      expect(
        AnticipationPersistence.snoozeDays(AnticipationTrigger.lppRachatWindow),
        14,
      );
      expect(
        AnticipationPersistence.snoozeDays(AnticipationTrigger.salaryIncrease3aRecalc),
        14,
      );
      expect(
        AnticipationPersistence.snoozeDays(AnticipationTrigger.ageMilestoneLppBonification),
        30,
      );
    });

    test('dismiss takes precedence over snooze on same trigger', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime(2026, 4, 6);

      // Snooze first, then dismiss
      await AnticipationPersistence.snooze(
        prefs,
        AnticipationTrigger.lppRachatWindow,
        now: now,
      );
      await AnticipationPersistence.dismiss(
        prefs,
        AnticipationTrigger.lppRachatWindow,
        now: now,
      );

      // 15 days later: snooze (14 days) would have expired, but dismiss (60 days) still active
      final later = DateTime(2026, 4, 21);
      final dismissed = await AnticipationPersistence.getDismissedTriggers(
        prefs,
        now: later,
      );
      expect(dismissed, contains(AnticipationTrigger.lppRachatWindow));
    });
  });
}
