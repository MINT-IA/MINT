import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';

void main() {
  const acquisitionId = '123e4567-e89b-42d3-a456-426614174000';
  final declaredAt = DateTime.utc(2026, 7, 15, 9);
  final now = DateTime.utc(2026, 7, 15, 10);

  LppAcquisitionAuthorization authorization({
    LppEvidenceOwnerKind subject = LppEvidenceOwnerKind.self,
    bool partnerAttested = false,
    String id = acquisitionId,
    String policyVersion = LppAcquisitionAuthorization.currentPolicyVersion,
    DateTime? at,
    String documentSha256 =
        '3d1f57c984978ef98a18378c8166c1cb8ede02c03eeb6aee7e2f121dfeee3e56',
  }) =>
      LppAcquisitionAuthorization(
        acquisitionId: id,
        subject: subject,
        partnerAttested: partnerAttested,
        policyVersion: policyVersion,
        declaredAt: at ?? declaredAt,
        documentSha256: documentSha256,
      );

  test('hashes the exact transmitted bytes to canonical lowercase SHA-256', () {
    expect(
      LppAcquisitionAuthorization.sha256Hex(
        Uint8List.fromList(const [0, 1, 2, 255]),
      ),
      '3d1f57c984978ef98a18378c8166c1cb8ede02c03eeb6aee7e2f121dfeee3e56',
    );
  });

  test('accepts self and attested manual-partner volatile contracts', () {
    expect(authorization().isValidAt(now), isTrue);
    expect(
      authorization(
        subject: LppEvidenceOwnerKind.manualPartner,
        partnerAttested: true,
      ).isValidAt(now),
      isTrue,
    );
  });

  test('fails closed on identity, attestation, policy, time or SHA drift', () {
    for (final invalid in <LppAcquisitionAuthorization>[
      authorization(
        subject: LppEvidenceOwnerKind.manualPartner,
        partnerAttested: false,
      ),
      authorization(partnerAttested: true),
      authorization(id: 'not-a-uuid'),
      authorization(policyVersion: 'legacy-policy'),
      authorization(at: DateTime.utc(2026, 7, 15, 10, 0, 1)),
      authorization(documentSha256: 'ABCDEF'),
      authorization(
        documentSha256:
            '0000000000000000000000000000000000000000000000000000000000000000',
      ),
    ]) {
      expect(invalid.isValidAt(now), isFalse, reason: invalid.toString());
    }
  });

  test('review confirmation derives its immutable subject from authorization',
      () {
    final partnerAuthorization = authorization(
      subject: LppEvidenceOwnerKind.manualPartner,
      partnerAttested: true,
    );
    final confirmation = LppReviewConfirmation(
      authorization: partnerAuthorization,
      sourceDate: null,
      facts: const {
        LppEvidenceFactKey.vestedBenefitsCapitalChf: LppReviewedFact(
          value: 100000,
          unit: LppEvidenceUnit.chf,
        ),
      },
    );

    expect(confirmation.authorization, same(partnerAuthorization));
    expect(confirmation.subject, LppEvidenceOwnerKind.manualPartner);
  });

  test('review confirmation defensively snapshots reviewed facts', () {
    final mutableFacts = <LppEvidenceFactKey, LppReviewedFact>{
      LppEvidenceFactKey.vestedBenefitsCapitalChf: const LppReviewedFact(
        value: 100000,
        unit: LppEvidenceUnit.chf,
      ),
    };
    final confirmation = LppReviewConfirmation(
      authorization: authorization(),
      sourceDate: null,
      facts: mutableFacts,
    );

    mutableFacts[LppEvidenceFactKey.vestedBenefitsCapitalChf] =
        const LppReviewedFact(
      value: 1,
      unit: LppEvidenceUnit.chf,
    );

    expect(
      confirmation.facts[LppEvidenceFactKey.vestedBenefitsCapitalChf]!.value,
      100000,
    );
    expect(
      () => confirmation.facts.clear(),
      throwsUnsupportedError,
    );
  });
}
