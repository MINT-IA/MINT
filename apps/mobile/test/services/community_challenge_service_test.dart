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
  //  COMMUNITY CHALLENGE SERVICE — 15 unit tests
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
}
