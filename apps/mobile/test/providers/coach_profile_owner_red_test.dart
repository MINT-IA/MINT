import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/coach_profile_owner.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/plan_generation_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ownerRootKey = '_coach_profile_owner_v1';
const _lppRootKey = '_coach_lpp_evidence_v1';
const _taxRootKey = '_coach_tax_snapshots_v1';
const _selfOwner = '11111111-1111-4111-8111-111111111111';
const _otherOwner = '22222222-2222-4222-8222-222222222222';
const _partnerOwner = '33333333-3333-4333-8333-333333333333';
const _snapshotId = '44444444-4444-4444-8444-444444444444';
final _canonicalUuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

final class _DelayedOwnerPersistence
    with SerializedCanonicalAnswerMutationPersistence
    implements TaxProfilePersistence, LppProfilePersistence {
  _DelayedOwnerPersistence(this.answers);

  final Map<String, dynamic> answers;
  final firstSaveStarted = Completer<void>();
  final releaseFirstSave = Completer<void>();
  var saveAttempts = 0;

  @override
  Future<Map<String, dynamic>> loadAnswers() async =>
      Map<String, dynamic>.from(answers);

  @override
  Future<void> saveAnswers(Map<String, dynamic> next) async {
    saveAttempts += 1;
    if (saveAttempts == 1) {
      firstSaveStarted.complete();
      await releaseFirstSave.future;
    }
    answers
      ..clear()
      ..addAll(Map<String, dynamic>.from(next));
  }
}

final class _FailingOwnerPersistence
    with SerializedCanonicalAnswerMutationPersistence
    implements TaxProfilePersistence, LppProfilePersistence {
  _FailingOwnerPersistence(this.answers);

  final Map<String, dynamic> answers;
  var saveAttempts = 0;

  @override
  Future<Map<String, dynamic>> loadAnswers() async =>
      Map<String, dynamic>.from(answers);

  @override
  Future<void> saveAnswers(Map<String, dynamic> next) async {
    saveAttempts += 1;
    throw StateError('simulated secure persistence failure');
  }
}

final class _FailOnceOwnerPersistence
    with SerializedCanonicalAnswerMutationPersistence
    implements TaxProfilePersistence, LppProfilePersistence {
  _FailOnceOwnerPersistence(this.answers);

  final Map<String, dynamic> answers;
  var saveAttempts = 0;

  @override
  Future<Map<String, dynamic>> loadAnswers() async =>
      Map<String, dynamic>.from(answers);

  @override
  Future<void> saveAnswers(Map<String, dynamic> next) async {
    saveAttempts += 1;
    if (saveAttempts == 1) {
      throw StateError('simulated one-shot persistence failure');
    }
    answers
      ..clear()
      ..addAll(Map<String, dynamic>.from(next));
  }
}

final class _RecordingOwnerPersistence
    with SerializedCanonicalAnswerMutationPersistence
    implements TaxProfilePersistence, LppProfilePersistence {
  _RecordingOwnerPersistence(Map<String, dynamic> answers)
      : answers = Map<String, dynamic>.from(answers);

  final Map<String, dynamic> answers;
  var saveAttempts = 0;

  @override
  Future<Map<String, dynamic>> loadAnswers() async =>
      Map<String, dynamic>.from(answers);

  @override
  Future<void> saveAnswers(Map<String, dynamic> next) async {
    saveAttempts += 1;
    answers
      ..clear()
      ..addAll(Map<String, dynamic>.from(next));
  }
}

