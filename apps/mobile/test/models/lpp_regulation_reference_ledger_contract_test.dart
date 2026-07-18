import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';

const _snapshotId = '11111111-1111-4111-8111-111111111111';
const _ownerId = '22222222-2222-4222-8222-222222222222';
const _partnerSnapshotId = '33333333-3333-4333-8333-333333333333';
const _partnerOwnerId = '44444444-4444-4444-8444-444444444444';
const _referenceId = '55555555-5555-4555-8555-555555555555';

Map<String, dynamic> _regulationReference({
  String referenceId = _referenceId,
  String kind = 'lppRegulation',
  String ownerKind = 'self',
  String source = 'certificate',
  Object? sourceDate = '2026-02-03',
  Object? legalYear = 2026,
  Object? confirmedAt = '2026-02-04T09:30:00.000Z',
}) =>
    <String, dynamic>{
      'referenceId': referenceId,
      'kind': kind,
      'ownerKind': ownerKind,
      'source': source,
      'sourceDate': sourceDate,
      'legalYear': legalYear,
      'confirmedAt': confirmedAt,
    };

Map<String, dynamic> _selfFact() => <String, dynamic>{
      'value': 125000.0,
      'unit': 'CHF',
      'owner': <String, dynamic>{
        'kind': 'self',
        'profileOwnerId': _ownerId,
      },
      'actor': <String, dynamic>{'profileOwnerId': _ownerId},
      'authorization': <String, dynamic>{
        'mode': 'self',
        'grantId': null,
      },
      'provenance': <String, dynamic>{
        'source': 'certificate',
        'sourceDate': '2026-01-31',
        'updatedAt': '2026-02-01T12:00:00.000Z',
      },
    };

Map<String, dynamic> _manualPartnerSnapshot() => <String, dynamic>{
      'snapshotId': _partnerSnapshotId,
      'facts': <String, dynamic>{
        'vestedBenefitsCapitalChf': <String, dynamic>{
          'value': 84000.0,
          'unit': 'CHF',
          'owner': <String, dynamic>{
            'kind': 'manualPartner',
            'profileOwnerId': _partnerOwnerId,
          },
          'actor': <String, dynamic>{'profileOwnerId': _ownerId},
          'authorization': <String, dynamic>{
            'mode': 'manualPartnerDeclaration',
            'grantId': null,
          },
          'provenance': <String, dynamic>{
            'source': 'certificate',
            'sourceDate': '2026-01-31',
            'updatedAt': '2026-02-01T12:00:00.000Z',
          },
        },
      },
    };

Map<String, dynamic> _root({
  Map<String, dynamic>? regulationReference,
  bool factlessSelf = false,
  bool regulationOnManualPartner = false,
}) {
  final self = <String, dynamic>{
    'snapshotId': _snapshotId,
    'facts': factlessSelf
        ? <String, dynamic>{}
        : <String, dynamic>{
            'vestedBenefitsCapitalChf': _selfFact(),
          },
    if (regulationReference != null && !regulationOnManualPartner)
      'lppRegulationReference': regulationReference,
  };
  final manualPartner = regulationOnManualPartner
      ? (_manualPartnerSnapshot()
        ..['lppRegulationReference'] = regulationReference)
      : null;
  return <String, dynamic>{
    'schemaVersion': 1,
    'self': self,
    'manualPartner': manualPartner,
    'legacyPartnerQuarantine': null,
  };
}

void main() {
  group('LPP regulation reference strict ledger contract', () {
    test(
        'schema 1 admits and round-trips exact metadata on a non-empty self snapshot',
        () {
      final encoded = _root(regulationReference: _regulationReference());
      final originalSelf = Map<String, dynamic>.from(
        encoded['self']! as Map<String, dynamic>,
      );

      final parsed = LppEvidenceRoot.fromJsonString(jsonEncode(encoded));

      expect(
        parsed,
        isNotNull,
        reason: 'The current RED is only the missing positive admission of '
            'self.lppRegulationReference in the existing schema-1 snapshot.',
      );
      final roundTrip =
          jsonDecode(parsed!.toJsonString()) as Map<String, dynamic>;
      final roundTripSelf =
          Map<String, dynamic>.from(roundTrip['self']! as Map);
      expect(roundTrip['schemaVersion'], 1);
      expect(roundTripSelf['snapshotId'], _snapshotId);
      expect(roundTripSelf['facts'], originalSelf['facts']);
      expect(
        roundTripSelf['lppRegulationReference'],
        _regulationReference(),
      );
    });

    test('unknown payload, value, raw, path, and OCR keys reject the root', () {
      for (final forbidden in <String>[
        'payload',
        'value',
        'raw',
        'path',
        'ocrText',
      ]) {
        final reference = _regulationReference()..[forbidden] = 'forbidden';
        expect(
          LppEvidenceRoot.fromJsonString(
            jsonEncode(_root(regulationReference: reference)),
          ),
          isNull,
          reason: forbidden,
        );
      }
    });

    test('manualPartner, wrong kind, and wrong source reject the root', () {
      final cases = <Map<String, dynamic>>[
        _root(
          regulationReference: _regulationReference(ownerKind: 'manualPartner'),
          regulationOnManualPartner: true,
        ),
        _root(
          regulationReference: _regulationReference(
            kind: 'lppCapitalNotice',
          ),
        ),
        _root(
          regulationReference: _regulationReference(source: 'userInput'),
        ),
      ];
      for (final encoded in cases) {
        expect(
          LppEvidenceRoot.fromJsonString(jsonEncode(encoded)),
          isNull,
        );
      }
    });

    test('future or noncanonical source and confirmation dates reject the root',
        () {
      for (final reference in <Map<String, dynamic>>[
        _regulationReference(sourceDate: '2999-01-01'),
        _regulationReference(sourceDate: '2026-2-03'),
        _regulationReference(sourceDate: '2026-02-03T00:00:00.000Z'),
        _regulationReference(confirmedAt: '2999-01-01T00:00:00.000Z'),
        _regulationReference(confirmedAt: '2026-02-04T09:30:00Z'),
        _regulationReference(confirmedAt: '2026-02-04T10:30:00.000+01:00'),
      ]) {
        expect(
          LppEvidenceRoot.fromJsonString(
            jsonEncode(_root(regulationReference: reference)),
          ),
          isNull,
        );
      }
    });

    test('invalid legal year, UUID, and factless self reject the root', () {
      for (final reference in <Map<String, dynamic>>[
        _regulationReference(legalYear: 1899),
        _regulationReference(legalYear: 10000),
        _regulationReference(legalYear: '2026'),
        _regulationReference(referenceId: 'not-a-uuid'),
      ]) {
        expect(
          LppEvidenceRoot.fromJsonString(
            jsonEncode(_root(regulationReference: reference)),
          ),
          isNull,
        );
      }
      expect(
        LppEvidenceRoot.fromJsonString(
          jsonEncode(
            _root(
              regulationReference: _regulationReference(),
              factlessSelf: true,
            ),
          ),
        ),
        isNull,
      );
    });
  });
}
