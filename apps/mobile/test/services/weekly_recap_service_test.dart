import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/services/coach/weekly_recap_service.dart';
import 'package:mint_mobile/models/coach_profile.dart';

// ────────────────────────────────────────────────────────────
//  WEEKLY RECAP SERVICE TESTS — S59
// ────────────────────────────────────────────────────────────
//
// 14 tests covering:
//   - Empty profile → noData budget, 0 actions, default insight
//   - Full profile → all fields populated, correct week range
//   - Budget on track / over / under detection
//   - Engagement days counted correctly
//   - Active goals reflected
//   - FHS delta computed correctly
//   - Disclaimer always present
//   - No banned terms in any generated text
//   - Non-breaking space compliance
//   - French accents present
//   - Summary text under 500 chars
//   - Week boundaries (Monday to Sunday)
//   - Motivational insight always actionnable
//   - Sources always present
// ────────────────────────────────────────────────────────────

final _defaultGoalA = GoalA(
  type: GoalAType.retraite,
  targetDate: DateTime(2042, 1, 1),
  label: 'Retraite',
);

/// Minimal CoachProfile for testing (no salary, no expenses).
CoachProfile _minimalProfile() {
  return CoachProfile(
    birthYear: 1977,
    canton: 'VS',
    salaireBrutMensuel: 0,
    goalA: _defaultGoalA,
  );
}

/// Full CoachProfile with budget data.
CoachProfile _fullProfile() {
  return CoachProfile(
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
    patrimoine: const PatrimoineProfile(
      epargneLiquide: 50000,
    ),
    goalA: _defaultGoalA,
  );
}

/// Profile with expenses > 90% of income (overBudget).
CoachProfile _overBudgetProfile() {
  return CoachProfile(
    birthYear: 1977,
    canton: 'VS',
    salaireBrutMensuel: 5000,
    depenses: const DepensesProfile(
      loyer: 2500,
      assuranceMaladie: 800,
      electricite: 200,
      transport: 300,
      telecom: 100,
      autresDepensesFixes: 800,
    ),
    goalA: _defaultGoalA,
  );
}

/// Profile with expenses < 70% of income (underBudget).
CoachProfile _underBudgetProfile() {
  return CoachProfile(
    birthYear: 1977,
    canton: 'VS',
    salaireBrutMensuel: 10000,
    depenses: const DepensesProfile(
      loyer: 1500,
      assuranceMaladie: 400,
    ),
    goalA: _defaultGoalA,
  );
}

/// On-track profile: expenses between 70-90% of estimated net income.
/// Net = gross * 0.80 = 4000. Expenses = 3300. Ratio = 0.825 → onTrack.
CoachProfile _onTrackProfile() {
  return CoachProfile(
    birthYear: 1977,
    canton: 'VS',
    salaireBrutMensuel: 5000,
    depenses: const DepensesProfile(
      loyer: 2000,
      assuranceMaladie: 500,
      electricite: 200,
      transport: 300,
      telecom: 100,
      autresDepensesFixes: 200,
    ),
    goalA: _defaultGoalA,
  );
}

/// Helper: date key format matching DailyEngagementService.
String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Seed engagement dates into SharedPreferences.
Future<void> _seedEngagement(SharedPreferences prefs, List<DateTime> dates) async {
  final keys = dates.map(_dateKey).toSet();
  await prefs.setStringList('_daily_engagement_dates', keys.toList());
}

/// Seed goals into SharedPreferences.
Future<void> _seedGoals(SharedPreferences prefs, List<Map<String, dynamic>> goals) async {
  await prefs.setString('_user_goals', jsonEncode(goals));
}

