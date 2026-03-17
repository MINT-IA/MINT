import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/notification_scheduler_service.dart';
import 'package:mint_mobile/services/plan_tracking_service.dart';

// ═══════════════════════════════════════════════════════════════
//  NOTIFICATION SCHEDULER SERVICE — Unit tests
// ═══════════════════════════════════════════════════════════════
//
// Tests:
//   1. Calendar: generates 3a deadline reminders (Oct, Nov, Dec, Dec20)
//   2. Calendar: generates monthly check-in reminders
//   3. Calendar: generates tax declaration reminders
//   4. Calendar: generates Jan 5 new-year plafonds
//   5. Calendar: skips past dates
//   6. Calendar: all notifications have deeplinks
//   7. Calendar: personal numbers contain CHF amounts
//   8. Calendar: time references are present in all bodies
//   9. Event: FRI improvement on check-in completion
//  10. Event: profile update notification
//  11. Event: FRI improvement without check-in
//  12. Event: off-track plan notification
//  13. Event: no notifications when no events
//  14. Event: FRI delta = 0 with check-in → no FRI notification
//  15. Calendar: Dec schedule from January shows all 4 reminders
//  16. Calendar: Nov schedule skips Oct reminder
//  17. Deduplication: all calendar notifications have unique dates
//  18. Formatting: CHF amounts use Swiss apostrophe
//  19. No banned terms in any notification body
//  20. Event: negative FRI delta shows minus sign
// ═══════════════════════════════════════════════════════════════

