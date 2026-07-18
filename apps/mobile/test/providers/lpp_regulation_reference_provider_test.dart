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
const _missingSnapshotApi = 'missing-snapshot-api';

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

String _schema1RootJson(
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

String _schema2RootJson(
  DateTime now, {
  String snapshotId = _snapshotId,
  bool includeSelf = true,
  bool factless = false,
  Map<String, dynamic>? selfRegulationReference,
}) =>
    jsonEncode(<String, dynamic>{
      'schemaVersion': 2,
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
      'selfRegulationReference': selfRegulationReference,
    });

bool _supportsAutonomousRoot(DateTime now) =>
    LppEvidenceRoot.fromJsonString(
      _schema2RootJson(now, includeSelf: false),
      now: () => now,
    ) !=
    null;

String _rootJson(
  DateTime now, {
  String snapshotId = _snapshotId,
  bool includeSelf = true,
  bool factless = false,
}) =>
    _supportsAutonomousRoot(now)
        ? _schema2RootJson(
            now,
            snapshotId: snapshotId,
            includeSelf: includeSelf,
            factless: factless,
          )
        : _schema1RootJson(
            now,
            snapshotId: snapshotId,
            includeSelf: includeSelf,
            factless: factless,
          );

Map<String, dynamic> _answers(
  DateTime now, {
  String? root,
  bool includeLppRoot = true,
}) =>
    <String, dynamic>{
      'q_birth_year': 1981,
      'q_canton': 'VD',
      'q_civil_status': 'celibataire',
      'q_has_pension_fund': 'yes',
      if (includeLppRoot) '_coach_lpp_evidence_v1': root ?? _rootJson(now),
    };

Map<String, dynamic> _referenceJson({
  String referenceId = '44444444-4444-4444-8444-444444444444',
  int legalYear = 2026,
  String fundRelationship = 'currentFund',
  String confirmedAt = '2026-02-04T09:30:00.000Z',
}) =>
    <String, dynamic>{
      'referenceId': referenceId,
      'kind': 'lppRegulation',
      'ownerKind': 'self',
      'source': 'certificate',
      'sourceDate': '2026-02-03',
      'legalYear': legalYear,
      'confirmedAt': confirmedAt,
      'fundRelationship': fundRelationship,
    };

dynamic _fundRelationship(String wireName) {
  final dynamic reference = LppRegulationReference.fromJson(
    _referenceJson(fundRelationship: wireName),
    now: () => DateTime.utc(2026, 7, 18, 12),
  );
  return reference?.fundRelationship;
}

LppRegulationReviewConfirmation _confirmation({
  LppEvidenceOwnerKind ownerKind = LppEvidenceOwnerKind.self,
  DateTime? sourceDate,
  int legalYear = 2026,
  String fundRelationship = 'currentFund',
  String? expectedPreviousReferenceId,
}) {
  try {
    return Function.apply(
      LppRegulationReviewConfirmation.new,
      const <Object?>[],
      <Symbol, Object?>{
        #ownerKind: ownerKind,
        #sourceDate: sourceDate ?? DateTime.utc(2026, 2, 3),
        #legalYear: legalYear,
        #fundRelationship: _fundRelationship(fundRelationship),
        if (expectedPreviousReferenceId != null)
          #expectedPreviousReferenceId: expectedPreviousReferenceId,
      },
    ) as LppRegulationReviewConfirmation;
  } on NoSuchMethodError {
    return Function.apply(
      LppRegulationReviewConfirmation.new,
      const <Object?>[],
      <Symbol, Object?>{
        #ownerKind: ownerKind,
        #sourceDate: sourceDate ?? DateTime.utc(2026, 2, 3),
        #legalYear: legalYear,
        #expectedSnapshotId: _snapshotId,
        if (expectedPreviousReferenceId != null)
          #expectedPreviousReferenceId: expectedPreviousReferenceId,
      },
    ) as LppRegulationReviewConfirmation;
  }
}

LppRegulationReceipt _forgedReceipt({
  required String referenceId,
  required DateTime confirmedAt,
  String snapshotId = _snapshotId,
}) {
  try {
    return Function.apply(
      LppRegulationReceipt.new,
      const <Object?>[],
      <Symbol, Object?>{
        #referenceId: referenceId,
        #confirmedAt: confirmedAt,
      },
    ) as LppRegulationReceipt;
  } on NoSuchMethodError {
    return Function.apply(
      LppRegulationReceipt.new,
      const <Object?>[],
      <Symbol, Object?>{
        #referenceId: referenceId,
        #snapshotId: snapshotId,
        #confirmedAt: confirmedAt,
      },
    ) as LppRegulationReceipt;
  }
}

Object? _receiptSnapshotId(dynamic receipt) {
  try {
    return receipt.snapshotId;
  } on NoSuchMethodError {
    return _missingSnapshotApi;
  }
}

Object? _rootRegulation(dynamic root) {
  try {
    return root.selfRegulationReference;
  } on NoSuchMethodError {
    return _missingSnapshotApi;
  }
}

dynamic _constructFutureConfirmation({
  Object? ownerKind = LppEvidenceOwnerKind.self,
  Object? sourceDate,
  Object? legalYear = 2026,
  Object? fundRelationship,
}) =>
    Function.apply(
      LppRegulationReviewConfirmation.new,
      const <Object?>[],
      <Symbol, Object?>{
        #ownerKind: ownerKind,
        #sourceDate: sourceDate ?? DateTime.utc(2026, 2, 3),
        #legalYear: legalYear,
        #fundRelationship: fundRelationship ?? _fundRelationship('currentFund'),
      },
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
    _loadedProvider(
  DateTime now, {
  String? root,
  bool includeLppRoot = true,
}) async {
  final persistence = _MemoryLppPersistence(
    _answers(now, root: root, includeLppRoot: includeLppRoot),
  );
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
      () => _constructFutureConfirmation(
        sourceDate: incompleteSourceDate,
      ),
      throwsA(anything),
    );
    expect(
      () => _constructFutureConfirmation(
        ownerKind: LppEvidenceOwnerKind.manualPartner,
      ),
      throwsA(anything),
    );
    expect(
      () => _constructFutureConfirmation(
        legalYear: 0,
      ),
      throwsA(anything),
    );
    expect(persistence.loadCalls, 0);
    expect(persistence.saveCalls, 0);
    expect(notifications, 0);
  });

  test('reference-only schema 2 accepts without a numeric self snapshot',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    FeatureFlags.lppRegulationReferenceEnabled = true;
    final loaded = await _loadedProvider(
      now,
      root: _schema2RootJson(now, includeSelf: false),
    );
    addTearDown(loaded.provider.dispose);

    final confirmation = _confirmation(fundRelationship: 'uncertain');
    expect(_receiptSnapshotId(confirmation), _missingSnapshotApi);
    final receipt = await loaded.provider.acceptLppRegulationReference(
      confirmation,
    );

    final root = LppEvidenceRoot.fromJsonString(
      loaded.persistence.answers['_coach_lpp_evidence_v1'],
      now: () => now,
    );
    expect(root, isNotNull);
    expect(root!.self, isNull);
    final dynamic reference = _rootRegulation(root);
    expect(reference.fundRelationship.wireName, 'uncertain');
    expect(_receiptSnapshotId(receipt), _missingSnapshotApi);
  });

  test(
      'first acquisition creates one exact schema 2 authority root when the key is absent',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    FeatureFlags.lppRegulationReferenceEnabled = true;
    final loaded = await _loadedProvider(now, includeLppRoot: false);
    addTearDown(loaded.provider.dispose);
    expect(
      loaded.persistence.answers.containsKey('_coach_lpp_evidence_v1'),
      isFalse,
    );

    final receipt = await loaded.provider.acceptLppRegulationReference(
      _confirmation(fundRelationship: 'formerOrOther'),
    );

    expect(loaded.persistence.loadCalls, 1);
    expect(loaded.persistence.saveCalls, 1);
    final encoded = Map<String, dynamic>.from(
      jsonDecode(
        loaded.persistence.answers['_coach_lpp_evidence_v1']! as String,
      ) as Map,
    );
    expect(encoded.keys.toSet(), <String>{
      'schemaVersion',
      'self',
      'manualPartner',
      'legacyPartnerQuarantine',
      'selfRegulationReference',
    });
    expect(encoded['schemaVersion'], 2);
    expect(encoded['self'], isNull);
    expect(encoded['manualPartner'], isNull);
    expect(encoded['legacyPartnerQuarantine'], isNull);
    final reference = Map<String, dynamic>.from(
      encoded['selfRegulationReference']! as Map,
    );
    expect(reference['referenceId'], receipt.referenceId);
    expect(reference['fundRelationship'], 'formerOrOther');

    final cold = CoachProfile.fromWizardAnswers(
      loaded.persistence.answers,
      now: () => now,
    );
    expect(cold.lppRegulationReference?.referenceId, receipt.referenceId);
    expect(cold.lppRegulationReference?.fundRelationship,
        LppFundRelationship.formerOrOther);
  });

  test('a present malformed root fails closed before every possible save',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    FeatureFlags.lppRegulationReferenceEnabled = true;

    final outerPersistence = _MemoryLppPersistence(_answers(now));
    final malformedOuter = CoachProfileProvider(
      taxProfilePersistence: outerPersistence,
      lppProfilePersistence: outerPersistence,
      now: () => now,
    );
    addTearDown(malformedOuter.dispose);
    malformedOuter.updateFromAnswers(_answers(now, root: '{malformed'));
    await expectLater(
      malformedOuter.acceptLppRegulationReference(_confirmation()),
      throwsStateError,
    );
    expect(outerPersistence.loadCalls, 0);
    expect(outerPersistence.saveCalls, 0);

    final malformedTransaction = await _loadedProvider(
      now,
      includeLppRoot: false,
    );
    addTearDown(malformedTransaction.provider.dispose);
    malformedTransaction.persistence.answers['_coach_lpp_evidence_v1'] =
        '{malformed';
    await expectLater(
      malformedTransaction.provider.acceptLppRegulationReference(
        _confirmation(),
      ),
      throwsStateError,
    );
    expect(malformedTransaction.persistence.loadCalls, 1);
    expect(malformedTransaction.persistence.saveCalls, 0);
  });

  test('future source date rejects without persistence or notification',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    FeatureFlags.lppRegulationReferenceEnabled = true;
    final loaded = await _loadedProvider(now);
    addTearDown(loaded.provider.dispose);
    var notifications = 0;
    loaded.provider.addListener(() => notifications += 1);

    await expectLater(
      loaded.provider.acceptLppRegulationReference(
        _confirmation(sourceDate: DateTime.utc(2026, 7, 19)),
      ),
      throwsArgumentError,
    );
    expect(loaded.persistence.saveCalls, 0);
    expect(notifications, 0);
  });

  test('schema 1 nested regulation is dropped without current-fund inference',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    FeatureFlags.lppRegulationReferenceEnabled = true;
    final legacy = Map<String, dynamic>.from(
      jsonDecode(_schema1RootJson(now)) as Map,
    );
    final self = Map<String, dynamic>.from(legacy['self']! as Map);
    final expectedFacts = Map<String, dynamic>.from(self['facts']! as Map);
    final capitalNotice = <String, dynamic>{
      'referenceId': '66666666-6666-4666-8666-666666666666',
      'kind': 'lppCapitalNotice',
      'ownerKind': 'self',
      'source': 'certificate',
      'sourceDate': '2026-02-03',
      'legalYear': 2026,
      'confirmedAt': '2026-02-04T09:30:00.000Z',
      'deadlineDate': '2026-09-30',
    };
    final quarantine = <String, dynamic>{
      'legacySchemaVersion': 0,
      'reasonCodes': <String>['untyped_legacy_partner_lpp'],
      'presentKeys': <String>['_coach_conjoint_avoir_lpp'],
      'quarantinedAt': '2026-02-01T12:00:00.000Z',
    };
    self
      ..['lppCapitalNoticeDeadline'] = capitalNotice
      ..['lppRegulationReference'] = <String, dynamic>{
        'referenceId': '55555555-5555-4555-8555-555555555555',
        'kind': 'lppRegulation',
        'ownerKind': 'self',
        'source': 'certificate',
        'sourceDate': '2026-02-03',
        'legalYear': 2026,
        'confirmedAt': '2026-02-04T09:30:00.000Z',
      };
    legacy
      ..['self'] = self
      ..['legacyPartnerQuarantine'] = quarantine;

    final loaded = await _loadedProvider(now, root: jsonEncode(legacy));
    addTearDown(loaded.provider.dispose);

    final persisted = Map<String, dynamic>.from(
      jsonDecode(
        loaded.persistence.answers['_coach_lpp_evidence_v1']! as String,
      ) as Map,
    );
    expect(persisted.keys.toSet(), <String>{
      'schemaVersion',
      'self',
      'manualPartner',
      'legacyPartnerQuarantine',
      'selfRegulationReference',
    });
    expect(persisted['schemaVersion'], 2);
    expect(persisted['manualPartner'], isNull);
    expect(persisted['selfRegulationReference'], isNull);
    expect(persisted['legacyPartnerQuarantine'], quarantine);
    final persistedSelf = Map<String, dynamic>.from(persisted['self']! as Map);
    expect(persistedSelf['snapshotId'], _snapshotId);
    expect(persistedSelf['facts'], expectedFacts);
    expect(persistedSelf['lppCapitalNoticeDeadline'], capitalNotice);
    expect(persistedSelf.containsKey('lppRegulationReference'), isFalse);
    expect(loaded.provider.profile!.lppRegulationReference, isNull);
    expect(
      jsonEncode(loaded.provider.profile!.toJson()),
      isNot(contains('currentFund')),
    );
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
    final dynamic regulation = _rootRegulation(after);
    expect(regulation, isA<LppRegulationReference>());
    expect(after.self!.snapshotId, before.self!.snapshotId);
    expect(after.self!.facts.keys, before.self!.facts.keys);
    expect(after.self!.facts.values.single.value,
        before.self!.facts.values.single.value);
    expect(regulation.referenceId, receipt.referenceId);
    expect(regulation.confirmedAt, receipt.confirmedAt);
    expect(regulation.fundRelationship.wireName, 'currentFund');
    expect(receipt.kind, LppRegulationReference.kind);
    expect(_receiptSnapshotId(receipt), _missingSnapshotApi);
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
    final dynamic coldReference = cold.lppRegulationReference;
    expect(coldReference.fundRelationship.wireName, 'currentFund');

    expect(
      loaded.provider.matchesAcceptedLppRegulationReceipt(receipt),
      isTrue,
    );
    for (final forged in <LppRegulationReceipt>[
      _forgedReceipt(
        referenceId: _replacementSnapshotId,
        confirmedAt: receipt.confirmedAt,
      ),
      _forgedReceipt(
        referenceId: receipt.referenceId,
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
    )!;
    expect(
      capitalThenRegulation.self?.lppCapitalNoticeDeadline?.referenceId,
      capitalFirstReceipt.referenceId,
    );
    final dynamic capitalThenRegulationReference =
        _rootRegulation(capitalThenRegulation);
    expect(
      capitalThenRegulationReference,
      isA<LppRegulationReference>(),
    );
    expect(
      capitalThenRegulationReference.referenceId,
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
    )!;
    final dynamic regulationThenCapitalReference =
        _rootRegulation(regulationThenCapital);
    expect(
      regulationThenCapitalReference,
      isA<LppRegulationReference>(),
    );
    expect(
      regulationThenCapitalReference.referenceId,
      regulationFirstReceipt.referenceId,
    );
    expect(
      regulationThenCapital.self?.lppCapitalNoticeDeadline?.referenceId,
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
    expect(loaded.persistence.saveCalls, 1);

    loaded.persistence.resetCounts();
    final replacementRetry = await loaded.provider.acceptLppRegulationReference(
      _confirmation(
        legalYear: 2027,
        expectedPreviousReferenceId: first.referenceId,
      ),
    );
    expect(replacementRetry.referenceId, replacement.referenceId);
    expect(replacementRetry.confirmedAt, replacement.confirmedAt);
    expect(
      loaded.persistence.saveCalls,
      0,
      reason: 'An exact crash retry must be recognized before stale-prior CAS.',
    );
    expect(_receiptSnapshotId(replacement), _missingSnapshotApi);
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

  test(
      'later ordinary self review replaces numeric snapshot and preserves regulation',
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

    expect(reviewReceipt.snapshotId, isNot(_snapshotId));
    expect(_receiptSnapshotId(regulationReceipt), _missingSnapshotApi);
    final root = LppEvidenceRoot.fromJsonString(
      loaded.persistence.answers['_coach_lpp_evidence_v1'],
      now: () => now,
    )!;
    expect(root.self!.snapshotId, reviewReceipt.snapshotId);
    final dynamic reference = _rootRegulation(root);
    expect(reference, isA<LppRegulationReference>());
    expect(reference.referenceId, regulationReceipt.referenceId);
    expect(reference.fundRelationship.wireName, 'currentFund');
    final cold = CoachProfile.fromWizardAnswers(
      loaded.persistence.answers,
      now: () => now,
    );
    expect(cold.lppRegulationReference?.referenceId,
        regulationReceipt.referenceId);
  });
}
