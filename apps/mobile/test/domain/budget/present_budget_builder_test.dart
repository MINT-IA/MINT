import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/budget_plan.dart';
import 'package:mint_mobile/domain/budget/present_budget_builder.dart';

void main() {
  group('PresentBudgetBuilder.fromInputs', () {
    test('preserves real deficit instead of BudgetPlan available clamp', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 3000,
        housingCost: 2500,
        debtPayments: 600,
        taxProvision: 400,
        healthInsurance: 450,
      );
      const plan = BudgetPlan(
        available: 0,
        variables: 0,
        future: 0,
        stopRuleTriggered: true,
      );

      final present = PresentBudgetBuilder.fromInputs(
        inputs: inputs,
        plan: plan,
      );

      expect(present.monthlyNet, 3000);
      expect(present.monthlyCharges, 3950);
      expect(present.monthlySavings, 0);
      expect(present.monthlyFree, -950);
      expect(present.isDeficit, isTrue);
    });

    test('subtracts future envelope from the real monthly remainder', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 5379,
        housingCost: 2200,
        debtPayments: 0,
        taxProvision: 520,
        healthInsurance: 420,
      );
      const plan = BudgetPlan(
        available: 2239,
        variables: 1539,
        future: 700,
        stopRuleTriggered: false,
      );

      final present = PresentBudgetBuilder.fromInputs(
        inputs: inputs,
        plan: plan,
      );

      expect(present.monthlyNet, 5379);
      expect(present.monthlyCharges, 3140);
      expect(present.monthlySavings, 700);
      expect(present.monthlyFree, 1539);
    });

    test('rounds every displayed input before computing monthlyFree', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 5000.4,
        housingCost: 1200.5,
        debtPayments: 200.49,
        taxProvision: 300.5,
        healthInsurance: 410.49,
        otherFixedCosts: 100.5,
      );
      const plan = BudgetPlan(
        available: 0,
        variables: 0,
        future: 250.5,
        stopRuleTriggered: false,
      );

      final present = PresentBudgetBuilder.fromInputs(
        inputs: inputs,
        plan: plan,
      );

      expect(present.monthlyNet, 5000);
      expect(present.monthlyCharges, 2213);
      expect(present.monthlySavings, 251);
      expect(present.monthlyFree, 2536);
    });

    test('sanitizes non-finite input values for display read models', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: double.nan,
        housingCost: 1200.4,
        debtPayments: double.infinity,
        taxProvision: 300.5,
        healthInsurance: 410.2,
        otherFixedCosts: double.nan,
      );
      const plan = BudgetPlan(
        available: 0,
        variables: 0,
        future: double.infinity,
        stopRuleTriggered: true,
      );

      final present = PresentBudgetBuilder.fromInputs(
        inputs: inputs,
        plan: plan,
      );

      expect(present.monthlyNet, 0);
      expect(present.monthlyCharges, 1911);
      expect(present.monthlySavings, 0);
      expect(present.monthlyFree, -1911);
    });
  });
}
