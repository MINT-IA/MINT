import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/document_provider.dart';

const _referenceId = '11111111-1111-4111-8111-111111111111';
const _snapshotId = '22222222-2222-4222-8222-222222222222';
const _regulationKind = 'lppRegulation';
const _confirmedAt = '2026-07-18T10:15:30.000Z';

Map<String, dynamic> _referenceJson({
  String referenceId = _referenceId,
  String kind = _regulationKind,
  String snapshotId = _snapshotId,
  String ownerKind = 'self',
  String confirmedAt = _confirmedAt,
}) {
  return <String, dynamic>{
    'referenceId': referenceId,
    'kind': kind,
    'snapshotId': snapshotId,
    'ownerKind': ownerKind,
    'confirmedAt': confirmedAt,
  };
}

ConfirmedDocumentReference? _asRegulationAuthority(
  Map<String, dynamic> json,
) {
  final reference = ConfirmedDocumentReference.fromJson(json);
  return reference?.kind == _regulationKind ? reference : null;
}

void main() {
  test('BND admits the exact raw-free self LPP regulation reference', () {
    final reference = ConfirmedDocumentReference.fromJson(_referenceJson());

    expect(
      reference,
      isNotNull,
      reason: 'TDD RED: BND does not yet admit exact lppRegulation authority',
    );
    if (reference == null) return;

    expect(reference.referenceId, _referenceId);
    expect(reference.kind, _regulationKind);
    expect(reference.snapshotId, _snapshotId);
    expect(reference.ownerKind, LppEvidenceOwnerKind.self);
    expect(reference.confirmedAt, DateTime.utc(2026, 7, 18, 10, 15, 30));
    expect(reference.toJson(), _referenceJson());
  });

  test('regulation authority rejects generic and capital-notice kinds', () {
    for (final kind in <String>[
      ConfirmedDocumentReference.lppKind,
      ConfirmedDocumentReference.lppCapitalNoticeKind,
    ]) {
      expect(
        _asRegulationAuthority(_referenceJson(kind: kind)),
        isNull,
        reason: '$kind must not masquerade as regulation authority',
      );
    }
  });

  test('regulation authority rejects a partner-owned reference', () {
    expect(
      ConfirmedDocumentReference.fromJson(
        _referenceJson(ownerKind: 'manualPartner'),
      ),
      isNull,
    );
  });

  test('regulation authority rejects non-canonical identifiers', () {
    for (final json in <Map<String, dynamic>>[
      _referenceJson(referenceId: 'not-a-uuid'),
      _referenceJson(snapshotId: '22222222-2222-1222-8222-222222222222'),
    ]) {
      expect(ConfirmedDocumentReference.fromJson(json), isNull);
    }
  });

  test('regulation authority rejects non-canonical confirmation times', () {
    for (final confirmedAt in <String>[
      '2026-07-18T10:15:30+00:00',
      '2026-07-18T10:15:30.000',
      'not-an-instant',
    ]) {
      expect(
        ConfirmedDocumentReference.fromJson(
          _referenceJson(confirmedAt: confirmedAt),
        ),
        isNull,
      );
    }
  });

  test('regulation authority rejects payload-bearing references', () {
    for (final forbiddenKey in <String>['payload', 'amountChf', 'sourceText']) {
      final json = _referenceJson()..[forbiddenKey] = 'RAW_FORBIDDEN';
      expect(
        ConfirmedDocumentReference.fromJson(json),
        isNull,
        reason: '$forbiddenKey must never enter BND reference metadata',
      );
    }
  });
}
