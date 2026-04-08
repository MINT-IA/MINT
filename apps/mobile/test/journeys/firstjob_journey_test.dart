// firstjob_journey_test.dart
//
// Integration test: firstJob life event journey.
// Traces intent chip → IntentRouter → CapSequence → premier eclairage →
// calculator routes → plan generation entry.
//
// Uses Julien golden couple profile (CLAUDE.md §8) for all assertions.
// Standalone — no shared state with other journey tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations_fr.dart';
import 'package:mint_mobile/models/cap_sequence.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/cap_sequence_engine.dart';
import 'package:mint_mobile/services/coach/intent_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────
//  TEST LOCALE
// ─────────────────────────────────────────────────────────────────

final _l = SFr();

// ─────────────────────────────────────────────────────────────────
//  JULIEN GOLDEN PROFILE (CLAUDE.md §8)
// ─────────────────────────────────────────────────────────────────
//
//  Julien: 49 ans, VS (Sion), 122'207 CHF/an brut, swiss_native
//  LPP CPE Plan Maxi: 70'377 CHF, rachat max 539'414 CHF, 3a 32'000 CHF

CoachProfile _julienProfile() {
  return CoachProfile(
    birthYear: 1977,
    canton: 'VS',
    salaireBrutMensuel: 122207 / 12, // 10'183.92 CHF/mois
    employmentStatus: 'salarie',
    prevoyance: const PrevoyanceProfile(
      anneesContribuees: 27,
      avoirLppTotal: 70377,
      rachatMaximum: 539414,
      totalEpargne3a: 32000,
    ),
    patrimoine: const PatrimoineProfile(epargneLiquide: 50000),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2042),
      label: 'Retraite',
    ),
  );
}

