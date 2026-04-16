import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/lifecycle_phase_service.dart';
import 'package:mint_mobile/services/content_adapter_service.dart';

// ────────────────────────────────────────────────────────────
//  LIFECYCLE PHASE SERVICE + CONTENT ADAPTER TESTS — S57
// ────────────────────────────────────────────────────────────
//
// 25+ tests covering:
//   - Golden couple: Julien (49) = Consolidation, Lauren (43) = Accélération
//   - All 7 phases by age
//   - Boundary ages (22, 28, 35, 45, 55, 65, 75)
//   - Override: retired user bypasses age-based detection
//   - Override: early retirement target shifts to transition
//   - Content adaptation per phase
//   - Priority ordering and situational boosts
//   - Edge cases (very young, very old, missing fields)
// ────────────────────────────────────────────────────────────

void main() {
  // ── Helper: create a minimal CoachProfile for testing ───────
  CoachProfile makeProfile({
    int birthYear = 1990,
    String canton = 'VD',
    double salaire = 6000,
    String employment = 'salarie',
    int? targetRetirementAge,
    CoachCivilStatus etatCivil = CoachCivilStatus.celibataire,
    int nombreEnfants = 0,
    String? nationality,
    int? arrivalAge,
    ConjointProfile? conjoint,
    PatrimoineProfile patrimoine = const PatrimoineProfile(),
    DetteProfile dettes = const DetteProfile(),
    FinancialLiteracyLevel literacy = FinancialLiteracyLevel.beginner,
  }) {
    return CoachProfile(
      birthYear: birthYear,
      canton: canton,
      salaireBrutMensuel: salaire,
      employmentStatus: employment,
      targetRetirementAge: targetRetirementAge,
      etatCivil: etatCivil,
      nombreEnfants: nombreEnfants,
      nationality: nationality,
      arrivalAge: arrivalAge,
      conjoint: conjoint,
      patrimoine: patrimoine,
      dettes: dettes,
      financialLiteracyLevel: literacy,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2055),
        label: 'Retraite',
      ),
    );
  }

  // Fixed "now" for deterministic tests: 2026-03-18
  final now = DateTime(2026, 3, 18);

  group('LifecyclePhaseService — Golden Couple', () {
    // ── JULIEN: born 1977, age 49 → Consolidation ──────────────
    test('Julien (49, swiss_native, 122k) = Consolidation', () {
      final profile = makeProfile(
        birthYear: 1977,
        canton: 'VS',
        salaire: 122207 / 12, // Monthly
        nationality: 'CH',
        etatCivil: CoachCivilStatus.marie,
        nombreEnfants: 0,
      );

      final result = LifecyclePhaseService.detect(profile, now: now);

      expect(result.phase, equals(LifecyclePhase.consolidation));
      expect(result.age, equals(49));
      expect(result.yearsToRetirement, equals(16)); // 65 - 49
      expect(result.tone, equals(LifecycleTone.reassuring));
    });

    // ── LAUREN: born 1982, age 43 → Accélération ───────────────
    test('Lauren (43, expat_us, 67k) = Accélération', () {
      final profile = makeProfile(
        birthYear: 1982,
        canton: 'VS',
        salaire: 67000 / 12,
        nationality: 'US',
        arrivalAge: 25,
        etatCivil: CoachCivilStatus.marie,
      );

      final result = LifecyclePhaseService.detect(profile, now: now);

      expect(result.phase, equals(LifecyclePhase.acceleration));
      expect(result.age, equals(44)); // 2026 - 1982
      expect(result.yearsToRetirement, equals(21));
      expect(result.tone, equals(LifecycleTone.empowering));
    });
  });

  group('LifecyclePhaseService — All 7 Phases', () {
    // ── Phase 1: Démarrage (22-27) ──────────────────────────────
    test('age 24 → Démarrage', () {
      final profile = makeProfile(birthYear: 2002);
      final result = LifecyclePhaseService.detect(profile, now: now);
      expect(result.phase, equals(LifecyclePhase.demarrage));
      expect(result.tone, equals(LifecycleTone.encouraging));
    });

    // ── Phase 2: Construction (28-34) ───────────────────────────
    test('age 30 → Construction', () {
      final profile = makeProfile(birthYear: 1996);
      final result = LifecyclePhaseService.detect(profile, now: now);
      expect(result.phase, equals(LifecyclePhase.construction));
      expect(result.tone, equals(LifecycleTone.encouraging));
    });

    // ── Phase 3: Accélération (38-44) ───────────────────────────
    test('age 40 → Accélération', () {
      final profile = makeProfile(birthYear: 1986);
      final result = LifecyclePhaseService.detect(profile, now: now);
      expect(result.phase, equals(LifecyclePhase.acceleration));
      expect(result.tone, equals(LifecycleTone.empowering));
    });

    // ── Phase 4: Consolidation (45-54) ──────────────────────────
    test('age 50 → Consolidation', () {
      final profile = makeProfile(birthYear: 1976);
      final result = LifecyclePhaseService.detect(profile, now: now);
      expect(result.phase, equals(LifecyclePhase.consolidation));
      expect(result.tone, equals(LifecycleTone.reassuring));
    });

    // ── Phase 5: Transition (55-64) ─────────────────────────────
    test('age 60 → Transition', () {
      final profile = makeProfile(birthYear: 1966);
      final result = LifecyclePhaseService.detect(profile, now: now);
      expect(result.phase, equals(LifecyclePhase.transition));
      expect(result.tone, equals(LifecycleTone.reassuring));
    });

    // ── Phase 6: Retraite (65-74) ───────────────────────────────
    test('age 70 → Retraite', () {
      final profile = makeProfile(birthYear: 1956);
      final result = LifecyclePhaseService.detect(profile, now: now);
      expect(result.phase, equals(LifecyclePhase.retraite));
      expect(result.tone, equals(LifecycleTone.simple));
    });

    // ── Phase 7: Transmission (75+) ─────────────────────────────
    test('age 80 → Transmission', () {
      final profile = makeProfile(birthYear: 1946);
      final result = LifecyclePhaseService.detect(profile, now: now);
      expect(result.phase, equals(LifecyclePhase.transmission));
      expect(result.tone, equals(LifecycleTone.simple));
    });
  });

  group('LifecyclePhaseService — Boundary Ages', () {
    test('age 22 → Démarrage (youngest)', () {
      final profile = makeProfile(birthYear: 2004);
      final result = LifecyclePhaseService.detect(profile, now: now);
      expect(result.phase, equals(LifecyclePhase.demarrage));
    });

    test('age 24 → still Démarrage', () {
      final profile = makeProfile(birthYear: 2002);
      final result = LifecyclePhaseService.detect(profile, now: now);
      expect(result.phase, equals(LifecyclePhase.demarrage));
    });

    test('age 25 → Construction (boundary, aligned with LifecycleDetector)', () {
      final profile = makeProfile(birthYear: 2001);
      final result = LifecyclePhaseService.detect(profile, now: now);
      expect(result.phase, equals(LifecyclePhase.construction));
    });

    test('age 34 → Construction (25-34 band)', () {
      final profile = makeProfile(birthYear: 1992);
      final result = LifecyclePhaseService.detect(profile, now: now);
      expect(result.phase, equals(LifecyclePhase.construction));
    });

    test('age 35 → Accélération (boundary)', () {
      final profile = makeProfile(birthYear: 1991);
      final result = LifecyclePhaseService.detect(profile, now: now);
      expect(result.phase, equals(LifecyclePhase.acceleration));
    });

    test('age 45 → Consolidation (boundary)', () {
      final profile = makeProfile(birthYear: 1981);
      final result = LifecyclePhaseService.detect(profile, now: now);
      expect(result.phase, equals(LifecyclePhase.consolidation));
    });

    test('age 55 → Transition (boundary)', () {
      final profile = makeProfile(birthYear: 1971);
      final result = LifecyclePhaseService.detect(profile, now: now);
      expect(result.phase, equals(LifecyclePhase.transition));
    });

    test('age 65 → Retraite (boundary)', () {
      final profile = makeProfile(birthYear: 1961);
      final result = LifecyclePhaseService.detect(profile, now: now);
      expect(result.phase, equals(LifecyclePhase.retraite));
    });

    test('age 75 → Transmission (boundary)', () {
      final profile = makeProfile(birthYear: 1951);
      final result = LifecyclePhaseService.detect(profile, now: now);
      expect(result.phase, equals(LifecyclePhase.transmission));
    });

    test('age 95 → Transmission (very old)', () {
      final profile = makeProfile(birthYear: 1931);
      final result = LifecyclePhaseService.detect(profile, now: now);
      expect(result.phase, equals(LifecyclePhase.transmission));
    });
  });

  group('LifecyclePhaseService — Overrides', () {
    test('retired user at age 60 → Retraite (not Transition)', () {
      final profile = makeProfile(
        birthYear: 1966,
        employment: 'retraite',
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      expect(result.phase, equals(LifecyclePhase.retraite));
    });

    test('retired user at age 80 → Transmission', () {
      final profile = makeProfile(
        birthYear: 1946,
        employment: 'retraite',
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      expect(result.phase, equals(LifecyclePhase.transmission));
    });

    test('early retirement target (58) at age 50 → Transition', () {
      final profile = makeProfile(
        birthYear: 1976,
        targetRetirementAge: 58,
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      // age=50, targetRetirement=58, yearsToRetirement=8 ≤ 10 && age >= 50
      expect(result.phase, equals(LifecyclePhase.transition));
    });

    test('early retirement target (58) at age 45 → no override (Consolidation)', () {
      final profile = makeProfile(
        birthYear: 1981,
        targetRetirementAge: 58,
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      // age=45, target=58, years=13 > 10 → no override
      expect(result.phase, equals(LifecyclePhase.consolidation));
    });

    test('early retirement target (60) at age 52 → Transition (8 years)', () {
      final profile = makeProfile(
        birthYear: 1974,
        targetRetirementAge: 60,
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      // age=52, target=60, years=8 ≤ 10 && age >= 50
      expect(result.phase, equals(LifecyclePhase.transition));
    });
  });

  group('LifecyclePhaseService — Priorities', () {
    test('Démarrage priorities include open_3a and emergency fund', () {
      final profile = makeProfile(birthYear: 2002);
      final result = LifecyclePhaseService.detect(profile, now: now);
      final keys = result.priorities.map((p) => p.key).toList();
      expect(keys, contains('open_3a'));
      expect(keys, contains('build_emergency_fund'));
    });

    test('Consolidation priorities include retirement planning', () {
      final profile = makeProfile(birthYear: 1977);
      final result = LifecyclePhaseService.detect(profile, now: now);
      final keys = result.priorities.map((p) => p.key).toList();
      expect(keys, contains('plan_retirement_scenario'));
      expect(keys, contains('rente_vs_capital'));
    });

    test('high debt adds debt_reduction as top priority', () {
      final profile = makeProfile(
        birthYear: 1986,
        dettes: const DetteProfile(creditConsommation: 25000),
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      // debt_reduction has weight 1.0 → should be first
      expect(result.priorities.first.key, equals('debt_reduction'));
    });

    test('concubinage adds protection priority', () {
      final profile = makeProfile(
        birthYear: 1986,
        etatCivil: CoachCivilStatus.concubinage,
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      final keys = result.priorities.map((p) => p.key).toList();
      expect(keys, contains('concubinage_protection'));
    });

    test('married with conjoint adds couple retirement sync', () {
      final profile = makeProfile(
        birthYear: 1977,
        etatCivil: CoachCivilStatus.marie,
        conjoint: const ConjointProfile(
          birthYear: 1982,
        ),
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      final keys = result.priorities.map((p) => p.key).toList();
      expect(keys, contains('couple_retirement_sync'));
    });
  });

  group('LifecyclePhaseService — Complexity & Literacy', () {
    test('Démarrage + beginner → basic complexity', () {
      final profile = makeProfile(
        birthYear: 2002,
        literacy: FinancialLiteracyLevel.beginner,
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      expect(result.complexity, equals(LifecycleComplexity.basic));
    });

    test('Démarrage + advanced → intermediate complexity', () {
      final profile = makeProfile(
        birthYear: 2002,
        literacy: FinancialLiteracyLevel.advanced,
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      expect(result.complexity, equals(LifecycleComplexity.intermediate));
    });

    test('Consolidation + intermediate → advanced complexity', () {
      final profile = makeProfile(
        birthYear: 1977,
        literacy: FinancialLiteracyLevel.intermediate,
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      expect(result.complexity, equals(LifecycleComplexity.advanced));
    });

    test('Transmission + beginner → basic complexity', () {
      final profile = makeProfile(birthYear: 1946);
      final result = LifecyclePhaseService.detect(profile, now: now);
      expect(result.complexity, equals(LifecycleComplexity.basic));
    });
  });

  group('ContentAdapterService', () {
    test('Démarrage adaptation hides advanced features', () {
      final profile = makeProfile(birthYear: 2002);
      final phaseResult = LifecyclePhaseService.detect(profile, now: now);
      final adaptation = ContentAdapterService.adapt(phaseResult, profile);

      expect(adaptation.showAdvancedProjections, isFalse);
      expect(adaptation.showTaxOptimization, isFalse);
      expect(adaptation.showLppBuyback, isFalse);
      expect(adaptation.showWithdrawalSequencing, isFalse);
      expect(adaptation.showEstatePlanning, isFalse);
      expect(adaptation.vocabularyLevel, equals('simple'));
      expect(adaptation.maxReadingLevel, equals(6));
    });

    test('Consolidation adaptation shows full features', () {
      final profile = makeProfile(
        birthYear: 1977,
        literacy: FinancialLiteracyLevel.intermediate,
      );
      final phaseResult = LifecyclePhaseService.detect(profile, now: now);
      final adaptation = ContentAdapterService.adapt(phaseResult, profile);

      expect(adaptation.showAdvancedProjections, isTrue);
      expect(adaptation.showTaxOptimization, isTrue);
      expect(adaptation.showLppBuyback, isTrue);
      expect(adaptation.showWithdrawalSequencing, isTrue);
      expect(adaptation.showEstatePlanning, isTrue);
      expect(adaptation.vocabularyLevel, equals('expert'));
    });

    test('Transition dashboard focuses on retirement', () {
      final profile = makeProfile(birthYear: 1966);
      final phaseResult = LifecyclePhaseService.detect(profile, now: now);
      final adaptation = ContentAdapterService.adapt(phaseResult, profile);

      expect(adaptation.dashboardFocusOrder.first, equals('retirement'));
      expect(adaptation.dashboardFocusOrder, contains('withdrawal'));
    });

    test('Retraite dashboard focuses on budget', () {
      final profile = makeProfile(birthYear: 1956);
      final phaseResult = LifecyclePhaseService.detect(profile, now: now);
      final adaptation = ContentAdapterService.adapt(phaseResult, profile);

      expect(adaptation.dashboardFocusOrder.first, equals('budget'));
    });

    test('coachSystemPromptAddition includes phase and priorities', () {
      final profile = makeProfile(birthYear: 1977);
      final phaseResult = LifecyclePhaseService.detect(profile, now: now);
      final adaptation = ContentAdapterService.adapt(phaseResult, profile);

      expect(adaptation.coachSystemPromptAddition, contains('consolidation'));
      expect(adaptation.coachSystemPromptAddition, contains('49'));
      expect(adaptation.coachSystemPromptAddition, contains('plan_retirement_scenario'));
    });

    test('greeting key follows naming convention', () {
      final profile = makeProfile(birthYear: 2002);
      final phaseResult = LifecyclePhaseService.detect(profile, now: now);
      final adaptation = ContentAdapterService.adapt(phaseResult, profile);

      expect(adaptation.greetingKey, equals('lifecycleGreetingDemarrage'));
    });
  });

  group('LifecyclePhaseService — yearsToRetirement', () {
    test('yearsToRetirement uses default 65 when no target', () {
      final profile = makeProfile(birthYear: 1977);
      final result = LifecyclePhaseService.detect(profile, now: now);
      expect(result.yearsToRetirement, equals(16)); // 65 - 49
    });

    test('yearsToRetirement uses custom target', () {
      final profile = makeProfile(
        birthYear: 1977,
        targetRetirementAge: 60,
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      expect(result.yearsToRetirement, equals(11)); // 60 - 49
    });

    test('yearsToRetirement can be negative (past retirement)', () {
      final profile = makeProfile(
        birthYear: 1956,
        targetRetirementAge: 65,
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      expect(result.yearsToRetirement, equals(-5)); // 65 - 70
    });
  });
}
