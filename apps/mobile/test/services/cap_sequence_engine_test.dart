import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations_fr.dart';
import 'package:mint_mobile/models/cap_sequence.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/cap_sequence_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ────────────────────────────────────────────────────────────────
//  CAP SEQUENCE ENGINE — Tests
// ────────────────────────────────────────────────────────────────
//
//  Validates:
//  - Retirement sequence with empty profile → mostly upcoming/blocked
//  - Retirement sequence with full profile → completed steps
//  - Budget sequence
//  - Housing sequence: with/without fonds propres
//  - Unknown goal → empty sequence
//  - Step status determinism
//  - Impact estimates are reasonable
//  - All steps have valid ARB titleKeys
//  - Golden couple: Julien (49, VS, 122207 CHF) + Lauren (43, VS, 67000 CHF)
// ────────────────────────────────────────────────────────────────

final _l = SFr();

/// Minimal profile helper.
CoachProfile _profile({
  int birthYear = 1980,
  double salaireBrutMensuel = 8000,
  String canton = 'VS',
  String employmentStatus = 'salarie',
  PrevoyanceProfile prevoyance = const PrevoyanceProfile(),
  PatrimoineProfile patrimoine = const PatrimoineProfile(),
  DepensesProfile depenses = const DepensesProfile(),
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: canton,
    salaireBrutMensuel: salaireBrutMensuel,
    employmentStatus: employmentStatus,
    prevoyance: prevoyance,
    patrimoine: patrimoine,
    depenses: depenses,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2042),
      label: 'Retraite',
    ),
  );
}

