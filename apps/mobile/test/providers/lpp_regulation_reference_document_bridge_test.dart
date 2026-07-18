import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/session_epoch.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _snapshotId = '11111111-1111-4111-8111-111111111111';
const _ownerId = '22222222-2222-4222-8222-222222222222';
const _genericReferenceId = '33333333-3333-4333-8333-333333333333';
const _capitalReferenceId = '44444444-4444-4444-8444-444444444444';
const _forgedReferenceId = '55555555-5555-4555-8555-555555555555';
const _forgedSnapshotId = '66666666-6666-4666-8666-666666666666';
const _missingSnapshotApi = 'missing-snapshot-api';

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
    this.failNextSave = false,
  }) : references = List<ConfirmedDocumentReference>.of(initial);

  List<ConfirmedDocumentReference> references;
  bool failLoad;
  bool failNextSave;
  int loadCalls = 0;
  int saveCalls = 0;
  Completer<void>? loadGate;
  Completer<void>? saveGate;

  @override
  Future<List<ConfirmedDocumentReference>> load() async {
    loadCalls += 1;
    if (failLoad) throw StateError('synthetic reference hydration failure');
    final gate = loadGate;
    if (gate != null) await gate.future;
    return List<ConfirmedDocumentReference>.unmodifiable(references);
  }

  @override
  Future<void> save(List<ConfirmedDocumentReference> next) async {
    saveCalls += 1;
    final gate = saveGate;
    if (gate != null) await gate.future;
    if (failNextSave) {
      failNextSave = false;
      throw StateError('synthetic reference persistence failure');
    }
    references = List<ConfirmedDocumentReference>.of(next);
  }
}

final class _FailingMigrationReferenceStore extends DocumentReferenceStore {
  _FailingMigrationReferenceStore(SharedPreferences preferences)
      : super(preferencesLoader: () async => preferences);

  @override
  Future<void> save(List<ConfirmedDocumentReference> references) async {
    throw StateError('synthetic schema migration persistence failure');
  }
}

final class _ObservingMigrationReferenceStore extends DocumentReferenceStore {
  _ObservingMigrationReferenceStore(SharedPreferences preferences)
      : super(preferencesLoader: () async => preferences);

  int saveCalls = 0;

  @override
  Future<void> save(List<ConfirmedDocumentReference> references) async {
    saveCalls += 1;
    await super.save(references);
  }
}

Map<String, dynamic> _numericSelf(DateTime now) => <String, dynamic>{
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
            'updatedAt':
                now.subtract(const Duration(days: 1)).toUtc().toIso8601String(),
          },
        },
      },
    };

String _schema1Root(DateTime now) => jsonEncode(<String, dynamic>{
      'schemaVersion': 1,
      'self': _numericSelf(now),
      'manualPartner': null,
      'legacyPartnerQuarantine': null,
    });

String _schema2Root(DateTime now, {bool includeSelf = true}) =>
    jsonEncode(<String, dynamic>{
      'schemaVersion': 2,
      'self': includeSelf ? _numericSelf(now) : null,
      'manualPartner': null,
      'legacyPartnerQuarantine': null,
      'selfRegulationReference': null,
    });

String _compatibleRoot(DateTime now) => LppEvidenceRoot.fromJsonString(
          _schema2Root(now),
          now: () => now,
        ) !=
        null
    ? _schema2Root(now)
    : _schema1Root(now);

Map<String, dynamic> _answers(DateTime now, {String? root}) =>
    <String, dynamic>{
      'q_birth_year': 1981,
      'q_canton': 'VD',
      'q_civil_status': 'celibataire',
      'q_has_pension_fund': 'yes',
      '_coach_lpp_evidence_v1': root ?? _compatibleRoot(now),
    };

Map<String, dynamic> _regulationJson({
  String referenceId = '77777777-7777-4777-8777-777777777777',
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
    _regulationJson(fundRelationship: wireName),
    now: () => DateTime.utc(2026, 7, 18, 12),
  );
  return reference?.fundRelationship;
}

