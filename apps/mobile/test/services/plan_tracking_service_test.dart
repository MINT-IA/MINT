import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/plan_tracking_service.dart';

CoachProfile _profileWith({
  required List<PlannedMonthlyContribution> planned,
  required List<MonthlyCheckIn> checkIns,
}) {
  return CoachProfile(
    birthYear: 1976,
    canton: 'ZH',
    salaireBrutMensuel: 8000,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2041, 1, 1),
      label: 'Retraite',
    ),
    plannedContributions: planned,
    checkIns: checkIns,
  );
}

void main() {
  group('PlanTrackingService.evaluate', () {
    test('returns hasPlan=false when no planned contributions', () {
      final profile = _profileWith(planned: const [], checkIns: const []);

      final status = PlanTrackingService.evaluate(
        profile: profile,
        today: DateTime(2026, 10, 15),
      );

      expect(status.hasPlan, isFalse);
      expect(status.monthsAnalyzed, 0);
      expect(status.isOffTrack, isFalse);
    });

    test('detects on-track when actual equals plan', () {
      const planned = [
        PlannedMonthlyContribution(
          id: '3a_julien',
          label: '3a Julien',
          amount: 600,
          category: '3a',
        ),
      ];
      final checkIns = [
        for (final month in [10, 9, 8])
          MonthlyCheckIn(
            month: DateTime(2026, month, 1),
            versements: const {'3a_julien': 600},
            completedAt: DateTime(2026, month, 5),
          ),
      ];
      final profile = _profileWith(planned: planned, checkIns: checkIns);

      final status = PlanTrackingService.evaluate(
        profile: profile,
        today: DateTime(2026, 10, 15),
      );

      expect(status.hasPlan, isTrue);
      expect(status.adherenceRate, 100);
      expect(status.monthsBehind, 0);
      expect(status.isOffTrack, isFalse);
    });

    test('detects off-track when adherence below threshold for 2+ months', () {
      const planned = [
        PlannedMonthlyContribution(
          id: '3a_julien',
          label: '3a Julien',
          amount: 600,
          category: '3a',
        ),
      ];
      final checkIns = [
        MonthlyCheckIn(
          month: DateTime(2026, 10, 1),
          versements: const {'3a_julien': 200},
          completedAt: DateTime(2026, 10, 5),
        ),
        MonthlyCheckIn(
          month: DateTime(2026, 9, 1),
          versements: const {'3a_julien': 100},
          completedAt: DateTime(2026, 9, 5),
        ),
        MonthlyCheckIn(
          month: DateTime(2026, 8, 1),
          versements: const {'3a_julien': 600},
          completedAt: DateTime(2026, 8, 5),
        ),
      ];
      final profile = _profileWith(planned: planned, checkIns: checkIns);

      final status = PlanTrackingService.evaluate(
        profile: profile,
        today: DateTime(2026, 10, 15),
      );

      expect(status.adherenceRate, lessThan(70));
      expect(status.monthsBehind, greaterThanOrEqualTo(2));
      expect(status.isOffTrack, isTrue);
    });

    test('projects positive impact when monthly gap persists', () {
      const planned = [
        PlannedMonthlyContribution(
          id: '3a_julien',
          label: '3a Julien',
          amount: 600,
          category: '3a',
        ),
      ];
      final checkIns = [
        for (final month in [10, 9, 8])
          MonthlyCheckIn(
            month: DateTime(2026, month, 1),
            versements: const {'3a_julien': 100},
            completedAt: DateTime(2026, month, 5),
          ),
      ];
      final profile = _profileWith(planned: planned, checkIns: checkIns);

      final status = PlanTrackingService.evaluate(
        profile: profile,
        today: DateTime(2026, 10, 15),
      );

      expect(status.projectedImpactChf, greaterThan(0));
      expect(status.topGaps, isNotEmpty);
      expect(status.topGaps.first.gapMonthly, greaterThan(0));
    });
  });
}
