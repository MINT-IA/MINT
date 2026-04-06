// housing_journey_test.dart
//
// Integration test: housingPurchase life event journey.
// Traces intentChipProjet → IntentRouter → housing CapSequence (7 steps) →
// EPL/mortgage calculator routes → affordability estimates → plan entry.
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
//  Epargne liquide: 50'000 CHF (used for fonds propres detection)

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
      type: GoalAType.achatImmo,
      targetDate: DateTime(2030),
      label: 'Achat immobilier',
    ),
  );
}

/// Profile with salary but no fonds propres (epargneLiquide = 0, totalEpargne3a = 0).
CoachProfile _julienNoFonds() {
  return CoachProfile(
    birthYear: 1977,
    canton: 'VS',
    salaireBrutMensuel: 122207 / 12,
    employmentStatus: 'salarie',
    prevoyance: const PrevoyanceProfile(
      anneesContribuees: 27,
      avoirLppTotal: 70377,
      rachatMaximum: 539414,
      totalEpargne3a: 0, // No 3a savings
    ),
    patrimoine: const PatrimoineProfile(epargneLiquide: 0), // No liquid savings
    goalA: GoalA(
      type: GoalAType.achatImmo,
      targetDate: DateTime(2030),
      label: 'Achat immobilier',
    ),
  );
}

