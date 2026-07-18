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

Map<String, dynamic> _schema3Root({
  Map<String, dynamic>? self,
  Map<String, dynamic>? selfRegulationReference,
  Object? selfRegulationRecoveryReason,
}) =>
    <String, dynamic>{
      'schemaVersion': 3,
      'self': self,
      'manualPartner': null,
      'legacyPartnerQuarantine': null,
      'selfRegulationReference': selfRegulationReference,
      'selfRegulationRecoveryReason': selfRegulationRecoveryReason,
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

Map<String, dynamic> _legacySchema1RootWithReference(Object? reference) {
  final root = _legacySchema1Root();
  final self = root['self']! as Map<String, dynamic>;
  self['lppRegulationReference'] = reference;
  return root;
}

LppEvidenceRoot? _decode(Map<String, dynamic> root) =>
    LppEvidenceRoot.fromJsonString(jsonEncode(root), now: _now);

Map<String, dynamic> _roundTrip(LppEvidenceRoot root) =>
    Map<String, dynamic>.from(jsonDecode(root.toJsonString()) as Map);

void main() {
  group('autonomous LPP regulation root contract', () {
    test('schema 2 migrates a reference-only root for each exact relationship',
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
        expect(encoded['schemaVersion'], 3);
        expect(encoded['self'], isNull);
        expect(encoded['selfRegulationReference'], reference);
        expect(encoded['selfRegulationRecoveryReason'], isNull);
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
        'schema 1 migration preserves facts and quarantine but drops authority-less notice and nested regulation',
        () {
      final legacy = _legacySchema1Root();
      final legacySelf = Map<String, dynamic>.from(legacy['self']! as Map);

      final parsed = _decode(legacy);

      expect(parsed, isNotNull);
      expect(parsed!.droppedLegacyCapitalNoticeWithoutAuthority, isTrue);
      final migrated = _roundTrip(parsed);
      final migratedSelf = Map<String, dynamic>.from(migrated['self']! as Map);
      expect(migrated['schemaVersion'], 3);
      expect(migrated.keys.toSet(), <String>{
        'schemaVersion',
        'self',
        'manualPartner',
        'legacyPartnerQuarantine',
        'selfRegulationReference',
        'selfRegulationRecoveryReason',
      });
      expect(migratedSelf['snapshotId'], _snapshotId);
      expect(migratedSelf['facts'], legacySelf['facts']);
      expect(
        migratedSelf.containsKey('lppCapitalNoticeDeadline'),
        isFalse,
      );
      expect(migratedSelf.containsKey('lppRegulationReference'), isFalse);
      expect(
        migrated['legacyPartnerQuarantine'],
        legacy['legacyPartnerQuarantine'],
      );
      expect(migrated['selfRegulationReference'], isNull);
      expect(
        migrated['selfRegulationRecoveryReason'],
        'legacyMissingFundRelationship',
      );
      expect(jsonEncode(migrated), isNot(contains('currentFund')));
    });

    test(
        'schema 1 validates the exact legacy regulation payload before dropping it',
        () {
      final missingKey = _legacyRegulationReference()..remove('confirmedAt');
      final extraKey = _legacyRegulationReference()
        ..['unexpectedAuthority'] = true;
      final wrongKind = _legacyRegulationReference()
        ..['kind'] = 'lppCapitalNotice';
      final malformedDate = _legacyRegulationReference()
        ..['sourceDate'] = '2026-2-03';
      final malformedUuid = _legacyRegulationReference()
        ..['referenceId'] = 'not-a-canonical-uuid-v4';

      for (final invalid in <Map<String, dynamic>>[
        missingKey,
        extraKey,
        wrongKind,
        malformedDate,
        malformedUuid,
      ]) {
        expect(
          _decode(_legacySchema1RootWithReference(invalid)),
          isNull,
          reason: 'A malformed legacy authority must reject the whole root, '
              'not be silently stripped or promoted: ${jsonEncode(invalid)}',
        );
      }
    });

    test(
        'schema 1 distinguishes an absent nested regulation from explicit non-map values',
        () {
      final withoutNestedRegulation = _legacySchema1Root();
      (withoutNestedRegulation['self']! as Map<String, dynamic>)
          .remove('lppRegulationReference');
      expect(
        _decode(withoutNestedRegulation),
        isNotNull,
        reason:
            'Only genuine key absence is a valid legacy no-authority state.',
      );
      expect(
        _roundTrip(
            _decode(withoutNestedRegulation)!)['selfRegulationRecoveryReason'],
        isNull,
      );

      for (final explicitInvalid in <Object?>[
        null,
        'not-a-regulation-map',
        <Object?>[],
      ]) {
        expect(
          _decode(_legacySchema1RootWithReference(explicitInvalid)),
          isNull,
          reason: 'An explicitly present legacy authority must be a strict '
              'seven-key map before it can be dropped: $explicitInvalid',
        );
      }
    });

    test('schema 1 and schema 2 keep exact four and five key allowlists', () {
      final schema1 = _legacySchema1Root();
      (schema1['self']! as Map<String, dynamic>)
          .remove('lppRegulationReference');
      final schema2 = _schema2Root();
      expect(_decode(schema1), isNotNull);
      expect(_decode(schema2), isNotNull);

      for (final root in <Map<String, dynamic>>[schema1, schema2]) {
        for (final key in root.keys) {
          expect(
            _decode(Map<String, dynamic>.from(root)..remove(key)),
            isNull,
            reason: 'schema ${root['schemaVersion']} missing $key',
          );
        }
        expect(
          _decode(Map<String, dynamic>.from(root)..['extra'] = true),
          isNull,
          reason: 'schema ${root['schemaVersion']} extra key',
        );
      }
    });

    test('schema 3 requires six exact keys and one exact nullable reason', () {
      final marker = _schema3Root(
        selfRegulationRecoveryReason: 'legacyMissingFundRelationship',
      );
      final parsedMarker = _decode(marker);
      expect(parsedMarker, isNotNull);
      expect(_roundTrip(parsedMarker!), marker);

      final authority = _schema3Root(
        selfRegulationReference: _regulationReference(),
      );
      expect(_decode(authority), isNotNull);

      for (final key in marker.keys) {
        final missing = Map<String, dynamic>.from(marker)..remove(key);
        expect(_decode(missing), isNull, reason: 'missing $key');
      }
      expect(
        _decode(Map<String, dynamic>.from(marker)..['extra'] = true),
        isNull,
      );
      for (final invalidReason in <Object>[
        'unknownReason',
        1,
        true,
        <Object>[],
      ]) {
        expect(
          _decode(_schema3Root(
            selfRegulationRecoveryReason: invalidReason,
          )),
          isNull,
          reason: '$invalidReason',
        );
      }
      expect(
        _decode(_schema3Root(
          selfRegulationReference: _regulationReference(),
          selfRegulationRecoveryReason: 'legacyMissingFundRelationship',
        )),
        isNull,
        reason: 'authority and recovery marker cannot coexist',
      );
    });

    test('numeric root reconstruction preserves the recovery reason', () {
      final parsed = _decode(
        _schema3Root(
          self: _selfSnapshot(includeCapitalNotice: true),
          selfRegulationRecoveryReason: 'legacyMissingFundRelationship',
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
          #selfRegulationRecoveryReason: typedRoot.selfRegulationRecoveryReason,
        },
      ) as LppEvidenceRoot;
      final encoded = _roundTrip(reconstructed);
      expect(encoded['selfRegulationReference'], isNull);
      expect(
        encoded['selfRegulationRecoveryReason'],
        'legacyMissingFundRelationship',
      );
      expect((encoded['self']! as Map)['snapshotId'], _replacementSnapshotId);
      expect(
        ((encoded['self']! as Map)['facts']! as Map)['vestedBenefitsCapitalChf']
            ['value'],
        130000,
      );
    });
  });
}
