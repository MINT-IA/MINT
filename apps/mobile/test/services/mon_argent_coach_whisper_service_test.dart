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

    test('uses canonical rounded charges for emergency months', () {
      final whisper = CoachWhisperService.evaluate(
        budgetInputs: const BudgetInputs(
          payFrequency: PayFrequency.monthly,
          netIncome: 8000,
          housingCost: 1200.5,
          healthInsurance: 400.5,
          taxProvision: 300.5,
          debtPayments: 200.5,
          otherFixedCosts: 100.5,
        ),
        budgetPlan: null,
        patrimoine: const PatrimoineSummary(
          epargneLiquide: PatrimoineField(
            value: 5397,
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

      expect(whisper, contains('2.4 mois'));
    });

    test('detects deficit from canonical rounded budget read model', () {
      final whisper = CoachWhisperService.evaluate(
        budgetInputs: const BudgetInputs(
          payFrequency: PayFrequency.monthly,
          netIncome: 3004.4,
          housingCost: 1200.5,
          healthInsurance: 400.5,
          taxProvision: 1100.5,
          debtPayments: 200.5,
          otherFixedCosts: 100.5,
        ),
        budgetPlan: null,
        patrimoine: const PatrimoineSummary(),
        profile: null,
      );

      expect(whisper, 'Mois serré. Regarde tes dépenses fixes.');
    });

    test('uses canonical rounded income when charges are still missing', () {
      final whisper = CoachWhisperService.evaluate(
        budgetInputs: const BudgetInputs(
          payFrequency: PayFrequency.monthly,
          netIncome: 8000.4,
          housingCost: 0,
          healthInsurance: 0,
          taxProvision: 0,
          debtPayments: 0,
          otherFixedCosts: 0,
        ),
        budgetPlan: null,
        patrimoine: const PatrimoineSummary(
          epargneLiquide: PatrimoineField(
            value: 19600.5,
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
        now: DateTime(2026, 1, 15), // deterministic proration (12 months left)
      );

      // D10 clamp: monthlyFree 4000 \u2192 round(4000\u00d70.25)=1000 pre-fix, but the
      // statutory remaining ceiling /12 = 7258/12 \u2248 604.83 \u2192 605 governs.
      // The raw 1000 (\u00d712 = 12'000 \u2248 1.65\u00d7 the 7258 ceiling) is NO LONGER
      // suggested \u2014 the canonical clamp caps the figure.
      expect(whisper, 'Bon mois. Tu pourrais verser 605\u00a0CHF en 3a.');
    });
  });
}
