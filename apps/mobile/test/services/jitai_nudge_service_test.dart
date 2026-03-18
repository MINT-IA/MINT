import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/coach/jitai_nudge_service.dart';
import 'package:mint_mobile/services/coach/goal_tracker_service.dart';

// ────────────────────────────────────────────────────────────
//  JITAI NUDGE SERVICE TESTS — S61
// ────────────────────────────────────────────────────────────
//
// 20 tests covering:
//   - Tax deadline trigger (before and after)
//   - 3a deadline trigger (December)
//   - Birthday milestone
//   - Salary day (25th)
//   - LPP bracket change
//   - Streak at risk (above and below threshold)
//   - Weekly check-in (7+ days no engagement)
//   - Goal deadline approaching (within and outside 30 days)
//   - FHS dropped detection
//   - Cooldown / dismiss logic
//   - Max 3 nudges cap
//   - Priority ordering
//   - No banned terms
//   - French accents
//   - Non-breaking space compliance
// ────────────────────────────────────────────────────────────

/// Minimal CoachProfile for testing.
CoachProfile _makeProfile({
  int birthYear = 1985,
  DateTime? createdAt,
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: 'VS',
    etatCivil: CoachCivilStatus.celibataire,
    nombreEnfants: 0,
    salaireBrutMensuel: 8000,
    nombreDeMois: 12,
    employmentStatus: 'salarie',
    depenses: const DepensesProfile(),
    prevoyance: const PrevoyanceProfile(),
    patrimoine: const PatrimoineProfile(),
    dettes: const DetteProfile(),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2042, 1, 1),
      label: 'Retraite',
    ),
    goalsB: const [],
    plannedContributions: const [],
    checkIns: const [],
    createdAt: createdAt ?? DateTime(2025, 3, 1),
    updatedAt: DateTime(2026, 3, 1),
  );
}

