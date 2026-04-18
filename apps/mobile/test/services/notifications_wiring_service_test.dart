/// Tests for [NotificationsWiringService] — Wave A-MINIMAL A2.
///
/// Contract:
/// - Incomplete triad → no schedule fired
/// - Complete triad for the first time → schedule fired after debounce
/// - Same triad seen twice → schedule fired only once (dedup on signature)
/// - Triad field changes → schedule re-fires
/// - Rapid bursts of changes (save_fact cascade) collapse via debounce
///
/// Panel adversaire BUG 2+3 (2026-04-18): save_fact flow NEVER re-fires
/// `scheduleCoachingReminders` without this service, because
/// `CoachProfileProvider.notifyListeners()` is not a lifecycle event.
///
/// Refs:
/// - .planning/wave-a-notifs-wiring/PLAN.md A2
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/notifications_wiring_service.dart';

/// Recorder that replaces the real scheduling callback — no contact
/// with `flutter_local_notifications` or the NotificationService
/// singleton. Matches the override signature accepted by
/// [NotificationsWiringService.new].
class _Recorder {
  final List<CoachProfile> scheduled = [];
  Future<void> call(CoachProfile profile) async {
    scheduled.add(profile);
  }
}

CoachProfile _profile({
  int birthYear = 0,
  String canton = '',
  double salaire = 0,
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: canton,
    salaireBrutMensuel: salaire,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2040),
      label: '',
    ),
  );
}

void main() {
  setUp(() {
    // Short debounce so tests are fast.
    NotificationsWiringService.debounce = const Duration(milliseconds: 10);
  });

  tearDown(() {
    NotificationsWiringService.debounce =
        const Duration(milliseconds: 500);
  });

  group('NotificationsWiringService — triad gate + debounce', () {
    test('incomplete triad → no schedule fired', () async {
      final rec = _Recorder();
      final service = NotificationsWiringService(scheduleOverride: rec.call);

      service.onProfileChanged(_profile(birthYear: 1977));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(rec.scheduled, isEmpty);
      expect(service.lastScheduledSignature, isNull);
    });

    test('complete triad → schedule fired exactly once after debounce',
        () async {
      final rec = _Recorder();
      final service = NotificationsWiringService(scheduleOverride: rec.call);

      service.onProfileChanged(_profile(
        birthYear: 1977,
        canton: 'VS',
        salaire: 10000,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(rec.scheduled, hasLength(1));
      expect(service.lastScheduledSignature, equals('1977|VS|10000'));
    });

    test('same triad seen twice → schedule fires once (signature dedup)',
        () async {
      final rec = _Recorder();
      final service = NotificationsWiringService(scheduleOverride: rec.call);
      final p = _profile(birthYear: 1977, canton: 'VS', salaire: 10000);

      service.onProfileChanged(p);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      service.onProfileChanged(p);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(rec.scheduled, hasLength(1));
    });

    test('triad field change → schedule re-fires', () async {
      final rec = _Recorder();
      final service = NotificationsWiringService(scheduleOverride: rec.call);

      service.onProfileChanged(_profile(
        birthYear: 1977,
        canton: 'VS',
        salaire: 10000,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      service.onProfileChanged(_profile(
        birthYear: 1977,
        canton: 'VD', // changed
        salaire: 10000,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(rec.scheduled, hasLength(2));
    });

    test(
        'rapid burst of changes collapses to a single schedule via debounce',
        () async {
      final rec = _Recorder();
      final service = NotificationsWiringService(scheduleOverride: rec.call);

      // Simulate save_fact cascade: 5 rapid changes within the debounce window.
      for (var i = 0; i < 5; i++) {
        service.onProfileChanged(_profile(
          birthYear: 1977,
          canton: 'VS',
          // vary salary slightly but same bucket rounding
          salaire: 10000 + i.toDouble(),
        ));
      }
      // Wait for the debounce to fire.
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(rec.scheduled, hasLength(1),
          reason: 'Debounce must collapse rapid bursts');
    });

    test('triad goes complete → incomplete → complete re-schedules', () async {
      final rec = _Recorder();
      final service = NotificationsWiringService(scheduleOverride: rec.call);

      service.onProfileChanged(_profile(
        birthYear: 1977,
        canton: 'VS',
        salaire: 10000,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(rec.scheduled, hasLength(1));

      // Simulate a logout/reset — profile becomes incomplete.
      service.onProfileChanged(_profile());
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(rec.scheduled, hasLength(1));
      expect(service.lastScheduledSignature, isNull);

      // Log back in with the SAME triad — must re-schedule, not dedup.
      service.onProfileChanged(_profile(
        birthYear: 1977,
        canton: 'VS',
        salaire: 10000,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(rec.scheduled, hasLength(2));
    });

    test('null profile is ignored silently', () async {
      final rec = _Recorder();
      final service = NotificationsWiringService(scheduleOverride: rec.call);

      service.onProfileChanged(null);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(rec.scheduled, isEmpty);
    });
  });
}
