import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_detector.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_phase.dart';

// ────────────────────────────────────────────────────────────
//  LIFECYCLE DETECTOR TESTS — S57
// ────────────────────────────────────────────────────────────
//
// 20 tests covering:
//   - All 7 phases by age (typical midpoint)
//   - Exact boundary ages (25, 35, 45, 55, 60, 67)
//   - Golden couple: Julien (49) = consolidation, Lauren (43) = acceleration
//   - Null birthYear → default construction
//   - Retired status overrides age
//   - Early retirement target override
//   - detectFromBirthYear convenience method
//   - adapt() returns correct LifecycleAdaptation per phase
// ────────────────────────────────────────────────────────────

void main() {
  // Fixed date: 2026-03-18 for deterministic age computation.
  final now = DateTime(2026, 3, 18);

  // ── Helper: minimal CoachProfile ────────────────────────────
  CoachProfile makeProfile({
    int birthYear = 1990,
    String canton = 'VD',
    double salaire = 6000,
    String employment = 'salarie',
    int? targetRetirementAge,
    FinancialLiteracyLevel literacy = FinancialLiteracyLevel.beginner,
  }) {
    return CoachProfile(
      birthYear: birthYear,
      canton: canton,
      salaireBrutMensuel: salaire,
      employmentStatus: employment,
      targetRetirementAge: targetRetirementAge,
      financialLiteracyLevel: literacy,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2055),
        label: 'Retraite',
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  GOLDEN COUPLE
  // ══════════════════════════════════════════════════════════════

  group('LifecycleDetector — Golden Couple', () {
    // Julien: born 1977, age 49 in 2026 → consolidation
    test('Julien (birthYear 1977, age 49) → consolidation', () {
      final profile = makeProfile(birthYear: 1977, canton: 'VS', salaire: 122207 / 12);
      expect(
        LifecycleDetector.detect(profile, now: now),
        equals(LifecyclePhase.consolidation),
      );
    });

    // Lauren: born 1982, age 44 in 2026 → acceleration
    test('Lauren (birthYear 1982, age 44) → acceleration', () {
      final profile = makeProfile(birthYear: 1982, canton: 'VS', salaire: 67000 / 12);
      expect(
        LifecycleDetector.detect(profile, now: now),
        equals(LifecyclePhase.acceleration),
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  ALL 7 PHASES — TYPICAL AGES
  // ══════════════════════════════════════════════════════════════

  group('LifecycleDetector — All 7 phases by typical age', () {
    test('age 22 → demarrage', () {
      final profile = makeProfile(birthYear: 2004);
      expect(LifecycleDetector.detect(profile, now: now), LifecyclePhase.demarrage);
    });

    test('age 30 → construction', () {
      final profile = makeProfile(birthYear: 1996);
      expect(LifecycleDetector.detect(profile, now: now), LifecyclePhase.construction);
    });

    test('age 40 → acceleration', () {
      final profile = makeProfile(birthYear: 1986);
      expect(LifecycleDetector.detect(profile, now: now), LifecyclePhase.acceleration);
    });

    test('age 50 → consolidation', () {
      final profile = makeProfile(birthYear: 1976);
      expect(LifecycleDetector.detect(profile, now: now), LifecyclePhase.consolidation);
    });

    test('age 58 → transition', () {
      final profile = makeProfile(birthYear: 1968);
      expect(LifecycleDetector.detect(profile, now: now), LifecyclePhase.transition);
    });

    // age 64: within 10 years of default retirement (65), age >= 50 → transition override
    test('age 64 → transition (within 10 years of default retirement age 65)', () {
      final profile = makeProfile(birthYear: 1962);
      expect(LifecycleDetector.detect(profile, now: now), LifecyclePhase.transition);
    });

    // age 66: past retirement age 65 (yearsLeft < 0 → no override) → retraite
    test('age 66 → retraite (past default retirement age)', () {
      final profile = makeProfile(birthYear: 1960);
      // 2026 - 1960 = 66; yearsLeft = 65 - 66 = -1 → no override → age <= 67 → retraite
      expect(LifecycleDetector.detect(profile, now: now), LifecyclePhase.retraite);
    });

    test('age 75 → transmission', () {
      final profile = makeProfile(birthYear: 1951);
      expect(LifecycleDetector.detect(profile, now: now), LifecyclePhase.transmission);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  BOUNDARY AGES (exact boundaries per spec)
  // ══════════════════════════════════════════════════════════════

  group('LifecycleDetector — Boundary ages', () {
    // age 25 → first year of construction
    test('age 25 → construction (boundary)', () {
      final profile = makeProfile(birthYear: 2001);
      // 2026 - 2001 = 25 → construction (< 35)
      expect(LifecycleDetector.detect(profile, now: now), LifecyclePhase.construction);
    });

    // age 24 → last year of demarrage
    test('age 24 → still demarrage', () {
      final profile = makeProfile(birthYear: 2002);
      // 2026 - 2002 = 24 → demarrage (< 25)
      expect(LifecycleDetector.detect(profile, now: now), LifecyclePhase.demarrage);
    });

    // age 35 → first year of acceleration
    test('age 35 → acceleration (boundary)', () {
      final profile = makeProfile(birthYear: 1991);
      expect(LifecycleDetector.detect(profile, now: now), LifecyclePhase.acceleration);
    });

    // age 45 → first year of consolidation
    test('age 45 → consolidation (boundary)', () {
      final profile = makeProfile(birthYear: 1981);
      expect(LifecycleDetector.detect(profile, now: now), LifecyclePhase.consolidation);
    });

    // age 55 → first year of transition
    test('age 55 → transition (boundary)', () {
      final profile = makeProfile(birthYear: 1971);
      expect(LifecycleDetector.detect(profile, now: now), LifecyclePhase.transition);
    });

    // age 60 → still transition (boundary is <= 60)
    test('age 60 → transition (upper boundary)', () {
      final profile = makeProfile(birthYear: 1966);
      expect(LifecycleDetector.detect(profile, now: now), LifecyclePhase.transition);
    });

    // age 61: within 10 years of default retirement (65), age >= 50 → transition override
    test('age 61 → transition (within 10 years of default retirement age 65)', () {
      final profile = makeProfile(birthYear: 1965);
      // yearsLeft = 65 - 61 = 4 <= 10 && age >= 50 → transition override
      expect(LifecycleDetector.detect(profile, now: now), LifecyclePhase.transition);
    });

    // age 67 → retraite (well within retraite band 65-74)
    test('age 67 → retraite', () {
      final profile = makeProfile(birthYear: 1959);
      expect(LifecycleDetector.detect(profile, now: now), LifecyclePhase.retraite);
    });

    // age 68 → retraite (retraite band = 65-74, unified with LifecyclePhaseService)
    test('age 68 → retraite (within 65-74 band)', () {
      final profile = makeProfile(birthYear: 1958);
      expect(LifecycleDetector.detect(profile, now: now), LifecyclePhase.retraite);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  OVERRIDES
  // ══════════════════════════════════════════════════════════════

  group('LifecycleDetector — Overrides', () {
    test('retired status at age 60 → retraite (not transition)', () {
      final profile = makeProfile(birthYear: 1966, employment: 'retraite');
      expect(LifecycleDetector.detect(profile, now: now), LifecyclePhase.retraite);
    });

    test('retired status at age 78 → transmission', () {
      final profile = makeProfile(birthYear: 1948, employment: 'retraite');
      expect(LifecycleDetector.detect(profile, now: now), LifecyclePhase.transmission);
    });

    test('retired status at age 40 → retraite (edge case)', () {
      // Unusual but valid (early retirement or disability)
      final profile = makeProfile(birthYear: 1986, employment: 'retraite');
      expect(LifecycleDetector.detect(profile, now: now), LifecyclePhase.retraite);
    });

    test('early retirement target (58) at age 50 → transition (8 years)', () {
      final profile = makeProfile(birthYear: 1976, targetRetirementAge: 58);
      // age=50, target=58, years=8 <= 10 && age >= 50 → transition
      expect(LifecycleDetector.detect(profile, now: now), LifecyclePhase.transition);
    });

    test('early retirement target (60) at age 52 → transition (8 years)', () {
      final profile = makeProfile(birthYear: 1974, targetRetirementAge: 60);
      // age=52, target=60, years=8 <= 10 && age >= 50 → transition
      expect(LifecycleDetector.detect(profile, now: now), LifecyclePhase.transition);
    });

    test('early retirement target at age 48 → no override (consolidation)', () {
      final profile = makeProfile(birthYear: 1978, targetRetirementAge: 55);
      // age=48, years=7 but age < 50 → no override → consolidation
      expect(LifecycleDetector.detect(profile, now: now), LifecyclePhase.consolidation);
    });

    test('target retirement in 15 years at age 50 → no override (consolidation)', () {
      final profile = makeProfile(birthYear: 1976, targetRetirementAge: 65);
      // age=50, years=15 > 10 → no override → consolidation
      expect(LifecycleDetector.detect(profile, now: now), LifecyclePhase.consolidation);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  detectFromBirthYear — nullable birthYear variant
  // ══════════════════════════════════════════════════════════════

  group('LifecycleDetector.detectFromBirthYear', () {
    test('null birthYear → construction (safe default)', () {
      expect(
        LifecycleDetector.detectFromBirthYear(null, now: now),
        LifecyclePhase.construction,
      );
    });

    test('birthYear 1977 → consolidation', () {
      expect(
        LifecycleDetector.detectFromBirthYear(1977, now: now),
        LifecyclePhase.consolidation,
      );
    });

    test('birthYear 1982, employmentStatus retraite → retraite', () {
      expect(
        LifecycleDetector.detectFromBirthYear(
          1982,
          employmentStatus: 'retraite',
          now: now,
        ),
        LifecyclePhase.retraite,
      );
    });

    test('birthYear 1976, targetRetirementAge 58 → transition (override)', () {
      expect(
        LifecycleDetector.detectFromBirthYear(
          1976,
          targetRetirementAge: 58,
          now: now,
        ),
        LifecyclePhase.transition,
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  adapt() — LifecycleAdaptation shape
  // ══════════════════════════════════════════════════════════════

  group('LifecycleDetector.adapt()', () {
    test('every phase returns a non-null adaptation', () {
      for (final phase in LifecyclePhase.values) {
        final adaptation = LifecycleDetector.adapt(phase);
        expect(adaptation, isNotNull, reason: 'phase $phase should have adaptation');
      }
    });

    test('adaptation phase matches requested phase', () {
      for (final phase in LifecyclePhase.values) {
        final adaptation = LifecycleDetector.adapt(phase);
        expect(adaptation.phase, equals(phase));
      }
    });

    test('demarrage has lowest complexityLevel (< 0.5)', () {
      final adaptation = LifecycleDetector.adapt(LifecyclePhase.demarrage);
      expect(adaptation.complexityLevel, lessThan(0.5));
    });

    test('consolidation has high complexityLevel (>= 0.8)', () {
      final adaptation = LifecycleDetector.adapt(LifecyclePhase.consolidation);
      expect(adaptation.complexityLevel, greaterThanOrEqualTo(0.8));
    });

    test('complexityLevel is in valid range [0.0, 1.0] for all phases', () {
      for (final phase in LifecyclePhase.values) {
        final adaptation = LifecycleDetector.adapt(phase);
        expect(
          adaptation.complexityLevel,
          inInclusiveRange(0.0, 1.0),
          reason: 'phase $phase complexityLevel out of range',
        );
      }
    });

    test('every phase has at least 1 priorityTopic', () {
      for (final phase in LifecyclePhase.values) {
        final adaptation = LifecycleDetector.adapt(phase);
        expect(
          adaptation.priorityTopics,
          isNotEmpty,
          reason: 'phase $phase should have at least one priorityTopic',
        );
      }
    });

    test('every phase has at least 1 relevantScreen', () {
      for (final phase in LifecyclePhase.values) {
        final adaptation = LifecycleDetector.adapt(phase);
        expect(
          adaptation.relevantScreens,
          isNotEmpty,
          reason: 'phase $phase should have at least one relevantScreen',
        );
      }
    });

    test('toneGuidance is non-empty for all phases', () {
      for (final phase in LifecyclePhase.values) {
        final adaptation = LifecycleDetector.adapt(phase);
        expect(adaptation.toneGuidance, isNotEmpty, reason: 'phase $phase missing toneGuidance');
      }
    });

    test('demarrage priorityTopics include budget and pillar_3a', () {
      final adaptation = LifecycleDetector.adapt(LifecyclePhase.demarrage);
      expect(adaptation.priorityTopics, contains('budget'));
      expect(adaptation.priorityTopics, contains('pillar_3a'));
    });

    test('consolidation priorityTopics include lpp_buyback and retirement_planning', () {
      final adaptation = LifecycleDetector.adapt(LifecyclePhase.consolidation);
      expect(adaptation.priorityTopics, contains('lpp_buyback'));
      expect(adaptation.priorityTopics, contains('retirement_planning'));
    });

    test('transmission priorityTopics include estate_planning', () {
      final adaptation = LifecycleDetector.adapt(LifecyclePhase.transmission);
      expect(adaptation.priorityTopics, contains('estate_planning'));
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  TONE GUIDANCE — concrete LLM directives (not vague adjectives)
  // ══════════════════════════════════════════════════════════════

  group('LifecycleAdaptation — toneGuidance is concrete, not vague', () {
    // Vague adjectives that were previously used and must be gone.
    const vagueAdjectives = [
      'Encourageant',
      'Motivant',
      'Strat\u00e9gique et orient\u00e9 action',
      'S\u00e9r\u00e8ne et de soutien',
      'Sage et respectueux',
    ];

    test('demarrage toneGuidance references exact CHF amounts', () {
      final adaptation = LifecycleDetector.adapt(LifecyclePhase.demarrage);
      expect(adaptation.toneGuidance, contains('CHF'));
      expect(adaptation.toneGuidance, contains('direct'));
    });

    test('demarrage toneGuidance does not start with vague encouragement', () {
      final adaptation = LifecycleDetector.adapt(LifecyclePhase.demarrage);
      expect(adaptation.toneGuidance, isNot(startsWith('Encourageant')));
    });

    test('construction toneGuidance references CHF comparisons', () {
      final adaptation = LifecycleDetector.adapt(LifecyclePhase.construction);
      expect(adaptation.toneGuidance, contains('CHF'));
    });

    test('construction toneGuidance is not vague motivational copy', () {
      final adaptation = LifecycleDetector.adapt(LifecyclePhase.construction);
      expect(adaptation.toneGuidance, isNot(startsWith('Motivant')));
    });

    test('acceleration toneGuidance references percentages or deadlines', () {
      final adaptation = LifecycleDetector.adapt(LifecyclePhase.acceleration);
      final g = adaptation.toneGuidance;
      // Must contain at least one of: pourcentages, délais, calculs, montants
      final hasConcreteTerms = g.contains('pourcentages') ||
          g.contains('délais') ||
          g.contains('calculs') ||
          g.contains('montants');
      expect(hasConcreteTerms, isTrue,
          reason: 'acceleration toneGuidance must reference concrete terms');
    });

    test('consolidation toneGuidance contains contextual framing cues', () {
      final adaptation = LifecycleDetector.adapt(LifecyclePhase.consolidation);
      // Must contain "dans la norme" or "attention" — the contextual anchors
      final g = adaptation.toneGuidance;
      expect(
        g.contains('dans la norme') || g.contains('attention'),
        isTrue,
        reason:
            'consolidation toneGuidance must include "dans la norme" or "attention"',
      );
    });

    test('transition toneGuidance explicitly mentions no pressure', () {
      final adaptation = LifecycleDetector.adapt(LifecyclePhase.transition);
      expect(adaptation.toneGuidance.toLowerCase(), contains('pression'));
    });

    test('retraite toneGuidance forbids jargon and mandates short sentences', () {
      final adaptation = LifecycleDetector.adapt(LifecyclePhase.retraite);
      final g = adaptation.toneGuidance.toLowerCase();
      expect(g, contains('jargon'));
      expect(g, contains('phrases courtes'));
    });

    test('transmission toneGuidance references succession sensitivity', () {
      final adaptation = LifecycleDetector.adapt(LifecyclePhase.transmission);
      expect(adaptation.toneGuidance.toLowerCase(), contains('succession'));
    });

    test('no toneGuidance starts with a vague adjective from the old spec', () {
      for (final phase in LifecyclePhase.values) {
        final adaptation = LifecycleDetector.adapt(phase);
        for (final adj in vagueAdjectives) {
          expect(
            adaptation.toneGuidance,
            isNot(startsWith(adj)),
            reason: 'phase $phase toneGuidance must not start with "$adj"',
          );
        }
      }
    });

    test('toneGuidance length > 50 chars for all phases (concrete, not a word)', () {
      for (final phase in LifecyclePhase.values) {
        final adaptation = LifecycleDetector.adapt(phase);
        expect(
          adaptation.toneGuidance.length,
          greaterThan(50),
          reason: 'phase $phase toneGuidance is too short to be concrete',
        );
      }
    });
  });
}
