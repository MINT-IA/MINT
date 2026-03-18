import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/lifecycle_phase_service.dart';
import 'package:mint_mobile/services/content_adapter_service.dart';

// ────────────────────────────────────────────────────────────
//  CONTENT ADAPTER SERVICE TESTS — Feature visibility, dashboard
//  focus, vocabulary, reading level for ALL 7 lifecycle phases.
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
    String? residencePermit,
    ConjointProfile? conjoint,
    PatrimoineProfile patrimoine = const PatrimoineProfile(),
    DetteProfile dettes = const DetteProfile(),
    PrevoyanceProfile prevoyance = const PrevoyanceProfile(),
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
      residencePermit: residencePermit,
      conjoint: conjoint,
      patrimoine: patrimoine,
      dettes: dettes,
      prevoyance: prevoyance,
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

  // ── Helper: get adaptation for a given birthYear + literacy ──
  ContentAdaptation adaptFor({
    required int birthYear,
    FinancialLiteracyLevel literacy = FinancialLiteracyLevel.beginner,
    String employment = 'salarie',
  }) {
    final profile = makeProfile(
      birthYear: birthYear,
      literacy: literacy,
      employment: employment,
    );
    final phaseResult = LifecyclePhaseService.detect(profile, now: now);
    return ContentAdapterService.adapt(phaseResult, profile);
  }

  // ════════════════════════════════════════════════════════════
  //  TASK 1: Feature visibility for ALL 7 phases
  // ════════════════════════════════════════════════════════════

  group('ContentAdapterService — Feature visibility per phase', () {
    test('Demarrage (age 24): LPP buyback=false, withdrawal=false, estate=false', () {
      final a = adaptFor(birthYear: 2002);
      expect(a.showLppBuyback, isFalse);
      expect(a.showWithdrawalSequencing, isFalse);
      expect(a.showEstatePlanning, isFalse);
      expect(a.showAdvancedProjections, isFalse);
      expect(a.showTaxOptimization, isFalse);
    });

    test('Construction (age 30): LPP buyback=false, withdrawal=false, estate=false', () {
      final a = adaptFor(birthYear: 1996);
      expect(a.showLppBuyback, isFalse);
      expect(a.showWithdrawalSequencing, isFalse);
      expect(a.showEstatePlanning, isFalse);
      expect(a.showAdvancedProjections, isFalse);
      expect(a.showTaxOptimization, isTrue);
    });

    test('Acceleration (age 40): LPP buyback=true, withdrawal=false, estate=false', () {
      final a = adaptFor(birthYear: 1986);
      expect(a.showLppBuyback, isTrue);
      expect(a.showWithdrawalSequencing, isFalse);
      expect(a.showEstatePlanning, isFalse);
      expect(a.showAdvancedProjections, isTrue);
      expect(a.showTaxOptimization, isTrue);
    });

    test('Consolidation (age 50): LPP buyback=true, withdrawal=true, estate=true', () {
      final a = adaptFor(birthYear: 1976);
      expect(a.showLppBuyback, isTrue);
      expect(a.showWithdrawalSequencing, isTrue);
      expect(a.showEstatePlanning, isTrue);
      expect(a.showAdvancedProjections, isTrue);
      expect(a.showTaxOptimization, isTrue);
    });

    test('Transition (age 60): LPP buyback=true, withdrawal=true, estate=true', () {
      final a = adaptFor(birthYear: 1966);
      expect(a.showLppBuyback, isTrue);
      expect(a.showWithdrawalSequencing, isTrue);
      expect(a.showEstatePlanning, isTrue);
      expect(a.showAdvancedProjections, isTrue);
      expect(a.showTaxOptimization, isTrue);
    });

    test('Retraite (age 70): LPP buyback=false, withdrawal=true, estate=true', () {
      final a = adaptFor(birthYear: 1956);
      expect(a.showLppBuyback, isFalse);
      expect(a.showWithdrawalSequencing, isTrue);
      expect(a.showEstatePlanning, isTrue);
      expect(a.showAdvancedProjections, isTrue);
      expect(a.showTaxOptimization, isTrue);
    });

    test('Transmission (age 80): LPP buyback=false, withdrawal=false, estate=true', () {
      final a = adaptFor(birthYear: 1946);
      expect(a.showLppBuyback, isFalse);
      expect(a.showWithdrawalSequencing, isFalse);
      expect(a.showEstatePlanning, isTrue);
      expect(a.showAdvancedProjections, isFalse);
      expect(a.showTaxOptimization, isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  TASK 1: Dashboard focus order for ALL 7 phases
  // ════════════════════════════════════════════════════════════

  group('ContentAdapterService — Dashboard focus order per phase', () {
    test('Demarrage dashboard: budget first', () {
      final a = adaptFor(birthYear: 2002);
      expect(a.dashboardFocusOrder, equals(['budget', '3a', 'education', 'goals', 'insurance']));
    });

    test('Construction dashboard: 3a first', () {
      final a = adaptFor(birthYear: 1996);
      expect(a.dashboardFocusOrder, equals(['3a', 'housing', 'patrimoine', 'budget', 'insurance']));
    });

    test('Acceleration dashboard: lpp first', () {
      final a = adaptFor(birthYear: 1986);
      expect(a.dashboardFocusOrder, equals(['lpp', 'tax', 'patrimoine', '3a', 'retirement']));
    });

    test('Consolidation dashboard: retirement first', () {
      final a = adaptFor(birthYear: 1976);
      expect(a.dashboardFocusOrder, equals(['retirement', 'lpp', 'rente_vs_capital', 'tax', 'patrimoine']));
    });

    test('Transition dashboard: retirement first', () {
      final a = adaptFor(birthYear: 1966);
      expect(a.dashboardFocusOrder, equals(['retirement', 'withdrawal', 'rente_vs_capital', 'budget', 'estate']));
    });

    test('Retraite dashboard: budget first', () {
      final a = adaptFor(birthYear: 1956);
      expect(a.dashboardFocusOrder, equals(['budget', 'withdrawal', 'lamal', 'estate', 'patrimoine']));
    });

    test('Transmission dashboard: estate first', () {
      final a = adaptFor(birthYear: 1946);
      expect(a.dashboardFocusOrder, equals(['estate', 'donation', 'simplify', 'budget', 'lamal']));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  TASK 1: Vocabulary level
  // ════════════════════════════════════════════════════════════

  group('ContentAdapterService — Vocabulary level', () {
    test('basic complexity → simple vocabulary', () {
      // Demarrage + beginner = basic
      final a = adaptFor(birthYear: 2002, literacy: FinancialLiteracyLevel.beginner);
      expect(a.vocabularyLevel, equals('simple'));
    });

    test('intermediate complexity → standard vocabulary', () {
      // Retraite + beginner = intermediate
      final a = adaptFor(birthYear: 1956, literacy: FinancialLiteracyLevel.beginner);
      expect(a.vocabularyLevel, equals('standard'));
    });

    test('advanced complexity → expert vocabulary', () {
      // Consolidation + intermediate = advanced
      final a = adaptFor(birthYear: 1976, literacy: FinancialLiteracyLevel.intermediate);
      expect(a.vocabularyLevel, equals('expert'));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  TASK 1: Max reading level
  // ════════════════════════════════════════════════════════════

  group('ContentAdapterService — Max reading level', () {
    test('basic complexity → reading level 6', () {
      final a = adaptFor(birthYear: 2002, literacy: FinancialLiteracyLevel.beginner);
      expect(a.maxReadingLevel, equals(6));
    });

    test('intermediate complexity → reading level 10', () {
      final a = adaptFor(birthYear: 1956, literacy: FinancialLiteracyLevel.beginner);
      expect(a.maxReadingLevel, equals(10));
    });

    test('advanced complexity → reading level 14', () {
      final a = adaptFor(birthYear: 1976, literacy: FinancialLiteracyLevel.intermediate);
      expect(a.maxReadingLevel, equals(14));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  TASK 1: Greeting key for all 7 phases
  // ════════════════════════════════════════════════════════════

  group('ContentAdapterService — Greeting keys', () {
    test('each phase generates correct greeting key', () {
      final expectedKeys = {
        2002: 'lifecycleGreetingDemarrage',
        1996: 'lifecycleGreetingConstruction',
        1986: 'lifecycleGreetingAcceleration',
        1976: 'lifecycleGreetingConsolidation',
        1966: 'lifecycleGreetingTransition',
        1956: 'lifecycleGreetingRetraite',
        1946: 'lifecycleGreetingTransmission',
      };

      for (final entry in expectedKeys.entries) {
        final a = adaptFor(birthYear: entry.key);
        expect(a.greetingKey, equals(entry.value),
            reason: 'birthYear=${entry.key} should produce ${entry.value}');
      }
    });
  });

  // ════════════════════════════════════════════════════════════
  //  TASK 2: Archetype-aware priorities
  // ════════════════════════════════════════════════════════════

  group('LifecyclePhaseService — Archetype priorities', () {
    test('expat_us → fatca_compliance priority added', () {
      final profile = makeProfile(
        birthYear: 1986,
        nationality: 'US',
        arrivalAge: 25,
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      final keys = result.priorities.map((p) => p.key).toList();
      expect(keys, contains('fatca_compliance'));
    });

    test('expat_eu → avs_gap_analysis priority added', () {
      final profile = makeProfile(
        birthYear: 1986,
        nationality: 'FR',
        arrivalAge: 30,
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      final keys = result.priorities.map((p) => p.key).toList();
      expect(keys, contains('avs_gap_analysis'));
    });

    test('expat_non_eu → avs_gap_analysis priority added', () {
      final profile = makeProfile(
        birthYear: 1986,
        nationality: 'BR',
        arrivalAge: 30,
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      final keys = result.priorities.map((p) => p.key).toList();
      expect(keys, contains('avs_gap_analysis'));
    });

    test('independent_no_lpp → max_3a priority boosted', () {
      final profile = makeProfile(
        birthYear: 1986,
        employment: 'independant',
        prevoyance: const PrevoyanceProfile(), // No LPP
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      final keys = result.priorities.map((p) => p.key).toList();
      // max_3a should appear (from archetype boost)
      expect(keys.where((k) => k == 'max_3a').length, greaterThanOrEqualTo(1));
    });

    test('cross_border (permis G) → source_tax_optimization priority added', () {
      final profile = makeProfile(
        birthYear: 1986,
        residencePermit: 'G',
        nationality: 'FR',
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      final keys = result.priorities.map((p) => p.key).toList();
      expect(keys, contains('source_tax_optimization'));
    });

    test('returning_swiss → lpp_buyback priority boosted', () {
      final profile = makeProfile(
        birthYear: 1986,
        nationality: 'CH',
        arrivalAge: 30, // Arrived late = returning Swiss
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      final keys = result.priorities.map((p) => p.key).toList();
      // lpp_buyback appears both from acceleration phase AND archetype boost
      expect(keys.where((k) => k == 'lpp_buyback').length, greaterThanOrEqualTo(2));
    });

    test('swiss_native → no extra archetype priority', () {
      final profile = makeProfile(
        birthYear: 1986,
        nationality: 'CH',
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      final keys = result.priorities.map((p) => p.key).toList();
      expect(keys, isNot(contains('fatca_compliance')));
      expect(keys, isNot(contains('avs_gap_analysis')));
      expect(keys, isNot(contains('source_tax_optimization')));
    });

    test('fatca_compliance has high weight (1.05)', () {
      final profile = makeProfile(
        birthYear: 1986,
        nationality: 'US',
        arrivalAge: 25,
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      final fatca = result.priorities.firstWhere((p) => p.key == 'fatca_compliance');
      expect(fatca.weight, equals(1.05));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  TASK 3: Edge case tests
  // ════════════════════════════════════════════════════════════

  group('LifecyclePhaseService — Edge cases', () {
    // (a) Debt threshold boundary: 10000 → NO safe mode, 10001 → YES safe mode
    test('debt = 10000 → NO debt_reduction priority (boundary)', () {
      final profile = makeProfile(
        birthYear: 1986,
        dettes: const DetteProfile(creditConsommation: 10000),
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      final keys = result.priorities.map((p) => p.key).toList();
      expect(keys, isNot(contains('debt_reduction')));
    });

    test('debt = 10001 → YES debt_reduction priority (safe mode)', () {
      final profile = makeProfile(
        birthYear: 1986,
        dettes: const DetteProfile(creditConsommation: 10001),
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      final keys = result.priorities.map((p) => p.key).toList();
      expect(keys, contains('debt_reduction'));
      // debt_reduction weight 1.1 should make it first
      expect(result.priorities.first.key, equals('debt_reduction'));
    });

    // (c) Children + age >= 55 → NO children_planning priority
    test('children + age >= 55 → NO children_planning priority', () {
      final profile = makeProfile(
        birthYear: 1971, // age 55
        nombreEnfants: 2,
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      final keys = result.priorities.map((p) => p.key).toList();
      expect(keys, isNot(contains('children_planning')));
    });

    test('children + age 54 → YES children_planning priority', () {
      final profile = makeProfile(
        birthYear: 1972, // age 54
        nombreEnfants: 2,
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      final keys = result.priorities.map((p) => p.key).toList();
      expect(keys, contains('children_planning'));
    });

    // (d) Married without conjoint → NO couple_retirement_sync
    test('married without conjoint → NO couple_retirement_sync', () {
      final profile = makeProfile(
        birthYear: 1977,
        etatCivil: CoachCivilStatus.marie,
        conjoint: null,
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      final keys = result.priorities.map((p) => p.key).toList();
      expect(keys, isNot(contains('couple_retirement_sync')));
    });

    test('married WITH conjoint → YES couple_retirement_sync', () {
      final profile = makeProfile(
        birthYear: 1977,
        etatCivil: CoachCivilStatus.marie,
        conjoint: const ConjointProfile(birthYear: 1982),
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      final keys = result.priorities.map((p) => p.key).toList();
      expect(keys, contains('couple_retirement_sync'));
    });

    // Debt split across multiple sources
    test('debt split across leasing + autresDettes crossing threshold', () {
      final profile = makeProfile(
        birthYear: 1986,
        dettes: const DetteProfile(leasing: 6000, autresDettes: 4001),
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      final keys = result.priorities.map((p) => p.key).toList();
      expect(keys, contains('debt_reduction'));
    });

    // Homeowner gets mortgage_optimization
    test('homeowner → mortgage_optimization priority', () {
      final profile = makeProfile(
        birthYear: 1986,
        patrimoine: const PatrimoineProfile(immobilier: 500000),
      );
      final result = LifecyclePhaseService.detect(profile, now: now);
      final keys = result.priorities.map((p) => p.key).toList();
      expect(keys, contains('mortgage_optimization'));
    });

    test('non-homeowner → no mortgage_optimization priority', () {
      final profile = makeProfile(birthYear: 1986);
      final result = LifecyclePhaseService.detect(profile, now: now);
      final keys = result.priorities.map((p) => p.key).toList();
      expect(keys, isNot(contains('mortgage_optimization')));
    });
  });
}
