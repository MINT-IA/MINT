import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/budget_plan.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';

/// Builds the present-budget read model from explicit budget inputs.
///
/// `BudgetPlan.available` is intentionally clamped for envelope allocation.
/// User-facing budget summaries need the real remainder, including deficits and
/// future envelopes, so they are derived from the original inputs plus
/// `plan.future`.
class PresentBudgetBuilder {
  PresentBudgetBuilder._();

  static PresentBudget fromInputs({
    required BudgetInputs inputs,
    required BudgetPlan plan,
  }) {
    final monthlyNet = displayChf(inputs.netIncome);
    final monthlyCharges = fixedChargesFromInputs(inputs);
    final monthlySavings = displayChf(plan.future);
    final monthlyFree = monthlyNet - monthlyCharges - monthlySavings;

    return PresentBudget(
      monthlyNet: monthlyNet,
      monthlyCharges: monthlyCharges,
      monthlySavings: monthlySavings,
      monthlyFree: monthlyFree,
    );
  }

  static double fixedChargesFromInputs(BudgetInputs inputs) =>
      displayChf(inputs.housingCost) +
      displayChf(inputs.debtPayments) +
      displayChf(inputs.taxProvision) +
      displayChf(inputs.healthInsurance) +
      displayChf(inputs.otherFixedCosts);

  /// Display contract: rounded to the nearest CHF using Dart's `round()`
  /// semantics (`.5` away from zero), then exposed as a double for JSON maps.
  static double displayChf(double value) =>
      value.isFinite ? value.roundToDouble() : 0;
}
