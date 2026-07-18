import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';

const _snapshotId = '11111111-1111-4111-8111-111111111111';
const _replacementSnapshotId = '33333333-3333-4333-8333-333333333333';
const _ownerId = '22222222-2222-4222-8222-222222222222';
const _referenceId = '55555555-5555-4555-8555-555555555555';

DateTime _now() => DateTime.utc(2026, 7, 18, 12);

Map<String, dynamic> _regulationReference({
  String referenceId = _referenceId,
  String kind = 'lppRegulation',
  String ownerKind = 'self',
  String source = 'certificate',
  Object? sourceDate = '2026-02-03',
  Object? legalYear = 2026,
  Object? confirmedAt = '2026-02-04T09:30:00.000Z',
  Object? fundRelationship = 'currentFund',
  bool includeFundRelationship = true,
}) =>
    <String, dynamic>{
      'referenceId': referenceId,
      'kind': kind,
      'ownerKind': ownerKind,
      'source': source,
      'sourceDate': sourceDate,
      'legalYear': legalYear,
      'confirmedAt': confirmedAt,
      if (includeFundRelationship) 'fundRelationship': fundRelationship,
    };

Map<String, dynamic> _legacyRegulationReference() => <String, dynamic>{
      'referenceId': _referenceId,
      'kind': 'lppRegulation',
      'ownerKind': 'self',
      'source': 'certificate',
      'sourceDate': '2026-02-03',
      'legalYear': 2026,
      'confirmedAt': '2026-02-04T09:30:00.000Z',
    };

