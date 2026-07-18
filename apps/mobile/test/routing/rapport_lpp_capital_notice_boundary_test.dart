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
  test('/rapport derives capital handoff only through exact document resolver',
      () {
    final app = File('lib/app.dart').readAsStringSync();
    final route = _rapportRouteBlock(app);

    expect(route, contains('context.watch<CoachProfileProvider>()'));
    expect(route, contains('context.watch<DocumentProvider?>()'));
    expect(route, contains('resolveLppCapitalNotice('));
    expect(route, contains('resolveLppRegulation('));
    expect(
      route,
      contains(
        'LppCapitalNoticeSpecialistHandoff.tryFromResolvedEvidence',
      ),
    );
    expect(route, contains('capitalNoticeEvidence:'));
    expect(route, contains('regulationEvidence:'));
    expect(route, contains('lppCapitalNoticeHandoff:'));
    expect(route, isNot(contains("['_coach_lpp_evidence_v1']")));
    expect(route, isNot(contains('toLocalJson')));
    expect(route, isNot(contains('referenceId')));
    expect(route, isNot(contains('authorityReferenceId')));
    expect(route, isNot(contains('snapshotId')));
  });
}
