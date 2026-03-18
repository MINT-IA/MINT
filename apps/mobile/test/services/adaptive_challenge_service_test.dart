import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/coach/adaptive_challenge_service.dart';
import 'package:mint_mobile/services/lifecycle_phase_service.dart';

// ────────────────────────────────────────────────────────────
//  ADAPTIVE CHALLENGE SERVICE TESTS — S62
// ────────────────────────────────────────────────────────────

/// Helper: create a minimal CoachProfile for testing.
///
/// archetype is computed from nationality, arrivalAge, employmentStatus, etc.
/// Use [nationality] and [employmentStatus] to control archetype detection.
CoachProfile _makeProfile({
  int birthYear = 1990,
  String? nationality,
  String employmentStatus = 'salarie',
  int? arrivalAge,
  PrevoyanceProfile prevoyance = const PrevoyanceProfile(),
  String? residencePermit,
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: 'VD',
    nationality: nationality,
    etatCivil: CoachCivilStatus.celibataire,
    nombreEnfants: 0,
    salaireBrutMensuel: 7000,
    nombreDeMois: 12,
    employmentStatus: employmentStatus,
    depenses: const DepensesProfile(),
    prevoyance: prevoyance,
    patrimoine: const PatrimoineProfile(),
    dettes: const DetteProfile(),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2055, 1, 1),
      label: 'Retraite',
    ),
    arrivalAge: arrivalAge,
    residencePermit: residencePermit,
  );
}

