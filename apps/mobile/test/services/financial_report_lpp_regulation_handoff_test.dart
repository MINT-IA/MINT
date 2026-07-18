import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_regulation_specialist_handoff.dart';
import 'package:mint_mobile/services/financial_report_service.dart';

const _referenceId = '11111111-1111-4111-8111-111111111111';
final _confirmedAt = DateTime.utc(2026, 7, 18, 10, 15, 30);

LppRegulationSpecialistHandoff _handoff() {
  final evidence = SpecialistReferenceEvidence.tryFromJson(
    <String, dynamic>{
      'referenceId': _referenceId,
      'kind': 'lppRegulation',
      'ownerKind': 'self',
      'source': 'certificate',
      'sourceDate': '2026-02-03',
      'legalYear': 2026,
      'confirmedAt': _confirmedAt.toIso8601String(),
      'fundRelationship': 'currentFund',
    },
    expectedKind: SpecialistReferenceKind.lppRegulation,
    now: _confirmedAt.add(const Duration(seconds: 1)),
  );
  return LppRegulationSpecialistHandoff.tryFromEvidence(evidence)!;
}

Map<String, dynamic> _answers() => <String, dynamic>{
      'q_birth_year': 1990,
      'q_canton': 'VD',
      'q_civil_status': 'single',
      'q_children': '0',
      'q_employment_status': 'employee',
      'q_net_income_period_chf': 6000.0,
    };

void main() {
  test('report service is null by default and passes typed handoff unchanged',
      () {
    final service = FinancialReportService();
    final without = service.generateReport(_answers());
    expect(without.lppRegulationHandoff, isNull);

    final handoff = _handoff();
    final withHandoff = service.generateReport(
      _answers(),
      lppRegulationHandoff: handoff,
    );
    expect(withHandoff.lppRegulationHandoff, same(handoff));
  });

  test('report service never derives regulation authority from raw answers',
      () {
    final service = FinancialReportService();
    final answers = _answers()
      ..['_coach_lpp_evidence_v1'] = <String, dynamic>{
        'referenceId': _referenceId,
        'kind': 'lppRegulation',
        'fundRelationship': 'currentFund',
      };

    final report = service.generateReport(answers);
    expect(report.lppRegulationHandoff, isNull);

    final source =
        File('lib/services/financial_report_service.dart').readAsStringSync();
    expect(source, isNot(contains("['_coach_lpp_evidence_v1']")));
    expect(source, isNot(contains('toLocalJson')));
  });
}