/// Julien: 49 ans, VS, 122'207 CHF/an brut, LPP CPE 70'377 CHF.
CoachProfile _julien() {
  return CoachProfile(
    birthYear: 1977,
    canton: 'VS',
    salaireBrutMensuel: 122207 / 12,
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

/// Lauren: 43 ans, VS, 67'000 CHF/an brut, LPP HOTELA 19'620 CHF.
CoachProfile _lauren() {
  return CoachProfile(
    birthYear: 1982,
    canton: 'VS',
    salaireBrutMensuel: 67000 / 12,
    employmentStatus: 'salarie',
    prevoyance: const PrevoyanceProfile(
      anneesContribuees: 21,
      avoirLppTotal: 19620,
      rachatMaximum: 52949,
      totalEpargne3a: 14000,
    ),
    patrimoine: const PatrimoineProfile(epargneLiquide: 20000),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2047),
      label: 'Retraite',
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── Empty memory helper ──────────────────────────────────────
  const emptyMemory = CapMemory();

  // ── RETIREMENT SEQUENCE ──────────────────────────────────────

  group('Retirement sequence — empty profile', () {
    test('produces 10 steps', () {
      final profile = _profile(salaireBrutMensuel: 0);
      final seq = CapSequenceEngine.build(
        profile: profile,
        memory: emptyMemory,
        goalIntentTag: 'retirement_choice',
        l: _l,
      );

      expect(seq.totalCount, equals(10));
    });

    test('step 1 (salary) is non-completed when salary == 0', () {
      final profile = _profile(salaireBrutMensuel: 0);
      final seq = CapSequenceEngine.build(
        profile: profile,
        memory: emptyMemory,
        goalIntentTag: 'retirement_choice',
        l: _l,
      );

      final step1 = seq.steps.firstWhere((s) => s.id == 'ret_01_salary');
      // Can be current (auto-promoted) or upcoming — never completed
      expect(step1.status, isNot(equals(CapStepStatus.completed)));
    });

    test('later steps are blocked when prerequisites missing', () {
      final profile = _profile(salaireBrutMensuel: 0);
      final seq = CapSequenceEngine.build(
        profile: profile,
        memory: emptyMemory,
        goalIntentTag: 'retirement_choice',
        l: _l,
      );

      // Step 4 (replacement rate) requires salary + LPP
      final step4 = seq.steps.firstWhere((s) => s.id == 'ret_04_rate');
      expect(step4.status, equals(CapStepStatus.blocked));
    });

    test('completedCount is low for minimal empty profile (no salary)', () {
      // profile has birthYear=1980, salary=0.
      // Step 2 (AVS) is completed because birthYear > 0.
      // Step 1 (salary) is not completed.
      final profile = _profile(salaireBrutMensuel: 0);
      final seq = CapSequenceEngine.build(
        profile: profile,
        memory: emptyMemory,
        goalIntentTag: 'retirement_choice',
        l: _l,
      );

      // At most step 2 (AVS) can be completed; step 1 (salary) is not
      expect(seq.completedCount, lessThanOrEqualTo(2));
      final step1 = seq.steps.firstWhere((s) => s.id == 'ret_01_salary');
      expect(step1.status, isNot(equals(CapStepStatus.completed)));
    });
  });

  group('Retirement sequence — profile with salary (step 1 complete)', () {
    test('step 1 is completed when salary > 0', () {
      final profile = _profile(salaireBrutMensuel: 8000);
      final seq = CapSequenceEngine.build(
        profile: profile,
        memory: emptyMemory,
        goalIntentTag: 'retirement_choice',
        l: _l,
      );

      final step1 = seq.steps.firstWhere((s) => s.id == 'ret_01_salary');
      expect(step1.status, equals(CapStepStatus.completed));
    });

    test('step 2 (AVS) is completed when birthYear is known', () {
      final profile = _profile(birthYear: 1977, salaireBrutMensuel: 8000);
      final seq = CapSequenceEngine.build(
        profile: profile,
        memory: emptyMemory,
        goalIntentTag: 'retirement_choice',
        l: _l,
      );

      final step2 = seq.steps.firstWhere((s) => s.id == 'ret_02_avs');
      expect(step2.status, equals(CapStepStatus.completed));
    });
  });

  group('Retirement sequence — Julien (golden couple)', () {
    test('has 10 steps', () {
      final seq = CapSequenceEngine.build(
        profile: _julien(),
        memory: emptyMemory,
        goalIntentTag: 'retirement_choice',
        l: _l,
      );
      expect(seq.totalCount, equals(10));
    });

    test('step 1 (salary) is completed', () {
      final seq = CapSequenceEngine.build(
        profile: _julien(),
        memory: emptyMemory,
        goalIntentTag: 'retirement_choice',
        l: _l,
      );
      final step1 = seq.steps.firstWhere((s) => s.id == 'ret_01_salary');
      expect(step1.status, equals(CapStepStatus.completed));
    });

    test('step 3 (LPP) is completed because avoirLppTotal > 0', () {
      final seq = CapSequenceEngine.build(
        profile: _julien(),
        memory: emptyMemory,
        goalIntentTag: 'retirement_choice',
        l: _l,
      );
      final step3 = seq.steps.firstWhere((s) => s.id == 'ret_03_lpp');
      expect(step3.status, equals(CapStepStatus.completed));
    });

    test('step 6 (rachat) is upcoming because rachatMaximum > 0', () {
      final seq = CapSequenceEngine.build(
        profile: _julien(),
        memory: emptyMemory,
        goalIntentTag: 'retirement_choice',
        l: _l,
      );
      // Step 6 requires rachatMaximum > 0 (Julien has 539'414)
      final step6 = seq.steps.firstWhere((s) => s.id == 'ret_06_rachat');
      expect(
          step6.status,
          anyOf(
            equals(CapStepStatus.upcoming),
            equals(CapStepStatus.current),
          ));
    });

    test('LPP impact estimate is reasonable for Julien', () {
      final seq = CapSequenceEngine.build(
        profile: _julien(),
        memory: emptyMemory,
        goalIntentTag: 'retirement_choice',
        l: _l,
      );
      final step3 = seq.steps.firstWhere((s) => s.id == 'ret_03_lpp');
      // LPP impact = 70'377 * 6.8% / 12 ≈ 399 CHF/mois
      expect(step3.impactEstimate, isNotNull);
      expect(step3.impactEstimate!, greaterThan(300.0));
      expect(step3.impactEstimate!, lessThan(600.0));
    });

    test('completedCount >= 3 with Julien full profile', () {
      final seq = CapSequenceEngine.build(
        profile: _julien(),
        memory: emptyMemory,
        goalIntentTag: 'retirement_choice',
        l: _l,
      );
      // At minimum: salary, age/AVS, LPP
      expect(seq.completedCount, greaterThanOrEqualTo(3));
    });
  });

  group('Retirement sequence — Lauren (golden couple)', () {
    test('has 10 steps', () {
      final seq = CapSequenceEngine.build(
        profile: _lauren(),
        memory: emptyMemory,
        goalIntentTag: 'retirement_choice',
        l: _l,
      );
      expect(seq.totalCount, equals(10));
    });

    test('step 3 (LPP) is completed because avoirLppTotal > 0', () {
      final seq = CapSequenceEngine.build(
        profile: _lauren(),
        memory: emptyMemory,
        goalIntentTag: 'retirement_choice',
        l: _l,
      );
      final step3 = seq.steps.firstWhere((s) => s.id == 'ret_03_lpp');
      expect(step3.status, equals(CapStepStatus.completed));
    });

    test('AVS impact estimate is positive for Lauren', () {
      final seq = CapSequenceEngine.build(
        profile: _lauren(),
        memory: emptyMemory,
        goalIntentTag: 'retirement_choice',
        l: _l,
      );
      final step2 = seq.steps.firstWhere((s) => s.id == 'ret_02_avs');
      expect(step2.impactEstimate, isNotNull);
      expect(step2.impactEstimate!, greaterThan(0.0));
    });
  });

  group('Retirement sequence — memory completions', () {
    test('step 5 (3a) is completed when memory contains 3a action', () {
      const memory = CapMemory(
        completedActions: ['pillar_3a'],
      );
      final seq = CapSequenceEngine.build(
        profile: _profile(salaireBrutMensuel: 8000),
        memory: memory,
        goalIntentTag: 'retirement_choice',
        l: _l,
      );
      final step5 = seq.steps.firstWhere((s) => s.id == 'ret_05_3a');
      expect(step5.status, equals(CapStepStatus.completed));
    });

    test('step 10 (specialist) is completed when memory marks it', () {
      const memory = CapMemory(
        completedActions: ['specialist_consulted'],
      );
      final seq = CapSequenceEngine.build(
        profile: _julien(),
        memory: memory,
        goalIntentTag: 'retirement_choice',
        l: _l,
      );
      final step10 = seq.steps.firstWhere((s) => s.id == 'ret_10_specialist');
      expect(step10.status, equals(CapStepStatus.completed));
    });
  });

  // ── BUDGET SEQUENCE ──────────────────────────────────────────

  group('Budget sequence', () {
    test('produces 6 steps', () {
      final seq = CapSequenceEngine.build(
        profile: _profile(),
        memory: emptyMemory,
        goalIntentTag: 'budget_overview',
        l: _l,
      );
      expect(seq.totalCount, equals(6));
    });

    test('step 1 (income) is completed when salary > 0', () {
      final seq = CapSequenceEngine.build(
        profile: _profile(salaireBrutMensuel: 5000),
        memory: emptyMemory,
        goalIntentTag: 'budget_overview',
        l: _l,
      );
      final step1 = seq.steps.firstWhere((s) => s.id == 'bud_01_income');
      expect(step1.status, equals(CapStepStatus.completed));
    });

    test('step 2 (charges) is completed when loyer > 0', () {
      final seq = CapSequenceEngine.build(
        profile: _profile(
          salaireBrutMensuel: 5000,
          depenses: const DepensesProfile(loyer: 1200),
        ),
        memory: emptyMemory,
        goalIntentTag: 'budget_overview',
        l: _l,
      );
      final step2 = seq.steps.firstWhere((s) => s.id == 'bud_02_charges');
      expect(step2.status, equals(CapStepStatus.completed));
    });

    test('step 5 (epargne) is completed when epargneLiquide > 0', () {
      final seq = CapSequenceEngine.build(
        profile: _profile(
          patrimoine: const PatrimoineProfile(epargneLiquide: 10000),
        ),
        memory: emptyMemory,
        goalIntentTag: 'budget_overview',
        l: _l,
      );
      final step5 = seq.steps.firstWhere((s) => s.id == 'bud_05_epargne');
      expect(step5.status, equals(CapStepStatus.completed));
    });

    test('step 6 (3a) is completed when 3a capital > 0', () {
      final seq = CapSequenceEngine.build(
        profile: _profile(
          prevoyance: const PrevoyanceProfile(totalEpargne3a: 5000),
        ),
        memory: emptyMemory,
        goalIntentTag: 'budget_overview',
        l: _l,
      );
      final step6 = seq.steps.firstWhere((s) => s.id == 'bud_06_3a');
      expect(step6.status, equals(CapStepStatus.completed));
    });

    test('step 3 (margin) blocked when income but no charges', () {
      final seq = CapSequenceEngine.build(
        profile: _profile(salaireBrutMensuel: 5000),
        memory: emptyMemory,
        goalIntentTag: 'budget_overview',
        l: _l,
      );
      final step3 = seq.steps.firstWhere((s) => s.id == 'bud_03_margin');
      expect(step3.status, equals(CapStepStatus.blocked));
    });
  });

  // ── HOUSING SEQUENCE ─────────────────────────────────────────

  group('Housing sequence — without fonds propres', () {
    test('produces 7 steps', () {
      final seq = CapSequenceEngine.build(
        profile: _profile(salaireBrutMensuel: 0),
        memory: emptyMemory,
        goalIntentTag: 'housing_purchase',
        l: _l,
      );
      expect(seq.totalCount, equals(7));
    });

    test('step 1 is non-completed when salary is 0', () {
      final seq = CapSequenceEngine.build(
        profile: _profile(salaireBrutMensuel: 0),
        memory: emptyMemory,
        goalIntentTag: 'housing_purchase',
        l: _l,
      );
      final step1 = seq.steps.firstWhere((s) => s.id == 'hou_01_income');
      // Can be current (auto-promoted by fromSteps) or upcoming — never completed
      expect(step1.status, isNot(equals(CapStepStatus.completed)));
    });

    test('step 2 is blocked when no salary and no savings', () {
      final seq = CapSequenceEngine.build(
        profile: _profile(salaireBrutMensuel: 0),
        memory: emptyMemory,
        goalIntentTag: 'housing_purchase',
        l: _l,
      );
      final step2 = seq.steps.firstWhere((s) => s.id == 'hou_02_fonds');
      expect(step2.status, equals(CapStepStatus.blocked));
    });
  });

  group('Housing sequence — with fonds propres', () {
    test('step 1 completed when salary > 0', () {
      final seq = CapSequenceEngine.build(
        profile: _profile(
          salaireBrutMensuel: 8000,
          patrimoine: const PatrimoineProfile(epargneLiquide: 80000),
        ),
        memory: emptyMemory,
        goalIntentTag: 'housing_purchase',
        l: _l,
      );
      final step1 = seq.steps.firstWhere((s) => s.id == 'hou_01_income');
      expect(step1.status, equals(CapStepStatus.completed));
    });

    test('step 2 completed when epargneLiquide > 0', () {
      final seq = CapSequenceEngine.build(
        profile: _profile(
          salaireBrutMensuel: 8000,
          patrimoine: const PatrimoineProfile(epargneLiquide: 80000),
        ),
        memory: emptyMemory,
        goalIntentTag: 'housing_purchase',
        l: _l,
      );
      final step2 = seq.steps.firstWhere((s) => s.id == 'hou_02_fonds');
      expect(step2.status, equals(CapStepStatus.completed));
    });

    test('affordability estimate is reasonable for 8000 CHF/mois', () {
      final seq = CapSequenceEngine.build(
        profile: _profile(salaireBrutMensuel: 8000),
        memory: emptyMemory,
        goalIntentTag: 'housing_purchase',
        l: _l,
      );
      final step3 = seq.steps.firstWhere((s) => s.id == 'hou_03_capacity');
      // 8000 * 12 * 4.5 = 432'000 CHF
      expect(step3.impactEstimate, isNotNull);
      expect(step3.impactEstimate!, closeTo(432000.0, 1.0));
    });
  });

  // ── UNKNOWN GOAL ─────────────────────────────────────────────

  group('Unknown goal', () {
    test('unknown goal produces empty sequence', () {
      final seq = CapSequenceEngine.build(
        profile: _profile(),
        memory: emptyMemory,
        goalIntentTag: 'totally_unknown_goal',
        l: _l,
      );
      expect(seq.hasSteps, isFalse);
      expect(seq.totalCount, equals(0));
    });

    test('empty goal string produces empty sequence', () {
      final seq = CapSequenceEngine.build(
        profile: _profile(),
        memory: emptyMemory,
        goalIntentTag: '',
        l: _l,
      );
      expect(seq.hasSteps, isFalse);
    });
  });

  // ── ARB KEY INTEGRITY ─────────────────────────────────────────

  group('ARB key integrity — retirement steps', () {
    test('all retirement step titleKeys match expected ARB pattern', () {
      final seq = CapSequenceEngine.build(
        profile: _julien(),
        memory: emptyMemory,
        goalIntentTag: 'retirement_choice',
        l: _l,
      );

      final validPrefixes = ['capStepRetirement'];
      for (final step in seq.steps) {
        final hasValidPrefix =
            validPrefixes.any((p) => step.titleKey.startsWith(p));
        expect(hasValidPrefix, isTrue,
            reason: 'Step ${step.id} has invalid titleKey: ${step.titleKey}');
      }
    });

    test('all retirement step titleKeys end with Title', () {
      final seq = CapSequenceEngine.build(
        profile: _julien(),
        memory: emptyMemory,
        goalIntentTag: 'retirement_choice',
        l: _l,
      );

      for (final step in seq.steps) {
        expect(step.titleKey.endsWith('Title'), isTrue,
            reason:
                'Step ${step.id} titleKey should end with Title: ${step.titleKey}');
      }
    });

    test('all budget step titleKeys match expected ARB pattern', () {
      final seq = CapSequenceEngine.build(
        profile: _profile(),
        memory: emptyMemory,
        goalIntentTag: 'budget_overview',
        l: _l,
      );

      for (final step in seq.steps) {
        expect(step.titleKey.startsWith('capStepBudget'), isTrue,
            reason: 'Budget step ${step.id}: ${step.titleKey}');
      }
    });

    test('all housing step titleKeys match expected ARB pattern', () {
      final seq = CapSequenceEngine.build(
        profile: _profile(),
        memory: emptyMemory,
        goalIntentTag: 'housing_purchase',
        l: _l,
      );

      for (final step in seq.steps) {
        expect(step.titleKey.startsWith('capStepHousing'), isTrue,
            reason: 'Housing step ${step.id}: ${step.titleKey}');
      }
    });

    test('step IDs are all unique within a sequence', () {
      final seq = CapSequenceEngine.build(
        profile: _julien(),
        memory: emptyMemory,
        goalIntentTag: 'retirement_choice',
        l: _l,
      );

      final ids = seq.steps.map((s) => s.id).toList();
      final uniqueIds = ids.toSet();
      expect(uniqueIds.length, equals(ids.length));
    });
  });

  // ── DETERMINISM ───────────────────────────────────────────────

  group('Determinism — same input, same output', () {
    test('same profile + memory produces same sequence twice', () {
      final profile = _julien();

      final seq1 = CapSequenceEngine.build(
        profile: profile,
        memory: emptyMemory,
        goalIntentTag: 'retirement_choice',
        l: _l,
      );
      final seq2 = CapSequenceEngine.build(
        profile: profile,
        memory: emptyMemory,
        goalIntentTag: 'retirement_choice',
        l: _l,
      );

      expect(seq1.completedCount, equals(seq2.completedCount));
      expect(seq1.totalCount, equals(seq2.totalCount));
      for (int i = 0; i < seq1.steps.length; i++) {
        expect(seq1.steps[i].id, equals(seq2.steps[i].id));
        expect(seq1.steps[i].status, equals(seq2.steps[i].status));
      }
    });

    test('adding memory action changes step status', () {
      final profile = _julien();

      final seqBefore = CapSequenceEngine.build(
        profile: profile,
        memory: emptyMemory,
        goalIntentTag: 'retirement_choice',
        l: _l,
      );
      final seqAfter = CapSequenceEngine.build(
        profile: profile,
        memory: const CapMemory(completedActions: ['pillar_3a']),
        goalIntentTag: 'retirement_choice',
        l: _l,
      );

      final step5Before =
          seqBefore.steps.firstWhere((s) => s.id == 'ret_05_3a');
      final step5After = seqAfter.steps.firstWhere((s) => s.id == 'ret_05_3a');

      // Before: not yet completed; After: completed
      expect(step5Before.status, isNot(equals(CapStepStatus.completed)));
      expect(step5After.status, equals(CapStepStatus.completed));
    });
  });
}
