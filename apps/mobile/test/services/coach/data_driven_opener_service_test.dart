import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations_fr.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/cap_sequence.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/mint_user_state.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/coach/data_driven_opener_service.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_phase.dart';

// ────────────────────────────────────────────────────────────────────────────
//  DATA-DRIVEN OPENER SERVICE TESTS — S52
// ────────────────────────────────────────────────────────────────────────────
//
// 18 tests covering:
//   1.  Budget deficit → budgetAlert
//   2.  Budget surplus → no budgetAlert
//   3.  No budget snapshot → no budgetAlert
//   4.  December + 3a empty + salary → deadlineUrgency
//   5.  December + 3a full (>= plafond) → no deadlineUrgency
//   6.  November + 3a empty → no deadlineUrgency (not December)
//   7.  December + FATCA (canContribute3a=false) → no deadlineUrgency
//   8.  Replacement rate 55 % → gapWarning
//   9.  Replacement rate 65 % (>= threshold) → no gapWarning
//  10.  Replacement rate null → no gapWarning
//  11.  3a = 0 + salary > 0 → savingsOpportunity
//  12.  3a > 0 → no savingsOpportunity
//  13.  Confidence improved 6 pts → progressCelebration
//  14.  Confidence improved 4 pts (< threshold) → no progressCelebration
//  15.  No previous confidence → no progressCelebration
//  16.  CapSequence step completed → planProgress
//  17.  No interesting data → null
//  18.  Priority ordering: deficit > deadline > gap (Julien scenario)
// ────────────────────────────────────────────────────────────────────────────

/// French localizations instance — no BuildContext needed.
final _l = SFr();

// ── Helpers ───────────────────────────────────────────────────────────────

/// Minimal Swiss salarié profile for testing.
CoachProfile _makeProfile({
  int birthYear = 1985,
  double salaireBrutMensuel = 8000,
  double totalEpargne3a = 0,
  bool canContribute3a = true,
  bool usTaxPerson = false,
  String? nationality,
  List<PlannedMonthlyContribution> plannedContributions = const [],
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: 'VS',
    etatCivil: CoachCivilStatus.celibataire,
    nombreEnfants: 0,
    salaireBrutMensuel: salaireBrutMensuel,
    nombreDeMois: 12,
    employmentStatus: 'salarie',
    usTaxPerson: usTaxPerson,
    nationality: nationality,
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
    plannedContributions: plannedContributions,
    checkIns: const [],
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2026, 3, 1),
  );
}

/// Build a [MintUserState] with the given parameters.
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

/// Build a [BudgetSnapshot] with a monthly free margin.
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

/// Build a present-only budget snapshot with no retirement gap.
BudgetSnapshot _presentOnlySnapshotWithFree(double monthlyFree) {
  return BudgetSnapshot(
    present: PresentBudget(
      monthlyNet: 5000,
      monthlyCharges: 3078,
      monthlySavings: 0,
      monthlyFree: monthlyFree,
    ),
    stage: BudgetStage.presentOnly,
    capImpacts: const [],
    confidenceScore: 45.0,
  );
}

/// Build a [BudgetSnapshot] with a specific gap and replacement rate.
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

/// Build a [CapSequence] with [completed] steps out of [total].
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

// ── Tests ─────────────────────────────────────────────────────────────────