CoachProfile _emptyProfile() {
  return CoachProfile(
    birthYear: 2000,
    canton: 'VS',
    salaireBrutMensuel: 0,
    employmentStatus: 'salarie',
    prevoyance: const PrevoyanceProfile(
      avoirLppTotal: null,
      totalEpargne3a: 0,
    ),
    patrimoine: const PatrimoineProfile(),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2065),
      label: 'Retraite',
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const emptyMemory = CapMemory();

  // ─────────────────────────────────────────────────────────────────
  //  TEST 1: FULL PROFILE — Julien golden couple
  // ─────────────────────────────────────────────────────────────────

  group('firstJob journey — Julien golden profile', () {
    test('Step A — intent chip intentChipPremierEmploi resolves to first_job',
        () {
      final mapping = IntentRouter.forChipKey('intentChipPremierEmploi');

      expect(mapping, isNotNull);
      expect(mapping!.goalIntentTag, equals('first_job'));
      expect(mapping.lifeEventFamily, equals('professionnel'));
      expect(mapping.stressType, equals('stress_prevoyance'));
    });

    test('Step B — suggestedRoute points to /first-job', () {
      final mapping = IntentRouter.forChipKey('intentChipPremierEmploi');

      expect(mapping, isNotNull);
      expect(mapping!.suggestedRoute, equals('/first-job'));
    });

    test('Step C — CapSequence has exactly 5 steps', () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'first_job',
        l: _l,
      );

      expect(seq.totalCount, equals(5));
      expect(seq.steps.length, equals(5));
    });

    test('Step C — step IDs match firstJob sequence specification', () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'first_job',
        l: _l,
      );

      final ids = seq.steps.map((s) => s.id).toList();
      expect(ids, equals(['fj_01_income', 'fj_02_salary_xray', 'fj_03_lpp',
          'fj_04_3a', 'fj_05_specialist']));
    });

    test('Step C — fj_01_income is completed when Julien has salary', () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'first_job',
        l: _l,
      );

      final incomeStep = seq.steps.firstWhere((s) => s.id == 'fj_01_income');
      expect(incomeStep.status, equals(CapStepStatus.completed));
    });

    test('Step C — fj_03_lpp is completed when Julien has avoirLppTotal', () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'first_job',
        l: _l,
      );

      final lppStep = seq.steps.firstWhere((s) => s.id == 'fj_03_lpp');
      expect(lppStep.status, equals(CapStepStatus.completed));
    });

    test('Step C — fj_04_3a is completed when Julien has totalEpargne3a > 0',
        () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'first_job',
        l: _l,
      );

      final step3a = seq.steps.firstWhere((s) => s.id == 'fj_04_3a');
      expect(step3a.status, equals(CapStepStatus.completed));
    });

    test('Step C — fj_02_salary_xray is NOT blocked when salary exists', () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'first_job',
        l: _l,
      );

      final salaryXray =
          seq.steps.firstWhere((s) => s.id == 'fj_02_salary_xray');
      expect(salaryXray.status, isNot(equals(CapStepStatus.blocked)));
    });

    test('Step D — lpp impact estimate is non-null (Julien has avoirLpp 70377)',
        () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'first_job',
        l: _l,
      );

      final lppStep = seq.steps.firstWhere((s) => s.id == 'fj_03_lpp');
      expect(lppStep.impactEstimate, isNotNull);
      expect(lppStep.impactEstimate!, greaterThan(0));
    });

    test(
        'Step E — step routes contain /first-job (fj_02), /rachat-lpp (fj_03), /pilier-3a (fj_04)',
        () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'first_job',
        l: _l,
      );

      final routes =
          seq.steps.map((s) => s.intentTag).whereType<String>().toList();
      expect(routes, contains('/first-job'));
      expect(routes, contains('/rachat-lpp'));
      expect(routes, contains('/pilier-3a'));
    });

    test('Step F — mapping.suggestedRoute is the plan generation entry point',
        () {
      final mapping = IntentRouter.forChipKey('intentChipPremierEmploi');

      expect(mapping, isNotNull);
      expect(mapping!.suggestedRoute, equals('/first-job'));
    });

    test('goalId is first_job', () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'first_job',
        l: _l,
      );

      expect(seq.goalId, equals('first_job'));
    });

    test('all steps have non-empty titleKeys (ARB contract)', () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'first_job',
        l: _l,
      );

      for (final step in seq.steps) {
        expect(step.titleKey, isNotEmpty,
            reason: '${step.id} has empty titleKey');
      }
    });

    test('specialist step (fj_05) has no intentTag — opens coach', () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'first_job',
        l: _l,
      );

      final specialist =
          seq.steps.firstWhere((s) => s.id == 'fj_05_specialist');
      expect(specialist.intentTag, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  TEST 2: EMPTY PROFILE — blocking conditions
  // ─────────────────────────────────────────────────────────────────

  group('firstJob journey — empty profile blocking', () {
    test('fj_01_income is non-completed when salary is 0', () {
      final seq = CapSequenceEngine.build(
        profile: _emptyProfile(),
        memory: emptyMemory,
        goalIntentTag: 'first_job',
        l: _l,
      );

      final incomeStep = seq.steps.firstWhere((s) => s.id == 'fj_01_income');
      expect(incomeStep.status, isNot(equals(CapStepStatus.completed)));
    });

    test('fj_02_salary_xray is blocked when salary is 0', () {
      final seq = CapSequenceEngine.build(
        profile: _emptyProfile(),
        memory: emptyMemory,
        goalIntentTag: 'first_job',
        l: _l,
      );

      final salaryXray =
          seq.steps.firstWhere((s) => s.id == 'fj_02_salary_xray');
      expect(salaryXray.status, equals(CapStepStatus.blocked));
    });

    test('fj_03_lpp is blocked when salary is 0', () {
      final seq = CapSequenceEngine.build(
        profile: _emptyProfile(),
        memory: emptyMemory,
        goalIntentTag: 'first_job',
        l: _l,
      );

      final lppStep = seq.steps.firstWhere((s) => s.id == 'fj_03_lpp');
      expect(lppStep.status, equals(CapStepStatus.blocked));
    });

    test('fj_04_3a is blocked when salary is 0', () {
      final seq = CapSequenceEngine.build(
        profile: _emptyProfile(),
        memory: emptyMemory,
        goalIntentTag: 'first_job',
        l: _l,
      );

      final step3a = seq.steps.firstWhere((s) => s.id == 'fj_04_3a');
      expect(step3a.status, equals(CapStepStatus.blocked));
    });

    test('intent mapping still resolves correctly regardless of profile', () {
      final mapping = IntentRouter.forChipKey('intentChipPremierEmploi');
      expect(mapping, isNotNull);
      expect(mapping!.goalIntentTag, equals('first_job'));
    });
  });
}
