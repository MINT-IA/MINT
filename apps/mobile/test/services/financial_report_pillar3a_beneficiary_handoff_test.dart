import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_report_service.dart';

import '../support/pillar3a_beneficiary_handoff_fixture.dart';

Map<String, dynamic> _answers() => <String, dynamic>{
      'q_birth_year': 1990,
      'q_canton': 'VD',
      'q_civil_status': 'single',
      'q_children': '0',
      'q_employment_status': 'employee',
      'q_net_income_period_chf': 6000.0,
    };

void main() {
  test('report is null by default and passes exact 3a handoff unchanged', () {
    final service = FinancialReportService();
    expect(
        service.generateReport(_answers()).pillar3aBeneficiaryHandoff, isNull);

    final handoff = pillar3aBeneficiaryHandoffFixture();
    final report = service.generateReport(
      _answers(),
      pillar3aBeneficiaryHandoff: handoff,
    );
    expect(report.pillar3aBeneficiaryHandoff, same(handoff));
  });

  test('report service never derives exact 3a authority from wizard answers',
      () {
    final report = FinancialReportService().generateReport(
      _answers()
        ..['_coach_pillar3a_beneficiary_evidence_v1'] = 'forbidden-direct-root',
    );
    expect(report.pillar3aBeneficiaryHandoff, isNull);

    final source =
        File('lib/services/financial_report_service.dart').readAsStringSync();
    expect(
      source,
      isNot(contains("['_coach_pillar3a_beneficiary_evidence_v1']")),
    );
    expect(source, isNot(contains('toLocalJson')));
  });
}