LppEvidenceFact _lppFact({
  required String ownerId,
  required String actorId,
  required LppEvidenceOwnerKind ownerKind,
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
      updatedAt: DateTime.utc(2026, 7, 1, 12),
    );

String _selfLppRoot(String ownerId) => LppEvidenceRoot(
      self: LppEvidenceSnapshot(
        snapshotId: _snapshotId,
        facts: {
          LppEvidenceFactKey.vestedBenefitsCapitalChf: _lppFact(
            ownerId: ownerId,
            actorId: ownerId,
            ownerKind: LppEvidenceOwnerKind.self,
          ),
        },
      ),
    ).toJsonString();

String _manualOnlyLppRoot({
  required String actorOwnerId,
  String partnerOwnerId = _partnerOwner,
}) =>
    LppEvidenceRoot(
      self: null,
      manualPartner: LppEvidenceSnapshot(
        snapshotId: _snapshotId,
        facts: {
          LppEvidenceFactKey.vestedBenefitsCapitalChf: _lppFact(
            ownerId: partnerOwnerId,
            actorId: actorOwnerId,
            ownerKind: LppEvidenceOwnerKind.manualPartner,
          ),
        },
      ),
    ).toJsonString();

String _taxRoot(String ownerId) => jsonEncode({
      'schemaVersion': 1,
      'snapshots': [
        TaxSnapshot(
          snapshotId: _snapshotId,
          profileOwnerId: ownerId,
          taxYear: 2025,
          basedOnTaxYear: null,
          sourceDate: DateTime.utc(2026, 6, 30),
          documentKind: TaxDocumentKind.assessmentNotice,
          assessmentStatus: TaxAssessmentStatus.assessedAppealable,
          subjectScope: TaxSubjectScope.individual,
          cantonCode: 'VD',
          municipalityId: null,
          municipalityLabel: null,
          cantonalCommunalTaxableIncomeChf: 98500,
          federalTaxableIncomeChf: null,
          cantonalCommunalTaxableWealthChf: null,
          cantonalCommunalAssessedTax: null,
          federalDirectAssessedTax: null,
          explicitMarginalIncomeTaxRate: null,
          explicitAverageIncomeTaxRate: null,
          updatedAt: DateTime.utc(2026, 7, 1, 12),
        ).toJson(),
      ],
      'legacyQuarantine': null,
    });

LppReviewConfirmation _selfLppConfirmation() => LppReviewConfirmation(
      authorization: LppAcquisitionAuthorization(
        acquisitionId: '55555555-5555-4555-8555-555555555555',
        subject: LppEvidenceOwnerKind.self,
        partnerAttested: false,
        policyVersion: LppAcquisitionAuthorization.currentPolicyVersion,
        declaredAt: DateTime.utc(2026, 7, 1),
        documentSha256:
            '1111111111111111111111111111111111111111111111111111111111111111',
      ),
      sourceDate: DateTime.utc(2026, 6, 30),
      facts: const {
        LppEvidenceFactKey.vestedBenefitsCapitalChf: LppReviewedFact(
          value: 130000,
          unit: LppEvidenceUnit.chf,
        ),
      },
    );

TaxReviewConfirmation _taxConfirmation() {
  const extraction = ExtractionResult(
    documentType: DocumentType.taxDeclaration,
    fields: [],
    overallConfidence: 0.9,
    confidenceDelta: 0,
    warnings: [],
    disclaimer: '',
    sources: [],
  );
  final candidate = TaxExtractionCandidate.fromExtractionResult(
    extraction,
    snapshotIdFactory: () => '66666666-6666-4666-8666-666666666666',
  );
  return TaxReviewConfirmation(
    candidate: candidate,
    taxYear: 2025,
    basedOnTaxYear: null,
    sourceDate: DateTime.utc(2026, 6, 30),
    documentKind: TaxDocumentKind.assessmentNotice,
    assessmentStatus: TaxAssessmentStatus.assessedAppealable,
    subjectScope: TaxSubjectScope.individual,
    cantonCode: 'VD',
    municipalityId: null,
    municipalityLabel: null,
    cantonalCommunalTaxableIncomeChf: 99000,
    federalTaxableIncomeChf: null,
    cantonalCommunalTaxableWealthChf: null,
    cantonalCommunalAssessedTax: null,
    federalDirectAssessedTax: null,
    explicitMarginalIncomeTaxRate: null,
    explicitAverageIncomeTaxRate: null,
    now: () => DateTime.utc(2026, 7, 16, 12),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    FeatureFlags.typedLppEvidence = false;
    FeatureFlags.typedTaxProfile = false;
  });

  test('canonical owner is secure, durable, and reused after restart',
      () async {
    await ReportPersistenceService.saveAnswers(<String, dynamic>{
      'q_birth_year': 1986,
      'q_canton': 'VD',
    });

    final writer = CoachProfileProvider(
      now: () => DateTime.utc(2026, 7, 16, 12),
    );
    await writer.loadFromWizard();
    expect(writer.canonicalProfileOwnerId, isNull);
    final prefs = await SharedPreferences.getInstance();
    final bytesBeforePreview = prefs.getString('wizard_answers_v2');
    final owner = await writer.previewCanonicalProfileOwner();

    expect(owner, matches(_canonicalUuidV4));
    expect(writer.canonicalProfileOwnerId, isNull);
    expect(await writer.previewCanonicalProfileOwner(), owner);
    expect(prefs.getString('wizard_answers_v2'), bytesBeforePreview);

    expect(await writer.commitStagedCanonicalProfileOwner(owner), owner);
    expect(writer.canonicalProfileOwnerId, owner);
    final raw = jsonDecode(
      prefs.getString('wizard_answers_v2')!,
    ) as Map<String, dynamic>;
    expect(raw[_ownerRootKey], '__secure__');

    final cold = CoachProfileProvider(
      now: () => DateTime.utc(2026, 7, 16, 12),
    );
    await cold.loadFromWizard();
    expect(cold.canonicalProfileOwnerId, owner);

    writer.dispose();
    cold.dispose();
  });

  test('owner preview is stable and performs zero persistence writes',
      () async {
    final persistence = _RecordingOwnerPersistence({
      'q_birth_year': 1986,
      'q_canton': 'VD',
    });
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
    );
    final before = jsonEncode(persistence.answers);

    final first = await provider.previewCanonicalProfileOwner();
    final second = await provider.previewCanonicalProfileOwner();

    expect(first, matches(_canonicalUuidV4));
    expect(second, first);
    expect(provider.canonicalProfileOwnerId, isNull);
    expect(persistence.saveAttempts, 0);
    expect(jsonEncode(persistence.answers), before);
    provider.dispose();
  });

  test('owner preview never migrates a legacy secure LPP root', () async {
    await ReportPersistenceService.saveAnswers(<String, dynamic>{
      'q_birth_year': 1986,
      'q_canton': 'VD',
      _lppRootKey: _selfLppRoot(_selfOwner),
    });
    final prefs = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage();
    final prefsBefore = <String, Object?>{
      for (final key in prefs.getKeys()) key: prefs.get(key),
    };
    final secureBefore = await secureStorage.readAll();
    final provider = CoachProfileProvider();

    expect(await provider.previewCanonicalProfileOwner(), _selfOwner);

    expect(
      <String, Object?>{for (final key in prefs.getKeys()) key: prefs.get(key)},
      prefsBefore,
    );
    expect(await secureStorage.readAll(), secureBefore);
    expect(prefs.getString('lpp_evidence_active_slot_v1'), isNull);
    expect(provider.canonicalProfileOwnerId, isNull);
    provider.dispose();
  });

  test(
      'owner preview adopts ledger owner and final commit writes that exact id',
      () async {
    final persistence = _RecordingOwnerPersistence({
      _lppRootKey: _selfLppRoot(_selfOwner),
    });
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
    );

    expect(await provider.previewCanonicalProfileOwner(), _selfOwner);
    expect(provider.canonicalProfileOwnerId, isNull);
    expect(persistence.saveAttempts, 0);
    expect(await provider.commitStagedCanonicalProfileOwner(_selfOwner),
        _selfOwner);
    expect(provider.canonicalProfileOwnerId, _selfOwner);
    expect(persistence.saveAttempts, 1);
    provider.dispose();
  });

  test('failed final owner commit keeps the staged id for exact retry',
      () async {
    final persistence = _FailOnceOwnerPersistence({
      'q_birth_year': 1986,
    });
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
    );
    final staged = await provider.previewCanonicalProfileOwner();

    await expectLater(
      provider.commitStagedCanonicalProfileOwner(staged),
      throwsStateError,
    );
    expect(provider.canonicalProfileOwnerId, isNull);
    expect(await provider.previewCanonicalProfileOwner(), staged);
    expect(await provider.commitStagedCanonicalProfileOwner(staged), staged);
    expect(provider.canonicalProfileOwnerId, staged);
    expect(persistence.saveAttempts, 2);
    provider.dispose();
  });

  test('root drift after preview rejects final commit with zero writes',
      () async {
    final persistence = _RecordingOwnerPersistence({
      'q_birth_year': 1986,
    });
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
    );
    final staged = await provider.previewCanonicalProfileOwner();
    persistence.answers[_ownerRootKey] =
        const CoachProfileOwnerRoot(_otherOwner).toJsonString();
    final driftedBytes = jsonEncode(persistence.answers);

    await expectLater(
      provider.commitStagedCanonicalProfileOwner(staged),
      throwsStateError,
    );

    expect(provider.canonicalProfileOwnerId, isNull);
    expect(persistence.saveAttempts, 0);
    expect(jsonEncode(persistence.answers), driftedBytes);
    provider.dispose();
  });

  test('high-stakes ensure after preview commits the exact staged owner',
      () async {
    final persistence = _RecordingOwnerPersistence({
      'q_birth_year': 1986,
    });
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
    );
    final staged = await provider.previewCanonicalProfileOwner();

    expect(await provider.ensureCanonicalProfileOwner(), staged);
    expect(provider.canonicalProfileOwnerId, staged);
    expect(persistence.saveAttempts, 1);
    expect(await provider.commitStagedCanonicalProfileOwner(staged), staged);
    expect(persistence.saveAttempts, 1);
    provider.dispose();
  });

  test('concurrent owner ensures single-flight one durable UUID', () async {
    final persistence = _DelayedOwnerPersistence(<String, dynamic>{
      'q_birth_year': 1986,
      'q_canton': 'VD',
    });
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => DateTime.utc(2026, 7, 16, 12),
    );

    final first = provider.ensureCanonicalProfileOwner();
    await persistence.firstSaveStarted.future;
    final second = provider.ensureCanonicalProfileOwner();
    persistence.releaseFirstSave.complete();

    final owners = await Future.wait([first, second]);
    expect(owners.toSet(), hasLength(1));
    expect(owners.first, matches(_canonicalUuidV4));
    expect(persistence.saveAttempts, 1);
    final root = CoachProfileOwnerRoot.fromJsonString(
      persistence.answers[_ownerRootKey],
    );
    expect(root?.profileOwnerId, owners.first);
    expect(provider.canonicalProfileOwnerId, owners.first);
    provider.dispose();
  });

  test('owner persistence failure never exposes an in-memory UUID', () async {
    final persistence = _FailingOwnerPersistence(<String, dynamic>{
      'q_birth_year': 1986,
      'q_canton': 'VD',
    });
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => DateTime.utc(2026, 7, 16, 12),
    );

    await expectLater(
      provider.ensureCanonicalProfileOwner(),
      throwsStateError,
    );
    expect(provider.canonicalProfileOwnerId, isNull);
    expect(persistence.saveAttempts, 1);
    expect(persistence.answers, isNot(contains(_ownerRootKey)));
    provider.dispose();
  });

  test(
      'owner secure-write failure keeps base profile and blocks plan authority',
      () async {
    final persistence = _FailingOwnerPersistence(<String, dynamic>{
      'q_birth_year': 1986,
      'q_canton': 'VD',
      'q_has_pension_fund': 'yes',
    });
    final before = jsonEncode(persistence.answers);
    final now = DateTime.utc(2026, 7, 16, 12);
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => now,
    );

    await provider.loadFromWizard();

    final baseProfile = provider.profile;
    expect(baseProfile, isNotNull);
    expect(baseProfile!.birthYear, 1986);
    expect(baseProfile.canton, 'VD');
    expect(baseProfile.prevoyance.projectedCapital65, isNull);
    expect(provider.canonicalProfileOwnerId, isNull);
    expect(persistence.saveAttempts, 0);
    expect(jsonEncode(persistence.answers), before);
    expect(persistence.answers, isNot(contains(_ownerRootKey)));
    expect(provider.reportAnswersSnapshot, <String, dynamic>{
      'q_birth_year': 1986,
      'q_canton': 'VD',
      'q_has_pension_fund': 'yes',
    });
    final stagedOwner = await provider.previewCanonicalProfileOwner();
    await expectLater(
      provider.commitStagedCanonicalProfileOwner(stagedOwner),
      throwsStateError,
    );
    expect(provider.canonicalProfileOwnerId, isNull);
    expect(persistence.saveAttempts, 1);

    final draft = await PlanGenerationService.generate(
      goalDescription: 'Objectif synthétique',
      goalCategory: 'goal_general',
      targetDate: DateTime.utc(2030, 6, 30),
      profile: baseProfile,
      profileOwnerId: _selfOwner,
      selfLppSnapshot: null,
      goalAmount: 120000,
      now: now,
    );
    final plan = draft.copyWith(confirmedAt: now);
    final planProvider = FinancialPlanProvider(clock: () => now)
      ..setPlanDirect(plan)
      ..attachProfileProvider(provider);

    expect(planProvider.isPlanStale, isTrue);
    await expectLater(planProvider.setPlan(plan), throwsStateError);
    expect(persistence.saveAttempts, 1);
    expect(jsonEncode(persistence.answers), before);

    planProvider.dispose();
    provider.dispose();
  });

  test('canonical owner adopts an existing self LPP owner', () async {
    final persistence = _RecordingOwnerPersistence({
      'q_birth_year': 1986,
      'q_canton': 'VD',
      _lppRootKey: _selfLppRoot(_selfOwner),
    });
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => DateTime.utc(2026, 7, 16, 12),
    );

    expect(await provider.ensureCanonicalProfileOwner(), _selfOwner);
    expect(persistence.saveAttempts, 1);
    expect(
      CoachProfileOwnerRoot.fromJsonString(persistence.answers[_ownerRootKey])
          ?.profileOwnerId,
      _selfOwner,
    );
    provider.dispose();
  });

  test('manual-only LPP adopts the actor and never the partner owner',
      () async {
    final persistence = _RecordingOwnerPersistence({
      _lppRootKey: _manualOnlyLppRoot(actorOwnerId: _selfOwner),
    });
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
    );

    expect(await provider.ensureCanonicalProfileOwner(), _selfOwner);
    expect(provider.canonicalProfileOwnerId, isNot(_partnerOwner));
    expect(persistence.saveAttempts, 1);
    provider.dispose();
  });

  test('canonical owner adopts an existing fiscal snapshot owner', () async {
    final persistence =
        _RecordingOwnerPersistence({_taxRootKey: _taxRoot(_selfOwner)});
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
    );

    expect(await provider.ensureCanonicalProfileOwner(), _selfOwner);
    expect(persistence.saveAttempts, 1);
    provider.dispose();
  });

  test('invalid or conflicting roots never remint or write an owner', () async {
    final cases = <String, Map<String, dynamic>>{
      'malformed LPP': {_lppRootKey: '{not-json'},
      'unreadable LPP': {_lppRootKey: '__secure__'},
      'unreadable owner': {_ownerRootKey: '__secure__'},
      'non-UUID fiscal owner': {_taxRootKey: _taxRoot('not-a-uuid')},
      'LPP/tax conflict': {
        _lppRootKey: _selfLppRoot(_selfOwner),
        _taxRootKey: _taxRoot(_otherOwner),
      },
      'root/ledger conflict': {
        _ownerRootKey: const CoachProfileOwnerRoot(_selfOwner).toJsonString(),
        _lppRootKey: _selfLppRoot(_otherOwner),
      },
    };

    for (final entry in cases.entries) {
      final persistence = _RecordingOwnerPersistence(entry.value);
      final before = jsonEncode(persistence.answers);
      final provider = CoachProfileProvider(
        taxProfilePersistence: persistence,
        lppProfilePersistence: persistence,
      );

      await expectLater(
        provider.ensureCanonicalProfileOwner(),
        throwsStateError,
        reason: entry.key,
      );
      await expectLater(
        provider.ensureCanonicalProfileOwner(),
        throwsStateError,
        reason: '${entry.key} must stay rejected on retry',
      );
      expect(provider.canonicalProfileOwnerId, isNull, reason: entry.key);
      expect(persistence.saveAttempts, 0, reason: entry.key);
      expect(jsonEncode(persistence.answers), before, reason: entry.key);
      provider.dispose();
    }
  });

  test('malformed LPP keeps base profile but blocks owner and plan authority',
      () async {
    const malformedRoot = '{not-json';
    final persistence = _RecordingOwnerPersistence({
      'q_birth_year': 1986,
      'q_canton': 'VD',
      'q_has_pension_fund': 'yes',
      _lppRootKey: malformedRoot,
    });
    final before = jsonEncode(persistence.answers);
    final now = DateTime.utc(2026, 7, 16, 12);
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => now,
    );

    await provider.loadFromWizard();

    final baseProfile = provider.profile;
    expect(baseProfile, isNotNull);
    expect(baseProfile!.birthYear, 1986);
    expect(baseProfile.canton, 'VD');
    expect(baseProfile.prevoyance.projectedCapital65, isNull);
    expect(provider.canonicalProfileOwnerId, isNull);
    expect(persistence.saveAttempts, 0);
    expect(persistence.answers[_lppRootKey], malformedRoot);
    expect(jsonEncode(persistence.answers), before);

    final draft = await PlanGenerationService.generate(
      goalDescription: 'Objectif synthétique',
      goalCategory: 'goal_general',
      targetDate: DateTime.utc(2030, 6, 30),
      profile: baseProfile,
      profileOwnerId: _selfOwner,
      selfLppSnapshot: null,
      goalAmount: 120000,
      now: now,
    );
    final plan = draft.copyWith(confirmedAt: now);
    final planProvider = FinancialPlanProvider(clock: () => now)
      ..setPlanDirect(plan)
      ..attachProfileProvider(provider);

    expect(planProvider.isPlanStale, isTrue);
    await expectLater(planProvider.setPlan(plan), throwsStateError);
    expect(persistence.saveAttempts, 0);
    expect(jsonEncode(persistence.answers), before);

    planProvider.dispose();
    provider.dispose();
  });

  test('LPP and tax review writers reuse the durable canonical owner',
      () async {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.typedTaxProfile = true;
    final persistence = _RecordingOwnerPersistence({
      'q_birth_year': 1986,
      'q_canton': 'VD',
      _ownerRootKey: const CoachProfileOwnerRoot(_selfOwner).toJsonString(),
    });
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => DateTime.utc(2026, 7, 16, 12),
    );

    await provider.loadFromWizard();
    final savesBeforeReview = persistence.saveAttempts;
    await provider.acceptLppReview(_selfLppConfirmation());
    await provider.acceptTaxReview(_taxConfirmation());

    final lpp =
        LppEvidenceRoot.fromJsonString(persistence.answers[_lppRootKey]);
    expect(lpp!.self!.identityFacts.single.profileOwnerId, _selfOwner);
    final tax = jsonDecode(persistence.answers[_taxRootKey] as String) as Map;
    expect(
      ((tax['snapshots'] as List).single as Map)['profileOwnerId'],
      _selfOwner,
    );
    expect(provider.canonicalProfileOwnerId, _selfOwner);
    expect(persistence.saveAttempts, savesBeforeReview + 2);
    provider.dispose();
  });

  test('report and backend-safe snapshots expose only the owner marker',
      () async {
    final rawRoot = const CoachProfileOwnerRoot(_selfOwner).toJsonString();
    final persistence = _RecordingOwnerPersistence({
      'q_birth_year': 1986,
      'q_canton': 'VD',
      _ownerRootKey: rawRoot,
    });
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
    );

    await provider.loadFromWizard();
    final report = provider.reportAnswersSnapshot;
    final backend = ReportPersistenceService.backendSafeAnswers(
      persistence.answers,
    );

    expect(report[_ownerRootKey], '__secure__');
    expect(backend[_ownerRootKey], '__secure__');
    expect(jsonEncode(report), isNot(contains(_selfOwner)));
    expect(jsonEncode(backend), isNot(contains(_selfOwner)));
    provider.dispose();
  });
}
