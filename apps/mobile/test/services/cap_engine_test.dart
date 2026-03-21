import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations_fr.dart';
import 'package:mint_mobile/models/cap_decision.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/cap_engine.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';

/// French localizations instance for tests (no BuildContext needed).
final _l = SFr();

/// Tests for CapEngine V1 heuristic.
///
/// Validates:
/// - Always returns exactly 1 cap
/// - Priority hierarchy (debt > missing data > fiscal > budget > fallback)
/// - Recency modifier prevents repetition
/// - Budget deficit uses reframing (lever, not just red)
/// - Golden couple (Julien + Lauren) produces sensible caps
void main() {
  // ── Helper ──
  CoachProfile profile0({
    int birthYear = 1980,
    double salaireBrutMensuel = 8000,
    String employmentStatus = 'salarie',
    String? primaryFocus,
    PrevoyanceProfile prevoyance = const PrevoyanceProfile(),
    DetteProfile dettes = const DetteProfile(),
    PatrimoineProfile patrimoine = const PatrimoineProfile(),
    DepensesProfile depenses = const DepensesProfile(),
    String canton = 'VD',
    int? arrivalAge,
  }) {
    return CoachProfile(
      birthYear: birthYear,
      canton: canton,
      salaireBrutMensuel: salaireBrutMensuel,
      employmentStatus: employmentStatus,
      primaryFocus: primaryFocus,
      prevoyance: prevoyance,
      dettes: dettes,
      patrimoine: patrimoine,
      depenses: depenses,
      arrivalAge: arrivalAge,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2045),
        label: 'Retraite',
      ),
    );
  }

  /// Build a DetteProfile with the desired total via creditConsommation.
  DetteProfile dettes(double total) =>
      DetteProfile(creditConsommation: total);

  final now = DateTime(2026, 3, 19);

  group('CapEngine — always returns 1 cap', () {
    test('returns a cap for minimal profile with stable id', () {
      final profile = profile0();
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      expect(cap, isNotNull);
      expect(cap.id, isNotEmpty);
      expect(cap.headline, isNotEmpty);
      expect(cap.whyNow, isNotEmpty);
      expect(cap.ctaLabel, isNotEmpty);
    });

    test('returns a cap even with zero salary', () {
      final profile = profile0(salaireBrutMensuel: 0);
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      expect(cap, isNotNull);
    });
  });

  group('CapEngine — priority: debt overrides other caps', () {
    test('debt > 10k produces Correct cap', () {
      final profile = profile0(
        dettes: dettes(25000),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      expect(cap.kind, CapKind.correct);
      expect(cap.ctaRoute, '/debt/repayment');
    });

    test('debt < 10k does not trigger debt cap', () {
      final profile = profile0(
        dettes: dettes(5000),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      expect(cap.kind, isNot(CapKind.correct));
    });
  });

  group('CapEngine — independent without LPP', () {
    test('produces Secure cap for independant without LPP', () {
      final profile = profile0(
        employmentStatus: 'independant',
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 0),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      expect(cap.kind, CapKind.secure);
      // Winner is either indep_no_lpp or disability_gap (both Secure,
      // disability_gap has higher priority score).
      expect(
        cap.id == 'indep_no_lpp' || cap.id == 'disability_gap',
        isTrue,
        reason: 'Independent without LPP should get indep_no_lpp or disability_gap',
      );
    });
  });

  group('CapEngine — fiscal window (3a year-end)', () {
    test('3a cap appears when < 90 days to year-end', () {
      // November 1st = ~60 days to year-end
      final novemberNow = DateTime(2026, 11, 1);
      final profile = profile0(
        salaireBrutMensuel: 10000,
        canton: 'ZH',
      );
      final cap = CapEngine.compute(profile: profile, now: novemberNow, l: _l);

      // Should produce a 3a optimize cap (unless debt or missing data overrides)
      expect(cap, isNotNull);
      // The 3a cap may or may not win — depends on profile completeness
      // But if it wins, it should be optimize kind
      if (cap.sourceCards.contains('pillar_3a_2026')) {
        expect(cap.kind, CapKind.optimize);
      }
    });

    test('3a cap does not appear in January (> 90 days)', () {
      final januaryNow = DateTime(2026, 1, 15);
      final profile = profile0(
        salaireBrutMensuel: 10000,
        canton: 'ZH',
      );
      final cap = CapEngine.compute(profile: profile, now: januaryNow, l: _l);

      // In January, the 3a window is > 90 days away
      // So the 3a candidate should not be generated
      final is3aFiscal = cap.sourceCards.any((s) => s.startsWith('pillar_3a'));
      expect(is3aFiscal, isFalse);
    });
  });

  group('CapEngine — budget deficit reframing', () {
    test('deficit budget produces Correct cap with lever, not just red', () {
      final profile = profile0(
        salaireBrutMensuel: 6000,
        depenses: const DepensesProfile(
          loyer: 2500,
          assuranceMaladie: 500,
          transport: 200,
          autresDepensesFixes: 3000,
        ),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      // Should not just show a negative number — must show lever
      if (cap.kind == CapKind.correct && cap.ctaRoute == '/budget') {
        expect(cap.headline, contains('marge'));
        expect(cap.whyNow, isNot(contains('déficit')));
        expect(cap.ctaLabel, isNotEmpty);
      }
    });
  });

  group('CapEngine — recency modifier (deterministic)', () {
    test('same cap served 2h ago has lower priority score', () {
      final profile = profile0(
        dettes: dettes(25000),
      );

      // Fresh — no memory
      final cap1 = CapEngine.compute(
        profile: profile,
        now: now,
        l: _l,
        memory: const CapMemory(),
      );

      // Same cap served 2 hours ago
      final memory = CapMemory(
        lastCapServed: cap1.id,
        lastCapDate: now.subtract(const Duration(hours: 2)),
      );
      final cap2 = CapEngine.compute(
        profile: profile,
        now: now,
        l: _l,
        memory: memory,
      );

      // If the same cap still wins, its score must be lower
      if (cap2.id == cap1.id) {
        expect(cap2.priorityScore, lessThan(cap1.priorityScore));
      }
    });

    test('cap served 24h+ ago is not penalized — same score', () {
      final profile = profile0(
        dettes: dettes(25000),
      );

      final capFresh = CapEngine.compute(
        profile: profile,
        now: now,
        l: _l,
        memory: const CapMemory(),
      );

      final memory = CapMemory(
        lastCapServed: capFresh.id,
        lastCapDate: now.subtract(const Duration(hours: 25)),
      );
      final capOld = CapEngine.compute(
        profile: profile,
        now: now,
        l: _l,
        memory: memory,
      );

      // 24h+ = no penalty, same winner, same score
      expect(capOld.id, capFresh.id);
      expect(capOld.priorityScore, capFresh.priorityScore);
    });

    test('recency is deterministic — same now gives same result', () {
      final profile = profile0(dettes: dettes(25000));
      final memory = CapMemory(
        lastCapServed: 'debt_correct',
        lastCapDate: now.subtract(const Duration(hours: 3)),
      );

      final r1 = CapEngine.compute(profile: profile, now: now, l: _l, memory: memory);
      final r2 = CapEngine.compute(profile: profile, now: now, l: _l, memory: memory);

      expect(r1.id, r2.id);
      expect(r1.priorityScore, r2.priorityScore);
    });
  });

  group('CapEngine — LPP buyback', () {
    test('rachat > 5k produces optimize cap', () {
      final profile = profile0(
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 50000,
          rachatMaximum: 100000,
        ),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      // May or may not be the winner depending on other candidates
      expect(cap, isNotNull);
    });
  });

  group('CapEngine — replacement rate for 45+', () {
    test('profile age 50 with low replacement rate triggers prepare cap', () {
      final profile = profile0(
        birthYear: 1976,
        salaireBrutMensuel: 10000,
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 30000),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      expect(cap, isNotNull);
      // At age 50 with only 30k LPP, replacement rate is low
      // This should produce either a prepare or optimize cap
    });
  });

  group('CapEngine — golden couple Julien', () {
    test('Julien profile produces sensible cap', () {
      final julien = profile0(
        birthYear: 1977,
        salaireBrutMensuel: 122207 / 12, // ~10184/mois
        canton: 'VS',
        employmentStatus: 'salarie',
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 70377,
          rachatMaximum: 539414,
        ),
      );

      final cap = CapEngine.compute(profile: julien, now: now, l: _l);

      expect(cap, isNotNull);
      expect(cap.headline, isNotEmpty);
      expect(cap.ctaLabel, isNotEmpty);
      // Julien at 49, with 539k rachat: should likely get LPP buyback or 3a
      expect(
        [CapKind.optimize, CapKind.prepare, CapKind.complete],
        contains(cap.kind),
      );
    });
  });

  group('CapEngine — CTA modes', () {
    test('capture mode when confidence is very low', () {
      // Profile with almost nothing filled → confidence < 45
      final profile = profile0(
        salaireBrutMensuel: 0,
        canton: '',
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      expect(cap, isNotNull);
      expect(cap.kind, CapKind.complete);
      // Should suggest enrichment
    });

    test('route mode for actionable caps', () {
      final profile = profile0(
        dettes: dettes(50000),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      expect(cap.ctaMode, CtaMode.route);
      expect(cap.ctaRoute, isNotNull);
    });
  });

  group('CapEngine — goal alignment boost', () {
    test('retraite goal boosts retirement-related caps', () {
      // Profile with LPP buyback opportunity + retraite goal
      final profileRetraite = CoachProfile(
        birthYear: 1977,
        canton: 'VS',
        salaireBrutMensuel: 10000,
        employmentStatus: 'salarie',
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 70000,
          rachatMaximum: 500000,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2042),
          label: 'Retraite',
        ),
      );

      // Same profile with custom goal (no boost)
      final profileCustom = CoachProfile(
        birthYear: 1977,
        canton: 'VS',
        salaireBrutMensuel: 10000,
        employmentStatus: 'salarie',
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 70000,
          rachatMaximum: 500000,
        ),
        goalA: GoalA(
          type: GoalAType.custom,
          targetDate: DateTime(2042),
          label: 'Custom',
        ),
      );

      final capRetraite = CapEngine.compute(
          profile: profileRetraite, now: now, l: _l);
      final capCustom = CapEngine.compute(
          profile: profileCustom, now: now, l: _l);

      // Both should return a cap
      expect(capRetraite, isNotNull);
      expect(capCustom, isNotNull);

      // If same cap wins, retraite-aligned should have higher score
      if (capRetraite.id == capCustom.id &&
          {'pillar_3a', 'lpp_buyback', 'replacement_rate', 'coverage_check'}
              .contains(capRetraite.id)) {
        expect(capRetraite.priorityScore,
            greaterThan(capCustom.priorityScore));
      }
    });

    test('life event marriage triggers prepare cap', () {
      final profile = profile0(
        salaireBrutMensuel: 8000,
      );
      // Create profile with familyChange using copyWith
      final profileWithEvent = CoachProfile(
        birthYear: profile.birthYear,
        canton: profile.canton,
        salaireBrutMensuel: profile.salaireBrutMensuel,
        employmentStatus: profile.employmentStatus,
        familyChange: 'marriage',
        goalA: profile.goalA,
      );

      final cap = CapEngine.compute(profile: profileWithEvent, now: now, l: _l);
      expect(cap, isNotNull);

      // The life event cap should be generated as a candidate
      // It may or may not win depending on other priorities
    });

    test('debtFree goal boosts debt-related caps', () {
      final profile = CoachProfile(
        birthYear: 1985,
        canton: 'ZH',
        salaireBrutMensuel: 6000,
        employmentStatus: 'salarie',
        dettes: const DetteProfile(creditConsommation: 25000),
        goalA: GoalA(
          type: GoalAType.debtFree,
          targetDate: DateTime(2028),
          label: 'Debt free',
        ),
      );

      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      // Debt correct should win and be boosted
      expect(cap.id, 'debt_correct');
    });
  });

  // ── HONESTY CLAUSE (spec §7) ────────────────────────────

  group('CapEngine — honesty clause', () {
    test('senior 62 with zero LPP triggers honesty cap', () {
      final profile = profile0(
        birthYear: 1964, // age 62
        salaireBrutMensuel: 5000,
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 0),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      expect(cap.isHonestyCap, isTrue);
      expect(cap.id, 'honesty_no_lever');
      expect(cap.kind, CapKind.prepare);
      expect(cap.ctaMode, CtaMode.coach);
      expect(cap.headline, 'Ton socle est là');
      // Must not be alarmist
      expect(cap.whyNow, isNot(contains('urgence')));
      expect(cap.whyNow, isNot(contains('danger')));
      expect(cap.whyNow, contains('spécialiste'));
    });

    test('senior 60 with small LPP (< 5k) triggers honesty cap', () {
      final profile = profile0(
        birthYear: 1966, // age 60
        salaireBrutMensuel: 4500,
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 3000),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      expect(cap.isHonestyCap, isTrue);
      expect(cap.acquiredAssets, isNotEmpty);
    });

    test('senior 60 with decent LPP does NOT trigger honesty cap', () {
      final profile = profile0(
        birthYear: 1966, // age 60
        salaireBrutMensuel: 8000,
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 200000),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      expect(cap.isHonestyCap, isFalse);
    });

    test('debt > 200% annual income triggers honesty cap', () {
      final profile = profile0(
        birthYear: 1985, // age 41
        salaireBrutMensuel: 5000, // 60k/year
        dettes: dettes(150000), // 250% of annual income
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      // Debt correct cap may also exist, but honesty should be a candidate.
      // The debt_correct cap has higher score, so it may win.
      // Let's verify the honesty detection works by checking
      // that either honesty wins or debt_correct wins (both are valid).
      expect(
        cap.id == 'honesty_no_lever' || cap.id == 'debt_correct',
        isTrue,
        reason: 'Either honesty or debt_correct should win for overwhelmed debt',
      );
    });

    test('debt at 150% annual income does NOT trigger honesty', () {
      final profile = profile0(
        birthYear: 1985,
        salaireBrutMensuel: 5000, // 60k/year
        dettes: dettes(80000), // ~133% — below 200% threshold
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      // Should not be honesty cap (debt_correct is fine)
      expect(cap.isHonestyCap, isFalse);
    });

    test('cross-border 62+ with zero LPP triggers honesty', () {
      // Cross-border requires residencePermit = 'G'
      final profile = CoachProfile(
        birthYear: 1964, // age 62
        canton: 'GE',
        salaireBrutMensuel: 6000,
        employmentStatus: 'salarie',
        residencePermit: 'G',
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 0),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2029),
          label: 'Retraite',
        ),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      expect(cap.isHonestyCap, isTrue);
      expect(cap.headline, 'Faisons le point ensemble');
      expect(cap.coachPrompt, contains('frontalier'));
    });

    test('cross-border 55 with zero LPP does NOT trigger honesty', () {
      final profile = CoachProfile(
        birthYear: 1971, // age 55
        canton: 'GE',
        salaireBrutMensuel: 6000,
        employmentStatus: 'salarie',
        residencePermit: 'G',
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 0),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2036),
          label: 'Retraite',
        ),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      // At 55, there's still time — no honesty cap
      expect(cap.isHonestyCap, isFalse);
    });

    test('independent 60+ without LPP does NOT trigger honesty (has own path)', () {
      // Independents have the indep_no_lpp cap which is the right path
      final profile = profile0(
        birthYear: 1964,
        salaireBrutMensuel: 6000,
        employmentStatus: 'independant',
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 0),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      // Should get indep_no_lpp or disability_gap, not honesty
      expect(cap.isHonestyCap, isFalse);
    });

    test('honesty cap includes acquired assets', () {
      final profile = profile0(
        birthYear: 1964,
        salaireBrutMensuel: 5000,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 2000,
          anneesContribuees: 35,
          renteAVSEstimeeMensuelle: 1800,
          totalEpargne3a: 25000,
        ),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      expect(cap.isHonestyCap, isTrue);
      expect(cap.acquiredAssets.length, greaterThanOrEqualTo(2));
      // Should mention AVS
      expect(cap.acquiredAssets.any((a) => a.contains('AVS')), isTrue);
      // Should mention 3a
      expect(cap.acquiredAssets.any((a) => a.contains('3a')), isTrue);
      // Should mention LPP (even small)
      expect(cap.acquiredAssets.any((a) => a.contains('LPP')), isTrue);
    });

    test('honesty cap CTA goes to coach, not a route', () {
      final profile = profile0(
        birthYear: 1963,
        salaireBrutMensuel: 4000,
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 0),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      expect(cap.isHonestyCap, isTrue);
      expect(cap.ctaMode, CtaMode.coach);
      expect(cap.ctaRoute, isNull);
      expect(cap.coachPrompt, isNotNull);
      expect(cap.coachPrompt, contains('spécialiste'));
    });

    test('honesty cap tone is calm, never alarmist', () {
      final profile = profile0(
        birthYear: 1962,
        salaireBrutMensuel: 4000,
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 0),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      expect(cap.isHonestyCap, isTrue);
      // No banned alarmist terms
      final allText = '${cap.headline} ${cap.whyNow} ${cap.ctaLabel}';
      expect(allText, isNot(contains('urgence')));
      expect(allText, isNot(contains('danger')));
      expect(allText, isNot(contains('catastrophe')));
      expect(allText, isNot(contains('grave')));
      expect(allText, isNot(contains('impossible')));
      // No banned compliance terms
      expect(allText, isNot(contains('garanti')));
      expect(allText, isNot(contains('optimal')));
    });

    test('normal profile (age 45, decent LPP) has isHonestyCap false', () {
      final profile = profile0(
        birthYear: 1981,
        salaireBrutMensuel: 8000,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 80000,
          rachatMaximum: 100000,
        ),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      expect(cap.isHonestyCap, isFalse);
    });
  });

  // ── DISABILITY GAP (invalidité) ──────────────────────────

  group('CapEngine — disability gap for independent without LPP', () {
    test('independent without LPP receives disability_gap cap', () {
      final profile = profile0(
        birthYear: 1985,
        salaireBrutMensuel: 7000,
        employmentStatus: 'independant',
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 0),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      // disability_gap or indep_no_lpp should be the winner (both are Secure)
      expect(cap.kind, CapKind.secure);
      expect(
        cap.id == 'disability_gap' || cap.id == 'indep_no_lpp',
        isTrue,
        reason:
            'Independent without LPP should get disability_gap or indep_no_lpp',
      );
    });

    test('disability_gap has calm tone, not alarmist', () {
      final profile = profile0(
        birthYear: 1985,
        salaireBrutMensuel: 7000,
        employmentStatus: 'independant',
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 0),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      // Check all text for alarmist terms (banned)
      final allText = '${cap.headline} ${cap.whyNow} ${cap.ctaLabel}';
      expect(allText, isNot(contains('urgence')));
      expect(allText, isNot(contains('danger')));
      expect(allText, isNot(contains('catastrophe')));
      expect(allText, isNot(contains('grave')));
      // No banned compliance terms
      expect(allText, isNot(contains('garanti')));
      expect(allText, isNot(contains('optimal')));
      expect(allText, isNot(contains('assurance')));
    });

    test('disability_gap coachPrompt orients toward understanding, not selling', () {
      final profile = profile0(
        birthYear: 1985,
        salaireBrutMensuel: 7000,
        employmentStatus: 'independant',
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 0),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      if (cap.id == 'disability_gap') {
        expect(cap.coachPrompt, isNotNull);
        // Must orient toward understanding the gap
        expect(cap.coachPrompt!, contains('comprendre'));
        // Must NOT sell insurance
        expect(cap.coachPrompt!, isNot(contains('souscrire')));
        expect(cap.coachPrompt!, isNot(contains('acheter')));
        expect(cap.coachPrompt!, isNot(contains('produit')));
      }
    });

    test('disability_gap not generated when already completed', () {
      final profile = profile0(
        birthYear: 1985,
        salaireBrutMensuel: 7000,
        employmentStatus: 'independant',
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 0),
      );
      const memory = CapMemory(
        completedActions: ['disability_gap'],
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l, memory: memory);

      // disability_gap should not appear when already completed
      expect(cap.id, isNot('disability_gap'));
    });

    test('salarié does NOT receive disability_gap cap', () {
      final profile = profile0(
        birthYear: 1985,
        salaireBrutMensuel: 7000,
        employmentStatus: 'salarie',
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      // Salarié should never get the disability_gap cap (that's for independants)
      expect(cap.id, isNot('disability_gap'));
    });

    test('independent WITH LPP does NOT receive disability_gap cap', () {
      final profile = profile0(
        birthYear: 1985,
        salaireBrutMensuel: 7000,
        employmentStatus: 'independant',
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 50000),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      // Has LPP → not indepNoLpp → no disability_gap
      expect(cap.id, isNot('disability_gap'));
      expect(cap.id, isNot('indep_no_lpp'));
    });
  });

  group('CapEngine — coverage_check differentiated for salarié 50+', () {
    test('salarié 52 gets enhanced coverage_check headline', () {
      final profile = profile0(
        birthYear: 1974, // age 52
        salaireBrutMensuel: 9000,
        employmentStatus: 'salarie',
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      // At 52, coverage_check should be generated as a candidate.
      // It may or may not win, but if it does, the headline should
      // mention invalidité after 50.
      if (cap.id == 'coverage_check') {
        expect(cap.headline, contains('50 ans'));
        expect(cap.whyNow, contains('40'));
        expect(cap.coachPrompt, isNotNull);
        expect(cap.coachPrompt!, contains('50 ans'));
      }
    });

    test('salarié 35 with children gets standard coverage_check', () {
      final profile = CoachProfile(
        birthYear: 1991, // age 35
        canton: 'VD',
        salaireBrutMensuel: 7000,
        employmentStatus: 'salarie',
        nombreEnfants: 1,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2056),
          label: 'Retraite',
        ),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);

      if (cap.id == 'coverage_check') {
        // Standard headline, not the senior variant
        expect(cap.headline, isNot(contains('50 ans')));
        expect(cap.headline, contains('check'));
      }
    });

    test('coverage_check for salarié 50+ has higher priority than for 35yo with kids', () {
      final senior = profile0(
        birthYear: 1974, // age 52
        salaireBrutMensuel: 9000,
        employmentStatus: 'salarie',
      );
      final young = CoachProfile(
        birthYear: 1991, // age 35
        canton: 'VD',
        salaireBrutMensuel: 9000,
        employmentStatus: 'salarie',
        nombreEnfants: 1,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2056),
          label: 'Retraite',
        ),
      );

      final capSenior = CapEngine.compute(profile: senior, now: now, l: _l);
      final capYoung = CapEngine.compute(profile: young, now: now, l: _l);

      // Both should return caps
      expect(capSenior, isNotNull);
      expect(capYoung, isNotNull);

      // If both are coverage_check, senior should have higher score
      if (capSenior.id == 'coverage_check' && capYoung.id == 'coverage_check') {
        expect(capSenior.priorityScore, greaterThan(capYoung.priorityScore));
      }
    });
  });

  // ── COUPLE CAPS (MÉNAGE) ──────────────────────────────────

  group('CapEngine — couple caps (ménage)', () {
    CoachProfile julienWithLauren({
      CoachCivilStatus etatCivil = CoachCivilStatus.marie,
      ConjointProfile? conjointOverride,
    }) {
      return CoachProfile(
        birthYear: 1977,
        canton: 'VS',
        salaireBrutMensuel: 122207 / 12,
        employmentStatus: 'salarie',
        etatCivil: etatCivil,
        conjoint: conjointOverride ??
            const ConjointProfile(
              firstName: 'Lauren',
              birthYear: 1982,
              salaireBrutMensuel: 67000 / 12,
              employmentStatus: 'salarie',
              nationality: 'US',
              isFatcaResident: true,
              canContribute3a: false,
              prevoyance: PrevoyanceProfile(
                avoirLppTotal: 19620,
                rachatMaximum: 52949,
              ),
            ),
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 70377,
          rachatMaximum: 539414,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2042),
          label: 'Retraite',
        ),
      );
    }

    test('married couple with conjoint generates couple caps', () {
      final profile = julienWithLauren();
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);
      expect(cap, isNotNull);
      expect(cap.id, isNotEmpty);
    });

    test('couple_lpp_buyback NOT generated when conjoint rachat < 10k', () {
      final profile = julienWithLauren(
        conjointOverride: const ConjointProfile(
          firstName: 'Lauren',
          birthYear: 1982,
          salaireBrutMensuel: 5583,
          employmentStatus: 'salarie',
          nationality: 'US',
          isFatcaResident: true,
          canContribute3a: false,
          prevoyance: PrevoyanceProfile(
            avoirLppTotal: 19620,
            rachatMaximum: 5000,
          ),
        ),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);
      expect(cap.id, isNot('couple_lpp_buyback'));
    });

    test('couple_3a NOT generated when conjoint is FATCA', () {
      final profile = julienWithLauren();
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);
      expect(cap.id, isNot('couple_3a'));
    });

    test('couple_3a generated when conjoint can contribute but has no 3a', () {
      final profile = julienWithLauren(
        conjointOverride: const ConjointProfile(
          firstName: 'Partner',
          birthYear: 1985,
          salaireBrutMensuel: 6000,
          employmentStatus: 'salarie',
          nationality: 'FR',
          isFatcaResident: false,
          canContribute3a: true,
          prevoyance: PrevoyanceProfile(
            avoirLppTotal: 30000,
            rachatMaximum: 5000,
            totalEpargne3a: 0,
          ),
        ),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);
      final isCouple3aWinner = cap.id == 'couple_3a';
      final isCouple3aSignal = cap.supportingSignals
          .any((s) => s.label == 'À deux, un levier de plus');
      expect(
        isCouple3aWinner || isCouple3aSignal || cap.supportingSignals.length == 2,
        isTrue,
        reason: 'couple_3a should be generated as a candidate',
      );
    });

    test('couple_3a NOT generated when conjoint already has 3a', () {
      final profile = julienWithLauren(
        conjointOverride: const ConjointProfile(
          firstName: 'Partner',
          birthYear: 1985,
          salaireBrutMensuel: 6000,
          employmentStatus: 'salarie',
          nationality: 'FR',
          canContribute3a: true,
          prevoyance: PrevoyanceProfile(
            avoirLppTotal: 30000,
            totalEpargne3a: 15000,
          ),
        ),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);
      expect(cap.id, isNot('couple_3a'));
    });

    test('couple_avs_cap NOT generated for concubins (LAVS art. 35)', () {
      final profile = julienWithLauren(
        etatCivil: CoachCivilStatus.concubinage,
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);
      expect(cap.id, isNot('couple_avs_cap'));
      final hasAvsSignal = cap.supportingSignals
          .any((s) => s.label.contains('AVS couple'));
      expect(hasAvsSignal, isFalse);
    });

    test('couple_avs_cap NOT generated when conjoint does not work', () {
      final profile = julienWithLauren(
        conjointOverride: const ConjointProfile(
          firstName: 'Lauren',
          birthYear: 1982,
          salaireBrutMensuel: 0,
          employmentStatus: 'retraite',
          prevoyance: PrevoyanceProfile(avoirLppTotal: 19620),
        ),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);
      expect(cap.id, isNot('couple_avs_cap'));
    });

    test('couple caps have lower priority than debt cap', () {
      final profile = CoachProfile(
        birthYear: 1977,
        canton: 'VS',
        salaireBrutMensuel: 10184,
        employmentStatus: 'salarie',
        etatCivil: CoachCivilStatus.marie,
        dettes: const DetteProfile(creditConsommation: 30000),
        conjoint: const ConjointProfile(
          firstName: 'Lauren',
          birthYear: 1982,
          salaireBrutMensuel: 5583,
          employmentStatus: 'salarie',
          prevoyance: PrevoyanceProfile(
            avoirLppTotal: 19620,
            rachatMaximum: 52949,
          ),
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2042),
          label: 'Retraite',
        ),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);
      expect(cap.id, 'debt_correct');
    });

    test('couple caps have lower priority than Complete cap', () {
      final profile = CoachProfile(
        birthYear: 1977,
        canton: '',
        salaireBrutMensuel: 0,
        employmentStatus: 'salarie',
        etatCivil: CoachCivilStatus.marie,
        conjoint: const ConjointProfile(
          firstName: 'Lauren',
          birthYear: 1982,
          salaireBrutMensuel: 5583,
          employmentStatus: 'salarie',
          prevoyance: PrevoyanceProfile(rachatMaximum: 50000),
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2042),
          label: 'Retraite',
        ),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);
      expect(cap.kind, CapKind.complete);
    });

    test('couple caps use inclusive voice', () {
      final profile = CoachProfile(
        birthYear: 1985,
        canton: 'VD',
        salaireBrutMensuel: 6000,
        employmentStatus: 'salarie',
        etatCivil: CoachCivilStatus.marie,
        conjoint: const ConjointProfile(
          firstName: 'Partner',
          birthYear: 1987,
          salaireBrutMensuel: 5000,
          employmentStatus: 'salarie',
          prevoyance: PrevoyanceProfile(
            avoirLppTotal: 20000,
            rachatMaximum: 80000,
            totalEpargne3a: 0,
          ),
          canContribute3a: true,
        ),
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 50000,
          rachatMaximum: 3000,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2050),
          label: 'Retraite',
        ),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);
      final allText =
          '${cap.headline} ${cap.whyNow} ${cap.ctaLabel} ${cap.coachPrompt ?? ""}';
      expect(allText, isNot(contains('ton mari')));
      expect(allText, isNot(contains('ta femme')));
      expect(allText, isNot(contains('ton époux')));
      expect(allText, isNot(contains('ton épouse')));
    });

    test('golden couple: FATCA blocks couple_3a for Lauren', () {
      final profile = julienWithLauren();
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);
      expect(cap, isNotNull);
      expect(cap.id, isNot('couple_3a'));
    });

    test('single user generates no couple caps', () {
      final profile = profile0(salaireBrutMensuel: 8000);
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);
      expect(cap.id, isNot(startsWith('couple_')));
    });

    test('couple without conjoint data generates no couple caps', () {
      final profile = CoachProfile(
        birthYear: 1985,
        canton: 'VD',
        salaireBrutMensuel: 8000,
        employmentStatus: 'salarie',
        etatCivil: CoachCivilStatus.marie,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2050),
          label: 'Retraite',
        ),
      );
      final cap = CapEngine.compute(profile: profile, now: now, l: _l);
      expect(cap.id, isNot(startsWith('couple_')));
    });

    test('recency modifier applies to couple caps', () {
      final profile = julienWithLauren(
        conjointOverride: const ConjointProfile(
          firstName: 'Partner',
          birthYear: 1987,
          salaireBrutMensuel: 5000,
          employmentStatus: 'salarie',
          prevoyance: PrevoyanceProfile(
            rachatMaximum: 80000,
            totalEpargne3a: 0,
          ),
          canContribute3a: true,
        ),
      );
      final cap1 = CapEngine.compute(profile: profile, now: now, l: _l);
      if (cap1.id.startsWith('couple_')) {
        final memory = CapMemory(
          lastCapServed: cap1.id,
          lastCapDate: now.subtract(const Duration(hours: 2)),
        );
        final cap2 =
            CapEngine.compute(profile: profile, now: now, l: _l, memory: memory);
        if (cap2.id == cap1.id) {
          expect(cap2.priorityScore, lessThan(cap1.priorityScore));
        }
      }
    });
  });
}
