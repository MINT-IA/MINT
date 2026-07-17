import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/partner_accountability.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/providers/timeline_provider.dart';
import 'package:mint_mobile/screens/coach/retirement_dashboard_screen.dart';
import 'package:mint_mobile/screens/document_detail_screen.dart';
import 'package:mint_mobile/services/consent/partner_accountability_binding_store.dart';
import 'package:mint_mobile/services/consent/partner_accountability_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

final class _MemoryProfilePersistence
    with SerializedCanonicalAnswerMutationPersistence
    implements LppProfilePersistence, TaxProfilePersistence {
  _MemoryProfilePersistence(Map<String, dynamic> answers)
      : answers = Map<String, dynamic>.from(answers);

  final Map<String, dynamic> answers;
  Map<String, dynamic>? lastSaved;
  int saveCalls = 0;

  @override
  Future<Map<String, dynamic>> loadAnswers() async =>
      Map<String, dynamic>.from(answers);

  @override
  Future<void> saveAnswers(Map<String, dynamic> nextAnswers) async {
    saveCalls += 1;
    lastSaved = Map<String, dynamic>.from(nextAnswers);
    answers
      ..clear()
      ..addAll(lastSaved!);
  }
}

final class _FailOnceMemoryReferenceStore extends DocumentReferenceStore {
  List<ConfirmedDocumentReference> references = const [];
  int saveCalls = 0;

  @override
  Future<List<ConfirmedDocumentReference>> load() async => references;

  @override
  Future<void> save(List<ConfirmedDocumentReference> next) async {
    saveCalls += 1;
    if (saveCalls == 1) {
      throw StateError('synthetic first metadata save failure');
    }
    references = List<ConfirmedDocumentReference>.unmodifiable(next);
  }
}