/// Profile with avoirLppTotal below OPP2 art. 5 minimum (20'000 CHF).
CoachProfile _julienLowLpp() {
  return CoachProfile(
    birthYear: 1977,
    canton: 'VS',
    salaireBrutMensuel: 122207 / 12,
    employmentStatus: 'salarie',
    prevoyance: const PrevoyanceProfile(
      anneesContribuees: 10,
      avoirLppTotal: 15000, // Below OPP2 art. 5 minimum (20'000)
      totalEpargne3a: 32000,
    ),
    patrimoine: const PatrimoineProfile(epargneLiquide: 50000),
    goalA: GoalA(
      type: GoalAType.achatImmo,
      targetDate: DateTime(2030),
      label: 'Achat immobilier',
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

  group('housingPurchase journey — Julien golden profile', () {
    test('Step A — intentChipProjet resolves goalIntentTag to housing_purchase',
        () {
      final mapping = IntentRouter.forChipKey('intentChipProjet');

      expect(mapping, isNotNull);
      expect(mapping!.goalIntentTag, equals('housing_purchase'));
      expect(mapping.lifeEventFamily, equals('patrimoine'));
      expect(mapping.stressType, equals('stress_patrimoine'));
    });

    test('Step A — suggestedRoute points to /achat-immobilier (plan entry)',
        () {
      final mapping = IntentRouter.forChipKey('intentChipProjet');

      expect(mapping, isNotNull);
      expect(mapping!.suggestedRoute, equals('/achat-immobilier'));
    });

    test('Step B — CapSequence has exactly 7 steps', () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'housing_purchase',
        l: _l,
      );

      expect(seq.totalCount, equals(7));
      expect(seq.steps.length, equals(7));
    });

    test('Step B — step IDs match housingPurchase sequence specification', () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'housing_purchase',
        l: _l,
      );

      final ids = seq.steps.map((s) => s.id).toList();
      expect(ids, equals([
        'hou_01_income',
        'hou_02_fonds',
        'hou_03_capacity',
        'hou_04_mortgage',
        'hou_05_epl',
        'hou_06_compare',
        'hou_07_specialist',
      ]));
    });

    test('Step C — hou_01_income is completed when Julien has salary', () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'housing_purchase',
        l: _l,
      );

      final incomeStep = seq.steps.firstWhere((s) => s.id == 'hou_01_income');
      expect(incomeStep.status, equals(CapStepStatus.completed));
    });

    test(
        'Step C — hou_02_fonds is completed when Julien has epargneLiquide 50000',
        () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'housing_purchase',
        l: _l,
      );

      final fondsStep = seq.steps.firstWhere((s) => s.id == 'hou_02_fonds');
      expect(fondsStep.status, equals(CapStepStatus.completed));
    });

    test(
        'Step C — hou_03_capacity is not blocked (income + fonds both present)',
        () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'housing_purchase',
        l: _l,
      );

      final capacityStep =
          seq.steps.firstWhere((s) => s.id == 'hou_03_capacity');
      expect(capacityStep.status, isNot(equals(CapStepStatus.blocked)));
    });

    test('Step D — steps contain /hypotheque route (capacity + mortgage)', () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'housing_purchase',
        l: _l,
      );

      final routes =
          seq.steps.map((s) => s.intentTag).whereType<String>().toList();
      expect(routes, contains('/hypotheque'));
    });

    test('Step D — steps contain /rachat-lpp route (EPL)', () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'housing_purchase',
        l: _l,
      );

      final routes =
          seq.steps.map((s) => s.intentTag).whereType<String>().toList();
      expect(routes, contains('/rachat-lpp'));
    });

    test('Step D — steps contain /location-vs-propriete route (compare)', () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'housing_purchase',
        l: _l,
      );

      final routes =
          seq.steps.map((s) => s.intentTag).whereType<String>().toList();
      expect(routes, contains('/location-vs-propriete'));
    });

    test(
        'Step E — hou_05_epl.impactEstimate is not null (avoirLpp 70377 > 20000 OPP2 min)',
        () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'housing_purchase',
        l: _l,
      );

      final eplStep = seq.steps.firstWhere((s) => s.id == 'hou_05_epl');
      expect(eplStep.impactEstimate, isNotNull);
      expect(eplStep.impactEstimate!, greaterThan(0));
    });

    test(
        'Step F — hou_03_capacity.impactEstimate is not null and > 0 (salary present)',
        () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'housing_purchase',
        l: _l,
      );

      final capacityStep =
          seq.steps.firstWhere((s) => s.id == 'hou_03_capacity');
      expect(capacityStep.impactEstimate, isNotNull);
      expect(capacityStep.impactEstimate!, greaterThan(0));
    });

    test('goalId is housing_purchase', () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'housing_purchase',
        l: _l,
      );

      expect(seq.goalId, equals('housing_purchase'));
    });

    test('all steps have non-empty titleKeys (ARB contract)', () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'housing_purchase',
        l: _l,
      );

      for (final step in seq.steps) {
        expect(step.titleKey, isNotEmpty,
            reason: '${step.id} has empty titleKey');
      }
    });

    test('specialist step (hou_07) has no intentTag — opens coach', () {
      final seq = CapSequenceEngine.build(
        profile: _julienProfile(),
        memory: emptyMemory,
        goalIntentTag: 'housing_purchase',
        l: _l,
      );

      final specialist =
          seq.steps.firstWhere((s) => s.id == 'hou_07_specialist');
      expect(specialist.intentTag, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  TEST 2: NO FONDS — capacity step blocked
  // ─────────────────────────────────────────────────────────────────

  group('housingPurchase — no fonds propres blocks capacity step', () {
    test('hou_02_fonds is non-completed when epargneLiquide and 3a are 0', () {
      final seq = CapSequenceEngine.build(
        profile: _julienNoFonds(),
        memory: emptyMemory,
        goalIntentTag: 'housing_purchase',
        l: _l,
      );

      final fondsStep = seq.steps.firstWhere((s) => s.id == 'hou_02_fonds');
      expect(fondsStep.status, isNot(equals(CapStepStatus.completed)));
    });

    test('hou_03_capacity is blocked when no fonds propres', () {
      final seq = CapSequenceEngine.build(
        profile: _julienNoFonds(),
        memory: emptyMemory,
        goalIntentTag: 'housing_purchase',
        l: _l,
      );

      final capacityStep =
          seq.steps.firstWhere((s) => s.id == 'hou_03_capacity');
      expect(capacityStep.status, equals(CapStepStatus.blocked));
    });

    test('hou_01_income remains completed even without fonds', () {
      final seq = CapSequenceEngine.build(
        profile: _julienNoFonds(),
        memory: emptyMemory,
        goalIntentTag: 'housing_purchase',
        l: _l,
      );

      final incomeStep = seq.steps.firstWhere((s) => s.id == 'hou_01_income');
      expect(incomeStep.status, equals(CapStepStatus.completed));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  TEST 3: LOW LPP — EPL blocked below 20k minimum
  // ─────────────────────────────────────────────────────────────────

  group('housingPurchase — EPL blocked below OPP2 art.5 minimum (20000 CHF)',
      () {
    test('hou_05_epl.impactEstimate is null when avoirLpp is 15000 < 20000',
        () {
      final seq = CapSequenceEngine.build(
        profile: _julienLowLpp(),
        memory: emptyMemory,
        goalIntentTag: 'housing_purchase',
        l: _l,
      );

      final eplStep = seq.steps.firstWhere((s) => s.id == 'hou_05_epl');
      expect(eplStep.impactEstimate, isNull);
    });

    test('hou_05_epl step still exists in sequence (just no impact estimate)',
        () {
      final seq = CapSequenceEngine.build(
        profile: _julienLowLpp(),
        memory: emptyMemory,
        goalIntentTag: 'housing_purchase',
        l: _l,
      );

      expect(seq.steps.any((s) => s.id == 'hou_05_epl'), isTrue);
    });

    test('hou_03_capacity estimate still non-null when income exists', () {
      final seq = CapSequenceEngine.build(
        profile: _julienLowLpp(),
        memory: emptyMemory,
        goalIntentTag: 'housing_purchase',
        l: _l,
      );

      final capacityStep =
          seq.steps.firstWhere((s) => s.id == 'hou_03_capacity');
      expect(capacityStep.impactEstimate, isNotNull);
    });
  });
}
