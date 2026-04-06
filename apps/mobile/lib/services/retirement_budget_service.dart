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
/// The model returns gross monthly income, estimated tax (12% heuristic),
/// and net monthly income at retirement.
abstract final class RetirementBudgetService {
  /// Minimum confidence to produce a retirement budget.
  static const int minConfidence = 45;

  /// Heuristic reduction factor for retirement charges (V1).
  // TODO(P2): re-enable when BudgetSnapshot tracks retirement charges
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

    // --- Monthly income, tax, and net at retirement ---
    final totalIncome = avsMonthly + lppMonthly + pillar3aMonthly + otherMonthly;
    // Tax estimation: retirement rente income tax ~12% (conservative for most cantons).
    // Educational estimate — not a precise projection.
    final estimatedTax = totalIncome * 0.12;
    final monthlyNet = totalIncome - estimatedTax;

    return RetirementBudget(
      monthlyIncome: totalIncome,
      monthlyTax: estimatedTax,
      monthlyNet: monthlyNet,
    );
  }
}
