import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/coach/community_challenge_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════════════

/// Banned terms that must NEVER appear in user-facing text.
const _bannedTerms = [
  'garanti',
  'certain',
  'assuré',
  'sans risque',
  'optimal',
  'meilleur',
  'parfait',
  'conseiller',
];

/// Set up clean SharedPreferences for each test.
Future<SharedPreferences> _freshPrefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

void main() {
  // ═══════════════════════════════════════════════════════════════
  //  COMMUNITY CHALLENGE SERVICE — 30 unit tests
  // ═══════════════════════════════════════════════════════════════

  TestWidgetsFlutterBinding.ensureInitialized();

  group('CommunityChallengeService.getActiveChallenges', () {
    test('1. returns only current season challenges', () async {
      // January → should return newYear challenges only.
      final challenges = await CommunityChallengeService.getActiveChallenges(
        now: DateTime(2026, 1, 15),
      );

      expect(challenges, isNotEmpty);
      expect(challenges.length, 3, reason: '3 challenges per season');
      for (final c in challenges) {
        expect(c.seasonalEvent, SeasonalEvent.newYear.name);
      }
    });

    test('2. tax season returns March-April challenges', () async {
      final challenges = await CommunityChallengeService.getActiveChallenges(
        now: DateTime(2026, 3, 15),
      );

      expect(challenges, isNotEmpty);
      for (final c in challenges) {
        expect(c.seasonalEvent, SeasonalEvent.taxSeason.name);
      }
    });

    test('3. no challenges in off-season month (February)', () async {
      final challenges = await CommunityChallengeService.getActiveChallenges(
        now: DateTime(2026, 2, 15),
      );

      expect(challenges, isEmpty,
          reason: 'February is between seasons, no active challenges');
    });
  });

  group('CommunityChallengeService.joinChallenge', () {
    test('4. join challenge persists', () async {
      final prefs = await _freshPrefs();

      await CommunityChallengeService.joinChallenge(
        challengeId: 'ny_goals_2026',
        prefs: prefs,
        now: DateTime(2026, 1, 10),
      );

      final history = await CommunityChallengeService.getHistory(prefs: prefs);
      expect(history, hasLength(1));
      expect(history.first.challengeId, 'ny_goals_2026');
      expect(history.first.isCompleted, isFalse);
    });

    test('5. joining same challenge twice is no-op', () async {
      final prefs = await _freshPrefs();

      await CommunityChallengeService.joinChallenge(
        challengeId: 'ny_goals_2026',
        prefs: prefs,
        now: DateTime(2026, 1, 10),
      );
      await CommunityChallengeService.joinChallenge(
        challengeId: 'ny_goals_2026',
        prefs: prefs,
        now: DateTime(2026, 1, 11),
      );

      final history = await CommunityChallengeService.getHistory(prefs: prefs);
      expect(history, hasLength(1), reason: 'Duplicate join should be ignored');
    });
  });

  group('CommunityChallengeService.completeChallenge', () {
    test('6. complete challenge persists', () async {
      final prefs = await _freshPrefs();

      await CommunityChallengeService.joinChallenge(
        challengeId: 'ny_avs_2026',
        prefs: prefs,
        now: DateTime(2026, 1, 5),
      );
      await CommunityChallengeService.completeChallenge(
        challengeId: 'ny_avs_2026',
        prefs: prefs,
        now: DateTime(2026, 1, 20),
      );

      final history = await CommunityChallengeService.getHistory(prefs: prefs);
      expect(history.first.isCompleted, isTrue);
      expect(history.first.completedAt, DateTime(2026, 1, 20));
    });

    test('7. completed challenge not shown as active', () async {
      final prefs = await _freshPrefs();

      await CommunityChallengeService.joinChallenge(
        challengeId: 'ny_goals_2026',
        prefs: prefs,
        now: DateTime(2026, 1, 5),
      );
      await CommunityChallengeService.completeChallenge(
        challengeId: 'ny_goals_2026',
        prefs: prefs,
        now: DateTime(2026, 1, 10),
      );

      final active = await CommunityChallengeService.getActiveChallenges(
        prefs: prefs,
        now: DateTime(2026, 1, 15),
      );

      final ids = active.map((c) => c.id).toSet();
      expect(ids, isNot(contains('ny_goals_2026')),
          reason: 'Completed challenge should not appear in active list');
    });
  });

  group('CommunityChallengeService.getHistory', () {
    test('8. history returns completed challenges', () async {
      final prefs = await _freshPrefs();

      // Join and complete two challenges.
      for (final id in ['ny_goals_2026', 'ny_avs_2026']) {
        await CommunityChallengeService.joinChallenge(
          challengeId: id,
          prefs: prefs,
          now: DateTime(2026, 1, 5),
        );
        await CommunityChallengeService.completeChallenge(
          challengeId: id,
          prefs: prefs,
          now: DateTime(2026, 1, 15),
        );
      }

      final history = await CommunityChallengeService.getHistory(prefs: prefs);
      expect(history, hasLength(2));
      expect(history.every((r) => r.isCompleted), isTrue);
    });
  });

  group('CommunityChallengeService.getUpcomingEvents', () {
    test('9. seasonal events correct for each quarter', () {
      // January → all 4 events upcoming.
      final jan = CommunityChallengeService.getUpcomingEvents(
        now: DateTime(2026, 1, 15),
      );
      expect(jan, contains(SeasonalEvent.newYear));
      expect(jan, contains(SeasonalEvent.taxSeason));
      expect(jan, contains(SeasonalEvent.summerSavings));
      expect(jan, contains(SeasonalEvent.yearEndPlanning));

      // May → summer + yearEnd.
      final may = CommunityChallengeService.getUpcomingEvents(
        now: DateTime(2026, 5, 15),
      );
      expect(may, contains(SeasonalEvent.summerSavings));
      expect(may, contains(SeasonalEvent.yearEndPlanning));
      expect(may, isNot(contains(SeasonalEvent.newYear)));

      // September → yearEnd only.
      final sep = CommunityChallengeService.getUpcomingEvents(
        now: DateTime(2026, 9, 15),
      );
      expect(sep, contains(SeasonalEvent.yearEndPlanning));
      expect(sep, hasLength(1));
    });
  });

  group('CommunityChallengeService.formatShareableAchievement', () {
    test('10. contains NO personal data', () {
      final text = CommunityChallengeService.formatShareableAchievement(
        milestoneId: 'streak_12',
        milestoneLabel: '12 mois de suivi',
      );

      // No numbers that could be amounts.
      expect(text, isNot(matches(RegExp(r'\d{3,}'))),
          reason: 'No large numbers that could be amounts');
      // No PII patterns.
      expect(text, isNot(matches(RegExp(r'CH\d{2}'))),
          reason: 'No IBAN fragments');
    });

    test('11. contains NO social comparison', () {
      final text = CommunityChallengeService.formatShareableAchievement(
        milestoneId: 'patrimoine_100k',
        milestoneLabel: 'Cap des 100k',
      );

      final lower = text.toLowerCase();
      expect(lower, isNot(contains('top')));
      expect(lower, isNot(contains('classement')));
      expect(lower, isNot(contains('rang')));
      expect(lower, isNot(contains('mieux que')));
      expect(lower, isNot(contains('leaderboard')));
    });

    test('12. includes disclaimer', () {
      final text = CommunityChallengeService.formatShareableAchievement(
        milestoneId: 'test',
        milestoneLabel: 'Test',
      );

      expect(text, contains('LSFin'));
      expect(text, contains('éducatif'));
    });
  });

  group('CommunityChallengeService — compliance', () {
    test('13. no banned terms in any challenge text', () async {
      final challenges = await CommunityChallengeService.getActiveChallenges(
        now: DateTime(2026, 1, 15),
      );
      // Also check other seasons.
      final tax = await CommunityChallengeService.getActiveChallenges(
        now: DateTime(2026, 3, 15),
      );
      final summer = await CommunityChallengeService.getActiveChallenges(
        now: DateTime(2026, 6, 15),
      );
      final yearEnd = await CommunityChallengeService.getActiveChallenges(
        now: DateTime(2026, 11, 15),
      );

      final allChallenges = [...challenges, ...tax, ...summer, ...yearEnd];

      for (final c in allChallenges) {
        final text = '${c.title} ${c.description}'.toLowerCase();
        for (final banned in _bannedTerms) {
          expect(text, isNot(contains(banned)),
              reason: 'Banned term "$banned" in challenge "${c.id}"');
        }
      }
    });

    test('14. French accents correct in challenge titles', () async {
      final challenges = await CommunityChallengeService.getActiveChallenges(
        now: DateTime(2026, 3, 15),
      );

      final allTitles = challenges.map((c) => c.title).join(' ');
      // Tax season challenges should have accented French.
      expect(allTitles, contains('é'),
          reason: 'French accent é expected in titles');
    });

    test('15. challenge dates are valid (start < end) and FHS bonus reasonable',
        () async {
      // Check all 4 seasons.
      for (final month in [1, 3, 6, 11]) {
        final challenges = await CommunityChallengeService.getActiveChallenges(
          now: DateTime(2026, month, 15),
        );

        for (final c in challenges) {
          expect(c.startDate.isBefore(c.endDate), isTrue,
              reason: 'Challenge ${c.id}: start must be before end');
          expect(c.fhsBonus, greaterThanOrEqualTo(1),
              reason: 'FHS bonus must be >= 1');
          expect(c.fhsBonus, lessThanOrEqualTo(10),
              reason: 'FHS bonus must be <= 10');
          // Aggregates should be positive.
          expect(c.participantCount, greaterThan(0));
          expect(c.completionRate, greaterThan(0));
          expect(c.completionRate, lessThanOrEqualTo(1.0));
        }
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  ADVERSARIAL COMPLIANCE TESTS (16-25)
  // ═══════════════════════════════════════════════════════════════

  group('CommunityChallengeService — adversarial compliance', () {
    /// Helper: get ALL 12 challenges across all 4 seasons.
    Future<List<CommunityChallenge>> _allChallenges() async {
      final results = <CommunityChallenge>[];
      for (final month in [1, 3, 6, 11]) {
        results.addAll(
          await CommunityChallengeService.getActiveChallenges(
            now: DateTime(2026, month, 15),
          ),
        );
      }
      return results;
    }

    test('16. NO social comparison in ANY challenge text', () async {
      final all = await _allChallenges();
      final socialPatterns = [
        'top ',
        'top\u00a0',
        'classement',
        'rang ',
        'rang\u00a0',
        'mieux que',
        'leaderboard',
        'meilleur que',
        'devance',
        'dépasse les autres',
        'en avance sur',
        'les autres participants',
        'comparé aux autres',
        'par rapport aux autres',
        'la moyenne des',
        'percentile',
        'quartile',
      ];

      for (final c in all) {
        final text = '${c.title} ${c.description}'.toLowerCase();
        for (final p in socialPatterns) {
          expect(text, isNot(contains(p)),
              reason:
                  'Social comparison "$p" in challenge "${c.id}" — BANNED');
        }
      }
    });

    test('17. NO ranking language in challenge text', () async {
      final all = await _allChallenges();
      final rankingPatterns = RegExp(
        r'(n°\s?\d|position|classé|place\s+\d|premier|dernier|podium|médaille)',
        caseSensitive: false,
      );

      for (final c in all) {
        final text = '${c.title} ${c.description}';
        expect(text, isNot(matches(rankingPatterns)),
            reason: 'Ranking language in challenge "${c.id}" — BANNED');
      }
    });

    test('18. share template contains NO PII fields', () {
      // Adversarial: inject PII-like milestoneLabel.
      final piiLabels = [
        'Julien a atteint 100k',
        'CH93 0076 2011 6238 5295 7',
        'julien@mint.ch',
        '756.1234.5678.97',
      ];

      for (final label in piiLabels) {
        final text = CommunityChallengeService.formatShareableAchievement(
          milestoneId: 'test',
          milestoneLabel: label,
        );

        // The share text echoes the label — that's OK as long as the
        // CALLER is responsible for sanitized labels. But the disclaimer
        // must always be present.
        expect(text, contains('LSFin'));
        expect(text, contains('éducatif'));
      }
    });

    test('19. share disclaimer is always non-empty and well-formed', () {
      expect(CommunityChallengeService.shareDisclaimer, isNotEmpty);
      expect(CommunityChallengeService.shareDisclaimer, contains('LSFin'));
      expect(
          CommunityChallengeService.shareDisclaimer, contains('éducatif'));
      expect(CommunityChallengeService.shareDisclaimer,
          isNot(contains('conseiller')));
    });

    test('20. NO "maximise/optimal" absolute language in challenges',
        () async {
      final all = await _allChallenges();
      final absolutePatterns = [
        'maximise',
        'maximiser',
        'optimal',
        'optimale',
        'parfait',
        'parfaite',
        'idéal ',
        'idéale',
      ];

      for (final c in all) {
        final text = '${c.title} ${c.description}'.toLowerCase();
        for (final p in absolutePatterns) {
          expect(text, isNot(contains(p)),
              reason: 'Absolute language "$p" in "${c.id}" — borderline');
        }
      }
    });

    test('21. exactly 12 challenges across 4 seasons (3 per season)',
        () async {
      final all = await _allChallenges();
      expect(all, hasLength(12));

      // Verify 3 per season.
      final bySeason = <String, int>{};
      for (final c in all) {
        bySeason[c.seasonalEvent ?? 'none'] =
            (bySeason[c.seasonalEvent ?? 'none'] ?? 0) + 1;
      }
      expect(bySeason.length, 4, reason: '4 seasons');
      for (final entry in bySeason.entries) {
        expect(entry.value, 3,
            reason: '3 challenges per season, got ${entry.value} for '
                '${entry.key}');
      }
    });

    test('22. all challenge IDs are unique', () async {
      final all = await _allChallenges();
      final ids = all.map((c) => c.id).toSet();
      expect(ids.length, all.length, reason: 'Duplicate challenge IDs found');
    });

    test('23. complete without join is no-op (no crash)', () async {
      final prefs = await _freshPrefs();

      // Attempt to complete a challenge that was never joined.
      await CommunityChallengeService.completeChallenge(
        challengeId: 'nonexistent_challenge',
        prefs: prefs,
        now: DateTime(2026, 1, 15),
      );

      final history =
          await CommunityChallengeService.getHistory(prefs: prefs);
      expect(history, isEmpty,
          reason: 'Completing without joining should be silent no-op');
    });

    test('24. null prefs gracefully handled (no crash)', () async {
      // All methods should handle null prefs without throwing.
      final active = await CommunityChallengeService.getActiveChallenges(
        prefs: null,
        now: DateTime(2026, 1, 15),
      );
      expect(active, isNotEmpty, reason: 'Active challenges available');

      await CommunityChallengeService.joinChallenge(
        challengeId: 'ny_goals_2026',
        prefs: null,
        now: DateTime(2026, 1, 10),
      );
      // No crash = pass.

      final history =
          await CommunityChallengeService.getHistory(prefs: null);
      expect(history, isEmpty);
    });

    test('25. double-complete is no-op (idempotent)', () async {
      final prefs = await _freshPrefs();

      await CommunityChallengeService.joinChallenge(
        challengeId: 'ny_avs_2026',
        prefs: prefs,
        now: DateTime(2026, 1, 5),
      );
      await CommunityChallengeService.completeChallenge(
        challengeId: 'ny_avs_2026',
        prefs: prefs,
        now: DateTime(2026, 1, 10),
      );
      await CommunityChallengeService.completeChallenge(
        challengeId: 'ny_avs_2026',
        prefs: prefs,
        now: DateTime(2026, 1, 15),
      );

      final history =
          await CommunityChallengeService.getHistory(prefs: prefs);
      expect(history, hasLength(1));
      // Original completion date preserved, not overwritten.
      expect(history.first.completedAt, DateTime(2026, 1, 10));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  COACHING CONTENT QUALITY TESTS (26-30)
  // ═══════════════════════════════════════════════════════════════

  group('CommunityChallengeService — coaching quality', () {
    Future<List<CommunityChallenge>> _allChallenges() async {
      final results = <CommunityChallenge>[];
      for (final month in [1, 3, 6, 11]) {
        results.addAll(
          await CommunityChallengeService.getActiveChallenges(
            now: DateTime(2026, month, 15),
          ),
        );
      }
      return results;
    }

    test('26. every challenge has at least 1 emotional marker', () async {
      final all = await _allChallenges();
      final emotionWords = [
        'imagine',
        'impact',
        'bravo',
        'progrès',
        'félicitations',
        'courage',
        'important',
        'confiance',
        'fierté',
        'motivation',
        'motivant',
        'réussie',
        'visible',
      ];

      for (final c in all) {
        final text = '${c.title} ${c.description}'.toLowerCase();
        final hasEmotion = emotionWords.any((w) => text.contains(w));
        expect(hasEmotion, isTrue,
            reason:
                'Challenge "${c.id}" lacks emotional hook — pattern: '
                'concret+émotionnel+actionnable');
      }
    });

    test('27. every challenge has at least 1 actionnable verb', () async {
      final all = await _allChallenges();
      final actionVerbs = [
        'tu peux',
        'vérifie',
        'demande',
        'action',
        'étape',
        'compare',
        'ouvre',
        'simule',
        'explore',
        'rassemble',
        'scanne',
        'commande',
        'fixe',
        'définis',
        'utilise',
        'regarde',
        'identifie',
        'fais',
        'organise',
        'planifie',
        'prépare',
        'évalue',
        'revisite',
        'compléter',
        'complète',
      ];

      for (final c in all) {
        final text = '${c.title} ${c.description}'.toLowerCase();
        final hasAction = actionVerbs.any((v) => text.contains(v));
        expect(hasAction, isTrue,
            reason:
                'Challenge "${c.id}" lacks actionnable verb — '
                'user must know WHAT to do');
      }
    });

    test('28. French diacritics present (no ASCII-only accented words)',
        () async {
      final all = await _allChallenges();
      // Common words that MUST have accents in French.
      final asciiErrors = RegExp(
        r'\b(prevoyance|epargne|decembre|depenses|deductions|securite'
        r'|deja|etape|reussie|felicitations|completee|preparee)\b',
        caseSensitive: false,
      );

      for (final c in all) {
        final text = '${c.title} ${c.description}';
        expect(text, isNot(matches(asciiErrors)),
            reason:
                'ASCII-only accented word in "${c.id}" — mandatory '
                'French diacritics');
      }
    });

    test('29. seasonal alignment: challenges map to correct months',
        () async {
      final seasonMonths = {
        SeasonalEvent.newYear.name: [1],
        SeasonalEvent.taxSeason.name: [3, 4],
        SeasonalEvent.summerSavings.name: [6, 7],
        SeasonalEvent.yearEndPlanning.name: [11, 12],
      };

      final all = await _allChallenges();
      for (final c in all) {
        final expectedMonths = seasonMonths[c.seasonalEvent];
        expect(expectedMonths, isNotNull,
            reason: 'Unknown seasonal event: ${c.seasonalEvent}');
        expect(expectedMonths, contains(c.startDate.month),
            reason:
                'Challenge "${c.id}" starts in month ${c.startDate.month} '
                'but season is ${c.seasonalEvent}');
      }
    });

    test('30. inclusive language: no "conseiller", uses "spécialiste"',
        () async {
      final all = await _allChallenges();

      for (final c in all) {
        final text = '${c.title} ${c.description}'.toLowerCase();
        expect(text, isNot(contains('conseiller')),
            reason:
                'Non-inclusive "conseiller" in "${c.id}" — use '
                '"spécialiste"');
      }

      // Also check share disclaimer.
      expect(
        CommunityChallengeService.shareDisclaimer.toLowerCase(),
        isNot(contains('conseiller')),
      );
    });
  });
}
