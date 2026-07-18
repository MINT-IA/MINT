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
const _authorityReferenceId = '77777777-7777-4777-8777-777777777777';
const _forgedAuthorityReferenceId = '88888888-8888-4888-8888-888888888888';

final class _MemoryLppPersistence
    with SerializedCanonicalAnswerMutationPersistence
    implements LppProfilePersistence, TaxProfilePersistence {
  _MemoryLppPersistence(Map<String, dynamic> initial)
      : answers = _copy(initial);

  Map<String, dynamic> answers;
  int loadCalls = 0;
  int saveCalls = 0;
  Completer<void>? saveGate;
  bool failSaves = false;

  @override
  Future<Map<String, dynamic>> loadAnswers() async {
    loadCalls += 1;
    return _copy(answers);
  }

  @override
  Future<void> saveAnswers(Map<String, dynamic> next) async {
    saveCalls += 1;
    if (failSaves) throw StateError('synthetic LPP save failure');
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
  bool includeAuthority = true,
  String authorityReferenceId = _authorityReferenceId,
  String fundRelationship = 'currentFund',
  String authoritySourceDate = '2026-02-03',
  int authorityLegalYear = 2026,
  bool legacyNoticeWithoutAuthority = false,
}) =>
    jsonEncode(<String, dynamic>{
      'schemaVersion': 3,
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
              if (legacyNoticeWithoutAuthority)
                'lppCapitalNoticeDeadline': <String, dynamic>{
                  'referenceId': '99999999-9999-4999-8999-999999999999',
                  'kind': 'lppCapitalNotice',
                  'ownerKind': 'self',
                  'source': 'certificate',
                  'sourceDate': '2026-02-03',
                  'legalYear': 2026,
                  'confirmedAt': '2026-02-04T09:30:00.000Z',
                  'deadlineDate': '2026-09-30',
                },
            }
          : null,
      'manualPartner': null,
      'legacyPartnerQuarantine': null,
      'selfRegulationReference': includeAuthority
          ? <String, dynamic>{
              'referenceId': authorityReferenceId,
              'kind': 'lppRegulation',
              'ownerKind': 'self',
              'source': 'certificate',
              'sourceDate': authoritySourceDate,
              'legalYear': authorityLegalYear,
              'confirmedAt': '2026-02-04T09:00:00.000Z',
              'fundRelationship': fundRelationship,
            }
          : null,
      'selfRegulationRecoveryReason': null,
    });

Map<String, dynamic> _answers(DateTime now, {String? root}) =>
    <String, dynamic>{
      'q_birth_year': 1981,
      'q_canton': 'VD',
      'q_civil_status': 'celibataire',
      'q_has_pension_fund': 'yes',
      '_coach_lpp_evidence_v1': root ?? _rootJson(now),
    };