final class _MemoryBindingPersistence
    implements PartnerAccountabilityBindingPersistence {
  _MemoryBindingPersistence(this.value);

  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

final class _AuthorityApi implements PartnerAccountabilityApi {
  _AuthorityApi(this.statusResult);

  final Object statusResult;

  @override
  Future<void> delete(String endpoint) async {}

  @override
  Future<Map<String, dynamic>> get(String endpoint) async {
    final result = statusResult;
    if (result is PartnerAccountabilityException) throw result;
    return Map<String, dynamic>.from(result as Map);
  }

  @override
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async =>
      throw StateError('unexpected post');
}

const _selfOwnerId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _partnerOwnerId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _mismatchOwnerId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const _manualSnapshotId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const _manualReferenceId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
const _receiptId = 'ffffffff-ffff-4fff-8fff-ffffffffffff';

LppEvidenceFact _authorityFact({
  required LppEvidenceOwnerKind ownerKind,
  required String ownerId,
  required String actorId,
  required DateTime now,
}) =>
    LppEvidenceFact(
      value: 125000,
      unit: LppEvidenceUnit.chf,
      profileOwnerId: ownerId,
      actorProfileOwnerId: actorId,
      ownerKind: ownerKind,
      authorizationMode: ownerKind == LppEvidenceOwnerKind.self
          ? LppEvidenceAuthorizationMode.self
          : LppEvidenceAuthorizationMode.manualPartnerDeclaration,
      source: 'certificate',
      sourceDate: DateTime.utc(2026, 6, 30),
      updatedAt: now.subtract(const Duration(hours: 2)),
    );

LppEvidenceRoot _manualAuthorityRoot(DateTime now) => LppEvidenceRoot(
      self: LppEvidenceSnapshot(
        snapshotId: '11111111-1111-4111-8111-111111111111',
        facts: <LppEvidenceFactKey, LppEvidenceFact>{
          LppEvidenceFactKey.vestedBenefitsCapitalChf: _authorityFact(
            ownerKind: LppEvidenceOwnerKind.self,
            ownerId: _selfOwnerId,
            actorId: _selfOwnerId,
            now: now,
          ),
        },
      ),
      manualPartner: LppEvidenceSnapshot(
        snapshotId: _manualSnapshotId,
        facts: <LppEvidenceFactKey, LppEvidenceFact>{
          LppEvidenceFactKey.vestedBenefitsCapitalChf: _authorityFact(
            ownerKind: LppEvidenceOwnerKind.manualPartner,
            ownerId: _partnerOwnerId,
            actorId: _selfOwnerId,
            now: now,
          ),
        },
      ),
    );

PartnerAccountabilityBinding _activeBinding(
  DateTime now, {
  String ownerId = _partnerOwnerId,
}) =>
    PartnerAccountabilityBinding(
      receiptId: _receiptId,
      manualPartnerOwnerId: ownerId,
      state: PartnerAccountabilityBindingState.active,
      createdAt: now.subtract(const Duration(days: 1)),
      noticeVersion: 'notice-v1',
      policyVersion: 'policy-v1',
      privacyContact: 'privacy@example.test',
      rightsChannel: 'https://example.test/rights',
      lppSnapshotId: _manualSnapshotId,
      lastVerifiedAt: now.subtract(const Duration(hours: 1)),
      receiptCreatedAt: now.subtract(const Duration(days: 1)),
      expiresAt: now.add(const Duration(days: 1)),
    );

Map<String, dynamic> _authorityAnswers(DateTime now) => <String, dynamic>{
      'q_birth_year': 1981,
      'q_canton': 'VD',
      'q_civil_status': 'marie',
      'q_partner_birth_year': 1982,
      '_coach_lpp_evidence_v1': _manualAuthorityRoot(now).toJsonString(),
    };

Map<String, dynamic> _independentOnlyAuthorityAnswers(DateTime now) {
  final root = _manualAuthorityRoot(now);
  return <String, dynamic>{
    ..._authorityAnswers(now),
    '_coach_lpp_evidence_v1': LppEvidenceRoot(
      self: root.self,
      manualPartner: LppEvidenceSnapshot(
        snapshotId: _manualSnapshotId,
        facts: const <LppEvidenceFactKey, LppEvidenceFact>{},
        independentFacts: <LppEvidenceFactKey, LppEvidenceFact>{
          LppEvidenceFactKey.vestedBenefitsCapitalChf: LppEvidenceFact(
            value: 100000,
            unit: LppEvidenceUnit.chf,
            profileOwnerId: _partnerOwnerId,
            actorProfileOwnerId: _selfOwnerId,
            ownerKind: LppEvidenceOwnerKind.manualPartner,
            authorizationMode:
                LppEvidenceAuthorizationMode.manualPartnerDeclaration,
            source: 'userInput',
            sourceDate: null,
            updatedAt: now.subtract(const Duration(hours: 2)),
          ),
        },
      ),
    ).toJsonString(),
  };
}

Map<String, dynamic> _certificateWithIndependentBaselineAnswers(DateTime now) {
  final root = _manualAuthorityRoot(now);
  return <String, dynamic>{
    ..._authorityAnswers(now),
    '_coach_lpp_evidence_v1': LppEvidenceRoot(
      self: root.self,
      manualPartner: LppEvidenceSnapshot(
        snapshotId: _manualSnapshotId,
        facts: <LppEvidenceFactKey, LppEvidenceFact>{
          ...root.manualPartner!.facts,
          LppEvidenceFactKey.retirementPensionAnnualChf: LppEvidenceFact(
            value: 24000,
            unit: LppEvidenceUnit.chfPerYear,
            profileOwnerId: _partnerOwnerId,
            actorProfileOwnerId: _selfOwnerId,
            ownerKind: LppEvidenceOwnerKind.manualPartner,
            authorizationMode:
                LppEvidenceAuthorizationMode.manualPartnerDeclaration,
            source: 'certificate',
            sourceDate: DateTime.utc(2026, 6, 30),
            updatedAt: now.subtract(const Duration(hours: 2)),
          ),
        },
        independentFacts: <LppEvidenceFactKey, LppEvidenceFact>{
          LppEvidenceFactKey.vestedBenefitsCapitalChf: LppEvidenceFact(
            value: 100000,
            unit: LppEvidenceUnit.chf,
            profileOwnerId: _partnerOwnerId,
            actorProfileOwnerId: _selfOwnerId,
            ownerKind: LppEvidenceOwnerKind.manualPartner,
            authorizationMode:
                LppEvidenceAuthorizationMode.manualPartnerDeclaration,
            source: 'userInput',
            sourceDate: null,
            updatedAt: now.subtract(const Duration(hours: 3)),
          ),
        },
      ),
    ).toJsonString(),
  };
}

Map<String, dynamic> _statusPayload(
  PartnerAccountabilityReceiptStatus status,
  DateTime now,
) =>
    <String, dynamic>{
      'receiptId': _receiptId,
      'status': status.name,
      'noticeVersion': 'notice-v1',
      'policyVersion': 'policy-v1',
      'expiresAt': status == PartnerAccountabilityReceiptStatus.expired
          ? now.subtract(const Duration(minutes: 1)).toIso8601String()
          : now.add(const Duration(days: 1)).toIso8601String(),
    };

Widget _authorityDetailApp({
  required CoachProfileProvider ledger,
  required DocumentProvider documents,
}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachProfileProvider>.value(value: ledger),
        ChangeNotifierProvider<DocumentProvider>.value(value: documents),
      ],
      child: const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: DocumentDetailScreen(documentId: _manualReferenceId),
      ),
    );

LppReviewConfirmation _manualConfirmation(DateTime now) =>
    LppReviewConfirmation(
      authorization: LppAcquisitionAuthorization(
        acquisitionId: '123e4567-e89b-42d3-a456-426614174099',
        subject: LppEvidenceOwnerKind.manualPartner,
        partnerAttested: true,
        policyVersion: LppAcquisitionAuthorization.currentPolicyVersion,
        declaredAt: now.subtract(const Duration(minutes: 5)),
        documentSha256:
            '9999999999999999999999999999999999999999999999999999999999999999',
        manualPartnerOwnerId: _partnerOwnerId,
        receiptId: _receiptId,
      ),
      sourceDate: DateTime.utc(2026, 6, 30),
      facts: const <LppEvidenceFactKey, LppReviewedFact>{
        LppEvidenceFactKey.vestedBenefitsCapitalChf: LppReviewedFact(
          value: 125000,
          unit: LppEvidenceUnit.chf,
        ),
      },
      partnerAccountabilityContext: ManualPartnerAccountabilityContext(
        receiptId: _receiptId,
        ownerId: _partnerOwnerId,
        expiresAt: now.add(const Duration(hours: 1)),
        noticeVersion: 'notice-v1',
        policyVersion: 'policy-v1',
        receiptStatus: PartnerAccountabilityReceiptStatus.active,
      ),
    );

LppAcquisitionAuthorization _selfAuthorization(DateTime declaredAt) {
  return LppAcquisitionAuthorization(
    acquisitionId: '123e4567-e89b-42d3-a456-426614174000',
    subject: LppEvidenceOwnerKind.self,
    partnerAttested: false,
    policyVersion: LppAcquisitionAuthorization.currentPolicyVersion,
    declaredAt: declaredAt,
    documentSha256:
        '1111111111111111111111111111111111111111111111111111111111111111',
  );
}

