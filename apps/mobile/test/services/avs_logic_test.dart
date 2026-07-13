import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_report_service.dart';

void main() {
  test('couple inputs never manufacture an AVS amount in the report', () {
    final report = FinancialReportService().generateReport({
      'q_birth_year': 1980,
      'q_canton': 'ZH',
      'q_civil_status': 'married',
      'q_employment_status': 'employee',
      'q_net_income_period_chf': 8000,
      'q_avs_lacunes_status': 'no',
      'q_avs_contribution_years': 44,
      'q_spouse_avs_contribution_years': 44,
      'q_current_lpp_capital': 150000,
    });

    expect(report.retirementProjection, isNotNull);
    expect(report.retirementProjection!.monthlyAvsRent, isNull);
    expect(report.retirementProjection!.totalMonthlyIncome, isNull);
    expect(report.retirementProjection!.replacementRate, isNull);
  });
}
