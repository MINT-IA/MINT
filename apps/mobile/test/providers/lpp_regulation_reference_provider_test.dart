import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/feature_flags.dart';

const _snapshotId = '11111111-1111-4111-8111-111111111111';
const _replacementSnapshotId = '22222222-2222-4222-8222-222222222222';
const _ownerId = '33333333-3333-4333-8333-333333333333';

final class _MemoryLppPersistence
    with SerializedCanonicalAnswerMutationPersistence
    implements LppProfilePersistence, TaxProfilePersistence {
  _MemoryLppPersistence(Map<String, dynamic> initial)
      : answers = _copy(initial);

  Map<String, dynamic> answers;
  int loadCalls = 0;
  int saveCalls = 0;
  Completer<void>? saveGate;

  @override
  Future<Map<String, dynamic>> loadAnswers() async {
    loadCalls += 1;
    return _copy(answers);
  }

  @override
  Future<void> saveAnswers(Map<String, dynamic> next) async {
    saveCalls += 1;
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

Map<String, dynamic> _factJson(DateTime updatedAt) => <String, dynamic>{
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
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      },
    };

String _rootJson(
  DateTime now, {
  String snapshotId = _snapshotId,
  bool includeSelf = true,
  bool factless = false,
}) =>
    jsonEncode(<String, dynamic>{
      'schemaVersion': 1,
      'self': includeSelf
          ? <String, dynamic>{
              'snapshotId': snapshotId,
              'facts': factless
                  ? <String, dynamic>{}
                  : <String, dynamic>{
                      'vestedBenefitsCapitalChf': _factJson(
                        now.subtract(const Duration(days: 1)),
                      ),
                    },
            }
          : null,
      'manualPartner': null,
      'legacyPartnerQuarantine': null,
    });

Map<String, dynamic> _answers(DateTime now, {String? root}) =>
    <String, dynamic>{
      'q_birth_year': 1981,
      'q_canton': 'VD',
      'q_civil_status': 'celibataire',
      'q_has_pension_fund': 'yes',
      '_coach_lpp_evidence_v1': root ?? _rootJson(now),
    };

LppRegulationReviewConfirmation _confirmation({
  LppEvidenceOwnerKind ownerKind = LppEvidenceOwnerKind.self,
  DateTime? sourceDate,
  int legalYear = 2026,
  String expectedSnapshotId = _snapshotId,
  String? expectedPreviousReferenceId,
}) =>
    LppRegulationReviewConfirmation(
      ownerKind: ownerKind,
      sourceDate: sourceDate ?? DateTime.utc(2026, 2, 3),
      legalYear: legalYear,
      expectedSnapshotId: expectedSnapshotId,
      expectedPreviousReferenceId: expectedPreviousReferenceId,
    );

LppCapitalNoticeReviewConfirmation _capitalConfirmation() =>
    LppCapitalNoticeReviewConfirmation(
      ownerKind: LppEvidenceOwnerKind.self,
      sourceDate: DateTime.utc(2026, 2, 3),
      legalYear: 2026,
      deadlineDate: DateTime.utc(2026, 9, 30),
      expectedSnapshotId: _snapshotId,
    );

LppReviewConfirmation _replacementReview(DateTime now) => LppReviewConfirmation(
      authorization: LppAcquisitionAuthorization(
        acquisitionId: _replacementSnapshotId,
        subject: LppEvidenceOwnerKind.self,
        partnerAttested: false,
        policyVersion: LppAcquisitionAuthorization.currentPolicyVersion,
        declaredAt: now.subtract(const Duration(minutes: 5)),
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

Future<({CoachProfileProvider provider, _MemoryLppPersistence persistence})>
    _loadedProvider(DateTime now, {String? root}) async {
  final persistence = _MemoryLppPersistence(_answers(now, root: root));
  final provider = CoachProfileProvider(
    taxProfilePersistence: persistence,
    lppProfilePersistence: persistence,
    now: () => now,
  );
  await provider.loadFromWizard();
  persistence.resetCounts();
  return (provider: provider, persistence: persistence);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.lppRegulationReferenceEnabled = false;
  });

  tearDown(() {
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = false;
    FeatureFlags.lppRegulationReferenceEnabled = false;
    FeatureFlags.typedLppEvidence = false;
  });

  test(
      'local regulation-reference flag defaults false and ignores backend maps',
      () {
    expect(FeatureFlags.lppRegulationReferenceEnabled, isFalse);

    FeatureFlags.applyFromMap(<String, dynamic>{
      'lppRegulationReferenceEnabled': true,
    });

    expect(FeatureFlags.lppRegulationReferenceEnabled, isFalse);
  });

  test('flag-off rejects before persistence or publication', () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    final persistence = _MemoryLppPersistence(_answers(now));
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => now,
    );
    addTearDown(provider.dispose);
    var notifications = 0;
    provider.addListener(() => notifications += 1);

    await expectLater(
      provider.acceptLppRegulationReference(_confirmation()),
      throwsStateError,
    );

    expect(persistence.loadCalls, 0);
    expect(persistence.saveCalls, 0);
    expect(notifications, 0);
  });

  test('invalid typed fields cannot construct a review or touch persistence',
      () {
    final now = DateTime.utc(2026, 7, 18, 12);
    final persistence = _MemoryLppPersistence(_answers(now));
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => now,
    );
    addTearDown(provider.dispose);
    var notifications = 0;
    provider.addListener(() => notifications += 1);
    const dynamic incompleteSourceDate = '2026-02';

    expect(
      () => LppRegulationReviewConfirmation(
        ownerKind: LppEvidenceOwnerKind.self,
        sourceDate: incompleteSourceDate,
        legalYear: 2026,
        expectedSnapshotId: _snapshotId,
      ),
      throwsA(anything),
    );
    expect(
      () => LppRegulationReviewConfirmation(
        ownerKind: LppEvidenceOwnerKind.manualPartner,
        sourceDate: DateTime.utc(2026, 2, 3),
        legalYear: 2026,
        expectedSnapshotId: _snapshotId,
      ),
      throwsA(anything),
    );
    expect(
      () => LppRegulationReviewConfirmation(
        ownerKind: LppEvidenceOwnerKind.self,
        sourceDate: DateTime.utc(2026, 2, 3),
        legalYear: 0,
        expectedSnapshotId: _snapshotId,
      ),
      throwsA(anything),
    );
    expect(persistence.loadCalls, 0);
    expect(persistence.saveCalls, 0);
    expect(notifications, 0);
  });

  test('invalid owner, root, binding, and dates reject without I/O or notify',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    FeatureFlags.lppRegulationReferenceEnabled = true;
    final cases = <({
      String name,
      String root,
      LppRegulationReviewConfirmation confirmation
    })>[
      (
        name: 'missing self',
        root: _rootJson(now, includeSelf: false),
        confirmation: _confirmation(),
      ),
      (
        name: 'factless self',
        root: _rootJson(now, factless: true),
        confirmation: _confirmation(),
      ),
      (
        name: 'stale expected snapshot',
        root: _rootJson(now),
        confirmation: _confirmation(
          expectedSnapshotId: _replacementSnapshotId,
        ),
      ),
      (
        name: 'future source date',
        root: _rootJson(now),
        confirmation: _confirmation(
          sourceDate: DateTime.utc(2026, 7, 19),
        ),
      ),
    ];

    for (final item in cases) {
      final loaded = await _loadedProvider(now, root: item.root);
      addTearDown(loaded.provider.dispose);
      var notifications = 0;
      loaded.provider.addListener(() => notifications += 1);

      await expectLater(
        loaded.provider.acceptLppRegulationReference(item.confirmation),
        throwsA(anything),
        reason: item.name,
      );
      expect(loaded.persistence.loadCalls, 0, reason: item.name);
      expect(loaded.persistence.saveCalls, 0, reason: item.name);
      expect(notifications, 0, reason: item.name);
    }
  });

  test('success preserves facts and binds one generated tuple live and cold',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    FeatureFlags.lppRegulationReferenceEnabled = true;
    final loaded = await _loadedProvider(now);
    addTearDown(loaded.provider.dispose);
    final before = LppEvidenceRoot.fromJsonString(
      loaded.persistence.answers['_coach_lpp_evidence_v1'],
      now: () => now,
    )!;
    var notifications = 0;
    loaded.provider.addListener(() => notifications += 1);

    final receipt = await loaded.provider.acceptLppRegulationReference(
      _confirmation(),
    );

    final after = LppEvidenceRoot.fromJsonString(
      loaded.persistence.answers['_coach_lpp_evidence_v1'],
      now: () => now,
    )!;
    final regulation = after.self!.lppRegulationReference!;
    expect(after.self!.snapshotId, before.self!.snapshotId);
    expect(after.self!.facts.keys, before.self!.facts.keys);
    expect(after.self!.facts.values.single.value,
        before.self!.facts.values.single.value);
    expect(regulation.referenceId, receipt.referenceId);
    expect(regulation.confirmedAt, receipt.confirmedAt);
    expect(receipt.kind, LppRegulationReference.kind);
    expect(receipt.snapshotId, _snapshotId);
    expect(receipt.ownerKind, LppEvidenceOwnerKind.self);
    expect(loaded.persistence.loadCalls, 1);
    expect(loaded.persistence.saveCalls, 1);
    expect(notifications, 1);

    final cold = CoachProfile.fromWizardAnswers(
      loaded.persistence.answers,
      now: () => now,
    );
    expect(cold.lppRegulationReference?.referenceId, receipt.referenceId);
    expect(cold.lppRegulationReference?.sourceDate, DateTime.utc(2026, 2, 3));
    expect(cold.lppRegulationReference?.legalYear, 2026);

    expect(
      loaded.provider.matchesAcceptedLppRegulationReceipt(receipt),
      isTrue,
    );
    for (final forged in <LppRegulationReceipt>[
      LppRegulationReceipt(
        referenceId: _replacementSnapshotId,
        snapshotId: receipt.snapshotId,
        confirmedAt: receipt.confirmedAt,
      ),
      LppRegulationReceipt(
        referenceId: receipt.referenceId,
        snapshotId: _replacementSnapshotId,
        confirmedAt: receipt.confirmedAt,
      ),
      LppRegulationReceipt(
        referenceId: receipt.referenceId,
        snapshotId: receipt.snapshotId,
        confirmedAt: receipt.confirmedAt.subtract(const Duration(seconds: 1)),
      ),
    ]) {
      expect(
        loaded.provider.matchesAcceptedLppRegulationReceipt(forged),
        isFalse,
      );
    }
  });

  test('capital notice and regulation coexist in both write orders', () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
    FeatureFlags.lppRegulationReferenceEnabled = true;

    final capitalFirst = await _loadedProvider(now);
    addTearDown(capitalFirst.provider.dispose);
    final capitalFirstReceipt =
        await capitalFirst.provider.acceptLppCapitalNotice(
      _capitalConfirmation(),
    );
    final regulationSecondReceipt =
        await capitalFirst.provider.acceptLppRegulationReference(
      _confirmation(),
    );
    final capitalThenRegulation = LppEvidenceRoot.fromJsonString(
      capitalFirst.persistence.answers['_coach_lpp_evidence_v1'],
      now: () => now,
    )!
        .self!;
    expect(
      capitalThenRegulation.lppCapitalNoticeDeadline?.referenceId,
      capitalFirstReceipt.referenceId,
    );
    expect(
      capitalThenRegulation.lppRegulationReference?.referenceId,
      regulationSecondReceipt.referenceId,
    );

    final regulationFirst = await _loadedProvider(now);
    addTearDown(regulationFirst.provider.dispose);
    final regulationFirstReceipt =
        await regulationFirst.provider.acceptLppRegulationReference(
      _confirmation(),
    );
    final capitalSecondReceipt =
        await regulationFirst.provider.acceptLppCapitalNotice(
      _capitalConfirmation(),
    );
    final regulationThenCapital = LppEvidenceRoot.fromJsonString(
      regulationFirst.persistence.answers['_coach_lpp_evidence_v1'],
      now: () => now,
    )!
        .self!;
    expect(
      regulationThenCapital.lppRegulationReference?.referenceId,
      regulationFirstReceipt.referenceId,
    );
    expect(
      regulationThenCapital.lppCapitalNoticeDeadline?.referenceId,
      capitalSecondReceipt.referenceId,
    );
  });

  test('identical retry is idempotent and replacement needs exact prior id',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    FeatureFlags.lppRegulationReferenceEnabled = true;
    final loaded = await _loadedProvider(now);
    addTearDown(loaded.provider.dispose);
    final first =
        await loaded.provider.acceptLppRegulationReference(_confirmation());
    loaded.persistence.resetCounts();

    final retry =
        await loaded.provider.acceptLppRegulationReference(_confirmation());
    expect(retry.referenceId, first.referenceId);
    expect(retry.confirmedAt, first.confirmedAt);
    expect(loaded.persistence.saveCalls, 0);

    await expectLater(
      loaded.provider.acceptLppRegulationReference(
        _confirmation(legalYear: 2027),
      ),
      throwsStateError,
    );
    expect(loaded.persistence.saveCalls, 0);

    final replacement = await loaded.provider.acceptLppRegulationReference(
      _confirmation(
        legalYear: 2027,
        expectedPreviousReferenceId: first.referenceId,
      ),
    );
    expect(replacement.referenceId, isNot(first.referenceId));
    expect(replacement.snapshotId, first.snapshotId);
    expect(loaded.persistence.saveCalls, 1);
  });

  test('concurrent writes serialize and cannot both replace the same prior id',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    FeatureFlags.lppRegulationReferenceEnabled = true;
    final loaded = await _loadedProvider(now);
    addTearDown(loaded.provider.dispose);
    final first =
        await loaded.provider.acceptLppRegulationReference(_confirmation());
    loaded.persistence.resetCounts();
    loaded.persistence.saveGate = Completer<void>();

    final replacementA = loaded.provider.acceptLppRegulationReference(
      _confirmation(
        legalYear: 2027,
        expectedPreviousReferenceId: first.referenceId,
      ),
    );
    final replacementB = loaded.provider.acceptLppRegulationReference(
      _confirmation(
        legalYear: 2028,
        expectedPreviousReferenceId: first.referenceId,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(loaded.persistence.saveCalls, 1);
    loaded.persistence.saveGate!.complete();
    loaded.persistence.saveGate = null;

    await expectLater(replacementA, completes);
    await expectLater(replacementB, throwsStateError);
    expect(loaded.persistence.saveCalls, 1);
  });

  test('later ordinary self review replaces snapshot and drops the regulation',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    FeatureFlags.lppRegulationReferenceEnabled = true;
    final loaded = await _loadedProvider(now);
    addTearDown(loaded.provider.dispose);
    final regulationReceipt =
        await loaded.provider.acceptLppRegulationReference(
      _confirmation(),
    );

    final reviewReceipt = await loaded.provider.acceptLppReview(
      _replacementReview(now),
    );

    expect(reviewReceipt.snapshotId, isNot(regulationReceipt.snapshotId));
    final root = LppEvidenceRoot.fromJsonString(
      loaded.persistence.answers['_coach_lpp_evidence_v1'],
      now: () => now,
    )!;
    expect(root.self!.snapshotId, reviewReceipt.snapshotId);
    expect(root.self!.lppRegulationReference, isNull);
    final cold = CoachProfile.fromWizardAnswers(
      loaded.persistence.answers,
      now: () => now,
    );
    expect(cold.lppRegulationReference, isNull);
  });
}
