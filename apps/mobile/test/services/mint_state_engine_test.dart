import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/mint_user_state.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_phase.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/mint_state_engine.dart';
import 'package:mint_mobile/services/session_snapshot_service.dart';

// ────────────────────────────────────────────────────────────────────────────
//  Helpers
// ────────────────────────────────────────────────────────────────────────────

/// Minimal profile — only required fields.
CoachProfile _emptyProfile() => CoachProfile(
      birthYear: 1990,
      canton: 'ZH',
      salaireBrutMensuel: 5000,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2055),
        label: 'Retraite',
      ),
    );

CoachProfile _certifiedDemoProfile() {
  // ignore: deprecated_member_use
  final profile = CoachProfile.buildDemo();
  final spouse = profile.conjoint!;
  return profile.copyWith(
    prevoyance: profile.prevoyance.copyWith(
      lacunesAVS: 0,
    ),
    conjoint: spouse.copyWith(
      prevoyance: spouse.prevoyance!.copyWith(
        lacunesAVS: 14,
        ramd: 60000,
        anneesContribuees: 25,
      ),
    ),
    dataSources: {
      ...profile.dataSources,
      AvsGapEvidence.selfFieldPath: ProfileDataSource.certificate,
      AvsGapEvidence.spouseFieldPath: ProfileDataSource.certificate,
      ForecasterService.spouseRamdFieldPath: ProfileDataSource.certificate,
      ForecasterService.spouseContributionYearsFieldPath:
          ProfileDataSource.certificate,
    },
  );
}

