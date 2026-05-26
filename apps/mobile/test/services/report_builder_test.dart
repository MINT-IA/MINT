import 'package:flutter_test/flutter_test.dart';
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
  });
}
