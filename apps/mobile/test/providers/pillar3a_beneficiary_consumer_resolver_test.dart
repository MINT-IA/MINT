import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/pillar3a_beneficiary_evidence.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/services/feature_flags.dart';

const _contract = '11111111-1111-4111-8111-111111111111';
const _reference = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _otherReference = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
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
      throw StateError('synthetic presence recovery save failure');
    }
    answers = Map<String, dynamic>.from(next);
  }
}

final class _MemoryReferenceStore extends DocumentReferenceStore {
  _MemoryReferenceStore(this.references, {this.failLoad = false});

  final List<ConfirmedDocumentReference> references;
  final bool failLoad;

  @override
  Future<List<ConfirmedDocumentReference>> load() async {
    if (failLoad) throw StateError('synthetic BND load failure');
    return references;
  }
}

Map<String, dynamic> _contractJson(String relation) => <String, dynamic>{
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
      'relationConfirmedAt': '2026-07-19T10:00:00.000Z',
    };

Map<String, dynamic> _answersWithContract(String relation) => <String, dynamic>{
      'q_birth_year': 1980,
      'q_canton': 'VD',
      Pillar3aBeneficiaryEvidenceRoot.answerKey: jsonEncode(
        <String, Object?>{
          'schemaVersion': 1,
          'contracts': <Map<String, dynamic>>[_contractJson(relation)],
        },
      ),
    };

ConfirmedDocumentReference _referenceFor({
  String referenceId = _reference,
  String documentAuthorityId = _authority,
  DateTime? confirmedAt,
}) =>
    ConfirmedDocumentReference(
      referenceId: referenceId,
      kind: Pillar3aBeneficiaryEvidence.kind,
      contractReferenceId: _contract,
      documentAuthorityId: documentAuthorityId,
      ownerKind: LppEvidenceOwnerKind.self,
      confirmedAt: confirmedAt ?? DateTime.utc(2026, 7, 19, 10),
    );

Future<CoachProfileProvider> _ledger(
  Map<String, dynamic> answers, {
  DateTime? now,
}) async {
  final persistence = _MemoryPersistence(answers);
  final ledger = CoachProfileProvider(
    taxProfilePersistence: persistence,
    lppProfilePersistence: persistence,
    now: () => now ?? DateTime.utc(2026, 7, 19, 10),
  );
  await ledger.loadFromWizard();
  return ledger;
}

