import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/mon_argent/coach_whisper_service.dart';
import 'package:mint_mobile/services/mon_argent/patrimoine_aggregator.dart';

void main() {
  group('CoachWhisperService', () {
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
  });
}
