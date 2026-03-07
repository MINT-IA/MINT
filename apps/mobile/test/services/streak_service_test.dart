import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/streak_service.dart';

/// Helper: build a minimal CoachProfile with given check-in months.
///
/// [months] is a list of DateTime representing the first day of each
/// check-in month (e.g. DateTime(2026, 1) for January 2026).
CoachProfile _profileWithCheckIns(List<DateTime> months) {
  final checkIns = months
      .map((m) => MonthlyCheckIn(
            month: m,
            versements: const {'3a': 604.83},
            completedAt: m,
          ))
      .toList();

  return CoachProfile(
    birthYear: 1990,
    canton: 'VD',
    salaireBrutMensuel: 7000,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2055, 12, 31),
      label: 'Retraite',
    ),
    checkIns: checkIns,
  );
}

/// Helper: build consecutive months ending at the current month.
List<DateTime> _consecutiveMonthsEndingNow(int count) {
  final now = DateTime.now();
  return List.generate(
    count,
    (i) => DateTime(now.year, now.month - (count - 1 - i)),
  );
}


void main() {
  // =========================================================================
  // STREAK SERVICE — Unit tests
  // =========================================================================
  //
  // Tests the check-in streak computation and milestone badges:
  //   - StreakService.compute: current streak, longest streak, badges
  //   - StreakService.computeMilestones: financial milestones
  //   - Edge cases: empty check-ins, gaps, single check-in
  //   - Badge progression logic
  //
  // All logic is pure and deterministic (no network calls).
  // =========================================================================

  group('StreakService.compute - empty profile', () {
    test('no check-ins returns zero streak', () {
      final profile = _profileWithCheckIns([]);
      final result = StreakService.compute(profile);

      expect(result.currentStreak, 0);
      expect(result.longestStreak, 0);
      expect(result.totalCheckIns, 0);
      expect(result.earnedBadges, isEmpty);
    });

    test('no check-ins sets nextBadge to Premier pas', () {
      final profile = _profileWithCheckIns([]);
      final result = StreakService.compute(profile);

      expect(result.nextBadge, isNotNull);
      expect(result.nextBadge!.id, 'first_step');
      expect(result.nextBadge!.label, 'Premier pas');
      expect(result.monthsToNextBadge, 1);
    });
  });

  group('StreakService.compute - single check-in', () {
    test('one check-in this month gives streak of 1', () {
      final now = DateTime.now();
      final profile = _profileWithCheckIns([DateTime(now.year, now.month)]);
      final result = StreakService.compute(profile);

      expect(result.currentStreak, 1);
      expect(result.longestStreak, 1);
      expect(result.totalCheckIns, 1);
    });

    test('one check-in last month gives streak of 1', () {
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1);
      final profile = _profileWithCheckIns([lastMonth]);
      final result = StreakService.compute(profile);

      expect(result.currentStreak, 1);
      expect(result.longestStreak, 1);
      expect(result.totalCheckIns, 1);
    });

    test('one check-in earns Premier pas badge', () {
      final months = _consecutiveMonthsEndingNow(1);
      final profile = _profileWithCheckIns(months);
      final result = StreakService.compute(profile);

      expect(result.earnedBadges.length, 1);
      expect(result.earnedBadges.first.id, 'first_step');
    });
  });

  group('StreakService.compute - consecutive months', () {
    test('3 consecutive months earns Regulier badge', () {
      final months = _consecutiveMonthsEndingNow(3);
      final profile = _profileWithCheckIns(months);
      final result = StreakService.compute(profile);

      expect(result.currentStreak, 3);
      expect(result.longestStreak, 3);
      final badgeIds = result.earnedBadges.map((b) => b.id).toList();
      expect(badgeIds, contains('first_step'));
      expect(badgeIds, contains('regulier'));
    });

    test('6 consecutive months earns Constant badge', () {
      final months = _consecutiveMonthsEndingNow(6);
      final profile = _profileWithCheckIns(months);
      final result = StreakService.compute(profile);

      expect(result.currentStreak, 6);
      expect(result.longestStreak, 6);
      final badgeIds = result.earnedBadges.map((b) => b.id).toList();
      expect(badgeIds, contains('constant'));
    });

    test('12 consecutive months earns Discipline badge', () {
      final months = _consecutiveMonthsEndingNow(12);
      final profile = _profileWithCheckIns(months);
      final result = StreakService.compute(profile);

      expect(result.currentStreak, 12);
      expect(result.longestStreak, 12);
      final badgeIds = result.earnedBadges.map((b) => b.id).toList();
      expect(badgeIds, contains('discipline'));
      // All 4 badges should be earned
      expect(result.earnedBadges.length, 4);
    });
  });

  group('StreakService.compute - gap resets current streak', () {
    test('old check-in (3 months ago) resets current streak', () {
      final now = DateTime.now();
      // Check-in from 3 months ago only — not recent enough
      final profile = _profileWithCheckIns([
        DateTime(now.year, now.month - 3),
      ]);
      final result = StreakService.compute(profile);

      expect(result.currentStreak, 0);
      expect(result.longestStreak, 1);
      expect(result.totalCheckIns, 1);
    });

    test('gap in the middle breaks current streak but not longest', () {
      final now = DateTime.now();
      // 3 consecutive months, then a gap, then 2 recent months
      final months = [
        DateTime(now.year, now.month - 8),
        DateTime(now.year, now.month - 7),
        DateTime(now.year, now.month - 6),
        // gap: month -5, -4, -3 missing
        DateTime(now.year, now.month - 1),
        DateTime(now.year, now.month),
      ];
      final profile = _profileWithCheckIns(months);
      final result = StreakService.compute(profile);

      expect(result.currentStreak, 2);
      expect(result.longestStreak, 3);
      expect(result.totalCheckIns, 5);
    });
  });

  group('StreakService.compute - nextBadge progression', () {
    test('after 1 month streak, next badge is Regulier (3 months)', () {
      final months = _consecutiveMonthsEndingNow(1);
      final profile = _profileWithCheckIns(months);
      final result = StreakService.compute(profile);

      expect(result.nextBadge, isNotNull);
      expect(result.nextBadge!.id, 'regulier');
      expect(result.monthsToNextBadge, 2);
    });

    test('after 3 month streak, next badge is Constant (6 months)', () {
      final months = _consecutiveMonthsEndingNow(3);
      final profile = _profileWithCheckIns(months);
      final result = StreakService.compute(profile);

      expect(result.nextBadge, isNotNull);
      expect(result.nextBadge!.id, 'constant');
      expect(result.monthsToNextBadge, 3);
    });

    test('after 12 month streak, no next badge', () {
      final months = _consecutiveMonthsEndingNow(12);
      final profile = _profileWithCheckIns(months);
      final result = StreakService.compute(profile);

      expect(result.nextBadge, isNull);
      expect(result.monthsToNextBadge, 0);
    });
  });

  group('StreakService.compute - badge labels en francais', () {
    test('all badge labels are in French', () {
      final months = _consecutiveMonthsEndingNow(12);
      final profile = _profileWithCheckIns(months);
      final result = StreakService.compute(profile);

      final labels = result.earnedBadges.map((b) => b.label).toList();
      expect(labels, contains('Premier pas'));
      expect(labels, containsAll([
        'Premier pas',
        'Constant\u00b7e',
      ]));
    });

    test('badge descriptions are in French', () {
      final months = _consecutiveMonthsEndingNow(12);
      final profile = _profileWithCheckIns(months);
      final result = StreakService.compute(profile);

      for (final badge in result.earnedBadges) {
        // All descriptions should be non-empty and contain French text
        expect(badge.description.isNotEmpty, true);
      }
      final descriptions = result.earnedBadges.map((b) => b.description).toList();
      expect(descriptions, contains('Tu as fait ton premier check-in.'));
    });
  });

  group('StreakService.computeMilestones', () {
    test('returns 6 milestones', () {
      final profile = _profileWithCheckIns([]);
      final milestones = StreakService.computeMilestones(profile);

      expect(milestones.length, 6);
    });

    test('patrimoine 50k milestone is reached with 50k+ patrimoine', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 7000,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055, 12, 31),
          label: 'Retraite',
        ),
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 30000,
          investissements: 25000,
        ),
      );
      final milestones = StreakService.computeMilestones(profile);
      final m50k = milestones.firstWhere((m) => m.id == 'patrimoine_50k');
      expect(m50k.isReached, true);
    });

    test('3a max milestone reached at 7258 CHF annual', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 7000,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055, 12, 31),
          label: 'Retraite',
        ),
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: '3a',
            label: '3a',
            amount: 604.84, // 604.84 * 12 = 7258.08 >= 7258
            category: '3a',
          ),
        ],
      );
      final milestones = StreakService.computeMilestones(profile);
      final m3a = milestones.firstWhere((m) => m.id == '3a_max');
      expect(m3a.isReached, true);
    });

    test('emergency fund 6 months milestone with sufficient liquid savings', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 7000,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055, 12, 31),
          label: 'Retraite',
        ),
        depenses: const DepensesProfile(
          loyer: 1500,
          assuranceMaladie: 400,
        ),
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 12000, // 1900*6 = 11400, 12000 >= 11400
        ),
      );
      final milestones = StreakService.computeMilestones(profile);
      final mEmergency = milestones.firstWhere((m) => m.id == 'emergency_fund');
      expect(mEmergency.isReached, true);
    });

    test('emergency fund not reached if monthly expenses are zero', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 7000,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055, 12, 31),
          label: 'Retraite',
        ),
        depenses: const DepensesProfile(), // all zeros
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 50000,
        ),
      );
      final milestones = StreakService.computeMilestones(profile);
      final mEmergency = milestones.firstWhere((m) => m.id == 'emergency_fund');
      // monthlyExpenses == 0, so condition monthlyExpenses > 0 is false
      expect(mEmergency.isReached, false);
    });

    test('milestone labels are in French', () {
      final profile = _profileWithCheckIns([]);
      final milestones = StreakService.computeMilestones(profile);

      final labels = milestones.map((m) => m.label).toList();
      expect(labels, contains('Premier jalon'));
      expect(labels, contains('3a au max'));
      expect(labels, contains('Matelas 6 mois'));
    });
  });
}