LppRegulationReviewConfirmation _confirmation({
  int legalYear = 2026,
  String fundRelationship = 'currentFund',
  String? expectedPreviousReferenceId,
}) {
  try {
    return Function.apply(
      LppRegulationReviewConfirmation.new,
      const <Object?>[],
      <Symbol, Object?>{
        #ownerKind: LppEvidenceOwnerKind.self,
        #sourceDate: DateTime.utc(2026, 2, 3),
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
        #ownerKind: LppEvidenceOwnerKind.self,
        #sourceDate: DateTime.utc(2026, 2, 3),
        #legalYear: legalYear,
        #expectedSnapshotId: _snapshotId,
        if (expectedPreviousReferenceId != null)
          #expectedPreviousReferenceId: expectedPreviousReferenceId,
      },
    ) as LppRegulationReviewConfirmation;
  }
}

LppRegulationReceipt _receipt({
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

Object? _snapshotIdOf(dynamic value) {
  try {
    return value.snapshotId;
  } on NoSuchMethodError {
    return _missingSnapshotApi;
  }
}

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
        acquisitionId: '88888888-8888-4888-8888-888888888888',
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

Future<
    ({
      CoachProfileProvider ledger,
      _MemoryLppPersistence persistence,
      LppRegulationReceipt receipt,
    })> _acceptedRegulation(
  DateTime now, {
  String? root,
  String fundRelationship = 'currentFund',
}) async {
  final persistence = _MemoryLppPersistence(_answers(now, root: root));
  final ledger = CoachProfileProvider(
    taxProfilePersistence: persistence,
    lppProfilePersistence: persistence,
    now: () => now,
  );
  await ledger.loadFromWizard();
  final receipt = await ledger.acceptLppRegulationReference(
    _confirmation(fundRelationship: fundRelationship),
  );
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
  String sourceDate = '2026-02-03',
  int legalYear = 2026,
  String fundRelationship = 'currentFund',
}) {
  final next = _regulationJson(
    referenceId: referenceId,
    legalYear: legalYear,
    fundRelationship: fundRelationship,
    confirmedAt: confirmedAt.toUtc().toIso8601String(),
  )..['sourceDate'] = sourceDate;
  return SpecialistReferenceEvidence.tryFromJson(
        next,
        expectedKind: SpecialistReferenceKind.lppRegulation,
        now: confirmedAt.add(const Duration(seconds: 1)),
      ) ??
      SpecialistReferenceEvidence.tryFromJson(
        Map<String, dynamic>.from(next)..remove('fundRelationship'),
        expectedKind: SpecialistReferenceKind.lppRegulation,
        now: confirmedAt.add(const Duration(seconds: 1)),
      )!;
}

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

Map<String, dynamic> _legacyReferenceRoot(DateTime confirmedAt) =>
    <String, dynamic>{
      'schemaVersion': 1,
      'references': <Map<String, dynamic>>[
        <String, dynamic>{
          'referenceId': _genericReferenceId,
          'kind': ConfirmedDocumentReference.lppKind,
          'snapshotId': _snapshotId,
          'ownerKind': 'self',
          'confirmedAt': confirmedAt.toIso8601String(),
        },
        <String, dynamic>{
          'referenceId': _forgedReferenceId,
          'kind': LppRegulationReference.kind,
          'snapshotId': _forgedSnapshotId,
          'ownerKind': 'self',
          'confirmedAt': confirmedAt.toIso8601String(),
        },
      ],
    };

Map<String, dynamic> _legacyReferenceRootWithMalformedRegulation(
  DateTime confirmedAt, {
  required String label,
}) {
  final root = _legacyReferenceRoot(confirmedAt);
  final references = root['references']! as List<Map<String, dynamic>>;
  final regulation = references[1];
  switch (label) {
    case 'referenceUuid':
      regulation['referenceId'] = 'not-a-canonical-uuid-v4';
    case 'snapshotUuid':
      regulation['snapshotId'] = 'not-a-canonical-snapshot-uuid-v4';
    case 'confirmedAt':
      regulation['confirmedAt'] = '2026-02-04';
    case 'extraKey':
      regulation['unexpectedAuthority'] = true;
  }
  return root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.lppRegulationReferenceEnabled = true;
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = false;
  });

  tearDown(() {
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = false;
    FeatureFlags.lppRegulationReferenceEnabled = false;
    FeatureFlags.typedLppEvidence = false;
  });

  test('regulation BND is exact metadata with no snapshot key', () {
    final confirmedAt = DateTime.utc(2026, 2, 4, 9, 30);
    final encoded = <String, dynamic>{
      'referenceId': _forgedReferenceId,
      'kind': LppRegulationReference.kind,
      'ownerKind': 'self',
      'confirmedAt': confirmedAt.toIso8601String(),
    };

    final reference = ConfirmedDocumentReference.fromJson(encoded);

    expect(reference, isNotNull);
    expect(reference!.toJson(), encoded);
    expect(_snapshotIdOf(reference), isNull);

    final legacySnapshotBound = <String, dynamic>{
      ...encoded,
      'snapshotId': _snapshotId,
    };
    expect(
      ConfirmedDocumentReference.fromJson(legacySnapshotBound),
      isNull,
      reason: 'Legacy regulation BND rows are dropped, never promoted.',
    );
  });

  test('store migrates schema 1 by dropping only snapshot-bound regulation',
      () async {
    final confirmedAt = DateTime.utc(2026, 2, 4, 9, 30);
    SharedPreferences.setMockInitialValues(<String, Object>{
      DocumentReferenceStore.storageKey:
          jsonEncode(_legacyReferenceRoot(confirmedAt)),
    });
    final preferences = await SharedPreferences.getInstance();
    final store = DocumentReferenceStore(
      preferencesLoader: () async => preferences,
    );

    final loaded = await store.load();

    expect(loaded, hasLength(1));
    expect(loaded.single.referenceId, _genericReferenceId);
    expect(loaded.single.kind, ConfirmedDocumentReference.lppKind);
    expect(_snapshotIdOf(loaded.single), _snapshotId);
    final persisted = Map<String, dynamic>.from(
      jsonDecode(
        preferences.getString(DocumentReferenceStore.storageKey)!,
      ) as Map,
    );
    expect(persisted['schemaVersion'], 2);
    expect(persisted['references'], hasLength(1));
    expect(
      (persisted['references'] as List).single,
      loaded.single.toJson(),
    );
  });

  test('schema migration save failure publishes no hydrated references',
      () async {
    final confirmedAt = DateTime.utc(2026, 2, 4, 9, 30);
    SharedPreferences.setMockInitialValues(<String, Object>{
      DocumentReferenceStore.storageKey:
          jsonEncode(_legacyReferenceRoot(confirmedAt)),
    });
    final preferences = await SharedPreferences.getInstance();
    final store = _FailingMigrationReferenceStore(preferences);
    final documents = DocumentProvider(referenceStore: store);
    addTearDown(documents.dispose);

    await expectLater(documents.hydrateReferences(), throwsStateError);

    expect(
      documents.referenceHydrationState,
      DocumentReferenceHydrationState.failed,
    );
    expect(documents.referencesHydrated, isFalse);
    expect(documents.hasStoredReference(_genericReferenceId), isFalse);
    expect(documents.hasStoredReference(_forgedReferenceId), isFalse);
    expect(documents.currentReferences, isEmpty);
  });

  test(
      'schema 1 rejects malformed legacy regulation before drop or migration save',
      () async {
    final confirmedAt = DateTime.utc(2026, 2, 4, 9, 30);

    for (final label in <String>{
      'referenceUuid',
      'snapshotUuid',
      'confirmedAt',
      'extraKey',
    }) {
      final encoded = jsonEncode(
        _legacyReferenceRootWithMalformedRegulation(
          confirmedAt,
          label: label,
        ),
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        DocumentReferenceStore.storageKey: encoded,
      });
      final preferences = await SharedPreferences.getInstance();
      final store = _ObservingMigrationReferenceStore(preferences);

      await expectLater(
        store.load(),
        throwsA(isA<FormatException>()),
        reason: label,
      );

      expect(store.saveCalls, 0, reason: label);
      expect(
        preferences.getString(DocumentReferenceStore.storageKey),
        encoded,
        reason: '$label must not publish a partially migrated root',
      );
    }
  });

  test('record rejects missing ledger before load or save', () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    final accepted = await _acceptedRegulation(now);
    addTearDown(accepted.ledger.dispose);
    final store = _MemoryReferenceStore();
    final documents = DocumentProvider(referenceStore: store, now: () => now);
    addTearDown(documents.dispose);

    await expectLater(
      documents.recordLppRegulation(accepted.receipt),
      throwsStateError,
    );

    expect(store.loadCalls, 0);
    expect(store.saveCalls, 0);
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
      documents.recordLppRegulation(_receipt(
        referenceId: _forgedReferenceId,
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
      'ownerKind': 'self',
      'confirmedAt': accepted.receipt.confirmedAt.toIso8601String(),
    });
    expect(_snapshotIdOf(accepted.receipt), _missingSnapshotApi);
    expect(_snapshotIdOf(reference), isNull);
    expect(retry.toJson(), reference.toJson());
    expect(documents.hasStoredReference(reference.referenceId), isTrue);
    expect(store.references, hasLength(1));
    expect(store.saveCalls, 1);
  });

  test('reference save failure publishes nothing and retry repairs the bridge',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    final accepted = await _acceptedRegulation(now);
    addTearDown(accepted.ledger.dispose);
    final store = _MemoryReferenceStore(failNextSave: true);
    final documents = DocumentProvider(referenceStore: store, now: () => now);
    addTearDown(documents.dispose);
    documents.bindLedger(accepted.ledger);

    await expectLater(
      documents.recordLppRegulation(accepted.receipt),
      throwsStateError,
    );

    expect(
      accepted.ledger.matchesAcceptedLppRegulationReceipt(accepted.receipt),
      isTrue,
    );
    expect(documents.hasStoredReference(accepted.receipt.referenceId), isFalse);
    expect(store.references, isEmpty);
    expect(store.saveCalls, 1);

    final repaired = await documents.recordLppRegulation(accepted.receipt);

    expect(repaired.referenceId, accepted.receipt.referenceId);
    expect(documents.hasStoredReference(repaired.referenceId), isTrue);
    expect(store.references, hasLength(1));
    expect(store.saveCalls, 2);
  });

  test('session termination during reference save cannot publish old metadata',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    final accepted = await _acceptedRegulation(now);
    addTearDown(accepted.ledger.dispose);
    final epoch = SessionEpoch();
    final store = _MemoryReferenceStore()..saveGate = Completer<void>();
    final documents = DocumentProvider(
      referenceStore: store,
      now: () => now,
      sessionEpoch: epoch,
    );
    addTearDown(documents.dispose);
    documents.bindLedger(accepted.ledger);

    final pending = documents.recordLppRegulation(accepted.receipt);
    while (store.saveCalls == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    var notificationsAfterTermination = 0;
    documents.addListener(() => notificationsAfterTermination += 1);
    epoch.beginTermination();
    store.saveGate!.complete();
    store.saveGate = null;

    await expectLater(
      pending,
      throwsA(isA<SessionEpochInvalidated>()),
    );

    expect(store.references, hasLength(1));
    expect(documents.hasStoredReference(accepted.receipt.referenceId), isFalse);
    expect(documents.currentReferences, isEmpty);
    expect(notificationsAfterTermination, 0);
    epoch.completeTermination();
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

  test('concurrent regulation and capital records serialize in both orders',
      () async {
    Future<void> expectOrder({required bool regulationFirst}) async {
      final now = DateTime.utc(2026, 7, 18, 12);
      final accepted = await _acceptedRegulation(now);
      addTearDown(accepted.ledger.dispose);
      FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
      final capitalReceipt =
          await accepted.ledger.acceptLppCapitalNotice(_capitalConfirmation());
      final store = _MemoryReferenceStore()..saveGate = Completer<void>();
      final documents = DocumentProvider(referenceStore: store, now: () => now);
      addTearDown(documents.dispose);
      documents.bindLedger(accepted.ledger);

      final first = regulationFirst
          ? documents.recordLppRegulation(accepted.receipt)
          : documents.recordLppCapitalNotice(capitalReceipt);
      final second = regulationFirst
          ? documents.recordLppCapitalNotice(capitalReceipt)
          : documents.recordLppRegulation(accepted.receipt);
      while (store.saveCalls == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(store.saveCalls, 1);
      store.saveGate!.complete();
      store.saveGate = null;

      await Future.wait(<Future<ConfirmedDocumentReference>>[first, second]);

      expect(store.saveCalls, 2);
      expect(store.references, hasLength(2));
      expect(
        store.references.where(
          (reference) => reference.kind == LppRegulationReference.kind,
        ),
        hasLength(1),
      );
      expect(
        store.references.where(
          (reference) => reference.kind == LppCapitalNoticeDeadline.kind,
        ),
        hasLength(1),
      );
      expect(
        store.references.any(
          (reference) => reference.referenceId == accepted.receipt.referenceId,
        ),
        isTrue,
      );
      expect(
        store.references.any(
          (reference) => reference.referenceId == capitalReceipt.referenceId,
        ),
        isTrue,
      );
    }

    await expectOrder(regulationFirst: true);
    await expectOrder(regulationFirst: false);
  });

  test(
      'numeric snapshot replacement keeps only regulation snapshotless resolution',
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
    final regulation = await documents.recordLppRegulation(accepted.receipt);

    expect(documents.currentReferences, hasLength(3));
    expect(documents.byId(regulation.referenceId), isNotNull);
    expect(documents.byId(_genericReferenceId), isNotNull);
    expect(documents.byId(_capitalReferenceId), isNotNull);

    final numericReceipt = await accepted.ledger.acceptLppReview(
      _replacementReview(now),
    );

    expect(numericReceipt.snapshotId, isNot(_snapshotId));
    expect(
      documents.currentReferences.map((reference) => reference.referenceId),
      <String>[accepted.receipt.referenceId],
    );
    expect(documents.byId(regulation.referenceId), isNotNull);
    expect(documents.byId(_genericReferenceId), isNull);
    expect(documents.byId(_capitalReferenceId), isNull);
    expect(
      documents.resolveLppRegulation(
        accepted.ledger.profile!.lppRegulationReference,
      ),
      isNotNull,
    );
  });

  test('cold resolver uses autonomous tuple without a numeric snapshot',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    final accepted = await _acceptedRegulation(
      now,
      root: _schema2Root(now, includeSelf: false),
      fundRelationship: 'uncertain',
    );
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
    expect(_snapshotIdOf(accepted.receipt), _missingSnapshotApi);
    expect(
      _snapshotIdOf(
        store.references.singleWhere(
          (reference) => reference.kind == LppRegulationReference.kind,
        ),
      ),
      isNull,
    );
    final dynamic typedCandidate = candidate;
    expect(typedCandidate.fundRelationship.wireName, 'uncertain');

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

    final legacySnapshotBound = DocumentProvider(
      referenceStore: _MemoryReferenceStore(initial: [
        _opaqueReference(
          referenceId: accepted.receipt.referenceId,
          kind: LppRegulationReference.kind,
          snapshotId: _forgedSnapshotId,
          confirmedAt: accepted.receipt.confirmedAt,
        ),
      ]),
    );
    addTearDown(legacySnapshotBound.dispose);
    legacySnapshotBound.bindLedger(coldLedger);
    await legacySnapshotBound.hydrateReferences();
    expect(legacySnapshotBound.resolveLppRegulation(candidate), isNull);

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

  test('regulation resolution classifies every hydration state opaquely',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    final accepted = await _acceptedRegulation(now);
    addTearDown(accepted.ledger.dispose);
    final candidate = accepted.ledger.profile!.lppRegulationReference!;
    final exactReference = ConfirmedDocumentReference(
      referenceId: candidate.referenceId,
      kind: ConfirmedDocumentReference.lppRegulationKind,
      ownerKind: LppEvidenceOwnerKind.self,
      confirmedAt: candidate.confirmedAt,
    );

    final idle = DocumentProvider(
      referenceStore: _MemoryReferenceStore(initial: [exactReference]),
    );
    addTearDown(idle.dispose);
    idle.bindLedger(accepted.ledger);
    expect(
      idle.resolveLppRegulationReference(candidate),
      LppRegulationReferenceResolution.unavailable,
    );

    final loadingStore = _MemoryReferenceStore(initial: [exactReference])
      ..loadGate = Completer<void>();
    final loading = DocumentProvider(referenceStore: loadingStore);
    addTearDown(loading.dispose);
    loading.bindLedger(accepted.ledger);
    final hydration = loading.hydrateReferences();
    expect(
      loading.resolveLppRegulationReference(candidate),
      LppRegulationReferenceResolution.unavailable,
    );
    loadingStore.loadGate!.complete();
    await hydration;
    expect(
      loading.resolveLppRegulationReference(candidate),
      LppRegulationReferenceResolution.resolved,
    );
    expect(loading.resolveLppRegulation(candidate), same(candidate));

    final failed = DocumentProvider(
      referenceStore: _MemoryReferenceStore(failLoad: true),
    );
    addTearDown(failed.dispose);
    failed.bindLedger(accepted.ledger);
    await expectLater(failed.hydrateReferences(), throwsStateError);
    expect(
      failed.resolveLppRegulationReference(candidate),
      LppRegulationReferenceResolution.unavailable,
    );

    final missing = DocumentProvider(
      referenceStore: _MemoryReferenceStore(),
    );
    addTearDown(missing.dispose);
    missing.bindLedger(accepted.ledger);
    await missing.hydrateReferences();
    expect(
      missing.resolveLppRegulationReference(candidate),
      LppRegulationReferenceResolution.missingDocumentReference,
    );
    expect(missing.resolveLppRegulation(candidate), isNull);
  });

  test('regulation resolution distinguishes every stored mismatch from missing',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    final accepted = await _acceptedRegulation(now);
    addTearDown(accepted.ledger.dispose);
    final candidate = accepted.ledger.profile!.lppRegulationReference!;

    final mismatches = <String, ConfirmedDocumentReference>{
      'another regulation reference': ConfirmedDocumentReference(
        referenceId: _forgedReferenceId,
        kind: ConfirmedDocumentReference.lppRegulationKind,
        ownerKind: LppEvidenceOwnerKind.self,
        confirmedAt: candidate.confirmedAt,
      ),
      'same id, other confirmation': ConfirmedDocumentReference(
        referenceId: candidate.referenceId,
        kind: ConfirmedDocumentReference.lppRegulationKind,
        ownerKind: LppEvidenceOwnerKind.self,
        confirmedAt: candidate.confirmedAt.subtract(const Duration(seconds: 1)),
      ),
      'same id, non-canonical confirmation': ConfirmedDocumentReference(
        referenceId: candidate.referenceId,
        kind: ConfirmedDocumentReference.lppRegulationKind,
        ownerKind: LppEvidenceOwnerKind.self,
        confirmedAt: candidate.confirmedAt.toLocal(),
      ),
      'same id, other kind': ConfirmedDocumentReference(
        referenceId: candidate.referenceId,
        kind: ConfirmedDocumentReference.lppKind,
        snapshotId: _snapshotId,
        ownerKind: LppEvidenceOwnerKind.self,
        confirmedAt: candidate.confirmedAt,
      ),
      'non-canonical regulation': ConfirmedDocumentReference(
        referenceId: 'not-a-canonical-uuid-v4',
        kind: ConfirmedDocumentReference.lppRegulationKind,
        ownerKind: LppEvidenceOwnerKind.self,
        confirmedAt: candidate.confirmedAt,
      ),
      'snapshot-bound regulation': ConfirmedDocumentReference(
        referenceId: candidate.referenceId,
        kind: ConfirmedDocumentReference.lppRegulationKind,
        snapshotId: _forgedSnapshotId,
        ownerKind: LppEvidenceOwnerKind.self,
        confirmedAt: candidate.confirmedAt,
      ),
    };

    for (final entry in mismatches.entries) {
      final documents = DocumentProvider(
        referenceStore: _MemoryReferenceStore(initial: [entry.value]),
      );
      addTearDown(documents.dispose);
      documents.bindLedger(accepted.ledger);
      await documents.hydrateReferences();

      if (entry.key == 'another regulation reference') {
        expect(
          documents.byId(candidate.referenceId),
          isNull,
          reason: 'byId hides the other tuple and cannot classify this drift.',
        );
      }

      expect(
        documents.resolveLppRegulationReference(candidate),
        LppRegulationReferenceResolution.mismatchedDocumentReference,
        reason: entry.key,
      );
      expect(
        documents.resolveLppRegulation(candidate),
        isNull,
        reason: entry.key,
      );
    }

    final divergentLedgerCandidate = _regulationEvidence(
      referenceId: candidate.referenceId,
      confirmedAt: candidate.confirmedAt,
      legalYear: 2025,
    );
    final exact = DocumentProvider(
      referenceStore: _MemoryReferenceStore(
        initial: [
          ConfirmedDocumentReference(
            referenceId: candidate.referenceId,
            kind: ConfirmedDocumentReference.lppRegulationKind,
            ownerKind: LppEvidenceOwnerKind.self,
            confirmedAt: candidate.confirmedAt,
          ),
        ],
      ),
    );
    addTearDown(exact.dispose);
    exact.bindLedger(accepted.ledger);
    await exact.hydrateReferences();
    expect(
      exact.resolveLppRegulationReference(divergentLedgerCandidate),
      LppRegulationReferenceResolution.unavailable,
      reason: 'Only a valid current ledger candidate can classify BND drift.',
    );
  });

  test(
      'resolver requires the exact canonical specialist projection beyond the receipt tuple',
      () async {
    final now = DateTime.utc(2026, 7, 18, 12);
    final accepted = await _acceptedRegulation(
      now,
      fundRelationship: 'currentFund',
    );
    addTearDown(accepted.ledger.dispose);
    final documents = DocumentProvider(referenceStore: _MemoryReferenceStore());
    addTearDown(documents.dispose);
    documents.bindLedger(accepted.ledger);
    await documents.recordLppRegulation(accepted.receipt);

    final canonical = accepted.ledger.profile!.lppRegulationReference!;
    expect(
      documents.resolveLppRegulation(canonical),
      same(canonical),
      reason: 'The exact ledger-derived projection remains resolvable.',
    );

    final divergent = <String, SpecialistReferenceEvidence>{
      'sourceDate': _regulationEvidence(
        referenceId: accepted.receipt.referenceId,
        confirmedAt: accepted.receipt.confirmedAt,
        sourceDate: '2026-02-02',
      ),
      'legalYear': _regulationEvidence(
        referenceId: accepted.receipt.referenceId,
        confirmedAt: accepted.receipt.confirmedAt,
        legalYear: 2025,
      ),
      'fundRelationship': _regulationEvidence(
        referenceId: accepted.receipt.referenceId,
        confirmedAt: accepted.receipt.confirmedAt,
        fundRelationship: 'formerOrOther',
      ),
    };

    for (final entry in divergent.entries) {
      expect(entry.value.referenceId, canonical.referenceId);
      expect(entry.value.confirmedAt, canonical.confirmedAt);
      expect(
        documents.resolveLppRegulation(entry.value),
        isNull,
        reason: '${entry.key} is ledger authority, not receipt identity.',
      );
    }
  });
}
