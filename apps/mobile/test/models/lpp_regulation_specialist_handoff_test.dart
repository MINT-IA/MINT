import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_regulation_specialist_handoff.dart';

const _referenceId = '11111111-1111-4111-8111-111111111111';
final _confirmedAt = DateTime.utc(2026, 7, 18, 10, 15, 30);
const _topics = <String>[
  'buyback',
  'conversion',
  'flexibleRetirement',
  'disability',
  'survivors',
  'divorce',
];

SpecialistReferenceEvidence _regulationEvidence({String ownerKind = 'self'}) =>
    SpecialistReferenceEvidence.tryFromJson(
      <String, dynamic>{
        'referenceId': _referenceId,
        'kind': 'lppRegulation',
        'ownerKind': ownerKind,
        'source': 'certificate',
        'sourceDate': '2026-02-03',
        'legalYear': 2026,
        'confirmedAt': _confirmedAt.toIso8601String(),
      },
      expectedKind: SpecialistReferenceKind.lppRegulation,
      now: _confirmedAt.add(const Duration(seconds: 1)),
    )!;

SpecialistReferenceEvidence _capitalEvidence() =>
    SpecialistReferenceEvidence.tryFromJson(
      <String, dynamic>{
        'referenceId': _referenceId,
        'kind': 'lppCapitalNotice',
        'ownerKind': 'self',
        'source': 'certificate',
        'sourceDate': '2026-02-03',
        'legalYear': 2026,
        'confirmedAt': _confirmedAt.toIso8601String(),
        'deadlineDate': '2026-09-30',
      },
      expectedKind: SpecialistReferenceKind.lppCapitalNotice,
      now: _confirmedAt.add(const Duration(seconds: 1)),
    )!;

SpecialistReferenceEvidence _taxEvidence() =>
    SpecialistReferenceEvidence.tryFromJson(
      <String, dynamic>{
        'referenceId': _referenceId,
        'kind': 'taxAssessmentDecision',
        'ownerKind': 'self',
        'source': 'certificate',
        'sourceDate': '2026-02-03',
        'legalYear': 2026,
        'confirmedAt': _confirmedAt.toIso8601String(),
        'taxYear': 2026,
        'jurisdiction': 'VD',
        'subject': 'individual',
      },
      expectedKind: SpecialistReferenceKind.taxAssessmentDecision,
      now: _confirmedAt.add(const Duration(seconds: 1)),
    )!;

dynamic _handoffFrom(SpecialistReferenceEvidence? evidence) =>
    LppRegulationSpecialistHandoff.tryFromEvidence(evidence);

void main() {
  test('regulation evidence exposes the ordered specialist topics', () {
    final handoff = _handoffFrom(_regulationEvidence());

    expect(handoff, isNotNull);
    expect(handoff.documentKind, 'lppRegulation');
    expect(handoff.sourceDate, DateTime.utc(2026, 2, 3));
    expect(handoff.legalYear, 2026);
    expect(handoff.confirmedAt, _confirmedAt);
    expect(handoff.topics, _topics);
  });

  test('local handoff serialization is an exact metadata-only allowlist', () {
    final handoff = _handoffFrom(_regulationEvidence());
    final json = Map<String, dynamic>.from(handoff.toLocalJson() as Map);

    expect(json, <String, dynamic>{
      'documentKind': 'lppRegulation',
      'sourceDate': '2026-02-03',
      'legalYear': 2026,
      'confirmedAt': '2026-07-18T10:15:30.000Z',
      'topics': _topics,
    });
    final encoded = jsonEncode(json).toLowerCase();
    for (final forbidden in <String>[
      'referenceid',
      'snapshotid',
      'ownerkind',
      'certificate',
      'chf',
      'taux',
      'raw',
    ]) {
      expect(encoded, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('null, partner, capital-notice, and other kinds fail closed', () {
    for (final candidate in <SpecialistReferenceEvidence?>[
      null,
      _regulationEvidence(ownerKind: 'manualPartner'),
      _capitalEvidence(),
      _taxEvidence(),
    ]) {
      expect(_handoffFrom(candidate), isNull);
    }
  });
}
