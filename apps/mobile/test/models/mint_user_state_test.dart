import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/cap_decision.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/mint_user_state.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_phase.dart';
import 'package:mint_mobile/services/retirement_projection_service.dart';

// ────────────────────────────────────────────────────────────────────────────
//  Helpers
// ────────────────────────────────────────────────────────────────────────────

CoachProfile _minimalProfile() => CoachProfile(
      birthYear: 1977,
      canton: 'VS',
      salaireBrutMensuel: 10000,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2042),
        label: 'Retraite',
      ),
    );

RetirementBudgetGap _sampleGap() => const RetirementBudgetGap(
      totalRevenusMensuel: 5000,
      avsMensuel: 2500,
      lppMensuel: 1500,
      troisAMensuel: 300,
      libreMensuel: 700,
      impotEstimeMensuel: 400,
      depensesMensuelles: 5500,
      soldeMensuel: -500,
      tauxRemplacement: 65.0,
      alertes: [],
    );

BudgetSnapshot _sampleSnapshot() => const BudgetSnapshot(
      present: PresentBudget(
        monthlyNet: 7500,
        monthlyCharges: 3000,
        monthlySavings: 604,
        monthlyFree: 3896,
      ),
      stage: BudgetStage.fullGapVisible,
      capImpacts: [],
      confidenceScore: 72.0,
    );

CapDecision _sampleCap() => const CapDecision(
      id: 'pillar_3a',
      kind: CapKind.optimize,
      priorityScore: 0.8,
      headline: 'Optimise ton pilier 3a',
      whyNow: 'La date limite approche.',
      ctaLabel: 'Voir les options',
      ctaMode: CtaMode.route,
      ctaRoute: '/pilier-3a',
    );

MintUserState _stateWithGap() => MintUserState(
      profile: _minimalProfile(),
      lifecyclePhase: LifecyclePhase.consolidation,
      archetype: FinancialArchetype.swissNative,
      budgetGap: _sampleGap(),
      currentCap: _sampleCap(),
      activeGoalIntentTag: 'retraite',
      confidenceScore: 72.0,
      friScore: 58.0,
      replacementRate: 65.0,
      capMemory: const CapMemory(),
      activeNudges: const [],
      pendingTrigger: null,
      computedAt: DateTime(2026, 3, 21),
    );

MintUserState _stateNoProjections() => MintUserState(
      profile: _minimalProfile(),
      lifecyclePhase: LifecyclePhase.construction,
      archetype: FinancialArchetype.swissNative,
      confidenceScore: 20.0,
      capMemory: const CapMemory(),
      computedAt: DateTime(2026, 3, 21),
    );

// ────────────────────────────────────────────────────────────────────────────
//  Tests
// ────────────────────────────────────────────────────────────────────────────

