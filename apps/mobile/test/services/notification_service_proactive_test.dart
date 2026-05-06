/// Phase 91 Plan 91-04 (VIVANT-01) — proactive push notification tests.
///
/// Scope :
///   - [ProactiveNotificationCopy.titleAndBodyFor] returns non-null copy
///     for the 6 wired trigger types and null for the 2 deferred types.
///   - [ProactiveNotificationCopy.applyQuietHoursAndWeekend] enforces
///     22:00-08:00 quiet window AND weekend dampening (with the
///     `confidenceImproved` positive-only bypass).
///   - Deep-link payload shape (`/coach/chat?topic=...&prefill=...`) is
///     produced via the same idiom as the rest of the notification
///     service (Uri.encodeQueryComponent).
///
/// Out of scope (deferred to manual `idb` device gate per CONTEXT.md
/// `<specifics>` test (a)) :
///   - Actual platform delivery via `flutter_local_notifications`
///     (no platform channel in unit-test isolate).
///   - iOS notification banner capture (Maestro can't see system UI ;
///     handled by manual `idb` step in plan).
library;

import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/coach/proactive_notification_copy.dart';
import 'package:mint_mobile/services/coach/proactive_trigger_service.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  // S (AppLocalizations) is generated from ARB ; in unit tests we
  // resolve French (the default locale per MintLocales.supportedLocales).
  late S strings;

  setUpAll(() async {
    strings = await S.delegate.load(const Locale('fr'));
  });

  group('ProactiveNotificationCopy.titleAndBodyFor — 6 wired types', () {
    test('lifecyclePhaseChange → non-null copy with title + body + prefill',
        () {
      final copy = ProactiveNotificationCopy.titleAndBodyFor(
        ProactiveTriggerType.lifecyclePhaseChange,
        strings,
      );
      expect(copy, isNotNull);
      expect(copy!.title, isNotEmpty);
      expect(copy.body, isNotEmpty);
      expect(copy.prefill, isNotEmpty);
    });

    test('confidenceImproved → interpolates {delta} param', () {
      final copy = ProactiveNotificationCopy.titleAndBodyFor(
        ProactiveTriggerType.confidenceImproved,
        strings,
        params: {'delta': '7'},
      );
      expect(copy, isNotNull);
      expect(copy!.body, contains('7'));
    });

    test('seasonalReminder → interpolates {event} param', () {
      final copy = ProactiveNotificationCopy.titleAndBodyFor(
        ProactiveTriggerType.seasonalReminder,
        strings,
        params: {'event': 'déclaration fiscale'},
      );
      expect(copy, isNotNull);
      expect(copy!.body, contains('déclaration'));
    });

    test('inactivityReturn → interpolates {days} param', () {
      final copy = ProactiveNotificationCopy.titleAndBodyFor(
        ProactiveTriggerType.inactivityReturn,
        strings,
        params: {'days': '14'},
      );
      expect(copy, isNotNull);
      expect(copy!.body, contains('14'));
    });

    test('newCapAvailable → no params required, body still non-empty', () {
      final copy = ProactiveNotificationCopy.titleAndBodyFor(
        ProactiveTriggerType.newCapAvailable,
        strings,
      );
      expect(copy, isNotNull);
      expect(copy!.body.length, greaterThan(5));
    });

    test('contractDeadlineApproaching → interpolates {label} + {days}', () {
      final copy = ProactiveNotificationCopy.titleAndBodyFor(
        ProactiveTriggerType.contractDeadlineApproaching,
        strings,
        params: {'label': 'bail', 'days': '21'},
      );
      expect(copy, isNotNull);
      expect(copy!.body, contains('bail'));
      expect(copy.body, contains('21'));
    });
  });

  group('ProactiveNotificationCopy.titleAndBodyFor — 2 deferred types', () {
    test('weeklyRecapAvailable → null (deleted in Phase 2b)', () {
      final copy = ProactiveNotificationCopy.titleAndBodyFor(
        ProactiveTriggerType.weeklyRecapAvailable,
        strings,
      );
      expect(copy, isNull,
          reason: 'weeklyRecap façade deleted, must not schedule push');
    });

    test('goalMilestone → null (depends on GoalTrackerService reactivation)',
        () {
      final copy = ProactiveNotificationCopy.titleAndBodyFor(
        ProactiveTriggerType.goalMilestone,
        strings,
      );
      expect(copy, isNull,
          reason: 'goalMilestone deferred until GoalTrackerService reactivates');
    });
  });

  group('ProactiveNotificationCopy.applyQuietHoursAndWeekend', () {
    test('22:00 (Wednesday) → forwarded to next day 09:00', () {
      // Wed 2026-05-06 22:30 → Thu 2026-05-07 09:00.
      final requested = DateTime(2026, 5, 6, 22, 30);
      final dampened = ProactiveNotificationCopy.applyQuietHoursAndWeekend(
        requested,
        ProactiveTriggerType.lifecyclePhaseChange,
      );
      expect(dampened.day, equals(7));
      expect(dampened.hour, equals(kReleaseHour));
    });

    test('07:00 (early-morning quiet) → forwarded to same day 09:00', () {
      // Tue 2026-05-05 07:00 → Tue 2026-05-05 09:00.
      final requested = DateTime(2026, 5, 5, 7, 0);
      final dampened = ProactiveNotificationCopy.applyQuietHoursAndWeekend(
        requested,
        ProactiveTriggerType.inactivityReturn,
      );
      expect(dampened.day, equals(5));
      expect(dampened.hour, equals(kReleaseHour));
    });

    test('Saturday 10:00 + non-confidenceImproved → forwarded to Monday 09:00',
        () {
      // Sat 2026-05-09 10:00 → Mon 2026-05-11 09:00.
      final requested = DateTime(2026, 5, 9, 10, 0);
      expect(requested.weekday, equals(DateTime.saturday));
      final dampened = ProactiveNotificationCopy.applyQuietHoursAndWeekend(
        requested,
        ProactiveTriggerType.lifecyclePhaseChange,
      );
      expect(dampened.weekday, equals(DateTime.monday));
      expect(dampened.hour, equals(kReleaseHour));
    });

    test('Saturday 10:00 + confidenceImproved → NOT shifted (positive bypass)',
        () {
      // Sat 2026-05-09 10:00 → unchanged (positive-only trigger fires
      // on weekends to avoid users waiting 2 days for good news).
      final requested = DateTime(2026, 5, 9, 10, 0);
      final dampened = ProactiveNotificationCopy.applyQuietHoursAndWeekend(
        requested,
        ProactiveTriggerType.confidenceImproved,
      );
      expect(dampened, equals(requested),
          reason: 'confidenceImproved bypasses weekend dampening');
    });

    test('Friday 23:00 + non-confidenceImproved → forwarded to Monday 09:00',
        () {
      // Fri 2026-05-08 23:00 → quiet hours push to Sat 09:00 → weekend
      // dampening pushes to Mon 09:00.
      final requested = DateTime(2026, 5, 8, 23, 0);
      expect(requested.weekday, equals(DateTime.friday));
      final dampened = ProactiveNotificationCopy.applyQuietHoursAndWeekend(
        requested,
        ProactiveTriggerType.contractDeadlineApproaching,
      );
      expect(dampened.weekday, equals(DateTime.monday));
      expect(dampened.hour, equals(kReleaseHour));
    });

    test('Daytime weekday 14:00 → unchanged (no dampening fires)', () {
      // Tue 2026-05-05 14:00 → unchanged.
      final requested = DateTime(2026, 5, 5, 14, 0);
      final dampened = ProactiveNotificationCopy.applyQuietHoursAndWeekend(
        requested,
        ProactiveTriggerType.lifecyclePhaseChange,
      );
      expect(dampened, equals(requested));
    });
  });

  group('Deep-link payload contract', () {
    test('intent + prefill round-trip via Uri.encodeQueryComponent', () {
      // Mirrors the production payload-construction in
      // NotificationService.scheduleProactiveTriggerCheck.
      const trigger = ProactiveTriggerType.lifecyclePhaseChange;
      const prefill = 'Quels changements ma nouvelle phase de vie implique ?';
      final encoded = Uri.encodeQueryComponent(prefill);
      final payload = '/coach/chat?topic=${trigger.name}&prefill=$encoded';

      // Parse back via Uri (same as GoRouter does internally).
      final uri = Uri.parse(payload);
      expect(uri.path, equals('/coach/chat'));
      expect(uri.queryParameters['topic'], equals('lifecyclePhaseChange'));
      expect(uri.queryParameters['prefill'], equals(prefill));
    });

    test('NBSP + accents in prefill survive encode/decode round-trip', () {
      // Quiet hours + weekend test ensures we don't corrupt the « ? »
      // before NBSP that appears in many FR opener strings.
      const prefill = 'Sur quoi j’ai progressé ?';
      final encoded = Uri.encodeQueryComponent(prefill);
      final decoded = Uri.decodeQueryComponent(encoded);
      expect(decoded, equals(prefill));
    });
  });
}
