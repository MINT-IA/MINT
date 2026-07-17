import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _snapshotId = '11111111-1111-4111-8111-111111111111';
const _ownerId = '22222222-2222-4222-8222-222222222222';
const _genericReferenceId = '33333333-3333-4333-8333-333333333333';
const _forgedReferenceId = '44444444-4444-4444-8444-444444444444';

final class _MemoryLppPersistence
    with SerializedCanonicalAnswerMutationPersistence
    implements LppProfilePersistence, TaxProfilePersistence {
  _MemoryLppPersistence(Map<String, dynamic> initial)
      : answers = _copy(initial);

  Map<String, dynamic> answers;

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
    this.failLoad = false,
  }) : references = List<ConfirmedDocumentReference>.of(initial);

  List<ConfirmedDocumentReference> references;
  bool failLoad;
  int loadCalls = 0;
  int saveCalls = 0;

  @override
  Future<List<ConfirmedDocumentReference>> load() async {
    loadCalls += 1;
    if (failLoad) throw StateError('synthetic reference hydration failure');
    return List<ConfirmedDocumentReference>.unmodifiable(references);
  }

  @override
  Future<void> save(List<ConfirmedDocumentReference> next) async {
    saveCalls += 1;
    references = List<ConfirmedDocumentReference>.of(next);
  }
}

Map<String, dynamic> _answers(DateTime now) => <String, dynamic>{
      'q_birth_year': 1981,
      'q_canton': 'VD',
      'q_civil_status': 'celibataire',
      'q_has_pension_fund': 'yes',
      '_coach_lpp_evidence_v1': jsonEncode(<String, dynamic>{
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
                'source': 'certificate',
                'sourceDate': '2026-01-31',
                'updatedAt': now
                    .subtract(const Duration(days: 1))
                    .toUtc()
                    .toIso8601String(),
              },
            },
          },
        },
        'manualPartner': null,
        'legacyPartnerQuarantine': null,
      }),
    };

LppCapitalNoticeReviewConfirmation _confirmation({
  DateTime? deadlineDate,
  String? expectedPreviousReferenceId,
}) =>
    LppCapitalNoticeReviewConfirmation(
      ownerKind: LppEvidenceOwnerKind.self,
      sourceDate: DateTime.utc(2026, 2, 3),
      legalYear: 2026,
      deadlineDate: deadlineDate ?? DateTime.utc(2026, 9, 30),
      expectedSnapshotId: _snapshotId,
      expectedPreviousReferenceId: expectedPreviousReferenceId,
    );

Future<
    ({
      CoachProfileProvider ledger,
      _MemoryLppPersistence persistence,
      LppCapitalNoticeReceipt receipt,
    })> _acceptedNotice(DateTime now) async {
  final persistence = _MemoryLppPersistence(_answers(now));
  final ledger = CoachProfileProvider(
    taxProfilePersistence: persistence,
    lppProfilePersistence: persistence,
    now: () => now,
  );
  await ledger.loadFromWizard();
  final receipt = await ledger.acceptLppCapitalNotice(_confirmation());
  return (ledger: ledger, persistence: persistence, receipt: receipt);
}

ConfirmedDocumentReference _genericReference(DateTime now) =>
    ConfirmedDocumentReference(
      referenceId: _genericReferenceId,
      kind: ConfirmedDocumentReference.lppKind,
      snapshotId: _snapshotId,
      ownerKind: LppEvidenceOwnerKind.self,
      confirmedAt: now.subtract(const Duration(minutes: 5)),
    );