void main() {
  group('MintUserState — construction', () {
    test('constructs with all required fields', () {
      final state = _stateWithGap();

      expect(state.profile.birthYear, 1977);
      expect(state.lifecyclePhase, LifecyclePhase.consolidation);
      expect(state.archetype, FinancialArchetype.swissNative);
      expect(state.confidenceScore, 72.0);
      expect(state.capMemory, isNotNull);
      expect(state.computedAt, DateTime(2026, 3, 21));
    });

    test('constructs with only required fields (nullables are null)', () {
      final state = _stateNoProjections();

      expect(state.budgetGap, isNull);
      expect(state.currentCap, isNull);
      expect(state.friScore, isNull);
      expect(state.replacementRate, isNull);
      expect(state.pendingTrigger, isNull);
      expect(state.activeGoalIntentTag, isNull);
      expect(state.capSequencePlan, isNull);
      expect(state.activeNudges, isEmpty);
    });

    test('stores profile reference unchanged', () {
      final profile = _minimalProfile();
      final state = MintUserState(
        profile: profile,
        lifecyclePhase: LifecyclePhase.demarrage,
        archetype: FinancialArchetype.swissNative,
        confidenceScore: 50.0,
        capMemory: const CapMemory(),
        computedAt: DateTime(2026, 3, 21),
      );

      expect(identical(state.profile, profile), isTrue);
    });
  });

  group('MintUserState — hasProjections / hasRetirement / hasGap', () {
    test('hasProjections is false when budgetGap is null', () {
      final state = _stateNoProjections();
      expect(state.hasProjections, isFalse);
    });

    test('hasProjections is true when budgetGap is present', () {
      final state = _stateWithGap();
      expect(state.hasProjections, isTrue);
    });

    test('hasRetirement mirrors hasProjections', () {
      expect(_stateNoProjections().hasRetirement, isFalse);
      expect(_stateWithGap().hasRetirement, isTrue);
    });

    test('hasGap mirrors hasProjections', () {
      expect(_stateNoProjections().hasGap, isFalse);
      expect(_stateWithGap().hasGap, isTrue);
    });
  });

  group('MintUserState — hasCap / hasNudges / hasPendingTrigger', () {
    test('hasCap is false when currentCap is null', () {
      expect(_stateNoProjections().hasCap, isFalse);
    });

    test('hasCap is true when currentCap is set', () {
      expect(_stateWithGap().hasCap, isTrue);
    });

    test('hasNudges is false for empty activeNudges', () {
      expect(_stateNoProjections().hasNudges, isFalse);
    });

    test('hasPendingTrigger is false when pendingTrigger is null', () {
      expect(_stateNoProjections().hasPendingTrigger, isFalse);
    });
  });

  group('MintUserState — isConfidenceSufficient', () {
    test('true when confidenceScore >= 45', () {
      final state = MintUserState(
        profile: _minimalProfile(),
        lifecyclePhase: LifecyclePhase.construction,
        archetype: FinancialArchetype.swissNative,
        confidenceScore: 45.0,
        capMemory: const CapMemory(),
        computedAt: DateTime.now(),
      );
      expect(state.isConfidenceSufficient, isTrue);
    });

    test('false when confidenceScore < 45', () {
      final state = MintUserState(
        profile: _minimalProfile(),
        lifecyclePhase: LifecyclePhase.construction,
        archetype: FinancialArchetype.swissNative,
        confidenceScore: 44.9,
        capMemory: const CapMemory(),
        computedAt: DateTime.now(),
      );
      expect(state.isConfidenceSufficient, isFalse);
    });

    test('false when confidenceScore is 0 (empty profile)', () {
      expect(_stateNoProjections().isConfidenceSufficient, isFalse);
    });
  });

  group('MintUserState — hasSignificantGap', () {
    test('false when replacementRate is null', () {
      expect(_stateNoProjections().hasSignificantGap, isFalse);
    });

    test('false when replacementRate >= 80', () {
      final state = _stateWithGap().copyWith(replacementRate: 80.0);
      expect(state.hasSignificantGap, isFalse);
    });

    test('false when replacementRate is exactly 80', () {
      final state = _stateWithGap().copyWith(replacementRate: 80.0);
      expect(state.hasSignificantGap, isFalse);
    });

    test('true when replacementRate < 80', () {
      final state = _stateWithGap().copyWith(replacementRate: 65.0);
      expect(state.hasSignificantGap, isTrue);
    });

    test('true for very low replacement rate (extreme case)', () {
      final state = _stateWithGap().copyWith(replacementRate: 10.0);
      expect(state.hasSignificantGap, isTrue);
    });
  });

  group('MintUserState — copyWith', () {
    test('copyWith returns new instance with replaced fields', () {
      final original = _stateWithGap();
      final copy = original.copyWith(confidenceScore: 90.0);

      expect(copy.confidenceScore, 90.0);
      expect(original.confidenceScore, 72.0); // original unchanged
      expect(copy.profile, original.profile); // other fields unchanged
    });

    test('copyWith with no args returns semantically equal state', () {
      final original = _stateWithGap();
      final copy = original.copyWith();

      expect(copy.lifecyclePhase, original.lifecyclePhase);
      expect(copy.archetype, original.archetype);
      expect(copy.confidenceScore, original.confidenceScore);
      expect(copy.replacementRate, original.replacementRate);
    });

    test('copyWith can set friScore independently', () {
      final state = _stateNoProjections().copyWith(friScore: 75.0);
      expect(state.friScore, 75.0);
    });

    test('copyWith preserves capSequencePlan', () {
      final original = _stateWithGap();
      final copy = original.copyWith(confidenceScore: 55.0);
      // capSequencePlan is null when not explicitly set — preserved across copy.
      expect(copy.capSequencePlan, original.capSequencePlan);
    });

    test('copyWith can set budgetSnapshot', () {
      final snap = _sampleSnapshot();
      final state = _stateNoProjections().copyWith(budgetSnapshot: snap);
      expect(state.budgetSnapshot, isNotNull);
      expect(state.budgetSnapshot!.present.monthlyFree, 3896.0);
    });

    test('copyWith can clear budgetSnapshot to null', () {
      final snap = _sampleSnapshot();
      final stateWithSnap = _stateNoProjections().copyWith(budgetSnapshot: snap);
      final cleared = stateWithSnap.copyWith(budgetSnapshot: null);
      expect(cleared.budgetSnapshot, isNull);
    });

    test('copyWith without budgetSnapshot argument preserves existing', () {
      final snap = _sampleSnapshot();
      final original = _stateNoProjections().copyWith(budgetSnapshot: snap);
      final copy = original.copyWith(confidenceScore: 25.0);
      expect(copy.budgetSnapshot, isNotNull);
    });
  });

  group('MintUserState — budgetSnapshot field', () {
    test('budgetSnapshot is null when not provided', () {
      final state = _stateNoProjections();
      expect(state.budgetSnapshot, isNull);
    });

    test('hasBudgetSnapshot is false when budgetSnapshot is null', () {
      final state = _stateNoProjections();
      expect(state.hasBudgetSnapshot, isFalse);
    });

    test('hasBudgetSnapshot is true when budgetSnapshot is set', () {
      final snap = _sampleSnapshot();
      final state = _stateNoProjections().copyWith(budgetSnapshot: snap);
      expect(state.hasBudgetSnapshot, isTrue);
    });

    test('monthlyFree is null when budgetSnapshot is null', () {
      expect(_stateNoProjections().monthlyFree, isNull);
    });

    test('monthlyFree returns present.monthlyFree when snapshot is set', () {
      final snap = _sampleSnapshot();
      final state = _stateNoProjections().copyWith(budgetSnapshot: snap);
      expect(state.monthlyFree, 3896.0);
    });

    test('budgetSnapshot stores all present budget fields correctly', () {
      final snap = _sampleSnapshot();
      final state = _stateNoProjections().copyWith(budgetSnapshot: snap);
      expect(state.budgetSnapshot!.present.monthlyNet, 7500.0);
      expect(state.budgetSnapshot!.present.monthlyCharges, 3000.0);
      expect(state.budgetSnapshot!.present.monthlySavings, 604.0);
      expect(state.budgetSnapshot!.confidenceScore, 72.0);
      expect(state.budgetSnapshot!.stage, BudgetStage.fullGapVisible);
    });

    test('budgetSnapshot is independent of budgetGap field', () {
      // budgetSnapshot and budgetGap can be set independently
      final snap = _sampleSnapshot();
      final stateWithBoth = _stateWithGap().copyWith(budgetSnapshot: snap);
      expect(stateWithBoth.budgetGap, isNotNull);
      expect(stateWithBoth.budgetSnapshot, isNotNull);

      final stateWithSnapOnly = _stateNoProjections().copyWith(budgetSnapshot: snap);
      expect(stateWithSnapOnly.budgetGap, isNull);
      expect(stateWithSnapOnly.budgetSnapshot, isNotNull);
    });
  });
}
