/// BudgetLivingEngine — orchestrates all financial services into a BudgetSnapshot.
///
/// Spec: docs/BUDGET_LIVING_ENGINE_IMPLEMENTATION_SPEC.md §6
/// Created: S53 — BudgetLivingEngine V0
///
/// Pipeline:
///   1. PresentBudget (from BudgetService)
///   2. ProjectionResult (from ForecasterService)
///   3. ConfidenceScore (from ConfidenceScorer)
///   4. RetirementBudget? (from RetirementBudgetService)
///   5. BudgetGap?
///   6. CapDecision (from CapEngine)
///   7. BudgetCapImpact?
///   8. BudgetCapSequence?
///   9. BudgetStage
///  10. BudgetSnapshot
///
/// Disclaimer: outil educatif — ne constitue pas un conseil financier (LSFin).
library;

import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/budget_service.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/cap_decision.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/cap_engine.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/retirement_budget_service.dart';

/// Orchestrates all financial services into a single [BudgetSnapshot].
///
/// Pure computation — no side effects, no network calls.
/// All dependencies are called as static methods.
abstract final class BudgetLivingEngine {
  /// Minimum confidence for emerging retirement stage.
  static const int _emergingThreshold = 45;

  /// Minimum confidence for full gap visible stage.
  static const int _fullGapThreshold = 60;