Map<String, dynamic> _selfFact({double value = 125000.0}) => <String, dynamic>{
      'value': value,
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

Map<String, dynamic> _selfSnapshot({
  String snapshotId = _snapshotId,
  double value = 125000.0,
  bool includeCapitalNotice = false,
  bool includeLegacyRegulation = false,
}) =>
    <String, dynamic>{
      'snapshotId': snapshotId,
      'facts': <String, dynamic>{
        'vestedBenefitsCapitalChf': _selfFact(value: value),
      },
      if (includeCapitalNotice)
        'lppCapitalNoticeDeadline': <String, dynamic>{
          'referenceId': '66666666-6666-4666-8666-666666666666',
          'kind': 'lppCapitalNotice',
          'ownerKind': 'self',
          'source': 'certificate',
          'sourceDate': '2026-02-03',
          'legalYear': 2026,
          'confirmedAt': '2026-02-04T09:30:00.000Z',
          'deadlineDate': '2026-09-30',
        },
      if (includeLegacyRegulation)
        'lppRegulationReference': _legacyRegulationReference(),
    };

Map<String, dynamic> _schema2Root({
  Map<String, dynamic>? self,
  Map<String, dynamic>? selfRegulationReference,
  Map<String, dynamic>? legacyPartnerQuarantine,
}) =>
    <String, dynamic>{
      'schemaVersion': 2,
      'self': self,
      'manualPartner': null,
      'legacyPartnerQuarantine': legacyPartnerQuarantine,
      'selfRegulationReference': selfRegulationReference,
    };

Map<String, dynamic> _legacySchema1Root() => <String, dynamic>{
      'schemaVersion': 1,
      'self': _selfSnapshot(
        includeCapitalNotice: true,
        includeLegacyRegulation: true,
      ),
      'manualPartner': null,
      'legacyPartnerQuarantine': <String, dynamic>{
        'legacySchemaVersion': 0,
        'reasonCodes': <String>['untyped_legacy_partner_lpp'],
        'presentKeys': <String>['_coach_conjoint_avoir_lpp'],
        'quarantinedAt': '2026-02-01T12:00:00.000Z',
      },
    };

LppEvidenceRoot? _decode(Map<String, dynamic> root) =>
    LppEvidenceRoot.fromJsonString(jsonEncode(root), now: _now);

Map<String, dynamic> _roundTrip(LppEvidenceRoot root) =>
    Map<String, dynamic>.from(jsonDecode(root.toJsonString()) as Map);

void main() {
  group('autonomous LPP regulation root contract', () {
    test('schema 2 admits a reference-only root for each exact relationship',
        () {
      for (final relationship in <String>{
        'currentFund',
        'uncertain',
        'formerOrOther',
      }) {
        final reference = _regulationReference(
          fundRelationship: relationship,
        );
        final parsed = _decode(
          _schema2Root(selfRegulationReference: reference),
        );

        expect(
          parsed,
          isNotNull,
          reason: '$relationship must not require a numeric self snapshot',
        );
        final dynamic typedRoot = parsed;
        final dynamic typedReference = typedRoot.selfRegulationReference;
        expect(typedReference, isNotNull);
        expect(typedReference.fundRelationship.wireName, relationship);
        final encoded = _roundTrip(parsed!);
        expect(encoded['schemaVersion'], 2);
        expect(encoded['self'], isNull);
        expect(encoded['selfRegulationReference'], reference);
      }
    });

    test('fund relationship is mandatory, exact, and has no default', () {
      expect(
        _decode(
          _schema2Root(
            selfRegulationReference: _regulationReference(),
          ),
        ),
        isNotNull,
        reason: 'The valid baseline distinguishes strict rejection from a '
            'schema-wide failure.',
      );

      for (final invalid in <Map<String, dynamic>>[
        _regulationReference(includeFundRelationship: false),
        _regulationReference(fundRelationship: null),
        _regulationReference(fundRelationship: ''),
        _regulationReference(fundRelationship: 'current'),
        _regulationReference(fundRelationship: 'former'),
        _regulationReference(fundRelationship: 'CURRENT_FUND'),
        _regulationReference(fundRelationship: true),
      ]) {
        expect(
          _decode(_schema2Root(selfRegulationReference: invalid)),
          isNull,
          reason: jsonEncode(invalid),
        );
      }
    });

    test('1900 is the technical lower bound and 1984 is not special-cased', () {
      for (final year in <int>[1900, 1984]) {
        final parsed = _decode(
          _schema2Root(
            selfRegulationReference: _regulationReference(
              sourceDate: '${year.toString().padLeft(4, '0')}-01-01',
              legalYear: year,
              fundRelationship: 'uncertain',
            ),
          ),
        );
        expect(
          parsed,
          isNotNull,
          reason: '$year is valid; no 1985 product cutoff belongs here',
        );
      }

      for (final year in <int>[1899, 10000]) {
        expect(
          _decode(
            _schema2Root(
              selfRegulationReference: _regulationReference(
                legalYear: year,
              ),
            ),
          ),
          isNull,
          reason: '$year is outside the technical serialization bound',
        );
      }
    });

    test('the autonomous reference is metadata-only and snapshotless', () {
      final reference = _regulationReference(
        fundRelationship: 'formerOrOther',
      );
      final parsed = _decode(
        _schema2Root(selfRegulationReference: reference),
      );
      expect(parsed, isNotNull);

      final encoded = _roundTrip(parsed!);
      final encodedReference = Map<String, dynamic>.from(
        encoded['selfRegulationReference']! as Map,
      );
      expect(encodedReference.keys.toSet(), reference.keys.toSet());
      expect(
        encodedReference.keys.toSet().intersection(<String>{
          'amount',
          'amountChf',
          'value',
          'fundName',
          'pensionFundName',
          'snapshotId',
        }),
        isEmpty,
      );

      for (final forbidden in <String>{
        'amount',
        'amountChf',
        'value',
        'fundName',
        'pensionFundName',
        'snapshotId',
      }) {
        final polluted = Map<String, dynamic>.from(reference)
          ..[forbidden] = forbidden == 'amount' ? 1 : 'forbidden';
        expect(
          _decode(
            _schema2Root(selfRegulationReference: polluted),
          ),
          isNull,
          reason: forbidden,
        );
      }
    });

    test(
        'schema 1 migration preserves facts, capital notice, and quarantine but drops nested regulation',
        () {
      final legacy = _legacySchema1Root();
      final legacySelf = Map<String, dynamic>.from(legacy['self']! as Map);

      final parsed = _decode(legacy);

      expect(parsed, isNotNull);
      final migrated = _roundTrip(parsed!);
      final migratedSelf = Map<String, dynamic>.from(migrated['self']! as Map);
      expect(migrated['schemaVersion'], 2);
      expect(migrated.keys.toSet(), <String>{
        'schemaVersion',
        'self',
        'manualPartner',
        'legacyPartnerQuarantine',
        'selfRegulationReference',
      });
      expect(migratedSelf['snapshotId'], _snapshotId);
      expect(migratedSelf['facts'], legacySelf['facts']);
      expect(
        migratedSelf['lppCapitalNoticeDeadline'],
        legacySelf['lppCapitalNoticeDeadline'],
      );
      expect(migratedSelf.containsKey('lppRegulationReference'), isFalse);
      expect(
        migrated['legacyPartnerQuarantine'],
        legacy['legacyPartnerQuarantine'],
      );
      expect(migrated['selfRegulationReference'], isNull);
      expect(jsonEncode(migrated), isNot(contains('currentFund')));
    });

    test('numeric root reconstruction preserves the autonomous reference', () {
      final reference = _regulationReference(
        fundRelationship: 'uncertain',
      );
      final parsed = _decode(
        _schema2Root(
          self: _selfSnapshot(includeCapitalNotice: true),
          selfRegulationReference: reference,
        ),
      );

      expect(parsed, isNotNull);
      expect(
        LppEvidenceSelector.selectSelf(
          parsed!.toJsonString(),
          now: _now,
        ),
        isNotNull,
      );
      final replacementSelf = LppEvidenceSnapshot.fromJson(
        _selfSnapshot(
          snapshotId: _replacementSnapshotId,
          value: 130000,
        ),
        expectedOwnerKind: LppEvidenceOwnerKind.self,
        now: _now,
      );
      expect(replacementSelf, isNotNull);
      final dynamic typedRoot = parsed;
      final reconstructed = Function.apply(
        LppEvidenceRoot.new,
        const <Object?>[],
        <Symbol, Object?>{
          #self: replacementSelf,
          #manualPartner: parsed.manualPartner,
          #legacyPartnerQuarantine: parsed.legacyPartnerQuarantine,
          #selfRegulationReference: typedRoot.selfRegulationReference,
        },
      ) as LppEvidenceRoot;
      final encoded = _roundTrip(reconstructed);
      expect(encoded['selfRegulationReference'], reference);
      expect((encoded['self']! as Map)['snapshotId'], _replacementSnapshotId);
      expect(
        ((encoded['self']! as Map)['facts']! as Map)['vestedBenefitsCapitalChf']
            ['value'],
        130000,
      );
    });
  });
}
