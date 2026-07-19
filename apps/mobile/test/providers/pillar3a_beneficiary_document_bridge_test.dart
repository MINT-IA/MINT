import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/pillar3a_beneficiary_evidence.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/session_epoch.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _contractA = '11111111-1111-4111-8111-111111111111';
const _contractB = '22222222-2222-4222-8222-222222222222';
const _authorityA = '33333333-3333-4333-8333-333333333333';
const _authorityB = '44444444-4444-4444-8444-444444444444';
const _forgedAuthority = '55555555-5555-4555-8555-555555555555';
const _referenceA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _referenceB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

final class _MemoryLppPersistence
    with SerializedCanonicalAnswerMutationPersistence
    implements LppProfilePersistence, TaxProfilePersistence {
  Map<String, dynamic> answers = <String, dynamic>{
    'q_birth_year': 1980,
    'q_canton': 'VD',
  };

  @override
  Future<Map<String, dynamic>> loadAnswers() async => _copy(answers);

  @override
  Future<void> saveAnswers(Map<String, dynamic> next) async {
    answers = _copy(next);
  }

  static Map<String, dynamic> _copy(Map<String, dynamic> value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
}

final class _MemoryReferenceStore extends DocumentReferenceStore {
  _MemoryReferenceStore({
    List<ConfirmedDocumentReference> initial = const [],
    this.failNextSave = false,
  }) : references = List<ConfirmedDocumentReference>.of(initial);

  List<ConfirmedDocumentReference> references;
  bool failNextSave;
  int loadCalls = 0;
  int saveCalls = 0;
  Completer<void>? saveGate;

  @override
  Future<List<ConfirmedDocumentReference>> load() async {
    loadCalls += 1;
    return List<ConfirmedDocumentReference>.unmodifiable(references);
  }

  @override
  Future<void> save(List<ConfirmedDocumentReference> next) async {
    saveCalls += 1;
    final gate = saveGate;
    if (gate != null) await gate.future;
    if (failNextSave) {
      failNextSave = false;
      throw StateError('synthetic pillar 3a BND save failure');
    }
    references = List<ConfirmedDocumentReference>.of(next);
  }
}

Pillar3aBeneficiaryReviewConfirmation _confirmation({
  String contractReferenceId = _contractA,
  String referenceId = _referenceA,
  String documentAuthorityId = _authorityA,
  String? expectedPreviousReferenceId,
  DateTime? lastAssignmentModificationDate,
}) =>
    Pillar3aBeneficiaryReviewConfirmation.exactDates(
      contractReferenceId: contractReferenceId,
      referenceId: referenceId,
      documentAuthorityId: documentAuthorityId,
      documentKind:
          Pillar3aBeneficiaryAuthorityDocumentKind.confirmationInstitutionnelle,
      relation: Pillar3aBeneficiaryRelation.currentActiveUnpaid,
      sourceDate: DateTime.utc(2026, 7, 18),
      legalYear: 2026,
      designationEffectiveDate: DateTime.utc(2026, 1, 15),
      lastAssignmentModificationDate: lastAssignmentModificationDate,
      expectedPreviousReferenceId: expectedPreviousReferenceId,
    );

Future<
    ({
      CoachProfileProvider ledger,
      _MemoryLppPersistence persistence,
      Pillar3aBeneficiaryReceipt receipt,
    })> _accepted({
  String contractReferenceId = _contractA,
  String documentAuthorityId = _authorityA,
}) async {
  final persistence = _MemoryLppPersistence();
  final ledger = CoachProfileProvider(
    taxProfilePersistence: persistence,
    lppProfilePersistence: persistence,
    now: () => DateTime.utc(2026, 7, 19, 10),
  );
  await ledger.loadFromWizard();
  final preallocator = DocumentProvider();
  final referenceId = preallocator.preallocatePillar3aBeneficiaryReferenceId(
    contractReferenceId: contractReferenceId,
    documentAuthorityId: documentAuthorityId,
  );
  preallocator.dispose();
  final receipt = await ledger.acceptPillar3aBeneficiaryReview(
    _confirmation(
      contractReferenceId: contractReferenceId,
      referenceId: referenceId,
      documentAuthorityId: documentAuthorityId,
    ),
  );
  return (ledger: ledger, persistence: persistence, receipt: receipt);
}

Pillar3aBeneficiaryReceipt _forgedReceipt(
  Pillar3aBeneficiaryReceipt receipt, {
  String? documentAuthorityId,
}) =>
    Pillar3aBeneficiaryReceipt(
      referenceId: receipt.referenceId,
      contractReferenceId: receipt.contractReferenceId,
      documentAuthorityId: documentAuthorityId ?? receipt.documentAuthorityId,
      relationConfirmedAt: receipt.relationConfirmedAt,
    );

ConfirmedDocumentReference _opaqueOther({
  required String referenceId,
  required String snapshotId,
}) =>
    ConfirmedDocumentReference(
      referenceId: referenceId,
      kind: ConfirmedDocumentReference.lppKind,
      snapshotId: snapshotId,
      ownerKind: LppEvidenceOwnerKind.self,
      confirmedAt: DateTime.utc(2026, 7, 18, 9),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = true;
  });

  tearDown(() {
    FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = false;
    FeatureFlags.typedLppEvidence = false;
  });

  test('DocumentProvider preallocates a distinct reference before any writer',
      () {
    final documents = DocumentProvider();
    addTearDown(documents.dispose);

    final referenceId = documents.preallocatePillar3aBeneficiaryReferenceId(
      contractReferenceId: _contractA,
      documentAuthorityId: _authorityA,
    );

    expect(
        referenceId,
        matches(RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        )));
    expect(referenceId, isNot(anyOf(_contractA, _authorityA)));
    FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = false;
    expect(
      () => documents.preallocatePillar3aBeneficiaryReferenceId(
        contractReferenceId: _contractA,
        documentAuthorityId: _authorityA,
      ),
      throwsStateError,
    );
  });

  test('pillar 3a BND is exact contract-bound physical metadata', () {
    final encoded = <String, dynamic>{
      'referenceId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'kind': Pillar3aBeneficiaryEvidence.kind,
      'contractReferenceId': _contractA,
      'documentAuthorityId': _authorityA,
      'ownerKind': 'self',
      'confirmedAt': '2026-07-19T10:00:00.000Z',
    };

    final reference = ConfirmedDocumentReference.fromJson(encoded);

    expect(reference, isNotNull);
    expect(reference!.toJson(), encoded);
    expect(reference.snapshotId, isNull);
    expect(reference.contractReferenceId, _contractA);
    expect(reference.documentAuthorityId, _authorityA);
    expect(
      ConfirmedDocumentReference.fromJson(
        <String, dynamic>{...encoded, 'snapshotId': _contractA},
      ),
      isNull,
    );
    for (final invalid in <Map<String, dynamic>>[
      <String, dynamic>{...encoded}..remove('contractReferenceId'),
      <String, dynamic>{...encoded, 'contractReferenceId': ''},
      <String, dynamic>{...encoded, 'documentAuthorityId': ''},
      <String, dynamic>{
        ...encoded,
        'documentAuthorityId': encoded['referenceId'],
      },
      <String, dynamic>{...encoded, 'kind': 'pillar_3a_attestation'},
    ]) {
      expect(ConfirmedDocumentReference.fromJson(invalid), isNull);
    }
    expect(
      () => Pillar3aBeneficiaryReceipt(
        referenceId: encoded['referenceId'] as String,
        contractReferenceId: _contractA,
        documentAuthorityId: encoded['referenceId'] as String,
        relationConfirmedAt: DateTime.utc(2026, 7, 19, 10),
      ),
      throwsArgumentError,
    );
  });

  test('store supports 32 kind-owner-contract bindings and rejects duplicates',
      () async {
    final references = <ConfirmedDocumentReference>[
      for (var index = 0; index < 32; index++)
        ConfirmedDocumentReference(
          referenceId:
              '10000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
          kind: Pillar3aBeneficiaryEvidence.kind,
          contractReferenceId:
              '20000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
          documentAuthorityId:
              '30000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
          ownerKind: LppEvidenceOwnerKind.self,
          confirmedAt: DateTime.utc(2026, 7, 19, 10),
        ),
    ];
    final store = DocumentReferenceStore();

    await store.save(references);
    final cold = await store.load();

    expect(cold, hasLength(32));
    expect(
      cold.map((item) => item.contractReferenceId).toSet(),
      hasLength(32),
    );
    await expectLater(
      store.save(<ConfirmedDocumentReference>[
        ...references,
        ConfirmedDocumentReference(
          referenceId: 'ffffffff-ffff-4fff-8fff-ffffffffffff',
          kind: Pillar3aBeneficiaryEvidence.kind,
          contractReferenceId: references.first.contractReferenceId,
          documentAuthorityId: _forgedAuthority,
          ownerKind: LppEvidenceOwnerKind.self,
          confirmedAt: DateTime.utc(2026, 7, 19, 10),
        ),
      ]),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      store.save(<ConfirmedDocumentReference>[
        ...references,
        ConfirmedDocumentReference(
          referenceId: '10000000-0000-4000-8000-000000000032',
          kind: Pillar3aBeneficiaryEvidence.kind,
          contractReferenceId: '20000000-0000-4000-8000-000000000032',
          documentAuthorityId: '30000000-0000-4000-8000-000000000032',
          ownerKind: LppEvidenceOwnerKind.self,
          confirmedAt: DateTime.utc(2026, 7, 19, 10),
        ),
      ]),
      throwsA(isA<FormatException>()),
      reason: 'A unique 33rd 3a contract must hit the abuse cap, not a dedupe.',
    );
  });

  test('record rejects missing ledger, flag-off, and forged authority',
      () async {
    final accepted = await _accepted();
    addTearDown(accepted.ledger.dispose);
    final store = _MemoryReferenceStore();
    final documents = DocumentProvider(referenceStore: store);
    addTearDown(documents.dispose);

    await expectLater(
      documents.recordPillar3aBeneficiaryEvidence(accepted.receipt),
      throwsStateError,
    );
    documents.bindLedger(accepted.ledger);
    FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = false;
    await expectLater(
      documents.recordPillar3aBeneficiaryEvidence(accepted.receipt),
      throwsStateError,
    );
    FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = true;
    await expectLater(
      documents.recordPillar3aBeneficiaryEvidence(
        _forgedReceipt(
          accepted.receipt,
          documentAuthorityId: _forgedAuthority,
        ),
      ),
      throwsStateError,
    );

    expect(store.loadCalls, 0);
    expect(store.saveCalls, 0);
  });

  test('record reuses ledger identity and saves before BND publication',
      () async {
    final accepted = await _accepted();
    addTearDown(accepted.ledger.dispose);
    final store = _MemoryReferenceStore()..saveGate = Completer<void>();
    final documents = DocumentProvider(referenceStore: store);
    addTearDown(documents.dispose);
    documents.bindLedger(accepted.ledger);
    await documents.hydrateReferences();
    var notifications = 0;
    documents.addListener(() => notifications += 1);

    final pending =
        documents.recordPillar3aBeneficiaryEvidence(accepted.receipt);
    while (store.saveCalls == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(
      documents.hasStoredReference(accepted.receipt.referenceId),
      isFalse,
    );
    store.saveGate!.complete();
    store.saveGate = null;
    final reference = await pending;
    final retry =
        await documents.recordPillar3aBeneficiaryEvidence(accepted.receipt);

    expect(reference.referenceId, accepted.receipt.referenceId);
    expect(reference.contractReferenceId, _contractA);
    expect(reference.documentAuthorityId, _authorityA);
    expect(reference.kind, Pillar3aBeneficiaryEvidence.kind);
    expect(reference.snapshotId, isNull);
    expect(retry.toJson(), reference.toJson());
    expect(store.saveCalls, 1);
    expect(store.references, hasLength(1));
    expect(notifications, 1);
  });

  test('newly preallocated revision replaces only its exact contract binding',
      () async {
    final accepted = await _accepted();
    addTearDown(accepted.ledger.dispose);
    final store = _MemoryReferenceStore();
    final documents = DocumentProvider(referenceStore: store);
    addTearDown(documents.dispose);
    documents.bindLedger(accepted.ledger);
    await documents.recordPillar3aBeneficiaryEvidence(accepted.receipt);

    final replacementReferenceId =
        documents.preallocatePillar3aBeneficiaryReferenceId(
      contractReferenceId: _contractA,
      documentAuthorityId: _authorityB,
    );
    final refreshed = await accepted.ledger.acceptPillar3aBeneficiaryReview(
      _confirmation(
        referenceId: replacementReferenceId,
        documentAuthorityId: _authorityB,
        expectedPreviousReferenceId: accepted.receipt.referenceId,
      ),
    );
    final replacement =
        await documents.recordPillar3aBeneficiaryEvidence(refreshed);

    expect(refreshed.referenceId, replacementReferenceId);
    expect(refreshed.documentAuthorityId, _authorityB);
    expect(replacement.referenceId, replacementReferenceId);
    expect(replacement.documentAuthorityId, _authorityB);
    expect(store.references, hasLength(1));
    expect(store.references.single.contractReferenceId, _contractA);
    expect(store.references.single.documentAuthorityId, _authorityB);
    expect(store.saveCalls, 2);
  });

  test('BND failure keeps ledger committed and retry repairs metadata',
      () async {
    final accepted = await _accepted();
    addTearDown(accepted.ledger.dispose);
    final store = _MemoryReferenceStore(failNextSave: true);
    final documents = DocumentProvider(referenceStore: store);
    addTearDown(documents.dispose);
    documents.bindLedger(accepted.ledger);

    await expectLater(
      documents.recordPillar3aBeneficiaryEvidence(accepted.receipt),
      throwsStateError,
    );
    expect(
      accepted.ledger.currentPillar3aBeneficiaryEvidence?.contracts,
      hasLength(1),
    );
    expect(documents.hasStoredReference(accepted.receipt.referenceId), isFalse);

    final repaired =
        await documents.recordPillar3aBeneficiaryEvidence(accepted.receipt);
    expect(repaired.referenceId, accepted.receipt.referenceId);
    expect(store.saveCalls, 2);
  });

  test('replacement removes only the prior binding for the exact contract',
      () async {
    final accepted = await _accepted();
    addTearDown(accepted.ledger.dispose);
    final store = _MemoryReferenceStore(initial: <ConfirmedDocumentReference>[
      _opaqueOther(
        referenceId: '66666666-6666-4666-8666-666666666666',
        snapshotId: '77777777-7777-4777-8777-777777777777',
      ),
    ]);
    final documents = DocumentProvider(referenceStore: store);
    addTearDown(documents.dispose);
    documents.bindLedger(accepted.ledger);
    await documents.recordPillar3aBeneficiaryEvidence(accepted.receipt);
    final secondReferenceId =
        documents.preallocatePillar3aBeneficiaryReferenceId(
      contractReferenceId: _contractB,
      documentAuthorityId: _authorityB,
    );
    final second = await accepted.ledger.acceptPillar3aBeneficiaryReview(
      _confirmation(
        contractReferenceId: _contractB,
        referenceId: secondReferenceId,
        documentAuthorityId: _authorityB,
      ),
    );
    await documents.recordPillar3aBeneficiaryEvidence(second);

    final replacementReferenceId =
        documents.preallocatePillar3aBeneficiaryReferenceId(
      contractReferenceId: _contractA,
      documentAuthorityId: _forgedAuthority,
    );
    final replacement = await accepted.ledger.acceptPillar3aBeneficiaryReview(
      _confirmation(
        referenceId: replacementReferenceId,
        documentAuthorityId: _forgedAuthority,
        lastAssignmentModificationDate: DateTime.utc(2026, 6, 1),
        expectedPreviousReferenceId: accepted.receipt.referenceId,
      ),
    );
    await documents.recordPillar3aBeneficiaryEvidence(replacement);

    expect(store.references, hasLength(3));
    expect(
      store.references
          .where((item) => item.kind == Pillar3aBeneficiaryEvidence.kind)
          .map((item) => item.contractReferenceId),
      <String>[_contractA, _contractB],
    );
    expect(
      store.references.any(
        (item) => item.referenceId == accepted.receipt.referenceId,
      ),
      isFalse,
    );
  });

  test('resolver is unavailable until flag, ledger, and BND hydration align',
      () async {
    final accepted = await _accepted();
    addTearDown(accepted.ledger.dispose);
    final evidence =
        accepted.ledger.currentPillar3aBeneficiaryEvidence!.contracts.single;
    final store = _MemoryReferenceStore(initial: <ConfirmedDocumentReference>[
      ConfirmedDocumentReference(
        referenceId: accepted.receipt.referenceId,
        kind: Pillar3aBeneficiaryEvidence.kind,
        contractReferenceId: accepted.receipt.contractReferenceId,
        documentAuthorityId: accepted.receipt.documentAuthorityId,
        ownerKind: LppEvidenceOwnerKind.self,
        confirmedAt: accepted.receipt.relationConfirmedAt,
      ),
    ]);
    final documents = DocumentProvider(referenceStore: store);
    addTearDown(documents.dispose);

    expect(
      documents.resolvePillar3aBeneficiaryReference(evidence),
      Pillar3aBeneficiaryReferenceResolution.unavailable,
    );
    documents.bindLedger(accepted.ledger);
    expect(
      documents.resolvePillar3aBeneficiaryReference(evidence),
      Pillar3aBeneficiaryReferenceResolution.unavailable,
    );
    await documents.hydrateReferences();
    expect(
      documents.resolvePillar3aBeneficiaryReference(evidence),
      Pillar3aBeneficiaryReferenceResolution.resolved,
    );

    FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = false;
    expect(
      documents.resolvePillar3aBeneficiaryReference(evidence),
      Pillar3aBeneficiaryReferenceResolution.unavailable,
    );
  });

  test('resolver distinguishes missing BND from mismatched physical authority',
      () async {
    final accepted = await _accepted();
    addTearDown(accepted.ledger.dispose);
    final evidence =
        accepted.ledger.currentPillar3aBeneficiaryEvidence!.contracts.single;

    final missing = DocumentProvider(referenceStore: _MemoryReferenceStore());
    addTearDown(missing.dispose);
    missing.bindLedger(accepted.ledger);
    await missing.hydrateReferences();
    expect(
      missing.resolvePillar3aBeneficiaryReference(evidence),
      Pillar3aBeneficiaryReferenceResolution.missingDocumentReference,
    );

    final exactTuple = ConfirmedDocumentReference(
      referenceId: evidence.referenceId,
      kind: Pillar3aBeneficiaryEvidence.kind,
      contractReferenceId: evidence.contractReferenceId,
      documentAuthorityId: evidence.documentAuthorityId,
      ownerKind: LppEvidenceOwnerKind.self,
      confirmedAt: evidence.relationConfirmedAt,
    );
    for (final mismatch
        in <({String name, ConfirmedDocumentReference reference})>[
      (
        name: 'kind',
        reference: ConfirmedDocumentReference(
          referenceId: exactTuple.referenceId,
          kind: ConfirmedDocumentReference.lppKind,
          contractReferenceId: exactTuple.contractReferenceId,
          documentAuthorityId: exactTuple.documentAuthorityId,
          ownerKind: exactTuple.ownerKind,
          confirmedAt: exactTuple.confirmedAt,
        ),
      ),
      (
        name: 'referenceId',
        reference: ConfirmedDocumentReference(
          referenceId: _referenceB,
          kind: exactTuple.kind,
          contractReferenceId: exactTuple.contractReferenceId,
          documentAuthorityId: exactTuple.documentAuthorityId,
          ownerKind: exactTuple.ownerKind,
          confirmedAt: exactTuple.confirmedAt,
        ),
      ),
      (
        name: 'contractReferenceId',
        reference: ConfirmedDocumentReference(
          referenceId: exactTuple.referenceId,
          kind: exactTuple.kind,
          contractReferenceId: _contractB,
          documentAuthorityId: exactTuple.documentAuthorityId,
          ownerKind: exactTuple.ownerKind,
          confirmedAt: exactTuple.confirmedAt,
        ),
      ),
      (
        name: 'documentAuthorityId',
        reference: ConfirmedDocumentReference(
          referenceId: exactTuple.referenceId,
          kind: exactTuple.kind,
          contractReferenceId: exactTuple.contractReferenceId,
          documentAuthorityId: _authorityB,
          ownerKind: exactTuple.ownerKind,
          confirmedAt: exactTuple.confirmedAt,
        ),
      ),
      (
        name: 'ownerKind',
        reference: ConfirmedDocumentReference(
          referenceId: exactTuple.referenceId,
          kind: exactTuple.kind,
          contractReferenceId: exactTuple.contractReferenceId,
          documentAuthorityId: exactTuple.documentAuthorityId,
          ownerKind: LppEvidenceOwnerKind.manualPartner,
          confirmedAt: exactTuple.confirmedAt,
        ),
      ),
      (
        name: 'confirmedAt',
        reference: ConfirmedDocumentReference(
          referenceId: exactTuple.referenceId,
          kind: exactTuple.kind,
          contractReferenceId: exactTuple.contractReferenceId,
          documentAuthorityId: exactTuple.documentAuthorityId,
          ownerKind: exactTuple.ownerKind,
          confirmedAt: exactTuple.confirmedAt.add(const Duration(seconds: 1)),
        ),
      ),
    ]) {
      final mismatched = DocumentProvider(
        referenceStore: _MemoryReferenceStore(
          initial: <ConfirmedDocumentReference>[mismatch.reference],
        ),
      );
      addTearDown(mismatched.dispose);
      mismatched.bindLedger(accepted.ledger);
      await mismatched.hydrateReferences();
      expect(
        mismatched.resolvePillar3aBeneficiaryReference(evidence),
        Pillar3aBeneficiaryReferenceResolution.mismatchedDocumentReference,
        reason: mismatch.name,
      );
    }
  });

  test('cold hydration resolves exact ledger and physical binding together',
      () async {
    final accepted = await _accepted();
    final store = _MemoryReferenceStore();
    final writer = DocumentProvider(referenceStore: store);
    writer.bindLedger(accepted.ledger);
    await writer.recordPillar3aBeneficiaryEvidence(accepted.receipt);
    writer.dispose();
    accepted.ledger.dispose();

    final coldLedger = CoachProfileProvider(
      taxProfilePersistence: accepted.persistence,
      lppProfilePersistence: accepted.persistence,
      now: () => DateTime.utc(2026, 7, 19, 10),
    );
    final coldDocuments = DocumentProvider(referenceStore: store);
    addTearDown(coldLedger.dispose);
    addTearDown(coldDocuments.dispose);
    await coldLedger.loadFromWizard();
    coldDocuments.bindLedger(coldLedger);
    await coldDocuments.hydrateReferences();

    expect(coldDocuments.currentReferences, hasLength(1));
    expect(
      coldDocuments.byId(accepted.receipt.referenceId)?.documentAuthorityId,
      _authorityA,
    );
    final evidence =
        coldLedger.currentPillar3aBeneficiaryEvidence!.contracts.single;
    expect(
      coldDocuments.resolvePillar3aBeneficiaryReference(evidence),
      Pillar3aBeneficiaryReferenceResolution.resolved,
    );
  });

  test('session invalidation during BND save cannot publish old metadata',
      () async {
    final accepted = await _accepted();
    addTearDown(accepted.ledger.dispose);
    final epoch = SessionEpoch();
    final store = _MemoryReferenceStore()..saveGate = Completer<void>();
    final documents = DocumentProvider(
      referenceStore: store,
      sessionEpoch: epoch,
    );
    addTearDown(documents.dispose);
    documents.bindLedger(accepted.ledger);

    final pending =
        documents.recordPillar3aBeneficiaryEvidence(accepted.receipt);
    while (store.saveCalls == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    epoch.beginTermination();
    store.saveGate!.complete();
    store.saveGate = null;

    await expectLater(pending, throwsA(isA<SessionEpochInvalidated>()));
    expect(store.references, hasLength(1));
    expect(documents.currentReferences, isEmpty);
    epoch.completeTermination();
  });
}
