import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/report/report_builder.dart';

void main() {
  group('ReportBuilder budget read model', () {
    test('uses BudgetInputs for persisted numeric strings and tax provision',
        () {
      final report = ReportBuilder({
        'q_canton': 'VD',
        'q_civil_status': 'single',
        'q_pay_frequency': 'monthly',
        'q_net_income_period_chf': "5'379",
        'q_housing_cost_period_chf': '2200',
        'q_lamal_premium_monthly_chf': '420',
        'q_tax_provision_monthly_chf': '520',
        'q_debt_payments_period_chf': '0',
      }).build();

      final available = report.scoreboard
          .singleWhere((item) => item.label == 'Disponible / mois');
      final tax = report.scoreboard
          .singleWhere((item) => item.label == 'Impôts Estimés');

      expect(available.value, 'CHF 2239');
      expect(tax.value, 'CHF 520');
    });

    test('preserves signed monthly deficit in scoreboard', () {
      final report = ReportBuilder({
        'q_canton': 'VD',
        'q_civil_status': 'single',
        'q_pay_frequency': 'monthly',
        'q_net_income_period_chf': '3000',
        'q_housing_cost_period_chf': '2500',
        'q_lamal_premium_monthly_chf': '420',
        'q_tax_provision_monthly_chf': '600',
        'q_debt_payments_period_chf': '0',
      }).build();

      final available = report.scoreboard
          .singleWhere((item) => item.label == 'Disponible / mois');
      final savingsRate = report.scoreboard
          .singleWhere((item) => item.label == "Taux d'épargne");

      expect(available.value, 'CHF -520');
      expect(available.value, isNot('CHF 0'));
      expect(savingsRate.value, '0%');
    });

    test('falls back to estimated tax when no tax provision is declared', () {
      final report = ReportBuilder({
        'q_canton': 'VD',
        'q_civil_status': 'single',
        'q_pay_frequency': 'monthly',
        'q_net_income_period_chf': "8'000",
        'q_housing_cost_period_chf': '2200',
        'q_lamal_premium_monthly_chf': '420',
        'q_debt_payments_period_chf': '0',
      }).build();

      final tax = report.scoreboard
          .singleWhere((item) => item.label == 'Impôts Estimés');

      expect(tax.value, isNot('CHF 0'));
      expect(tax.note, 'Prov. Vaud');
    });

    test('uses BudgetInputs debt parsing for persisted numeric strings', () {
      final report = ReportBuilder({
        'q_canton': 'VD',
        'q_civil_status': 'single',
        'q_pay_frequency': 'monthly',
        'q_net_income_period_chf': "5'379",
        'q_housing_cost_period_chf': '2200',
        'q_lamal_premium_monthly_chf': '420',
        'q_tax_provision_monthly_chf': '520',
        'q_debt_payments_period_chf': '150',
        'q_emergency_fund': 'yes_6months',
      }).build();

      expect(report.recommendations.first.id, 'reco_debt_safe');
    });

    test('does not invent a debt plan for emergency-fund-only Safe Mode', () {
      final report = ReportBuilder({
        'q_canton': 'VD',
        'q_civil_status': 'single',
        'q_pay_frequency': 'monthly',
        'q_net_income_period_chf': "5'379",
        'q_housing_cost_period_chf': '2200',
        'q_lamal_premium_monthly_chf': '420',
        'q_tax_provision_monthly_chf': '520',
        'q_has_consumer_debt': 'no',
        'q_debt_payments_period_chf': '0',
        'q_emergency_fund': 'no',
      }).build();

      expect(
        report.recommendations.map((recommendation) => recommendation.id),
        isNot(contains('reco_debt_safe')),
      );
      expect(
        report.topActions.map((action) => action.nextAction.deepLink),
        contains('/budget'),
      );

      final protection = report.scoreboard
          .singleWhere((item) => item.label == 'Score Protection');
      expect(protection.value, 'Faible');
      expect(protection.note, 'Réserve à renforcer');
    });

    test('keeps debt note when Safe Mode also has active debt', () {
      final report = ReportBuilder({
        'q_canton': 'VD',
        'q_civil_status': 'single',
        'q_pay_frequency': 'monthly',
        'q_net_income_period_chf': "5'379",
        'q_housing_cost_period_chf': '2200',
        'q_lamal_premium_monthly_chf': '420',
        'q_tax_provision_monthly_chf': '520',
        'q_has_consumer_debt': 'yes',
        'q_debt_payments_period_chf': '150',
        'q_emergency_fund': 'no',
      }).build();

      expect(report.recommendations.first.id, 'reco_debt_safe');

      final protection = report.scoreboard
          .singleWhere((item) => item.label == 'Score Protection');
      expect(protection.value, 'Faible');
      expect(protection.note, 'Dettes actives');
    });

    test('grounds first 3a recommendation impact in tax calculator', () {
      final report = ReportBuilder({
        'q_canton': 'VD',
        'q_civil_status': 'single',
        'q_children': '0',
        'q_employment_status': 'employee',
        'q_birth_year': DateTime.now().year - 45,
        'q_pay_frequency': 'monthly',
        'q_net_income_period_chf': '6000',
        'q_housing_cost_period_chf': '1800',
        'q_lamal_premium_monthly_chf': '420',
        'q_tax_provision_monthly_chf': '650',
        'q_debt_payments_period_chf': '0',
        'q_has_3a': 'no',
      }).build();

      final recommendation = report.recommendations.singleWhere(
          (recommendation) => recommendation.id == 'reco_3a_generic');
      final grossAnnualSalary = NetIncomeBreakdown.estimateBrutFromNet(
        6000.0 * 12,
        canton: 'VD',
      );
      final expected = RetirementTaxCalculator.estimate3aTaxImpact(
        grossAnnualSalary: grossAnnualSalary,
        canton: 'VD',
        isMarried: false,
        children: 0,
        hasLpp: true,
        contribution: pilier3aPlafondAvecLpp,
      ).estimatedTaxSaving;

      expect(recommendation.summary, isNot(contains('dès maintenant')));
      expect(recommendation.why.join(' '), isNot(contains('2000')));
      expect(recommendation.impact.amountCHF, closeTo(expected, 1.0));
      expect(recommendation.impact.amountCHF, isNot(1500));
    });

    test('missing birth data does not invent age for 3a tax impact', () {
      final report = ReportBuilder({
        'q_canton': 'VD',
        'q_civil_status': 'single',
        'q_children': '0',
        'q_employment_status': 'employee',
        'q_pay_frequency': 'monthly',
        'q_net_income_period_chf': '6000',
        'q_housing_cost_period_chf': '1800',
        'q_lamal_premium_monthly_chf': '420',
        'q_tax_provision_monthly_chf': '650',
        'q_debt_payments_period_chf': '0',
        'q_has_3a': 'no',
      }).build();

      final recommendation = report.recommendations.singleWhere(
          (recommendation) => recommendation.id == 'reco_3a_generic');

      expect(recommendation.impact.amountCHF, 0);
    });

    test('does not show fixed 3a gain when tax impact is unavailable', () {
      final report = ReportBuilder({
        'q_canton': 'VD',
        'q_civil_status': 'single',
        'q_children': '0',
        'q_employment_status': 'employee',
        'q_pay_frequency': 'monthly',
        'q_net_income_period_chf': '0',
        'q_housing_cost_period_chf': '0',
        'q_lamal_premium_monthly_chf': '420',
        'q_debt_payments_period_chf': '0',
        'q_has_3a': 'no',
      }).build();

      final recommendation = report.recommendations.singleWhere(
          (recommendation) => recommendation.id == 'reco_3a_generic');

      expect(recommendation.impact.amountCHF, 0);
      expect(recommendation.why.join(' '), isNot(contains('2000')));
    });

    test('does not invent a fixed optimization gain for an existing 3a', () {
      final report = ReportBuilder({
        'q_canton': 'VD',
        'q_civil_status': 'single',
        'q_pay_frequency': 'monthly',
        'q_net_income_period_chf': '6000',
        'q_housing_cost_period_chf': '1800',
        'q_lamal_premium_monthly_chf': '420',
        'q_tax_provision_monthly_chf': '650',
        'q_debt_payments_period_chf': '0',
        'q_has_3a': 'yes',
      }).build();

      final recommendation = report.recommendations
          .singleWhere((recommendation) => recommendation.id == 'reco_3a_opt');

      expect(recommendation.impact.amountCHF, 0);
      expect(recommendation.impact.amountCHF, isNot(500));
    });

    test('does not show generic 3a opening when contribution fact exists', () {
      final report = ReportBuilder({
        'q_canton': 'VD',
        'q_civil_status': 'single',
        'q_pay_frequency': 'monthly',
        'q_net_income_period_chf': '6000',
        'q_housing_cost_period_chf': '1800',
        'q_lamal_premium_monthly_chf': '420',
        'q_tax_provision_monthly_chf': '650',
        'q_debt_payments_period_chf': '0',
        'q_3a_annual_contribution': '3000',
      }).build();

      expect(
        report.recommendations.map((recommendation) => recommendation.id),
        isNot(contains('reco_3a_generic')),
      );
    });
  });
}
