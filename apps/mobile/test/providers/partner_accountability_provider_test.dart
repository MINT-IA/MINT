import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/partner_accountability.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/consent/partner_accountability_binding_store.dart';
import 'package:mint_mobile/services/consent/partner_accountability_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _Persistence
    implements TaxProfilePersistence, LppProfilePersistence {
  Map<String, dynamic> answers = {
    'q_birth_year': 1980,
    'q_canton': 'VD',
    'q_civil_status': 'marie',
    'q_partner_birth_year': 1982,
    'q_partner_employment_status': 'salarie',
  };
  int loads = 0;
  int saves = 0;
  int? failOnSaveNumber;

  @override
  Future<Map<String, dynamic>> loadAnswers() async {
    loads += 1;
    return Map.of(answers);
  }

  @override
  Future<void> saveAnswers(Map<String, dynamic> answers) async {
    saves += 1;
    if (saves == failOnSaveNumber) {
      throw StateError('synthetic LPP root restore failure');
    }
    this.answers = Map.of(answers);
  }
}

final class _BindingPersistence
    implements PartnerAccountabilityBindingPersistence {
  String? value;
  int reads = 0;
  int writes = 0;
  final Map<int, _BindingWriteFailure> writeFailures = {};
  bool failDeletes = false;

  @override
  Future<void> delete() async {
    if (failDeletes) {
      throw StateError('synthetic secure binding delete failure');
    }
    value = null;
  }

  @override
  Future<String?> read() async {
    reads += 1;
    return value;
  }

  @override
  Future<void> write(String value) async {
    writes += 1;
    final failure = writeFailures.remove(writes);
    if (failure == _BindingWriteFailure.beforeWrite) {
      throw StateError('synthetic binding activation failure');
    }
    this.value = value;
    if (failure == _BindingWriteFailure.afterWrite) {
      throw StateError('synthetic binding uncertain activation failure');
    }
  }
}

enum _BindingWriteFailure { beforeWrite, afterWrite }

final class _UnusedApi implements PartnerAccountabilityApi {
  int statusCalls = 0;

  @override
  Future<void> delete(String endpoint) async {}

  @override
  Future<Map<String, dynamic>> get(String endpoint) async {
    statusCalls += 1;
    throw StateError('status must not be called');
  }

  @override
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async =>
      throw StateError('post must not be called');
}

final class _StatusApi implements PartnerAccountabilityApi {
  _StatusApi(this.response);

  final Map<String, dynamic> response;
  int statusCalls = 0;

  @override
  Future<void> delete(String endpoint) async {}

  @override
  Future<Map<String, dynamic>> get(String endpoint) async {
    statusCalls += 1;
    return Map.of(response);
  }

  @override
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async =>
      throw StateError('post must not be called');
}

const _receiptId = '11111111-1111-4111-8111-111111111111';
const _pendingReceiptId = '44444444-4444-4444-8444-444444444444';
const _ownerId = '22222222-2222-4222-8222-222222222222';
final _now = DateTime.utc(2026, 7, 15, 10);
final _expiresAt = DateTime.utc(2027, 7, 15, 10);

LppReviewConfirmation _confirmation({
  String noticeVersion = 'notice-v1',
  String receiptId = _receiptId,
  double value = 90000,
}) =>
    LppReviewConfirmation(
      facts: {
        LppEvidenceFactKey.vestedBenefitsCapitalChf: LppReviewedFact(
          value: value,
          unit: LppEvidenceUnit.chf,
        ),
      },
      sourceDate: DateTime.utc(2026, 6, 30),
      authorization: LppAcquisitionAuthorization(
        acquisitionId: '33333333-3333-4333-8333-333333333333',
        subject: LppEvidenceOwnerKind.manualPartner,
        partnerAttested: true,
        policyVersion: LppAcquisitionAuthorization.currentPolicyVersion,
        declaredAt: _now,
        documentSha256:
            '4d1f57c984978ef98a18378c8166c1cb8ede02c03eeb6aee7e2f121dfeee3e57',
        manualPartnerOwnerId: _ownerId,
        receiptId: receiptId,
      ),
      partnerAccountabilityContext: ManualPartnerAccountabilityContext(
        receiptId: receiptId,
        ownerId: _ownerId,
        expiresAt: _expiresAt,
        noticeVersion: noticeVersion,
        policyVersion: 'policy-v1',
        receiptStatus: PartnerAccountabilityReceiptStatus.active,
      ),
    );

