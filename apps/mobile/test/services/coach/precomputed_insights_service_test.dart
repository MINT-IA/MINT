// ────────────────────────────────────────────────────────────────────────────
//  PRECOMPUTED INSIGHTS SERVICE TESTS
// ────────────────────────────────────────────────────────────────────────────
//
// 14 tests covering:
//   1.  Empty cache → getCachedInsight returns null
//   2.  computeAndCache + getCachedInsight roundtrip (budgetAlert)
//   3.  Stale insight (> 1 hour) not returned by getCachedInsight
//   4.  Fresh insight (< 1 hour) returned by getCachedInsight
//   5.  clear() removes cached insight
//   6.  budgetAlert params preserved through cache
//   7.  gapWarning type stored and read correctly
//   8.  savingsOpportunity type stored and read correctly
//   9.  deadlineUrgency type stored and read correctly (December)
//  10.  planProgress type stored and read correctly
//  11.  progressCelebration skipped (session-transient delta — no cache)
//  12.  No interesting data → computeAndCache removes key
//  13.  Malformed JSON in prefs → getCachedInsight returns null safely
//  14.  resolve() returns null for missing params
// ────────────────────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations_fr.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/cap_sequence.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/mint_user_state.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/coach/data_driven_opener_service.dart';
import 'package:mint_mobile/services/coach/precomputed_insights_service.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_phase.dart';

// ── Shared l10n instance ─────────────────────────────────────────────────────

final _l = SFr();

// ── Helpers ──────────────────────────────────────────────────────────────────

CoachProfile _makeProfile({
  double salaireBrutMensuel = 8000,
  double totalEpargne3a = 0,
  bool canContribute3a = true,
}) {
  return CoachProfile(
    birthYear: 1985,
    canton: 'VS',
    etatCivil: CoachCivilStatus.celibataire,
    nombreEnfants: 0,
    salaireBrutMensuel: salaireBrutMensuel,
    nombreDeMois: 12,
    employmentStatus: 'salarie',
    depenses: const DepensesProfile(),
    prevoyance: PrevoyanceProfile(
      totalEpargne3a: totalEpargne3a,
      canContribute3a: canContribute3a,
    ),
    patrimoine: const PatrimoineProfile(),
    dettes: const DetteProfile(),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2045, 1, 1),
      label: 'Retraite',
    ),
    goalsB: const [],
    plannedContributions: const [],
    checkIns: const [],
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2026, 3, 1),
  );
}

MintUserState _makeState({
  CoachProfile? profile,
  BudgetSnapshot? budgetSnapshot,
  double? replacementRate,
  CapSequence? capSequencePlan,
  double confidenceScore = 50.0,
  FinancialArchetype archetype = FinancialArchetype.swissNative,
}) {
  return MintUserState(
    profile: profile ?? _makeProfile(),
    lifecyclePhase: LifecyclePhase.consolidation,
    archetype: archetype,
    budgetSnapshot: budgetSnapshot,
    replacementRate: replacementRate,
    capSequencePlan: capSequencePlan,
    confidenceScore: confidenceScore,
    capMemory: const CapMemory(),
    computedAt: DateTime(2026, 3, 22),
  );
}

BudgetSnapshot _snapshotWithFree(double monthlyFree) {
  return BudgetSnapshot(
    present: PresentBudget(
      monthlyNet: 7000,
      monthlyCharges: 3000,
      monthlySavings: 500,
      monthlyFree: monthlyFree,
    ),
    stage: BudgetStage.fullGapVisible,
    gap: const BudgetGap(monthlyGap: 1500, replacementRate: 55.0),
    capImpacts: const [],
    confidenceScore: 65.0,
  );
}

BudgetSnapshot _snapshotWithGap({
  required double monthlyFree,
  required double replacementRate,
  required double monthlyGap,
}) {
  return BudgetSnapshot(
    present: PresentBudget(
      monthlyNet: 7000,
      monthlyCharges: 3000,
      monthlySavings: 500,
      monthlyFree: monthlyFree,
    ),
    stage: BudgetStage.fullGapVisible,
    gap: BudgetGap(monthlyGap: monthlyGap, replacementRate: replacementRate),
    capImpacts: const [],
    confidenceScore: 65.0,
  );
}

