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

Map<String, dynamic> _capitalNotice({
  String referenceId = '66666666-6666-4666-8666-666666666666',
  String kind = 'lppCapitalNotice',
  String ownerKind = 'self',
  String sourceDate = '2026-02-03',
  int legalYear = 2026,
  String confirmedAt = '2026-02-04T09:30:00.000Z',
  String deadlineDate = '2026-09-30',
}) =>
    <String, dynamic>{
      'referenceId': referenceId,
      'kind': kind,
      'ownerKind': ownerKind,
      'source': 'certificate',
      'sourceDate': sourceDate,
      'legalYear': legalYear,
      'confirmedAt': confirmedAt,
      'deadlineDate': deadlineDate,
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

    test('cold selector uses Zurich civil midnight in CEST and CET', () {
      for (final boundary in <({
        String sourceDate,
        DateTime beforeLocalMidnight,
        DateTime afterLocalMidnight,
      })>[
        (
          sourceDate: '2026-07-16',
          beforeLocalMidnight: DateTime.utc(2026, 7, 15, 21, 59),
          afterLocalMidnight: DateTime.utc(2026, 7, 15, 22, 1),
        ),
        (
          sourceDate: '2027-01-01',
          beforeLocalMidnight: DateTime.utc(2026, 12, 31, 22, 59),
          afterLocalMidnight: DateTime.utc(2026, 12, 31, 23, 1),
        ),
      ]) {
        final raw = jsonEncode(_validRoot(sourceDate: boundary.sourceDate));

        expect(
          LppEvidenceSelector.selectSelf(
            raw,
            now: () => boundary.beforeLocalMidnight,
          ),
          isNull,
          reason:
              '${boundary.sourceDate} is tomorrow in Zurich before midnight',
        );
        expect(
          LppEvidenceSelector.selectSelf(
            raw,
            now: () => boundary.afterLocalMidnight,
          ),
          isNotNull,
          reason: '${boundary.sourceDate} is today in Zurich after midnight',
        );
      }
    });

    test(
        'schema-v1 self snapshot accepts one exact optional capital notice without changing facts',
        () {
      final encoded = _validRoot();
      final self = encoded['self']! as Map<String, dynamic>;
      self['lppCapitalNoticeDeadline'] = _capitalNotice();

      final root = LppEvidenceRoot.fromJsonString(jsonEncode(encoded));

      expect(root, isNotNull);
      expect(root!.self!.snapshotId, _snapshotId);
      expect(root.self!.facts.keys,
          <LppEvidenceFactKey>[LppEvidenceFactKey.vestedBenefitsCapitalChf]);
      final notice = root.self!.lppCapitalNoticeDeadline;
      expect(notice, isNotNull);
      expect(notice!.referenceId, '66666666-6666-4666-8666-666666666666');
      expect(notice.deadlineDate, DateTime.utc(2026, 9, 30));
    });

    test('capital notice rejects inference-shaped, incomplete and extra fields',
        () {
      for (final mutation in <void Function(Map<String, dynamic>)>[
        (notice) => notice.remove('sourceDate'),
        (notice) => notice.remove('legalYear'),
        (notice) => notice.remove('deadlineDate'),
        (notice) => notice['sourceDate'] = '2026',
        (notice) => notice['deadlineDate'] = '2026-09',
        (notice) => notice['kind'] = 'lpp',
        (notice) => notice['documentType'] = 'privateLppCertificate',
      ]) {
        final encoded = _validRoot();
        final notice = _capitalNotice();
        mutation(notice);
        (encoded['self']! as Map<String, dynamic>)['lppCapitalNoticeDeadline'] =
            notice;
        expect(
          LppEvidenceRoot.fromJsonString(jsonEncode(encoded)),
          isNull,
        );
      }
    });

    test('capital notice is self-only and cannot create a factless root', () {
      final manual = _validRoot();
      manual['manualPartner'] = _manualPartnerSnapshot()
        ..['lppCapitalNoticeDeadline'] = _capitalNotice(
          ownerKind: 'manualPartner',
        );
      expect(LppEvidenceRoot.fromJsonString(jsonEncode(manual)), isNull);

      final factless = _validRoot();
      final self = factless['self']! as Map<String, dynamic>;
      self['facts'] = <String, dynamic>{};
      self['lppCapitalNoticeDeadline'] = _capitalNotice();
      expect(LppEvidenceRoot.fromJsonString(jsonEncode(factless)), isNull);
    });

    test('ordinary certificate facts alone never synthesize a capital notice',
        () {
      final root = LppEvidenceRoot.fromJsonString(jsonEncode(_validRoot()));
      expect(root!.self!.lppCapitalNoticeDeadline, isNull);
    });
  });
}
