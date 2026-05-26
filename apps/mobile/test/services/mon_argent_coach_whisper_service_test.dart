import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/budget_plan.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/mon_argent/coach_whisper_service.dart';
import 'package:mint_mobile/services/mon_argent/patrimoine_aggregator.dart';

void main() {
  group('CoachWhisperService', () {
    test('detects deficit from signed monthly cashflow', () {
      final whisper = CoachWhisperService.evaluate(
        budgetInputs: const BudgetInputs(
          payFrequency: PayFrequency.monthly,
          netIncome: 5000,
          housingCost: 5200,
          taxProvision: 500,
          healthInsurance: 420,
          debtPayments: 0,
        ),
        budgetPlan: const BudgetPlan(
          available: 0,
          variables: 0,
          future: 0,
          stopRuleTriggered: true,
          emergencyFundMonths: 0,
        ),
        patrimoine: const PatrimoineSummary(),
        profile: null,
      );

      expect(whisper, 'Mois serré. Regarde tes dépenses fixes.');
    });

    test('prefers canonical snapshot over stale provider plan', () {
      final whisper = CoachWhisperService.evaluate(
        budgetSnapshot: const BudgetSnapshot(
          present: PresentBudget(
            monthlyNet: 5000,
            monthlyCharges: 6200,
            monthlySavings: 0,
            monthlyFree: -1200,
          ),
          capImpacts: [],
          stage: BudgetStage.presentOnly,
          confidenceScore: 70,
        ),
        budgetInputs: const BudgetInputs(
          payFrequency: PayFrequency.monthly,
          netIncome: 9000,
          housingCost: 1500,
          taxProvision: 700,
          healthInsurance: 420,
          debtPayments: 0,
        ),
        budgetPlan: const BudgetPlan(
          available: 6380,
          variables: 5100,
          future: 1280,
          stopRuleTriggered: false,
          emergencyFundMonths: 0,
        ),
        patrimoine: const PatrimoineSummary(),
        profile: null,
      );

      expect(whisper, 'Mois serré. Regarde tes dépenses fixes.');
    });

    test('uses fixed charges instead of net income for emergency months', () {
      final whisper = CoachWhisperService.evaluate(
        budgetInputs: const BudgetInputs(
          payFrequency: PayFrequency.monthly,
          netIncome: 8000,
          housingCost: 1200,
          healthInsurance: 400,
          otherFixedCosts: 400,
          debtPayments: 0,
        ),
        budgetPlan: null,
        patrimoine: const PatrimoineSummary(
          epargneLiquide: PatrimoineField(
            value: 5000,
            source: 'userInput',
          ),
        ),
        profile: CoachProfile(
          birthYear: 1988,
          canton: 'VD',
          salaireBrutMensuel: 9000,
          goalA: GoalA(
            type: GoalAType.custom,
            targetDate: DateTime.utc(2027),
            label: 'Coussin',
          ),
        ),
      );

      expect(whisper, contains('2.5 mois'));
    });

    test('uses canonical monthly free for 3a suggestion without budget inputs',
        () {
      final whisper = CoachWhisperService.evaluate(
        budgetSnapshot: const BudgetSnapshot(
          present: PresentBudget(
            monthlyNet: 9000,
            monthlyCharges: 5000,
            monthlySavings: 0,
            monthlyFree: 4000,
          ),
          capImpacts: [],
          stage: BudgetStage.presentOnly,
          confidenceScore: 78,
        ),
        budgetInputs: null,
        budgetPlan: null,
        patrimoine: const PatrimoineSummary(),
        profile: CoachProfile(
          birthYear: 1988,
          canton: 'VD',
          salaireBrutMensuel: 9000,
          goalA: GoalA(
            type: GoalAType.custom,
            targetDate: DateTime.utc(2027),
            label: 'Retraite',
          ),
        ),
      );

      expect(whisper, 'Bon mois. Tu pourrais verser 1000\u00a0CHF en 3a.');
    });
  });
}
