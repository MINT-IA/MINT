// newjob_journey_test.dart
//
// Integration test: newJob life event journey.
// Traces intentChipNouvelEmploi → IntentRouter → newJob CapSequence (5 steps) →
// salary comparison → LPP transfer → 3a optimization routes.
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

/// Profile with no salary — triggers blocking of comparison/transfer steps.
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

/// Profile with salary and completed actions: salary_compared + lpp_transfer_checked.
CoachProfile _julienWithProgress() {
  return _julienProfile();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const emptyMemory = CapMemory();

  // ─────────────────────────────────────────────────────────────────
  //  TEST 1: FULL PROFILE — Julien golden couple
  // ─────────────────────────────────────────────────────────────────

  group('newJob journey — Julien golden profile', () {
    test('Step A — intentChipNouvelEmploi resolves goalIntentTag to new_job',
        () {
      final mapping = IntentRouter.forChipKey('intentChipNouvelEmploi');

      expect(mapping, isNotNull);
      expect(mapping!.goalIntentTag, equals('new_job'));
      expect(mapping.lifeEventFamily, equals('professionnel'));
      expect(mapping.stressType, equals('stress_budget'));
    });

    test('Step A — suggestedRoute points to /rente-vs-capital (plan entry)',
        () {
      final mapping = IntentRouter.forChipKey('intentChipNouvelEmploi');

      expect(mapping, isNotNull);
      expect(mapping!.suggestedRoute, equals('/rente-vs-capital'));
    });

    test('Step B — CapSequence has exactly 5 steps', () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'new_job',
        l: _l,
      );

      expect(seq.totalCount, equals(5));
      expect(seq.steps.length, equals(5));
    });

    test('Step B — step IDs match newJob sequence specification', () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'new_job',
        l: _l,
      );

      final ids = seq.steps.map((s) => s.id).toList();
      expect(ids, equals([
        'nj_01_income',
        'nj_02_compare',
        'nj_03_lpp_transfer',
        'nj_04_3a',
        'nj_05_specialist',
      ]));
    });

    test('Step C — nj_01_income is completed when Julien has salary', () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'new_job',
        l: _l,
      );

      final incomeStep = seq.steps.firstWhere((s) => s.id == 'nj_01_income');
      expect(incomeStep.status, equals(CapStepStatus.completed));
    });

    test(
        'Step C — nj_02_compare is NOT blocked when salary exists (upcoming/current)',
        () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'new_job',
        l: _l,
      );

      final compareStep = seq.steps.firstWhere((s) => s.id == 'nj_02_compare');
      expect(compareStep.status, isNot(equals(CapStepStatus.blocked)));
    });

    test(
        'Step C — nj_03_lpp_transfer is NOT blocked when salary exists (upcoming/current)',
        () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'new_job',
        l: _l,
      );

      final transferStep =
          seq.steps.firstWhere((s) => s.id == 'nj_03_lpp_transfer');
      expect(transferStep.status, isNot(equals(CapStepStatus.blocked)));
    });

    test('Step C — nj_04_3a is completed when Julien has totalEpargne3a 32000',
        () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'new_job',
        l: _l,
      );

      final step3a = seq.steps.firstWhere((s) => s.id == 'nj_04_3a');
      expect(step3a.status, equals(CapStepStatus.completed));
    });

    test('Step D — steps contain /rente-vs-capital route (compare)', () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'new_job',
        l: _l,
      );

      final routes =
          seq.steps.map((s) => s.intentTag).whereType<String>().toList();
      expect(routes, contains('/rente-vs-capital'));
    });

    test('Step D — steps contain /rachat-lpp route (LPP transfer)', () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'new_job',
        l: _l,
      );

      final routes =
          seq.steps.map((s) => s.intentTag).whereType<String>().toList();
      expect(routes, contains('/rachat-lpp'));
    });

    test('Step D — steps contain /pilier-3a route (3a optimization)', () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'new_job',
        l: _l,
      );

      final routes =
          seq.steps.map((s) => s.intentTag).whereType<String>().toList();
      expect(routes, contains('/pilier-3a'));
    });

    test('goalId is new_job', () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'new_job',
        l: _l,
      );

      expect(seq.goalId, equals('new_job'));
    });

    test('all steps have non-empty titleKeys (ARB contract)', () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'new_job',
        l: _l,
      );

      for (final step in seq.steps) {
        expect(step.titleKey, isNotEmpty,
            reason: '${step.id} has empty titleKey');
      }
    });

    test('specialist step (nj_05) has no intentTag — opens coach', () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'new_job',
        l: _l,
      );

      final specialist =
          seq.steps.firstWhere((s) => s.id == 'nj_05_specialist');
      expect(specialist.intentTag, isNull);
    });

    test('lpp_transfer step has non-null impactEstimate (Julien avoirLpp 70377)',
        () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'new_job',
        l: _l,
      );

      final transferStep =
          seq.steps.firstWhere((s) => s.id == 'nj_03_lpp_transfer');
      expect(transferStep.impactEstimate, isNotNull);
      expect(transferStep.impactEstimate!, greaterThan(0));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  TEST 2: EMPTY PROFILE — comparison steps blocked
  // ─────────────────────────────────────────────────────────────────

  group('newJob journey — empty profile blocks comparison steps', () {
    test('nj_01_income is non-completed when salary is 0', () {
      final seq = CapSequenceEngine.build(
        profile: _emptyProfile(),
        memory: emptyMemory,
        goalIntentTag: 'new_job',
        l: _l,
      );

      final incomeStep = seq.steps.firstWhere((s) => s.id == 'nj_01_income');
      expect(incomeStep.status, isNot(equals(CapStepStatus.completed)));
    });

    test('nj_02_compare is blocked when salary is 0', () {
      final seq = CapSequenceEngine.build(
        profile: _emptyProfile(),
        memory: emptyMemory,
        goalIntentTag: 'new_job',
        l: _l,
      );

      final compareStep = seq.steps.firstWhere((s) => s.id == 'nj_02_compare');
      expect(compareStep.status, equals(CapStepStatus.blocked));
    });

    test('nj_03_lpp_transfer is blocked when salary is 0', () {
      final seq = CapSequenceEngine.build(
        profile: _emptyProfile(),
        memory: emptyMemory,
        goalIntentTag: 'new_job',
        l: _l,
      );

      final transferStep =
          seq.steps.firstWhere((s) => s.id == 'nj_03_lpp_transfer');
      expect(transferStep.status, equals(CapStepStatus.blocked));
    });

    test('nj_04_3a is blocked when salary is 0', () {
      final seq = CapSequenceEngine.build(
        profile: _emptyProfile(),
        memory: emptyMemory,
        goalIntentTag: 'new_job',
        l: _l,
      );

      final step3a = seq.steps.firstWhere((s) => s.id == 'nj_04_3a');
      expect(step3a.status, equals(CapStepStatus.blocked));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  TEST 3: COMPLETED ACTIONS — progress from memory
  // ─────────────────────────────────────────────────────────────────

  group('newJob journey — completedActions drive step progression', () {
    test(
        'nj_02_compare is completed when memory contains salary_compared',
        () {
      final memory = const CapMemory(
        completedActions: ['salary_compared'],
      );

      final seq = CapSequenceEngine.build(
        profile: _julienWithProgress(),
        memory: memory,
        goalIntentTag: 'new_job',
        l: _l,
      );

      final compareStep = seq.steps.firstWhere((s) => s.id == 'nj_02_compare');
      expect(compareStep.status, equals(CapStepStatus.completed));
    });

    test(
        'nj_03_lpp_transfer is completed when memory contains lpp_transfer_checked',
        () {
      final memory = const CapMemory(
        completedActions: ['salary_compared', 'lpp_transfer_checked'],
      );

      final seq = CapSequenceEngine.build(
        profile: _julienWithProgress(),
        memory: memory,
        goalIntentTag: 'new_job',
        l: _l,
      );

      final transferStep =
          seq.steps.firstWhere((s) => s.id == 'nj_03_lpp_transfer');
      expect(transferStep.status, equals(CapStepStatus.completed));
    });

    test(
        'nj_04_3a is upcoming when salary_compared+lpp_transfer_checked but no 3a (no 3a data or memory)',
        () {
      // Profile with no 3a + no 3a_optimized memory action
      final profileNo3a = CoachProfile(
        birthYear: 1977,
        canton: 'VS',
        salaireBrutMensuel: 122207 / 12,
        employmentStatus: 'salarie',
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 70377,
          totalEpargne3a: 0, // No 3a savings
        ),
        patrimoine: const PatrimoineProfile(),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2042),
          label: 'Retraite',
        ),
      );

      final memory = const CapMemory(
        completedActions: ['salary_compared', 'lpp_transfer_checked'],
      );

      final seq = CapSequenceEngine.build(
        profile: profileNo3a,
        memory: memory,
        goalIntentTag: 'new_job',
        l: _l,
      );

      final step3a = seq.steps.firstWhere((s) => s.id == 'nj_04_3a');
      // With salary present and no 3a data, step should be upcoming or current (not blocked or completed)
      expect(step3a.status, isNot(equals(CapStepStatus.blocked)));
      expect(step3a.status, isNot(equals(CapStepStatus.completed)));
    });

    test('sequence with both completed actions shows 3+ completed steps', () {
      final memory = const CapMemory(
        completedActions: ['salary_compared', 'lpp_transfer_checked'],
      );

      final seq = CapSequenceEngine.build(
        profile: _julienWithProgress(),
        memory: memory,
        goalIntentTag: 'new_job',
        l: _l,
      );

      // nj_01 (salary), nj_02 (memory), nj_03 (memory), nj_04 (3a 32000) = 4 completed
      expect(seq.completedCount, greaterThanOrEqualTo(3));
    });
  });
}