void main() {
  // Fixed test dates for determinism.
  final december15 = DateTime(2026, 12, 15);
  final november15 = DateTime(2026, 11, 15);
  final march22 = DateTime(2026, 3, 22);

  group('DataDrivenOpenerService', () {
    // ── Test 1: Budget deficit → budgetAlert ──────────────────
    test('1. Monthly deficit → budgetAlert with CHF amount', () {
      final state = _makeState(
        budgetSnapshot: _snapshotWithFree(-350),
      );
      final opener = DataDrivenOpenerService.generate(
        state: state,
        l: _l,
        now: march22,
      );
      expect(opener, isNotNull);
      expect(opener!.type, DataOpenerType.budgetAlert);
      // Message must contain a CHF number (the deficit).
      expect(opener.message, contains('350'));
      // Message must NOT be empty.
      expect(opener.message, isNotEmpty);
      expect(opener.intentTag, equals('/budget'));
    });

    // ── Test 2: Budget surplus → no budgetAlert ───────────────
    test('2. Monthly surplus → no budgetAlert', () {
      final state = _makeState(
        budgetSnapshot: _presentOnlySnapshotWithFree(1922),
      );
      final opener = DataDrivenOpenerService.generate(
        state: state,
        l: _l,
        now: march22,
      );
      expect(opener, isNotNull);
      expect(opener!.type, DataOpenerType.budgetRoom);
      expect(opener.message, contains("1'922"));
      expect(opener.intentTag, equals('/budget'));
    });

    test('2b. Monthly surplus with full gap keeps budget room priority', () {
      final state = _makeState(
        budgetSnapshot: _snapshotWithFree(1922),
        replacementRate: 55,
      );
      final opener = DataDrivenOpenerService.generate(
        state: state,
        l: _l,
        now: march22,
      );
      expect(opener, isNotNull);
      expect(opener!.type, DataOpenerType.budgetRoom);
      expect(opener.type, isNot(DataOpenerType.budgetAlert));
      expect(opener.type, isNot(DataOpenerType.gapWarning));
      expect(opener.message, contains("1'922"));
      expect(opener.intentTag, equals('/budget'));
    });

    // ── Test 3: No budget snapshot → no budgetAlert ───────────
    test('3. No budget snapshot → no budgetAlert', () {
      final state = _makeState(); // budgetSnapshot = null
      final opener = DataDrivenOpenerService.generate(
        state: state,
        l: _l,
        now: march22,
      );
      expect(opener?.type, isNot(DataOpenerType.budgetAlert));
    });

    // ── Test 4: December + 3a empty + salary → deadlineUrgency
    test('4. December + 3a empty + salary → deadlineUrgency', () {
      final profile = _makeProfile(totalEpargne3a: 0, salaireBrutMensuel: 8000);
      final state = _makeState(profile: profile);
      final opener = DataDrivenOpenerService.generate(
        state: state,
        l: _l,
        now: december15,
      );
      expect(opener, isNotNull);
      expect(opener!.type, DataOpenerType.deadlineUrgency);
      // Message must contain the number of days remaining.
      final daysLeft = DateTime(2026, 12, 31).difference(december15).inDays + 1;
      expect(opener.message, contains(daysLeft.toString()));
      // Message must contain the Swiss-formatted plafond amount.
      expect(opener.message, contains("7'258"));
      expect(opener.message, isNot(contains('7258 CHF')));
      expect(opener.intentTag, equals('/pilier-3a'));
    });

    test('4b. December deadline shows remaining room after planned 3a', () {
      final profile = _makeProfile(
        totalEpargne3a: 12000,
        salaireBrutMensuel: 8000,
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: '3a_monthly',
            label: '3a mensuel',
            amount: 250,
            category: '3a',
          ),
        ],
      );
      final state = _makeState(profile: profile);
      final opener = DataDrivenOpenerService.generate(
        state: state,
        l: _l,
        now: december15,
      );

      expect(opener, isNotNull);
      expect(opener!.type, DataOpenerType.deadlineUrgency);
      expect(opener.message, contains("4'258"));
      expect(opener.message, isNot(contains("7'258")));
    });

    // ── Test 5: December + 3a full → no deadlineUrgency ───────
    test('5. December + 3a planned full → no deadlineUrgency', () {
      final profile = _makeProfile(
        salaireBrutMensuel: 8000,
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: '3a_full',
            label: '3a complet',
            amount: 605,
            category: '3a',
          ),
        ],
      );
      final state = _makeState(profile: profile);
      final opener = DataDrivenOpenerService.generate(
        state: state,
        l: _l,
        now: december15,
      );
      expect(opener?.type, isNot(DataOpenerType.deadlineUrgency));
    });

    // ── Test 6: November + 3a empty → no deadlineUrgency ──────
    test('6. November + 3a empty → no deadlineUrgency (not December)', () {
      final profile = _makeProfile(totalEpargne3a: 0, salaireBrutMensuel: 8000);
      final state = _makeState(profile: profile);
      final opener = DataDrivenOpenerService.generate(
        state: state,
        l: _l,
        now: november15,
      );
      expect(opener?.type, isNot(DataOpenerType.deadlineUrgency));
    });

    // ── Test 7: December + FATCA → no deadlineUrgency ─────────
    test('7. December + canContribute3a=false → no deadlineUrgency', () {
      final profile = _makeProfile(
        totalEpargne3a: 0,
        salaireBrutMensuel: 8000,
        canContribute3a: false,
      );
      final state = _makeState(profile: profile);
      final opener = DataDrivenOpenerService.generate(
        state: state,
        l: _l,
        now: december15,
      );
      expect(opener?.type, isNot(DataOpenerType.deadlineUrgency));
    });

    // ── Codex P1 gap closure — US person leak via wrong eligibility source ──
    //
    // Test 7 above sets prevoyance.canContribute3a=false explicitly. The real
    // leak: a US person built via the normal flow keeps prevoyance.canContribute3a
    // at its default `true` (CoachProfile.fromWizardAnswers never sets it), so
    // the opener — which gated on prevoyance.canContribute3a — fired a 3a
    // opener for someone who cannot contribute (FATCA, CLAUDE.md NEVER #7). The
    // fix switches the opener to the archetype-aware top-level getter
    // profile.canContribute3a.
    test('7b. December + US person (usTaxPerson) → no deadlineUrgency (Codex P1)',
        () {
      final profile = _makeProfile(
        totalEpargne3a: 0,
        salaireBrutMensuel: 8000,
        usTaxPerson: true,
        nationality: 'US',
        // prevoyance.canContribute3a left at default true — this is the leak.
      );
      expect(profile.prevoyance.canContribute3a, isTrue,
          reason: 'fixture sanity: the leaking default the gate used to read');
      expect(profile.canContribute3a, isFalse,
          reason: 'archetype-aware getter correctly blocks the US person');

      final state = _makeState(
        profile: profile,
        archetype: FinancialArchetype.expatUs,
      );
      final opener = DataDrivenOpenerService.generate(
        state: state,
        l: _l,
        now: december15,
      );
      expect(opener?.type, isNot(DataOpenerType.deadlineUrgency),
          reason: 'US person must never see a 3a deadline opener (FATCA)');
    });

    test('12b. US person (usTaxPerson) → no savingsOpportunity (Codex P1)', () {
      final profile = _makeProfile(
        totalEpargne3a: 0,
        salaireBrutMensuel: 8000,
        usTaxPerson: true,
        nationality: 'US',
      );
      final state = _makeState(
        profile: profile,
        archetype: FinancialArchetype.expatUs,
      );
      final opener = DataDrivenOpenerService.generate(
        state: state,
        l: _l,
        now: march22,
      );
      expect(opener?.type, isNot(DataOpenerType.savingsOpportunity),
          reason: 'US person must never see a 3a savings opener (FATCA)');
    });

    // ── Test 8: Replacement rate 55% → gapWarning ─────────────
    test('8. Replacement rate 55% → gapWarning with numbers', () {
      final snapshot = _snapshotWithGap(
        monthlyFree: 0,
        replacementRate: 55.0,
        monthlyGap: 1200,
      );
      final state = _makeState(
        budgetSnapshot: snapshot,
        replacementRate: 55.0,
      );
      final opener = DataDrivenOpenerService.generate(
        state: state,
        l: _l,
        now: march22,
      );
      expect(opener, isNotNull);
      expect(opener!.type, DataOpenerType.gapWarning);
      // Message must contain rate and gap numbers.
      expect(opener.message, contains('55'));
      expect(opener.message, contains('1200'));
      expect(opener.intentTag, equals('/retraite'));
    });

    // ── Test 9: Replacement rate 65% → no gapWarning ──────────
    test('9. Replacement rate 65% (>= 60%) → no gapWarning', () {
      final snapshot = _snapshotWithGap(
        monthlyFree: 500,
        replacementRate: 65.0,
        monthlyGap: 800,
      );
      final state = _makeState(
        budgetSnapshot: snapshot,
        replacementRate: 65.0,
      );
      final opener = DataDrivenOpenerService.generate(
        state: state,
        l: _l,
        now: march22,
      );
      expect(opener?.type, isNot(DataOpenerType.gapWarning));
    });

    // ── Test 10: Replacement rate null → no gapWarning ────────
    test('10. Replacement rate null → no gapWarning', () {
      final state = _makeState(); // replacementRate = null
      final opener = DataDrivenOpenerService.generate(
        state: state,
        l: _l,
        now: march22,
      );
      expect(opener?.type, isNot(DataOpenerType.gapWarning));
    });

    // ── Test 11: 3a = 0 + salary > 0 → savingsOpportunity ─────
    test('11. 3a = 0 + salary > 0 → savingsOpportunity with room', () {
      final profile = _makeProfile(totalEpargne3a: 0, salaireBrutMensuel: 5000);
      final state = _makeState(profile: profile);
      // Use a month that is not December to avoid deadlineUrgency taking priority.
      final opener = DataDrivenOpenerService.generate(
        state: state,
        l: _l,
        now: march22,
      );
      expect(opener, isNotNull);
      expect(opener!.type, DataOpenerType.savingsOpportunity);
      expect(opener.message, contains("7'258"));
      expect(opener.message, isNot(contains('7258 CHF')));
      expect(opener.message, isNot(contains("d’économie d’impôt")));
      expect(opener.intentTag, equals('/pilier-3a'));
    });

    test('11b. savingsOpportunity uses planned-contribution remaining room',
        () {
      final profile = _makeProfile(
        totalEpargne3a: 0,
        salaireBrutMensuel: 5000,
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: '3a_monthly',
            label: '3a mensuel',
            amount: 250,
            category: '3a',
          ),
        ],
      );
      final state = _makeState(profile: profile);

      final opener = DataDrivenOpenerService.generate(
        state: state,
        l: _l,
        now: march22,
      );

      expect(opener, isNotNull);
      expect(opener!.type, DataOpenerType.savingsOpportunity);
      expect(opener.message, contains("4'258"));
      expect(opener.message, isNot(contains("7'258")));
    });

    test('11c. independent without LPP uses income-based 3a room', () {
      final profile = _makeProfile(
        totalEpargne3a: 0,
        salaireBrutMensuel: 8000,
      );
      final state = _makeState(
        profile: profile,
        archetype: FinancialArchetype.independentNoLpp,
      );

      final opener = DataDrivenOpenerService.generate(
        state: state,
        l: _l,
        now: march22,
      );

      expect(opener, isNotNull);
      expect(opener!.type, DataOpenerType.savingsOpportunity);
      expect(opener.message, contains("19'200"));
      expect(opener.message, isNot(contains("36'288")));
    });

    // ── Test 12: 3a > 0 → no savingsOpportunity ───────────────
    test('12. 3a > 0 → no savingsOpportunity', () {
      final profile =
          _makeProfile(totalEpargne3a: 1000, salaireBrutMensuel: 5000);
      final state = _makeState(profile: profile);
      final opener = DataDrivenOpenerService.generate(
        state: state,
        l: _l,
        now: march22,
      );
      expect(opener?.type, isNot(DataOpenerType.savingsOpportunity));
    });

    // ── Test 13: Confidence improved 6 pts → progressCelebration
    test('13. Confidence +6 pts → progressCelebration with delta', () {
      // Use a profile with 3a > 0 (above 0) so savingsOpportunity does not fire.
      // No budget snapshot so budget room does not mask progress.
      // Use march22 (not December) so deadlineUrgency does not fire.
      // replacementRate >= 60 so gapWarning does not fire.
      final profile =
          _makeProfile(totalEpargne3a: 5000, salaireBrutMensuel: 8000);
      final state = _makeState(
        profile: profile,
        replacementRate: 75.0,
        confidenceScore: 66.0,
      );
      final opener = DataDrivenOpenerService.generate(
        state: state,
        l: _l,
        now: march22,
        previousConfidenceScore: 60.0,
      );
      expect(opener, isNotNull);
      expect(opener!.type, DataOpenerType.progressCelebration);
      expect(opener.message, contains('6'));
    });

    // ── Test 14: Confidence +4 pts → no progressCelebration ───
    test('14. Confidence +4 pts (< threshold 5) → no progressCelebration', () {
      final state = _makeState(confidenceScore: 64.0);
      final opener = DataDrivenOpenerService.generate(
        state: state,
        l: _l,
        now: march22,
        previousConfidenceScore: 60.0,
      );
      expect(opener?.type, isNot(DataOpenerType.progressCelebration));
    });

    // ── Test 15: No previous confidence → no progressCelebration
    test('15. No previous confidence → no progressCelebration', () {
      final state = _makeState(confidenceScore: 80.0);
      final opener = DataDrivenOpenerService.generate(
        state: state,
        l: _l,
        now: march22,
        // previousConfidenceScore not provided → null
      );
      expect(opener?.type, isNot(DataOpenerType.progressCelebration));
    });

    // ── Test 16: CapSequence step completed → planProgress ─────
    test('16. CapSequence 2/5 steps → planProgress with n/total/next', () {
      // Use a profile with 3a > 0, no budget snapshot, replacement rate >= 60.
      // This ensures all higher-priority openers are suppressed.
      final profile =
          _makeProfile(totalEpargne3a: 5000, salaireBrutMensuel: 8000);
      final sequence = _makeSequence(completed: 2, total: 5);
      final state = _makeState(
        profile: profile,
        replacementRate: 75.0,
        capSequencePlan: sequence,
      );
      final opener = DataDrivenOpenerService.generate(
        state: state,
        l: _l,
        now: march22,
      );
      expect(opener, isNotNull);
      expect(opener!.type, DataOpenerType.planProgress);
      // Message must contain step counts.
      expect(opener.message, contains('2'));
      expect(opener.message, contains('5'));
    });

    // ── Test 17: No interesting data → null ───────────────────
    test('17. No interesting data → null', () {
      // Profile: salary > 0, 3a > 0, no budget snapshot, no sequence, no delta.
      final profile = _makeProfile(
        totalEpargne3a: 5000,
        salaireBrutMensuel: 8000,
      );
      final state = _makeState(
        profile: profile,
        replacementRate: 75.0, // above threshold
      );
      final opener = DataDrivenOpenerService.generate(
        state: state,
        l: _l,
        now: march22,
        previousConfidenceScore: 50.0, // only +0 pts delta
      );
      expect(opener, isNull);
    });

    // ── Test 18: Priority: deficit > deadline > gap (Julien) ───
    test('18. Julien: deficit beats deadline and gap — budgetAlert wins', () {
      // Julien profile (golden couple, 49 ans, VS, salaire 122'207 CHF/an).
      final julienProfile = CoachProfile(
        firstName: 'Julien',
        birthYear: 1977,
        canton: 'VS',
        etatCivil: CoachCivilStatus.marie,
        nombreEnfants: 0,
        salaireBrutMensuel: 10184, // 122'207 / 12
        nombreDeMois: 12,
        employmentStatus: 'salarie',
        nationality: 'CH',
        depenses: const DepensesProfile(),
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 70377,
          rachatMaximum: 539414,
          anneesContribuees: 24,
          totalEpargne3a:
              0, // 3a empty this year → deadline + savings candidates
        ),
        patrimoine: const PatrimoineProfile(epargneLiquide: 50000),
        dettes: const DetteProfile(),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2042, 1, 1),
          label: 'Retraite',
        ),
        goalsB: const [],
        plannedContributions: const [],
        checkIns: const [],
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      // Scenario: Julien has a deficit AND it's December AND replacement rate < 60%.
      final julienSnapshot = _snapshotWithGap(
        monthlyFree: -400, // deficit! — highest priority
        replacementRate: 55.0, // also below threshold
        monthlyGap: 2000,
      );
      final state = _makeState(
        profile: julienProfile,
        budgetSnapshot: julienSnapshot,
        replacementRate: 55.0,
      );

      // Test in December — deadline + gap are candidates, but deficit wins.
      final opener = DataDrivenOpenerService.generate(
        state: state,
        l: _l,
        now: december15,
      );

      expect(opener, isNotNull);
      expect(opener!.type, DataOpenerType.budgetAlert);
      // Must show the deficit number (400 CHF).
      expect(opener.message, contains('400'));
    });
  });
}