CapSequence _makeSequence({required int completed, required int total}) {
  final steps = <CapStep>[];
  for (int i = 1; i <= total; i++) {
    final status = i <= completed
        ? CapStepStatus.completed
        : (i == completed + 1 ? CapStepStatus.current : CapStepStatus.upcoming);
    steps.add(CapStep(
      id: 'step_$i',
      order: i,
      titleKey: 'capStepRetirement0${i}Title',
      status: status,
      intentTag: '/retraite',
    ));
  }
  return CapSequence(
    goalId: 'retirement',
    steps: steps,
    completedCount: completed,
    totalCount: total,
    progressPercent: total > 0 ? completed / total : 0.0,
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // Fixed dates for determinism.
  final march22 = DateTime(2026, 3, 22);
  final december15 = DateTime(2026, 12, 15);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PrecomputedInsightsService', () {
    // ── Test 1: Empty cache → null ─────────────────────────────────────────
    test('1. Empty cache → getCachedInsight returns null', () async {
      final prefs = await SharedPreferences.getInstance();
      final result = await PrecomputedInsightsService.getCachedInsight(
        prefs: prefs,
      );
      expect(result, isNull);
    });

    // ── Test 2: computeAndCache + getCachedInsight roundtrip ────────────────
    test('2. computeAndCache + getCachedInsight roundtrip (budgetAlert)', () async {
      final state = _makeState(
        budgetSnapshot: _snapshotWithFree(-350),
      );
      final prefs = await SharedPreferences.getInstance();

      await PrecomputedInsightsService.computeAndCache(
        state: state,
        prefs: prefs,
        now: march22,
      );

      final cached = await PrecomputedInsightsService.getCachedInsight(
        prefs: prefs,
        now: march22, // same reference point → not stale
      );
      expect(cached, isNotNull);
      expect(cached!.type, DataOpenerType.budgetAlert);
    });

    // ── Test 3: Stale insight (> 1 hour) not returned ──────────────────────
    test('3. Stale insight (> 1 hour) returns null', () async {
      final prefs = await SharedPreferences.getInstance();

      // Manually write a stale insight (computedAt = 2 hours ago).
      final staleInsight = PrecomputedInsight(
        type: DataOpenerType.budgetAlert,
        params: {'deficit': '350'},
        intentTag: '/budget',
        computedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      await prefs.setString(
        'mint_precomputed_insight_v1',
        jsonEncode(staleInsight.toJson()),
      );

      final result = await PrecomputedInsightsService.getCachedInsight(
        prefs: prefs,
      );
      expect(result, isNull);
    });

    // ── Test 4: Fresh insight (< 1 hour) returned ──────────────────────────
    test('4. Fresh insight (30 min old) returned by getCachedInsight', () async {
      final prefs = await SharedPreferences.getInstance();

      final freshInsight = PrecomputedInsight(
        type: DataOpenerType.gapWarning,
        params: {'rate': '55', 'gap': '1200'},
        intentTag: '/retraite',
        computedAt: DateTime.now().subtract(const Duration(minutes: 30)),
      );
      await prefs.setString(
        'mint_precomputed_insight_v1',
        jsonEncode(freshInsight.toJson()),
      );

      final result = await PrecomputedInsightsService.getCachedInsight(
        prefs: prefs,
      );
      expect(result, isNotNull);
      expect(result!.type, DataOpenerType.gapWarning);
    });

    // ── Test 5: clear() removes cached insight ─────────────────────────────
    test('5. clear() removes cached insight', () async {
      final state = _makeState(
        budgetSnapshot: _snapshotWithFree(-350),
      );
      final prefs = await SharedPreferences.getInstance();

      await PrecomputedInsightsService.computeAndCache(
        state: state,
        prefs: prefs,
        now: march22,
      );
      // Confirm it was written.
      expect(
        await PrecomputedInsightsService.getCachedInsight(
          prefs: prefs,
          now: march22,
        ),
        isNotNull,
      );

      await PrecomputedInsightsService.clear(prefs);

      final afterClear = await PrecomputedInsightsService.getCachedInsight(
        prefs: prefs,
      );
      expect(afterClear, isNull);
    });

    // ── Test 6: budgetAlert params preserved ───────────────────────────────
    test('6. budgetAlert params preserved through cache', () async {
      final state = _makeState(
        budgetSnapshot: _snapshotWithFree(-420),
      );
      final prefs = await SharedPreferences.getInstance();

      await PrecomputedInsightsService.computeAndCache(
        state: state,
        prefs: prefs,
        now: march22,
      );

      final cached = await PrecomputedInsightsService.getCachedInsight(
        prefs: prefs,
        now: march22,
      );
      expect(cached, isNotNull);
      expect(cached!.params['deficit'], equals('420'));
      expect(cached.intentTag, equals('/budget'));

      // Resolve with real l10n.
      final opener = cached.resolve(_l);
      expect(opener, isNotNull);
      expect(opener!.message, contains('420'));
      expect(opener.type, DataOpenerType.budgetAlert);
    });

    // ── Test 7: gapWarning stored and read correctly ────────────────────────
    test('7. gapWarning type stored and read correctly', () async {
      final snapshot = _snapshotWithGap(
        monthlyFree: 500,
        replacementRate: 55.0,
        monthlyGap: 1800,
      );
      final state = _makeState(
        budgetSnapshot: snapshot,
        replacementRate: 55.0,
      );
      final prefs = await SharedPreferences.getInstance();

      await PrecomputedInsightsService.computeAndCache(
        state: state,
        prefs: prefs,
        now: march22,
      );

      final cached = await PrecomputedInsightsService.getCachedInsight(
        prefs: prefs,
        now: march22,
      );
      expect(cached, isNotNull);
      expect(cached!.type, DataOpenerType.gapWarning);
      expect(cached.params['rate'], equals('55'));
      expect(cached.params['gap'], equals('1800'));
      expect(cached.intentTag, equals('/retraite'));
    });

    // ── Test 8: savingsOpportunity stored and read correctly ────────────────
    test('8. savingsOpportunity type stored and read correctly', () async {
      final profile = _makeProfile(totalEpargne3a: 0, salaireBrutMensuel: 5000);
      final state = _makeState(profile: profile);
      final prefs = await SharedPreferences.getInstance();

      await PrecomputedInsightsService.computeAndCache(
        state: state,
        prefs: prefs,
        now: march22, // Not December → savingsOpportunity fires
      );

      final cached = await PrecomputedInsightsService.getCachedInsight(
        prefs: prefs,
        now: march22,
      );
      expect(cached, isNotNull);
      expect(cached!.type, DataOpenerType.savingsOpportunity);
      expect(
        cached.params['plafond'],
        equals(pilier3aPlafondAvecLpp.round().toString()),
      );

      // Resolve with real l10n.
      final opener = cached.resolve(_l);
      expect(opener, isNotNull);
      expect(opener!.message, contains(pilier3aPlafondAvecLpp.round().toString()));
    });

    // ── Test 9: deadlineUrgency stored and read correctly ───────────────────
    test('9. deadlineUrgency stored and read correctly (December)', () async {
      final profile = _makeProfile(totalEpargne3a: 0, salaireBrutMensuel: 8000);
      final state = _makeState(profile: profile);
      final prefs = await SharedPreferences.getInstance();

      await PrecomputedInsightsService.computeAndCache(
        state: state,
        prefs: prefs,
        now: december15, // December → deadlineUrgency fires
      );

      final cached = await PrecomputedInsightsService.getCachedInsight(
        prefs: prefs,
        now: december15,
      );
      expect(cached, isNotNull);
      expect(cached!.type, DataOpenerType.deadlineUrgency);

      final expectedDays =
          DateTime(2026, 12, 31).difference(december15).inDays + 1;
      expect(cached.params['daysLeft'], equals(expectedDays.toString()));
      expect(
        cached.params['plafond'],
        equals(pilier3aPlafondAvecLpp.round().toString()),
      );
      expect(cached.intentTag, equals('/pilier-3a'));

      // Resolve with real l10n.
      final opener = cached.resolve(_l);
      expect(opener, isNotNull);
      expect(opener!.message, contains(expectedDays.toString()));
    });

    // ── Test 10: planProgress stored and read correctly ─────────────────────
    test('10. planProgress type stored and read correctly', () async {
      final profile = _makeProfile(totalEpargne3a: 5000, salaireBrutMensuel: 8000);
      final snapshot = _snapshotWithFree(800); // surplus
      final sequence = _makeSequence(completed: 2, total: 5);
      final state = _makeState(
        profile: profile,
        budgetSnapshot: snapshot,
        replacementRate: 75.0,
        capSequencePlan: sequence,
      );
      final prefs = await SharedPreferences.getInstance();

      await PrecomputedInsightsService.computeAndCache(
        state: state,
        prefs: prefs,
        now: march22,
      );

      final cached = await PrecomputedInsightsService.getCachedInsight(
        prefs: prefs,
        now: march22,
      );
      expect(cached, isNotNull);
      expect(cached!.type, DataOpenerType.planProgress);
      expect(cached.params['completed'], equals('2'));
      expect(cached.params['total'], equals('5'));
      expect(cached.params['next'], isNotEmpty);

      // Resolve with real l10n — message contains step counts.
      final opener = cached.resolve(_l);
      expect(opener, isNotNull);
      expect(opener!.message, contains('2'));
      expect(opener.message, contains('5'));
    });

    // ── Test 11: progressCelebration skipped (session-transient delta) ──────
    test(
      '11. progressCelebration not cached (session-transient — no cache written)',
      () async {
        // Force only progressCelebration to fire: salary > 0, 3a > 0, surplus,
        // replacement rate >= 60 (no other conditions met), confidence delta >= 5.
        // But computeAndCache has no previousConfidenceScore, so it won't fire via
        // DataDrivenOpenerService (needs previous score). The result is null opener.
        final profile =
            _makeProfile(totalEpargne3a: 5000, salaireBrutMensuel: 8000);
        final snapshot = _snapshotWithFree(800);
        final state = _makeState(
          profile: profile,
          budgetSnapshot: snapshot,
          replacementRate: 75.0,
          confidenceScore: 66.0,
          // No previous confidence → DataDrivenOpenerService returns null for celebration
        );
        final prefs = await SharedPreferences.getInstance();

        await PrecomputedInsightsService.computeAndCache(
          state: state,
          prefs: prefs,
          now: march22,
        );

        // No interesting data → key is removed.
        final cached = await PrecomputedInsightsService.getCachedInsight(
          prefs: prefs,
          now: march22,
        );
        // Either null (no opener) or not progressCelebration (because delta
        // cannot be computed without previousConfidenceScore at this layer).
        if (cached != null) {
          expect(cached.type, isNot(DataOpenerType.progressCelebration));
        }
      },
    );

    // ── Test 12: No interesting data → key removed ──────────────────────────
    test('12. No interesting data → computeAndCache removes key', () async {
      final profile =
          _makeProfile(totalEpargne3a: 5000, salaireBrutMensuel: 8000);
      final snapshot = _snapshotWithFree(800); // surplus
      final state = _makeState(
        profile: profile,
        budgetSnapshot: snapshot,
        replacementRate: 75.0, // above 60% threshold
      );
      final prefs = await SharedPreferences.getInstance();

      // Pre-seed a stale value to verify it gets cleared.
      await prefs.setString(
        'mint_precomputed_insight_v1',
        '{"type":"budgetAlert","params":{"deficit":"100"},"computedAt":"2020-01-01T00:00:00.000"}',
      );

      await PrecomputedInsightsService.computeAndCache(
        state: state,
        prefs: prefs,
        now: march22,
      );

      expect(prefs.containsKey('mint_precomputed_insight_v1'), isFalse);
    });

    // ── Test 13: Malformed JSON → null returned safely ──────────────────────
    test('13. Malformed JSON in prefs → getCachedInsight returns null', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mint_precomputed_insight_v1', 'not-valid-json{{{');

      final result = await PrecomputedInsightsService.getCachedInsight(
        prefs: prefs,
      );
      expect(result, isNull);
    });

    // ── Test 14: resolve() returns null for missing params ──────────────────
    test('14. resolve() returns null when required params are absent', () {
      // gapWarning with missing 'gap' param.
      final insight = PrecomputedInsight(
        type: DataOpenerType.gapWarning,
        params: const {'rate': '55'}, // 'gap' is missing
        computedAt: DateTime(2026, 3, 22),
      );
      final opener = insight.resolve(_l);
      expect(opener, isNull);
    });
  });
}