Future<
    ({
      _Persistence root,
      _BindingPersistence secure,
      PartnerAccountabilityBindingStore store,
      CoachProfileProvider provider,
    })> _preparedReplacementAttempt() async {
  final root = _Persistence();
  final secure = _BindingPersistence();
  final store = PartnerAccountabilityBindingStore(persistence: secure);
  await store.beginPending(
    receiptId: _receiptId,
    manualPartnerOwnerId: _ownerId,
    now: _now,
    noticeVersion: 'notice-v1',
    policyVersion: 'policy-v1',
    privacyContact: 'privacy@example.test',
    rightsChannel: 'https://example.test/rights',
  );
  await store.markReceiptCreated(
    receiptId: _receiptId,
    manualPartnerOwnerId: _ownerId,
    now: _now,
    expiresAt: _expiresAt,
  );
  final provider = CoachProfileProvider(
    taxProfilePersistence: root,
    lppProfilePersistence: root,
    partnerAccountabilityBindingStore: store,
    partnerAccountabilityService: PartnerAccountabilityService(
      api: _UnusedApi(),
    ),
    now: () => _now.add(const Duration(minutes: 1)),
  );
  await provider.loadFromWizard();
  await provider.acceptLppReview(_confirmation());
  await store.beginPending(
    receiptId: _pendingReceiptId,
    manualPartnerOwnerId: _ownerId,
    now: _now.add(const Duration(minutes: 2)),
    noticeVersion: 'notice-v1',
    policyVersion: 'policy-v1',
    privacyContact: 'privacy@example.test',
    rightsChannel: 'https://example.test/rights',
  );
  await store.markReceiptCreated(
    receiptId: _pendingReceiptId,
    manualPartnerOwnerId: _ownerId,
    now: _now.add(const Duration(minutes: 2)),
    expiresAt: _expiresAt,
  );
  return (root: root, secure: secure, store: store, provider: provider);
}

