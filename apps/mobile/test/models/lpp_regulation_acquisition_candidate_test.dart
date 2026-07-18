import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';

const _snapshotId = '11111111-1111-4111-8111-111111111111';
const _previousReferenceId = '22222222-2222-4222-8222-222222222222';

void main() {
  test('candidate retains only the exact local snapshot boundary', () {
    final candidate = LppRegulationAcquisitionCandidate(
      expectedSnapshotId: _snapshotId,
      expectedPreviousReferenceId: _previousReferenceId,
    );

    expect(candidate.expectedSnapshotId, _snapshotId);
    expect(candidate.expectedPreviousReferenceId, _previousReferenceId);
  });

  test('previous reference is optional', () {
    final candidate = LppRegulationAcquisitionCandidate(
      expectedSnapshotId: _snapshotId,
    );

    expect(candidate.expectedPreviousReferenceId, isNull);
  });

  test('candidate rejects non-canonical local identifiers', () {
    for (final invalidSnapshotId in <String>[
      '',
      'not-a-uuid',
      '11111111-1111-1111-8111-111111111111',
      '11111111-1111-4111-8111-11111111111A',
    ]) {
      expect(
        () => LppRegulationAcquisitionCandidate(
          expectedSnapshotId: invalidSnapshotId,
        ),
        throwsArgumentError,
        reason: invalidSnapshotId,
      );
    }

    expect(
      () => LppRegulationAcquisitionCandidate(
        expectedSnapshotId: _snapshotId,
        expectedPreviousReferenceId: 'not-a-uuid',
      ),
      throwsArgumentError,
    );
  });
}