void main() {
  group('JitaiNudgeService', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    // ── Tax deadline ──────────────────────────────────────────

    test('tax deadline: March 15 → nudge triggered', () async {
      final now = DateTime(2026, 3, 15);
      final nudges = await JitaiNudgeService.evaluateNudges(
        profile: _makeProfile(),
        now: now,
        prefs: prefs,
      );

      final taxNudge = nudges.where((n) => n.type == NudgeType.taxDeadline);
      expect(taxNudge.isNotEmpty, isTrue,
          reason: 'Tax deadline nudge should fire in March');
      expect(taxNudge.first.priority, NudgePriority.high);
    });

    test('tax deadline: April 5 → no nudge', () async {
      final now = DateTime(2026, 4, 5);
      final nudges = await JitaiNudgeService.evaluateNudges(
        profile: _makeProfile(),
        now: now,
        prefs: prefs,
      );

      final taxNudge = nudges.where((n) => n.type == NudgeType.taxDeadline);
      expect(taxNudge.isEmpty, isTrue,
          reason: 'Tax deadline nudge should NOT fire after March');
    });

    // ── 3a deadline ───────────────────────────────────────────

    test('3a deadline: December 10 → nudge triggered', () async {
      final now = DateTime(2026, 12, 10);
      final nudges = await JitaiNudgeService.evaluateNudges(
        profile: _makeProfile(),
        now: now,
        prefs: prefs,
      );

      final threeA = nudges.where((n) => n.type == NudgeType.threeADeadline);
      expect(threeA.isNotEmpty, isTrue);
      expect(threeA.first.message, contains("7'258"));
      expect(threeA.first.priority, NudgePriority.high);
    });

    test('3a deadline: June 15 → no nudge', () async {
      final now = DateTime(2026, 6, 15);
      final nudges = await JitaiNudgeService.evaluateNudges(
        profile: _makeProfile(),
        now: now,
        prefs: prefs,
      );

      final threeA = nudges.where((n) => n.type == NudgeType.threeADeadline);
      expect(threeA.isEmpty, isTrue);
    });

    // ── Birthday milestone ────────────────────────────────────

    test('birthday: user turns 50 (Jan 3) → milestone nudge', () async {
      final now = DateTime(2035, 1, 3);
      final profile = _makeProfile(birthYear: 1985);
      final nudges = await JitaiNudgeService.evaluateNudges(
        profile: profile,
        now: now,
        prefs: prefs,
      );

      final birthday =
          nudges.where((n) => n.type == NudgeType.birthdayMilestone);
      expect(birthday.isNotEmpty, isTrue);
      expect(birthday.first.title, contains('50'));
    });

    test('birthday: user turns 42 (non-milestone) → no nudge', () async {
      final now = DateTime(2027, 1, 3);
      final profile = _makeProfile(birthYear: 1985);
      final nudges = await JitaiNudgeService.evaluateNudges(
        profile: profile,
        now: now,
        prefs: prefs,
      );

      final birthday =
          nudges.where((n) => n.type == NudgeType.birthdayMilestone);
      expect(birthday.isEmpty, isTrue);
    });

    // ── Salary day ────────────────────────────────────────────

    test('salary day: 25th of month → nudge', () async {
      final now = DateTime(2026, 5, 25);
      final nudges = await JitaiNudgeService.evaluateNudges(
        profile: _makeProfile(),
        now: now,
        prefs: prefs,
      );

      final salary = nudges.where((n) => n.type == NudgeType.salaryDay);
      expect(salary.isNotEmpty, isTrue);
      expect(salary.first.message, contains('3a'));
    });

    test('salary day: 15th of month → no nudge', () async {
      final now = DateTime(2026, 5, 15);
      final nudges = await JitaiNudgeService.evaluateNudges(
        profile: _makeProfile(),
        now: now,
        prefs: prefs,
      );

      final salary = nudges.where((n) => n.type == NudgeType.salaryDay);
      expect(salary.isEmpty, isTrue);
    });

    // ── LPP bracket change ────────────────────────────────────

    test('LPP bracket: user turns 35 (Jan 5) → bonification nudge', () async {
      final now = DateTime(2026, 1, 5);
      final profile = _makeProfile(birthYear: 1991); // 2026 - 1991 = 35
      final nudges = await JitaiNudgeService.evaluateNudges(
        profile: profile,
        now: now,
        prefs: prefs,
      );

      final lpp =
          nudges.where((n) => n.type == NudgeType.lppBonificationChange);
      expect(lpp.isNotEmpty, isTrue);
      expect(lpp.first.message, contains('10'));
    });

    test('LPP bracket: user turns 36 → no nudge', () async {
      final now = DateTime(2026, 1, 5);
      final profile = _makeProfile(birthYear: 1990); // 2026 - 1990 = 36
      final nudges = await JitaiNudgeService.evaluateNudges(
        profile: profile,
        now: now,
        prefs: prefs,
      );

      final lpp =
          nudges.where((n) => n.type == NudgeType.lppBonificationChange);
      expect(lpp.isEmpty, isTrue);
    });

    // ── Streak at risk ────────────────────────────────────────

    test('streak at risk: yesterday missed, streak > 3 → nudge', () async {
      final now = DateTime(2026, 5, 10);
      final nudges = await JitaiNudgeService.evaluateNudges(
        profile: _makeProfile(),
        now: now,
        prefs: prefs,
        currentStreak: 7,
        engagedYesterday: false,
      );

      final streak = nudges.where((n) => n.type == NudgeType.streakAtRisk);
      expect(streak.isNotEmpty, isTrue);
      expect(streak.first.priority, NudgePriority.high);
    });

    test('streak at risk: yesterday missed, streak = 1 → no nudge', () async {
      final now = DateTime(2026, 5, 10);
      final nudges = await JitaiNudgeService.evaluateNudges(
        profile: _makeProfile(),
        now: now,
        prefs: prefs,
        currentStreak: 1,
        engagedYesterday: false,
      );

      final streak = nudges.where((n) => n.type == NudgeType.streakAtRisk);
      expect(streak.isEmpty, isTrue);
    });

    test('streak at risk: engaged yesterday → no nudge', () async {
      final now = DateTime(2026, 5, 10);
      final nudges = await JitaiNudgeService.evaluateNudges(
        profile: _makeProfile(),
        now: now,
        prefs: prefs,
        currentStreak: 7,
        engagedYesterday: true,
      );

      final streak = nudges.where((n) => n.type == NudgeType.streakAtRisk);
      expect(streak.isEmpty, isTrue);
    });

    // ── Weekly check-in ───────────────────────────────────────

    test('weekly check-in: 7+ days no engagement → nudge', () async {
      // Empty prefs = no engagement dates at all
      final now = DateTime(2026, 5, 10);
      final nudges = await JitaiNudgeService.evaluateNudges(
        profile: _makeProfile(),
        now: now,
        prefs: prefs,
      );

      final weekly = nudges.where((n) => n.type == NudgeType.weeklyCheckIn);
      expect(weekly.isNotEmpty, isTrue);
    });

    test('weekly check-in: engaged 2 days ago → no nudge', () async {
      // Simulate engagement 2 days ago
      final now = DateTime(2026, 5, 10);
      final twoDaysAgo = now.subtract(const Duration(days: 2));
      final key =
          '${twoDaysAgo.year}-${twoDaysAgo.month.toString().padLeft(2, '0')}-${twoDaysAgo.day.toString().padLeft(2, '0')}';
      await prefs.setStringList('_daily_engagement_dates', [key]);

      final nudges = await JitaiNudgeService.evaluateNudges(
        profile: _makeProfile(),
        now: now,
        prefs: prefs,
      );

      final weekly = nudges.where((n) => n.type == NudgeType.weeklyCheckIn);
      expect(weekly.isEmpty, isTrue);
    });

    // ── Goal deadline ─────────────────────────────────────────

    test('goal deadline: 20 days left → nudge', () async {
      final now = DateTime(2026, 5, 10);
      final goals = [
        UserGoal(
          id: 'g1',
          description: 'Maximiser mon 3a',
          category: '3a',
          createdAt: DateTime(2026, 1, 1),
          targetDate: DateTime(2026, 5, 30), // 20 days left
        ),
      ];

      final nudges = await JitaiNudgeService.evaluateNudges(
        profile: _makeProfile(),
        now: now,
        prefs: prefs,
        goals: goals,
      );

      final goalNudge =
          nudges.where((n) => n.type == NudgeType.goalDeadlineApproaching);
      expect(goalNudge.isNotEmpty, isTrue);
      expect(goalNudge.first.message, contains('20'));
    });

    test('goal deadline: 40 days left → no nudge', () async {
      final now = DateTime(2026, 5, 10);
      final goals = [
        UserGoal(
          id: 'g1',
          description: 'Maximiser mon 3a',
          category: '3a',
          createdAt: DateTime(2026, 1, 1),
          targetDate: DateTime(2026, 6, 20), // 41 days left
        ),
      ];

      final nudges = await JitaiNudgeService.evaluateNudges(
        profile: _makeProfile(),
        now: now,
        prefs: prefs,
        goals: goals,
      );

      final goalNudge =
          nudges.where((n) => n.type == NudgeType.goalDeadlineApproaching);
      expect(goalNudge.isEmpty, isTrue);
    });

    // ── FHS dropped ───────────────────────────────────────────

    test('FHS dropped > 5 points → nudge', () async {
      await prefs.setDouble('_jitai_last_fhs', 75.0);
      final now = DateTime(2026, 5, 10);
      final nudges = await JitaiNudgeService.evaluateNudges(
        profile: _makeProfile(),
        now: now,
        prefs: prefs,
        fhsScore: 68.0, // dropped 7 points
      );

      final fhs = nudges.where((n) => n.type == NudgeType.fhsDropped);
      expect(fhs.isNotEmpty, isTrue);
      expect(fhs.first.message, contains('7'));
    });

    test('FHS dropped < 5 points → no nudge', () async {
      await prefs.setDouble('_jitai_last_fhs', 75.0);
      final now = DateTime(2026, 5, 10);
      final nudges = await JitaiNudgeService.evaluateNudges(
        profile: _makeProfile(),
        now: now,
        prefs: prefs,
        fhsScore: 72.0, // only 3 points
      );

      final fhs = nudges.where((n) => n.type == NudgeType.fhsDropped);
      expect(fhs.isEmpty, isTrue);
    });

    // ── Cooldown / dismiss ────────────────────────────────────

    test('cooldown: dismissed nudge → not re-triggered within cooldown',
        () async {
      final now = DateTime(2026, 3, 15);

      // Dismiss taxDeadline
      await JitaiNudgeService.dismissNudge(
        type: NudgeType.taxDeadline,
        prefs: prefs,
        now: now,
      );

      // Same day → should be filtered
      final nudges = await JitaiNudgeService.evaluateNudges(
        profile: _makeProfile(),
        now: now,
        prefs: prefs,
      );

      final tax = nudges.where((n) => n.type == NudgeType.taxDeadline);
      expect(tax.isEmpty, isTrue,
          reason: 'Dismissed nudge should not reappear during cooldown');
    });

    test('cooldown expired → nudge re-triggered', () async {
      final dismissDate = DateTime(2026, 3, 1);
      await JitaiNudgeService.dismissNudge(
        type: NudgeType.taxDeadline,
        prefs: prefs,
        now: dismissDate,
      );

      // 10 days later (cooldown is 7 days for taxDeadline)
      final later = DateTime(2026, 3, 11);
      final nudges = await JitaiNudgeService.evaluateNudges(
        profile: _makeProfile(),
        now: later,
        prefs: prefs,
      );

      final tax = nudges.where((n) => n.type == NudgeType.taxDeadline);
      expect(tax.isNotEmpty, isTrue,
          reason: 'Nudge should reappear after cooldown expires');
    });

    // ── Max 3 nudges ──────────────────────────────────────────

    test('max 3 nudges returned', () async {
      // Dec 25 triggers: salaryDay, threeADeadline, weeklyCheckIn (no engagement)
      // Also streakAtRisk if we pass it
      final now = DateTime(2026, 12, 25);
      await prefs.setDouble('_jitai_last_fhs', 80.0);

      final nudges = await JitaiNudgeService.evaluateNudges(
        profile: _makeProfile(),
        now: now,
        prefs: prefs,
        currentStreak: 10,
        engagedYesterday: false,
        fhsScore: 70.0, // dropped 10 points
      );

      expect(nudges.length, lessThanOrEqualTo(3));
    });

    // ── Priority ordering ─────────────────────────────────────

    test('priority ordering: high before medium before low', () async {
      // March 25: taxDeadline (high) + salaryDay (medium) + weeklyCheckIn (medium)
      final now = DateTime(2026, 3, 25);
      final nudges = await JitaiNudgeService.evaluateNudges(
        profile: _makeProfile(),
        now: now,
        prefs: prefs,
      );

      if (nudges.length >= 2) {
        for (int i = 0; i < nudges.length - 1; i++) {
          expect(nudges[i].priority.index,
              lessThanOrEqualTo(nudges[i + 1].priority.index));
        }
      }
    });

    // ── Text quality ──────────────────────────────────────────

    test('no banned terms in any nudge text', () async {
      // Trigger many nudges across multiple evaluations and check text
      final bannedTerms = [
        'garanti',
        'certain',
        'assuré',
        'sans risque',
        'optimal',
        'meilleur',
        'parfait',
        'conseiller',
      ];

      // March 25 + December overlap
      for (final date in [
        DateTime(2026, 3, 25),
        DateTime(2026, 12, 25),
        DateTime(2026, 1, 3),
      ]) {
        SharedPreferences.setMockInitialValues({});
        final sp = await SharedPreferences.getInstance();

        final nudges = await JitaiNudgeService.evaluateNudges(
          profile: _makeProfile(birthYear: 1976), // turns 50 in 2026
          now: date,
          prefs: sp,
          currentStreak: 5,
          engagedYesterday: false,
          fhsScore: 60.0,
          goals: [
            UserGoal(
              id: 'g1',
              description: 'Test',
              category: 'other',
              createdAt: DateTime(2026, 1, 1),
              targetDate: date.add(const Duration(days: 15)),
            ),
          ],
        );

        for (final nudge in nudges) {
          final textLower =
              '${nudge.title} ${nudge.message}'.toLowerCase();
          for (final term in bannedTerms) {
            expect(textLower.contains(term), isFalse,
                reason:
                    'Banned term "$term" found in nudge ${nudge.type}: $textLower');
          }
        }
      }
    });

    test('French accents present in nudge text', () async {
      final now = DateTime(2026, 3, 15);
      final nudges = await JitaiNudgeService.evaluateNudges(
        profile: _makeProfile(),
        now: now,
        prefs: prefs,
      );

      // Tax deadline nudge should have accented French
      final tax = nudges.where((n) => n.type == NudgeType.taxDeadline);
      expect(tax.isNotEmpty, isTrue);
      // "Déclaration" has an accent
      expect(tax.first.title, contains('é'));
    });

    test('non-breaking space compliance', () async {
      // Trigger salary day nudge (has \u00a0 before !)
      final now = DateTime(2026, 5, 25);
      final nudges = await JitaiNudgeService.evaluateNudges(
        profile: _makeProfile(),
        now: now,
        prefs: prefs,
      );

      final salary = nudges.where((n) => n.type == NudgeType.salaryDay);
      expect(salary.isNotEmpty, isTrue);
      // Title should have non-breaking space before !
      expect(salary.first.title, contains('\u00a0!'));
    });

    // ── Contract anniversary ──────────────────────────────────

    test('contract anniversary: 365 days since creation → nudge', () async {
      final createdAt = DateTime(2025, 5, 10);
      final now = DateTime(2026, 5, 10); // exactly 365 days later
      final profile = _makeProfile(createdAt: createdAt);

      final nudges = await JitaiNudgeService.evaluateNudges(
        profile: profile,
        now: now,
        prefs: prefs,
      );

      final anniversary =
          nudges.where((n) => n.type == NudgeType.contractAnniversary);
      expect(anniversary.isNotEmpty, isTrue);
    });
  });
}
