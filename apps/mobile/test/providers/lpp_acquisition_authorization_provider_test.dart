import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/partner_accountability.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/consent/partner_accountability_binding_store.dart';
import 'package:mint_mobile/services/consent/partner_accountability_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _TrackingProfilePersistence
    with SerializedCanonicalAnswerMutationPersistence
    implements TaxProfilePersistence, LppProfilePersistence {
  _TrackingProfilePersistence(this.answers);

  Map<String, dynamic> answers;
  int loadCalls = 0;
  int saveCalls = 0;
  Completer<void>? loadStarted;
  Future<void>? loadGate;

  @override
  Future<Map<String, dynamic>> loadAnswers() async {
    loadCalls += 1;
    loadStarted?.complete();
    final gate = loadGate;
    if (gate != null) await gate;
    return Map<String, dynamic>.from(answers);
  }

  @override
  Future<void> saveAnswers(Map<String, dynamic> next) async {
    saveCalls += 1;
    answers = Map<String, dynamic>.from(next);
  }

  void resetCalls() {
    loadCalls = 0;
    saveCalls = 0;
  }
}

final class _BindingPersistence
    implements PartnerAccountabilityBindingPersistence {
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

final class _StatusApi implements PartnerAccountabilityApi {
  @override
  Future<void> delete(String endpoint) async {}

  @override
  Future<Map<String, dynamic>> get(String endpoint) async => <String, dynamic>{
        'receiptId': _receiptId,
        'status': 'active',
        'noticeVersion': 'notice-v1',
        'policyVersion': 'policy-v1',
        'expiresAt': _expiresAt.toIso8601String(),
      };

  @override
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async =>
      throw StateError('post must not be called');
}

const _receiptId = '11111111-1111-4111-8111-111111111111';
const _ownerId = '22222222-2222-4222-8222-222222222222';
final _expiresAt = DateTime.utc(2027, 7, 15, 10);

const _facts = <LppEvidenceFactKey, LppReviewedFact>{
  LppEvidenceFactKey.vestedBenefitsCapitalChf: LppReviewedFact(
    value: 84000,
    unit: LppEvidenceUnit.chf,
    corrected: true,
  ),
};

LppAcquisitionAuthorization _authorization({
  required LppEvidenceOwnerKind subject,
  bool? partnerAttested,
  String acquisitionId = '123e4567-e89b-42d3-a456-426614174000',
  String documentSha256 =
      '3d1f57c984978ef98a18378c8166c1cb8ede02c03eeb6aee7e2f121dfeee3e56',
  String? manualPartnerOwnerId,
  String? receiptId,
}) =>
    LppAcquisitionAuthorization(
      acquisitionId: acquisitionId,
      subject: subject,
      partnerAttested:
          partnerAttested ?? subject == LppEvidenceOwnerKind.manualPartner,
      policyVersion: LppAcquisitionAuthorization.currentPolicyVersion,
      declaredAt: DateTime.utc(2026, 7, 15, 9),
      documentSha256: documentSha256,
      manualPartnerOwnerId: manualPartnerOwnerId,
      receiptId: receiptId,
    );

Future<
    ({
      CoachProfileProvider provider,
      _TrackingProfilePersistence persistence,
    })> _harness({
  required bool withLocalPartner,
  PartnerAccountabilityBindingStore? partnerBindingStore,
  PartnerAccountabilityService? partnerAccountabilityService,
}) async {
  final persistence = _TrackingProfilePersistence(<String, dynamic>{
    'q_birth_year': 1980,
    'q_canton': 'VD',
    'q_civil_status': withLocalPartner ? 'marie' : 'celibataire',
    if (withLocalPartner) 'q_partner_birth_year': 1982,
    if (withLocalPartner) 'q_partner_employment_status': 'salarie',
  });
  final provider = CoachProfileProvider(
    taxProfilePersistence: persistence,
    lppProfilePersistence: persistence,
    partnerAccountabilityBindingStore: partnerBindingStore,
    partnerAccountabilityService: partnerAccountabilityService,
    now: () => DateTime.utc(2026, 7, 15, 10),
  );
  await provider.loadFromWizard();
  expect(provider.profile?.conjoint != null, withLocalPartner);
  persistence.resetCalls();
  return (provider: provider, persistence: persistence);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.partnerLppAccountabilityEnabled = true;
  });
  tearDown(() {
    FeatureFlags.typedLppEvidence = false;
    FeatureFlags.partnerLppAccountabilityEnabled = false;
  });

  test('invalid manual-partner authorization rejects before load or publish',
      () async {
    final harness = await _harness(withLocalPartner: true);
    final provider = harness.provider;
    final persistence = harness.persistence;
    final beforeProfile = provider.profile;
    final beforeAnswers = provider.reportAnswersSnapshot;
    var notifications = 0;
    provider.addListener(() => notifications += 1);

    await expectLater(
      provider.acceptLppReview(
        LppReviewConfirmation(
          authorization: _authorization(
            subject: LppEvidenceOwnerKind.manualPartner,
            partnerAttested: false,
          ),
          sourceDate: null,
          facts: _facts,
        ),
      ),
      throwsStateError,
    );

    expect(persistence.loadCalls, 0);
    expect(persistence.saveCalls, 0);
    expect(notifications, 0);
    expect(identical(provider.profile, beforeProfile), isTrue);
    expect(provider.reportAnswersSnapshot, beforeAnswers);
  });

  test('manual partner still requires exactly a local conjoint profile',
      () async {
    final harness = await _harness(withLocalPartner: false);
    final provider = harness.provider;
    final persistence = harness.persistence;

    await expectLater(
      provider.acceptLppReview(
        LppReviewConfirmation(
          authorization: _authorization(
            subject: LppEvidenceOwnerKind.manualPartner,
          ),
          sourceDate: null,
          facts: _facts,
        ),
      ),
      throwsStateError,
    );

    expect(persistence.loadCalls, 0);
    expect(persistence.saveCalls, 0);
  });

  test('valid local partner persists no volatile authorization or hash',
      () async {
    final store = PartnerAccountabilityBindingStore(
      persistence: _BindingPersistence(),
    );
    await store.beginPending(
      receiptId: _receiptId,
      manualPartnerOwnerId: _ownerId,
      now: DateTime.utc(2026, 7, 15, 9),
      noticeVersion: 'notice-v1',
      policyVersion: 'policy-v1',
      privacyContact: 'privacy@example.test',
      rightsChannel: 'https://example.test/rights',
    );
    await store.markReceiptCreated(
      receiptId: _receiptId,
      manualPartnerOwnerId: _ownerId,
      now: DateTime.utc(2026, 7, 15, 9),
      expiresAt: _expiresAt,
    );
    final service = PartnerAccountabilityService(api: _StatusApi());
    final harness = await _harness(
      withLocalPartner: true,
      partnerBindingStore: store,
      partnerAccountabilityService: service,
    );
    final provider = harness.provider;
    final persistence = harness.persistence;
    final authorization = _authorization(
      subject: LppEvidenceOwnerKind.manualPartner,
      manualPartnerOwnerId: _ownerId,
      receiptId: _receiptId,
    );

    await provider.acceptLppReview(
      LppReviewConfirmation(
        authorization: authorization,
        sourceDate: null,
        facts: _facts,
        partnerAccountabilityContext: ManualPartnerAccountabilityContext(
          receiptId: _receiptId,
          ownerId: _ownerId,
          expiresAt: _expiresAt,
          noticeVersion: 'notice-v1',
          policyVersion: 'policy-v1',
          receiptStatus: PartnerAccountabilityReceiptStatus.active,
        ),
      ),
    );

    // Root write followed by exact activation CAS verification.
    expect(persistence.loadCalls, 2);
    expect(persistence.saveCalls, 1);
    final encoded = persistence.answers['_coach_lpp_evidence_v1'] as String;
    expect(encoded, isNot(contains(authorization.acquisitionId)));
    expect(encoded, isNot(contains(authorization.documentSha256)));
    expect(encoded, isNot(contains(authorization.policyVersion)));
    final root = jsonDecode(encoded) as Map<String, dynamic>;
    final manual = root['manualPartner'] as Map<String, dynamic>;
    final fact = (manual['facts'] as Map<String, dynamic>).values.single
        as Map<String, dynamic>;
    expect(
      fact['authorization'],
      {'mode': 'manualPartnerDeclaration', 'grantId': null},
    );
    expect(
      (fact['owner'] as Map)['profileOwnerId'],
      isNot((fact['actor'] as Map)['profileOwnerId']),
    );

    final cold = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      partnerAccountabilityBindingStore: store,
      partnerAccountabilityService: service,
      now: () => DateTime.utc(2026, 7, 15, 10),
    );
    await cold.loadFromWizard();
    expect(
      cold.profile?.conjoint?.prevoyance
          ?.lppEvidenceFact(
            LppEvidenceFactKey.vestedBenefitsCapitalChf,
          )
          ?.value,
      84000,
    );
  });

  test('facts cannot change after validation while persistence awaits',
      () async {
    final harness = await _harness(withLocalPartner: false);
    final provider = harness.provider;
    final persistence = harness.persistence;
    final loadStarted = Completer<void>();
    final releaseLoad = Completer<void>();
    persistence
      ..loadStarted = loadStarted
      ..loadGate = releaseLoad.future;
    final mutableFacts = <LppEvidenceFactKey, LppReviewedFact>{
      LppEvidenceFactKey.vestedBenefitsCapitalChf: const LppReviewedFact(
        value: 100,
        unit: LppEvidenceUnit.chf,
        corrected: true,
      ),
      LppEvidenceFactKey.mandatoryVestedBenefitsCapitalChf:
          const LppReviewedFact(
        value: 60,
        unit: LppEvidenceUnit.chf,
        corrected: true,
      ),
      LppEvidenceFactKey.extraMandatoryVestedBenefitsCapitalChf:
          const LppReviewedFact(
        value: 40,
        unit: LppEvidenceUnit.chf,
        corrected: true,
      ),
    };

    final write = provider.acceptLppReview(
      LppReviewConfirmation(
        authorization: _authorization(subject: LppEvidenceOwnerKind.self),
        sourceDate: null,
        facts: mutableFacts,
      ),
    );
    await loadStarted.future;
    mutableFacts[LppEvidenceFactKey.vestedBenefitsCapitalChf] =
        const LppReviewedFact(
      value: 1,
      unit: LppEvidenceUnit.chf,
      corrected: true,
    );
    releaseLoad.complete();
    await write;

    final snapshot = LppEvidenceSelector.selectSelf(
      persistence.answers['_coach_lpp_evidence_v1'],
    );
    expect(snapshot, isNotNull);
    expect(
      snapshot!.facts[LppEvidenceFactKey.vestedBenefitsCapitalChf]!.value,
      100,
    );
    expect(
      LppBalanceCoherence.isCoherent({
        for (final entry in snapshot.facts.entries)
          entry.key: entry.value.value,
      }),
      isTrue,
    );
  });
}
