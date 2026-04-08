import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/services/coach/goal_tracker_service.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';
import 'package:mint_mobile/services/financial_plan_service.dart';

// ────────────────────────────────────────────────────────────────────────────
//  PlanGenerationService
//
//  Computes a FinancialPlan from financial_core calculators — NOT from LLM
//  output. LLM may supply the coachNarrative only.
//
//  D-03: Monthly target computation branches on goalCategory.
//  D-07: Confidence level computed from profile completeness (5-field count).
//  T-04-07: Skip Monte Carlo for non-retirement goals and confidence < 40%.
//  Threat T-04-04: Numbers come from calculators, never from LLM tool payload.
//
//  Compliance: educational tool — ne constitue pas un conseil financier (LSFin).
//  Legal references: LIFD art. 38, LPP art. 14, OPP2 art. 5.
// ────────────────────────────────────────────────────────────────────────────

/// Default goal amounts per category (CHF).
/// Used when [goalAmount] is not provided by the caller.
const Map<String, double> _defaultGoalAmounts = {
  'goal_house': 500000,
  'goal_retirement_plan': 1000000,
  'goal_pension_opt': 1000000,
  'goal_emergency_fund': 30000,
  'goal_tax_basic': 10000,
  'goal_invest_simple': 50000,
  'goal_control_debts': 20000,
};

/// Minimum confidence percentage to attempt ArbitrageEngine (retirement goals).
const double _minConfidenceForArbitrage = 40.0;

class PlanGenerationService {
  PlanGenerationService._();