LppReviewConfirmation _replacementReview(DateTime now) => LppReviewConfirmation(
      authorization: LppAcquisitionAuthorization(
        acquisitionId: '55555555-5555-4555-8555-555555555555',
        subject: LppEvidenceOwnerKind.self,
        partnerAttested: false,
        policyVersion: LppAcquisitionAuthorization.currentPolicyVersion,
        declaredAt: now.subtract(const Duration(minutes: 2)),
        documentSha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
      sourceDate: DateTime.utc(2026, 3, 31),
      facts: const <LppEvidenceFactKey, LppReviewedFact>{
        LppEvidenceFactKey.vestedBenefitsCapitalChf: LppReviewedFact(
          value: 130000,
          unit: LppEvidenceUnit.chf,
        ),
      },
    );

SpecialistReferenceEvidence _evidence({
  required String referenceId,
  required DateTime confirmedAt,
}) {
  return SpecialistReferenceEvidence.tryFromJson(
    <String, dynamic>{
      'referenceId': referenceId,
      'kind': LppCapitalNoticeDeadline.kind,
      'ownerKind': 'self',
      'source': 'certificate',
      'sourceDate': '2026-02-03',
      'legalYear': 2026,
      'confirmedAt': confirmedAt.toUtc().toIso8601String(),
      'deadlineDate': '2026-09-30',
    },
    expectedKind: SpecialistReferenceKind.lppCapitalNotice,
    now: confirmedAt.add(const Duration(seconds: 1)),
  )!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
  });

  tearDown(() {
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = false;
    FeatureFlags.typedLppEvidence = false;
  });

  test('receipt matcher rejects forged tuple fields and flag-off state',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    final accepted = await _acceptedNotice(now);
    addTearDown(accepted.ledger.dispose);
    expect(
      accepted.ledger.matchesAcceptedLppCapitalNoticeReceipt(accepted.receipt),
      isTrue,
    );
    for (final forged in <LppCapitalNoticeReceipt>[
      LppCapitalNoticeReceipt(
        referenceId: _forgedReferenceId,
        snapshotId: accepted.receipt.snapshotId,
        confirmedAt: accepted.receipt.confirmedAt,
      ),
      LppCapitalNoticeReceipt(
        referenceId: accepted.receipt.referenceId,
        snapshotId: _forgedReferenceId,
        confirmedAt: accepted.receipt.confirmedAt,
      ),
      LppCapitalNoticeReceipt(
        referenceId: accepted.receipt.referenceId,
        snapshotId: accepted.receipt.snapshotId,
        confirmedAt:
            accepted.receipt.confirmedAt.subtract(const Duration(seconds: 1)),
      ),
    ]) {
      expect(
        accepted.ledger.matchesAcceptedLppCapitalNoticeReceipt(forged),
        isFalse,
      );
    }
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = false;
    expect(
      accepted.ledger.matchesAcceptedLppCapitalNoticeReceipt(accepted.receipt),
      isFalse,
    );
  });

  test('record rejects flag-off, missing, unloaded, and forged ledger pre-save',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    final accepted = await _acceptedNotice(now);
    addTearDown(accepted.ledger.dispose);
    final forged = LppCapitalNoticeReceipt(
      referenceId: _forgedReferenceId,
      snapshotId: accepted.receipt.snapshotId,
      confirmedAt: accepted.receipt.confirmedAt,
    );

    Future<void> expectRejected(
      String name, {
      CoachProfileProvider? ledger,
      required LppCapitalNoticeReceipt receipt,
      bool flag = true,
    }) async {
      final store = _MemoryReferenceStore();
      final documents = DocumentProvider(referenceStore: store, now: () => now);
      addTearDown(documents.dispose);
      if (ledger != null) documents.bindLedger(ledger);
      FeatureFlags.lppCapitalNoticeDeadlineEnabled = flag;
      await expectLater(
        documents.recordLppCapitalNotice(receipt),
        throwsStateError,
        reason: name,
      );
      expect(store.loadCalls, 0, reason: name);
      expect(store.saveCalls, 0, reason: name);
      FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
    }

    await expectRejected(
      'flag off',
      ledger: accepted.ledger,
      receipt: accepted.receipt,
      flag: false,
    );
    await expectRejected('missing ledger', receipt: accepted.receipt);
    final unloadedPersistence = _MemoryLppPersistence(_answers(now));
    final unloadedLedger = CoachProfileProvider(
      taxProfilePersistence: unloadedPersistence,
      lppProfilePersistence: unloadedPersistence,
      now: () => now,
    );
    addTearDown(unloadedLedger.dispose);
    await expectRejected(
      'unloaded ledger',
      ledger: unloadedLedger,
      receipt: accepted.receipt,
    );
    await expectRejected(
      'forged tuple',
      ledger: accepted.ledger,
      receipt: forged,
    );
  });

  test('store allowlist admits only lpp and exact lppCapitalNotice kinds',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    final notice = ConfirmedDocumentReference(
      referenceId: _forgedReferenceId,
      kind: LppCapitalNoticeDeadline.kind,
      snapshotId: _snapshotId,
      ownerKind: LppEvidenceOwnerKind.self,
      confirmedAt: now,
    );
    final generic = _genericReference(now);
    expect(ConfirmedDocumentReference.fromJson(notice.toJson()), isNotNull);
    expect(ConfirmedDocumentReference.fromJson(generic.toJson()), isNotNull);
    for (final mutation in <Map<String, dynamic>>[
      <String, dynamic>{...notice.toJson(), 'kind': 'salary'},
      <String, dynamic>{...notice.toJson(), 'rawOcr': 'forbidden'},
      <String, dynamic>{...notice.toJson(), 'value': 125000},
    ]) {
      expect(ConfirmedDocumentReference.fromJson(mutation), isNull);
    }

    final store = DocumentReferenceStore();
    await store.save(<ConfirmedDocumentReference>[generic, notice]);
    expect(await store.load(), hasLength(2));

    final preferences = await SharedPreferences.getInstance();
    final persisted = jsonDecode(
      preferences.getString(DocumentReferenceStore.storageKey)!,
    ) as Map<String, dynamic>;
    (persisted['references'] as List).add(<String, dynamic>{
      ...notice.toJson(),
      'raw': 'forbidden',
    });
    await preferences.setString(
      DocumentReferenceStore.storageKey,
      jsonEncode(persisted),
    );
    await expectLater(store.load(), throwsFormatException);
  });

  test(
      'record preserves receipt tuple exactly and identical retry is idempotent',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    final accepted = await _acceptedNotice(now);
    addTearDown(accepted.ledger.dispose);
    final store = _MemoryReferenceStore();
    final documents = DocumentProvider(
      referenceStore: store,
      now: () => now.add(const Duration(days: 10)),
    );
    addTearDown(documents.dispose);
    documents.bindLedger(accepted.ledger);

    final reference = await documents.recordLppCapitalNotice(accepted.receipt);
    final retry = await documents.recordLppCapitalNotice(accepted.receipt);

    expect(reference.referenceId, accepted.receipt.referenceId);
    expect(reference.kind, LppCapitalNoticeDeadline.kind);
    expect(reference.snapshotId, accepted.receipt.snapshotId);
    expect(reference.ownerKind, LppEvidenceOwnerKind.self);
    expect(reference.confirmedAt, accepted.receipt.confirmedAt);
    expect(retry.toJson(), reference.toJson());
    expect(store.references, hasLength(1));
    expect(store.saveCalls, 1);
  });

  test('notice replacement replaces its tuple while generic lpp coexists',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    final accepted = await _acceptedNotice(now);
    addTearDown(accepted.ledger.dispose);
    final store = _MemoryReferenceStore(initial: <ConfirmedDocumentReference>[
      _genericReference(now),
    ]);
    final documents = DocumentProvider(referenceStore: store, now: () => now);
    addTearDown(documents.dispose);
    documents.bindLedger(accepted.ledger);
    await documents.recordLppCapitalNotice(accepted.receipt);

    final replacementReceipt = await accepted.ledger.acceptLppCapitalNotice(
      _confirmation(
        deadlineDate: DateTime.utc(2026, 10, 31),
        expectedPreviousReferenceId: accepted.receipt.referenceId,
      ),
    );
    await documents.recordLppCapitalNotice(replacementReceipt);

    expect(store.references, hasLength(2));
    expect(
      store.references.where(
        (reference) => reference.kind == ConfirmedDocumentReference.lppKind,
      ),
      hasLength(1),
    );
    final notices = store.references.where(
      (reference) => reference.kind == LppCapitalNoticeDeadline.kind,
    );
    expect(notices, hasLength(1));
    expect(notices.single.referenceId, replacementReceipt.referenceId);
    expect(
      store.references.any(
        (reference) => reference.referenceId == accepted.receipt.referenceId,
      ),
      isFalse,
    );
  });

  test('cold hydration resolves only the exact current candidate', () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    final accepted = await _acceptedNotice(now);
    addTearDown(accepted.ledger.dispose);
    final store = _MemoryReferenceStore();
    final writerDocuments = DocumentProvider(referenceStore: store);
    addTearDown(writerDocuments.dispose);
    writerDocuments.bindLedger(accepted.ledger);
    await writerDocuments.recordLppCapitalNotice(accepted.receipt);

    final coldLedger = CoachProfileProvider(
      taxProfilePersistence: accepted.persistence,
      lppProfilePersistence: accepted.persistence,
      now: () => now,
    );
    addTearDown(coldLedger.dispose);
    await coldLedger.loadFromWizard();
    final coldDocuments = DocumentProvider(referenceStore: store);
    addTearDown(coldDocuments.dispose);
    coldDocuments.bindLedger(coldLedger);
    await coldDocuments.hydrateReferences();
    final candidate = coldLedger.profile!.lppCapitalNoticeDeadline;

    expect(candidate, isNotNull);
    expect(coldDocuments.resolveLppCapitalNotice(candidate)?.referenceId,
        accepted.receipt.referenceId);
  });

  test('resolver fails closed for hydration, kind, tuple, snapshot, and flag',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    final accepted = await _acceptedNotice(now);
    addTearDown(accepted.ledger.dispose);
    final candidate = accepted.ledger.profile!.lppCapitalNoticeDeadline!;

    final missingHydrationStore = _MemoryReferenceStore();
    final missingHydration = DocumentProvider(
      referenceStore: missingHydrationStore,
    );
    addTearDown(missingHydration.dispose);
    missingHydration.bindLedger(accepted.ledger);
    expect(missingHydration.resolveLppCapitalNotice(candidate), isNull);

    final failedStore = _MemoryReferenceStore(failLoad: true);
    final failed = DocumentProvider(referenceStore: failedStore);
    addTearDown(failed.dispose);
    failed.bindLedger(accepted.ledger);
    await expectLater(failed.hydrateReferences(), throwsStateError);
    expect(failed.resolveLppCapitalNotice(candidate), isNull);

    Future<DocumentProvider> hydratedWith(
        ConfirmedDocumentReference reference) async {
      final documents = DocumentProvider(
        referenceStore: _MemoryReferenceStore(initial: [reference]),
      );
      documents.bindLedger(accepted.ledger);
      await documents.hydrateReferences();
      addTearDown(documents.dispose);
      return documents;
    }

    final generic = await hydratedWith(ConfirmedDocumentReference(
      referenceId: accepted.receipt.referenceId,
      kind: ConfirmedDocumentReference.lppKind,
      snapshotId: accepted.receipt.snapshotId,
      ownerKind: LppEvidenceOwnerKind.self,
      confirmedAt: accepted.receipt.confirmedAt,
    ));
    expect(generic.resolveLppCapitalNotice(candidate), isNull);

    final referenceMismatch = _evidence(
      referenceId: _forgedReferenceId,
      confirmedAt: accepted.receipt.confirmedAt,
    );
    final exactDocuments = await hydratedWith(ConfirmedDocumentReference(
      referenceId: accepted.receipt.referenceId,
      kind: LppCapitalNoticeDeadline.kind,
      snapshotId: accepted.receipt.snapshotId,
      ownerKind: LppEvidenceOwnerKind.self,
      confirmedAt: accepted.receipt.confirmedAt,
    ));
    expect(
      exactDocuments.resolveLppCapitalNotice(referenceMismatch),
      isNull,
    );
    final confirmationMismatch = _evidence(
      referenceId: accepted.receipt.referenceId,
      confirmedAt:
          accepted.receipt.confirmedAt.subtract(const Duration(seconds: 1)),
    );
    expect(
      exactDocuments.resolveLppCapitalNotice(confirmationMismatch),
      isNull,
    );

    await accepted.ledger.acceptLppReview(_replacementReview(now));
    expect(exactDocuments.resolveLppCapitalNotice(candidate), isNull);

    FeatureFlags.lppCapitalNoticeDeadlineEnabled = false;
    expect(exactDocuments.resolveLppCapitalNotice(candidate), isNull);
    expect(exactDocuments.resolveLppCapitalNotice(null), isNull);
  });
}
