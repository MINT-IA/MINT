import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/budget_crash_financial_facts.dart';
import 'package:mint_mobile/services/financial_core/unemployment_budget_estimator.dart';
import 'package:mint_mobile/services/financial_core/unemployment_financial_facts.dart';

void main() {
  group('BudgetCrashFinancialFacts', () {
    test('calculates totals, margins and survival savings', () {
      final totals = BudgetCrashFinancialFacts.calculate(
        monthlyIncome: 7000,
        survivalIncome: 5200,
        normalAmounts: const [2100, 450, 300],
        survivalAmounts: const [2100, 450, 150],
      );

      expect(totals.totalNormal, 2850);
      expect(totals.totalSurvival, 2700);
      expect(totals.marginNormal, 4150);
      expect(totals.marginSurvival, 2500);
      expect(totals.saving, 150);
    });

    test('validates imported monthly expenses against the income ceiling', () {
      expect(
        BudgetCrashFinancialFacts.isMonthlyExpensePlausible(
          monthlyExpense: 7500,
          grossMonthlyIncome: 10000,
          maximumExpenseRatio: 0.50,
        ),
        isTrue,
      );
      expect(
        BudgetCrashFinancialFacts.isMonthlyExpensePlausible(
          monthlyExpense: 7500.01,
          grossMonthlyIncome: 10000,
          maximumExpenseRatio: 0.50,
        ),
        isFalse,
      );
      expect(
        BudgetCrashFinancialFacts.isMonthlyExpensePlausible(
          monthlyExpense: 3000,
          grossMonthlyIncome: 0,
          maximumExpenseRatio: 0.50,
        ),
        isTrue,
      );
    });
  });

  group('UnemploymentFinancialFacts', () {
    test('converts annual insured earnings to monthly gain assure', () {
      expect(
        UnemploymentFinancialFacts.monthlyInsuredEarningsFromAnnual(104000),
        closeTo(8666.67, 0.01),
      );
      expect(
        UnemploymentFinancialFacts.monthlyInsuredEarningsFromAnnual(0),
        isNull,
      );
    });

    test('adds near-AVS supplement only with 22 contribution months', () {
      expect(
        UnemploymentFinancialFacts.withNearAvsExtraDays(
          baseDays: 400,
          contributionMonths: 18,
          nearAvsReferenceAge: true,
        ),
        400,
      );
      expect(
        UnemploymentFinancialFacts.withNearAvsExtraDays(
          baseDays: 520,
          contributionMonths: 22,
          nearAvsReferenceAge: true,
        ),
        640,
      );
    });

    test('calculates OACI/LACI general waiting days by income and children',
        () {
      expect(
        UnemploymentFinancialFacts.generalWaitingDays(
          annualInsuredEarnings: 30000,
          hasMaintenanceDuty: false,
        ),
        0,
      );
      expect(
        UnemploymentFinancialFacts.generalWaitingDays(
          annualInsuredEarnings: 48000,
          hasMaintenanceDuty: true,
        ),
        0,
      );
      expect(
        UnemploymentFinancialFacts.generalWaitingDays(
          annualInsuredEarnings: 72000,
          hasMaintenanceDuty: false,
        ),
        10,
      );
      expect(
        UnemploymentFinancialFacts.generalWaitingDays(
          annualInsuredEarnings: 100000,
          hasMaintenanceDuty: true,
        ),
        5,
      );
      expect(
        UnemploymentFinancialFacts.generalWaitingDays(
          annualInsuredEarnings: 132000,
          hasMaintenanceDuty: false,
        ),
        20,
      );
    });

    test('estimates net monthly benefit from gross LACI benefit', () {
      expect(
        UnemploymentFinancialFacts.estimatedNetMonthlyBenefitFromGross(5600),
        5040,
      );
    });
  });

  group('UnemploymentBudgetEstimator', () {
    test('returns null until monthly expense facts are user-provided', () {
      final profile = CoachProfile.fromWizardAnswers({
        'q_gross_salary_annual': 96000,
      });

      expect(
        UnemploymentBudgetEstimator.fromLedger(
          profile: profile,
          grossMonthlyBenefit: 6400,
        ),
        isNull,
      );
    });

    test('uses ledger expenses and the already computed LACI benefit', () {
      final profile = CoachProfile.fromWizardAnswers({
        'q_net_income_period_chf': 6900,
        'q_housing_cost_period_chf': 2200,
        'q_lamal_premium_monthly_chf': 410,
        '_coach_depenses_transport': 180,
      });
      final estimate = UnemploymentBudgetEstimator.fromLedger(
        profile: profile,
        grossMonthlyBenefit: 6400,
      );

      expect(estimate, isNotNull);
      final value = estimate!;
      expect(value.normalIncome, 6900);
      expect(value.survivalIncome, 5760);
      expect(value.housing, 2200);
      expect(value.lamal, 410);
      expect(value.transport, 180);
    });

    test('returns null when budget cash-flow lacks declared net income', () {
      final profile = CoachProfile.fromWizardAnswers({
        'q_housing_cost_period_chf': 2200,
        'q_lamal_premium_monthly_chf': 410,
      });

      expect(
        UnemploymentBudgetEstimator.fromLedger(
          profile: profile,
          grossMonthlyBenefit: 6400,
        ),
        isNull,
      );
    });
  });
}