// ────────────────────────────────────────────────────────────────────────────
//  Tests
// ────────────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MintStateEngine — empty profile', () {
    test('returns a MintUserState (never throws)', () async {
      final prefs = await SharedPreferences.getInstance();
      final state = await MintStateEngine.compute(
        profile: _emptyProfile(),
        prefs: prefs,
        now: DateTime(2026, 3, 21),
      );
      expect(state, isA<MintUserState>());
    });

    test('lifecycle phase is set for profile aged 36', () async {
      final prefs = await SharedPreferences.getInstance();
      final state = await MintStateEngine.compute(
        profile: _emptyProfile(), // birthYear 1990 → age 36
        prefs: prefs,
        now: DateTime(2026, 3, 21),
      );
      // Age 36 → acceleration phase (35-44 boundary in LifecycleDetector)
      expect(state.lifecyclePhase, LifecyclePhase.acceleration);
    });

    test('archetype matches profile archetype getter', () async {
      final profile = _emptyProfile();
      final prefs = await SharedPreferences.getInstance();
      final state = await MintStateEngine.compute(
        profile: profile,
        prefs: prefs,
        now: DateTime(2026, 3, 21),
      );
      expect(state.archetype, profile.archetype);
    });

    test('confidenceScore is between 0 and 100', () async {
      final prefs = await SharedPreferences.getInstance();
      final state = await MintStateEngine.compute(
        profile: _emptyProfile(),
        prefs: prefs,
        now: DateTime(2026, 3, 21),
      );
      expect(state.confidenceScore, inInclusiveRange(0.0, 100.0));
    });

    test('capMemory is non-null (defaults to empty)', () async {
      final prefs = await SharedPreferences.getInstance();
      final state = await MintStateEngine.compute(
        profile: _emptyProfile(),
        prefs: prefs,
        now: DateTime(2026, 3, 21),
      );
      expect(state.capMemory, isNotNull);
    });

    test('empty profile has low confidence → no projections', () async {
      final prefs = await SharedPreferences.getInstance();
      final state = await MintStateEngine.compute(
        profile: _emptyProfile(),
        prefs: prefs,
        now: DateTime(2026, 3, 21),
      );
      // Minimal profile has confidence well below 30 → projections skipped
      if (state.confidenceScore < 30.0) {
        expect(state.hasProjections, isFalse);
        expect(state.friScore, isNull);
        expect(state.replacementRate, isNull);
        // Present-day budget remains available without unlocking projections.
        expect(state.budgetSnapshot, isNotNull);
        expect(state.budgetSnapshot!.stage, BudgetStage.presentOnly);
        expect(state.hasBudgetSnapshot, isTrue);
        expect(state.monthlyFree, isNotNull);
        expect(state.monthlyFree!.isFinite, isTrue);
      }
    });

    test('computedAt matches the injected now', () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime(2026, 3, 21, 14, 30);
      final state = await MintStateEngine.compute(
        profile: _emptyProfile(),
        prefs: prefs,
        now: now,
      );
      expect(state.computedAt, now);
    });

    test('nudges are a list (may be empty for fresh profile)', () async {
      final prefs = await SharedPreferences.getInstance();
      final state = await MintStateEngine.compute(
        profile: _emptyProfile(),
        prefs: prefs,
        now: DateTime(2026, 3, 21),
      );
      expect(state.activeNudges, isA<List>());
    });

    test('missing retirement budget omits session delta', () async {
      await SessionSnapshotService.save(
        SessionSnapshot(
          confidenceScore: 50,
          monthlyRetirementIncome: 4000,
          fhsScore: 60,
          savedAt: DateTime(2026, 3, 20),
        ),
      );
      final prefs = await SharedPreferences.getInstance();

      final state = await MintStateEngine.compute(
        profile: _emptyProfile(),
        prefs: prefs,
        now: DateTime(2026, 3, 21),
      );

      expect(state.budgetGap, isNull);
      expect(state.sessionDelta, isNull);
    });

    test('partial retirement omits budget gap, FRI, and session delta',
        () async {
      await SessionSnapshotService.save(
        SessionSnapshot(
          confidenceScore: 50,
          monthlyRetirementIncome: 4000,
          fhsScore: 60,
          savedAt: DateTime(2026, 3, 20),
        ),
      );
      final profile = _certifiedDemoProfile().copyWith(
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2020),
          label: 'Retraite',
        ),
      );
      final prefs = await SharedPreferences.getInstance();

      final state = await MintStateEngine.compute(
        profile: profile,
        prefs: prefs,
        now: DateTime(2026, 3, 21),
      );

      expect(state.budgetGap, isNull);
      expect(state.friScore, isNull);
      expect(state.sessionDelta, isNull);
    });
  });

  group('MintStateEngine — Julien (golden profile)', () {
    late CoachProfile julien;

    setUp(() {
      julien = _certifiedDemoProfile();
    });

    test('returns a complete MintUserState for Julien', () async {
      final prefs = await SharedPreferences.getInstance();
      final state = await MintStateEngine.compute(
        profile: julien,
        prefs: prefs,
        now: DateTime(2026, 3, 21),
      );
      expect(state, isA<MintUserState>());
    });

    test('Julien lifecycle phase is consolidation (age 49)', () async {
      final prefs = await SharedPreferences.getInstance();
      final state = await MintStateEngine.compute(
        profile: julien,
        prefs: prefs,
        now: DateTime(2026, 3, 21),
      );
      // Julien born 1977, age 49 → consolidation (45-55)
      expect(state.lifecyclePhase, LifecyclePhase.consolidation);
    });

    test('Julien archetype is swissNative', () async {
      final prefs = await SharedPreferences.getInstance();
      final state = await MintStateEngine.compute(
        profile: julien,
        prefs: prefs,
        now: DateTime(2026, 3, 21),
      );
      expect(state.archetype, FinancialArchetype.swissNative);
    });

    test('Julien confidence score is meaningful (>= 30)', () async {
      final prefs = await SharedPreferences.getInstance();
      final state = await MintStateEngine.compute(
        profile: julien,
        prefs: prefs,
        now: DateTime(2026, 3, 21),
      );
      // Julien has salary, LPP, 3a, couple → confidence should be substantial
      expect(state.confidenceScore, greaterThanOrEqualTo(30.0));
    });

    test('Julien cap is computed (non-null)', () async {
      final prefs = await SharedPreferences.getInstance();
      final state = await MintStateEngine.compute(
        profile: julien,
        prefs: prefs,
        now: DateTime(2026, 3, 21),
      );
      expect(state.currentCap, isNotNull);
    });

    test('Julien cap has a non-empty id and headline', () async {
      final prefs = await SharedPreferences.getInstance();
      final state = await MintStateEngine.compute(
        profile: julien,
        prefs: prefs,
        now: DateTime(2026, 3, 21),
      );
      expect(state.currentCap!.id, isNotEmpty);
      expect(state.currentCap!.headline, isNotEmpty);
    });

    test('Julien profile is preserved verbatim in state', () async {
      final prefs = await SharedPreferences.getInstance();
      final state = await MintStateEngine.compute(
        profile: julien,
        prefs: prefs,
        now: DateTime(2026, 3, 21),
      );
      expect(state.profile.birthYear, 1977);
      expect(state.profile.canton, 'VS');
    });

    test('Julien confidence cannot bypass the AVS hard floor', () async {
      final prefs = await SharedPreferences.getInstance();
      final state = await MintStateEngine.compute(
        profile: julien,
        prefs: prefs,
        now: DateTime(2026, 3, 21),
      );
      // Confidence is independent from official AVS readiness.
      if (state.confidenceScore >= 30.0) {
        expect(state.replacementRate, isNull);
        expect(state.budgetGap, isNull);
        expect(state.friScore, isNull);
      }
    });

    test('Julien budgetSnapshot is populated (single computation source)',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final state = await MintStateEngine.compute(
        profile: julien,
        prefs: prefs,
        now: DateTime(2026, 3, 21),
      );
      // Julien has salary + age → BudgetLivingEngine should produce a snapshot.
      expect(state.budgetSnapshot, isNotNull);
    });

    test('Julien hasBudgetSnapshot is true', () async {
      final prefs = await SharedPreferences.getInstance();
      final state = await MintStateEngine.compute(
        profile: julien,
        prefs: prefs,
        now: DateTime(2026, 3, 21),
      );
      expect(state.hasBudgetSnapshot, isTrue);
    });

    test('Julien monthlyFree is non-null and finite', () async {
      final prefs = await SharedPreferences.getInstance();
      final state = await MintStateEngine.compute(
        profile: julien,
        prefs: prefs,
        now: DateTime(2026, 3, 21),
      );
      expect(state.monthlyFree, isNotNull);
      expect(state.monthlyFree!.isFinite, isTrue);
    });

    test('Julien budgetSnapshot present budget has positive net income',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final state = await MintStateEngine.compute(
        profile: julien,
        prefs: prefs,
        now: DateTime(2026, 3, 21),
      );
      final snap = state.budgetSnapshot;
      if (snap != null) {
        expect(snap.present.monthlyNet, greaterThan(0));
      }
    });
  });

  group('MintStateEngine — AVS readiness', () {
    test('omits replacement rate and FRI for an unverified profile', () async {
      // ignore: deprecated_member_use
      final profile = CoachProfile.buildDemo();
      final prefs = await SharedPreferences.getInstance();

      final state = await MintStateEngine.compute(
        profile: profile,
        prefs: prefs,
        now: DateTime(2026, 3, 21),
      );

      expect(state.confidenceScore, greaterThanOrEqualTo(30));
      expect(state.replacementRate, isNull);
      expect(state.friScore, isNull);
    });
  });

  group('MintStateEngine — CapMemory integration', () {
    test('empty prefs → empty CapMemory (no completed actions)', () async {
      final prefs = await SharedPreferences.getInstance();
      final state = await MintStateEngine.compute(
        profile: _emptyProfile(),
        prefs: prefs,
        now: DateTime(2026, 3, 21),
      );
      expect(state.capMemory.completedActions, isEmpty);
      expect(state.capMemory.abandonedFlows, isEmpty);
    });

    test('activeGoalIntentTag is null when no goals declared', () async {
      final prefs = await SharedPreferences.getInstance();
      final state = await MintStateEngine.compute(
        profile: _emptyProfile(),
        prefs: prefs,
        now: DateTime(2026, 3, 21),
      );
      expect(state.activeGoalIntentTag, isNull);
    });
  });

  group('MintStateEngine — determinism', () {
    test('same inputs produce same state', () async {
      final profile = _emptyProfile();
      final now = DateTime(2026, 3, 21, 10, 0);

      SharedPreferences.setMockInitialValues({});
      final prefs1 = await SharedPreferences.getInstance();
      final state1 = await MintStateEngine.compute(
        profile: profile,
        prefs: prefs1,
        now: now,
      );

      SharedPreferences.setMockInitialValues({});
      final prefs2 = await SharedPreferences.getInstance();
      final state2 = await MintStateEngine.compute(
        profile: profile,
        prefs: prefs2,
        now: now,
      );

      expect(state1.confidenceScore, state2.confidenceScore);
      expect(state1.lifecyclePhase, state2.lifecyclePhase);
      expect(state1.archetype, state2.archetype);
      expect(state1.computedAt, state2.computedAt);
    });
  });
}
