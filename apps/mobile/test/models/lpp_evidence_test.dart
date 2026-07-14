import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';

const _snapshotId = '11111111-1111-4111-8111-111111111111';
const _ownerId = '22222222-2222-4222-8222-222222222222';
const _partnerSnapshotId = '33333333-3333-4333-8333-333333333333';
const _partnerOwnerId = '44444444-4444-4444-8444-444444444444';
const _wrongActorId = '55555555-5555-4555-8555-555555555555';

Map<String, dynamic> _validRoot({
  String source = 'certificate',
  Object? sourceDate = '2026-01-14',
  String updatedAt = '2026-01-15T12:00:00.000Z',
}) =>
    <String, dynamic>{
      'schemaVersion': 1,
      'self': <String, dynamic>{
        'snapshotId': _snapshotId,
        'facts': <String, dynamic>{
          'vestedBenefitsCapitalChf': <String, dynamic>{
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
              'source': source,
              'sourceDate': sourceDate,
              'updatedAt': updatedAt,
            },
          },
        },
      },
      'manualPartner': null,
      'legacyPartnerQuarantine': null,
    };

Map<String, dynamic> _manualPartnerSnapshot({
  String actorId = _ownerId,
  Object? grantId,
  String authorizationMode = 'manualPartnerDeclaration',
}) =>
    <String, dynamic>{
      'snapshotId': _partnerSnapshotId,
      'facts': <String, dynamic>{
        'vestedBenefitsCapitalChf': <String, dynamic>{
          'value': 84000.0,
          'unit': 'CHF',
          'owner': <String, dynamic>{
            'kind': 'manualPartner',
            'profileOwnerId': _partnerOwnerId,
          },
          'actor': <String, dynamic>{'profileOwnerId': actorId},
          'authorization': <String, dynamic>{
            'mode': authorizationMode,
            'grantId': grantId,
          },
          'provenance': <String, dynamic>{
            'source': 'certificate',
            'sourceDate': null,
            'updatedAt': '2026-01-15T12:00:00.000Z',
          },
        },
      },
    };

void main() {
  group('LppEvidenceRoot strict decoding', () {
    test('requires the exact root key set', () {
      for (final requiredKey in <String>[
        'schemaVersion',
        'self',
        'manualPartner',
        'legacyPartnerQuarantine',
      ]) {
        final mutated = _validRoot()
          ..remove(requiredKey)
          ..['unknown_$requiredKey'] = null;

        expect(
          LppEvidenceRoot.fromJsonString(jsonEncode(mutated)),
          isNull,
          reason: 'required root key replaced by unknown null: $requiredKey',
        );
      }
    });

    test('requires sourceDate to be exact YYYY-MM-DD', () {
      for (final malformed in <String>[
        '2026-1-14',
        '2026-01-14T00:00:00.000Z',
      ]) {
        expect(
          LppEvidenceRoot.fromJsonString(
            jsonEncode(_validRoot(sourceDate: malformed)),
          ),
          isNull,
          reason: malformed,
        );
      }
    });

    test('requires updatedAt to round-trip as the canonical UTC instant', () {
      for (final malformed in <String>[
        '2026-01-15T13:00:00.000+01:00',
        '2026-01-15T12:00:00Z',
      ]) {
        expect(
          LppEvidenceRoot.fromJsonString(
            jsonEncode(_validRoot(updatedAt: malformed)),
          ),
          isNull,
          reason: malformed,
        );
      }
    });

    test('userInput provenance requires a null sourceDate', () {
      expect(
        LppEvidenceRoot.fromJsonString(
          jsonEncode(
            _validRoot(source: 'userInput', sourceDate: '2026-01-14'),
          ),
        ),
        isNull,
      );
    });

    test('a certificate without a date explicitly needs confirmation', () {
      final root = LppEvidenceRoot.fromJsonString(
        jsonEncode(_validRoot(sourceDate: null)),
      );
      final fact = root!.self!.facts.values.single;

      expect(fact.status, LppEvidenceStatus.availableNeedsConfirmation);
    });

    test('corrected user input with a null date is available', () {
      final root = LppEvidenceRoot.fromJsonString(
        jsonEncode(_validRoot(source: 'userInput', sourceDate: null)),
      );
      final fact = root!.self!.facts.values.single;

      expect(fact.status, LppEvidenceStatus.available);
    });

    test('manual partner actor must match the persisted self owner', () {
      final mutated = _validRoot()
        ..['manualPartner'] = _manualPartnerSnapshot(actorId: _wrongActorId);

      expect(
        LppEvidenceRoot.fromJsonString(jsonEncode(mutated)),
        isNull,
      );
      expect(
        LppEvidenceSelector.selectManualPartner(
          jsonEncode(mutated),
          expectedOwnerId: _partnerOwnerId,
          now: () => DateTime.utc(2026, 7, 14),
        ),
        isNull,
      );
    });

    test('linked mode and grant-shaped manual partner facts are rejected', () {
      for (final snapshot in <Map<String, dynamic>>[
        _manualPartnerSnapshot(authorizationMode: 'linkedPartnerGrant'),
        _manualPartnerSnapshot(grantId: _snapshotId),
      ]) {
        final mutated = _validRoot()..['manualPartner'] = snapshot;
        expect(
          LppEvidenceRoot.fromJsonString(jsonEncode(mutated)),
          isNull,
        );
      }
    });

    test('an invalid manual slot cannot hide a valid self slot', () {
      final mutated = _validRoot()
        ..['manualPartner'] = _manualPartnerSnapshot(
          authorizationMode: 'linkedPartnerGrant',
        );

      expect(
        LppEvidenceSelector.selectSelf(
          jsonEncode(mutated),
          now: () => DateTime.utc(2026, 7, 14),
        ),
        isNotNull,
      );
    });
  });
}
