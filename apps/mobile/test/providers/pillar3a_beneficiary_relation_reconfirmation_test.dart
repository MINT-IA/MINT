import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/pillar3a_beneficiary_evidence.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/services/feature_flags.dart';

const _contract = '11111111-1111-4111-8111-111111111111';
const _reference = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _authority = '33333333-3333-4333-8333-333333333333';

final class _MemoryPersistence
    with SerializedCanonicalAnswerMutationPersistence
    implements LppProfilePersistence, TaxProfilePersistence {
  _MemoryPersistence(this.answers);

  Map<String, dynamic> answers;
  bool failNextSave = false;

  @override
  Future<Map<String, dynamic>> loadAnswers() async =>
      Map<String, dynamic>.from(answers);

  @override
  Future<void> saveAnswers(Map<String, dynamic> next) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('synthetic ledger save failure');
    }
    answers = Map<String, dynamic>.from(next);
  }
}

final class _MemoryReferenceStore extends DocumentReferenceStore {
  _MemoryReferenceStore(this.references);

  List<ConfirmedDocumentReference> references;
  bool failNextSave = false;

  @override
  Future<List<ConfirmedDocumentReference>> load() async =>
      List<ConfirmedDocumentReference>.of(references);

  @override
  Future<void> save(List<ConfirmedDocumentReference> next) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('synthetic BND save failure');
    }
    references = List<ConfirmedDocumentReference>.of(next);
  }
}

Map<String, dynamic> _contractJson({
  String relation = 'currentActiveUnpaid',
  String confirmedAt = '2026-07-19T10:00:00.000Z',
}) =>
    <String, dynamic>{
      'kind': 'pillar3aBeneficiaryClause',
      'ownerKind': 'self',
      'documentSource': 'certificate',
      'contractReferenceId': _contract,
      'referenceId': _reference,
      'documentAuthorityId': _authority,
      'documentKind': 'confirmationInstitutionnelle',
      'sourceDate': '2026-07-18',
      'legalYear': 2026,
      'institutionAttested': true,
      'contractScoped': true,
      'temporalBasis': <String, Object?>{
        'kind': 'exactDates',
        'designationEffectiveDate': '2026-01-15',
        'lastAssignmentModificationDate': null,
      },
      'relation': relation,
      'relationSource': 'userInput',
      'relationConfirmedAt': confirmedAt,
    };

Map<String, dynamic> _answersWithRoot(Map<String, dynamic> contract) =>
    <String, dynamic>{
      'q_birth_year': 1980,
      'q_canton': 'VD',
      Pillar3aBeneficiaryEvidenceRoot.answerKey: jsonEncode(
        <String, Object?>{
          'schemaVersion': 1,
          'contracts': <Map<String, dynamic>>[contract],
        },
      ),
    };

ConfirmedDocumentReference _bnd(DateTime confirmedAt) =>
    ConfirmedDocumentReference(
      referenceId: _reference,
      kind: Pillar3aBeneficiaryEvidence.kind,
      contractReferenceId: _contract,
      documentAuthorityId: _authority,
      ownerKind: LppEvidenceOwnerKind.self,
      confirmedAt: confirmedAt,
    );

