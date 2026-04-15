import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/recap/weekly_recap_service.dart';

// ────────────────────────────────────────────────────────────
//  WeeklyRecapService (S59 recap/ layer) TESTS
// ────────────────────────────────────────────────────────────
//
// 20 tests covering:
//   1.  Empty activity → no actions, no budget
//   2.  With insights → highlights populated
//   3.  With engagement → actions list correct
//   4.  With FHS delta → RecapProgress populated correctly
//   5.  Date range (weekStart/weekEnd) correct
//   6.  Golden couple Julien with full activity
//   7.  Budget null when no salary
//   8.  Budget null when no expenses
//   9.  Budget computed when salary + expenses present
//   10. Savings rate 0 when expenses >= net income
//   11. savingsRate clamped ≥ 0 even if expenses > income
//   12. Actions only within week window (not previous week)
//   13. Actions not counted for future days
//   14. Disclaimer always present
//   15. Sources always present
//   16. nextWeekFocus == '3a' when savings rate > 30%
//   17. nextWeekFocus == 'budget' when savings rate < 10%
//   18. activeGoals count from GoalTrackerService (only non-completed)
//   19. RecapProgress delta sign preserved (positive and negative)
//   20. Generate uses current-week window (no explicit weekStart param)
// ────────────────────────────────────────────────────────────

// ══ Fixtures ════════════════════════════════════════════════

final _goalA = GoalA(
  type: GoalAType.retraite,
  targetDate: DateTime(2042, 1, 1),
  label: 'Retraite',
);

/// Minimal profile — no salary, no expenses.
CoachProfile _minimalProfile() => CoachProfile(
      birthYear: 1977,
      canton: 'VS',
      salaireBrutMensuel: 0,
      goalA: _goalA,
    );

/// Golden couple Julien — salary 122'207 CHF/year → monthly 10'184.
CoachProfile _julienProfile() => CoachProfile(
      firstName: 'Julien',
      birthYear: 1977,
      canton: 'VS',
      salaireBrutMensuel: 10184,
      nombreDeMois: 12,
      employmentStatus: 'salarie',
      depenses: const DepensesProfile(
        loyer: 2200,
        assuranceMaladie: 450,
        electricite: 100,
        transport: 200,
        telecom: 80,
      ),
      prevoyance: const PrevoyanceProfile(
        avoirLppTotal: 70377,
        totalEpargne3a: 32000,
      ),
      patrimoine: const PatrimoineProfile(epargneLiquide: 50000),
      goalA: _goalA,
    );

/// Over-budget profile (expenses ~> 90% of estimated net).
/// Net = 5000 * 0.80 = 4000. Expenses = 3700. Ratio ~= 0.925 → over.
CoachProfile _overBudgetProfile() => CoachProfile(
      birthYear: 1977,
      canton: 'VS',
      salaireBrutMensuel: 5000,
      depenses: const DepensesProfile(
        loyer: 2500,
        assuranceMaladie: 800,
        electricite: 200,
        transport: 200,
        // total = 3700 ; net = 4000 ; ratio 0.925 → overBudget
      ),
      goalA: _goalA,
    );

/// Under-budget profile (expenses << 70% of net).
/// Net = 10000 * 0.80 = 8000. Expenses = 1900. Ratio = 0.2375 < 0.70.
/// Savings rate = 0.7625 → > 30% → nextFocus = '3a'.
CoachProfile _underBudgetProfile() => CoachProfile(
      birthYear: 1977,
      canton: 'VS',
      salaireBrutMensuel: 10000,
      depenses: const DepensesProfile(
        loyer: 1500,
        assuranceMaladie: 400,
        // total = 1900 ; net = 8000 ; savings = 6100 ; rate = 76%
      ),
      goalA: _goalA,
    );

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

Future<void> _seedEngagement(
    SharedPreferences prefs, List<DateTime> dates) async {
  final keys = dates.map(_dateKey).toSet();
  await prefs.setStringList('_daily_engagement_dates', keys.toList());
}

Future<void> _seedGoals(
    SharedPreferences prefs, List<Map<String, dynamic>> goals) async {
  await prefs.setString('_user_goals', jsonEncode(goals));
}

