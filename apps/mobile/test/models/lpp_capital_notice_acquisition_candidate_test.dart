import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';

const _snapshotId = '11111111-1111-4111-8111-111111111111';
const _previousNoticeId = '22222222-2222-4222-8222-222222222222';

void main() {
  test('capital notice acquisition candidate retains strict ids only', () {
    final candidate = LppCapitalNoticeAcquisitionCandidate(
      expectedSnapshotId: _snapshotId,
      expectedPreviousReferenceId: _previousNoticeId,
    );

    expect(candidate.expectedSnapshotId, _snapshotId);
    expect(candidate.expectedPreviousReferenceId, _previousNoticeId);

    final source = File('lib/models/lpp_evidence.dart').readAsStringSync();
    final start = source.indexOf(
      'final class LppCapitalNoticeAcquisitionCandidate',
    );
    final end = source.indexOf(
      'final class LppRegulationAcquisitionCandidate',
      start,
    );
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final declaration = source.substring(start, end).toLowerCase();
    for (final forbidden in const <String>[
      'raw',
      'ocr',
      'path',
      'sha',
      'hash',
      'datetime',
      'deadline',
      'sourcedate',
      'tojson',
      'fromjson',
    ]) {
      expect(declaration, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('capital notice acquisition candidate allows no previous notice', () {
    final candidate = LppCapitalNoticeAcquisitionCandidate(
      expectedSnapshotId: _snapshotId,
    );

    expect(candidate.expectedSnapshotId, _snapshotId);
    expect(candidate.expectedPreviousReferenceId, isNull);
  });

  test('capital notice acquisition candidate rejects non-canonical UUIDv4s',
      () {
    for (final invalidSnapshotId in const <String>[
      '',
      'not-a-uuid',
      '11111111-1111-3111-8111-111111111111',
      '11111111-1111-4111-7111-111111111111',
      '11111111-1111-4111-8111-11111111111A',
    ]) {
      expect(
        () => LppCapitalNoticeAcquisitionCandidate(
          expectedSnapshotId: invalidSnapshotId,
        ),
        throwsArgumentError,
        reason: invalidSnapshotId,
      );
    }

    for (final invalidPreviousReferenceId in const <String>[
      '',
      'not-a-uuid',
      '22222222-2222-3222-8222-222222222222',
      '22222222-2222-4222-7222-222222222222',
      '22222222-2222-4222-8222-22222222222A',
    ]) {
      expect(
        () => LppCapitalNoticeAcquisitionCandidate(
          expectedSnapshotId: _snapshotId,
          expectedPreviousReferenceId: invalidPreviousReferenceId,
        ),
        throwsArgumentError,
        reason: invalidPreviousReferenceId,
      );
    }
  });
}