  /// Generate a calculator-backed [FinancialPlan].
  ///
  /// [goalDescription]  Human-readable description (from coach conversation).
  /// [goalCategory]     Category matching GoalTemplate.id values.
  /// [targetDate]       Must be strictly in the future.
  /// [profile]          CoachProfile to compute against.
  /// [coachNarrative]   Optional LLM-generated narrative (compliance-filtered).
  /// [goalAmount]       Target amount in CHF. Defaults to category default if null.
  ///
  /// Throws [ArgumentError] if [targetDate] is in the past.
  ///
  /// Persists via [FinancialPlanService.save] and tracks via [GoalTrackerService].
  static Future<FinancialPlan> generate({
    required String goalDescription,
    required String goalCategory,
    required DateTime targetDate,
    required CoachProfile profile,
    String? coachNarrative,
    double? goalAmount,
  }) async {
    final now = DateTime.now();

    // Threat T-04-07: validate target date
    if (targetDate.isBefore(now)) {
      throw ArgumentError(
        'targetDate must be in the future. Got: $targetDate',
      );
    }

    // ── 1. Effective goal amount ──────────────────────────────────────────
    final effectiveGoalAmount =
        goalAmount ?? _defaultGoalAmounts[goalCategory] ?? 50000.0;

    // ── 2. Months remaining (minimum 1 to avoid divide-by-zero) ─────────
    final monthsRemaining = ((targetDate.year - now.year) * 12 +
            (targetDate.month - now.month))
        .clamp(1, 9999)
        .toDouble();

    // ── 3. Confidence level (D-07: 5-field count, 20% each) ──────────────
    final confidenceLevel = _computeSimplifiedConfidence(profile);

    // ── 4. Monthly target (D-03: branch on goalCategory) ─────────────────
    final monthlyTarget = _computeMonthlyTarget(
      goalCategory: goalCategory,
      effectiveGoalAmount: effectiveGoalAmount,
      monthsRemaining: monthsRemaining,
      profile: profile,
      confidenceLevel: confidenceLevel,
    );

    // ── 5. Projected outcome (deterministic unless retirement + complete) ─
    final projectedMid = monthlyTarget * monthsRemaining;
    final projectedLow = projectedMid * 0.85;
    final projectedHigh = projectedMid * 1.15;

    // ── 6. Milestones (25/50/75/100%) ────────────────────────────────────
    final milestones = FinancialPlan.generateMilestones(
      effectiveGoalAmount,
      targetDate,
    );

    // ── 7. Profile hash ───────────────────────────────────────────────────
    final profileHash = computeProfileHash(profile);

    // ── 8. Sources ────────────────────────────────────────────────────────
    final sources = _buildSources(goalCategory, profile);

    // ── 9. Disclaimer ─────────────────────────────────────────────────────
    const disclaimer =
        'Outil éducatif — ne constitue pas un conseil financier (LSFin).';

    // ── 10. Coach narrative ───────────────────────────────────────────────
    final narrative = coachNarrative?.isNotEmpty == true
        ? coachNarrative!
        : _defaultNarrative(goalCategory, monthlyTarget, effectiveGoalAmount);

    // ── 11. Unique ID ─────────────────────────────────────────────────────
    final id =
        '${DateTime.now().millisecondsSinceEpoch}_${goalCategory.hashCode.abs()}';

    // ── 12. Build plan ────────────────────────────────────────────────────
    final plan = FinancialPlan(
      id: id,
      goalDescription: goalDescription,
      goalCategory: goalCategory,
      monthlyTarget: monthlyTarget,
      milestones: milestones,
      projectedOutcome: projectedMid,
      projectedLow: projectedLow,
      projectedHigh: projectedHigh,
      targetDate: targetDate,
      generatedAt: now,
      profileHashAtGeneration: profileHash,
      coachNarrative: narrative,
      confidenceLevel: confidenceLevel,
      sources: sources,
      disclaimer: disclaimer,
    );

    // ── 13. Persist (D-09) ────────────────────────────────────────────────
    await FinancialPlanService.save(plan);

    // ── 14. Track goal in GoalTrackerService (D-09) ───────────────────────
    await _trackGoal(goalDescription, goalCategory, targetDate);

    return plan;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Compute monthly target — branches on goalCategory per D-03 + Pitfall 6.
  ///
  /// Retirement goals with sufficient profile data use ArbitrageEngine.
  /// All other goals use simple arithmetic: goalAmount / monthsRemaining.
  static double _computeMonthlyTarget({
    required String goalCategory,
    required double effectiveGoalAmount,
    required double monthsRemaining,
    required CoachProfile profile,
    required double confidenceLevel,
  }) {
    switch (goalCategory) {
      case 'goal_retirement_plan':
      case 'goal_pension_opt':
        // Attempt ArbitrageEngine if profile is sufficiently complete.
        if (confidenceLevel >= _minConfidenceForArbitrage &&
            profile.prevoyance.avoirLppTotal != null) {
          try {
            return _retirementMonthlyTarget(
              profile: profile,
              effectiveGoalAmount: effectiveGoalAmount,
              monthsRemaining: monthsRemaining,
            );
          } catch (_) {
            // Fallback to arithmetic if ArbitrageEngine fails
          }
        }
        // Arithmetic fallback (Pitfall 1 / confidence < 40%)
        return effectiveGoalAmount / monthsRemaining;

      default:
        // All other goals: simple arithmetic
        return effectiveGoalAmount / monthsRemaining;
    }
  }

  /// Retirement-specific computation using ArbitrageEngine.
  ///
  /// Uses compareRenteVsCapital to determine the gap between projected
  /// LPP capital and the goal amount, expressed as a monthly savings target.
  static double _retirementMonthlyTarget({
    required CoachProfile profile,
    required double effectiveGoalAmount,
    required double monthsRemaining,
  }) {
    final now = DateTime.now();
    final age = profile.dateOfBirth != null
        ? now.year -
            profile.dateOfBirth!.year -
            (now.month < profile.dateOfBirth!.month ||
                    (now.month == profile.dateOfBirth!.month &&
                        now.day < profile.dateOfBirth!.day)
                ? 1
                : 0)
        : now.year - profile.birthYear;

    final lppTotal = profile.prevoyance.avoirLppTotal ?? 0.0;
    final lppOblig = profile.prevoyance.avoirLppObligatoire ?? lppTotal * 0.6;
    final lppSurob = profile.prevoyance.avoirLppSurobligatoire ??
        lppTotal - lppOblig;

    // Estimate annual salary from monthly
    final grossAnnual = profile.salaireBrutMensuel * profile.nombreDeMois;

    // Estimated annual rente (obligatoire portion × 6.8% conversion rate)
    final estimatedRente = lppOblig * 0.068 + lppSurob * 0.05;

    final result = ArbitrageEngine.compareRenteVsCapital(
      capitalLppTotal: lppTotal,
      capitalObligatoire: lppOblig,
      capitalSurobligatoire: lppSurob,
      renteAnnuelleProposee: estimatedRente,
      canton: profile.canton,
      currentAge: age,
      grossAnnualSalary: grossAnnual,
      caisseReturn: profile.prevoyance.rendementCaisse,
    );

    // Use the projected capital-at-retirement from the arbitrage result
    // to determine the monthly savings gap
    final projectedCapital =
        result.options.isNotEmpty ? result.options.first.terminalValue : lppTotal;

    // Gap between goal and projected LPP capital
    final gap = (effectiveGoalAmount - projectedCapital).clamp(0.0, double.infinity);
    if (gap == 0) {
      // Already on track — minimal monthly target
      return (effectiveGoalAmount * 0.01).clamp(100.0, 1000.0);
    }
    return gap / monthsRemaining;
  }

  /// Simplified confidence (D-07): count non-null key fields (5 × 20% each).
  ///
  /// Fields: salaireBrutMensuel, avoirLppTotal, totalEpargne3a, canton, dateOfBirth.
  /// This is NOT the full EnhancedConfidence 4-axis model — just a plan-level proxy.
  static double _computeSimplifiedConfidence(CoachProfile profile) {
    int count = 0;
    // salaireBrutMensuel is always present (required field) — contributes 20%
    if (profile.salaireBrutMensuel > 0) count++;
    if (profile.prevoyance.avoirLppTotal != null) count++;
    if (profile.prevoyance.totalEpargne3a > 0) count++;
    if (profile.canton.isNotEmpty) count++;
    if (profile.dateOfBirth != null) count++;
    return (count * 20).toDouble();
  }

  /// Build legal sources list (always includes LIFD + LPP; adds OPP2 for housing).
  static List<String> _buildSources(String goalCategory, CoachProfile profile) {
    final sources = <String>['LIFD art. 38', 'LPP art. 14'];

    if (goalCategory == 'goal_house') {
      sources.add('OPP2 art. 5');
      // Note EPL eligibility if LPP >= 20000
      final lpp = profile.prevoyance.avoirLppTotal ?? 0.0;
      if (lpp >= 20000) {
        sources.add('LPP art. 30c (EPL — retrait anticipé pour propriété)');
      }
    }

    if (goalCategory == 'goal_retirement_plan' ||
        goalCategory == 'goal_pension_opt') {
      sources.add('LAVS art. 21');
    }

    if (goalCategory == 'goal_tax_basic') {
      sources.add('OPP3 art. 7 (plafond 3e pilier)');
    }

    return sources;
  }

  /// Default coach narrative when no LLM narrative is provided.
  static String _defaultNarrative(
    String goalCategory,
    double monthlyTarget,
    double goalAmount,
  ) {
    final chf = monthlyTarget.toStringAsFixed(0);
    switch (goalCategory) {
      case 'goal_house':
        return "Pour atteindre ton objectif d'achat immobilier, "
            'un effort mensuel de $chf\u00a0CHF te permettrait '
            "d'y arriver dans les délais prévus.";
      case 'goal_retirement_plan':
      case 'goal_pension_opt':
        return 'En mettant de côté $chf\u00a0CHF par mois en complément '
            'de tes piliers 1 et 2, tu renforces la sécurité de ta retraite.';
      case 'goal_emergency_fund':
        return 'Un fonds de roulement de ${goalAmount.toStringAsFixed(0)}\u00a0CHF '
            'te protège des imprévus. $chf\u00a0CHF/mois te permettra '
            "d'y arriver sereinement.";
      case 'goal_control_debts':
        return 'Rembourser $chf\u00a0CHF par mois te libérera progressivement '
            'de tes dettes et améliorera ta situation financière.';
      case 'goal_tax_basic':
        return 'Optimiser ta fiscalité via le 3e pilier te permet de réduire '
            'ta charge fiscale immédiatement. Un versement de $chf\u00a0CHF/mois '
            'maximise ton impact.';
      case 'goal_invest_simple':
        return 'Investir $chf\u00a0CHF par mois de façon régulière permet '
            "de bénéficier de l'effet de capitalisation sur le long terme.";
      default:
        return 'En épargnant $chf\u00a0CHF par mois, tu progresseras '
            'vers ton objectif financier dans les délais prévus.';
    }
  }

  /// Track goal in GoalTrackerService (D-09).
  static Future<void> _trackGoal(
    String description,
    String category,
    DateTime targetDate,
  ) async {
    final goal = UserGoal(
      id:
          '${DateTime.now().millisecondsSinceEpoch}_${category.hashCode.abs()}',
      description: description,
      category: _mapCategoryToGoalTrackerCategory(category),
      createdAt: DateTime.now(),
      targetDate: targetDate,
    );
    await GoalTrackerService.addGoal(goal);
  }

  /// Map plan goalCategory to GoalTrackerService category strings.
  static String _mapCategoryToGoalTrackerCategory(String goalCategory) {
    switch (goalCategory) {
      case 'goal_house':
        return 'housing';
      case 'goal_retirement_plan':
      case 'goal_pension_opt':
        return 'retirement';
      case 'goal_emergency_fund':
        return 'budget';
      case 'goal_control_debts':
        return 'other';
      case 'goal_tax_basic':
        return '3a';
      case 'goal_invest_simple':
        return 'other';
      default:
        return 'other';
    }
  }
}
