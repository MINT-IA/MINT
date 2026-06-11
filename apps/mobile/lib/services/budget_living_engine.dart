/// BudgetLivingEngine — real computation, not a stub.
///
/// Produces a [BudgetSnapshot] from a [CoachProfile].
/// All calculations are pure and deterministic.
///
/// Sources:
///   - Present budget: NetIncomeBreakdown (tax_calculator.dart), BudgetInputs
///   - Retirement income: RetirementProjectionService (financial_core)
///   - Confidence: ConfidenceScorer (financial_core)
///
/// CLAUDE.md rules enforced:
///   - Uses financial_core calculators — never re-implements.
///   - Confidence score mandatory on all projections.
///   - No double-taxation: capital taxed at withdrawal, SWR ≠ income.
///   - Archetype-aware (via RetirementProjectionService).
library;

import 'dart:math';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/present_budget_builder.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';
import 'package:mint_mobile/services/retirement_projection_service.dart';

/// Computes a [BudgetSnapshot] from a [CoachProfile].
///
/// All methods are static and pure (no side effects, no I/O).
class BudgetLivingEngine {
  BudgetLivingEngine._();

  // ══════════════════════════════════════════════════════════
  //  PUBLIC API
  // ══════════════════════════════════════════════════════════

  /// Compute the full budget snapshot for [profile].
  ///
  /// Returns a [BudgetSnapshot] with appropriate [BudgetStage].
  /// Never throws — all errors produce a degraded snapshot.
  static BudgetSnapshot compute(CoachProfile profile) {
    // 1. Present budget
    final present = _computePresent(profile);

    // 2. Confidence — mandatory on all projections
    final confidence = ConfidenceScorer.score(profile);

    // 3. Determine stage — three distinct cases:
    //    a) Retired (age >= targetRetirementAge): budget based on actual rentes.
    //    b) Pre-retirement (has salary + valid age): full projection + gap.
    //    c) No usable data (zero salary and not retired): present-only.
    final targetRetirementAge = profile.targetRetirementAge ??
        reg('avs.reference_age_men', avsAgeReferenceHomme.toDouble()).toInt();
    final isRetired = profile.age > 0 && profile.age >= targetRetirementAge;

    // Case a: user is already in retirement — show rente income, no gap.
    if (isRetired) {
      try {
        final retirementResult = RetirementProjectionService.project(
          profile: profile,
          retirementAgeUser: targetRetirementAge,
        );
        final retirementBudget =
            _wrapRetirementResult(retirementResult, profile);
        return BudgetSnapshot(
          present: present,
          retirement: retirementBudget,
          gap: null, // already retired — gap is not meaningful
          capImpacts: const [],
          stage: BudgetStage.fullGapVisible,
          confidenceScore: confidence.score,
        );
      } catch (_) {
        // Graceful degradation: show present-only if rente calc fails.
        return BudgetSnapshot(
          present: present,
          stage: BudgetStage.presentOnly,
          capImpacts: const [],
          confidenceScore: confidence.score,
        );
      }
    }

    // Case b/c: pre-retirement — require salary > 0 and valid age for projection.
    final hasRetirementData = profile.salaireBrutMensuel > 0 && profile.age > 0;

    if (!hasRetirementData) {
      return BudgetSnapshot(
        present: present,
        stage: BudgetStage.presentOnly,
        capImpacts: const [],
        confidenceScore: confidence.score,
      );
    }

    // 4. Retirement budget
    RetirementBudget? retirementBudget;
    BudgetGap? gap;

    try {
      final retirementResult = RetirementProjectionService.project(
        profile: profile,
        retirementAgeUser: targetRetirementAge,
      );
      retirementBudget = _wrapRetirementResult(retirementResult, profile);
      gap = _computeGap(present, retirementBudget);
    } catch (_) {
      // Graceful degradation: show present-only if retirement calc fails.
      return BudgetSnapshot(
        present: present,
        stage: BudgetStage.presentOnly,
        capImpacts: const [],
        confidenceScore: confidence.score,
      );
    }

    // 5. Stage
    final stage = confidence.score >= 40
        ? BudgetStage.fullGapVisible
        : BudgetStage.emergingRetirement;

    // 6. Cap impacts (what-if levers)
    final capImpacts = _computeCapImpacts(profile, retirementBudget);

    return BudgetSnapshot(
      present: present,
      retirement: retirementBudget,
      gap: gap,
      capImpacts: capImpacts,
      stage: stage,
      confidenceScore: confidence.score,
    );
  }

