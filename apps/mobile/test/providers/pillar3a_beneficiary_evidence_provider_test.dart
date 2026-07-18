import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/pillar3a_beneficiary_evidence.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/session_epoch.dart';

const _contractA = '11111111-1111-4111-8111-111111111111';
const _contractB = '22222222-2222-4222-8222-222222222222';
const _referenceA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _authorityA = '33333333-3333-4333-8333-333333333333';
const _authorityB = '44444444-4444-4444-8444-444444444444';

final class _MemoryLppPersistence
    with SerializedCanonicalAnswerMutationPersistence
    implements LppProfilePersistence, TaxProfilePersistence {
  _MemoryLppPersistence([Map<String, dynamic> initial = const {}])
      : answers = _copy(initial);

  Map<String, dynamic> answers;
  int loadCalls = 0;
  int saveCalls = 0;
  bool failNextSave = false;
  Completer<void>? saveGate;

  @override
  Future<Map<String, dynamic>> loadAnswers() async {
    loadCalls += 1;
    return _copy(answers);
  }

  @override
  Future<void> saveAnswers(Map<String, dynamic> next) async {
    saveCalls += 1;
    if (failNextSave) {
      failNextSave = false;
      throw StateError('synthetic pillar 3a save failure');
    }
    final gate = saveGate;
    if (gate != null) await gate.future;
    answers = _copy(next);
  }

  void resetCounts() {
    loadCalls = 0;
    saveCalls = 0;
  }

  static Map<String, dynamic> _copy(Map<String, dynamic> value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
}

Map<String, dynamic> _contractJson({
  required String contractReferenceId,
  required String referenceId,
  String relation = 'currentActiveUnpaid',
  Object? temporalBasis = const <String, Object?>{
    'kind': 'exactDates',
    'designationEffectiveDate': '2026-01-15',
    'lastAssignmentModificationDate': null,
  },
  String confirmedAt = '2026-07-19T10:00:00.000Z',
}) =>
    <String, dynamic>{
      'kind': 'pillar3aBeneficiaryClause',
      'ownerKind': 'self',
      'source': 'certificate',
      'contractReferenceId': contractReferenceId,
      'relation': relation,
      'referenceId': referenceId,
      'sourceDate': '2026-07-18',
      'legalYear': 2026,
      'confirmedAt': confirmedAt,
      'temporalBasis': relation == 'paidOrClosed' ? null : temporalBasis,
    };

String _rootJson(List<Map<String, dynamic>> contracts) => jsonEncode(
      <String, dynamic>{
        'schemaVersion': 1,
        'contracts': contracts,
      },
    );

Pillar3aBeneficiaryReviewConfirmation _exactConfirmation({
  String contractReferenceId = _contractA,
  String documentAuthorityId = _authorityA,
  DateTime? designationEffectiveDate,
  DateTime? lastAssignmentModificationDate,
  String? expectedPreviousReferenceId,
}) =>
    Pillar3aBeneficiaryReviewConfirmation.exactDates(
      contractReferenceId: contractReferenceId,
      documentAuthorityId: documentAuthorityId,
      relation: Pillar3aBeneficiaryRelation.currentActiveUnpaid,
      sourceDate: DateTime.utc(2026, 7, 18),
      legalYear: 2026,
      designationEffectiveDate:
          designationEffectiveDate ?? DateTime.utc(2026, 1, 15),
      lastAssignmentModificationDate: lastAssignmentModificationDate,
      expectedPreviousReferenceId: expectedPreviousReferenceId,
    );

Future<({CoachProfileProvider provider, _MemoryLppPersistence persistence})>
    _loadedProvider({
  Map<String, dynamic> initial = const <String, dynamic>{
    'q_birth_year': 1980,
    'q_canton': 'VD',
  },
  SessionEpoch? sessionEpoch,
}) async {
  final persistence = _MemoryLppPersistence(initial);
  final provider = CoachProfileProvider(
    taxProfilePersistence: persistence,
    lppProfilePersistence: persistence,
    sessionEpoch: sessionEpoch,
    now: () => DateTime.utc(2026, 7, 19, 10),
  );
  await provider.loadFromWizard();
  persistence.resetCounts();
  return (provider: provider, persistence: persistence);
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

  test('typed factories reject incomplete unions before persistence exists',
      () {
    expect(
      () => Pillar3aBeneficiaryReviewConfirmation.exactDates(
        contractReferenceId: _contractA,
        documentAuthorityId: _authorityA,
        relation: Pillar3aBeneficiaryRelation.currentActiveUnpaid,
        sourceDate: DateTime.utc(2026, 7, 18),
        legalYear: 2026,
        designationEffectiveDate: null,
        lastAssignmentModificationDate: null,
      ),
      throwsArgumentError,
    );
    expect(
      () => Pillar3aBeneficiaryReviewConfirmation.attestedRegime(
        contractReferenceId: _contractA,
        documentAuthorityId: '',
        relation: Pillar3aBeneficiaryRelation.uncertain,
        sourceDate: DateTime.utc(2027, 7, 18),
        legalYear: 2027,
        regime: Pillar3aBeneficiaryRegime.post20270601,
      ),
      throwsArgumentError,
    );
    expect(
      () => Pillar3aBeneficiaryReviewConfirmation.paidOrClosed(
        contractReferenceId: 'not-a-contract-uuid',
        documentAuthorityId: _authorityA,
        sourceDate: DateTime.utc(2026, 7, 18),
        legalYear: 2026,
      ),
      throwsArgumentError,
    );
    expect(
      () => Pillar3aBeneficiaryReviewConfirmation.paidOrClosed(
        contractReferenceId: _contractA,
        documentAuthorityId: _contractA,
        sourceDate: DateTime.utc(2026, 7, 18),
        legalYear: 2026,
      ),
      throwsArgumentError,
      reason: 'Physical document authority must not alias contract identity.',
    );
    expect(
      () => Pillar3aBeneficiaryReviewConfirmation.paidOrClosed(
        contractReferenceId: _contractA,
        documentAuthorityId: 'not-an-authority-uuid',
        sourceDate: DateTime.utc(2026, 7, 18),
        legalYear: 2026,
      ),
      throwsArgumentError,
    );
  });

  test('flag-off rejects before load, save, receipt, or publication', () async {
    final loaded = await _loadedProvider();
    addTearDown(loaded.provider.dispose);
    FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = false;
    var notifications = 0;
    loaded.provider.addListener(() => notifications += 1);

    await expectLater(
      loaded.provider.acceptPillar3aBeneficiaryReview(_exactConfirmation()),
      throwsStateError,
    );

    expect(loaded.persistence.loadCalls, 0);
    expect(loaded.persistence.saveCalls, 0);
    expect(loaded.provider.currentPillar3aBeneficiaryEvidence, isNull);
    expect(notifications, 0);
  });

  test('first contract saves before publishing one generated receipt',
      () async {
    final loaded = await _loadedProvider();
    addTearDown(loaded.provider.dispose);
    loaded.persistence.saveGate = Completer<void>();
    var notifications = 0;
    loaded.provider.addListener(() => notifications += 1);
    final confirmation = _exactConfirmation();

    final pending =
        loaded.provider.acceptPillar3aBeneficiaryReview(confirmation);
    while (loaded.persistence.saveCalls == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(loaded.provider.currentPillar3aBeneficiaryEvidence, isNull);
    expect(notifications, 0);

    loaded.persistence.saveGate!.complete();
    loaded.persistence.saveGate = null;
    final receipt = await pending;
    final root = Pillar3aBeneficiaryEvidenceRoot.fromJsonString(
      loaded.persistence.answers[Pillar3aBeneficiaryEvidenceRoot.answerKey],
      now: () => DateTime.utc(2026, 7, 19, 10),
    )!;

    expect(root.contracts, hasLength(1));
    expect(root.contracts.single.contractReferenceId, _contractA);
    expect(root.contracts.single.referenceId, receipt.referenceId);
    expect(
        receipt.referenceId,
        matches(RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        )));
    expect(receipt.contractReferenceId, _contractA);
    expect(receipt.documentAuthorityId, _authorityA);
    expect(receipt.confirmedAt, DateTime.utc(2026, 7, 19, 10));
    expect(root.toJsonString(), isNot(contains(_authorityA)));
    expect(
      loaded.provider.currentPillar3aBeneficiaryEvidence?.toJson(),
      root.toJson(),
    );
    expect(
      loaded.provider.matchesAcceptedPillar3aBeneficiaryReceipt(receipt),
      isTrue,
    );
    expect(loaded.persistence.loadCalls, 1);
    expect(loaded.persistence.saveCalls, 1);
    expect(notifications, 1);
  });

  test('attested regime persists as the exclusive temporal union', () async {
    final loaded = await _loadedProvider();
    addTearDown(loaded.provider.dispose);

    final receipt = await loaded.provider.acceptPillar3aBeneficiaryReview(
      Pillar3aBeneficiaryReviewConfirmation.attestedRegime(
        contractReferenceId: _contractA,
        documentAuthorityId: _authorityA,
        relation: Pillar3aBeneficiaryRelation.uncertain,
        sourceDate: DateTime.utc(2027, 7, 18),
        legalYear: 2027,
        regime: Pillar3aBeneficiaryRegime.post20270601,
      ),
    );
    final evidence =
        loaded.provider.currentPillar3aBeneficiaryEvidence!.contracts.single;

    expect(evidence.referenceId, receipt.referenceId);
    expect(evidence.relation, Pillar3aBeneficiaryRelation.uncertain);
    expect(
      evidence.temporalBasis?.toJson(),
      <String, Object?>{
        'kind': 'attestedRegime',
        'regime': 'post20270601',
      },
    );
    expect(evidence.toJson(),
        isNot(containsPair('documentAuthorityId', anything)));
  });

  test('cold hydration exposes the durable root but no forged live authority',
      () async {
    final writer = await _loadedProvider();
    final receipt = await writer.provider
        .acceptPillar3aBeneficiaryReview(_exactConfirmation());
    writer.provider.dispose();

    final cold = CoachProfileProvider(
      taxProfilePersistence: writer.persistence,
      lppProfilePersistence: writer.persistence,
      now: () => DateTime.utc(2026, 7, 19, 10),
    );
    addTearDown(cold.dispose);
    await cold.loadFromWizard();

    expect(cold.currentPillar3aBeneficiaryEvidence?.contracts, hasLength(1));
    expect(
      cold.currentPillar3aBeneficiaryEvidence?.contracts.single.referenceId,
      receipt.referenceId,
    );
    expect(
      cold.matchesAcceptedPillar3aBeneficiaryReceipt(receipt),
      isFalse,
      reason: 'The document authority is physical BND state, not ledger data.',
    );
  });

  test('cold hydration drops a malformed root without repairing storage',
      () async {
    final loaded = await _loadedProvider(initial: <String, dynamic>{
      'q_birth_year': 1980,
      'q_canton': 'VD',
      Pillar3aBeneficiaryEvidenceRoot.answerKey: '{malformed-json',
    });
    addTearDown(loaded.provider.dispose);

    expect(loaded.provider.currentPillar3aBeneficiaryEvidence, isNull);
    expect(
      loaded.persistence.answers[Pillar3aBeneficiaryEvidenceRoot.answerKey],
      '{malformed-json',
    );
    expect(loaded.persistence.saveCalls, 0);
  });

  test('flag-off masks an existing durable root without repairing storage',
      () async {
    FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = false;
    final durable = _rootJson(<Map<String, dynamic>>[
      _contractJson(
        contractReferenceId: _contractA,
        referenceId: _referenceA,
      ),
    ]);
    final loaded = await _loadedProvider(initial: <String, dynamic>{
      'q_birth_year': 1980,
      'q_canton': 'VD',
      Pillar3aBeneficiaryEvidenceRoot.answerKey: durable,
    });
    addTearDown(loaded.provider.dispose);

    expect(loaded.provider.currentPillar3aBeneficiaryEvidence, isNull);
    expect(
      loaded.persistence.answers[Pillar3aBeneficiaryEvidenceRoot.answerKey],
      durable,
    );
    expect(loaded.persistence.saveCalls, 0);
  });

  test('save failure publishes nothing; exact retry becomes idempotent',
      () async {
    final loaded = await _loadedProvider();
    addTearDown(loaded.provider.dispose);
    loaded.persistence.failNextSave = true;
    final confirmation = _exactConfirmation();
    var notifications = 0;
    loaded.provider.addListener(() => notifications += 1);

    await expectLater(
      loaded.provider.acceptPillar3aBeneficiaryReview(confirmation),
      throwsStateError,
    );
    expect(loaded.provider.currentPillar3aBeneficiaryEvidence, isNull);
    expect(notifications, 0);

    final accepted =
        await loaded.provider.acceptPillar3aBeneficiaryReview(confirmation);
    final savesAfterRepair = loaded.persistence.saveCalls;
    final retry =
        await loaded.provider.acceptPillar3aBeneficiaryReview(confirmation);

    expect(retry.referenceId, accepted.referenceId);
    expect(retry.confirmedAt, accepted.confirmedAt);
    expect(retry.documentAuthorityId, accepted.documentAuthorityId);
    expect(loaded.persistence.saveCalls, savesAfterRepair);
    expect(notifications, 1);
  });

  test(
      'same ledger content may refresh transient document authority without save',
      () async {
    final loaded = await _loadedProvider();
    addTearDown(loaded.provider.dispose);
    final first = await loaded.provider
        .acceptPillar3aBeneficiaryReview(_exactConfirmation());
    final rootBefore =
        loaded.provider.currentPillar3aBeneficiaryEvidence!.toJsonString();
    loaded.persistence.resetCounts();
    var notifications = 0;
    loaded.provider.addListener(() => notifications += 1);

    final refreshed = await loaded.provider.acceptPillar3aBeneficiaryReview(
      _exactConfirmation(documentAuthorityId: _authorityB),
    );

    expect(refreshed.referenceId, first.referenceId);
    expect(refreshed.confirmedAt, first.confirmedAt);
    expect(refreshed.documentAuthorityId, _authorityB);
    expect(loaded.persistence.saveCalls, 0);
    expect(notifications, 0);
    expect(
      loaded.provider.currentPillar3aBeneficiaryEvidence!.toJsonString(),
      rootBefore,
    );
    expect(
      loaded.provider.matchesAcceptedPillar3aBeneficiaryReceipt(first),
      isFalse,
    );
    expect(
      loaded.provider.matchesAcceptedPillar3aBeneficiaryReceipt(refreshed),
      isTrue,
    );
  });

  test('replacement is exact CAS and retry is checked before stale-prior CAS',
      () async {
    final loaded = await _loadedProvider();
    addTearDown(loaded.provider.dispose);
    final first = await loaded.provider
        .acceptPillar3aBeneficiaryReview(_exactConfirmation());
    loaded.persistence.resetCounts();

    await expectLater(
      loaded.provider.acceptPillar3aBeneficiaryReview(
        _exactConfirmation(
          documentAuthorityId: _authorityB,
          lastAssignmentModificationDate: DateTime.utc(2026, 6, 1),
        ),
      ),
      throwsStateError,
    );
    final replacementConfirmation = _exactConfirmation(
      documentAuthorityId: _authorityB,
      lastAssignmentModificationDate: DateTime.utc(2026, 6, 1),
      expectedPreviousReferenceId: first.referenceId,
    );
    final replacement = await loaded.provider
        .acceptPillar3aBeneficiaryReview(replacementConfirmation);
    final retry = await loaded.provider
        .acceptPillar3aBeneficiaryReview(replacementConfirmation);

    expect(replacement.referenceId, isNot(first.referenceId));
    expect(retry.referenceId, replacement.referenceId);
    expect(retry.documentAuthorityId, _authorityB);
    expect(loaded.persistence.saveCalls, 1);
    expect(
      loaded.provider.currentPillar3aBeneficiaryEvidence?.contracts,
      hasLength(1),
    );
  });

  test('contracts 1 through 32 are retained and a 33rd insertion is rejected',
      () async {
    final contracts = <Map<String, dynamic>>[
      for (var index = 0; index < 32; index++)
        _contractJson(
          contractReferenceId:
              '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
          referenceId:
              '10000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
        ),
    ];
    final loaded = await _loadedProvider(initial: <String, dynamic>{
      'q_birth_year': 1980,
      Pillar3aBeneficiaryEvidenceRoot.answerKey: _rootJson(contracts),
    });
    addTearDown(loaded.provider.dispose);

    expect(
      loaded.provider.currentPillar3aBeneficiaryEvidence?.contracts,
      hasLength(32),
    );
    await expectLater(
      loaded.provider.acceptPillar3aBeneficiaryReview(
        Pillar3aBeneficiaryReviewConfirmation.paidOrClosed(
          contractReferenceId: _contractA,
          documentAuthorityId: _authorityA,
          sourceDate: DateTime.utc(2026, 7, 18),
          legalYear: 2026,
        ),
      ),
      throwsStateError,
    );
    expect(loaded.persistence.saveCalls, 0);
  });

  test('replacement remains allowed when the root already has 32 contracts',
      () async {
    final contracts = <Map<String, dynamic>>[
      for (var index = 0; index < 32; index++)
        _contractJson(
          contractReferenceId:
              '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
          referenceId:
              '10000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
        ),
    ];
    final loaded = await _loadedProvider(initial: <String, dynamic>{
      'q_birth_year': 1980,
      Pillar3aBeneficiaryEvidenceRoot.answerKey: _rootJson(contracts),
    });
    addTearDown(loaded.provider.dispose);

    final replacement = await loaded.provider.acceptPillar3aBeneficiaryReview(
      _exactConfirmation(
        contractReferenceId: '00000000-0000-4000-8000-000000000000',
        documentAuthorityId: _authorityB,
        lastAssignmentModificationDate: DateTime.utc(2026, 6, 1),
        expectedPreviousReferenceId: '10000000-0000-4000-8000-000000000000',
      ),
    );

    expect(
        replacement.referenceId, isNot('10000000-0000-4000-8000-000000000000'));
    expect(
      loaded.provider.currentPillar3aBeneficiaryEvidence?.contracts,
      hasLength(32),
    );
    expect(loaded.persistence.saveCalls, 1);
  });

  test('concurrent distinct contracts serialize without lost updates',
      () async {
    final loaded = await _loadedProvider();
    addTearDown(loaded.provider.dispose);
    loaded.persistence.saveGate = Completer<void>();

    final first =
        loaded.provider.acceptPillar3aBeneficiaryReview(_exactConfirmation());
    final second = loaded.provider.acceptPillar3aBeneficiaryReview(
      _exactConfirmation(
        contractReferenceId: _contractB,
        documentAuthorityId: _authorityB,
      ),
    );
    while (loaded.persistence.saveCalls == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(loaded.persistence.saveCalls, 1);
    loaded.persistence.saveGate!.complete();
    loaded.persistence.saveGate = null;
    await Future.wait(<Future<Pillar3aBeneficiaryReceipt>>[first, second]);

    expect(loaded.persistence.saveCalls, 2);
    expect(
      loaded.provider.currentPillar3aBeneficiaryEvidence?.contracts
          .map((contract) => contract.contractReferenceId),
      <String>[_contractA, _contractB],
    );
  });

  test('session invalidation during save leaves durable bytes unpublished',
      () async {
    final epoch = SessionEpoch();
    final loaded = await _loadedProvider(sessionEpoch: epoch);
    addTearDown(loaded.provider.dispose);
    loaded.persistence.saveGate = Completer<void>();
    var notifications = 0;
    loaded.provider.addListener(() => notifications += 1);

    final pending =
        loaded.provider.acceptPillar3aBeneficiaryReview(_exactConfirmation());
    while (loaded.persistence.saveCalls == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    epoch.beginTermination();
    loaded.persistence.saveGate!.complete();
    loaded.persistence.saveGate = null;

    await expectLater(pending, throwsA(isA<SessionEpochInvalidated>()));
    expect(
      loaded.persistence.answers,
      contains(Pillar3aBeneficiaryEvidenceRoot.answerKey),
    );
    expect(loaded.provider.currentPillar3aBeneficiaryEvidence, isNull);
    expect(notifications, 0);
    epoch.completeTermination();
  });
}