// ══ Tests ════════════════════════════════════════════════════

void main() {
  group('WeeklyRecapService (S59)', () {
    late SharedPreferences prefs;

    // "now" = Wednesday 2026-03-18 → week starts Monday 2026-03-16
    final now = DateTime(2026, 3, 18);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    // ── 1. Empty activity → no actions, no budget ─────────────
    test('1. empty profile: no actions, no budget, disclaimer present', () async {
      final recap = await WeeklyRecapService.generate(
        profile: _minimalProfile(),
        prefs: prefs,
        now: now,
      );

      expect(recap.actions, isEmpty);
      expect(recap.budget, isNull);
      expect(recap.disclaimer, contains('outil éducatif'));
      expect(recap.sources, isNotEmpty);
    });

    // ── 2. With insights → highlights populated ───────────────
    test('2. seeded insights this week → recapHighlightsTitle in highlights', () async {
      // Seed a CoachInsight from this week
      final insightJson = jsonEncode([
        {
          'id': 'i1',
          'createdAt': '2026-03-16T10:00:00.000',
          'topic': 'lpp',
          'summary': 'Discussed LPP rachat options',
          'type': 'fact',
        },
      ]);
      // CoachMemoryService now namespaces keys per user (Gate 0 P0 fix
       // 2026-04-15). In tests where AuthService has no token, the
       // anonymous namespace is used.
      await prefs.setString('_coach_insights___anon', insightJson);

      final recap = await WeeklyRecapService.generate(
        profile: _minimalProfile(),
        prefs: prefs,
        now: now,
      );

      expect(recap.highlights.contains('recapHighlightsTitle'), isTrue);
    });

    // ── 3. With engagement → actions list correct ─────────────
    test('3. 3 engaged days this week → 3 RecapActions', () async {
      await _seedEngagement(prefs, [
        DateTime(2026, 3, 16), // Monday
        DateTime(2026, 3, 17), // Tuesday
        DateTime(2026, 3, 18), // Wednesday
      ]);

      final recap = await WeeklyRecapService.generate(
        profile: _minimalProfile(),
        prefs: prefs,
        now: now,
      );

      expect(recap.actions.length, 3);
      for (final action in recap.actions) {
        expect(action.capId, 'engagement');
        expect(action.actionId, startsWith('engagement_'));
      }
    });

    // ── 4. FHS delta → RecapProgress populated ────────────────
    test('4. positive fhsDelta → RecapProgress with correct delta', () async {
      final recap = await WeeklyRecapService.generate(
        profile: _minimalProfile(),
        prefs: prefs,
        now: now,
        fhsDelta: 5.5,
      );

      expect(recap.progress, isNotNull);
      expect(recap.progress!.delta, 5.5);
      expect(recap.highlights.contains('recapProgressDelta'), isTrue);
    });

    // ── 5. Date range correct ─────────────────────────────────
    test('5. weekStart is Monday, weekEnd is Sunday', () async {
      final recap = await WeeklyRecapService.generate(
        profile: _minimalProfile(),
        prefs: prefs,
        now: now,
      );

      // now = Wednesday March 18 → Monday = March 16
      expect(recap.weekStart.weekday, DateTime.monday);
      expect(recap.weekStart, DateTime(2026, 3, 16));

      expect(recap.weekEnd.weekday, DateTime.sunday);
      expect(recap.weekEnd, DateTime(2026, 3, 22));
    });

    // ── 6. Golden couple Julien ────────────────────────────────
    test('6. Julien golden couple: budget present, savings rate positive', () async {
      await _seedEngagement(prefs, [
        DateTime(2026, 3, 16),
        DateTime(2026, 3, 17),
        DateTime(2026, 3, 18),
      ]);
      await _seedGoals(prefs, [
        {
          'id': 'g1',
          'description': 'Maximiser 3a 2026',
          'category': '3a',
          'createdAt': '2026-03-10T00:00:00.000',
          'isCompleted': false,
        },
      ]);

      final recap = await WeeklyRecapService.generate(
        profile: _julienProfile(),
        prefs: prefs,
        now: now,
        fhsDelta: 2.0,
      );

      expect(recap.budget, isNotNull);
      final budget = recap.budget!;
      // Net = 10184 * 0.80 = 8147.2; expenses = 3030
      // savings = 8147.2 - 3030 = 5117.2; rate ~ 0.628
      expect(budget.savingsRate, greaterThan(0.3));
      expect(budget.totalIncome, closeTo(10184 * 0.80, 0.01));
      expect(budget.savedAmount, greaterThan(0));
      expect(recap.actions.length, 3);
      expect(recap.activeGoals, 1);
      expect(recap.progress, isNotNull);
    });

    // ── 7. Budget null when no salary ─────────────────────────
    test('7. profile with salary=0 → budget is null', () async {
      final recap = await WeeklyRecapService.generate(
        profile: _minimalProfile(), // salary = 0
        prefs: prefs,
        now: now,
      );

      expect(recap.budget, isNull);
    });

    // ── 8. Budget null when no expenses ───────────────────────
    test('8. profile with salary but no expenses → budget is null', () async {
      final profile = CoachProfile(
        birthYear: 1977,
        canton: 'VS',
        salaireBrutMensuel: 8000,
        // no depenses → totalMensuel = 0 + 0 = 0
        goalA: _goalA,
      );

      final recap = await WeeklyRecapService.generate(
        profile: profile,
        prefs: prefs,
        now: now,
      );

      expect(recap.budget, isNull);
    });

    // ── 9. Budget computed when salary + expenses present ─────
    test('9. profile with salary + expenses → budget not null', () async {
      final recap = await WeeklyRecapService.generate(
        profile: _julienProfile(),
        prefs: prefs,
        now: now,
      );

      expect(recap.budget, isNotNull);
    });

    // ── 10. Savings rate 0 when expenses >= net income ────────
    test('10. savings rate 0 when expenses >= estimated net', () async {
      final profile = CoachProfile(
        birthYear: 1977,
        canton: 'VS',
        salaireBrutMensuel: 2000, // net ~= 1600
        depenses: const DepensesProfile(
          loyer: 1500,
          assuranceMaladie: 400,
          // total = 1900 > 1600 net → savings clamped to 0
        ),
        goalA: _goalA,
      );

      final recap = await WeeklyRecapService.generate(
        profile: profile,
        prefs: prefs,
        now: now,
      );

      expect(recap.budget, isNotNull);
      expect(recap.budget!.savedAmount, 0.0);
      expect(recap.budget!.savingsRate, 0.0);
    });

    // ── 11. savedAmount clamped ≥ 0 ──────────────────────────
    test('11. savedAmount is never negative even if expenses exceed income', () async {
      final profile = CoachProfile(
        birthYear: 1977,
        canton: 'VS',
        salaireBrutMensuel: 1000, // net = 800
        depenses: const DepensesProfile(
          loyer: 1200,
          assuranceMaladie: 500,
          // total = 1700 > 800 net → should clamp
        ),
        goalA: _goalA,
      );

      final recap = await WeeklyRecapService.generate(
        profile: profile,
        prefs: prefs,
        now: now,
      );

      expect(recap.budget!.savedAmount, greaterThanOrEqualTo(0.0));
    });

    // ── 12. Actions only within week window ───────────────────
    test('12. previous-week engagement not counted as action', () async {
      await _seedEngagement(prefs, [
        DateTime(2026, 3, 14), // Saturday — PREVIOUS week
        DateTime(2026, 3, 15), // Sunday — PREVIOUS week
        DateTime(2026, 3, 16), // Monday — this week ✓
      ]);

      final recap = await WeeklyRecapService.generate(
        profile: _minimalProfile(),
        prefs: prefs,
        now: now,
      );

      // Only Monday counts
      expect(recap.actions.length, 1);
    });

    // ── 13. Future days not counted ───────────────────────────
    test('13. future days after now are not counted as actions', () async {
      await _seedEngagement(prefs, [
        DateTime(2026, 3, 16), // Monday ✓
        DateTime(2026, 3, 17), // Tuesday ✓
        DateTime(2026, 3, 19), // Thursday — FUTURE (now = Wednesday)
        DateTime(2026, 3, 20), // Friday — FUTURE
      ]);

      final recap = await WeeklyRecapService.generate(
        profile: _minimalProfile(),
        prefs: prefs,
        now: now, // Wednesday March 18
      );

      // Only Monday + Tuesday count (now = Wednesday, not yet engaged)
      expect(recap.actions.length, 2);
    });

    // ── 14. Disclaimer always present ─────────────────────────
    test('14. disclaimer always present regardless of profile', () async {
      for (final profile in [
        _minimalProfile(),
        _julienProfile(),
        _overBudgetProfile(),
        _underBudgetProfile(),
      ]) {
        SharedPreferences.setMockInitialValues({});
        final sp = await SharedPreferences.getInstance();

        final recap = await WeeklyRecapService.generate(
          profile: profile,
          prefs: sp,
          now: now,
        );

        expect(recap.disclaimer, isNotEmpty,
            reason: 'Disclaimer missing for profile');
        expect(recap.disclaimer, contains('outil éducatif'));
        expect(recap.disclaimer, contains('ne constitue pas un conseil'));
      }
    });

    // ── 15. Sources always present ────────────────────────────
    test('15. sources always non-empty', () async {
      final recap = await WeeklyRecapService.generate(
        profile: _minimalProfile(),
        prefs: prefs,
        now: now,
      );

      expect(recap.sources, isNotEmpty);
      expect(
        recap.sources.any((s) => s.contains('LAVS') || s.contains('LPP')),
        isTrue,
      );
    });

    // ── 16. nextWeekFocus '3a' when savings rate > 30% ────────
    test('16. nextWeekFocus is "3a" when savings rate > 30%', () async {
      final recap = await WeeklyRecapService.generate(
        profile: _underBudgetProfile(), // savingsRate ~= 76%
        prefs: prefs,
        now: now,
      );

      expect(recap.nextWeekFocus, '3a');
    });

    // ── 17. nextWeekFocus 'budget' when savings rate < 10% ────
    test('17. nextWeekFocus is "budget" when savings rate < 10%', () async {
      final recap = await WeeklyRecapService.generate(
        profile: _overBudgetProfile(), // expenses > net → saved = 0 → rate = 0%
        prefs: prefs,
        now: now,
      );

      expect(recap.nextWeekFocus, 'budget');
    });

    // ── 18. activeGoals only non-completed ────────────────────
    test('18. activeGoals counts only non-completed goals', () async {
      await _seedGoals(prefs, [
        {
          'id': 'g1',
          'description': 'Active goal 1',
          'category': '3a',
          'createdAt': '2026-03-10T00:00:00.000',
          'isCompleted': false,
        },
        {
          'id': 'g2',
          'description': 'Active goal 2',
          'category': 'lpp',
          'createdAt': '2026-03-10T00:00:00.000',
          'isCompleted': false,
        },
        {
          'id': 'g3',
          'description': 'Completed goal',
          'category': 'other',
          'createdAt': '2026-03-01T00:00:00.000',
          'isCompleted': true,
        },
      ]);

      final recap = await WeeklyRecapService.generate(
        profile: _minimalProfile(),
        prefs: prefs,
        now: now,
      );

      expect(recap.activeGoals, 2); // g3 is completed → not counted
    });

    // ── 19. RecapProgress delta sign preserved ─────────────────
    test('19. negative fhsDelta → RecapProgress delta is negative', () async {
      final recap = await WeeklyRecapService.generate(
        profile: _minimalProfile(),
        prefs: prefs,
        now: now,
        fhsDelta: -3.7,
      );

      expect(recap.progress, isNotNull);
      expect(recap.progress!.delta, -3.7);
    });

    // ── 20. Generate uses current-week window ─────────────────
    test('20. generate uses current week from "now" — no manual weekStart', () async {
      await _seedEngagement(prefs, [
        DateTime(2026, 3, 16), // This week Monday
        DateTime(2026, 3, 17), // This week Tuesday
      ]);

      final recap = await WeeklyRecapService.generate(
        profile: _minimalProfile(),
        prefs: prefs,
        now: now, // Wednesday March 18 → week starts Monday March 16
      );

      // Week boundaries
      expect(recap.weekStart, DateTime(2026, 3, 16));
      expect(recap.weekEnd, DateTime(2026, 3, 22));
      expect(recap.actions.length, 2);
    });
  });
}