  /// Monthly 3a contribution we may legitimately suggest from a free margin.
  ///
  /// W4 / D10 fix — a free-margin number is NEVER suggested as a 3a versement
  /// without clamping to the statutory ceiling. Reproduced on device: a margin
  /// of 1541 CHF/month suggested as-is is ~2.55× the 7258 CHF annual ceiling.
  ///
  /// Semantics:
  ///   - The room is the CANONICAL remaining annual 3a room
  ///     (`Pillar3aRoomCalculator.remainingAnnualRoom`, archetype-aware,
  ///     net-base for independents per plan 04, FATCA-gated to 0 per plan 08).
  ///   - A room of 0 (ceiling reached OR US person who cannot contribute) means
  ///     NO 3a suggestion at all — returns 0.0, not a dissonant 0-CHF suggestion.
  ///   - Otherwise the room is pro-rated over the remaining calendar months and
  ///     capped by the available margin:
  ///       `min(availableMonthlyMargin, remainingRoom / monthsRemaining)`.
  ///   - A non-positive margin (deficit) yields 0.0 — nothing to suggest.
  ///
  /// Pure and deterministic. [now] is injectable for tests; defaults to the
  /// current date so the proration tracks the real calendar.
  static double cappedMonthly3aSuggestion(
    CoachProfile profile, {
    required double availableMonthlyMargin,
    FinancialArchetype? archetype,
    DateTime? now,
  }) {
    if (availableMonthlyMargin <= 0) return 0.0;

    final remainingRoom = Pillar3aRoomCalculator.remainingAnnualRoom(
      profile,
      archetype: archetype,
    );
    // 0 ceiling (FATCA / US person) or ceiling already reached → NO suggestion.
    if (remainingRoom <= 0) return 0.0;

    final reference = now ?? DateTime.now();
    // Months left in the calendar year, current month inclusive
    // (January → 12, December → 1). The room can be spread across them.
    final monthsRemaining = (13 - reference.month).clamp(1, 12);
    final monthlyRoom = remainingRoom / monthsRemaining;

    return min(availableMonthlyMargin, monthlyRoom);
  }

  // ══════════════════════════════════════════════════════════
  //  STEP 1 — PRESENT BUDGET
  // ══════════════════════════════════════════════════════════

  static PresentBudget _computePresent(CoachProfile profile) {
    // Net income — same household derivation as BudgetInputs.
    final inputs = BudgetInputs.fromCoachProfile(profile);
    final monthlyNet = PresentBudgetBuilder.displayChf(inputs.netIncome);

    // Fixed charges from BudgetInputs (single source of truth for budget calc).
    // Use the same display read model as BudgetScreen so Mon Argent and Coach
    // do not show a one-franc drift from different rounding boundaries.
    final monthlyCharges = PresentBudgetBuilder.fixedChargesFromInputs(inputs);

    // Planned savings out-flows: 3a contributions + LPP buybacks
    final monthlySavings = computeMonthlySavings(profile);

    final monthlyFree = monthlyNet - monthlyCharges - monthlySavings;

    return PresentBudget(
      monthlyNet: monthlyNet,
      monthlyHousing: PresentBudgetBuilder.displayChf(inputs.housingCost),
      monthlyDebt: PresentBudgetBuilder.displayChf(inputs.debtPayments),
      monthlyTax: PresentBudgetBuilder.displayChf(inputs.taxProvision),
      monthlyHealth: PresentBudgetBuilder.displayChf(inputs.healthInsurance),
      monthlyOtherFixed:
          PresentBudgetBuilder.displayChf(inputs.otherFixedCosts),
      monthlyCharges: monthlyCharges,
      monthlySavings: monthlySavings,
      monthlyFree: monthlyFree,
    );
  }

  /// Monthly savings out-flows: 3a + LPP buybacks.
  ///
  /// These are not "expenses" but capital formation.
  /// We separate them so the UI can show both the full libre
  /// and what is earmarked for the future.
  ///
  /// SALVAGE-00 SC-2 / Gate Fix 2 (arch-03): exposed as a public static so it
  /// is the ONE shared savings helper BOTH budget producers call (this engine +
  /// budget_screen._presentBudgetFromInputs). A 3a-contributing user must see
  /// the SAME Disponible everywhere. Do NOT add a second savings formula
  /// (CLAUDE.md NEVER #3 — single source of truth).
  static double computeMonthlySavings(CoachProfile profile) {
    double savings = 0;

    // 3a contributions
    savings += profile.total3aMensuel;

    // LPP buybacks
    savings += profile.totalLppBuybackMensuel;

    // Conjoint 3a (if applicable)
    // Use canContribute3a from conjoint's prevoyance profile (FATCA-aware).
    // Default to false (safer: assume no contribution unless explicitly declared).
    // 3a eligibility requires LPP coverage (canContribute3a), not a salary
    // threshold — lppSeuilEntree is an LPP access threshold, not a 3a one.
    final conj = profile.conjoint;
    if (conj != null &&
        (conj.salaireBrutMensuel ?? 0) > 0 &&
        (conj.prevoyance?.canContribute3a ?? false)) {
      // Avoid double-counting: if there are already >= 2 planned 3a entries,
      // the conjoint's contribution is likely already tracked explicitly.
      // A single 3a entry belongs to the main user; we add the conjoint estimate.
      final planned3aCount =
          profile.plannedContributions.where((c) => c.category == '3a').length;
      if (planned3aCount < 2) {
        savings += reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp) / 12;
      }
    }

