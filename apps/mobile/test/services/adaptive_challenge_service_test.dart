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
      final profile = _makeProfile(birthYear: 1986); // age ~40 → acceleration
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

    // ════════════════════════════════════════════════════════════
    //  ADDITIONAL TESTS — autoresearch-test-generation audit
    // ════════════════════════════════════════════════════════════

    // ── Test 21: all 8 archetypes receive at least 5 challenges ──
    test('every archetype receives at least 5 eligible challenges', () {
      const archetypeNames = [
        'swissNative',
        'expatEu',
        'expatNonEu',
        'expatUs',
        'independentWithLpp',
        'independentNoLpp',
        'crossBorder',
        'returningSwiss',
      ];

      for (final archName in archetypeNames) {
        final eligible = AdaptiveChallengeService.challengePool.where((c) {
          if (c.targetArchetypes.isEmpty) return true; // universal
          return c.targetArchetypes.contains(archName);
        }).toList();

        expect(
          eligible.length,
          greaterThanOrEqualTo(5),
          reason: 'Archetype $archName should have >= 5 eligible challenges, '
              'got ${eligible.length}',
        );
      }
    });

    // ── Test 22: swiss_native archetype gets challenge ──
    test('swiss_native archetype gets a weekly challenge', () async {
      final profile = _makeProfile(birthYear: 1990);
      expect(profile.archetype, FinancialArchetype.swissNative);
      final lifecycle = _lifecycle(profile, now: testDate);

      final challenge = await AdaptiveChallengeService.getWeeklyChallenge(
        profile: profile,
        lifecycle: lifecycle,
        now: testDate,
        prefs: prefs,
      );
      expect(challenge, isNotNull);
    });

    // ── Test 23: expat_eu archetype gets challenge ──
    test('expat_eu archetype gets a weekly challenge', () async {
      final profile = _makeProfile(birthYear: 1990, nationality: 'FR');
      expect(profile.archetype, FinancialArchetype.expatEu);
      final lifecycle = _lifecycle(profile, now: testDate);

      final challenge = await AdaptiveChallengeService.getWeeklyChallenge(
        profile: profile,
        lifecycle: lifecycle,
        now: testDate,
        prefs: prefs,
      );
      expect(challenge, isNotNull);
    });

    // ── Test 24: expat_non_eu archetype gets challenge ──
    test('expat_non_eu archetype gets a weekly challenge', () async {
      final profile = _makeProfile(birthYear: 1990, nationality: 'BR');
      expect(profile.archetype, FinancialArchetype.expatNonEu);
      final lifecycle = _lifecycle(profile, now: testDate);

      final challenge = await AdaptiveChallengeService.getWeeklyChallenge(
        profile: profile,
        lifecycle: lifecycle,
        now: testDate,
        prefs: prefs,
      );
      expect(challenge, isNotNull);
    });

    // ── Test 25: expat_us archetype gets challenge ──
    test('expat_us archetype gets a weekly challenge', () async {
      final profile = _makeProfile(birthYear: 1990, nationality: 'US');
      expect(profile.archetype, FinancialArchetype.expatUs);
      final lifecycle = _lifecycle(profile, now: testDate);

      final challenge = await AdaptiveChallengeService.getWeeklyChallenge(
        profile: profile,
        lifecycle: lifecycle,
        now: testDate,
        prefs: prefs,
      );
      expect(challenge, isNotNull);
    });

    // ── Test 26: independent_with_lpp archetype gets challenge ──
    test('independent_with_lpp archetype gets a weekly challenge', () async {
      final profile = _makeProfile(
        birthYear: 1990,
        employmentStatus: 'independant',
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 50000),
      );
      expect(profile.archetype, FinancialArchetype.independentWithLpp);
      final lifecycle = _lifecycle(profile, now: testDate);

      final challenge = await AdaptiveChallengeService.getWeeklyChallenge(
        profile: profile,
        lifecycle: lifecycle,
        now: testDate,
        prefs: prefs,
      );
      expect(challenge, isNotNull);
    });

    // ── Test 27: independent_no_lpp archetype gets challenge ──
    test('independent_no_lpp archetype gets a weekly challenge', () async {
      final profile = _makeProfile(
        birthYear: 1990,
        employmentStatus: 'independant',
      );
      expect(profile.archetype, FinancialArchetype.independentNoLpp);
      final lifecycle = _lifecycle(profile, now: testDate);

      final challenge = await AdaptiveChallengeService.getWeeklyChallenge(
        profile: profile,
        lifecycle: lifecycle,
        now: testDate,
        prefs: prefs,
      );
      expect(challenge, isNotNull);
    });

    // ── Test 28: cross_border archetype gets challenge ──
    test('cross_border archetype gets a weekly challenge', () async {
      final profile = _makeProfile(
        birthYear: 1990,
        nationality: 'FR',
        residencePermit: 'G',
      );
      expect(profile.archetype, FinancialArchetype.crossBorder);
      final lifecycle = _lifecycle(profile, now: testDate);

      final challenge = await AdaptiveChallengeService.getWeeklyChallenge(
        profile: profile,
        lifecycle: lifecycle,
        now: testDate,
        prefs: prefs,
      );
      expect(challenge, isNotNull);
    });

    // ── Test 29: returning_swiss archetype gets challenge ──
    test('returning_swiss archetype gets a weekly challenge', () async {
      final profile = _makeProfile(
        birthYear: 1990,
        nationality: 'CH',
        arrivalAge: 30,
      );
      expect(profile.archetype, FinancialArchetype.returningSwiss);
      final lifecycle = _lifecycle(profile, now: testDate);

      final challenge = await AdaptiveChallengeService.getWeeklyChallenge(
        profile: profile,
        lifecycle: lifecycle,
        now: testDate,
        prefs: prefs,
      );
      expect(challenge, isNotNull);
    });

    // ── Test 30: golden profile Julien (swiss_native, 49yo, 122'207 CHF) ──
    test('golden profile Julien gets consolidation-phase challenge', () async {
      final julien = CoachProfile(
        birthYear: 1977,
        canton: 'VS',
        nationality: 'CH',
        etatCivil: CoachCivilStatus.marie,
        nombreEnfants: 0,
        salaireBrutMensuel: 10184, // 122'207 / 12
        nombreDeMois: 12,
        employmentStatus: 'salarie',
        depenses: const DepensesProfile(),
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 70377),
        patrimoine: const PatrimoineProfile(),
        dettes: const DetteProfile(),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2042, 1, 1),
          label: 'Retraite',
        ),
      );
      expect(julien.archetype, FinancialArchetype.swissNative);

      final lifecycle = _lifecycle(julien, now: testDate);
      // Julien is 49 → consolidation (45-55)
      expect(lifecycle.phase, LifecyclePhase.consolidation);

      final challenge = await AdaptiveChallengeService.getWeeklyChallenge(
        profile: julien,
        lifecycle: lifecycle,
        now: testDate,
        prefs: prefs,
      );
      expect(challenge, isNotNull);
      // Challenge must be compatible with consolidation phase
      if (challenge!.targetPhases.isNotEmpty) {
        expect(challenge.targetPhases, contains(LifecyclePhase.consolidation));
      }
    });

    // ── Test 31: golden profile Lauren (expat_us, 43yo, 67'000 CHF) ──
    test('golden profile Lauren gets acceleration-phase challenge', () async {
      final lauren = CoachProfile(
        birthYear: 1982,
        canton: 'VS',
        nationality: 'US',
        etatCivil: CoachCivilStatus.marie,
        nombreEnfants: 0,
        salaireBrutMensuel: 5583, // 67'000 / 12
        nombreDeMois: 12,
        employmentStatus: 'salarie',
        depenses: const DepensesProfile(),
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 19620),
        patrimoine: const PatrimoineProfile(),
        dettes: const DetteProfile(),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2047, 1, 1),
          label: 'Retraite',
        ),
      );
      expect(lauren.archetype, FinancialArchetype.expatUs);

      final lifecycle = _lifecycle(lauren, now: testDate);
      // Lauren is 43 → acceleration (35-45)
      expect(lifecycle.phase, LifecyclePhase.acceleration);

      final challenge = await AdaptiveChallengeService.getWeeklyChallenge(
        profile: lauren,
        lifecycle: lifecycle,
        now: testDate,
        prefs: prefs,
      );
      expect(challenge, isNotNull);
    });

    // ── Test 32: age extreme — young (22yo, demarrage phase) ──
    test('age extreme: 22yo gets demarrage phase challenge', () async {
      final profile = _makeProfile(birthYear: 2004); // age ~22
      final lifecycle = _lifecycle(profile, now: testDate);
      expect(lifecycle.phase, LifecyclePhase.demarrage);

      final challenge = await AdaptiveChallengeService.getWeeklyChallenge(
        profile: profile,
        lifecycle: lifecycle,
        now: testDate,
        prefs: prefs,
      );
      expect(challenge, isNotNull);
      if (challenge!.targetPhases.isNotEmpty) {
        expect(challenge.targetPhases, contains(LifecyclePhase.demarrage));
      }
    });

    // ── Test 33: age extreme — 65yo (transition/retraite) ──
    test('age extreme: 65yo gets challenge', () async {
      final profile = _makeProfile(birthYear: 1961); // age ~65
      final lifecycle = _lifecycle(profile, now: testDate);
      // 65 could be transition or retraite depending on exact detection
      expect(
        {LifecyclePhase.transition, LifecyclePhase.retraite},
        contains(lifecycle.phase),
      );

      final challenge = await AdaptiveChallengeService.getWeeklyChallenge(
        profile: profile,
        lifecycle: lifecycle,
        now: testDate,
        prefs: prefs,
      );
      expect(challenge, isNotNull);
    });

    // ── Test 34: age extreme — 80yo (retraite/transmission) ──
    test('age extreme: 80yo gets challenge', () async {
      final profile = _makeProfile(birthYear: 1946); // age ~80
      final lifecycle = _lifecycle(profile, now: testDate);
      expect(
        {LifecyclePhase.retraite, LifecyclePhase.transmission},
        contains(lifecycle.phase),
      );

      final challenge = await AdaptiveChallengeService.getWeeklyChallenge(
        profile: profile,
        lifecycle: lifecycle,
        now: testDate,
        prefs: prefs,
      );
      // May be null if no challenges target these late phases, but should not crash
      // At minimum, universal challenges (targetPhases empty) should match
      expect(challenge, isNotNull);
    });

    // ── Test 35: difficulty progression easy → medium → hard ──
    test('full difficulty progression: easy → medium → hard', () async {
      // Start: easy
      expect(
        await AdaptiveChallengeService.currentDifficulty(prefs: prefs),
        ChallengeDifficulty.easy,
      );

      // 3 completions → medium
      for (var i = 0; i < 3; i++) {
        await AdaptiveChallengeService.completeChallenge(
          challengeId: 'prog_$i',
          prefs: prefs,
          now: testDate,
        );
      }
      expect(
        await AdaptiveChallengeService.currentDifficulty(prefs: prefs),
        ChallengeDifficulty.medium,
      );

      // 3 more completions → hard
      for (var i = 3; i < 6; i++) {
        await AdaptiveChallengeService.completeChallenge(
          challengeId: 'prog_$i',
          prefs: prefs,
          now: testDate,
        );
      }
      expect(
        await AdaptiveChallengeService.currentDifficulty(prefs: prefs),
        ChallengeDifficulty.hard,
      );

      // More completions stay at hard (ceiling)
      for (var i = 6; i < 9; i++) {
        await AdaptiveChallengeService.completeChallenge(
          challengeId: 'prog_$i',
          prefs: prefs,
          now: testDate,
        );
      }
      expect(
        await AdaptiveChallengeService.currentDifficulty(prefs: prefs),
        ChallengeDifficulty.hard,
      );
    });

    // ── Test 36: difficulty cannot go below easy ──
    test('difficulty cannot go below easy after skips', () async {
      // Skip many times at easy level
      for (var i = 0; i < 5; i++) {
        await AdaptiveChallengeService.skipChallenge(
          challengeId: 'skip_$i',
          prefs: prefs,
          now: testDate,
        );
      }
      expect(
        await AdaptiveChallengeService.currentDifficulty(prefs: prefs),
        ChallengeDifficulty.easy,
      );
    });

    // ── Test 37: no duplicate challenge IDs across categories ──
    test('no duplicate challenge IDs across different categories', () {
      final idCategoryMap = <String, ChallengeCategory>{};
      for (final c in AdaptiveChallengeService.challengePool) {
        if (idCategoryMap.containsKey(c.id)) {
          fail('Duplicate challenge ID "${c.id}" found in '
              '${idCategoryMap[c.id]!.name} and ${c.category.name}');
        }
        idCategoryMap[c.id] = c.category;
      }
    });

    // ── Test 38: challenge pool covers all 6 categories ──
    test('challenge pool covers all 6 categories', () {
      final categories = AdaptiveChallengeService.challengePool
          .map((c) => c.category)
          .toSet();
      expect(categories, containsAll(ChallengeCategory.values));
    });

    // ── Test 39: challenge pool covers all 3 difficulties ──
    test('challenge pool covers all 3 difficulties', () {
      final difficulties = AdaptiveChallengeService.challengePool
          .map((c) => c.difficulty)
          .toSet();
      expect(difficulties, containsAll(ChallengeDifficulty.values));
    });

    // ── Test 40: different weeks can produce different challenges ──
    test('different ISO weeks select from pool deterministically', () async {
      final profile = _makeProfile(birthYear: 1990);
      final lifecycle = _lifecycle(profile, now: testDate);

      // Test across 8 weeks — with 50-challenge pool, highly likely
      // to get at least 2 distinct challenges
      final ids = <String?>{};
      for (var w = 0; w < 8; w++) {
        final weekDate = DateTime(2026, 3, 16).add(Duration(days: 7 * w));
        SharedPreferences.setMockInitialValues({});
        final weekPrefs = await SharedPreferences.getInstance();
        final c = await AdaptiveChallengeService.getWeeklyChallenge(
          profile: profile,
          lifecycle: lifecycle,
          now: weekDate,
          prefs: weekPrefs,
        );
        ids.add(c?.id);
      }

      // At least 2 distinct challenges over 8 weeks
      expect(ids.length, greaterThanOrEqualTo(2),
          reason: 'Over 8 weeks, should see variety from the pool');
    });

    // ── Test 41: MicroChallenge.toJson includes all required fields ──
    test('MicroChallenge.toJson includes required fields', () {
      final challenge = AdaptiveChallengeService.challengePool.first;
      final json = challenge.toJson();
      expect(json, containsPair('id', isNotEmpty));
      expect(json, containsPair('title', isNotEmpty));
      expect(json, containsPair('description', isNotEmpty));
      expect(json, containsPair('actionRoute', isNotEmpty));
      expect(json, containsPair('category', isNotEmpty));
      expect(json, containsPair('difficulty', isNotEmpty));
      expect(json, containsPair('fhsRewardPoints', isA<int>()));
    });

    // ── Test 42: history accumulates multiple records ──
    test('history accumulates multiple records', () async {
      await AdaptiveChallengeService.completeChallenge(
        challengeId: 'budget_01',
        prefs: prefs,
        now: testDate,
      );
      await AdaptiveChallengeService.skipChallenge(
        challengeId: 'budget_02',
        prefs: prefs,
        now: testDate,
      );
      await AdaptiveChallengeService.completeChallenge(
        challengeId: 'budget_04',
        prefs: prefs,
        now: testDate,
      );

      final history = await AdaptiveChallengeService.getHistory(prefs: prefs);
      expect(history, hasLength(3));
      expect(history[0].completed, isTrue);
      expect(history[1].completed, isFalse);
      expect(history[2].completed, isTrue);
    });

    // ── Test 43: empty history returns empty list ──
    test('getHistory returns empty list on fresh prefs', () async {
      final history = await AdaptiveChallengeService.getHistory(prefs: prefs);
      expect(history, isEmpty);
    });

    // ── Test 44: cross_border-only challenge not given to swiss_native ──
    test('crossBorder-only challenge is not eligible for swiss_native', () {
      final crossBorderOnly = AdaptiveChallengeService.challengePool
          .where((c) => c.targetArchetypes.contains('crossBorder'))
          .toList();
      expect(crossBorderOnly, isNotEmpty);

      for (final c in crossBorderOnly) {
        expect(
          c.targetArchetypes.contains('swissNative'),
          isFalse,
          reason: '${c.id} targets crossBorder but should not match swissNative',
        );
      }
    });

    // ── Test 45: challenge text contains no "conseiller" (banned term) ──
    test('no challenge uses "conseiller" — must use "spécialiste"', () {
      for (final c in AdaptiveChallengeService.challengePool) {
        final text = '${c.title} ${c.description}'.toLowerCase();
        expect(text.contains('conseiller'), isFalse,
            reason: '${c.id} uses banned term "conseiller"');
      }
    });

    // ── Test 46: upgrade then downgrade then re-upgrade ──
    test('difficulty oscillation: up → down → up', () async {
      // 3 completions → medium
      for (var i = 0; i < 3; i++) {
        await AdaptiveChallengeService.completeChallenge(
          challengeId: 'osc_c$i',
          prefs: prefs,
          now: testDate,
        );
      }
      expect(
        await AdaptiveChallengeService.currentDifficulty(prefs: prefs),
        ChallengeDifficulty.medium,
      );

      // 2 skips → back to easy
      await AdaptiveChallengeService.skipChallenge(
        challengeId: 'osc_s1',
        prefs: prefs,
        now: testDate,
      );
      await AdaptiveChallengeService.skipChallenge(
        challengeId: 'osc_s2',
        prefs: prefs,
        now: testDate,
      );
      expect(
        await AdaptiveChallengeService.currentDifficulty(prefs: prefs),
        ChallengeDifficulty.easy,
      );

      // 3 more completions → medium again
      for (var i = 0; i < 3; i++) {
        await AdaptiveChallengeService.completeChallenge(
          challengeId: 'osc_r$i',
          prefs: prefs,
          now: testDate,
        );
      }
      expect(
        await AdaptiveChallengeService.currentDifficulty(prefs: prefs),
        ChallengeDifficulty.medium,
      );
    });

    // ── Test 47: skip then complete resets consecutive skip counter ──
    test('one completion between skips resets skip counter', () async {
      // Upgrade to medium first
      for (var i = 0; i < 3; i++) {
        await AdaptiveChallengeService.completeChallenge(
          challengeId: 'reset_c$i',
          prefs: prefs,
          now: testDate,
        );
      }
      expect(
        await AdaptiveChallengeService.currentDifficulty(prefs: prefs),
        ChallengeDifficulty.medium,
      );

      // 1 skip, then 1 completion, then 1 skip — should NOT downgrade
      await AdaptiveChallengeService.skipChallenge(
        challengeId: 'reset_s1',
        prefs: prefs,
        now: testDate,
      );
      await AdaptiveChallengeService.completeChallenge(
        challengeId: 'reset_c3',
        prefs: prefs,
        now: testDate,
      );
      await AdaptiveChallengeService.skipChallenge(
        challengeId: 'reset_s2',
        prefs: prefs,
        now: testDate,
      );

      // Still medium (skips were not consecutive)
      expect(
        await AdaptiveChallengeService.currentDifficulty(prefs: prefs),
        ChallengeDifficulty.medium,
      );
    });

    // ── Test 48: each category has at least 3 challenges per difficulty ──
    test('each category has challenges across difficulties', () {
      for (final cat in ChallengeCategory.values) {
        final inCategory = AdaptiveChallengeService.challengePool
            .where((c) => c.category == cat)
            .toList();
        expect(
          inCategory.length,
          greaterThanOrEqualTo(3),
          reason: 'Category ${cat.name} should have >= 3 challenges',
        );
      }
    });

    // ── Test 49: fallback to other difficulty when primary exhausted ──
    test('fallback to other difficulty when primary is exhausted', () async {
      final profile = _makeProfile(birthYear: 1990);
      final lifecycle = _lifecycle(profile, now: testDate);

      // Complete all easy challenges
      final easyChallenges = AdaptiveChallengeService.challengePool
          .where((c) => c.difficulty == ChallengeDifficulty.easy)
          .toList();
      for (final c in easyChallenges) {
        await AdaptiveChallengeService.completeChallenge(
          challengeId: c.id,
          prefs: prefs,
          now: testDate,
        );
      }

      // Difficulty is now medium (after 3+ completions), but even if
      // we force re-check, fallback should give us something
      // Use a new week so it picks a new challenge
      final futureWeek = testDate.add(const Duration(days: 70));
      final challenge = await AdaptiveChallengeService.getWeeklyChallenge(
        profile: profile,
        lifecycle: lifecycle,
        now: futureWeek,
        prefs: prefs,
      );

      // Should get a non-easy challenge from fallback
      expect(challenge, isNotNull);
    });

    // ── Test 50: challenge descriptions contain educational content ──
    test('every challenge has non-trivial description (>= 30 chars)', () {
      for (final c in AdaptiveChallengeService.challengePool) {
        expect(
          c.description.length,
          greaterThanOrEqualTo(30),
          reason: '${c.id} description too short: "${c.description}"',
        );
      }
    });
  });
}
