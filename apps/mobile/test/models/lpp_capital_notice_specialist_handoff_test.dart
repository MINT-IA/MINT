import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_capital_notice_specialist_handoff.dart';

const _referenceId = '22222222-2222-4222-8222-222222222222';
final _confirmedAt = DateTime.utc(2026, 7, 18, 10, 15, 30);

SpecialistReferenceEvidence? _evidence({
  String kind = 'lppCapitalNotice',
  String ownerKind = 'self',
  String? deadlineDate = '2026-09-30',
}) {
  final expectedKind = switch (kind) {
    'lppCapitalNotice' => SpecialistReferenceKind.lppCapitalNotice,
    'lppRegulation' => SpecialistReferenceKind.lppRegulation,
    _ => SpecialistReferenceKind.taxAssessmentDecision,
  };
  return SpecialistReferenceEvidence.tryFromJson(
    <String, dynamic>{
      'referenceId': _referenceId,
      'kind': kind,
      'ownerKind': ownerKind,
      'source': 'certificate',
      'sourceDate': '2026-02-03',
      'legalYear': 2026,
      'confirmedAt': _confirmedAt.toIso8601String(),
      if (kind == 'lppCapitalNotice' && deadlineDate != null)
        'deadlineDate': deadlineDate,
      if (kind == 'lppRegulation') 'fundRelationship': 'currentFund',
      if (kind == 'taxAssessmentDecision') ...<String, dynamic>{
        'taxYear': 2026,
        'jurisdiction': 'VD',
        'subject': 'individual',
      },
    },
    expectedKind: expectedKind,
    now: _confirmedAt.add(const Duration(seconds: 1)),
  );
}

SpecialistReferenceEvidence? _regulationEvidence({
  String ownerKind = 'self',
  String fundRelationship = 'currentFund',
  String sourceDate = '2026-02-03',
  int legalYear = 2026,
}) =>
    SpecialistReferenceEvidence.tryFromJson(
      <String, dynamic>{
        'referenceId': '11111111-1111-4111-8111-111111111111',
        'kind': 'lppRegulation',
        'ownerKind': ownerKind,
        'source': 'certificate',
        'sourceDate': sourceDate,
        'legalYear': legalYear,
        'confirmedAt': _confirmedAt.toIso8601String(),
        'fundRelationship': fundRelationship,
      },
      expectedKind: SpecialistReferenceKind.lppRegulation,
      now: _confirmedAt.add(const Duration(seconds: 1)),
    );

void main() {
  test('capital-notice handoff is an exact metadata-only projection', () {
    final handoff = LppCapitalNoticeSpecialistHandoff.tryFromResolvedEvidence(
      capitalNoticeEvidence: _evidence(),
      regulationEvidence: _regulationEvidence(),
    );

    expect(handoff, isNotNull);
    expect(handoff!.documentKind, 'lppCapitalNotice');
    expect(handoff.sourceDate, DateTime.utc(2026, 2, 3));
    expect(handoff.legalYear, 2026);
    expect(handoff.confirmedAt, _confirmedAt);
    expect(handoff.deadlineDate, DateTime.utc(2026, 9, 30));
    expect(handoff.fundRelationship.wireName, 'currentFund');

    expect(handoff.toLocalJson(), <String, dynamic>{
      'documentKind': 'lppCapitalNotice',
      'sourceDate': '2026-02-03',
      'legalYear': 2026,
      'confirmedAt': '2026-07-18T10:15:30.000Z',
      'deadlineDate': '2026-09-30',
      'fundRelationship': 'currentFund',
    });
    final encoded = jsonEncode(handoff.toLocalJson()).toLowerCase();
    for (final forbidden in <String>[
      _referenceId,
      'referenceid',
      'authorityreferenceid',
      'snapshotid',
      'ownerkind',
      'certificate',
      'raw',
      'ocr',
      'chf',
    ]) {
      expect(encoded, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('past civil deadline remains an explicit stale-display candidate', () {
    final handoff = LppCapitalNoticeSpecialistHandoff.tryFromResolvedEvidence(
      capitalNoticeEvidence: _evidence(deadlineDate: '2026-01-01'),
      regulationEvidence: _regulationEvidence(),
    );

    expect(handoff, isNotNull);
    expect(handoff!.deadlineDate, DateTime.utc(2026, 1, 1));
  });

  test('null, wrong kinds, non-self, and non-current authority fail closed',
      () {
    final missingDeadline = _evidence(deadlineDate: null);
    expect(missingDeadline, isNull);

    for (final candidate in <SpecialistReferenceEvidence?>[
      null,
      missingDeadline,
      _evidence(kind: 'lppRegulation'),
      _evidence(kind: 'taxAssessmentDecision'),
      _evidence(ownerKind: 'manualPartner'),
    ]) {
      expect(
        LppCapitalNoticeSpecialistHandoff.tryFromResolvedEvidence(
          capitalNoticeEvidence: candidate,
          regulationEvidence: _regulationEvidence(),
        ),
        isNull,
      );
    }

    for (final regulation in <SpecialistReferenceEvidence?>[
      null,
      _regulationEvidence(ownerKind: 'manualPartner'),
      _regulationEvidence(fundRelationship: 'uncertain'),
      _regulationEvidence(fundRelationship: 'formerOrOther'),
      _evidence(),
    ]) {
      expect(
        LppCapitalNoticeSpecialistHandoff.tryFromResolvedEvidence(
          capitalNoticeEvidence: _evidence(),
          regulationEvidence: regulation,
        ),
        isNull,
      );
    }
  });

  test('capital and regulation document metadata must stay coherent', () {
    for (final regulation in <SpecialistReferenceEvidence?>[
      _regulationEvidence(sourceDate: '2026-02-02'),
      _regulationEvidence(legalYear: 2025),
    ]) {
      expect(
        LppCapitalNoticeSpecialistHandoff.tryFromResolvedEvidence(
          capitalNoticeEvidence: _evidence(),
          regulationEvidence: regulation,
        ),
        isNull,
      );
    }
  });
}
