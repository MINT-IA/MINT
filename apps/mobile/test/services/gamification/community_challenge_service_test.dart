import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/services/gamification/community_challenge_service.dart';

// ═══════════════════════════════════════════════════════════════
//  COMMUNITY CHALLENGE SERVICE — Unit tests
// ═══════════════════════════════════════════════════════════════
//
// Tests:
//  1.  January → theme fiscalite
//  2.  April → theme prevoyance
//  3.  July → theme epargne
//  4.  October → theme bilan
//  5.  Each of the 12 months has a challenge defined
//  6.  Challenge id includes year and month
//  7.  Completing a challenge persists in SharedPreferences
//  8.  isCompleted returns false for uncompleted challenge
//  9.  isCompleted returns true after complete()
// 10.  completedChallenges returns history
// 11.  complete() is idempotent (no duplicates)
// 12.  completedCount returns correct count
// 13.  December → theme bilan + intentTag "3a-deep"
// 14.  May → theme prevoyance + intentTag "lpp-deep"
// 15.  COMPLIANCE: no ranking/comparison language in any ARB key
// ═══════════════════════════════════════════════════════════════

void main() {
  // ── Theme mapping ────────────────────────────────────────────

  group('CommunityChallengeService.currentChallenge — theme mapping', () {
    test('January returns fiscalite theme', () {
      final challenge = CommunityChallengeService.currentChallenge(
        now: DateTime(2026, 1, 15),
      );

      expect(challenge, isNotNull);
      expect(challenge!.theme, ChallengeTheme.fiscalite);
    });

    test('February returns fiscalite theme', () {
      final challenge = CommunityChallengeService.currentChallenge(
        now: DateTime(2026, 2, 10),
      );

      expect(challenge, isNotNull);
      expect(challenge!.theme, ChallengeTheme.fiscalite);
    });

    test('March returns fiscalite theme', () {
      final challenge = CommunityChallengeService.currentChallenge(
        now: DateTime(2026, 3, 1),
      );

      expect(challenge, isNotNull);
      expect(challenge!.theme, ChallengeTheme.fiscalite);
    });

    test('April returns prevoyance theme', () {
      final challenge = CommunityChallengeService.currentChallenge(
        now: DateTime(2026, 4, 5),
      );

      expect(challenge, isNotNull);
      expect(challenge!.theme, ChallengeTheme.prevoyance);
    });

    test('May returns prevoyance theme', () {
      final challenge = CommunityChallengeService.currentChallenge(
        now: DateTime(2026, 5, 20),
      );

      expect(challenge, isNotNull);
      expect(challenge!.theme, ChallengeTheme.prevoyance);
    });

    test('June returns prevoyance theme', () {
      final challenge = CommunityChallengeService.currentChallenge(
        now: DateTime(2026, 6, 30),
      );

      expect(challenge, isNotNull);
      expect(challenge!.theme, ChallengeTheme.prevoyance);
    });

    test('July returns epargne theme', () {
      final challenge = CommunityChallengeService.currentChallenge(
        now: DateTime(2026, 7, 1),
      );

      expect(challenge, isNotNull);
      expect(challenge!.theme, ChallengeTheme.epargne);
    });

    test('August returns epargne theme', () {
      final challenge = CommunityChallengeService.currentChallenge(
        now: DateTime(2026, 8, 15),
      );

      expect(challenge, isNotNull);
      expect(challenge!.theme, ChallengeTheme.epargne);
    });

    test('September returns epargne theme', () {
      final challenge = CommunityChallengeService.currentChallenge(
        now: DateTime(2026, 9, 10),
      );

      expect(challenge, isNotNull);
      expect(challenge!.theme, ChallengeTheme.epargne);
    });

    test('October returns bilan theme', () {
      final challenge = CommunityChallengeService.currentChallenge(
        now: DateTime(2026, 10, 1),
      );

      expect(challenge, isNotNull);
      expect(challenge!.theme, ChallengeTheme.bilan);
    });

    test('November returns bilan theme', () {
      final challenge = CommunityChallengeService.currentChallenge(
        now: DateTime(2026, 11, 15),
      );

      expect(challenge, isNotNull);
      expect(challenge!.theme, ChallengeTheme.bilan);
    });

    test('December returns bilan theme', () {
      final challenge = CommunityChallengeService.currentChallenge(
        now: DateTime(2026, 12, 31),
      );

      expect(challenge, isNotNull);
      expect(challenge!.theme, ChallengeTheme.bilan);
    });
  });

  // ── All 12 months have a challenge ───────────────────────────

  group('CommunityChallengeService — 12-month coverage', () {
    test('every month from 1 to 12 returns a non-null challenge', () {
      for (int month = 1; month <= 12; month++) {
        final challenge = CommunityChallengeService.challengeForMonth(
          2026,
          month,
        );
        expect(
          challenge,
          isNotNull,
          reason: 'Month $month should have a challenge',
        );
      }
    });

    test('all 12 challenges have unique ids', () {
      final ids = <String>[];
      for (int month = 1; month <= 12; month++) {
        final challenge = CommunityChallengeService.challengeForMonth(
          2026,
          month,
        )!;
        ids.add(challenge.id);
      }
      expect(ids.toSet().length, 12, reason: 'All challenge ids must be unique');
    });

    test('challenge id includes year and zero-padded month', () {
      final challenge = CommunityChallengeService.challengeForMonth(2026, 3)!;
      expect(challenge.id, startsWith('2026-03-'));
    });

    test('challenge id changes year-over-year', () {
      final c2026 = CommunityChallengeService.challengeForMonth(2026, 1)!;
      final c2027 = CommunityChallengeService.challengeForMonth(2027, 1)!;
      expect(c2026.id, isNot(c2027.id));
    });

    test('December challenge has intentTag 3a-deep', () {
      final challenge = CommunityChallengeService.challengeForMonth(2026, 12)!;
      expect(challenge.intentTag, '3a-deep');
    });

    test('May challenge has intentTag lpp-deep', () {
      final challenge = CommunityChallengeService.challengeForMonth(2026, 5)!;
      expect(challenge.intentTag, 'lpp-deep');
    });

    test('all challenges have non-empty titleKey and descriptionKey', () {
      for (int month = 1; month <= 12; month++) {
        final c = CommunityChallengeService.challengeForMonth(2026, month)!;
        expect(c.titleKey, isNotEmpty);
        expect(c.descriptionKey, isNotEmpty);
      }
    });

    test('startDate is always first day of the month', () {
      for (int month = 1; month <= 12; month++) {
        final c = CommunityChallengeService.challengeForMonth(2026, month)!;
        expect(c.startDate.day, 1);
        expect(c.startDate.month, month);
      }
    });

    test('endDate is always last day of the month', () {
      // Test a specific month (march = 31 days)
      final march = CommunityChallengeService.challengeForMonth(2026, 3)!;
      expect(march.endDate.day, 31);

      // February 2026 has 28 days (not a leap year)
      final feb = CommunityChallengeService.challengeForMonth(2026, 2)!;
      expect(feb.endDate.day, 28);

      // Leap year February 2028
      final feb2028 = CommunityChallengeService.challengeForMonth(2028, 2)!;
      expect(feb2028.endDate.day, 29);
    });
  });

  // ── Persistence ──────────────────────────────────────────────

  group('CommunityChallengeService — persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('isCompleted returns false for a fresh challenge', () async {
      final prefs = await SharedPreferences.getInstance();
      final result = await CommunityChallengeService.isCompleted(
        '2026-03-pilier3a-deadline',
        prefs,
      );
      expect(result, isFalse);
    });

    test('complete marks challenge as completed', () async {
      final prefs = await SharedPreferences.getInstance();
      const id = '2026-07-objectif-epargne';

      await CommunityChallengeService.complete(id, prefs);

      final result = await CommunityChallengeService.isCompleted(id, prefs);
      expect(result, isTrue);
    });

    test('completedChallenges returns history after completion', () async {
      final prefs = await SharedPreferences.getInstance();
      const id1 = '2026-01-declarations-impots';
      const id2 = '2026-12-deadline-3a';

      await CommunityChallengeService.complete(id1, prefs);
      await CommunityChallengeService.complete(id2, prefs);

      final history = await CommunityChallengeService.completedChallenges(prefs);
      expect(history, contains(id1));
      expect(history, contains(id2));
      expect(history.length, 2);
    });

    test('complete is idempotent — no duplicate entries', () async {
      final prefs = await SharedPreferences.getInstance();
      const id = '2026-10-mois-prevoyance';

      await CommunityChallengeService.complete(id, prefs);
      await CommunityChallengeService.complete(id, prefs);
      await CommunityChallengeService.complete(id, prefs);

      final history = await CommunityChallengeService.completedChallenges(prefs);
      expect(history.where((e) => e == id).length, 1);
    });

    test('completedCount returns correct count after multiple completions',
        () async {
      final prefs = await SharedPreferences.getInstance();

      await CommunityChallengeService.complete('2026-01-declarations-impots', prefs);
      await CommunityChallengeService.complete('2026-02-deductions-fiscales', prefs);
      await CommunityChallengeService.complete('2026-03-pilier3a-deadline', prefs);

      final count = await CommunityChallengeService.completedCount(prefs);
      expect(count, 3);
    });

    test('completedChallenges returns empty list when nothing completed',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final history = await CommunityChallengeService.completedChallenges(prefs);
      expect(history, isEmpty);
    });
  });

  // ── COMPLIANCE check ─────────────────────────────────────────

  group('CommunityChallengeService — COMPLIANCE', () {
    test('no titleKey or descriptionKey contains ranking/comparison terms', () {
      final bannedTerms = [
        'top',
        'classement',
        'rang',
        'leaderboard',
        'mieux que',
        'pire que',
      ];

      for (int month = 1; month <= 12; month++) {
        final c = CommunityChallengeService.challengeForMonth(2026, month)!;
        for (final term in bannedTerms) {
          expect(
            c.titleKey.toLowerCase(),
            isNot(contains(term)),
            reason:
                'titleKey of month $month must not contain banned term "$term"',
          );
          expect(
            c.descriptionKey.toLowerCase(),
            isNot(contains(term)),
            reason:
                'descriptionKey of month $month must not contain banned term "$term"',
          );
        }
      }
    });
  });
}
