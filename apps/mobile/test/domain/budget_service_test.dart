import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/budget_service.dart';

void main() {
  late BudgetService service;

  setUp(() {
    service = BudgetService();
  });

  group('BudgetService Logic', () {
    test('computePlan justAvailable calculates correctly', () {
      final inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 6000,
        housingCost: 2000,
        debtPayments: 500,
        style: BudgetStyle.justAvailable,
      );

      final plan = service.computePlan(inputs);

      // Expected: 6000 - 2000 - 500 = 3500
      expect(plan.available, 3500);
      expect(plan.variables, 3500); // Pour justAvailable, variables = available
      expect(plan.future, 0);
      expect(plan.stopRuleTriggered, false);
    });

    test('computePlan Envelopes3 default splits (all to variables)', () {
      final inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 5000,
        housingCost: 1500,
        debtPayments: 0,
        style: BudgetStyle.envelopes3,
      );

      final plan = service.computePlan(inputs);

      // Expected: 5000 - 1500 = 3500
      expect(plan.available, 3500);
      expect(plan.variables, 3500);
      expect(plan.future, 0);
      expect(plan.stopRuleTriggered, false);
    });

    test('computePlan Envelopes3 with Future override', () {
      final inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 5000,
        housingCost: 1500,
        debtPayments: 0,
        style: BudgetStyle.envelopes3,
      );

      // User wants to save 500
      final plan = service.computePlan(inputs, overrides: {'future': 500});

      expect(plan.available, 3500);
      expect(plan.future, 500);
      expect(plan.variables, 3000); // 3500 - 500
      expect(plan.stopRuleTriggered, false);
    });

    test('computePlan Envelopes3 Stop Rule Triggered', () {
      final inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 5000,
        housingCost: 1500,
        debtPayments: 0,
        style: BudgetStyle.envelopes3,
      );

      // User puts EVERYTHING in future (unrealistic but tests the logic)
      final plan = service.computePlan(inputs, overrides: {'future': 3500});

      expect(plan.available, 3500);
      expect(plan.future, 3500);
      expect(plan.variables, 0);
      expect(plan.stopRuleTriggered, true); // Variables is 0 => Stop!
    });

    test('computePlan negative fallback', () {
      final inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 1000,
        housingCost: 2000, // Costs > Income
        debtPayments: 0,
        style: BudgetStyle.justAvailable,
      );

      final plan = service.computePlan(inputs);
      expect(plan.available, 0); // Should be max(0, ...)
    });

    test('computePlan inclut impots, lamal et autres charges fixes', () {
      final inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 8000,
        housingCost: 1800,
        debtPayments: 400,
        taxProvision: 1200,
        healthInsurance: 430,
        otherFixedCosts: 300,
        style: BudgetStyle.justAvailable,
      );

      final plan = service.computePlan(inputs);
      expect(plan.available, 3870); // 8000 - 1800 - 400 - 1200 - 430 - 300
    });
  });
}
