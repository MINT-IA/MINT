import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';

const _snapshotId = '11111111-1111-4111-8111-111111111111';
const _ownerId = '22222222-2222-4222-8222-222222222222';

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
  });
}