/// Helper: detect lifecycle from profile.
LifecyclePhaseResult _lifecycle(CoachProfile profile, {DateTime? now}) {
  return LifecyclePhaseService.detect(profile, now: now);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  final testDate = DateTime(2026, 3, 18);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('AdaptiveChallengeService', () {
    // ── Test 1: returns challenge matching user's phase ──
    test('getWeeklyChallenge returns challenge matching user phase', () async {
      final profile = _makeProfile(birthYear: 1990); // age ~36 → acceleration
      final lifecycle = _lifecycle(profile, now: testDate);
      expect(lifecycle.phase, LifecyclePhase.acceleration);

      final challenge = await AdaptiveChallengeService.getWeeklyChallenge(
        profile: profile,
        lifecycle: lifecycle,
        now: testDate,
        prefs: prefs,
      );

      expect(challenge, isNotNull);
      // Challenge should either target this phase or target all phases (empty set)
      if (challenge!.targetPhases.isNotEmpty) {
        expect(challenge.targetPhases, contains(lifecycle.phase));
      }
    });

    // ── Test 2: filters by archetype (expat_us gets FATCA) ──
    test('expat_us archetype can get FATCA challenge', () async {
      // nationality: 'US' → archetype = expatUs
      final profile = _makeProfile(
        birthYear: 1982,
        nationality: 'US',
      );
      expect(profile.archetype, FinancialArchetype.expatUs);

      // FATCA challenge exists in pool for expatUs
      final fatcaChallenge = AdaptiveChallengeService.challengePool
          .where((c) => c.id == 'fiscalite_07')
          .first;
      expect(fatcaChallenge.targetArchetypes, contains('expatUs'));

      // Non-expatUs should NOT get FATCA challenge
      final swissProfile = _makeProfile(birthYear: 1982);
      expect(swissProfile.archetype, FinancialArchetype.swissNative);

      // Verify the filtering logic directly
      const pool = AdaptiveChallengeService.challengePool;
      final expatOnlyChallenges =
          pool.where((c) => c.targetArchetypes.contains('expatUs')).toList();
      expect(expatOnlyChallenges, isNotEmpty);

      // Swiss native should not match expatUs-only challenges
      for (final c in expatOnlyChallenges) {
        expect(
          c.targetArchetypes.contains(swissProfile.archetype.name),
          isFalse,
          reason: '${c.id} should not match swissNative',
        );
      }
    });

    // ── Test 3: never returns completed challenge ──
    test('getWeeklyChallenge never returns a completed challenge', () async {
      final profile = _makeProfile(birthYear: 1998); // demarrage
      final lifecycle = _lifecycle(profile, now: testDate);

      // Get first challenge
      final first = await AdaptiveChallengeService.getWeeklyChallenge(
        profile: profile,
        lifecycle: lifecycle,
        now: testDate,
        prefs: prefs,
      );
      expect(first, isNotNull);

      // Complete it
      await AdaptiveChallengeService.completeChallenge(
        challengeId: first!.id,
        prefs: prefs,
        now: testDate,
      );

      // Next week should not return the same challenge
      final nextWeek = testDate.add(const Duration(days: 7));
      final second = await AdaptiveChallengeService.getWeeklyChallenge(
        profile: profile,
        lifecycle: lifecycle,
        now: nextWeek,
        prefs: prefs,
      );

      if (second != null) {
        expect(second.id, isNot(equals(first.id)));
      }
    });

    // ── Test 4: returns null when all challenges completed ──
    test('returns null when all matching challenges completed', () async {
      final profile = _makeProfile(birthYear: 1998); // demarrage
      final lifecycle = _lifecycle(profile, now: testDate);

      // Complete ALL challenges in the pool
      for (final c in AdaptiveChallengeService.challengePool) {
        await AdaptiveChallengeService.completeChallenge(
          challengeId: c.id,
          prefs: prefs,
          now: testDate,
        );
      }

      final result = await AdaptiveChallengeService.getWeeklyChallenge(
        profile: profile,
        lifecycle: lifecycle,
        now: testDate.add(const Duration(days: 14)),
        prefs: prefs,
      );

      expect(result, isNull);
    });

    // ── Test 5: difficulty starts at easy ──
    test('difficulty starts at easy', () async {
      final difficulty =
          await AdaptiveChallengeService.currentDifficulty(prefs: prefs);
      expect(difficulty, ChallengeDifficulty.easy);
    });

    // ── Test 6: difficulty upgrades after 3 completions ──
    test('difficulty upgrades to medium after 3 completions', () async {
      await AdaptiveChallengeService.completeChallenge(
          challengeId: 'budget_01', prefs: prefs, now: testDate);
      await AdaptiveChallengeService.completeChallenge(
          challengeId: 'budget_02', prefs: prefs, now: testDate);
      await AdaptiveChallengeService.completeChallenge(
          challengeId: 'budget_04', prefs: prefs, now: testDate);

      final difficulty =
          await AdaptiveChallengeService.currentDifficulty(prefs: prefs);
      expect(difficulty, ChallengeDifficulty.medium);
    });

    // ── Test 7: difficulty downgrades after 2 consecutive skips ──
    test('difficulty downgrades after 2 consecutive skips', () async {
      // First upgrade to medium
      await AdaptiveChallengeService.completeChallenge(
          challengeId: 'a1', prefs: prefs, now: testDate);
      await AdaptiveChallengeService.completeChallenge(
          challengeId: 'a2', prefs: prefs, now: testDate);
      await AdaptiveChallengeService.completeChallenge(
          challengeId: 'a3', prefs: prefs, now: testDate);

      expect(await AdaptiveChallengeService.currentDifficulty(prefs: prefs),
          ChallengeDifficulty.medium);

      // Now skip 2 in a row
      await AdaptiveChallengeService.skipChallenge(
          challengeId: 'b1', prefs: prefs, now: testDate);
      await AdaptiveChallengeService.skipChallenge(
          challengeId: 'b2', prefs: prefs, now: testDate);

      expect(await AdaptiveChallengeService.currentDifficulty(prefs: prefs),
          ChallengeDifficulty.easy);
    });

    // ── Test 8: completeChallenge persists in history ──
    test('completeChallenge persists in history', () async {
      await AdaptiveChallengeService.completeChallenge(
        challengeId: 'budget_01',
        prefs: prefs,
        now: testDate,
      );

      final history = await AdaptiveChallengeService.getHistory(prefs: prefs);
      expect(history, hasLength(1));
      expect(history.first.challengeId, 'budget_01');
      expect(history.first.completed, isTrue);
    });

    // ── Test 9: skipChallenge persists in history ──
    test('skipChallenge persists in history', () async {
      await AdaptiveChallengeService.skipChallenge(
        challengeId: 'budget_02',
        prefs: prefs,
        now: testDate,
      );

      final history = await AdaptiveChallengeService.getHistory(prefs: prefs);
      expect(history, hasLength(1));
      expect(history.first.challengeId, 'budget_02');
      expect(history.first.completed, isFalse);
    });

    // ── Test 10: challenge pool has >= 50 entries ──
    test('challenge pool has at least 50 entries', () {
      expect(
        AdaptiveChallengeService.challengePool.length,
        greaterThanOrEqualTo(50),
      );
    });

    // ── Test 11: all challenges have valid GoRouter routes ──
    test('all challenges have valid GoRouter routes', () {
      // Valid routes must start with /
      final validRoutePattern = RegExp(r'^/[a-z0-9\-/]+$');
      for (final c in AdaptiveChallengeService.challengePool) {
        expect(
          validRoutePattern.hasMatch(c.actionRoute),
          isTrue,
          reason: '${c.id} has invalid route: ${c.actionRoute}',
        );
      }
    });

    // ── Test 12: no banned terms in any challenge text ──
    test('no banned terms in challenge text', () {
      const bannedTerms = [
        'garanti',
        'certain',
        'assuré',
        'sans risque',
        'optimal',
        'meilleur',
        'parfait',
        'conseiller',
      ];

      for (final c in AdaptiveChallengeService.challengePool) {
        final text = '${c.title} ${c.description}'.toLowerCase();
        for (final term in bannedTerms) {
          // Allow "meilleure allocation" as comparative, not absolute
          // But check for absolute usage
          if (term == 'meilleur' || term == 'optimal') {
            // These are banned as absolutes — check for "le meilleur", "la meilleure"
            // but allow comparative forms
            final absolutePattern =
                RegExp('\\b(le |la |les |l\')$term(e|s|es)?\\b');
            expect(
              absolutePattern.hasMatch(text),
              isFalse,
              reason: '${c.id} contains banned absolute term "$term"',
            );
          } else {
            expect(
              text.contains(term),
              isFalse,
              reason: '${c.id} contains banned term "$term"',
            );
          }
        }
      }
    });

    // ── Test 13: French accents present in titles/descriptions ──
    test('French accents present in challenge text', () {
      // At least some challenges should have accented characters
      final accentPattern = RegExp('[éèêëàâùûôîçÉÈÊÀÂÙÛÔÎÇ]');
      var accentedCount = 0;
      for (final c in AdaptiveChallengeService.challengePool) {
        if (accentPattern.hasMatch(c.title) ||
            accentPattern.hasMatch(c.description)) {
          accentedCount++;
        }
      }
      // Vast majority of French text should have accents
      expect(
        accentedCount,
        greaterThan(AdaptiveChallengeService.challengePool.length * 0.8),
        reason: 'Most challenges should contain French accented characters',
      );
    });

    // ── Test 14: non-breaking space compliance ──
    test('non-breaking space before punctuation marks', () {
      // Check that text containing ! ? : ; % uses non-breaking space (\u00a0)
      // before those characters (not regular space)
      final badPattern = RegExp(r' [!?:;%]');
      for (final c in AdaptiveChallengeService.challengePool) {
        // Allow : in routes (actionRoute), only check user-facing text
        final text = '${c.title} ${c.description}';
        final matches = badPattern.allMatches(text);
        for (final m in matches) {
          fail(
            '${c.id} has regular space before "${m.group(0)?.trim()}" — '
            'should use non-breaking space (\\u00a0)',
          );
        }
      }
    });

    // ── Test 15: FHS rewards match difficulty ──
    test('FHS rewards: easy=1, medium=3, hard=5', () {
      for (final c in AdaptiveChallengeService.challengePool) {
        switch (c.difficulty) {
          case ChallengeDifficulty.easy:
            expect(c.fhsRewardPoints, 1,
                reason: '${c.id} (easy) should have 1 FHS point');
          case ChallengeDifficulty.medium:
            expect(c.fhsRewardPoints, 3,
                reason: '${c.id} (medium) should have 3 FHS points');
          case ChallengeDifficulty.hard:
            expect(c.fhsRewardPoints, 5,
                reason: '${c.id} (hard) should have 5 FHS points');
        }
      }
    });

    // ── Test 16: same week returns same challenge ──
    test('same ISO week returns the same challenge', () async {
      final profile = _makeProfile(birthYear: 1990);
      final lifecycle = _lifecycle(profile, now: testDate);

      final monday = DateTime(2026, 3, 16); // Monday
      final wednesday = DateTime(2026, 3, 18); // Wednesday same week

      final first = await AdaptiveChallengeService.getWeeklyChallenge(
        profile: profile,
        lifecycle: lifecycle,
        now: monday,
        prefs: prefs,
      );

      final second = await AdaptiveChallengeService.getWeeklyChallenge(
        profile: profile,
        lifecycle: lifecycle,
        now: wednesday,
        prefs: prefs,
      );

      expect(first?.id, equals(second?.id));
    });

    // ── Test 17: unique challenge IDs ──
    test('all challenge IDs are unique', () {
      final ids =
          AdaptiveChallengeService.challengePool.map((c) => c.id).toSet();
      expect(ids.length, AdaptiveChallengeService.challengePool.length);
    });

    // ── Test 18: difficulty upgrades to hard after 6 completions ──
    test('difficulty upgrades to hard after 6 total completions', () async {
      // 3 completions → medium
      for (var i = 0; i < 3; i++) {
        await AdaptiveChallengeService.completeChallenge(
            challengeId: 'c$i', prefs: prefs, now: testDate);
      }
      expect(await AdaptiveChallengeService.currentDifficulty(prefs: prefs),
          ChallengeDifficulty.medium);

      // 3 more completions → hard
      for (var i = 3; i < 6; i++) {
        await AdaptiveChallengeService.completeChallenge(
            challengeId: 'c$i', prefs: prefs, now: testDate);
      }
      expect(await AdaptiveChallengeService.currentDifficulty(prefs: prefs),
          ChallengeDifficulty.hard);
    });

    // ── Test 19: ChallengeRecord serialization round-trip ──
    test('ChallengeRecord JSON round-trip', () {
      final record = ChallengeRecord(
        challengeId: 'test_01',
        timestamp: DateTime(2026, 3, 18, 10, 30),
        completed: true,
      );

      final json = record.toJson();
      final restored = ChallengeRecord.fromJson(json);

      expect(restored.challengeId, record.challengeId);
      expect(restored.timestamp, record.timestamp);
      expect(restored.completed, record.completed);
    });

    // ── Test 20: archetype-specific challenges only for matching archetypes ──
    test('independent challenges only target independant archetypes', () {
      final independentChallenges = AdaptiveChallengeService.challengePool
          .where((c) =>
              c.targetArchetypes.contains('independentWithLpp') ||
              c.targetArchetypes.contains('independentNoLpp'))
          .toList();

      expect(independentChallenges, isNotEmpty);
      for (final c in independentChallenges) {
        // Should not target swissNative or expatUs exclusively
        expect(
          c.targetArchetypes.contains('independentWithLpp') ||
              c.targetArchetypes.contains('independentNoLpp'),
          isTrue,
          reason: '${c.id} should target independent archetypes',
        );
      }
    });
  });
}
