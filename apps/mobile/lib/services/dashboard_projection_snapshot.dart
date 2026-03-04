import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

/// Single source of truth for all dashboard display numbers.
///
/// Computed once from ForecasterService output, consumed by all widgets.
/// This prevents multiple widgets from computing their own numbers
/// with different methodologies.
///
/// Revenue data comes from ForecasterService decomposition (annual income
/// by pillar at retirement). Capital data comes from CoachProfile (real
/// stocks, not projected revenue).
class DashboardProjectionSnapshot {
  // -- Retirement income (from ForecasterService) --
  final double totalMonthlyIncome;
  final double monthlyPrudent;
  final double monthlyOptimiste;
  final double replacementRate;

  // -- Per-pillar monthly retirement income --
  final double avsMonthly;
  final double avsUserMonthly;
  final double avsConjointMonthly;
  final double lppUserMonthly;
  final double lppConjointMonthly;
  final double threeAMonthly;
  final double libreMonthly;

  // -- Current household net income (for Monte Carlo reference) --
  final double currentHouseholdNetMonthly;

  const DashboardProjectionSnapshot({
    required this.totalMonthlyIncome,
    required this.monthlyPrudent,
    required this.monthlyOptimiste,
    required this.replacementRate,
    required this.avsMonthly,
    required this.avsUserMonthly,
    required this.avsConjointMonthly,
    required this.lppUserMonthly,
    required this.lppConjointMonthly,
    required this.threeAMonthly,
    required this.libreMonthly,
    required this.currentHouseholdNetMonthly,
  });

  /// Build snapshot from ForecasterService projection + profile.
  factory DashboardProjectionSnapshot.fromProjection({
    required ProjectionResult projection,
    required CoachProfile profile,
  }) {
    final deco = projection.base.decomposition;

    // Current household net income: user + conjoint
    double householdNet = 0;
    if (profile.salaireBrutMensuel > 0) {
      householdNet += NetIncomeBreakdown.compute(
        grossSalary: profile.salaireBrutMensuel * 12,
        canton: profile.canton,
        age: profile.age,
      ).monthlyNetPayslip;
    }

    final conjoint = profile.conjoint;
    if (conjoint != null &&
        conjoint.salaireBrutMensuel != null &&
        conjoint.salaireBrutMensuel! > 0 &&
        conjoint.age != null) {
      householdNet += NetIncomeBreakdown.compute(
        grossSalary: conjoint.salaireBrutMensuel! * 12,
        canton: profile.canton,
        age: conjoint.age!,
      ).monthlyNetPayslip;
    }

    return DashboardProjectionSnapshot(
      totalMonthlyIncome: projection.base.revenuAnnuelRetraite / 12,
      monthlyPrudent: projection.prudent.revenuAnnuelRetraite / 12,
      monthlyOptimiste: projection.optimiste.revenuAnnuelRetraite / 12,
      replacementRate: projection.tauxRemplacementBase,
      avsMonthly: (deco['avs'] ?? 0) / 12,
      avsUserMonthly: (deco['avs_user'] ?? 0) / 12,
      avsConjointMonthly: (deco['avs_conjoint'] ?? 0) / 12,
      lppUserMonthly: (deco['lpp_user'] ?? 0) / 12,
      lppConjointMonthly: (deco['lpp_conjoint'] ?? 0) / 12,
      threeAMonthly: (deco['3a'] ?? 0) / 12,
      libreMonthly: (deco['libre'] ?? 0) / 12,
      currentHouseholdNetMonthly: householdNet,
    );
  }
}
