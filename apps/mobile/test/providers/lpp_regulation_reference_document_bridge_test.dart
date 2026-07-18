import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/services/feature_flags.dart';

const _snapshotId = '11111111-1111-4111-8111-111111111111';
const _ownerId = '22222222-2222-4222-8222-222222222222';
const _genericReferenceId = '33333333-3333-4333-8333-333333333333';
const _capitalReferenceId = '44444444-4444-4444-8444-444444444444';
const _forgedReferenceId = '55555555-5555-4555-8555-555555555555';
const _forgedSnapshotId = '66666666-6666-4666-8666-666666666666';

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
  Completer<void>? saveGate;

  @override
  Future<List<ConfirmedDocumentReference>> load() async {
    loadCalls += 1;
    if (failLoad) throw StateError('synthetic reference hydration failure');
    return List<ConfirmedDocumentReference>.unmodifiable(references);
  }

  @override
  Future<void> save(List<ConfirmedDocumentReference> next) async {
    saveCalls += 1;
    final gate = saveGate;
    if (gate != null) await gate.future;
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

LppRegulationReviewConfirmation _confirmation({
  int legalYear = 2026,
  String? expectedPreviousReferenceId,
}) =>
    LppRegulationReviewConfirmation(
      ownerKind: LppEvidenceOwnerKind.self,
      sourceDate: DateTime.utc(2026, 2, 3),
      legalYear: legalYear,
      expectedSnapshotId: _snapshotId,
      expectedPreviousReferenceId: expectedPreviousReferenceId,
    );

Future<
    ({
      CoachProfileProvider ledger,
      _MemoryLppPersistence persistence,
      LppRegulationReceipt receipt,
    })> _acceptedRegulation(DateTime now) async {
  final persistence = _MemoryLppPersistence(_answers(now));
  final ledger = CoachProfileProvider(
    taxProfilePersistence: persistence,
    lppProfilePersistence: persistence,
    now: () => now,
  );
  await ledger.loadFromWizard();
  final receipt = await ledger.acceptLppRegulationReference(_confirmation());
  return (ledger: ledger, persistence: persistence, receipt: receipt);
}

ConfirmedDocumentReference _opaqueReference({
  required String referenceId,
  required String kind,
  required DateTime confirmedAt,
  String snapshotId = _snapshotId,
}) =>
    ConfirmedDocumentReference(
      referenceId: referenceId,
      kind: kind,
      snapshotId: snapshotId,
      ownerKind: LppEvidenceOwnerKind.self,
      confirmedAt: confirmedAt,
    );

SpecialistReferenceEvidence _regulationEvidence({
  required String referenceId,
  required DateTime confirmedAt,
}) =>
    SpecialistReferenceEvidence.tryFromJson(
      <String, dynamic>{
        'referenceId': referenceId,
        'kind': LppRegulationReference.kind,
        'ownerKind': 'self',
        'source': 'certificate',
        'sourceDate': '2026-02-03',
        'legalYear': 2026,
        'confirmedAt': confirmedAt.toUtc().toIso8601String(),
      },
      expectedKind: SpecialistReferenceKind.lppRegulation,
      now: confirmedAt.add(const Duration(seconds: 1)),
    )!;

SpecialistReferenceEvidence _capitalEvidence(DateTime confirmedAt) =>
    SpecialistReferenceEvidence.tryFromJson(
      <String, dynamic>{
        'referenceId': _capitalReferenceId,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.lppRegulationReferenceEnabled = true;
  });

  tearDown(() {
    FeatureFlags.lppRegulationReferenceEnabled = false;
    FeatureFlags.typedLppEvidence = false;
  });

  test('record rejects flag-off, unloaded, and forged receipt before save',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    final accepted = await _acceptedRegulation(now);
    addTearDown(accepted.ledger.dispose);
    final store = _MemoryReferenceStore();
    final documents = DocumentProvider(referenceStore: store, now: () => now);
    addTearDown(documents.dispose);
    documents.bindLedger(accepted.ledger);

    FeatureFlags.lppRegulationReferenceEnabled = false;
    await expectLater(
      documents.recordLppRegulation(accepted.receipt),
      throwsStateError,
    );
    FeatureFlags.lppRegulationReferenceEnabled = true;

    final unloadedPersistence = _MemoryLppPersistence(_answers(now));
    final unloadedLedger = CoachProfileProvider(
      taxProfilePersistence: unloadedPersistence,
      lppProfilePersistence: unloadedPersistence,
      now: () => now,
    );
    addTearDown(unloadedLedger.dispose);
    documents.bindLedger(unloadedLedger);
    await expectLater(
      documents.recordLppRegulation(accepted.receipt),
      throwsStateError,
    );

    documents.bindLedger(accepted.ledger);
    await expectLater(
      documents.recordLppRegulation(LppRegulationReceipt(
        referenceId: _forgedReferenceId,
        snapshotId: accepted.receipt.snapshotId,
        confirmedAt: accepted.receipt.confirmedAt,
      )),
      throwsStateError,
    );
    expect(store.loadCalls, 0);
    expect(store.saveCalls, 0);
  });

  test('exact raw-free record saves before publish and retry is idempotent',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    final accepted = await _acceptedRegulation(now);
    addTearDown(accepted.ledger.dispose);
    final store = _MemoryReferenceStore()..saveGate = Completer<void>();
    final documents = DocumentProvider(referenceStore: store, now: () => now);
    addTearDown(documents.dispose);
    documents.bindLedger(accepted.ledger);

    final pending = documents.recordLppRegulation(accepted.receipt);
    while (store.saveCalls == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(documents.hasStoredReference(accepted.receipt.referenceId), isFalse);
    store.saveGate!.complete();
    store.saveGate = null;
    final reference = await pending;
    final retry = await documents.recordLppRegulation(accepted.receipt);

    expect(reference.toJson(), <String, dynamic>{
      'referenceId': accepted.receipt.referenceId,
      'kind': LppRegulationReference.kind,
      'snapshotId': accepted.receipt.snapshotId,
      'ownerKind': 'self',
      'confirmedAt': accepted.receipt.confirmedAt.toIso8601String(),
    });
    expect(retry.toJson(), reference.toJson());
    expect(documents.hasStoredReference(reference.referenceId), isTrue);
    expect(store.references, hasLength(1));
    expect(store.saveCalls, 1);
  });

  test('replacement removes only prior regulation and preserves other kinds',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    final accepted = await _acceptedRegulation(now);
    addTearDown(accepted.ledger.dispose);
    final store = _MemoryReferenceStore(initial: <ConfirmedDocumentReference>[
      _opaqueReference(
        referenceId: _genericReferenceId,
        kind: ConfirmedDocumentReference.lppKind,
        confirmedAt: now.subtract(const Duration(minutes: 2)),
      ),
      _opaqueReference(
        referenceId: _capitalReferenceId,
        kind: LppCapitalNoticeDeadline.kind,
        confirmedAt: now.subtract(const Duration(minutes: 1)),
      ),
    ]);
    final documents = DocumentProvider(referenceStore: store, now: () => now);
    addTearDown(documents.dispose);
    documents.bindLedger(accepted.ledger);
    await documents.recordLppRegulation(accepted.receipt);

    final replacement = await accepted.ledger.acceptLppRegulationReference(
      _confirmation(
        legalYear: 2027,
        expectedPreviousReferenceId: accepted.receipt.referenceId,
      ),
    );
    await documents.recordLppRegulation(replacement);

    expect(store.references, hasLength(3));
    for (final kind in <String>[
      ConfirmedDocumentReference.lppKind,
      LppCapitalNoticeDeadline.kind,
      LppRegulationReference.kind,
    ]) {
      expect(store.references.where((item) => item.kind == kind), hasLength(1));
    }
    expect(
      store.references
          .singleWhere((item) => item.kind == LppRegulationReference.kind)
          .referenceId,
      replacement.referenceId,
    );
    expect(
      store.references.any(
        (item) => item.referenceId == accepted.receipt.referenceId,
      ),
      isFalse,
    );
  });

  test('cold resolver requires exact hydration, kind, tuple, and snapshot',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    final accepted = await _acceptedRegulation(now);
    addTearDown(accepted.ledger.dispose);
    final store = _MemoryReferenceStore();
    final writer = DocumentProvider(referenceStore: store);
    addTearDown(writer.dispose);
    writer.bindLedger(accepted.ledger);
    await writer.recordLppRegulation(accepted.receipt);

    final coldLedger = CoachProfileProvider(
      taxProfilePersistence: accepted.persistence,
      lppProfilePersistence: accepted.persistence,
      now: () => now,
    );
    addTearDown(coldLedger.dispose);
    await coldLedger.loadFromWizard();
    final candidate = coldLedger.profile!.lppRegulationReference!;
    final coldDocuments = DocumentProvider(referenceStore: store);
    addTearDown(coldDocuments.dispose);
    coldDocuments.bindLedger(coldLedger);
    expect(coldDocuments.resolveLppRegulation(candidate), isNull);
    await coldDocuments.hydrateReferences();
    expect(
      coldDocuments.resolveLppRegulation(candidate)?.referenceId,
      accepted.receipt.referenceId,
    );

    expect(coldDocuments.resolveLppRegulation(_capitalEvidence(now)), isNull);
    expect(
      coldDocuments.resolveLppRegulation(_regulationEvidence(
        referenceId: _forgedReferenceId,
        confirmedAt: accepted.receipt.confirmedAt,
      )),
      isNull,
    );
    expect(
      coldDocuments.resolveLppRegulation(_regulationEvidence(
        referenceId: accepted.receipt.referenceId,
        confirmedAt:
            accepted.receipt.confirmedAt.subtract(const Duration(seconds: 1)),
      )),
      isNull,
    );

    final wrongSnapshot = DocumentProvider(
      referenceStore: _MemoryReferenceStore(initial: [
        _opaqueReference(
          referenceId: accepted.receipt.referenceId,
          kind: LppRegulationReference.kind,
          snapshotId: _forgedSnapshotId,
          confirmedAt: accepted.receipt.confirmedAt,
        ),
      ]),
    );
    addTearDown(wrongSnapshot.dispose);
    wrongSnapshot.bindLedger(coldLedger);
    await wrongSnapshot.hydrateReferences();
    expect(wrongSnapshot.resolveLppRegulation(candidate), isNull);

    final failed = DocumentProvider(
      referenceStore: _MemoryReferenceStore(failLoad: true),
    );
    addTearDown(failed.dispose);
    failed.bindLedger(coldLedger);
    await expectLater(failed.hydrateReferences(), throwsStateError);
    expect(failed.resolveLppRegulation(candidate), isNull);

    FeatureFlags.lppRegulationReferenceEnabled = false;
    expect(coldDocuments.resolveLppRegulation(candidate), isNull);
  });
}
