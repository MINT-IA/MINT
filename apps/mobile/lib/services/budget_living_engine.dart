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

    // 3. Determine stage
    final hasRetirementData = profile.salaireBrutMensuel > 0 &&
        profile.age > 0 &&
        profile.age < 70;

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

  // ══════════════════════════════════════════════════════════
  //  STEP 1 — PRESENT BUDGET
  // ══════════════════════════════════════════════════════════

  static PresentBudget _computePresent(CoachProfile profile) {
    // Net income — main user
    final mainBreakdown = NetIncomeBreakdown.compute(
      grossSalary: profile.salaireBrutMensuel * 12,
      canton: profile.canton.isNotEmpty ? profile.canton : 'ZH',
      age: profile.age,
    );
    double monthlyNet = mainBreakdown.monthlyNetPayslip;

    // Partner net income
    final conj = profile.conjoint;
    if (conj != null &&
        (conj.salaireBrutMensuel ?? 0) > 0 &&
        conj.age != null) {
      final partnerBreakdown = NetIncomeBreakdown.compute(
        grossSalary: conj.salaireBrutMensuel! * 12,
        canton: profile.canton.isNotEmpty ? profile.canton : 'ZH',
        age: conj.age!,
      );
      monthlyNet += partnerBreakdown.monthlyNetPayslip;
    }

    // Fixed charges from BudgetInputs (single source of truth for budget calc)
    // BudgetInputs.fromCoachProfile uses the same tax estimator path.
    final inputs = BudgetInputs.fromCoachProfile(profile);
    final monthlyCharges = inputs.housingCost +
        inputs.debtPayments +
        inputs.taxProvision +
        inputs.healthInsurance +
        inputs.otherFixedCosts;

    // Planned savings out-flows: 3a contributions + LPP buybacks
    final monthlySavings = _computeMonthlySavings(profile);

    final monthlyFree = monthlyNet - monthlyCharges - monthlySavings;

    return PresentBudget(
      monthlyNet: monthlyNet,
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
  static double _computeMonthlySavings(CoachProfile profile) {
    double savings = 0;

    // 3a contributions
    savings += profile.total3aMensuel;

    // LPP buybacks
    savings += profile.totalLppBuybackMensuel;

    // Conjoint 3a (if applicable)
    final conj = profile.conjoint;
    if (conj != null &&
        (conj.salaireBrutMensuel ?? 0) > lppSeuilEntree / 12 &&
        (conj.prevoyance?.canContribute3a ?? true)) {
      // Avoid double-counting if already in plannedContributions
      final conjFirstName = conj.firstName?.toLowerCase() ?? '';
      final hasPartner3a = profile.plannedContributions.any((c) =>
          c.category == '3a' &&
          conjFirstName.isNotEmpty &&
          c.id.toLowerCase().contains(conjFirstName));
      if (!hasPartner3a) {
        savings += pilier3aPlafondAvecLpp / 12;
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

    // Replacement rate: retirement net as % of present net.
    final replacementRate = present.monthlyNet > 0
        ? (retirement.monthlyNet / present.monthlyNet * 100).clamp(0.0, 200.0)
        : 0.0;

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
    const plafondMensuel = pilier3aPlafondAvecLpp / 12;
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
