// Phase 91 Plan 91-02 (VIVANT-03) — DismissedNudgesStore tests.
//
// The store delegates to NudgePersistence, so the tests assert the
// observable contract from the chat-screen perspective:
//   - default empty: nothing dismissed
//   - dismiss(nudge) → isDismissed(id) == true within cooldown window
//   - past the trigger's cooldown → isDismissed(id) == false (auto-purged)
//   - multiple dismissals tracked independently
//   - id of a different month/trigger is not falsely flagged
//
// Cooldown days are owned by NudgePersistence (per-trigger). For the
// 7-day-style triggers the plan calls out (taxDeadlineApproach,
// pillar3aDeadline, goalProgress) we use 8 days as the « past cooldown »
// boundary.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/services/nudge/nudge_engine.dart';
import 'package:mint_mobile/services/nudge/nudge_trigger.dart';
import 'package:mint_mobile/services/preferences/dismissed_nudges_store.dart';

Nudge _fakeTaxNudge({DateTime? expires}) {
  // Mirror NudgeEngine._id format: `{trigger}_{yyyyMM}`.
  final now = DateTime(2026, 3, 15);
  final id =
      '${NudgeTrigger.taxDeadlineApproach.name}_${now.year}${now.month.toString().padLeft(2, '0')}';
  return Nudge(
    id: id,
    trigger: NudgeTrigger.taxDeadlineApproach,
    priority: NudgePriority.high,
    intentTag: '/fiscal',
    titleKey: 'nudgeTaxDeadlineTitle',
    bodyKey: 'nudgeTaxDeadlineBody',
    expiresAt: expires ?? DateTime(2026, 4, 1),
  );
}

Nudge _fakeSalaryNudge() {
  final now = DateTime(2026, 3, 3);
  final id =
      '${NudgeTrigger.salaryReceived.name}_${now.year}${now.month.toString().padLeft(2, '0')}';
  return Nudge(
    id: id,
    trigger: NudgeTrigger.salaryReceived,
    priority: NudgePriority.medium,
    intentTag: '/pilier-3a',
    titleKey: 'nudgeSalaryTitle',
    bodyKey: 'nudgeSalaryBody',
    expiresAt: DateTime(2026, 3, 6),
  );
}

void main() {
  group('DismissedNudgesStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('default state — nothing is dismissed', () async {
      const store = DismissedNudgesStore();
      final nudge = _fakeTaxNudge();
      final result = await store.isDismissed(nudge.id);
      expect(result, isFalse);
    });

    test('dismiss(nudge) → isDismissed(id) == true within cooldown',
        () async {
      const store = DismissedNudgesStore();
      final nudge = _fakeTaxNudge();
      final dismissedAt = DateTime(2026, 3, 15, 12, 0, 0);

      await store.dismiss(nudge, now: dismissedAt);
      // 1 day later — well inside the 7-day taxDeadline cooldown.
      final inWindow = await store.isDismissed(
        nudge.id,
        now: dismissedAt.add(const Duration(days: 1)),
      );
      expect(inWindow, isTrue);
    });

    test(
        'dismiss + 8 days later → isDismissed returns false (cooldown expired)',
        () async {
      const store = DismissedNudgesStore();
      final nudge = _fakeTaxNudge();
      final dismissedAt = DateTime(2026, 3, 15, 12, 0, 0);

      await store.dismiss(nudge, now: dismissedAt);
      // 8 days later — past the 7-day taxDeadline cooldown window.
      final pastWindow = await store.isDismissed(
        nudge.id,
        now: dismissedAt.add(const Duration(days: 8)),
      );
      expect(pastWindow, isFalse);
    });

    test('different trigger ids are tracked independently', () async {
      const store = DismissedNudgesStore();
      final tax = _fakeTaxNudge();
      final salary = _fakeSalaryNudge();
      final now = DateTime(2026, 3, 15, 9, 0, 0);

      await store.dismiss(tax, now: now);
      // Salary nudge was never dismissed — must read as not-dismissed
      // even though tax is currently in cooldown.
      final taxDismissed = await store.isDismissed(tax.id, now: now);
      final salaryDismissed = await store.isDismissed(salary.id, now: now);
      expect(taxDismissed, isTrue);
      expect(salaryDismissed, isFalse);
    });

    test('mix of expired + active dismissals returns the right ids',
        () async {
      const store = DismissedNudgesStore();
      final tax = _fakeTaxNudge();
      final salary = _fakeSalaryNudge();

      // Tax dismissed 10 days ago — expired (taxDeadline cooldown = 7d).
      // Salary dismissed today — active (salaryReceived cooldown = 25d).
      final taxAt = DateTime(2026, 3, 5);
      final salaryAt = DateTime(2026, 3, 15);
      await store.dismiss(tax, now: taxAt);
      await store.dismiss(salary, now: salaryAt);

      final readNow = DateTime(2026, 3, 15, 12, 0, 0);
      final taxState = await store.isDismissed(tax.id, now: readNow);
      final salaryState = await store.isDismissed(salary.id, now: readNow);

      expect(taxState, isFalse, reason: 'tax cooldown should have expired');
      expect(salaryState, isTrue, reason: 'salary cooldown still active');
    });

    test('isDismissed(unknown id) → false', () async {
      const store = DismissedNudgesStore();
      final result = await store.isDismissed('does_not_exist_999999');
      expect(result, isFalse);
    });
  });
}
