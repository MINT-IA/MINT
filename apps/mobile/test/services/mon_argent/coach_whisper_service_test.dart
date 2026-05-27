import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/budget_plan.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/mon_argent/coach_whisper_service.dart';
import 'package:mint_mobile/services/mon_argent/patrimoine_aggregator.dart';

void main() {
  group('CoachWhisperService', () {
    test('does not suggest 3a from clamped available when free cash is low',
        () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 6000,
        housingCost: 2000,
        debtPayments: 0,
        taxProvision: 600,
        healthInsurance: 400,
      );
      const plan = BudgetPlan(
        available: 3000,
        variables: 100,
        future: 2900,
        stopRuleTriggered: false,
      );

      final whisper = CoachWhisperService.evaluate(
        budgetInputs: inputs,
        budgetPlan: plan,
        patrimoine: const PatrimoineSummary(
          epargneLiquide: PatrimoineField(value: 30000, source: 'userInput'),
          investissements: PatrimoineField(value: 10000, source: 'userInput'),
          dettes: PatrimoineField(value: 0, source: 'userInput'),
        ),
        profile: _profile(),
      );

      expect(whisper, isNull);
    });

    test('suggests 3a from signed monthly free cash when genuinely high', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 6000,
        housingCost: 2000,
        debtPayments: 0,
        taxProvision: 600,
        healthInsurance: 400,
      );
      const plan = BudgetPlan(
        available: 3000,
        variables: 2500,
        future: 500,
        stopRuleTriggered: false,
      );

      final whisper = CoachWhisperService.evaluate(
        budgetInputs: inputs,
        budgetPlan: plan,
        patrimoine: const PatrimoineSummary(
          epargneLiquide: PatrimoineField(value: 30000, source: 'userInput'),
          investissements: PatrimoineField(value: 10000, source: 'userInput'),
          dettes: PatrimoineField(value: 0, source: 'userInput'),
        ),
        profile: _profile(),
      );

      expect(whisper, 'Bon mois. Tu pourrais verser 625\u00a0CHF en 3a.');
    });
  });
}

CoachProfile _profile() {
  return CoachProfile(
    birthYear: 1990,
    canton: 'VD',
    salaireBrutMensuel: 6000,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2055),
      label: 'Retraite',
    ),
  );
}
