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

  // ══════════════════════════════════════════════════════════════
  //  ADVERSARIAL COMPLIANCE TESTS — S59 Hardener Audit
  // ══════════════════════════════════════════════════════════════
  //
  // 8 adversarial scenarios targeting MINT compliance guardrails:
  //   15. Extreme debt user — no "garanti", no recovery promises
  //   16. Zero progress user — encouraging without false promises
  //   17. PII in goals — recap must NOT leak employer/IBAN
  //   18. Exhaustive banned terms scan (all code paths)
  //   19. Disclaimer & sources present on every code path
  //   20. No-ranking — no social comparison in any text
  //   21. Conditional language — "pourrait"/"envisager" not absolutes
  //   22. Disability/invalidité profile — sensitive, no "garanti"
  // ══════════════════════════════════════════════════════════════

  group('WeeklyRecapService — Adversarial Compliance', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    final monday = DateTime(2026, 3, 16);
    final now = DateTime(2026, 3, 18);

    /// Comprehensive banned-terms checker applied to all text output.
    void assertNoBannedTerms(WeeklyRecap recap, {String context = ''}) {
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
          reason: '[$context] Banned term "$term" found in recap text: $allText',
        );
      }
    }

    /// Check no social comparison / ranking language.
    void assertNoRanking(WeeklyRecap recap, {String context = ''}) {
      final rankingPatterns = [
        'top 20%',
        'top 10%',
        'mieux que la moyenne',
        'meilleur que',
        'pire que',
        'comparé aux autres',
        'par rapport aux autres',
        'moyenne suisse',
        'la plupart des gens',
        'percentile',
        'classement',
      ];

      final allText = [
        recap.summaryText,
        recap.motivationalInsight,
        recap.disclaimer,
        ...recap.highlights.map((h) => h.detail),
        ...recap.highlights.map((h) => h.title),
      ].join(' ').toLowerCase();

      for (final pattern in rankingPatterns) {
        expect(
          allText.contains(pattern),
          isFalse,
          reason: '[$context] Social comparison "$pattern" found: $allText',
        );
      }
    }

    /// Check no absolute promises (must use conditional language).
    void assertConditionalLanguage(WeeklyRecap recap, {String context = ''}) {
      final absolutePromises = [
        'tu vas réussir',
        'tu réussiras',
        'c\'est certain',
        'sans aucun doute',
        'tu auras',
        'tu obtiendras',
        'tu gagneras',
        'tu élimineras',
        'ta dette sera effacée',
        'tu seras riche',
        'tu ne perdras jamais',
      ];

      final allText = [
        recap.summaryText,
        recap.motivationalInsight,
        ...recap.highlights.map((h) => h.detail),
      ].join(' ').toLowerCase();

      for (final promise in absolutePromises) {
        expect(
          allText.contains(promise),
          isFalse,
          reason: '[$context] Absolute promise "$promise" found: $allText',
        );
      }
    }

    // ── 15. Extreme debt user (CHF 500k) ────────────────────────
    test('extreme debt user: no recovery promises, no "garanti"', () async {
      // Simulate a user drowning in debt: huge expenses, low savings
      final debtProfile = CoachProfile(
        birthYear: 1975,
        canton: 'GE',
        salaireBrutMensuel: 4000,
        depenses: const DepensesProfile(
          loyer: 2500,
          assuranceMaladie: 600,
          electricite: 150,
          transport: 200,
          telecom: 100,
          autresDepensesFixes: 1500, // debt payments
        ),
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 0,
          // CHF 500k mortgage debt (simulating extreme debt scenario)
          mortgageBalance: 500000,
        ),
        goalA: GoalA(
          type: GoalAType.debtFree,
          targetDate: DateTime(2035, 1, 1),
          label: 'Sortir des dettes',
        ),
      );

      final recap = await WeeklyRecapService.generateRecap(
        profile: debtProfile,
        weekStart: monday,
        now: now,
        prefs: prefs,
        fhsDelta: -8.0, // severe FHS drop
      );

      // Must be overBudget (expenses >> income)
      expect(recap.budgetStatus, RecapBudgetStatus.overBudget);

      // Compliance: no banned terms, no promises, no ranking
      assertNoBannedTerms(recap, context: 'extreme_debt');
      assertNoRanking(recap, context: 'extreme_debt');
      assertConditionalLanguage(recap, context: 'extreme_debt');

      // Disclaimer always present even for distressed users
      expect(recap.disclaimer, contains('outil éducatif'));
      expect(recap.disclaimer, contains('ne constitue pas un conseil'));

      // Sources always present
      expect(recap.sources, isNotEmpty);

      // Summary must NOT contain "garanti" or recovery promises
      expect(recap.summaryText.toLowerCase().contains('garanti'), isFalse);
      expect(recap.summaryText.toLowerCase().contains('tu vas t\'en sortir'), isFalse);
    });

    // ── 16. Zero progress user ──────────────────────────────────
    test('zero progress user: encouraging without false promises', () async {
      // No engagement, no goals, no FHS, no budget
      final recap = await WeeklyRecapService.generateRecap(
        profile: _minimalProfile(),
        weekStart: monday,
        now: now,
        prefs: prefs,
        fhsDelta: null, // no FHS data at all
      );

      expect(recap.actionsThisWeek, 0);
      expect(recap.activeGoals, 0);
      expect(recap.budgetStatus, RecapBudgetStatus.noData);
      expect(recap.fhsDelta, isNull);

      // Must still generate text (not empty or crashy)
      expect(recap.summaryText, isNotEmpty);
      expect(recap.motivationalInsight, isNotEmpty);
      expect(recap.highlights, isNotEmpty);

      // Compliance
      assertNoBannedTerms(recap, context: 'zero_progress');
      assertNoRanking(recap, context: 'zero_progress');
      assertConditionalLanguage(recap, context: 'zero_progress');

      // No false optimism
      expect(recap.summaryText.toLowerCase().contains('garanti'), isFalse);
      expect(recap.motivationalInsight.toLowerCase().contains('certain'), isFalse);
    });

    // ── 17. PII in goals — recap must NOT leak them ─────────────
    test('PII in goals: recap text must not contain employer, IBAN, or names', () async {
      // Seed goals with PII-laden descriptions
      await _seedGoals(prefs, [
        {
          'id': 'pii1',
          'description': 'Demander augmentation chez UBS AG Zurich',
          'category': 'other',
          'createdAt': '2026-03-10T00:00:00.000',
          'isCompleted': false,
        },
        {
          'id': 'pii2',
          'description': 'Virer 50k depuis IBAN CH93 0076 2011 6238 5295 7',
          'category': 'other',
          'createdAt': '2026-03-10T00:00:00.000',
          'isCompleted': false,
        },
        {
          'id': 'pii3',
          'description': 'Racheter LPP pour Maria Gonzalez-Dupont AVS 756.1234.5678.90',
          'category': 'lpp',
          'createdAt': '2026-03-10T00:00:00.000',
          'isCompleted': false,
        },
      ]);

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

      // PII must NOT appear in recap text
      expect(allText.contains('UBS'), isFalse,
          reason: 'Employer name leaked in recap');
      expect(allText.contains('CH93'), isFalse,
          reason: 'IBAN leaked in recap');
      expect(allText.contains('Gonzalez'), isFalse,
          reason: 'Personal name leaked in recap');
      expect(allText.contains('756.1234'), isFalse,
          reason: 'AVS number leaked in recap');
      expect(allText.contains('5678'), isFalse,
          reason: 'Partial AVS number leaked in recap');

      // But goals should still be counted
      expect(recap.activeGoals, 3);
    });

    // ── 18. Exhaustive banned terms across ALL code paths ────────
    test('exhaustive banned terms scan across all budget/engagement/FHS paths', () async {
      // Generate recaps for every combination and check all text
      final profiles = [
        _minimalProfile(),
        _fullProfile(),
        _overBudgetProfile(),
        _underBudgetProfile(),
        _onTrackProfile(),
      ];

      final fhsValues = <double?>[null, 0.0, 5.0, -5.0, -0.5];
      final engagementCounts = [0, 1, 3, 5, 7];

      for (var pi = 0; pi < profiles.length; pi++) {
        for (var fi = 0; fi < fhsValues.length; fi++) {
          // Reset prefs for each iteration
          SharedPreferences.setMockInitialValues({});
          final iterPrefs = await SharedPreferences.getInstance();

          // Seed engagement days
          final engDays = engagementCounts[fi];
          if (engDays > 0) {
            final dates = List.generate(
              engDays,
              (i) => DateTime(2026, 3, 16 + i),
            );
            await _seedEngagement(iterPrefs, dates);
          }

          final recap = await WeeklyRecapService.generateRecap(
            profile: profiles[pi],
            weekStart: monday,
            now: DateTime(2026, 3, 22), // End of week to count all days
            prefs: iterPrefs,
            fhsDelta: fhsValues[fi],
          );

          assertNoBannedTerms(
            recap,
            context: 'profile[$pi] fhs[$fi] eng[$engDays]',
          );
          assertNoRanking(
            recap,
            context: 'profile[$pi] fhs[$fi] eng[$engDays]',
          );
        }
      }
    });

    // ── 19. Disclaimer & sources present on EVERY code path ─────
    test('disclaimer and sources present on every code path variant', () async {
      // Test with various profiles to ensure disclaimer is never missing
      final profiles = [
        _minimalProfile(),
        _fullProfile(),
        _overBudgetProfile(),
        _underBudgetProfile(),
      ];

      for (var i = 0; i < profiles.length; i++) {
        SharedPreferences.setMockInitialValues({});
        final iterPrefs = await SharedPreferences.getInstance();

        final recap = await WeeklyRecapService.generateRecap(
          profile: profiles[i],
          weekStart: monday,
          now: now,
          prefs: iterPrefs,
        );

        expect(recap.disclaimer, isNotEmpty,
            reason: 'Disclaimer missing for profile[$i]');
        expect(recap.disclaimer, contains('outil éducatif'),
            reason: 'Disclaimer lacks "outil éducatif" for profile[$i]');
        expect(recap.disclaimer, contains('ne constitue pas un conseil'),
            reason: 'Disclaimer lacks "ne constitue pas un conseil" for profile[$i]');
        expect(recap.sources, isNotEmpty,
            reason: 'Sources missing for profile[$i]');
        expect(recap.sources.any((s) => s.contains('LAVS') || s.contains('LPP')),
            isTrue,
            reason: 'Sources lack legal references for profile[$i]');
      }
    });

    // ── 20. No social comparison / ranking ──────────────────────
    test('no social comparison or ranking language in any output', () async {
      await _seedEngagement(prefs, [
        DateTime(2026, 3, 16),
        DateTime(2026, 3, 17),
        DateTime(2026, 3, 18),
      ]);
      await _seedGoals(prefs, [
        {
          'id': 'g1',
          'description': 'Objectif test',
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

      assertNoRanking(recap, context: 'full_profile_positive');

      // Also test with negative FHS and overBudget (more likely to slip)
      SharedPreferences.setMockInitialValues({});
      final prefs2 = await SharedPreferences.getInstance();

      final recap2 = await WeeklyRecapService.generateRecap(
        profile: _overBudgetProfile(),
        weekStart: monday,
        now: now,
        prefs: prefs2,
        fhsDelta: -10.0,
      );

      assertNoRanking(recap2, context: 'overbudget_negative_fhs');
    });

    // ── 21. Conditional language (no absolutes) ─────────────────
    test('conditional language used, no absolute promises in any path', () async {
      // Test all engagement levels + budget states
      final testCases = <({CoachProfile profile, int engDays, double? fhs, String label})>[
        (profile: _minimalProfile(), engDays: 0, fhs: null, label: 'minimal_no_eng'),
        (profile: _fullProfile(), engDays: 7, fhs: 10.0, label: 'full_max_eng'),
        (profile: _overBudgetProfile(), engDays: 1, fhs: -5.0, label: 'overbudget_low_eng'),
        (profile: _underBudgetProfile(), engDays: 5, fhs: 2.0, label: 'underbudget_high_eng'),
      ];

      for (final tc in testCases) {
        SharedPreferences.setMockInitialValues({});
        final iterPrefs = await SharedPreferences.getInstance();

        if (tc.engDays > 0) {
          final dates = List.generate(
            tc.engDays,
            (i) => DateTime(2026, 3, 16 + i),
          );
          await _seedEngagement(iterPrefs, dates);
        }

        final recap = await WeeklyRecapService.generateRecap(
          profile: tc.profile,
          weekStart: monday,
          now: DateTime(2026, 3, 22),
          prefs: iterPrefs,
          fhsDelta: tc.fhs,
        );

        assertConditionalLanguage(recap, context: tc.label);

        // Verify overBudget uses "pourrait" or "envisager" (conditional)
        if (recap.budgetStatus == RecapBudgetStatus.overBudget) {
          final budgetText = [
            recap.motivationalInsight,
            ...recap.highlights.where((h) => h.title == 'Budget').map((h) => h.detail),
          ].join(' ').toLowerCase();

          final hasConditional = budgetText.contains('pourrai') ||
              budgetText.contains('envisager') ||
              budgetText.contains('sembl') ||
              budgetText.contains('peut-être');
          expect(hasConditional, isTrue,
              reason: '[${tc.label}] OverBudget text lacks conditional language: $budgetText');
        }
      }
    });

    // ── 22. Disability/invalidité profile ───────────────────────
    test('disability profile: sensitive tone, no "garanti" recovery', () async {
      final disabilityProfile = CoachProfile(
        birthYear: 1980,
        canton: 'VD',
        salaireBrutMensuel: 3000, // reduced income (AI rente)
        employmentStatus: 'invalide',
        depenses: const DepensesProfile(
          loyer: 1800,
          assuranceMaladie: 500,
          electricite: 100,
          transport: 50,
          telecom: 80,
        ),
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 5000,
        ),
        goalA: GoalA(
          type: GoalAType.custom,
          targetDate: DateTime(2045, 1, 1),
          label: 'Stabilité financière',
        ),
      );

      await _seedGoals(prefs, [
        {
          'id': 'inv1',
          'description': 'Vérifier rente AI',
          'category': 'other',
          'createdAt': '2026-03-10T00:00:00.000',
          'isCompleted': false,
        },
      ]);

      final recap = await WeeklyRecapService.generateRecap(
        profile: disabilityProfile,
        weekStart: monday,
        now: now,
        prefs: prefs,
        fhsDelta: -2.5,
      );

      // Must still produce valid output
      expect(recap.summaryText, isNotEmpty);
      expect(recap.motivationalInsight, isNotEmpty);
      expect(recap.disclaimer, contains('outil éducatif'));

      // Compliance
      assertNoBannedTerms(recap, context: 'disability');
      assertNoRanking(recap, context: 'disability');
      assertConditionalLanguage(recap, context: 'disability');

      // No recovery guarantees
      final allText = [
        recap.summaryText,
        recap.motivationalInsight,
        ...recap.highlights.map((h) => h.detail),
      ].join(' ').toLowerCase();

      expect(allText.contains('guérison'), isFalse,
          reason: 'Must not promise "guérison"');
      expect(allText.contains('rétablissement'), isFalse,
          reason: 'Must not promise "rétablissement"');
      expect(allText.contains('garanti'), isFalse,
          reason: 'Must not use "garanti" for disability user');
    });
  });
}
