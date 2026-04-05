/// RetirementBudgetService — transforms projection into monthly retirement budget.
///
/// Spec: docs/BUDGET_LIVING_ENGINE_IMPLEMENTATION_SPEC.md §5
/// Created: S53 — BudgetLivingEngine V0
///
/// Sources: LAVS art. 21-29, LPP art. 14, OPP3 art. 7
/// Disclaimer: outil educatif — ne constitue pas un conseil financier (LSFin).
library;

import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/forecaster_service.dart';

/// Transforms a [ProjectionResult] into a readable [RetirementBudget].
///
/// Returns `null` if:
/// - projection is null
/// - confidence < 45 (data too sparse for defensible projection)
/// - profile lacks minimum retirement data (salary)
///
/// The `monthlyCharges` is an educational estimate:
/// current charges * 0.80 heuristic (V1). This is conservative —
/// retirement typically reduces work-related expenses but may
/// increase health/leisure costs. Certificate data would refine this.
abstract final class RetirementBudgetService {
  /// Minimum confidence to produce a retirement budget.
  static const int minConfidence = 45;

  /// Heuristic reduction factor for retirement charges (V1).
  /// Conservative: assumes 80% of current charges persist.
  /// Source: CSIAS guidelines for post-retirement budget estimation.
  static const double chargesReductionFactor = 0.80;

  /// Default retirement withdrawal period in months (20 years).
  static const int retirementMonths = 240;

  static RetirementBudget? compute({
    required CoachProfile profile,
    required ProjectionResult? projection,
    required int confidenceScore,
  }) {
    // Guard: no projection
    if (projection == null) return null;

    // Guard: confidence too low for defensible estimate
    if (confidenceScore < minConfidence) return null;

    // Guard: no salary means no meaningful budget computation
    if (profile.salaireBrutMensuel <= 0) return null;

    // --- Retirement income from projection (base scenario) ---
    final decomposition = projection.base.decomposition;

    // AVS: annual → monthly
    final avsAnnual = (decomposition['avs'] ?? 0.0);
    final avsMonthly = avsAnnual / 12;

    // LPP: user + conjoint, annual → monthly
    final lppUserAnnual = (decomposition['lpp_user'] ?? 0.0);
    final lppConjointAnnual = (decomposition['lpp_conjoint'] ?? 0.0);
    final lppMonthly = (lppUserAnnual + lppConjointAnnual) / 12;

    // 3a: annualized from projection (already tax-adjusted, over 20y)
    final threeAAnnual = (decomposition['3a'] ?? 0.0);
    final pillar3aMonthly = threeAAnnual / 12;

    // Free/investment income
    final libreAnnual = (decomposition['libre'] ?? 0.0);
    final otherMonthly = libreAnnual / 12;

    // --- Retirement charges (heuristic V1) ---
    // Use current profile charges * reduction factor.
    // This is an educational estimate — not a precise projection.
    final currentCharges = profile.totalDepensesMensuelles;
    final monthlyCharges = currentCharges > 0
        ? currentCharges * chargesReductionFactor
        : 0.0;

    // --- Monthly free at retirement ---
    final totalIncome = avsMonthly + lppMonthly + pillar3aMonthly + otherMonthly;
    final monthlyFree = totalIncome - monthlyCharges;

    return RetirementBudget(
      avsMonthly: avsMonthly,
      lppMonthly: lppMonthly,
      pillar3aMonthly: pillar3aMonthly,
      otherMonthly: otherMonthly,
      monthlyCharges: monthlyCharges,
      monthlyFree: monthlyFree,
    );
  }
}
