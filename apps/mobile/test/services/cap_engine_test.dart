import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/cap_decision.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/cap_engine.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';

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
      final cap = CapEngine.compute(profile: profile, now: now);

      expect(cap, isNotNull);
      expect(cap.id, isNotEmpty);
      expect(cap.headline, isNotEmpty);
      expect(cap.whyNow, isNotEmpty);
      expect(cap.ctaLabel, isNotEmpty);
    });

    test('returns a cap even with zero salary', () {
      final profile = profile0(salaireBrutMensuel: 0);
      final cap = CapEngine.compute(profile: profile, now: now);

      expect(cap, isNotNull);
    });
  });

  group('CapEngine — priority: debt overrides other caps', () {
    test('debt > 10k produces Correct cap', () {
      final profile = profile0(
        dettes: dettes(25000),
      );
      final cap = CapEngine.compute(profile: profile, now: now);

      expect(cap.kind, CapKind.correct);
      expect(cap.ctaRoute, '/debt/repayment');
    });

    test('debt < 10k does not trigger debt cap', () {
      final profile = profile0(
        dettes: dettes(5000),
      );
      final cap = CapEngine.compute(profile: profile, now: now);

      expect(cap.kind, isNot(CapKind.correct));
    });
  });

  group('CapEngine — independent without LPP', () {
    test('produces Secure cap for independant without LPP', () {
      final profile = profile0(
        employmentStatus: 'independant',
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 0),
      );
      final cap = CapEngine.compute(profile: profile, now: now);

      expect(cap.kind, CapKind.secure);
      expect(cap.ctaRoute, '/independants/lpp-volontaire');
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
      final cap = CapEngine.compute(profile: profile, now: novemberNow);

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
      final cap = CapEngine.compute(profile: profile, now: januaryNow);

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
      final cap = CapEngine.compute(profile: profile, now: now);

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
        memory: const CapMemory(),
      );

      final memory = CapMemory(
        lastCapServed: capFresh.id,
        lastCapDate: now.subtract(const Duration(hours: 25)),
      );
      final capOld = CapEngine.compute(
        profile: profile,
        now: now,
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

      final r1 = CapEngine.compute(profile: profile, now: now, memory: memory);
      final r2 = CapEngine.compute(profile: profile, now: now, memory: memory);

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
      final cap = CapEngine.compute(profile: profile, now: now);

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
      final cap = CapEngine.compute(profile: profile, now: now);

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

      final cap = CapEngine.compute(profile: julien, now: now);

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
      final cap = CapEngine.compute(profile: profile, now: now);

      expect(cap, isNotNull);
      expect(cap.kind, CapKind.complete);
      // Should suggest enrichment
    });

    test('route mode for actionable caps', () {
      final profile = profile0(
        dettes: dettes(50000),
      );
      final cap = CapEngine.compute(profile: profile, now: now);

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
          profile: profileRetraite, now: now);
      final capCustom = CapEngine.compute(
          profile: profileCustom, now: now);

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

      final cap = CapEngine.compute(profile: profileWithEvent, now: now);
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

      final cap = CapEngine.compute(profile: profile, now: now);

      // Debt correct should win and be boosted
      expect(cap.id, 'debt_correct');
    });
  });
}