Future<CoachProfileProvider> _coldProvider({
  required _Persistence root,
  required PartnerAccountabilityBindingStore store,
  required PartnerAccountabilityApi api,
}) async {
  final provider = CoachProfileProvider(
    taxProfilePersistence: root,
    lppProfilePersistence: root,
    partnerAccountabilityBindingStore: store,
    partnerAccountabilityService: PartnerAccountabilityService(api: api),
    now: () => _now.add(const Duration(minutes: 3)),
  );
  await provider.loadFromWizard();
  return provider;
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

  test('accept validates full volatile context against exact pending',
      () async {
    final persistence = _Persistence();
    final bindingPersistence = _BindingPersistence();
    final store = PartnerAccountabilityBindingStore(
      persistence: bindingPersistence,
    );
    await store.beginPending(
      receiptId: _receiptId,
      manualPartnerOwnerId: _ownerId,
      now: _now,
      noticeVersion: 'notice-v1',
      policyVersion: 'policy-v1',
      privacyContact: 'privacy@example.test',
      rightsChannel: 'https://example.test/rights',
    );
    await store.markReceiptCreated(
      receiptId: _receiptId,
      manualPartnerOwnerId: _ownerId,
      now: _now,
      expiresAt: _expiresAt,
    );
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      partnerAccountabilityBindingStore: store,
      partnerAccountabilityService: PartnerAccountabilityService(
        api: _UnusedApi(),
      ),
      now: () => _now.add(const Duration(minutes: 1)),
    );
    await provider.loadFromWizard();

    await provider.acceptLppReview(_confirmation());

    expect(
      (await store.load()).active?.state,
      PartnerAccountabilityBindingState.active,
    );
  });

  test(
      'activation failure restores the prior root and binding before cold load',
      () async {
    final persistence = _Persistence();
    final bindingPersistence = _BindingPersistence();
    final store = PartnerAccountabilityBindingStore(
      persistence: bindingPersistence,
    );
    await store.beginPending(
      receiptId: _receiptId,
      manualPartnerOwnerId: _ownerId,
      now: _now,
      noticeVersion: 'notice-v1',
      policyVersion: 'policy-v1',
      privacyContact: 'privacy@example.test',
      rightsChannel: 'https://example.test/rights',
    );
    await store.markReceiptCreated(
      receiptId: _receiptId,
      manualPartnerOwnerId: _ownerId,
      now: _now,
      expiresAt: _expiresAt,
    );
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      partnerAccountabilityBindingStore: store,
      partnerAccountabilityService: PartnerAccountabilityService(
        api: _UnusedApi(),
      ),
      now: () => _now.add(const Duration(minutes: 1)),
    );
    await provider.loadFromWizard();
    await provider.acceptLppReview(_confirmation());
    await store.beginPending(
      receiptId: _pendingReceiptId,
      manualPartnerOwnerId: _ownerId,
      now: _now.add(const Duration(minutes: 2)),
      noticeVersion: 'notice-v1',
      policyVersion: 'policy-v1',
      privacyContact: 'privacy@example.test',
      rightsChannel: 'https://example.test/rights',
    );
    await store.markReceiptCreated(
      receiptId: _pendingReceiptId,
      manualPartnerOwnerId: _ownerId,
      now: _now.add(const Duration(minutes: 2)),
      expiresAt: _expiresAt,
    );
    bindingPersistence.writeFailures[bindingPersistence.writes + 1] =
        _BindingWriteFailure.afterWrite;

    await expectLater(
      provider.acceptLppReview(
        _confirmation(receiptId: _pendingReceiptId, value: 150000),
      ),
      throwsStateError,
    );

    final restoredBinding = await store.load();
    expect(restoredBinding.pending, isNull);
    expect(restoredBinding.active?.receiptId, _receiptId);
    final restoredRoot = LppEvidenceRoot.fromJsonString(
      persistence.answers['_coach_lpp_evidence_v1'],
    )!;
    expect(
      restoredRoot.manualPartner
          ?.facts[LppEvidenceFactKey.vestedBenefitsCapitalChf]?.value,
      90000,
    );
    expect(provider.profile?.conjoint?.prevoyance?.avoirLppTotal, 90000);

    final api = _StatusApi({
      'receiptId': _receiptId,
      'status': 'active',
      'noticeVersion': 'notice-v1',
      'policyVersion': 'policy-v1',
      'expiresAt': _expiresAt.toIso8601String(),
    });
    final cold = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      partnerAccountabilityBindingStore: store,
      partnerAccountabilityService: PartnerAccountabilityService(api: api),
      now: () => _now.add(const Duration(minutes: 3)),
    );
    await cold.loadFromWizard();

    expect(api.statusCalls, 1);
    expect(cold.partnerLppAccountabilityBinding?.receiptId, _receiptId);
    expect(cold.profile?.conjoint?.prevoyance?.avoirLppTotal, 90000);
  });

  for (final deleteFails in <bool>[false, true]) {
    test(
        'uncertain activation plus failed binding compensation quarantines '
        'facts when delete ${deleteFails ? 'fails' : 'succeeds'}', () async {
      final attempt = await _preparedReplacementAttempt();
      attempt.secure.writeFailures[attempt.secure.writes + 1] =
          _BindingWriteFailure.afterWrite;
      attempt.secure.writeFailures[attempt.secure.writes + 2] =
          _BindingWriteFailure.beforeWrite;
      attempt.secure.failDeletes = deleteFails;

      await expectLater(
        attempt.provider.acceptLppReview(
          _confirmation(receiptId: _pendingReceiptId, value: 150000),
        ),
        throwsStateError,
      );

      final restoredRoot = LppEvidenceRoot.fromJsonString(
        attempt.root.answers['_coach_lpp_evidence_v1'],
      )!;
      expect(
        restoredRoot.manualPartner
            ?.facts[LppEvidenceFactKey.vestedBenefitsCapitalChf]?.value,
        90000,
      );
      expect((await attempt.store.load()).effective, isNull);

      final api = _StatusApi({
        'receiptId': _receiptId,
        'status': 'active',
        'noticeVersion': 'notice-v1',
        'policyVersion': 'policy-v1',
        'expiresAt': _expiresAt.toIso8601String(),
      });
      final cold = await _coldProvider(
        root: attempt.root,
        store: attempt.store,
        api: api,
      );

      expect(api.statusCalls, 0);
      expect(cold.partnerLppAccountabilityBinding, isNull);
      expect(cold.profile?.conjoint?.prevoyance?.avoirLppTotal, isNull);
    });
  }

  test('root restore failure removes the binding and cold load stays closed',
      () async {
    final persistence = _Persistence();
    final bindingPersistence = _BindingPersistence();
    final store = PartnerAccountabilityBindingStore(
      persistence: bindingPersistence,
    );
    await store.beginPending(
      receiptId: _receiptId,
      manualPartnerOwnerId: _ownerId,
      now: _now,
      noticeVersion: 'notice-v1',
      policyVersion: 'policy-v1',
      privacyContact: 'privacy@example.test',
      rightsChannel: 'https://example.test/rights',
    );
    await store.markReceiptCreated(
      receiptId: _receiptId,
      manualPartnerOwnerId: _ownerId,
      now: _now,
      expiresAt: _expiresAt,
    );
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      partnerAccountabilityBindingStore: store,
      partnerAccountabilityService: PartnerAccountabilityService(
        api: _UnusedApi(),
      ),
      now: () => _now.add(const Duration(minutes: 1)),
    );
    await provider.loadFromWizard();
    await provider.acceptLppReview(_confirmation());
    await store.beginPending(
      receiptId: _pendingReceiptId,
      manualPartnerOwnerId: _ownerId,
      now: _now.add(const Duration(minutes: 2)),
      noticeVersion: 'notice-v1',
      policyVersion: 'policy-v1',
      privacyContact: 'privacy@example.test',
      rightsChannel: 'https://example.test/rights',
    );
    await store.markReceiptCreated(
      receiptId: _pendingReceiptId,
      manualPartnerOwnerId: _ownerId,
      now: _now.add(const Duration(minutes: 2)),
      expiresAt: _expiresAt,
    );
    bindingPersistence.writeFailures[bindingPersistence.writes + 1] =
        _BindingWriteFailure.afterWrite;
    persistence.failOnSaveNumber = persistence.saves + 2;

    await expectLater(
      provider.acceptLppReview(
        _confirmation(receiptId: _pendingReceiptId, value: 150000),
      ),
      throwsStateError,
    );

    expect((await store.load()).effective, isNull);
    final api = _StatusApi({
      'receiptId': _receiptId,
      'status': 'active',
      'noticeVersion': 'notice-v1',
      'policyVersion': 'policy-v1',
      'expiresAt': _expiresAt.toIso8601String(),
    });
    final cold = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      partnerAccountabilityBindingStore: store,
      partnerAccountabilityService: PartnerAccountabilityService(api: api),
      now: () => _now.add(const Duration(minutes: 3)),
    );
    await cold.loadFromWizard();

    expect(api.statusCalls, 0);
    expect(cold.partnerLppAccountabilityBinding, isNull);
    expect(cold.profile?.conjoint?.prevoyance?.avoirLppTotal, isNull);
  });

  test('notice mismatch and flag flip reject before ledger save', () async {
    final persistence = _Persistence();
    final bindingPersistence = _BindingPersistence();
    final store = PartnerAccountabilityBindingStore(
      persistence: bindingPersistence,
    );
    await store.beginPending(
      receiptId: _receiptId,
      manualPartnerOwnerId: _ownerId,
      now: _now,
      noticeVersion: 'notice-v1',
      policyVersion: 'policy-v1',
      privacyContact: 'privacy@example.test',
      rightsChannel: 'https://example.test/rights',
    );
    await store.markReceiptCreated(
      receiptId: _receiptId,
      manualPartnerOwnerId: _ownerId,
      now: _now,
      expiresAt: _expiresAt,
    );
    final api = _UnusedApi();
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      partnerAccountabilityBindingStore: store,
      partnerAccountabilityService: PartnerAccountabilityService(api: api),
      now: () => _now.add(const Duration(minutes: 1)),
    );
    await provider.loadFromWizard();
    final savesBefore = persistence.saves;

    await expectLater(
      provider.acceptLppReview(_confirmation(noticeVersion: 'notice-v2')),
      throwsStateError,
    );
    FeatureFlags.partnerLppAccountabilityEnabled = false;
    await expectLater(
      provider.acceptLppReview(_confirmation()),
      throwsStateError,
    );

    expect(persistence.saves, savesBefore);
    expect(api.statusCalls, 0);
  });

  test('cold kill switch masks receipt facts without a status call', () async {
    final persistence = _Persistence();
    final store = PartnerAccountabilityBindingStore(
      persistence: _BindingPersistence(),
    );
    await store.beginPending(
      receiptId: _receiptId,
      manualPartnerOwnerId: _ownerId,
      now: _now,
      noticeVersion: 'notice-v1',
      policyVersion: 'policy-v1',
      privacyContact: 'privacy@example.test',
      rightsChannel: 'https://example.test/rights',
    );
    await store.markReceiptCreated(
      receiptId: _receiptId,
      manualPartnerOwnerId: _ownerId,
      now: _now,
      expiresAt: _expiresAt,
    );
    final writer = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      partnerAccountabilityBindingStore: store,
      partnerAccountabilityService: PartnerAccountabilityService(
        api: _UnusedApi(),
      ),
      now: () => _now.add(const Duration(minutes: 1)),
    );
    await writer.loadFromWizard();
    await writer.acceptLppReview(_confirmation());
    expect(writer.profile?.conjoint?.prevoyance?.avoirLppTotal, 90000);

    final api = _StatusApi({
      'receiptId': _receiptId,
      'status': 'active',
      'noticeVersion': 'notice-v1',
      'policyVersion': 'policy-v1',
      'expiresAt': _expiresAt.toIso8601String(),
    });
    FeatureFlags.partnerLppAccountabilityEnabled = false;
    final cold = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      partnerAccountabilityBindingStore: store,
      partnerAccountabilityService: PartnerAccountabilityService(api: api),
      now: () => _now.add(const Duration(minutes: 2)),
    );

    await cold.loadFromWizard();

    expect(api.statusCalls, 0);
    expect(cold.partnerLppAccountabilityBinding, isNull);
    expect(cold.profile?.conjoint?.prevoyance?.avoirLppTotal, isNull);
  });

  test('cold pending never auto-activates even if backend reports active',
      () async {
    final persistence = _Persistence();
    final store = PartnerAccountabilityBindingStore(
      persistence: _BindingPersistence(),
    );
    await store.beginPending(
      receiptId: _receiptId,
      manualPartnerOwnerId: _ownerId,
      now: _now,
      noticeVersion: 'notice-v1',
      policyVersion: 'policy-v1',
      privacyContact: 'privacy@example.test',
      rightsChannel: 'https://example.test/rights',
    );
    await store.markReceiptCreated(
      receiptId: _receiptId,
      manualPartnerOwnerId: _ownerId,
      now: _now,
      expiresAt: _expiresAt,
    );
    final writer = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      partnerAccountabilityBindingStore: store,
      partnerAccountabilityService: PartnerAccountabilityService(
        api: _UnusedApi(),
      ),
      now: () => _now.add(const Duration(minutes: 1)),
    );
    await writer.loadFromWizard();
    await writer.acceptLppReview(_confirmation());
    await store.beginPending(
      receiptId: _pendingReceiptId,
      manualPartnerOwnerId: _ownerId,
      now: _now.add(const Duration(minutes: 2)),
      noticeVersion: 'notice-v1',
      policyVersion: 'policy-v1',
      privacyContact: 'privacy@example.test',
      rightsChannel: 'https://example.test/rights',
    );
    await store.markReceiptCreated(
      receiptId: _pendingReceiptId,
      manualPartnerOwnerId: _ownerId,
      now: _now.add(const Duration(minutes: 2)),
      expiresAt: _expiresAt,
    );
    final api = _StatusApi({
      'receiptId': _pendingReceiptId,
      'status': 'active',
      'noticeVersion': 'notice-v1',
      'policyVersion': 'policy-v1',
      'expiresAt': _expiresAt.toIso8601String(),
    });
    final cold = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      partnerAccountabilityBindingStore: store,
      partnerAccountabilityService: PartnerAccountabilityService(api: api),
      now: () => _now.add(const Duration(minutes: 3)),
    );

    await cold.loadFromWizard();

    expect(api.statusCalls, 0);
    expect(
      cold.partnerLppAccountabilityState,
      PartnerAccountabilityBindingState.pending,
    );
    expect(cold.profile?.conjoint?.prevoyance?.avoirLppTotal, isNull);
  });

  test('cold active renders only after exact current status verification',
      () async {
    final persistence = _Persistence();
    final store = PartnerAccountabilityBindingStore(
      persistence: _BindingPersistence(),
    );
    await store.beginPending(
      receiptId: _receiptId,
      manualPartnerOwnerId: _ownerId,
      now: _now,
      noticeVersion: 'notice-v1',
      policyVersion: 'policy-v1',
      privacyContact: 'privacy@example.test',
      rightsChannel: 'https://example.test/rights',
    );
    await store.markReceiptCreated(
      receiptId: _receiptId,
      manualPartnerOwnerId: _ownerId,
      now: _now,
      expiresAt: _expiresAt,
    );
    final writer = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      partnerAccountabilityBindingStore: store,
      partnerAccountabilityService: PartnerAccountabilityService(
        api: _UnusedApi(),
      ),
      now: () => _now.add(const Duration(minutes: 1)),
    );
    await writer.loadFromWizard();
    await writer.acceptLppReview(_confirmation());
    final api = _StatusApi({
      'receiptId': _receiptId,
      'status': 'active',
      'noticeVersion': 'notice-v1',
      'policyVersion': 'policy-v1',
      'expiresAt': _expiresAt.toIso8601String(),
    });
    final cold = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      partnerAccountabilityBindingStore: store,
      partnerAccountabilityService: PartnerAccountabilityService(api: api),
      now: () => _now.add(const Duration(minutes: 2)),
    );

    await cold.loadFromWizard();

    expect(api.statusCalls, 1);
    expect(
      cold.partnerLppAccountabilityState,
      PartnerAccountabilityBindingState.active,
    );
    expect(cold.profile?.conjoint?.prevoyance?.avoirLppTotal, 90000);
  });

  test('failed privacy purge quarantines old receipt facts across cold load',
      () async {
    final persistence = _Persistence();
    final bindingPersistence = _BindingPersistence();
    final store = PartnerAccountabilityBindingStore(
      persistence: bindingPersistence,
    );
    await store.beginPending(
      receiptId: _receiptId,
      manualPartnerOwnerId: _ownerId,
      now: _now,
      noticeVersion: 'notice-v1',
      policyVersion: 'policy-v1',
      privacyContact: 'privacy@example.test',
      rightsChannel: 'https://example.test/rights',
    );
    await store.markReceiptCreated(
      receiptId: _receiptId,
      manualPartnerOwnerId: _ownerId,
      now: _now,
      expiresAt: _expiresAt,
    );
    final writer = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      partnerAccountabilityBindingStore: store,
      partnerAccountabilityService: PartnerAccountabilityService(
        api: _UnusedApi(),
      ),
      now: () => _now.add(const Duration(minutes: 1)),
    );
    await writer.loadFromWizard();
    await writer.acceptLppReview(_confirmation());
    bindingPersistence.failDeletes = true;

    try {
      await store.clear();
    } on Object {
      // The privacy boundary must remain closed even when secure deletion fails.
    }

    final api = _StatusApi({
      'receiptId': _receiptId,
      'status': 'active',
      'noticeVersion': 'notice-v1',
      'policyVersion': 'policy-v1',
      'expiresAt': _expiresAt.toIso8601String(),
    });
    final cold = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      partnerAccountabilityBindingStore: store,
      partnerAccountabilityService: PartnerAccountabilityService(api: api),
      now: () => _now.add(const Duration(minutes: 2)),
    );

    await cold.loadFromWizard();

    expect(api.statusCalls, 0);
    expect(cold.partnerLppAccountabilityBinding, isNull);
    expect(cold.profile?.conjoint?.prevoyance?.avoirLppTotal, isNull);
  });

  test('coach profile reset awaits its injected accountability purge',
      () async {
    final bindingPersistence = _BindingPersistence();
    final store = PartnerAccountabilityBindingStore(
      persistence: bindingPersistence,
    );
    await store.beginPending(
      receiptId: _receiptId,
      manualPartnerOwnerId: _ownerId,
      now: _now,
      noticeVersion: 'notice-v1',
      policyVersion: 'policy-v1',
      privacyContact: 'privacy@example.test',
      rightsChannel: 'https://example.test/rights',
    );
    final provider = CoachProfileProvider(
      taxProfilePersistence: _Persistence(),
      lppProfilePersistence: _Persistence(),
      partnerAccountabilityBindingStore: store,
      partnerAccountabilityService: PartnerAccountabilityService(
        api: _UnusedApi(),
      ),
      now: () => _now,
    );

    await provider.clear();

    expect((await store.load()).effective, isNull);
  });

  test('manual recovery stores one positive independent fact or unknown',
      () async {
    final persistence = _Persistence();
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      partnerAccountabilityBindingStore: PartnerAccountabilityBindingStore(
        persistence: _BindingPersistence(),
      ),
      partnerAccountabilityService: PartnerAccountabilityService(
        api: _UnusedApi(),
      ),
      now: () => _now,
    );
    await provider.loadFromWizard();

    await expectLater(
      provider.setIndependentManualPartnerVestedBenefitsCapital(0),
      throwsArgumentError,
    );
    await provider.setIndependentManualPartnerVestedBenefitsCapital(75000);
    expect(provider.profile?.conjoint?.prevoyance?.avoirLppTotal, 75000);
    var root = LppEvidenceRoot.fromJsonString(
      persistence.answers['_coach_lpp_evidence_v1'],
    )!;
    expect(root.manualPartner?.facts, isEmpty);
    expect(
      root
          .manualPartner
          ?.independentFacts[LppEvidenceFactKey.vestedBenefitsCapitalChf]
          ?.source,
      ProfileDataSource.userInput.name,
    );

    await provider.setIndependentManualPartnerVestedBenefitsCapital(null);

    expect(provider.profile?.conjoint?.prevoyance?.avoirLppTotal, isNull);
    root = LppEvidenceRoot.fromJsonString(
      persistence.answers['_coach_lpp_evidence_v1'],
    )!;
    expect(root.manualPartner, isNull);
  });
}
