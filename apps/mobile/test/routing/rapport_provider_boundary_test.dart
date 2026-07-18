import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _rapportRouteBlock(String source) {
  final start = source.indexOf("path: '/rapport'");
  expect(start, isNonNegative, reason: '/rapport route missing');
  final rest = source.substring(start);
  final end = rest.indexOf("path: '/report'");
  expect(end, isNonNegative, reason: '/report alias missing');
  return rest.substring(0, end);
}

void main() {
  test('/rapport reads the provider snapshot, never the persistence store', () {
    final app = File('lib/app.dart').readAsStringSync();
    final route = _rapportRouteBlock(app);

    expect(route, isNot(contains('ReportPersistenceService.loadAnswers')));
    expect(route, contains('context.watch<CoachProfileProvider>()'));
    expect(route, contains('context.watch<DocumentProvider?>()'));
    expect(route, contains('resolveLppRegulation('));
    expect(route, contains('LppRegulationSpecialistHandoff.tryFromEvidence'));
    expect(route, contains('lppRegulationHandoff:'));
    expect(route, contains('reportAnswersSnapshot'));
    expect(route, contains('snapshot.hasError'));
    expect(route, contains('FinancialReportScreenV2'));
    expect(route, isNot(contains("['_coach_lpp_evidence_v1']")));
    expect(route, isNot(contains('toLocalJson')));
    expect(route, isNot(contains('referenceId')));
  });
}