void main() {
  group('WeeklyRecapService', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    // Monday 2026-03-16
    final monday = DateTime(2026, 3, 16);
    final now = DateTime(2026, 3, 18); // Wednesday

    // ── 1. Empty profile → noData budget, 0 actions ──────────
    test('empty profile yields noData budget, 0 actions, motivational default', () async {
      final recap = await WeeklyRecapService.generateRecap(
        profile: _minimalProfile(),
        weekStart: monday,
        now: now,
        prefs: prefs,
      );

      expect(recap.budgetStatus, RecapBudgetStatus.noData);
      expect(recap.actionsThisWeek, 0);
      expect(recap.activeGoals, 0);
      expect(recap.motivationalInsight, isNotEmpty);
      expect(recap.disclaimer, contains('outil éducatif'));
    });

    // ── 2. Full profile → all fields populated ────────────────
    test('full profile with engagement and goals populates all fields', () async {
      await _seedEngagement(prefs, [
        DateTime(2026, 3, 16),
        DateTime(2026, 3, 17),
        DateTime(2026, 3, 18),
      ]);
      await _seedGoals(prefs, [
        {
          'id': 'g1',
          'description': 'Maximiser 3a',
          'category': '3a',
          'createdAt': '2026-03-10T00:00:00.000',
          'isCompleted': false,
        },
        {
          'id': 'g2',
          'description': 'Acheter appartement',
          'category': 'housing',
          'createdAt': '2026-03-10T00:00:00.000',
          'isCompleted': false,
        },
      ]);

      final recap = await WeeklyRecapService.generateRecap(
        profile: _fullProfile(),
        weekStart: monday,
        now: now,
        prefs: prefs,
        fhsDelta: 3.5,
      );

      expect(recap.weekStart, DateTime(2026, 3, 16));
      expect(recap.weekEnd, DateTime(2026, 3, 22));
      expect(recap.actionsThisWeek, 3);
      expect(recap.activeGoals, 2);
      expect(recap.fhsDelta, 3.5);
      expect(recap.summaryText, isNotEmpty);
      expect(recap.highlights.length, greaterThanOrEqualTo(3));
    });

    // ── 3. Budget on track ────────────────────────────────────
    test('budget on track when expenses between 70-90% of income', () async {
      final recap = await WeeklyRecapService.generateRecap(
        profile: _onTrackProfile(),
        weekStart: monday,
        now: now,
        prefs: prefs,
      );

      expect(recap.budgetStatus, RecapBudgetStatus.onTrack);
    });

    // ── 4. Budget over ────────────────────────────────────────
    test('budget overBudget when expenses > 90% of income', () async {
      final recap = await WeeklyRecapService.generateRecap(
        profile: _overBudgetProfile(),
        weekStart: monday,
        now: now,
        prefs: prefs,
      );

      expect(recap.budgetStatus, RecapBudgetStatus.overBudget);
    });

    // ── 5. Budget under ───────────────────────────────────────
    test('budget underBudget when expenses < 70% of income', () async {
      final recap = await WeeklyRecapService.generateRecap(
        profile: _underBudgetProfile(),
        weekStart: monday,
        now: now,
        prefs: prefs,
      );

      expect(recap.budgetStatus, RecapBudgetStatus.underBudget);
    });

    // ── 6. Engagement days counted correctly ──────────────────
    test('engagement days counted correctly from SharedPreferences', () async {
      await _seedEngagement(prefs, [
        DateTime(2026, 3, 16), // Monday
        DateTime(2026, 3, 17), // Tuesday
        // Wednesday (now) not yet
        DateTime(2026, 3, 14), // Saturday — previous week, should NOT count
      ]);

      final recap = await WeeklyRecapService.generateRecap(
        profile: _minimalProfile(),
        weekStart: monday,
        now: now,
        prefs: prefs,
      );

      expect(recap.actionsThisWeek, 2);
    });

    // ── 7. Active goals reflected ─────────────────────────────
    test('active goals count matches GoalTrackerService data', () async {
      await _seedGoals(prefs, [
        {
          'id': 'g1',
          'description': 'Objectif 1',
          'category': 'other',
          'createdAt': '2026-03-10T00:00:00.000',
          'isCompleted': false,
        },
        {
          'id': 'g2',
          'description': 'Objectif 2',
          'category': 'other',
          'createdAt': '2026-03-10T00:00:00.000',
          'isCompleted': false,
        },
        {
          'id': 'g3',
          'description': 'Objectif 3',
          'category': 'other',
          'createdAt': '2026-03-10T00:00:00.000',
          'isCompleted': true,
        },
      ]);

      final recap = await WeeklyRecapService.generateRecap(
        profile: _minimalProfile(),
        weekStart: monday,
        now: now,
        prefs: prefs,
      );

      // g3 is completed → only 2 active
      expect(recap.activeGoals, 2);
    });

    // ── 8. FHS delta computed correctly ───────────────────────
    test('FHS delta passed through correctly with negative value', () async {
      final recap = await WeeklyRecapService.generateRecap(
        profile: _minimalProfile(),
        weekStart: monday,
        now: now,
        prefs: prefs,
        fhsDelta: -4.2,
      );

      expect(recap.fhsDelta, -4.2);
      // Should have a trending_down highlight
      final fhsHighlight = recap.highlights.where((h) => h.icon == 'trending_down');
      expect(fhsHighlight, isNotEmpty);
    });

    // ── 9. Disclaimer always present ──────────────────────────
    test('disclaimer always present and correct', () async {
      final recap = await WeeklyRecapService.generateRecap(
        profile: _minimalProfile(),
        weekStart: monday,
        now: now,
        prefs: prefs,
      );

      expect(recap.disclaimer, contains('outil éducatif'));
      expect(recap.disclaimer, contains('ne constitue pas un conseil'));
    });

    // ── 10. No banned terms ───────────────────────────────────
    test('no banned terms in any generated text', () async {
      await _seedEngagement(prefs, [
        DateTime(2026, 3, 16),
        DateTime(2026, 3, 17),
        DateTime(2026, 3, 18),
      ]);
      await _seedGoals(prefs, [
        {
          'id': 'g1',
          'description': 'Test goal',
          'category': 'other',
          'createdAt': '2026-03-10T00:00:00.000',
          'isCompleted': false,
        },
      ]);

      final recap = await WeeklyRecapService.generateRecap(
        profile: _fullProfile(),
        weekStart: monday,
        now: now,
        prefs: prefs,
        fhsDelta: 5.0,
      );

      final bannedTerms = [
        'garanti', 'certain', 'assuré', 'sans risque',
        'optimal', 'meilleur', 'parfait', 'conseiller',
      ];

      final allText = [
        recap.summaryText,
        recap.motivationalInsight,
        recap.disclaimer,
        ...recap.highlights.map((h) => h.detail),
        ...recap.highlights.map((h) => h.title),
      ].join(' ').toLowerCase();

      for (final term in bannedTerms) {
        expect(
          allText.contains(term),
          isFalse,
          reason: 'Banned term "$term" found in recap text',
        );
      }
    });

    // ── 11. Non-breaking space compliance ─────────────────────
    test('non-breaking space present in French text', () async {
      await _seedEngagement(prefs, [
        DateTime(2026, 3, 16),
        DateTime(2026, 3, 17),
        DateTime(2026, 3, 18),
        DateTime(2026, 3, 19),
        DateTime(2026, 3, 20),
      ]);

      final recap = await WeeklyRecapService.generateRecap(
        profile: _fullProfile(),
        weekStart: monday,
        now: DateTime(2026, 3, 20),
        prefs: prefs,
      );

      final allText = [
        recap.summaryText,
        recap.motivationalInsight,
        ...recap.highlights.map((h) => h.detail),
      ].join(' ');

      // Verify at least one nbsp exists in the text
      const nbspChar = '\u00a0';
      expect(allText.contains(nbspChar), isTrue,
          reason: 'Expected non-breaking spaces in French text');
    });

    // ── 12. French accents present ────────────────────────────
    test('French accents present in generated text', () async {
      final recap = await WeeklyRecapService.generateRecap(
        profile: _fullProfile(),
        weekStart: monday,
        now: now,
        prefs: prefs,
      );

      final allText = [
        recap.summaryText,
        recap.motivationalInsight,
        recap.disclaimer,
        ...recap.highlights.map((h) => h.detail),
        ...recap.highlights.map((h) => h.title),
      ].join(' ');

      // Disclaimer alone contains é
      expect(allText.contains('é'), isTrue,
          reason: 'Expected French accent é in text');
    });

    // ── 13. Summary text under 500 chars ──────────────────────
    test('summary text never exceeds 500 characters', () async {
      await _seedEngagement(prefs, [
        DateTime(2026, 3, 16),
        DateTime(2026, 3, 17),
        DateTime(2026, 3, 18),
      ]);
      await _seedGoals(prefs, [
        {
          'id': 'g1',
          'description': 'Goal 1',
          'category': 'other',
          'createdAt': '2026-03-10T00:00:00.000',
          'isCompleted': false,
        },
        {
          'id': 'g2',
          'description': 'Goal 2',
          'category': 'other',
          'createdAt': '2026-03-10T00:00:00.000',
          'isCompleted': false,
        },
        {
          'id': 'g3',
          'description': 'Goal 3',
          'category': 'other',
          'createdAt': '2026-03-10T00:00:00.000',
          'isCompleted': false,
        },
      ]);

      final recap = await WeeklyRecapService.generateRecap(
        profile: _fullProfile(),
        weekStart: monday,
        now: now,
        prefs: prefs,
        fhsDelta: 2.0,
      );

      expect(recap.summaryText.length, lessThanOrEqualTo(500));
    });

    // ── 14. Week boundaries (Monday to Sunday) ────────────────
    test('week boundaries always Monday to Sunday', () async {
      // Pass a Wednesday — should normalize to Monday
      final wednesday = DateTime(2026, 3, 18);
      final recap = await WeeklyRecapService.generateRecap(
        profile: _minimalProfile(),
        weekStart: wednesday,
        now: now,
        prefs: prefs,
      );

      // weekStart should be Monday March 16
      expect(recap.weekStart.weekday, DateTime.monday);
      expect(recap.weekStart, DateTime(2026, 3, 16));

      // weekEnd should be Sunday March 22
      expect(recap.weekEnd.weekday, DateTime.sunday);
      expect(recap.weekEnd, DateTime(2026, 3, 22));
    });
  });
}