void main() {
  // ── Tier 1: Calendar notifications ────────────────────────────

  group('NotificationSchedulerService.generateCalendarNotifications', () {
    test('generates 3a deadline reminders from January', () {
      final notifications =
          NotificationSchedulerService.generateCalendarNotifications(
        taxSaving3a: 1820,
        today: DateTime(2026, 1, 15, 8, 0),
      );

      final threeANotifs = notifications
          .where((n) => n.category == NotificationCategory.threeADeadline)
          .toList();

      // Should have Oct 1, Nov 1, Dec 1, Dec 20 = 4 reminders
      expect(threeANotifs.length, 4);

      // Verify dates
      final dates =
          threeANotifs.map((n) => '${n.scheduledDate.month}-${n.scheduledDate.day}').toSet();
      expect(dates, contains('10-1'));
      expect(dates, contains('11-1'));
      expect(dates, contains('12-1'));
      expect(dates, contains('12-20'));
    });

    test('generates monthly check-in reminders', () {
      final notifications =
          NotificationSchedulerService.generateCalendarNotifications(
        taxSaving3a: 1500,
        today: DateTime(2026, 1, 15, 8, 0),
      );

      final checkIns = notifications
          .where((n) => n.category == NotificationCategory.monthlyCheckIn)
          .toList();

      // From Jan 15 → remaining months: Feb-Dec + Jan next year = 12
      expect(checkIns.length, 12);

      // All check-ins should deeplink to coach/checkin
      for (final n in checkIns) {
        expect(n.deeplink, '/coach/checkin');
        expect(n.tier, NotificationTier.calendar);
      }
    });

    test('generates tax declaration reminders from January', () {
      final notifications =
          NotificationSchedulerService.generateCalendarNotifications(
        taxSaving3a: 2000,
        today: DateTime(2026, 1, 10, 8, 0),
      );

      final taxNotifs = notifications
          .where((n) => n.category == NotificationCategory.taxDeclaration)
          .toList();

      // Should have Feb 15, Mar 15, Mar 25 = 3 reminders
      expect(taxNotifs.length, 3);

      final dates =
          taxNotifs.map((n) => '${n.scheduledDate.month}-${n.scheduledDate.day}').toSet();
      expect(dates, contains('2-15'));
      expect(dates, contains('3-15'));
      expect(dates, contains('3-25'));
    });

    test('generates Jan 5 new-year plafonds notification', () {
      final notifications =
          NotificationSchedulerService.generateCalendarNotifications(
        taxSaving3a: 1500,
        today: DateTime(2026, 6, 1, 8, 0),
      );

      final plafonds = notifications
          .where((n) => n.category == NotificationCategory.newYearPlafonds)
          .toList();

      expect(plafonds.length, 1);
      expect(plafonds.first.scheduledDate.month, 1);
      expect(plafonds.first.scheduledDate.day, 5);
      expect(plafonds.first.scheduledDate.year, 2027);
      expect(plafonds.first.body, contains('2027'));
    });

    test('skips dates in the past', () {
      // Set today to November 15 → Oct 1 and Nov 1 are past
      final notifications =
          NotificationSchedulerService.generateCalendarNotifications(
        taxSaving3a: 1820,
        today: DateTime(2026, 11, 15, 8, 0),
      );

      final threeANotifs = notifications
          .where((n) => n.category == NotificationCategory.threeADeadline)
          .toList();

      // Only Dec 1 and Dec 20 should remain
      expect(threeANotifs.length, 2);
      for (final n in threeANotifs) {
        expect(n.scheduledDate.month, 12);
      }
    });

    test('skips tax reminders when past March', () {
      final notifications =
          NotificationSchedulerService.generateCalendarNotifications(
        taxSaving3a: 1500,
        today: DateTime(2026, 4, 1, 8, 0),
      );

      final taxNotifs = notifications
          .where((n) => n.category == NotificationCategory.taxDeclaration)
          .toList();

      expect(taxNotifs, isEmpty);
    });

    test('all notifications have deeplinks starting with /', () {
      final notifications =
          NotificationSchedulerService.generateCalendarNotifications(
        taxSaving3a: 1000,
        today: DateTime(2026, 1, 1, 8, 0),
      );

      for (final n in notifications) {
        expect(n.deeplink, startsWith('/'));
      }
    });

    test('all notifications have non-empty personalNumber and timeReference',
        () {
      final notifications =
          NotificationSchedulerService.generateCalendarNotifications(
        taxSaving3a: 1820,
        today: DateTime(2026, 1, 1, 8, 0),
      );

      for (final n in notifications) {
        expect(n.personalNumber, isNotEmpty,
            reason: 'personalNumber should not be empty for ${n.category}');
        expect(n.timeReference, isNotEmpty,
            reason: 'timeReference should not be empty for ${n.category}');
      }
    });

    test('CHF amounts formatted with Swiss apostrophe', () {
      final notifications =
          NotificationSchedulerService.generateCalendarNotifications(
        taxSaving3a: 1820,
        today: DateTime(2026, 1, 1, 8, 0),
      );

      // The Nov 1 notification should contain "1'820"
      final nov1 = notifications.firstWhere(
        (n) =>
            n.category == NotificationCategory.threeADeadline &&
            n.scheduledDate.month == 11,
      );
      expect(nov1.body, contains("1'820"));
    });

    test('from November, only Dec reminders for 3a', () {
      final notifications =
          NotificationSchedulerService.generateCalendarNotifications(
        taxSaving3a: 1500,
        today: DateTime(2026, 11, 5, 8, 0),
      );

      final threeANotifs = notifications
          .where((n) => n.category == NotificationCategory.threeADeadline)
          .toList();

      // Dec 1 and Dec 20
      expect(threeANotifs.length, 2);
    });

    test('all calendar notifications are tier calendar', () {
      final notifications =
          NotificationSchedulerService.generateCalendarNotifications(
        taxSaving3a: 1000,
        today: DateTime(2026, 1, 1, 8, 0),
      );

      for (final n in notifications) {
        expect(n.tier, NotificationTier.calendar);
      }
    });

    test('unique scheduled dates for calendar notifications of same category',
        () {
      final notifications =
          NotificationSchedulerService.generateCalendarNotifications(
        taxSaving3a: 1500,
        today: DateTime(2026, 1, 1, 8, 0),
      );

      // Within each category, dates should be unique
      final categories = NotificationCategory.values;
      for (final cat in categories) {
        final catNotifs = notifications.where((n) => n.category == cat).toList();
        final dates = catNotifs.map((n) => n.scheduledDate.toIso8601String()).toSet();
        expect(dates.length, catNotifs.length,
            reason: 'Duplicate dates found in category $cat');
      }
    });
  });

  // ── Tier 2: Event notifications ───────────────────────────────

  group('NotificationSchedulerService.generateEventNotifications', () {
    test('FRI improvement on check-in completion', () {
      final notifications =
          NotificationSchedulerService.generateEventNotifications(
        friDelta: 5,
        checkInCompleted: true,
        today: DateTime(2026, 3, 15),
      );

      final friNotifs = notifications
          .where((n) => n.category == NotificationCategory.friImprovement)
          .toList();

      expect(friNotifs.length, 1);
      expect(friNotifs.first.body, contains('+5'));
      expect(friNotifs.first.personalNumber, contains('+5'));
      expect(friNotifs.first.timeReference, contains('dernier check-in'));
      expect(friNotifs.first.tier, NotificationTier.event);
    });

    test('profile update notification', () {
      final notifications =
          NotificationSchedulerService.generateEventNotifications(
        profileUpdated: true,
        today: DateTime(2026, 3, 15),
      );

      final profileNotifs = notifications
          .where((n) => n.category == NotificationCategory.profileUpdate)
          .toList();

      expect(profileNotifs.length, 1);
      expect(profileNotifs.first.body, contains('mis à jour'));
      expect(profileNotifs.first.deeplink, '/retraite');
    });

    test('FRI improvement without check-in context', () {
      final notifications =
          NotificationSchedulerService.generateEventNotifications(
        friDelta: 3,
        checkInCompleted: false,
        today: DateTime(2026, 3, 15),
      );

      final friNotifs = notifications
          .where((n) => n.category == NotificationCategory.friImprovement)
          .toList();

      expect(friNotifs.length, 1);
      expect(friNotifs.first.body, contains('progressé'));
      expect(friNotifs.first.body, contains('3'));
      expect(friNotifs.first.timeReference, contains('récemment'));
    });

    test('off-track plan notification when adherence < 80%', () {
      final planStatus = PlanStatus(
        score: 50,
        completedActions: 2,
        totalActions: 5,
        nextActions: ['Verser 3a', 'Racheter LPP'],
        averageMonthlyActual: 300,
        totalMonthlyPlanned: 600,
      );

      final notifications =
          NotificationSchedulerService.generateEventNotifications(
        planStatus: planStatus,
        today: DateTime(2026, 3, 15),
      );

      final offTrackNotifs = notifications
          .where((n) => n.category == NotificationCategory.offTrack)
          .toList();

      expect(offTrackNotifs.length, 1);
      expect(offTrackNotifs.first.body, contains('40%')); // 2/5 = 40%
      expect(offTrackNotifs.first.body, contains('5 actions'));
      expect(offTrackNotifs.first.deeplink, '/coach/checkin');
    });

    test('no notifications when no events', () {
      final notifications =
          NotificationSchedulerService.generateEventNotifications(
        friDelta: 0,
        profileUpdated: false,
        checkInCompleted: false,
        today: DateTime(2026, 3, 15),
      );

      expect(notifications, isEmpty);
    });

    test('FRI delta = 0 with check-in completed does not generate FRI notif',
        () {
      final notifications =
          NotificationSchedulerService.generateEventNotifications(
        friDelta: 0,
        checkInCompleted: true,
        today: DateTime(2026, 3, 15),
      );

      final friNotifs = notifications
          .where((n) => n.category == NotificationCategory.friImprovement)
          .toList();

      expect(friNotifs, isEmpty);
    });

    test('negative FRI delta shows minus sign', () {
      final notifications =
          NotificationSchedulerService.generateEventNotifications(
        friDelta: -3,
        checkInCompleted: true,
        today: DateTime(2026, 3, 15),
      );

      final friNotifs = notifications
          .where((n) => n.category == NotificationCategory.friImprovement)
          .toList();

      expect(friNotifs.length, 1);
      expect(friNotifs.first.body, contains('-3'));
      expect(friNotifs.first.personalNumber, contains('-3'));
    });

    test('all event notifications are tier event', () {
      final notifications =
          NotificationSchedulerService.generateEventNotifications(
        friDelta: 5,
        profileUpdated: true,
        checkInCompleted: true,
        today: DateTime(2026, 3, 15),
      );

      for (final n in notifications) {
        expect(n.tier, NotificationTier.event);
      }
    });

    test('off-track not triggered when adherence >= 80%', () {
      final planStatus = PlanStatus(
        score: 85,
        completedActions: 4,
        totalActions: 5,
        nextActions: ['Verser 3a'],
        averageMonthlyActual: 550,
        totalMonthlyPlanned: 600,
      );

      final notifications =
          NotificationSchedulerService.generateEventNotifications(
        planStatus: planStatus,
        today: DateTime(2026, 3, 15),
      );

      final offTrackNotifs = notifications
          .where((n) => n.category == NotificationCategory.offTrack)
          .toList();

      expect(offTrackNotifs, isEmpty);
    });

    test('off-track not triggered when totalActions = 0', () {
      final planStatus = const PlanStatus(
        score: 0,
        completedActions: 0,
        totalActions: 0,
        nextActions: [],
      );

      final notifications =
          NotificationSchedulerService.generateEventNotifications(
        planStatus: planStatus,
        today: DateTime(2026, 3, 15),
      );

      final offTrackNotifs = notifications
          .where((n) => n.category == NotificationCategory.offTrack)
          .toList();

      expect(offTrackNotifs, isEmpty);
    });

    test('multiple events can fire simultaneously', () {
      final planStatus = PlanStatus(
        score: 30,
        completedActions: 1,
        totalActions: 5,
        nextActions: ['Verser 3a'],
        averageMonthlyActual: 100,
        totalMonthlyPlanned: 600,
      );

      final notifications =
          NotificationSchedulerService.generateEventNotifications(
        friDelta: 5,
        profileUpdated: true,
        checkInCompleted: true,
        planStatus: planStatus,
        today: DateTime(2026, 3, 15),
      );

      // Should have: FRI improvement, profile update, off-track
      expect(notifications.length, greaterThanOrEqualTo(3));
      final categories = notifications.map((n) => n.category).toSet();
      expect(categories, contains(NotificationCategory.friImprovement));
      expect(categories, contains(NotificationCategory.profileUpdate));
      expect(categories, contains(NotificationCategory.offTrack));
    });
  });

  // ── Compliance checks ─────────────────────────────────────────

  group('Notification compliance', () {
    test('no banned terms in any notification body', () {
      final calendarNotifs =
          NotificationSchedulerService.generateCalendarNotifications(
        taxSaving3a: 1820,
        today: DateTime(2026, 1, 1, 8, 0),
      );

      final eventNotifs =
          NotificationSchedulerService.generateEventNotifications(
        friDelta: 5,
        profileUpdated: true,
        checkInCompleted: true,
        today: DateTime(2026, 3, 15),
      );

      final allNotifs = [...calendarNotifs, ...eventNotifs];
      for (final n in allNotifs) {
        final lower = n.body.toLowerCase();
        expect(lower.contains('garanti'), false,
            reason: 'Body should not contain "garanti"');
        expect(lower.contains('sans risque'), false,
            reason: 'Body should not contain "sans risque"');
        expect(lower.contains('certain'), false,
            reason: 'Body should not contain "certain"');
      }
    });

    test('no social comparison in any notification', () {
      final calendarNotifs =
          NotificationSchedulerService.generateCalendarNotifications(
        taxSaving3a: 1820,
        today: DateTime(2026, 1, 1, 8, 0),
      );

      for (final n in calendarNotifs) {
        final lower = n.body.toLowerCase();
        expect(lower.contains('top'), false,
            reason: 'Body should not contain social comparison (top X%)');
        expect(lower.contains('moyenne'), false,
            reason: 'Body should not contain social comparison (moyenne)');
      }
    });
  });
}
