import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/partner_accountability.dart';
import 'package:mint_mobile/services/feature_flags.dart';

const _ownerId = '22222222-2222-4222-8222-222222222222';
const _actorId = '11111111-1111-4111-8111-111111111111';

LppEvidenceFact _fact(
  double value,
  DateTime updatedAt, {
  LppEvidenceUnit unit = LppEvidenceUnit.chf,
}) =>
    LppEvidenceFact(
      value: value,
      unit: unit,
      profileOwnerId: _ownerId,
      actorProfileOwnerId: _actorId,
      ownerKind: LppEvidenceOwnerKind.manualPartner,
      authorizationMode: LppEvidenceAuthorizationMode.manualPartnerDeclaration,
      source: 'userInput',
      sourceDate: null,
      updatedAt: updatedAt,
    );

Map<String, dynamic> _answers(LppEvidenceSnapshot snapshot) => {
      'q_birth_year': 1980,
      'q_canton': 'VD',
      'q_civil_status': 'marie',
      'q_partner_birth_year': 1982,
      'q_partner_employment_status': 'salarie',
      '_coach_lpp_evidence_v1': LppEvidenceRoot(
        self: null,
        manualPartner: snapshot,
      ).toJsonString(),
    };

void main() {
  setUp(() => FeatureFlags.typedLppEvidence = true);
  tearDown(() => FeatureFlags.typedLppEvidence = false);

  test('receipt-bound review correction does not become independent', () {
    final snapshot = LppEvidenceSnapshot(
      snapshotId: '33333333-3333-4333-8333-333333333333',
      facts: {
        LppEvidenceFactKey.vestedBenefitsCapitalChf:
            _fact(90000, DateTime.utc(2026, 7, 15, 10)),
      },
    );

    final profile = CoachProfile.fromWizardAnswers(
      _answers(snapshot),
      now: () => DateTime.utc(2026, 7, 15, 11),
      enforcePartnerAccountability: true,
    );

    expect(profile.conjoint?.prevoyance?.avoirLppTotal, isNull);
  });

  test('invalid receipt restores only the prior independent same-key value',
      () {
    final snapshot = LppEvidenceSnapshot(
      snapshotId: '33333333-3333-4333-8333-333333333333',
      facts: {
        LppEvidenceFactKey.vestedBenefitsCapitalChf:
            _fact(90000, DateTime.utc(2026, 7, 15, 10)),
      },
      independentFacts: {
        LppEvidenceFactKey.vestedBenefitsCapitalChf:
            _fact(55000, DateTime.utc(2026, 7, 14, 10)),
      },
    );

    final decoded = LppEvidenceRoot.fromJsonString(
      LppEvidenceRoot(self: null, manualPartner: snapshot).toJsonString(),
    );
    final profile = CoachProfile.fromWizardAnswers(
      _answers(decoded!.manualPartner!),
      now: () => DateTime.utc(2026, 7, 15, 11),
      enforcePartnerAccountability: true,
    );

    expect(profile.conjoint?.prevoyance?.avoirLppTotal, 55000);
    expect(
      decoded.manualPartner!.independentFacts.values.single.updatedAt,
      DateTime.utc(2026, 7, 14, 10),
    );
  });

  test('active receipt overrides same key and keeps independent other keys',
      () {
    final snapshot = LppEvidenceSnapshot(
      snapshotId: '33333333-3333-4333-8333-333333333333',
      facts: {
        LppEvidenceFactKey.vestedBenefitsCapitalChf:
            _fact(90000, DateTime.utc(2026, 7, 15, 10)),
      },
      independentFacts: {
        LppEvidenceFactKey.vestedBenefitsCapitalChf:
            _fact(55000, DateTime.utc(2026, 7, 14, 10)),
        LppEvidenceFactKey.insuredSalaryAnnualChf: _fact(
          72000,
          DateTime.utc(2026, 7, 14, 10),
          unit: LppEvidenceUnit.chfPerYear,
        ),
      },
    );
    final binding = PartnerAccountabilityBinding(
      receiptId: '44444444-4444-4444-8444-444444444444',
      manualPartnerOwnerId: _ownerId,
      state: PartnerAccountabilityBindingState.active,
      createdAt: DateTime.utc(2026, 7, 15, 9),
      noticeVersion: 'notice-v1',
      policyVersion: 'policy-v1',
      privacyContact: 'privacy@example.test',
      rightsChannel: 'https://example.test/rights',
      lppSnapshotId: '33333333-3333-4333-8333-333333333333',
      lastVerifiedAt: DateTime.utc(2026, 7, 15, 10),
      receiptCreatedAt: DateTime.utc(2026, 7, 15, 9),
      expiresAt: DateTime.utc(2027, 7, 15, 10),
    );

    final profile = CoachProfile.fromWizardAnswers(
      _answers(snapshot),
      now: () => DateTime.utc(2026, 7, 15, 11),
      partnerAccountabilityBinding: binding,
      enforcePartnerAccountability: true,
    );

    expect(profile.conjoint?.prevoyance?.avoirLppTotal, 90000);
    expect(profile.conjoint?.prevoyance?.salaireAssure, 72000);
  });
}