    return savings;
  }

  // ══════════════════════════════════════════════════════════
  //  STEP 2 — RETIREMENT BUDGET WRAPPER
  // ══════════════════════════════════════════════════════════

  static RetirementBudget _wrapRetirementResult(
    RetirementProjectionResult result,
    CoachProfile profile,
  ) {
    // Gross retirement income (monthly)
    final monthlyIncome = result.revenuMensuelAt65;

    // Estimated income tax on rentes is computed by RetirementProjectionService
    // via budgetGap.impotEstimeMensuel, which uses RetirementTaxCalculator
    // with the correct canton, marital status, and income decomposition.
    //
    // Only AVS + LPP rente portions are taxable income at retirement.
    // 3a: capital already taxed at withdrawal (LIFD art. 38).
    // SWR drawdown: NOT income — consumption of own patrimony (CLAUDE.md §5 #10).
    final monthlyTax = result.budgetGap.impotEstimeMensuel;
    final monthlyNet = max(0.0, monthlyIncome - monthlyTax);

    return RetirementBudget(
      monthlyIncome: monthlyIncome,
      monthlyTax: monthlyTax,
      monthlyNet: monthlyNet,
    );
  }

  // ══════════════════════════════════════════════════════════
  //  STEP 3 — BUDGET GAP
  // ══════════════════════════════════════════════════════════

  static BudgetGap _computeGap(
    PresentBudget present,
    RetirementBudget retirement,
  ) {
    // Gap: positive means retirement income < today (need to plan).
    final monthlyGap = present.monthlyNet - retirement.monthlyNet;

    // Taux de remplacement : définition canonique unique (financial_core L1).
    // Numérateur ET dénominateur sont NET (fin de la formule mixte net/brut) :
    // revenu retraite NET / revenu présent NET, en %. Plus de grossMonthlySalary
    // au dénominateur (lock CONTEXT W1, voir replacement_rate.dart + D3).
    final replacementRate = ReplacementRate.percent(
      totalMonthlyRetirement: retirement.monthlyNet,
      netMonthlyIncome: present.monthlyNet,
    ).clamp(0.0, 200.0);

    return BudgetGap(
      monthlyGap: monthlyGap,
      replacementRate: replacementRate,
    );
  }

  // ══════════════════════════════════════════════════════════
  //  STEP 4 — CAP IMPACTS
  // ══════════════════════════════════════════════════════════

  /// Compute the monthly delta if specific levers were activated.
  ///
  /// Each cap impact shows how much a given action would reduce the gap.
  /// Ordered by descending monthly delta (biggest lever first).
  static List<BudgetCapImpact> _computeCapImpacts(
    CoachProfile profile,
    RetirementBudget retirement,
  ) {
    final impacts = <BudgetCapImpact>[];

    final yearsToRetire =
        (profile.effectiveRetirementAge - profile.age).clamp(0, 50);
    if (yearsToRetire == 0) return const [];

    // Cap 1: Rachat LPP — if there is a remaining lacune.
    final lacune = profile.prevoyance.lacuneRachatRestante;
    if (lacune > 0) {
      // Project the lacune to retirement at default LPP return (2%)
      // and convert to monthly income delta using tauxConversion.
      final projectedLpp = lacune * pow(1.02, yearsToRetire);
      final convRate = LppCalculator.adjustedConversionRate(
        baseRate: profile.prevoyance.tauxConversion,
        retirementAge: profile.effectiveRetirementAge,
      );
      final monthlyDelta = (projectedLpp * convRate) / 12;
      if (monthlyDelta > 0) {
        impacts.add(BudgetCapImpact(
          capId: 'rachat_lpp',
          monthlyDelta: monthlyDelta,
        ));
      }
    }

    // Cap 2: 3a max — if not already maxing out.
    final current3aMensuel = profile.total3aMensuel;
    final plafondMensuel =
        reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp) / 12;
    final has3aGap = current3aMensuel < plafondMensuel * 0.95;
    if (has3aGap) {
      final additional3aMonthly = plafondMensuel - current3aMensuel;
      // Project additional monthly 3a to retirement at 4.5% average return
      // then annualise over 20 years (same as ForecasterService).
      final additional3aCapital =
          additional3aMonthly * 12 * _annuityFactor(0.045, yearsToRetire);
      final monthly3aDelta = (additional3aCapital * 0.8) /
          20 /
          12; // 0.8 factor for capital withdrawal tax
      if (monthly3aDelta > 0) {
        impacts.add(BudgetCapImpact(
          capId: '3a_max',
          monthlyDelta: monthly3aDelta,
        ));
      }
    }

    // Sort by descending delta (biggest lever first)
    impacts.sort((a, b) => b.monthlyDelta.compareTo(a.monthlyDelta));
    return impacts;
  }

  /// Annuity accumulation factor: ((1+r)^n - 1) / r
  static double _annuityFactor(double rate, int years) {
    if (rate == 0 || years == 0) return years.toDouble();
    return (pow(1 + rate, years) - 1) / rate;
  }
}
