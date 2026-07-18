import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';

const _snapshotId = '11111111-1111-4111-8111-111111111111';
const _previousReferenceId = '22222222-2222-4222-8222-222222222222';

dynamic _createCandidate({String? expectedPreviousReferenceId}) =>
    Function.apply(
      LppRegulationAcquisitionCandidate.new,
      const <Object?>[],
      <Symbol, Object?>{
        if (expectedPreviousReferenceId != null)
          #expectedPreviousReferenceId: expectedPreviousReferenceId,
      },
    );

void main() {
  group('snapshotless LPP regulation acquisition candidate', () {
    test('retains only the canonical previous autonomous reference', () {
      dynamic candidate;
      expect(
        () => candidate = _createCandidate(
          expectedPreviousReferenceId: _previousReferenceId,
        ),
        returnsNormally,
        reason: 'A regulation-only journey has no numeric snapshot.',
      );

      expect(candidate.expectedPreviousReferenceId, _previousReferenceId);
    });

    test('previous autonomous reference is optional', () {
      dynamic candidate;
      expect(
        () => candidate = _createCandidate(),
        returnsNormally,
        reason: 'First acquisition must not invent a prior reference.',
      );

      expect(candidate.expectedPreviousReferenceId, isNull);
    });

    test('rejects non-canonical previous reference identifiers', () {
      for (final invalidReferenceId in <String>[
        '',
        'not-a-uuid',
        '22222222-2222-1222-8222-222222222222',
        '22222222-2222-4222-8222-22222222222A',
      ]) {
        expect(
          () => _createCandidate(
            expectedPreviousReferenceId: invalidReferenceId,
          ),
          throwsArgumentError,
          reason: invalidReferenceId,
        );
      }
    });

    test('the removed numeric snapshot argument is not admitted', () {
      expect(
        () => Function.apply(
          LppRegulationAcquisitionCandidate.new,
          const <Object?>[],
          <Symbol, Object?>{#expectedSnapshotId: _snapshotId},
        ),
        throwsA(isA<NoSuchMethodError>()),
      );
    });
  });
}