Future<CoachProfileProvider> _ledger(
  _MemoryPersistence persistence, {
  DateTime? now,
}) async {
  final ledger = CoachProfileProvider(
    taxProfilePersistence: persistence,
    lppProfilePersistence: persistence,
    now: () => now ?? DateTime.utc(2026, 7, 19, 11),
  );
  await ledger.loadFromWizard();
  return ledger;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = true;
  });

  tearDown(() {
    FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = false;
    FeatureFlags.typedLppEvidence = false;
  });

  test('relation-only writer preserves document authority and exact identity',
      () async {
    final persistence = _MemoryPersistence(_answersWithRoot(_contractJson()));
    final ledger = await _ledger(persistence);
    addTearDown(ledger.dispose);
    final before = ledger.currentPillar3aBeneficiaryEvidence!.contracts.single;

    final receipt = await ledger.reconfirmPillar3aBeneficiaryRelation(
      contractReferenceId: _contract,
      expectedReferenceId: _reference,
      relation: Pillar3aBeneficiaryRelation.uncertain,
    );

    final after = ledger.currentPillar3aBeneficiaryEvidence!.contracts.single;
    expect(after.relation, Pillar3aBeneficiaryRelation.uncertain);
    expect(after.relationConfirmedAt, DateTime.utc(2026, 7, 19, 11));
    expect(after.contractReferenceId, before.contractReferenceId);
    expect(after.referenceId, before.referenceId);
    expect(after.documentAuthorityId, before.documentAuthorityId);
    expect(after.documentKind, before.documentKind);
    expect(after.sourceDate, before.sourceDate);
    expect(after.legalYear, before.legalYear);
    expect(after.temporalBasis, before.temporalBasis);
    expect(receipt.referenceId, _reference);
    expect(receipt.documentAuthorityId, _authority);
    await expectLater(
      ledger.reconfirmPillar3aBeneficiaryRelation(
        contractReferenceId: _contract,
        expectedReferenceId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        relation: Pillar3aBeneficiaryRelation.paidOrClosed,
      ),
      throwsStateError,
    );
  });

  test('relation persistence and BND failures retry without changing IDs',
      () async {
    final persistence = _MemoryPersistence(_answersWithRoot(_contractJson()));
    final ledger = await _ledger(persistence);
    addTearDown(ledger.dispose);
    persistence.failNextSave = true;
    await expectLater(
      ledger.reconfirmPillar3aBeneficiaryRelation(
        contractReferenceId: _contract,
        expectedReferenceId: _reference,
        relation: Pillar3aBeneficiaryRelation.uncertain,
      ),
      throwsStateError,
    );
    expect(
      ledger.currentPillar3aBeneficiaryEvidence!.contracts.single.relation,
      Pillar3aBeneficiaryRelation.currentActiveUnpaid,
    );

    final receipt = await ledger.reconfirmPillar3aBeneficiaryRelation(
      contractReferenceId: _contract,
      expectedReferenceId: _reference,
      relation: Pillar3aBeneficiaryRelation.uncertain,
    );
    final store = _MemoryReferenceStore(<ConfirmedDocumentReference>[
      _bnd(DateTime.utc(2026, 7, 19, 10)),
    ])
      ..failNextSave = true;
    final documents = DocumentProvider(referenceStore: store)
      ..bindLedger(ledger);
    addTearDown(documents.dispose);
    await documents.hydrateReferences();
    await expectLater(
      documents.recordPillar3aBeneficiaryEvidence(receipt),
      throwsStateError,
    );
    expect(store.references.single.confirmedAt, DateTime.utc(2026, 7, 19, 10));

    final repaired = await documents.recordPillar3aBeneficiaryEvidence(receipt);
    expect(repaired.referenceId, _reference);
    expect(store.references.single.referenceId, _reference);
    expect(store.references.single.contractReferenceId, _contract);
    expect(store.references.single.documentAuthorityId, _authority);
    expect(store.references.single.confirmedAt, receipt.relationConfirmedAt);

    final coldLedger = await _ledger(persistence);
    addTearDown(coldLedger.dispose);
    final coldDocuments = DocumentProvider(referenceStore: store)
      ..bindLedger(coldLedger);
    addTearDown(coldDocuments.dispose);
    await coldDocuments.hydrateReferences();
    expect(
      coldDocuments.resolvePillar3aBeneficiaryConsumer().state,
      Pillar3aBeneficiaryConsumerState.needsConfirmation,
    );
  });

  test('invalid durable root is reset explicitly and retryably', () async {
    final persistence = _MemoryPersistence(<String, dynamic>{
      'q_birth_year': 1980,
      'q_canton': 'VD',
      Pillar3aBeneficiaryEvidenceRoot.answerKey: '{invalid',
    });
    final ledger = await _ledger(persistence);
    addTearDown(ledger.dispose);
    expect(
      ledger.pillar3aBeneficiaryLedgerState,
      Pillar3aBeneficiaryLedgerState.invalid,
    );

    final unrelated = ConfirmedDocumentReference(
      referenceId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      kind: ConfirmedDocumentReference.lppKind,
      snapshotId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      ownerKind: LppEvidenceOwnerKind.self,
      confirmedAt: DateTime.utc(2026, 7, 19, 9),
    );
    final store = _MemoryReferenceStore(<ConfirmedDocumentReference>[
      _bnd(DateTime.utc(2026, 7, 19, 10)),
      unrelated,
    ]);
    final documents = DocumentProvider(referenceStore: store)
      ..bindLedger(ledger);
    addTearDown(documents.dispose);
    await documents.hydrateReferences();

    store.failNextSave = true;
    await expectLater(
      documents.resetInvalidPillar3aBeneficiaryEvidence(),
      throwsStateError,
    );
    expect(
      ledger.pillar3aBeneficiaryLedgerState,
      Pillar3aBeneficiaryLedgerState.invalid,
    );
    expect(store.references, hasLength(2));

    persistence.failNextSave = true;
    await expectLater(
      documents.resetInvalidPillar3aBeneficiaryEvidence(),
      throwsStateError,
    );
    expect(
      ledger.pillar3aBeneficiaryLedgerState,
      Pillar3aBeneficiaryLedgerState.invalid,
    );
    expect(store.references, <ConfirmedDocumentReference>[unrelated]);

    expect(
      await documents.resetInvalidPillar3aBeneficiaryEvidence(),
      isTrue,
    );
    expect(
      persistence.answers,
      isNot(contains(Pillar3aBeneficiaryEvidenceRoot.answerKey)),
    );
    expect(
      ledger.pillar3aBeneficiaryLedgerState,
      Pillar3aBeneficiaryLedgerState.missing,
    );
    expect(
      await documents.resetInvalidPillar3aBeneficiaryEvidence(),
      isFalse,
    );
    expect(store.references, <ConfirmedDocumentReference>[unrelated]);
  });
}