LppReviewConfirmation _syntheticConfirmation(
  DateTime now, {
  double total = 125000,
  double disability = 24000,
}) {
  return LppReviewConfirmation(
    authorization: _selfAuthorization(now.subtract(const Duration(minutes: 5))),
    sourceDate: DateTime.utc(2026, 6, 30),
    facts: <LppEvidenceFactKey, LppReviewedFact>{
      LppEvidenceFactKey.vestedBenefitsCapitalChf: LppReviewedFact(
        value: total,
        unit: LppEvidenceUnit.chf,
      ),
      LppEvidenceFactKey.disabilityPensionAnnualChf: LppReviewedFact(
        value: disability,
        unit: LppEvidenceUnit.chfPerYear,
      ),
    },
  );
}

_MemoryProfilePersistence _profilePersistence() {
  return _MemoryProfilePersistence(<String, dynamic>{
    'q_birth_year': 1981,
    'q_canton': 'VD',
    'q_civil_status': 'celibataire',
    'q_has_pension_fund': 'yes',
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.partnerLppAccountabilityEnabled = true;
  });

  tearDown(() {
    FeatureFlags.typedLppEvidence = false;
    FeatureFlags.partnerLppAccountabilityEnabled = false;
  });

  test('strict self review persists selected facts before returning receipt',
      () async {
    final now = DateTime.utc(2026, 7, 16, 12);
    final sourceDate = DateTime.utc(2026, 6, 30);
    final persistence = _profilePersistence();
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => now,
    );
    addTearDown(provider.dispose);
    await provider.loadFromWizard();

    const selectedFactKeys = <LppEvidenceFactKey>{
      LppEvidenceFactKey.vestedBenefitsCapitalChf,
      LppEvidenceFactKey.disabilityPensionAnnualChf,
    };
    final authorization =
        _selfAuthorization(now.subtract(const Duration(hours: 1)));
    const rawSentinel = 'RAW_OCR_BND05_DEATH_CAPITAL_91000';
    final candidateFacts = <LppEvidenceFactKey, LppReviewedFact>{
      LppEvidenceFactKey.vestedBenefitsCapitalChf: const LppReviewedFact(
        value: 125000,
        unit: LppEvidenceUnit.chf,
      ),
      LppEvidenceFactKey.disabilityPensionAnnualChf: const LppReviewedFact(
        value: 24000,
        unit: LppEvidenceUnit.chfPerYear,
      ),
      LppEvidenceFactKey.deathCapitalLumpSumChf: const LppReviewedFact(
        value: 91000,
        unit: LppEvidenceUnit.chfLumpSum,
      ),
    };
    final syntheticCandidateEnvelope = <String, Object?>{
      'facts': candidateFacts,
      'sourceText': rawSentinel,
      'acquisitionId': authorization.acquisitionId,
      'documentSha256': authorization.documentSha256,
    };
    expect(
      (syntheticCandidateEnvelope['facts']
              as Map<LppEvidenceFactKey, LppReviewedFact>)
          .keys,
      contains(LppEvidenceFactKey.deathCapitalLumpSumChf),
    );

    final receipt = await provider.acceptLppReview(
      LppReviewConfirmation(
        authorization: authorization,
        sourceDate: sourceDate,
        facts: <LppEvidenceFactKey, LppReviewedFact>{
          for (final key in selectedFactKeys) key: candidateFacts[key]!,
        },
      ),
    );

    final persistedSerialization =
        persistence.lastSaved!['_coach_lpp_evidence_v1'] as String;
    final persistedRoot =
        LppEvidenceRoot.fromJsonString(persistedSerialization);
    expect(persistedRoot, isNotNull);
    expect(persistedRoot!.manualPartner, isNull);
    expect(persistedRoot.self, isNotNull);
    expect(persistedRoot.self!.facts.keys.toSet(), selectedFactKeys);
    expect(
      persistedRoot.self!.facts,
      isNot(contains(LppEvidenceFactKey.deathCapitalLumpSumChf)),
    );
    for (final fact in persistedRoot.self!.facts.values) {
      expect(fact.source, 'certificate');
      expect(fact.sourceDate, sourceDate);
      expect(fact.ownerKind, LppEvidenceOwnerKind.self);
      expect(fact.profileOwnerId, fact.actorProfileOwnerId);
    }
    expect(
      persistedRoot.self!.facts.values
          .map((fact) => fact.updatedAt.toUtc())
          .toSet(),
      hasLength(1),
    );
    for (final forbidden in <String>[
      rawSentinel,
      authorization.acquisitionId,
      authorization.documentSha256,
      'sourceText',
    ]) {
      expect(persistedSerialization, isNot(contains(forbidden)));
    }

    expect(receipt.snapshotId, persistedRoot.self!.snapshotId);
    expect(receipt.ownerKind, LppEvidenceOwnerKind.self);
    expect(receipt.factKeys, selectedFactKeys);
    expect(
      () => receipt.factKeys.add(LppEvidenceFactKey.deathCapitalLumpSumChf),
      throwsUnsupportedError,
    );
    expect(provider.currentLppSnapshotId(LppEvidenceOwnerKind.self),
        receipt.snapshotId);
    expect(provider.currentLppSnapshot(LppEvidenceOwnerKind.self)!.facts.keys,
        selectedFactKeys);
  });

  test('reference JSON and persisted root are exact raw-free allowlists',
      () async {
    final confirmedAt = DateTime.utc(2026, 7, 16, 14, 30);
    final reference = ConfirmedDocumentReference(
      referenceId: '123e4567-e89b-42d3-a456-426614174001',
      kind: ConfirmedDocumentReference.lppKind,
      snapshotId: '123e4567-e89b-42d3-a456-426614174002',
      ownerKind: LppEvidenceOwnerKind.self,
      confirmedAt: confirmedAt,
    );
    final json = reference.toJson();
    expect(json.keys.toSet(), <String>{
      'referenceId',
      'kind',
      'snapshotId',
      'ownerKind',
      'confirmedAt',
    });
    final decoded = ConfirmedDocumentReference.fromJson(json);
    expect(decoded, isNotNull);
    expect(decoded!.referenceId, reference.referenceId);
    expect(decoded.snapshotId, reference.snapshotId);
    expect(decoded.ownerKind, reference.ownerKind);
    expect(decoded.confirmedAt, confirmedAt);

    for (final mutation in <Map<String, dynamic>>[
      <String, dynamic>{...json, 'sourceText': 'RAW_FORBIDDEN'},
      <String, dynamic>{...json, 'value': 125000},
      <String, dynamic>{...json, 'acquisitionId': 'volatile-id'},
      <String, dynamic>{...json, 'documentSha256': 'private-sha'},
      <String, dynamic>{...json, 'kind': 'salary'},
      <String, dynamic>{...json, 'referenceId': 'not-a-uuid'},
      <String, dynamic>{...json, 'snapshotId': 'not-a-uuid'},
      <String, dynamic>{...json, 'ownerKind': 'unknown'},
      <String, dynamic>{...json, 'confirmedAt': '2026-07-16T14:30:00+00:00'},
    ]) {
      expect(ConfirmedDocumentReference.fromJson(mutation), isNull);
    }

    final store = DocumentReferenceStore();
    await store.save(<ConfirmedDocumentReference>[reference]);
    final preferences = await SharedPreferences.getInstance();
    final persisted = preferences.getString(DocumentReferenceStore.storageKey)!;
    final root = jsonDecode(persisted) as Map<String, dynamic>;
    expect(root.keys.toSet(), <String>{'schemaVersion', 'references'});
    expect(root['schemaVersion'], DocumentReferenceStore.schemaVersion);
    expect((root['references'] as List), hasLength(1));
    expect((root['references'] as List).single, json);
    for (final forbidden in <String>[
      'RAW_FORBIDDEN',
      '125000',
      '24000',
      'sourceText',
      'acquisitionId',
      'documentSha256',
      'scanSessionId',
      'filename',
      'rawOcr',
      'value',
    ]) {
      expect(persisted, isNot(contains(forbidden)));
    }
  });

  test(
      'hydrate-before-ledger leaks nothing, idempotent reference survives restart and snapshot swap invalidates it',
      () async {
    final now = DateTime.utc(2026, 7, 16, 14);
    final persistence = _profilePersistence();
    final writer = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => now,
    );
    addTearDown(writer.dispose);
    await writer.loadFromWizard();
    final receipt = await writer.acceptLppReview(_syntheticConfirmation(now));

    final documentWriter = DocumentProvider(now: () => now);
    addTearDown(documentWriter.dispose);
    documentWriter.bindLedger(writer);
    final reference = await documentWriter.recordConfirmedLppReview(receipt);
    final retryReference =
        await documentWriter.recordConfirmedLppReview(receipt);
    expect(retryReference.referenceId, reference.referenceId);

    final preferences = await SharedPreferences.getInstance();
    final persisted = preferences.getString(DocumentReferenceStore.storageKey)!;
    final persistedRoot = jsonDecode(persisted) as Map<String, dynamic>;
    expect((persistedRoot['references'] as List), hasLength(1));
    for (final forbidden in <String>[
      '125000',
      '24000',
      '1111111111111111111111111111111111111111111111111111111111111111',
      '123e4567-e89b-42d3-a456-426614174000',
    ]) {
      expect(persisted, isNot(contains(forbidden)));
    }

    final coldLedger = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => now,
    );
    addTearDown(coldLedger.dispose);
    final coldDocuments = DocumentProvider();
    addTearDown(coldDocuments.dispose);
    await coldDocuments.hydrateReferences();
    expect(coldDocuments.referencesHydrated, isTrue);
    expect(coldDocuments.byId(reference.referenceId), isNull);
    coldDocuments.bindLedger(coldLedger);
    expect(coldDocuments.byId(reference.referenceId), isNull);

    await coldLedger.loadFromWizard();
    final resolved = coldDocuments.byId(reference.referenceId);
    expect(resolved, isNotNull);
    expect(resolved!.referenceId, reference.referenceId);
    expect(resolved.snapshotId, receipt.snapshotId);
    expect(resolved.ownerKind, LppEvidenceOwnerKind.self);

    final timeline = TimelineProvider();
    addTearDown(timeline.dispose);
    timeline.bindLedger(coldLedger);
    await timeline.refresh();
    final documentNodes = timeline.months
        .expand((month) => month.nodes)
        .where((node) => node.id == 'document_${reference.referenceId}')
        .toList();
    expect(documentNodes, hasLength(1));
    expect(
        documentNodes.single.deepLink, '/documents/${reference.referenceId}');
    expect(documentNodes.single.subtitle, isEmpty);

    final replacementReceipt = await coldLedger.acceptLppReview(
      _syntheticConfirmation(now, total: 131000, disability: 25200),
    );
    expect(replacementReceipt.snapshotId, isNot(receipt.snapshotId));
    expect(coldDocuments.byId(reference.referenceId), isNull);
    expect(coldDocuments.hasStoredReference(reference.referenceId), isTrue);
    await expectLater(
      coldDocuments.recordConfirmedLppReview(receipt),
      throwsStateError,
    );
    await timeline.refresh();
    expect(
      timeline.months
          .expand((month) => month.nodes)
          .where((node) => node.id == 'document_${reference.referenceId}'),
      isEmpty,
    );
  });

  test('manual-partner references fail closed without current authority',
      () async {
    final now = DateTime.utc(2026, 7, 16, 14);
    final cases = <({
      String name,
      bool accountabilityFlag,
      String bindingOwnerId,
      Object status,
      bool independentOnly,
    })>[
      (
        name: 'revoked',
        accountabilityFlag: true,
        bindingOwnerId: _partnerOwnerId,
        independentOnly: false,
        status: _statusPayload(
          PartnerAccountabilityReceiptStatus.revoked,
          now,
        ),
      ),
      (
        name: 'expired',
        accountabilityFlag: true,
        bindingOwnerId: _partnerOwnerId,
        independentOnly: false,
        status: _statusPayload(
          PartnerAccountabilityReceiptStatus.expired,
          now,
        ),
      ),
      (
        name: 'offline-partial',
        accountabilityFlag: true,
        bindingOwnerId: _partnerOwnerId,
        independentOnly: false,
        status: const PartnerAccountabilityException(
          PartnerAccountabilityReceiptStatus.offline,
          retryable: true,
        ),
      ),
      (
        name: 'flag-off',
        accountabilityFlag: false,
        bindingOwnerId: _partnerOwnerId,
        independentOnly: false,
        status: _statusPayload(
          PartnerAccountabilityReceiptStatus.active,
          now,
        ),
      ),
      (
        name: 'owner-mismatch',
        accountabilityFlag: true,
        bindingOwnerId: _mismatchOwnerId,
        independentOnly: false,
        status: _statusPayload(
          PartnerAccountabilityReceiptStatus.active,
          now,
        ),
      ),
      (
        name: 'independent-only',
        accountabilityFlag: true,
        bindingOwnerId: _partnerOwnerId,
        independentOnly: true,
        status: _statusPayload(
          PartnerAccountabilityReceiptStatus.active,
          now,
        ),
      ),
    ];

    for (final scenario in cases) {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      FeatureFlags.partnerLppAccountabilityEnabled =
          scenario.accountabilityFlag;
      final reference = ConfirmedDocumentReference(
        referenceId: _manualReferenceId,
        kind: ConfirmedDocumentReference.lppKind,
        snapshotId: _manualSnapshotId,
        ownerKind: LppEvidenceOwnerKind.manualPartner,
        confirmedAt: now,
      );
      await DocumentReferenceStore().save(<ConfirmedDocumentReference>[
        reference,
      ]);
      final persistence = _MemoryProfilePersistence(
        scenario.independentOnly
            ? _independentOnlyAuthorityAnswers(now)
            : _authorityAnswers(now),
      );
      final bindingPersistence = _MemoryBindingPersistence(
        PartnerAccountabilityBindingEnvelope(
          active: _activeBinding(
            now,
            ownerId: scenario.bindingOwnerId,
          ),
        ).toJsonString(),
      );
      final ledger = CoachProfileProvider(
        taxProfilePersistence: persistence,
        lppProfilePersistence: persistence,
        partnerAccountabilityBindingStore: PartnerAccountabilityBindingStore(
          persistence: bindingPersistence,
        ),
        partnerAccountabilityService: PartnerAccountabilityService(
          api: _AuthorityApi(scenario.status),
        ),
        now: () => now,
      );
      final documents = DocumentProvider(now: () => now);
      final timeline = TimelineProvider();
      try {
        await ledger.loadFromWizard();
        documents.bindLedger(ledger);
        await documents.hydrateReferences();
        timeline.bindLedger(ledger);
        await timeline.refresh();

        expect(
          ledger.currentLppSnapshot(LppEvidenceOwnerKind.manualPartner),
          isNull,
          reason: scenario.name,
        );
        expect(
          documents.byId(_manualReferenceId),
          isNull,
          reason: scenario.name,
        );
        expect(
          timeline.months
              .expand((month) => month.nodes)
              .where((node) => node.id == 'document_$_manualReferenceId'),
          isEmpty,
          reason: scenario.name,
        );
        if (scenario.independentOnly) {
          await expectLater(
            documents.recordConfirmedLppReview(
              LppReviewReceipt(
                snapshotId: _manualSnapshotId,
                ownerKind: LppEvidenceOwnerKind.manualPartner,
                factKeys: const <LppEvidenceFactKey>{
                  LppEvidenceFactKey.vestedBenefitsCapitalChf,
                },
              ),
            ),
            throwsStateError,
          );
        }
      } finally {
        timeline.dispose();
        documents.dispose();
        ledger.dispose();
      }
    }
  });

  testWidgets(
      'manual-partner detail and timeline invalidate at authority deadline without mutation',
      (tester) async {
    var now = DateTime.utc(2026, 7, 16, 14);
    final authorityExpiry = now.add(const Duration(hours: 1));
    final reference = ConfirmedDocumentReference(
      referenceId: _manualReferenceId,
      kind: ConfirmedDocumentReference.lppKind,
      snapshotId: _manualSnapshotId,
      ownerKind: LppEvidenceOwnerKind.manualPartner,
      confirmedAt: now,
    );
    await DocumentReferenceStore().save(<ConfirmedDocumentReference>[
      reference,
    ]);
    final persistence = _MemoryProfilePersistence(_authorityAnswers(now));
    final bindingPersistence = _MemoryBindingPersistence(
      PartnerAccountabilityBindingEnvelope(
        active: _activeBinding(now).copyWith(expiresAt: authorityExpiry),
      ).toJsonString(),
    );
    final ledger = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      partnerAccountabilityBindingStore: PartnerAccountabilityBindingStore(
        persistence: bindingPersistence,
      ),
      partnerAccountabilityService: PartnerAccountabilityService(
        api: _AuthorityApi(<String, dynamic>{
          ..._statusPayload(PartnerAccountabilityReceiptStatus.active, now),
          'expiresAt': authorityExpiry.toIso8601String(),
        }),
      ),
      now: () => now,
    );
    final documents = DocumentProvider(now: () => now);
    final timeline = TimelineProvider();
    addTearDown(ledger.dispose);
    addTearDown(documents.dispose);
    addTearDown(timeline.dispose);
    await ledger.loadFromWizard();
    documents.bindLedger(ledger);
    await documents.hydrateReferences();
    timeline.bindLedger(ledger);
    timeline.bindDocuments(documents);
    timeline.activateAfterSessionReady();

    await tester.pumpWidget(
      _authorityDetailApp(ledger: ledger, documents: documents),
    );
    await tester.pump();
    expect(find.text("CHF 125'000"), findsOneWidget);
    expect(
      timeline.months
          .expand((month) => month.nodes)
          .where((node) => node.id == 'document_$_manualReferenceId'),
      hasLength(1),
    );

    now = authorityExpiry;
    await tester.pump(const Duration(hours: 1));
    await tester.pump();

    expect(
      find.byKey(const Key('document_reference_stale_state')),
      findsOneWidget,
    );
    expect(find.text("CHF 125'000"), findsNothing);
    expect(
      timeline.months
          .expand((month) => month.nodes)
          .where((node) => node.id == 'document_$_manualReferenceId'),
      isEmpty,
    );
  });

  testWidgets(
      'mounted retirement projection drops partner certificate at authority deadline but keeps independent baseline',
      (tester) async {
    final startedAt = DateTime.utc(2026, 7, 16, 15);
    var now = startedAt;
    final receiptExpiry = startedAt.add(const Duration(hours: 10));
    final persistence = _MemoryProfilePersistence(
      _certificateWithIndependentBaselineAnswers(startedAt),
    );
    final bindingPersistence = _MemoryBindingPersistence(
      PartnerAccountabilityBindingEnvelope(
        active: _activeBinding(startedAt).copyWith(expiresAt: receiptExpiry),
      ).toJsonString(),
    );
    final ledger = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      partnerAccountabilityBindingStore: PartnerAccountabilityBindingStore(
        persistence: bindingPersistence,
      ),
      partnerAccountabilityService: PartnerAccountabilityService(
        api: _AuthorityApi(<String, dynamic>{
          ..._statusPayload(
            PartnerAccountabilityReceiptStatus.active,
            startedAt,
          ),
          'expiresAt': receiptExpiry.toIso8601String(),
        }),
      ),
      now: () => now,
    );
    addTearDown(ledger.dispose);
    await ledger.loadFromWizard();
    final runtimeCheckIn = MonthlyCheckIn(
      month: DateTime.utc(2026, 7),
      versements: const <String, double>{'runtime': 50},
      completedAt: startedAt,
    );
    const runtimeContribution = PlannedMonthlyContribution(
      id: 'runtime_non_lpp',
      label: 'Runtime',
      amount: 75,
      category: 'epargne_libre',
    );
    await ledger.addCheckIn(runtimeCheckIn);
    ledger.addContribution(runtimeContribution);

    final projectedPartnerCapitals = <double?>[];
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CoachProfileProvider>.value(value: ledger),
          ChangeNotifierProvider<ByokProvider>(create: (_) => ByokProvider()),
          ChangeNotifierProvider<SlmProvider>(create: (_) => SlmProvider()),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: RetirementDashboardScreen(
            projectionBuilder: (profile) {
              projectedPartnerCapitals
                  .add(profile.conjoint?.prevoyance?.avoirLppTotal);
              return ForecasterService.project(profile: profile);
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(projectedPartnerCapitals.last, 125000);
    expect(
      ledger.profile!.conjoint!.prevoyance!.projectedRenteLpp,
      24000,
    );

    now = startedAt.add(const Duration(hours: 6));
    await tester.pump(const Duration(hours: 6));
    await tester.pump();

    expect(
      ledger.currentLppSnapshot(LppEvidenceOwnerKind.manualPartner),
      isNull,
    );
    expect(
      ledger.profile!.conjoint!.prevoyance!.avoirLppTotal,
      100000,
      reason: 'The independent userInput baseline must survive invalidation.',
    );
    expect(
      projectedPartnerCapitals.last,
      100000,
      reason:
          'The mounted financial consumer must lose the CHF 25k certificate delta.',
    );
    final capitalPath =
        LppEvidenceFactKey.vestedBenefitsCapitalChf.manualPartnerProfilePath;
    final pensionPath =
        LppEvidenceFactKey.retirementPensionAnnualChf.manualPartnerProfilePath;
    expect(
        ledger.profile!.dataSources[capitalPath], ProfileDataSource.userInput);
    expect(
      ledger.profile!.dataTimestamps[capitalPath],
      startedAt.subtract(const Duration(hours: 3)),
    );
    expect(ledger.profile!.dataSourceDates.containsKey(capitalPath), isTrue);
    expect(ledger.profile!.dataSourceDates[capitalPath], isNull);
    expect(
      ledger.profile!.conjoint!.prevoyance!.projectedRenteLpp,
      isNull,
    );
    expect(ledger.profile!.dataSources.containsKey(pensionPath), isFalse);
    expect(ledger.profile!.dataTimestamps.containsKey(pensionPath), isFalse);
    expect(ledger.profile!.dataSourceDates.containsKey(pensionPath), isFalse);
    expect(ledger.profile!.checkIns, contains(runtimeCheckIn));
    expect(
      ledger.profile!.plannedContributions,
      contains(runtimeContribution),
    );
  });

  testWidgets(
      'manual-partner metadata retry accepts committed receipt after authority expiry but stays hidden',
      (tester) async {
    var now = DateTime.utc(2026, 7, 16, 16);
    final authorityExpiry = now.add(const Duration(hours: 1));
    final persistence = _MemoryProfilePersistence(<String, dynamic>{
      'q_birth_year': 1981,
      'q_canton': 'VD',
      'q_civil_status': 'marie',
      'q_partner_birth_year': 1982,
    });
    final pending = PartnerAccountabilityBinding(
      receiptId: _receiptId,
      manualPartnerOwnerId: _partnerOwnerId,
      state: PartnerAccountabilityBindingState.pending,
      createdAt: now.subtract(const Duration(minutes: 10)),
      noticeVersion: 'notice-v1',
      policyVersion: 'policy-v1',
      privacyContact: 'privacy@example.test',
      rightsChannel: 'https://example.test/rights',
      receiptCreatedAt: now.subtract(const Duration(minutes: 5)),
      expiresAt: authorityExpiry,
    );
    final bindingStore = PartnerAccountabilityBindingStore(
      persistence: _MemoryBindingPersistence(
        PartnerAccountabilityBindingEnvelope(pending: pending).toJsonString(),
      ),
    );
    final ledger = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      partnerAccountabilityBindingStore: bindingStore,
      now: () => now,
    );
    final store = _FailOnceMemoryReferenceStore();
    final documents = DocumentProvider(referenceStore: store, now: () => now);
    final timeline = TimelineProvider();
    addTearDown(ledger.dispose);
    addTearDown(documents.dispose);
    addTearDown(timeline.dispose);
    await ledger.loadFromWizard();
    final receipt = await ledger.acceptLppReview(_manualConfirmation(now));
    final ledgerSaveCalls = persistence.saveCalls;
    documents.bindLedger(ledger);

    await expectLater(
      documents.recordConfirmedLppReview(receipt),
      throwsStateError,
    );
    expect(store.saveCalls, 1);

    now = authorityExpiry;
    await tester.pump(const Duration(hours: 1));
    final reference = await documents.recordConfirmedLppReview(receipt);

    expect(store.saveCalls, 2);
    expect(store.references.single.referenceId, reference.referenceId);
    expect(persistence.saveCalls, ledgerSaveCalls);
    expect(documents.byId(reference.referenceId), isNull);
    expect(documents.currentReferences, isEmpty);
    timeline.bindLedger(ledger);
    timeline.bindDocuments(documents);
    await tester.pump();
    expect(
      timeline.months
          .expand((month) => month.nodes)
          .where((node) => node.id == 'document_${reference.referenceId}'),
      isEmpty,
    );
  });

  test('timeline reacts to reference record delete and snapshot replacement',
      () async {
    final now = DateTime.utc(2026, 7, 16, 14);
    final persistence = _profilePersistence();
    final ledger = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => now,
    );
    final documents = DocumentProvider(now: () => now);
    final timeline = TimelineProvider();
    addTearDown(ledger.dispose);
    addTearDown(documents.dispose);
    addTearDown(timeline.dispose);
    await ledger.loadFromWizard();
    documents.bindLedger(ledger);
    await documents.hydrateReferences();
    timeline.bindLedger(ledger);
    timeline.bindDocuments(documents);

    final receipt = await ledger.acceptLppReview(_syntheticConfirmation(now));
    final reference = await documents.recordConfirmedLppReview(receipt);
    await Future<void>.delayed(Duration.zero);
    expect(
      timeline.months
          .expand((month) => month.nodes)
          .where((node) => node.id == 'document_${reference.referenceId}'),
      hasLength(1),
    );

    await documents.deleteConfirmedReference(reference.referenceId);
    await Future<void>.delayed(Duration.zero);
    expect(
      timeline.months
          .expand((month) => month.nodes)
          .where((node) => node.id == 'document_${reference.referenceId}'),
      isEmpty,
    );

    final recreated = await documents.recordConfirmedLppReview(receipt);
    await Future<void>.delayed(Duration.zero);
    expect(
      timeline.months
          .expand((month) => month.nodes)
          .where((node) => node.id == 'document_${recreated.referenceId}'),
      hasLength(1),
    );
    await ledger.acceptLppReview(
      _syntheticConfirmation(now, total: 131000, disability: 25200),
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      timeline.months
          .expand((month) => month.nodes)
          .where((node) => node.id == 'document_${recreated.referenceId}'),
      isEmpty,
    );
  });

  test('reference persistence failure never rolls back accepted ledger facts',
      () async {
    final now = DateTime.utc(2026, 7, 16, 15);
    final persistence = _profilePersistence();
    final ledger = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => now,
    );
    addTearDown(ledger.dispose);
    await ledger.loadFromWizard();
    final receipt = await ledger.acceptLppReview(_syntheticConfirmation(now));
    final acceptedRoot = persistence.lastSaved!['_coach_lpp_evidence_v1'];

    final failingStore = DocumentReferenceStore(
      preferencesLoader: () async =>
          throw StateError('synthetic store failure'),
    );
    final documents = DocumentProvider(referenceStore: failingStore);
    addTearDown(documents.dispose);
    documents.bindLedger(ledger);
    await expectLater(
      documents.recordConfirmedLppReview(receipt),
      throwsA(isA<StateError>()),
    );

    expect(persistence.lastSaved!['_coach_lpp_evidence_v1'], acceptedRoot);
    final snapshot = ledger.currentLppSnapshot(LppEvidenceOwnerKind.self);
    expect(snapshot, isNotNull);
    expect(snapshot!.snapshotId, receipt.snapshotId);
    expect(snapshot.facts.keys.toSet(), receipt.factKeys);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(DocumentReferenceStore.storageKey), isNull);
  });

  test('malformed or raw-bearing reference roots fail closed as a whole',
      () async {
    final invalidReference = <String, dynamic>{
      'referenceId': '123e4567-e89b-42d3-a456-426614174001',
      'kind': ConfirmedDocumentReference.lppKind,
      'snapshotId': '123e4567-e89b-42d3-a456-426614174002',
      'ownerKind': LppEvidenceOwnerKind.self.wireName,
      'confirmedAt': DateTime.utc(2026, 7, 16, 14).toIso8601String(),
      'sourceText': 'RAW_FORBIDDEN',
    };
    SharedPreferences.setMockInitialValues(<String, Object>{
      DocumentReferenceStore.storageKey: jsonEncode(<String, dynamic>{
        'schemaVersion': DocumentReferenceStore.schemaVersion,
        'references': <Map<String, dynamic>>[invalidReference],
      }),
    });
    final store = DocumentReferenceStore();
    await expectLater(store.load(), throwsFormatException);

    final provider = DocumentProvider(referenceStore: store);
    addTearDown(provider.dispose);
    await expectLater(provider.hydrateReferences(), throwsFormatException);
    expect(provider.referencesHydrated, isFalse);
    expect(provider.byId(invalidReference['referenceId'] as String), isNull);
  });

  test('deleting a reference removes only metadata, never strict ledger facts',
      () async {
    final now = DateTime.utc(2026, 7, 16, 16);
    final persistence = _profilePersistence();
    final ledger = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => now,
    );
    addTearDown(ledger.dispose);
    await ledger.loadFromWizard();
    final receipt = await ledger.acceptLppReview(_syntheticConfirmation(now));
    final acceptedRoot = persistence.lastSaved!['_coach_lpp_evidence_v1'];
    final documents = DocumentProvider();
    addTearDown(documents.dispose);
    documents.bindLedger(ledger);
    final reference = await documents.recordConfirmedLppReview(receipt);

    await documents.deleteConfirmedReference(reference.referenceId);

    expect(documents.byId(reference.referenceId), isNull);
    expect(documents.hasStoredReference(reference.referenceId), isFalse);
    expect(persistence.lastSaved!['_coach_lpp_evidence_v1'], acceptedRoot);
    expect(ledger.currentLppSnapshotId(LppEvidenceOwnerKind.self),
        receipt.snapshotId);
  });

  test('production route and providers wire the bridge without a facade', () {
    final appSource = File('lib/app.dart').readAsStringSync();
    final reviewSource = File(
      'lib/screens/document_scan/extraction_review_screen.dart',
    ).readAsStringSync();
    final detailSource =
        File('lib/screens/document_detail_screen.dart').readAsStringSync();
    final timelineSource =
        File('lib/providers/timeline_provider.dart').readAsStringSync();

    expect(
      appSource,
      contains(
        'ChangeNotifierProxyProvider<CoachProfileProvider, DocumentProvider>',
      ),
    );
    expect(appSource, contains('provider.bindLedger(profileProvider)'));
    expect(appSource, contains('AccountSessionInitializer('));
    expect(
      appSource,
      contains('context.read<DocumentProvider>().hydrateReferences()'),
    );
    expect(appSource, isNot(contains('provider.hydrateReferences().ignore()')));
    expect(appSource, contains('recordConfirmedLppReview:'));
    expect(appSource, contains('context.read<DocumentProvider>()'));
    expect(
      appSource,
      contains(
        'ChangeNotifierProxyProvider2<CoachProfileProvider, DocumentProvider,',
      ),
    );
    expect(appSource, contains('provider.bindDocuments(documentProvider)'));
    expect(reviewSource, contains('await coachProvider.acceptLppReview'));
    expect(reviewSource, contains('_partnerReceiptFinalized = true'));
    expect(reviewSource, contains('await referenceRecorder'));
    expect(detailSource, contains('currentLppSnapshot(reference.ownerKind)'));
    expect(detailSource, contains('snapshot.facts'));
    expect(detailSource, contains('!isStoredReference'));
    expect(timelineSource, isNot(contains('_uploaded_documents')));
    expect(timelineSource, contains("deepLink: '/documents/"));
  });
}
