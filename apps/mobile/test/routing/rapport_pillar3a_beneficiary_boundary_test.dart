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
  test('/rapport checks the exact triple gate before reading the 3a consumer',
      () {
    final route = _rapportRouteBlock(
      File('lib/app.dart').readAsStringSync(),
    );
    final resolver =
        route.indexOf('resolvePillar3aBeneficiarySpecialistHandoff()');
    expect(resolver, isNonNegative);
    for (final gate in const <String>[
      'FeatureFlags.typedLppEvidence',
      'FeatureFlags.documentLppEvidenceEnabled',
      'FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled',
    ]) {
      final gateIndex = route.indexOf(gate);
      expect(gateIndex, isNonNegative, reason: gate);
      expect(gateIndex, lessThan(resolver),
          reason: '$gate must guard the read');
    }
    expect(route, isNot(contains('tryFromConsumerResolution')));
    expect(route, isNot(contains('resolvePillar3aBeneficiaryConsumer')));
    expect(route, contains('pillar3aBeneficiaryHandoff:'));
  });

  test('/rapport never opens, decodes, or serializes the exact 3a root', () {
    final route = _rapportRouteBlock(
      File('lib/app.dart').readAsStringSync(),
    );
    for (final forbidden in const <String>[
      '_coach_pillar3a_beneficiary_evidence_v1',
      'Pillar3aBeneficiaryEvidenceRoot',
      'toLocalJson',
      'contractReferenceId',
      'referenceId',
      'documentAuthorityId',
    ]) {
      expect(route, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}