LppCapitalNoticeReviewConfirmation _confirmation({
  LppEvidenceOwnerKind ownerKind = LppEvidenceOwnerKind.self,
  DateTime? sourceDate,
  int legalYear = 2026,
  DateTime? deadlineDate,
  String expectedSnapshotId = _snapshotId,
  String authorityReferenceId = _authorityReferenceId,
  String? expectedPreviousReferenceId,
}) =>
    LppCapitalNoticeReviewConfirmation(
      ownerKind: ownerKind,
      authorityReferenceId: authorityReferenceId,
      sourceDate: sourceDate ?? DateTime.utc(2026, 2, 3),
      legalYear: legalYear,
      deadlineDate: deadlineDate ?? DateTime.utc(2026, 9, 30),
      expectedSnapshotId: expectedSnapshotId,
      expectedPreviousReferenceId: expectedPreviousReferenceId,
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
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = false;
    FeatureFlags.lppRegulationReferenceEnabled = true;
  });

  tearDown(() {
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = false;
    FeatureFlags.lppRegulationReferenceEnabled = false;
    FeatureFlags.typedLppEvidence = false;
  });

  test('local capital-notice flag defaults false and ignores backend maps', () {
    expect(FeatureFlags.lppCapitalNoticeDeadlineEnabled, isFalse);

    FeatureFlags.applyFromMap(<String, dynamic>{
      'lppCapitalNoticeDeadlineEnabled': true,
    });

    expect(FeatureFlags.lppCapitalNoticeDeadlineEnabled, isFalse);
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
      provider.acceptLppCapitalNotice(_confirmation()),
      throwsStateError,
    );

    expect(persistence.loadCalls, 0);
    expect(persistence.saveCalls, 0);
    expect(notifications, 0);
  });

  test('regulation flag-off rejects even when the capital flag is on',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
    FeatureFlags.lppRegulationReferenceEnabled = false;
    final persistence = _MemoryLppPersistence(_answers(now));
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => now,
    );
    addTearDown(provider.dispose);

    await expectLater(
      provider.acceptLppCapitalNotice(_confirmation()),
      throwsStateError,
    );

    expect(persistence.loadCalls, 0);
    expect(persistence.saveCalls, 0);
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
    const dynamic incompleteDeadlineDate = '2026-09';

    expect(
      () => LppCapitalNoticeReviewConfirmation(
        ownerKind: LppEvidenceOwnerKind.self,
        authorityReferenceId: _authorityReferenceId,
        sourceDate: incompleteSourceDate,
        legalYear: 2026,
        deadlineDate: incompleteDeadlineDate,
        expectedSnapshotId: _snapshotId,
      ),
      throwsA(anything),
    );
    expect(
      () => LppCapitalNoticeReviewConfirmation(
        ownerKind: LppEvidenceOwnerKind.self,
        authorityReferenceId: 'not-an-opaque-reference',
        sourceDate: DateTime.utc(2026, 2, 3),
        legalYear: 2026,
        deadlineDate: DateTime.utc(2026, 9, 30),
        expectedSnapshotId: _snapshotId,
      ),
      throwsA(anything),
    );
    expect(
      () => LppCapitalNoticeReviewConfirmation(
        ownerKind: LppEvidenceOwnerKind.manualPartner,
        authorityReferenceId: _authorityReferenceId,
        sourceDate: DateTime.utc(2026, 2, 3),
        legalYear: 2026,
        deadlineDate: DateTime.utc(2026, 9, 30),
        expectedSnapshotId: _snapshotId,
      ),
      throwsA(anything),
    );
    expect(
      () => LppCapitalNoticeReviewConfirmation(
        ownerKind: LppEvidenceOwnerKind.self,
        authorityReferenceId: _authorityReferenceId,
        sourceDate: DateTime.utc(2026, 2, 3),
        legalYear: 0,
        deadlineDate: DateTime.utc(2026, 9, 30),
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
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
    final cases = <({
      String name,
      String root,
      LppCapitalNoticeReviewConfirmation confirmation
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
      (
        name: 'missing authority',
        root: _rootJson(now, includeAuthority: false),
        confirmation: _confirmation(),
      ),
      (
        name: 'forged authority id',
        root: _rootJson(now),
        confirmation: _confirmation(
          authorityReferenceId: _forgedAuthorityReferenceId,
        ),
      ),
      (
        name: 'non-current fund authority',
        root: _rootJson(now, fundRelationship: 'uncertain'),
        confirmation: _confirmation(),
      ),
      (
        name: 'discordant authority source date',
        root: _rootJson(now, authoritySourceDate: '2026-02-02'),
        confirmation: _confirmation(),
      ),
      (
        name: 'discordant authority legal year',
        root: _rootJson(now, authorityLegalYear: 2025),
        confirmation: _confirmation(),
      ),
    ];

    for (final item in cases) {
      final loaded = await _loadedProvider(now, root: item.root);
      addTearDown(loaded.provider.dispose);
      var notifications = 0;
      loaded.provider.addListener(() => notifications += 1);

      await expectLater(
        loaded.provider.acceptLppCapitalNotice(item.confirmation),
        throwsA(anything),
        reason: item.name,
      );
      expect(loaded.persistence.loadCalls, 0, reason: item.name);
      expect(loaded.persistence.saveCalls, 0, reason: item.name);
      expect(notifications, 0, reason: item.name);
    }
  });

  test('writer rejects an absent regulation authority before persistence',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
    FeatureFlags.lppRegulationReferenceEnabled = true;
    final loaded = await _loadedProvider(
      now,
      root: _rootJson(now, includeAuthority: false),
    );
    addTearDown(loaded.provider.dispose);

    await expectLater(
      loaded.provider.acceptLppCapitalNotice(
        LppCapitalNoticeReviewConfirmation(
          ownerKind: LppEvidenceOwnerKind.self,
          authorityReferenceId: '77777777-7777-4777-8777-777777777777',
          sourceDate: DateTime.utc(2026, 2, 3),
          legalYear: 2026,
          deadlineDate: DateTime.utc(2026, 9, 30),
          expectedSnapshotId: _snapshotId,
        ),
      ),
      throwsStateError,
    );
    expect(loaded.persistence.loadCalls, 0);
    expect(loaded.persistence.saveCalls, 0);
  });

  test('success preserves facts and binds one generated tuple live and cold',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
    final loaded = await _loadedProvider(now);
    addTearDown(loaded.provider.dispose);
    final before = LppEvidenceRoot.fromJsonString(
      loaded.persistence.answers['_coach_lpp_evidence_v1'],
    )!;
    var notifications = 0;
    loaded.provider.addListener(() => notifications += 1);

    final receipt = await loaded.provider.acceptLppCapitalNotice(
      _confirmation(),
    );

    final after = LppEvidenceRoot.fromJsonString(
      loaded.persistence.answers['_coach_lpp_evidence_v1'],
    )!;
    final notice = after.self!.lppCapitalNoticeDeadline!;
    expect(after.self!.snapshotId, before.self!.snapshotId);
    expect(after.self!.facts.keys, before.self!.facts.keys);
    expect(after.self!.facts.values.single.value,
        before.self!.facts.values.single.value);
    expect(notice.referenceId, receipt.referenceId);
    expect(notice.authorityReferenceId, _authorityReferenceId);
    expect(receipt.authorityReferenceId, _authorityReferenceId);
    expect(notice.confirmedAt, receipt.confirmedAt);
    expect(receipt.kind, LppCapitalNoticeDeadline.kind);
    expect(receipt.snapshotId, _snapshotId);
    expect(receipt.ownerKind, LppEvidenceOwnerKind.self);
    expect(loaded.persistence.loadCalls, 1);
    expect(loaded.persistence.saveCalls, 1);
    expect(notifications, 1);

    final cold = CoachProfile.fromWizardAnswers(
      loaded.persistence.answers,
      now: () => now,
    );
    expect(cold.lppCapitalNoticeDeadline?.referenceId, receipt.referenceId);
    expect(
        cold.lppCapitalNoticeDeadline?.deadlineDate, DateTime.utc(2026, 9, 30));
    expect(
      jsonEncode(cold.toJson()),
      isNot(contains('authorityReferenceId')),
    );
  });

  test('cold load purges only a legacy authority-less notice once', () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
    final persistence = _MemoryLppPersistence(
      _answers(now, root: _rootJson(now, legacyNoticeWithoutAuthority: true)),
    );
    final first = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => now,
    );
    addTearDown(first.dispose);

    await first.loadFromWizard();

    expect(persistence.saveCalls, 1);
    final rewritten = LppEvidenceRoot.fromJsonString(
      persistence.answers['_coach_lpp_evidence_v1'],
      now: () => now,
    )!;
    expect(rewritten.droppedLegacyCapitalNoticeWithoutAuthority, isFalse);
    expect(rewritten.self!.facts, isNotEmpty);
    expect(rewritten.self!.lppCapitalNoticeDeadline, isNull);
    expect(
        rewritten.selfRegulationReference?.referenceId, _authorityReferenceId);
    expect(first.profile!.lppCapitalNoticeDeadline, isNull);

    persistence.resetCounts();
    final second = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => now,
    );
    addTearDown(second.dispose);
    await second.loadFromWizard();

    expect(persistence.saveCalls, 0);
    expect(second.profile!.prevoyance.avoirLppTotal, 125000);
    expect(second.profile!.lppRegulationReference?.referenceId,
        _authorityReferenceId);
    expect(second.profile!.lppCapitalNoticeDeadline, isNull);
  });

  test('legacy notice purge save failure publishes no profile or cleanup',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
    final initial =
        _answers(now, root: _rootJson(now, legacyNoticeWithoutAuthority: true));
    final persistence = _MemoryLppPersistence(initial)..failSaves = true;
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => now,
    );
    addTearDown(provider.dispose);

    await provider.loadFromWizard();

    expect(provider.isLoaded, isTrue);
    expect(
      provider.reportAnswersSnapshot.containsKey('_coach_lpp_evidence_v1'),
      isFalse,
    );
    expect(provider.profile!.lppCapitalNoticeDeadline, isNull);
    expect(provider.profile!.lppRegulationReference, isNull);
    expect(persistence.answers, initial);
    expect(persistence.saveCalls, 1);
  });

  test('identical retry is idempotent and replacement needs exact prior id',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
    final loaded = await _loadedProvider(now);
    addTearDown(loaded.provider.dispose);
    final first = await loaded.provider.acceptLppCapitalNotice(_confirmation());
    loaded.persistence.resetCounts();

    final retry = await loaded.provider.acceptLppCapitalNotice(_confirmation());
    expect(retry.referenceId, first.referenceId);
    expect(retry.confirmedAt, first.confirmedAt);
    expect(loaded.persistence.saveCalls, 0);

    await expectLater(
      loaded.provider.acceptLppCapitalNotice(
        _confirmation(deadlineDate: DateTime.utc(2026, 10, 31)),
      ),
      throwsStateError,
    );
    expect(loaded.persistence.saveCalls, 0);

    final replacement = await loaded.provider.acceptLppCapitalNotice(
      _confirmation(
        deadlineDate: DateTime.utc(2026, 10, 31),
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
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
    final loaded = await _loadedProvider(now);
    addTearDown(loaded.provider.dispose);
    final first = await loaded.provider.acceptLppCapitalNotice(_confirmation());
    loaded.persistence.resetCounts();
    loaded.persistence.saveGate = Completer<void>();

    final replacementA = loaded.provider.acceptLppCapitalNotice(
      _confirmation(
        deadlineDate: DateTime.utc(2026, 10, 31),
        expectedPreviousReferenceId: first.referenceId,
      ),
    );
    final replacementB = loaded.provider.acceptLppCapitalNotice(
      _confirmation(
        deadlineDate: DateTime.utc(2026, 11, 30),
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

  test('later ordinary self review replaces snapshot and drops the notice',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
    final loaded = await _loadedProvider(now);
    addTearDown(loaded.provider.dispose);
    final noticeReceipt = await loaded.provider.acceptLppCapitalNotice(
      _confirmation(),
    );

    final reviewReceipt = await loaded.provider.acceptLppReview(
      _replacementReview(now),
    );

    expect(reviewReceipt.snapshotId, isNot(noticeReceipt.snapshotId));
    final root = LppEvidenceRoot.fromJsonString(
      loaded.persistence.answers['_coach_lpp_evidence_v1'],
    )!;
    expect(root.self!.snapshotId, reviewReceipt.snapshotId);
    expect(root.self!.lppCapitalNoticeDeadline, isNull);
    final cold = CoachProfile.fromWizardAnswers(
      loaded.persistence.answers,
      now: () => now,
    );
    expect(cold.lppCapitalNoticeDeadline, isNull);
  });
}