Future<DocumentProvider> _documents(
  CoachProfileProvider ledger,
  List<ConfirmedDocumentReference> references,
) async {
  final documents = DocumentProvider(
    referenceStore: _MemoryReferenceStore(references),
  )..bindLedger(ledger);
  await documents.hydrateReferences();
  return documents;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = true;
  });

  tearDown(() {
    FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = false;
    FeatureFlags.documentLppEvidenceEnabled = false;
    FeatureFlags.typedLppEvidence = false;
  });

  test('canonical states contain no stale or conflict vocabulary', () {
    expect(
      Pillar3aBeneficiaryConsumerState.values.map((value) => value.name),
      <String>[
        'loading',
        'unavailable',
        'empty',
        'knownCurrentDeclared',
        'needsConfirmation',
        'inactive',
        'missingDocumentReference',
        'mismatchedDocumentReference',
        'invalidPresenceProvenance',
        'invalid',
      ],
    );
  });

  test('resolver distinguishes unavailable, missing, invalid, and loading',
      () async {
    final beforeLoad = CoachProfileProvider();
    addTearDown(beforeLoad.dispose);
    expect(
      beforeLoad.pillar3aBeneficiaryLedgerState,
      Pillar3aBeneficiaryLedgerState.unavailable,
    );

    final unbound = DocumentProvider();
    addTearDown(unbound.dispose);
    expect(
      unbound.resolvePillar3aBeneficiaryConsumer().state,
      Pillar3aBeneficiaryConsumerState.unavailable,
    );

    final missingLedger = await _ledger(<String, dynamic>{
      'q_birth_year': 1980,
      'q_canton': 'VD',
      'q_has_3a': true,
    });
    addTearDown(missingLedger.dispose);
    expect(
      missingLedger.pillar3aBeneficiaryLedgerState,
      Pillar3aBeneficiaryLedgerState.missing,
    );
    final missingDocuments = DocumentProvider()..bindLedger(missingLedger);
    addTearDown(missingDocuments.dispose);
    expect(
      missingDocuments.resolvePillar3aBeneficiaryConsumer().state,
      Pillar3aBeneficiaryConsumerState.empty,
      reason: 'q_has_3a must not fake beneficiary provenance or freshness',
    );

    final invalidLedger = await _ledger(<String, dynamic>{
      'q_birth_year': 1980,
      'q_canton': 'VD',
      Pillar3aBeneficiaryEvidenceRoot.answerKey: '{invalid',
    });
    addTearDown(invalidLedger.dispose);
    expect(
      invalidLedger.pillar3aBeneficiaryLedgerState,
      Pillar3aBeneficiaryLedgerState.invalid,
    );
    final invalidDocuments = DocumentProvider()..bindLedger(invalidLedger);
    addTearDown(invalidDocuments.dispose);
    expect(
      invalidDocuments.resolvePillar3aBeneficiaryConsumer().state,
      Pillar3aBeneficiaryConsumerState.invalid,
    );

    final validLedger = await _ledger(_answersWithContract(
      Pillar3aBeneficiaryRelation.currentActiveUnpaid.name,
    ));
    addTearDown(validLedger.dispose);
    final loadingDocuments = DocumentProvider()..bindLedger(validLedger);
    addTearDown(loadingDocuments.dispose);
    expect(
      loadingDocuments.resolvePillar3aBeneficiaryConsumer().state,
      Pillar3aBeneficiaryConsumerState.loading,
    );

    final failedDocuments = DocumentProvider(
      referenceStore: _MemoryReferenceStore(
        const <ConfirmedDocumentReference>[],
        failLoad: true,
      ),
    )..bindLedger(validLedger);
    addTearDown(failedDocuments.dispose);
    await expectLater(failedDocuments.hydrateReferences(), throwsStateError);
    expect(
      failedDocuments.resolvePillar3aBeneficiaryConsumer().state,
      Pillar3aBeneficiaryConsumerState.unavailable,
    );

    final exactDocuments = await _documents(
      validLedger,
      <ConfirmedDocumentReference>[_referenceFor()],
    );
    addTearDown(exactDocuments.dispose);
    FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = false;
    final hidden = exactDocuments.resolvePillar3aBeneficiaryConsumer();
    expect(hidden.state, Pillar3aBeneficiaryConsumerState.unavailable);
    expect(hidden.entries, isEmpty);
    FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = true;
  });

  test('resolver requires exact live BND before mapping declared relation',
      () async {
    for (final scenario in <({
      String relation,
      List<ConfirmedDocumentReference> references,
      Pillar3aBeneficiaryConsumerState expected,
    })>[
      (
        relation: Pillar3aBeneficiaryRelation.currentActiveUnpaid.name,
        references: <ConfirmedDocumentReference>[_referenceFor()],
        expected: Pillar3aBeneficiaryConsumerState.knownCurrentDeclared,
      ),
      (
        relation: Pillar3aBeneficiaryRelation.uncertain.name,
        references: <ConfirmedDocumentReference>[_referenceFor()],
        expected: Pillar3aBeneficiaryConsumerState.needsConfirmation,
      ),
      (
        relation: Pillar3aBeneficiaryRelation.paidOrClosed.name,
        references: <ConfirmedDocumentReference>[_referenceFor()],
        expected: Pillar3aBeneficiaryConsumerState.inactive,
      ),
      (
        relation: Pillar3aBeneficiaryRelation.currentActiveUnpaid.name,
        references: const <ConfirmedDocumentReference>[],
        expected: Pillar3aBeneficiaryConsumerState.missingDocumentReference,
      ),
      (
        relation: Pillar3aBeneficiaryRelation.currentActiveUnpaid.name,
        references: <ConfirmedDocumentReference>[
          _referenceFor(referenceId: _otherReference),
        ],
        expected: Pillar3aBeneficiaryConsumerState.mismatchedDocumentReference,
      ),
      (
        relation: Pillar3aBeneficiaryRelation.currentActiveUnpaid.name,
        references: <ConfirmedDocumentReference>[
          _referenceFor(
            documentAuthorityId: '44444444-4444-4444-8444-444444444444',
          ),
        ],
        expected: Pillar3aBeneficiaryConsumerState.mismatchedDocumentReference,
      ),
      (
        relation: Pillar3aBeneficiaryRelation.currentActiveUnpaid.name,
        references: <ConfirmedDocumentReference>[
          _referenceFor(confirmedAt: DateTime.utc(2026, 7, 19, 9)),
        ],
        expected: Pillar3aBeneficiaryConsumerState.mismatchedDocumentReference,
      ),
    ]) {
      final ledger = await _ledger(_answersWithContract(scenario.relation));
      final documents = await _documents(ledger, scenario.references);
      addTearDown(documents.dispose);
      addTearDown(ledger.dispose);

      final resolution = documents.resolvePillar3aBeneficiaryConsumer();

      expect(resolution.state, scenario.expected);
      expect(resolution.entries, hasLength(1));
      expect(resolution.entries.single.state, scenario.expected);
      expect(
        resolution.entries.single.scanExpectedPreviousReferenceId,
        _reference,
      );
      expect(resolution.entries.single.scanContractReferenceId, _contract);
      final precise =
          resolution.entries.single.renderablePreciseDocumentMetadata;
      if (scenario.expected ==
          Pillar3aBeneficiaryConsumerState.knownCurrentDeclared) {
        expect(precise, isNotNull);
        expect(
          precise!.documentKind,
          Pillar3aBeneficiaryAuthorityDocumentKind.confirmationInstitutionnelle,
        );
        expect(precise.sourceDate, DateTime.utc(2026, 7, 18));
        expect(precise.legalYear, 2026);
        expect(precise.temporalBasis, isA<Pillar3aBeneficiaryExactDates>());
        expect(
          precise.relation,
          Pillar3aBeneficiaryRelation.currentActiveUnpaid,
        );
        expect(
          precise.relationConfirmedAt,
          DateTime.utc(2026, 7, 19, 10),
        );
      } else {
        expect(precise, isNull);
      }
    }
  });

  test('canonical hasPillar3a=false supersedes only at equal or newer time',
      () async {
    for (final scenario in <({
      String name,
      Object? provenance,
      Pillar3aBeneficiaryConsumerState expected,
    })>[
      (
        name: 'newer',
        provenance: <String, Object?>{
          'source': 'userInput',
          'updatedAt': '2026-07-19T11:00:00.000Z',
          'sourceDate': null,
        },
        expected: Pillar3aBeneficiaryConsumerState.inactive,
      ),
      (
        name: 'equal',
        provenance: <String, Object?>{
          'source': 'userInput',
          'updatedAt': '2026-07-19T10:00:00.000Z',
          'sourceDate': null,
        },
        expected: Pillar3aBeneficiaryConsumerState.inactive,
      ),
      (
        name: 'older',
        provenance: <String, Object?>{
          'source': 'userInput',
          'updatedAt': '2026-07-19T09:00:00.000Z',
          'sourceDate': null,
        },
        expected: Pillar3aBeneficiaryConsumerState.knownCurrentDeclared,
      ),
      (
        name: 'naked q_has_3a',
        provenance: null,
        expected: Pillar3aBeneficiaryConsumerState.knownCurrentDeclared,
      ),
      (
        name: 'malformed',
        provenance: <String, Object?>{
          'source': 'userInput',
          'updatedAt': '2026-07-19 11:00:00',
          'sourceDate': null,
        },
        expected: Pillar3aBeneficiaryConsumerState.invalidPresenceProvenance,
      ),
      (
        name: 'future',
        provenance: <String, Object?>{
          'source': 'userInput',
          'updatedAt': '2026-07-19T13:00:00.000Z',
          'sourceDate': null,
        },
        expected: Pillar3aBeneficiaryConsumerState.invalidPresenceProvenance,
      ),
    ]) {
      final answers = _answersWithContract(
        Pillar3aBeneficiaryRelation.currentActiveUnpaid.name,
      )..['q_has_3a'] = false;
      if (scenario.provenance != null) {
        answers['__provenance'] = <String, Object?>{
          'hasPillar3a': scenario.provenance,
        };
      }
      final ledger = await _ledger(
        answers,
        now: DateTime.utc(2026, 7, 19, 12),
      );
      final documents = await _documents(
        ledger,
        <ConfirmedDocumentReference>[_referenceFor()],
      );
      addTearDown(documents.dispose);
      addTearDown(ledger.dispose);

      final resolved = documents.resolvePillar3aBeneficiaryConsumer();

      expect(resolved.state, scenario.expected, reason: scenario.name);
      if (scenario.expected !=
          Pillar3aBeneficiaryConsumerState.knownCurrentDeclared) {
        expect(
          resolved.entries.single.renderablePreciseDocumentMetadata,
          isNull,
          reason: scenario.name,
        );
      }
    }
  });

  test(
      'presence recovery is durable and preserves root BND and provenance siblings',
      () async {
    final answers = _answersWithContract(
      Pillar3aBeneficiaryRelation.currentActiveUnpaid.name,
    )
      ..['q_has_3a'] = false
      ..['__provenance'] = <String, Object?>{
        'hasPillar3a': <String, Object?>{
          'source': 'userInput',
          'updatedAt': '2026-07-19T13:00:00.000Z',
          'sourceDate': null,
        },
        'siblingFact': <String, Object?>{
          'source': 'userInput',
          'updatedAt': '2026-07-19T09:00:00.000Z',
          'sourceDate': null,
        },
      };
    final rootBefore =
        answers[Pillar3aBeneficiaryEvidenceRoot.answerKey] as String;
    final persistence = _MemoryPersistence(answers);
    final ledger = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => DateTime.utc(2026, 7, 19, 12),
    );
    await ledger.loadFromWizard();
    addTearDown(ledger.dispose);
    final reference = _referenceFor();
    final documents = await _documents(
      ledger,
      <ConfirmedDocumentReference>[reference],
    );
    addTearDown(documents.dispose);
    expect(
      documents.resolvePillar3aBeneficiaryConsumer().state,
      Pillar3aBeneficiaryConsumerState.invalidPresenceProvenance,
    );

    persistence.failNextSave = true;
    await expectLater(
      ledger.resetInvalidPillar3aBeneficiaryPresenceProvenance(),
      throwsStateError,
    );
    expect(persistence.answers['q_has_3a'], isFalse);
    expect(
      persistence.answers[Pillar3aBeneficiaryEvidenceRoot.answerKey],
      rootBefore,
    );
    expect(
      documents.resolvePillar3aBeneficiaryConsumer().state,
      Pillar3aBeneficiaryConsumerState.invalidPresenceProvenance,
    );

    expect(
      await ledger.resetInvalidPillar3aBeneficiaryPresenceProvenance(),
      isTrue,
    );
    expect(persistence.answers, isNot(contains('q_has_3a')));
    expect(
      persistence.answers[Pillar3aBeneficiaryEvidenceRoot.answerKey],
      rootBefore,
    );
    final provenance = persistence.answers['__provenance'] as Map;
    expect(provenance, isNot(contains('hasPillar3a')));
    expect(provenance, contains('siblingFact'));
    expect(documents.hasStoredReference(reference.referenceId), isTrue);
    expect(
      documents.resolvePillar3aBeneficiaryConsumer().state,
      Pillar3aBeneficiaryConsumerState.knownCurrentDeclared,
    );
    expect(
      await ledger.resetInvalidPillar3aBeneficiaryPresenceProvenance(),
      isFalse,
    );

    final coldLedger = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => DateTime.utc(2026, 7, 19, 12),
    );
    await coldLedger.loadFromWizard();
    addTearDown(coldLedger.dispose);
    final coldDocuments = await _documents(
      coldLedger,
      <ConfirmedDocumentReference>[reference],
    );
    addTearDown(coldDocuments.dispose);
    expect(
      coldDocuments.resolvePillar3aBeneficiaryConsumer().state,
      Pillar3aBeneficiaryConsumerState.knownCurrentDeclared,
    );
    expect(
      coldLedger.currentPillar3aBeneficiaryEvidence?.toJsonString(),
      rootBefore,
    );
  });

  test('presence recovery refuses a non-map provenance root', () async {
    final answers = _answersWithContract(
      Pillar3aBeneficiaryRelation.currentActiveUnpaid.name,
    )
      ..['q_has_3a'] = false
      ..['__provenance'] = 'malformed';
    final persistence = _MemoryPersistence(answers);
    final ledger = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => DateTime.utc(2026, 7, 19, 12),
    );
    await ledger.loadFromWizard();
    addTearDown(ledger.dispose);

    expect(
      await ledger.resetInvalidPillar3aBeneficiaryPresenceProvenance(),
      isFalse,
    );
    expect(persistence.answers['q_has_3a'], isFalse);
    expect(persistence.answers['__provenance'], 'malformed');
  });

  test('presence recovery keeps an empty envelope and the original relation',
      () async {
    for (final scenario in <({
      String relation,
      Pillar3aBeneficiaryConsumerState expected,
    })>[
      (
        relation: Pillar3aBeneficiaryRelation.uncertain.name,
        expected: Pillar3aBeneficiaryConsumerState.needsConfirmation,
      ),
      (
        relation: Pillar3aBeneficiaryRelation.paidOrClosed.name,
        expected: Pillar3aBeneficiaryConsumerState.inactive,
      ),
    ]) {
      final answers = _answersWithContract(scenario.relation)
        ..['q_has_3a'] = false
        ..['__provenance'] = <String, Object?>{
          'hasPillar3a': <String, Object?>{
            'source': 'userInput',
            'updatedAt': '2026-07-19T13:00:00.000Z',
            'sourceDate': null,
          },
        };
      final persistence = _MemoryPersistence(answers);
      final ledger = CoachProfileProvider(
        taxProfilePersistence: persistence,
        lppProfilePersistence: persistence,
        now: () => DateTime.utc(2026, 7, 19, 12),
      );
      await ledger.loadFromWizard();
      final documents = await _documents(
        ledger,
        <ConfirmedDocumentReference>[_referenceFor()],
      );

      expect(
        await ledger.resetInvalidPillar3aBeneficiaryPresenceProvenance(),
        isTrue,
      );
      expect(persistence.answers, contains('__provenance'));
      expect(persistence.answers['__provenance'], isEmpty);
      expect(
        documents.resolvePillar3aBeneficiaryConsumer().state,
        scenario.expected,
      );

      documents.dispose();
      ledger.dispose();
    }
  });
}