  /// Compute the unified budget snapshot from profile state.
  static BudgetSnapshot compute({
    required CoachProfile profile,
    required DateTime now,
    CapMemory? memory,
  }) {
    // ── 1. Present budget ─────────────────────────────────────
    final presentBudget = _computePresentBudget(profile);

    // ── 2. Projection ─────────────────────────────────────────
    ProjectionResult? projection;
    if (profile.salaireBrutMensuel > 0 && profile.age > 0) {
      projection = ForecasterService.project(profile: profile);
    }

    // ── 3. Confidence score ───────────────────────────────────
    final confidence = ConfidenceScorer.score(profile);
    final confidenceScore = confidence.score.round();

    // ── 4. Retirement budget ──────────────────────────────────
    final retirementBudget = RetirementBudgetService.compute(
      profile: profile,
      projection: projection,
      confidenceScore: confidenceScore,
    );

    // ── 5. Budget gap ─────────────────────────────────────────
    final gap = _computeGap(presentBudget, retirementBudget, confidenceScore);

    // ── 6. CapEngine ──────────────────────────────────────────
    final cap = CapEngine.compute(
      profile: profile,
      now: now,
      memory: memory ?? const CapMemory(),
    );

    // ── 7. Cap impact ─────────────────────────────────────────
    final capImpact = _deriveCapImpact(
      profile: profile,
      cap: cap,
      retirementBudget: retirementBudget,
    );

    // ── 8. Cap sequence ───────────────────────────────────────
    final capSequence = _deriveCapSequence(cap: cap);

    // ── 9. Stage ──────────────────────────────────────────────
    final stage = _determineStage(
      retirementBudget: retirementBudget,
      confidenceScore: confidenceScore,
      gap: gap,
    );

    // ── 10. Snapshot ──────────────────────────────────────────
    return BudgetSnapshot(
      present: presentBudget,
      retirement: retirementBudget,
      gap: gap,
      cap: cap,
      capImpact: capImpact,
      capSequence: capSequence,
      confidenceScore: confidenceScore,
      stage: stage,
      activeGoal: profile.goalA,
      supportingSignals: cap.supportingSignals,
      computedAt: now,
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  PRESENT BUDGET (adapter for BudgetService)
  // ════════════════════════════════════════════════════════════════

  static PresentBudget _computePresentBudget(CoachProfile profile) {
    // Build BudgetInputs from profile (reuses existing logic)
    final inputs = BudgetInputs.fromCoachProfile(profile);

    // Compute the plan to get available (free) amount
    final plan = BudgetService().computePlan(inputs);

    return PresentBudget(
      monthlyIncome: inputs.netIncome,
      monthlyCharges: inputs.netIncome - plan.available,
      monthlyFree: plan.available,
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  BUDGET GAP
  // ════════════════════════════════════════════════════════════════

  static BudgetGap? _computeGap(
    PresentBudget present,
    RetirementBudget? retirement,
    int confidenceScore,
  ) {
    if (retirement == null) return null;
    if (confidenceScore < _emergingThreshold) return null;

    final monthlyGap = present.monthlyFree - retirement.monthlyFree;

    // Prudent handling: if present free is zero or negative,
    // ratio is not meaningful — return null rather than mislead.
    if (present.monthlyFree <= 0) return null;

    final ratioRetained = retirement.monthlyFree / present.monthlyFree;

    return BudgetGap(
      monthlyGap: monthlyGap,
      ratioRetained: ratioRetained,
      // isPositive means retirement >= present (no gap)
      isPositive: monthlyGap <= 0,
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  STAGE DETERMINATION
  // ════════════════════════════════════════════════════════════════

  static BudgetStage _determineStage({
    required RetirementBudget? retirementBudget,
    required int confidenceScore,
    required BudgetGap? gap,
  }) {
    if (retirementBudget == null) return BudgetStage.presentOnly;
    if (confidenceScore < _emergingThreshold) return BudgetStage.presentOnly;
    if (confidenceScore < _fullGapThreshold || gap == null) {
      return BudgetStage.emergingRetirement;
    }
    return BudgetStage.fullGapVisible;
  }

  // ════════════════════════════════════════════════════════════════
  //  CAP IMPACT DERIVATION
  // ════════════════════════════════════════════════════════════════

  static BudgetCapImpact? _deriveCapImpact({
    required CoachProfile profile,
    required CapDecision cap,
    required RetirementBudget? retirementBudget,
  }) {
    switch (cap.id) {
      case 'pillar_3a':
      case 'couple_3a':
        // 3a: fiscal deduction this year + retirement income boost
        final marginalRate = _estimateMarginalRate(profile);
        const maxDeduction = 7258.0; // pilier3aPlafondAvecLpp
        final taxSaving = (maxDeduction * marginalRate).round();
        return BudgetCapImpact(
          now: '~CHF\u00a0$taxSaving d\u2019imp\u00f4t en moins cette ann\u00e9e',
          later: retirementBudget != null
              ? '\u00e9cart retraite r\u00e9duit'
              : null,
        );

      case 'lpp_buyback':
      case 'couple_lpp_buyback':
        // LPP buyback: fiscal deduction + retirement rente boost
        final marginalRate = _estimateMarginalRate(profile);
        final rachat = profile.prevoyance.rachatMaximum ?? 0;
        // Suggest a reasonable annual buyback (capped at 50k for readability)
        final suggestedAmount = rachat.clamp(0.0, 50000.0);
        final taxSaving = (suggestedAmount * marginalRate).round();
        return BudgetCapImpact(
          now: '~CHF\u00a0$taxSaving de d\u00e9duction fiscale',
          later: '\u00e9cart retraite r\u00e9duit',
        );

      case 'budget_deficit':
        return const BudgetCapImpact(
          now: 'marge mensuelle \u00e0 retrouver',
          later: '\u00e9quilibre budg\u00e9taire',
        );

      case 'replacement_rate':
        return const BudgetCapImpact(
          now: 'leviers 3a ou rachat LPP',
          later: '+4 \u00e0 +7 pts de taux de remplacement',
        );

      default:
        // Unknown cap — return null rather than a weak message
        return null;
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  CAP SEQUENCE DERIVATION
  // ════════════════════════════════════════════════════════════════

  static BudgetCapSequence? _deriveCapSequence({
    required CapDecision cap,
  }) {
    switch (cap.id) {
      case 'lpp_buyback':
      case 'couple_lpp_buyback':
        return const BudgetCapSequence(
          title: 'Rachats LPP \u00e9chelonn\u00e9s',
          steps: [
            BudgetCapSequenceStep(
              label: 'Cette ann\u00e9e',
              effect: 'd\u00e9duction fiscale imm\u00e9diate',
            ),
            BudgetCapSequenceStep(
              label: 'Ann\u00e9e suivante',
              effect: 'nouveau rachat selon ton TMI',
            ),
            BudgetCapSequenceStep(
              label: '\u00c0 la retraite',
              effect: '\u00e9cart r\u00e9duit',
            ),
          ],
        );

      case 'pillar_3a':
      case 'couple_3a':
        return const BudgetCapSequence(
          title: 'Versements 3a r\u00e9guliers',
          steps: [
            BudgetCapSequenceStep(
              label: 'Cette ann\u00e9e',
              effect: 'd\u00e9duction fiscale',
            ),
            BudgetCapSequenceStep(
              label: 'Chaque ann\u00e9e',
              effect: 'effet cumul\u00e9 + rendement',
            ),
            BudgetCapSequenceStep(
              label: '\u00c0 la retraite',
              effect: 'capital compl\u00e9mentaire',
            ),
          ],
        );

      default:
        return null;
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════════

  /// Estimate marginal tax rate from profile (simplified V1).
  /// Uses a rough heuristic: 25% default, 30% for high earners.
  /// A precise TMI requires the tax declaration (data source: certificate).
  static double _estimateMarginalRate(CoachProfile profile) {
    final annualGross = profile.salaireBrutMensuel * 12;
    if (annualGross > 150000) return 0.30;
    if (annualGross > 80000) return 0.25;
    return 0.20;
  }
}
