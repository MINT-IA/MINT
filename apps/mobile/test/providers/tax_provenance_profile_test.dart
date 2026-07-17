import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/coach_profile_owner.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';

const _assessmentId = '11111111-1111-4111-8111-111111111111';
const _provisionalId = '22222222-2222-4222-8222-222222222222';
const _returnId = '33333333-3333-4333-8333-333333333333';
const _finalBillId = '55555555-5555-4555-8555-555555555555';
const _ownerId = '66666666-6666-4666-8666-666666666666';
const _useDefaultSourceDate = Object();
const _useDefaultCantonalTax = Object();
const _useDefaultFederalTax = Object();

AssessedTaxAmount _defaultCantonalTax() => AssessedTaxAmount(
      amountChf: 14520,
      authorityScope: TaxAuthorityScope.cantonalCommunalCombined,
      baseScope: TaxBaseScope.incomeAndWealth,
    );

AssessedTaxAmount _defaultFederalTax() => AssessedTaxAmount(
      amountChf: 3840,
      authorityScope: TaxAuthorityScope.federalDirect,
      baseScope: TaxBaseScope.incomeOnly,
    );

class _MemoryTaxPersistence
    with SerializedCanonicalAnswerMutationPersistence
    implements TaxProfilePersistence {
  _MemoryTaxPersistence([Map<String, dynamic> initial = const {}])
      : answers = _copy(initial);

  Map<String, dynamic> answers;
  int saveCalls = 0;
  bool failNextSave = false;
  bool holdNextSave = false;
  Completer<void>? _saveGate;

  @override
  Future<Map<String, dynamic>> loadAnswers() async => _copy(answers);

  @override
  Future<void> saveAnswers(Map<String, dynamic> next) async {
    saveCalls += 1;
    if (failNextSave) {
      failNextSave = false;
      throw StateError('synthetic save failure');
    }
    if (holdNextSave) {
      holdNextSave = false;
      _saveGate = Completer<void>();
      await _saveGate!.future;
      _saveGate = null;
    }
    answers = _copy(next);
  }

  void completePendingSave() {
    final gate = _saveGate;
    if (gate == null) throw StateError('no synthetic save is pending');
    gate.complete();
  }

  static Map<String, dynamic> _copy(Map<String, dynamic> value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
}

TaxExtractionCandidate _candidate(
  String id, {
  void Function()? onSnapshotIdFactory,
}) {
  const extraction = ExtractionResult(
    documentType: DocumentType.taxDeclaration,
    fields: [
      ExtractedField(
        fieldName: 'revenu_imposable',
        label: 'Revenu imposable',
        value: 98500.0,
        confidence: 0.9,
        sourceText: 'No contribuable PII-NEVER-PERSIST 98\'500',
        needsReview: false,
      ),
    ],
    overallConfidence: 0.9,
    confidenceDelta: 0,
    warnings: [],
    disclaimer: '',
    sources: [],
  );
  return TaxExtractionCandidate.fromExtractionResult(
    extraction,
    snapshotIdFactory: () {
      onSnapshotIdFactory?.call();
      return id;
    },
  );
}

TaxReviewConfirmation _confirmation(
  TaxExtractionCandidate candidate, {
  TaxDocumentKind kind = TaxDocumentKind.assessmentNotice,
  TaxAssessmentStatus status = TaxAssessmentStatus.assessedAppealable,
  bool inForceAttested = false,
  int? taxYear = 2025,
  int? basedOnTaxYear,
  Object? sourceDate = _useDefaultSourceDate,
  String? cantonCode = 'VD',
  String? municipalityId = '5586',
  String? municipalityLabel = 'Lausanne',
  double? cantonalIncome = 98500,
  double? federalIncome = 96200,
  double? cantonalWealth = 245000,
  Object? cantonalTax = _useDefaultCantonalTax,
  Object? federalTax = _useDefaultFederalTax,
  double? marginalRate = 0.325,
  double? averageRate = 0.186,
  TaxSubjectScope subjectScope = TaxSubjectScope.jointlyAssessedCouple,
  DateTime Function()? now,
}) {
  return TaxReviewConfirmation(
    candidate: candidate,
    taxYear: taxYear,
    basedOnTaxYear: basedOnTaxYear,
    sourceDate: identical(sourceDate, _useDefaultSourceDate)
        ? DateTime.utc(2026, 6, 20)
        : sourceDate as DateTime?,
    documentKind: kind,
    assessmentStatus: status,
    inForceAttested: inForceAttested,
    subjectScope: subjectScope,
    cantonCode: cantonCode,
    municipalityId: municipalityId,
    municipalityLabel: municipalityLabel,
    cantonalCommunalTaxableIncomeChf: cantonalIncome,
    federalTaxableIncomeChf: federalIncome,
    cantonalCommunalTaxableWealthChf: cantonalWealth,
    cantonalCommunalAssessedTax: identical(
      cantonalTax,
      _useDefaultCantonalTax,
    )
        ? _defaultCantonalTax()
        : cantonalTax as AssessedTaxAmount?,
    federalDirectAssessedTax: identical(federalTax, _useDefaultFederalTax)
        ? _defaultFederalTax()
        : federalTax as AssessedTaxAmount?,
    explicitMarginalIncomeTaxRate: marginalRate,
    explicitAverageIncomeTaxRate: averageRate,
    now: now,
  );
}

void main() {
  tearDown(() {
    FeatureFlags.typedTaxProfile = false;
    FeatureFlags.documentTaxAssessmentEnabled = false;
  });

  test('tax review confirmation enforces the injected civil tax year', () {
    DateTime today() => DateTime.utc(2026, 7, 14);

    expect(
      () => _confirmation(
        _candidate(_assessmentId),
        taxYear: 2026,
        now: today,
      ),
      returnsNormally,
    );
    for (final invalidYear in const [1899, 2027]) {
      expect(
        () => _confirmation(
          _candidate(_assessmentId),
          taxYear: invalidYear,
          now: today,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => _confirmation(
          _candidate(_assessmentId),
          basedOnTaxYear: invalidYear,
          now: today,
        ),
        throwsA(isA<ArgumentError>()),
      );
    }
    expect(
      () => _confirmation(
        _candidate(_provisionalId),
        kind: TaxDocumentKind.provisionalBill,
        status: TaxAssessmentStatus.provisional,
        taxYear: 2025,
        basedOnTaxYear: 2026,
        now: today,
      ),
      throwsA(isA<ArgumentError>()),
    );

    expect(
      () => FiscalSnapshotQuery.precise(
        requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
        taxYear: 2026,
        subjectScope: TaxSubjectScope.individual,
        cantonCode: 'VD',
        now: today,
      ),
      returnsNormally,
    );
    expect(
      () => FiscalSnapshotQuery.precise(
        requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
        taxYear: 2027,
        subjectScope: TaxSubjectScope.individual,
        cantonCode: 'VD',
        now: today,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('in-force tax review writes a precise reference and cold reloads it',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final asOf = DateTime.utc(2026, 7, 14, 12);
    final persistence = _MemoryTaxPersistence({
      '_coach_profile_owner_v1': const CoachProfileOwnerRoot(
        _ownerId,
      ).toJsonString(),
    });
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      now: () => asOf,
    );
    await provider.acceptTaxReview(
      _confirmation(
        _candidate(_assessmentId),
        status: TaxAssessmentStatus.inForce,
        inForceAttested: true,
        now: () => asOf,
      ),
    );

    final snapshot = provider.profile!.fiscal.snapshots.single;
    final reference = provider.profile!.latestTaxDecisionReference;
    expect(reference, isNotNull);
    expect(reference!.referenceId, snapshot.snapshotId);
    expect(reference.kind, SpecialistReferenceKind.taxAssessmentDecision);
    expect(
      reference.precisionReadyAt(asOf, taxSnapshot: snapshot),
      isTrue,
    );

    final cold = CoachProfileProvider(
      taxProfilePersistence: persistence,
      now: () => asOf,
    );
    await cold.loadFromWizard();
    expect(cold.profile!.latestTaxDecisionReference, reference);
    expect(
      cold.profile!.latestTaxDecisionReference!.toJson(),
      reference.toJson(),
    );
    expect(
      cold.profile!.latestTaxDecisionReference!.precisionReadyAt(
        asOf,
        taxSnapshot: cold.profile!.fiscal.snapshots.single,
      ),
      isTrue,
    );
    FeatureFlags.documentTaxAssessmentEnabled = true;
    expect(
      ConfidenceScorer.score(cold.profile!, now: () => asOf)
          .prompts
          .where((prompt) => prompt.fieldPath == 'fiscal.assessedBaseline'),
      isEmpty,
    );
  });

  test(
      'non-final, incomplete, and non-assessment snapshots create no reference',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final asOf = DateTime.utc(2026, 7, 14, 12);
    final cases = <String, TaxReviewConfirmation>{
      'appealable': _confirmation(
        _candidate(_assessmentId),
        now: () => asOf,
      ),
      'incomplete': _confirmation(
        _candidate(_returnId),
        status: TaxAssessmentStatus.inForce,
        inForceAttested: true,
        cantonCode: null,
        now: () => asOf,
      ),
      'provisional': _confirmation(
        _candidate(_provisionalId),
        kind: TaxDocumentKind.provisionalBill,
        status: TaxAssessmentStatus.provisional,
        now: () => asOf,
      ),
      'taxpayer-return': _confirmation(
        _candidate(_finalBillId),
        kind: TaxDocumentKind.taxpayerReturn,
        status: TaxAssessmentStatus.selfDeclared,
        now: () => asOf,
      ),
    };

    for (final entry in cases.entries) {
      final provider = CoachProfileProvider(
        taxProfilePersistence: _MemoryTaxPersistence(),
        now: () => asOf,
      );
      await provider.acceptTaxReview(entry.value);
      expect(
        provider.profile!.latestTaxDecisionReference,
        isNull,
        reason: entry.key,
      );
    }
  });

  test('same UUID replacement clears an ineligible reference live and cold',
      () async {
    FeatureFlags.typedTaxProfile = true;
    FeatureFlags.documentTaxAssessmentEnabled = true;
    final asOf = DateTime.utc(2026, 7, 14, 12);
    final persistence = _MemoryTaxPersistence();
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      now: () => asOf,
    );
    await provider.acceptTaxReview(
      _confirmation(
        _candidate(_assessmentId),
        status: TaxAssessmentStatus.inForce,
        inForceAttested: true,
        now: () => asOf,
      ),
    );
    expect(provider.profile!.latestTaxDecisionReference, isNotNull);

    await provider.acceptTaxReview(
      _confirmation(
        _candidate(_assessmentId),
        status: TaxAssessmentStatus.assessedAppealable,
        now: () => asOf,
      ),
    );
    expect(provider.profile!.fiscal.snapshots, hasLength(1));
    expect(provider.profile!.latestTaxDecisionReference, isNull);
    expect(
      ConfidenceScorer.score(provider.profile!, now: () => asOf)
          .prompts
          .where((prompt) => prompt.fieldPath == 'fiscal.assessedBaseline'),
      hasLength(1),
    );

    final cold = CoachProfileProvider(
      taxProfilePersistence: persistence,
      now: () => asOf,
    );
    await cold.loadFromWizard();
    expect(cold.profile!.fiscal.snapshots, hasLength(1));
    expect(cold.profile!.latestTaxDecisionReference, isNull);
    expect(
      ConfidenceScorer.score(cold.profile!, now: () => asOf)
          .prompts
          .where((prompt) => prompt.fieldPath == 'fiscal.assessedBaseline'),
      hasLength(1),
    );
  });

  test('same-rank in-force conflict clears reference live and cold', () async {
    FeatureFlags.typedTaxProfile = true;
    FeatureFlags.documentTaxAssessmentEnabled = true;
    final asOf = DateTime.utc(2026, 7, 14, 12);
    final persistence = _MemoryTaxPersistence();
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      now: () => asOf,
    );
    for (final confirmation in <TaxReviewConfirmation>[
      _confirmation(
        _candidate(_assessmentId),
        status: TaxAssessmentStatus.inForce,
        inForceAttested: true,
        cantonalIncome: 98500,
        now: () => asOf,
      ),
      _confirmation(
        _candidate(_provisionalId),
        status: TaxAssessmentStatus.inForce,
        inForceAttested: true,
        cantonalIncome: 112000,
        now: () => asOf,
      ),
    ]) {
      await provider.acceptTaxReview(confirmation);
    }
    expect(provider.profile!.fiscal.snapshots, hasLength(2));
    expect(provider.profile!.latestTaxDecisionReference, isNull);
    expect(
      ConfidenceScorer.score(provider.profile!, now: () => asOf)
          .prompts
          .where((prompt) => prompt.fieldPath == 'fiscal.assessedBaseline'),
      hasLength(1),
    );

    final cold = CoachProfileProvider(
      taxProfilePersistence: persistence,
      now: () => asOf,
    );
    await cold.loadFromWizard();
    expect(cold.profile!.latestTaxDecisionReference, isNull);
    expect(
      ConfidenceScorer.score(cold.profile!, now: () => asOf)
          .prompts
          .where((prompt) => prompt.fieldPath == 'fiscal.assessedBaseline'),
      hasLength(1),
    );
  });

  test('corrupt cold provenance preserves history but clears reference',
      () async {
    FeatureFlags.typedTaxProfile = true;
    FeatureFlags.documentTaxAssessmentEnabled = true;
    final asOf = DateTime.utc(2026, 7, 14, 12);
    final persistence = _MemoryTaxPersistence();
    final writer = CoachProfileProvider(
      taxProfilePersistence: persistence,
      now: () => asOf,
    );
    await writer.acceptTaxReview(
      _confirmation(
        _candidate(_assessmentId),
        status: TaxAssessmentStatus.inForce,
        inForceAttested: true,
        now: () => asOf,
      ),
    );
    expect(writer.profile!.latestTaxDecisionReference, isNotNull);

    final provenance = Map<String, dynamic>.from(
      persistence.answers['__provenance'] as Map,
    );
    const path = 'fiscal.snapshots.$_assessmentId.taxYear';
    provenance[path] = Map<String, dynamic>.from(provenance[path] as Map)
      ..['updatedAt'] = DateTime.utc(2026, 7, 13).toIso8601String();
    persistence.answers['__provenance'] = provenance;
    final before = jsonEncode(persistence.answers);
    persistence.saveCalls = 0;

    final cold = CoachProfileProvider(
      taxProfilePersistence: persistence,
      now: () => asOf,
    );
    await cold.loadFromWizard();
    expect(cold.profile!.fiscal.snapshots.single.snapshotId, _assessmentId);
    expect(cold.profile!.fiscal.provenanceValidatedSnapshotIds, isEmpty);
    expect(cold.profile!.latestTaxDecisionReference, isNull);
    expect(
      ConfidenceScorer.score(cold.profile!, now: () => asOf)
          .prompts
          .where((prompt) => prompt.fieldPath == 'fiscal.assessedBaseline'),
      hasLength(1),
    );
    expect(persistence.saveCalls, 0);
    expect(jsonEncode(persistence.answers), before);
  });

  test('provider rejects future tax and basis years before persistence',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final confirmations = [
      _confirmation(
        _candidate(_assessmentId),
        taxYear: 2027,
        now: () => DateTime.utc(2027, 7, 14),
      ),
      _confirmation(
        _candidate(_assessmentId),
        taxYear: 2025,
        basedOnTaxYear: 2027,
        now: () => DateTime.utc(2027, 7, 14),
      ),
    ];

    for (final confirmation in confirmations) {
      final persistence = _MemoryTaxPersistence();
      final provider = CoachProfileProvider(
        taxProfilePersistence: persistence,
        now: () => DateTime.utc(2026, 7, 14),
      );
      await expectLater(
        provider.acceptTaxReview(confirmation),
        throwsA(isA<ArgumentError>()),
      );
      expect(persistence.saveCalls, 0);
      expect(persistence.answers, isEmpty);
      expect(provider.profile, isNull);
    }
  });

  test(
      'cold provenance and selector independently exclude 2099 before ranking 2025',
      () async {
    FeatureFlags.typedTaxProfile = true;
    DateTime today() => DateTime.utc(2026, 7, 14);
    final persistence = _MemoryTaxPersistence();
    final writer = CoachProfileProvider(
      taxProfilePersistence: persistence,
      now: today,
    );
    await writer.acceptTaxReview(
      _confirmation(
        _candidate(_assessmentId),
        taxYear: 2025,
        now: today,
      ),
    );
    await writer.acceptTaxReview(
      _confirmation(
        _candidate(_provisionalId),
        kind: TaxDocumentKind.provisionalBill,
        status: TaxAssessmentStatus.provisional,
        taxYear: 2026,
        basedOnTaxYear: 2025,
        now: today,
      ),
    );
    const futureId = '99999999-9999-4999-8999-999999999999';
    await writer.acceptTaxReview(
      _confirmation(
        _candidate(futureId),
        taxYear: 2026,
        now: today,
      ),
    );
    final writtenSnapshots = writer.profile!.fiscal.snapshots;
    final valid2025 = writtenSnapshots.singleWhere(
      (snapshot) => snapshot.snapshotId == _assessmentId,
    );
    final invalidFutureBasis = writtenSnapshots
        .singleWhere((snapshot) => snapshot.snapshotId == futureId)
        .copyWith(taxYear: 2025, basedOnTaxYear: 2099);

    final rawRoot = jsonDecode(
      persistence.answers['_coach_tax_snapshots_v1'] as String,
    ) as Map<String, dynamic>;
    final rawFuture = (rawRoot['snapshots'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .singleWhere((snapshot) => snapshot['snapshotId'] == futureId);
    rawFuture['taxYear'] = 2099;
    final rawProvisional = (rawRoot['snapshots'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .singleWhere((snapshot) => snapshot['snapshotId'] == _provisionalId);
    rawProvisional['basedOnTaxYear'] = 2099;
    persistence.answers['_coach_tax_snapshots_v1'] = jsonEncode(rawRoot);

    final cold = CoachProfileProvider(
      taxProfilePersistence: persistence,
      now: today,
    );
    await cold.loadFromWizard();
    expect(cold.profile!.fiscal.snapshots, hasLength(3));
    expect(
      cold.profile!.fiscal.provenanceValidatedSnapshotIds,
      {_assessmentId},
      reason: 'cold provenance must reject the future-year snapshot',
    );
    final coldSelection = FiscalSnapshotSelector.selectAssessedBaseline(
      cold.profile!.fiscal,
      const FiscalSnapshotQuery.latestCompleteness(
        requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
      ),
      now: today,
    );
    expect(coldSelection.status, FiscalSelectionStatus.available);

    final hostileValidatedProfile = FiscalProfile(
      snapshots: [valid2025, invalidFutureBasis],
      provenanceValidatedSnapshotIds: const {_assessmentId, futureId},
    );
    final independentlyFiltered = FiscalSnapshotSelector.selectAssessedBaseline(
      hostileValidatedProfile,
      FiscalSnapshotQuery.precise(
        requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
        taxYear: 2025,
        subjectScope: TaxSubjectScope.jointlyAssessedCouple,
        cantonCode: 'VD',
        now: today,
      ),
      now: today,
    );
    expect(independentlyFiltered.status, FiscalSelectionStatus.available);
    expect(independentlyFiltered.snapshot?.snapshotId, _assessmentId);
  });

  test('undated precise tax fact stays visible but needs confirmation',
      () async {
    FeatureFlags.typedTaxProfile = true;
    DateTime today() => DateTime.utc(2026, 7, 14);
    final persistence = _MemoryTaxPersistence();
    final writer = CoachProfileProvider(
      taxProfilePersistence: persistence,
      now: today,
    );
    await writer.acceptTaxReview(
      _confirmation(
        _candidate(_assessmentId),
        sourceDate: null,
        now: today,
      ),
    );
    final precise = FiscalSnapshotSelector.selectAssessedBaseline(
      writer.profile!.fiscal,
      FiscalSnapshotQuery.precise(
        requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
        taxYear: 2025,
        subjectScope: TaxSubjectScope.jointlyAssessedCouple,
        cantonCode: 'VD',
        now: today,
      ),
      now: today,
    );
    expect(
      precise.status,
      FiscalSelectionStatus.availableNeedsConfirmation,
    );
    expect(precise.snapshot?.snapshotId, _assessmentId);

    final completeness = FiscalSnapshotSelector.selectAssessedBaseline(
      writer.profile!.fiscal,
      const FiscalSnapshotQuery.latestCompleteness(
        requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
      ),
      now: today,
    );
    expect(completeness.status, FiscalSelectionStatus.partialAsk);
    expect(completeness.snapshot, isNull);
  });

  final coldProvenanceCorruptions = <({
    String name,
    bool nullMarginal,
    void Function(Map<String, dynamic>, TaxSnapshot) corrupt,
  })>[
    (
      name: 'missing metadata taxYear entry',
      nullMarginal: false,
      corrupt: (provenance, snapshot) {
        provenance.remove(
          'fiscal.snapshots.${snapshot.snapshotId}.taxYear',
        );
      },
    ),
    (
      name: 'metadata documentKind with the wrong envelope type',
      nullMarginal: false,
      corrupt: (provenance, snapshot) {
        provenance['fiscal.snapshots.${snapshot.snapshotId}.documentKind'] =
            'not-an-envelope';
      },
    ),
    (
      name: 'financial income source inconsistent with document kind',
      nullMarginal: false,
      corrupt: (provenance, snapshot) {
        final path =
            'fiscal.snapshots.${snapshot.snapshotId}.cantonalCommunalTaxableIncomeChf';
        provenance[path] = Map<String, dynamic>.from(
          provenance[path] as Map,
        )..['source'] = ProfileDataSource.userInput.name;
      },
    ),
    (
      name: 'nested assessed-tax amount with inconsistent sourceDate',
      nullMarginal: false,
      corrupt: (provenance, snapshot) {
        final path =
            'fiscal.snapshots.${snapshot.snapshotId}.cantonalCommunalAssessedTax.amountChf';
        provenance[path] = Map<String, dynamic>.from(
          provenance[path] as Map,
        )..['sourceDate'] = DateTime.utc(2026, 6, 21).toIso8601String();
      },
    ),
    (
      name: 'nested assessed-tax authority with inconsistent updatedAt',
      nullMarginal: false,
      corrupt: (provenance, snapshot) {
        final path =
            'fiscal.snapshots.${snapshot.snapshotId}.cantonalCommunalAssessedTax.authorityScope';
        provenance[path] = Map<String, dynamic>.from(
          provenance[path] as Map,
        )..['updatedAt'] = DateTime.utc(2026, 7, 13).toIso8601String();
      },
    ),
    (
      name: 'nested assessed-tax base with an extra envelope key',
      nullMarginal: false,
      corrupt: (provenance, snapshot) {
        final path =
            'fiscal.snapshots.${snapshot.snapshotId}.cantonalCommunalAssessedTax.baseScope';
        provenance[path] = Map<String, dynamic>.from(
          provenance[path] as Map,
        )..['unexpected'] = true;
      },
    ),
    (
      name: 'marginal rate envelope has null sourceDate against dated snapshot',
      nullMarginal: false,
      corrupt: (provenance, snapshot) {
        final path =
            'fiscal.snapshots.${snapshot.snapshotId}.explicitMarginalIncomeTaxRate';
        provenance[path] = Map<String, dynamic>.from(
          provenance[path] as Map,
        )..['sourceDate'] = null;
      },
    ),
    (
      name: 'extra envelope exists for an allowlisted null marginal rate leaf',
      nullMarginal: true,
      corrupt: (provenance, snapshot) {
        expect(snapshot.explicitMarginalIncomeTaxRate, isNull);
        final path =
            'fiscal.snapshots.${snapshot.snapshotId}.explicitMarginalIncomeTaxRate';
        expect(provenance.containsKey(path), isFalse);
        provenance[path] = Map<String, dynamic>.from(
          provenance['fiscal.snapshots.${snapshot.snapshotId}.taxYear'] as Map,
        );
      },
    ),
  ];

  for (final testCase in coldProvenanceCorruptions) {
    test(
        'cold provenance ${testCase.name} keeps history but blocks consumption without writes',
        () async {
      FeatureFlags.typedTaxProfile = true;
      final persistence = _MemoryTaxPersistence();
      final writer = CoachProfileProvider(
        taxProfilePersistence: persistence,
      );
      await writer.acceptTaxReview(
        _confirmation(
          _candidate(_assessmentId),
          marginalRate: testCase.nullMarginal ? null : 0.325,
        ),
      );
      final root = Map<String, dynamic>.from(
        jsonDecode(persistence.answers['_coach_tax_snapshots_v1'] as String)
            as Map,
      );
      final snapshot = TaxSnapshot.fromJson(
        Map<String, dynamic>.from((root['snapshots'] as List).single as Map),
      );
      final provenance = Map<String, dynamic>.from(
        persistence.answers['__provenance'] as Map,
      );
      testCase.corrupt(provenance, snapshot);
      persistence.answers['__provenance'] = provenance;
      persistence.saveCalls = 0;
      final before = jsonEncode(persistence.answers);

      final cold = CoachProfileProvider(
        taxProfilePersistence: persistence,
      );
      await cold.loadFromWizard();

      expect(cold.profile!.fiscal.snapshots, [snapshot]);
      final preciseSelection = FiscalSnapshotSelector.selectAssessedBaseline(
        cold.profile!.fiscal,
        FiscalSnapshotQuery.precise(
          requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
          taxYear: 2025,
          cantonCode: 'VD',
          subjectScope: TaxSubjectScope.jointlyAssessedCouple,
        ),
      );
      expect(preciseSelection.status, FiscalSelectionStatus.partialAsk);
      expect(preciseSelection.snapshot, isNull);
      final completenessSelection =
          FiscalSnapshotSelector.selectAssessedBaseline(
        cold.profile!.fiscal,
        const FiscalSnapshotQuery.latestCompleteness(
          requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
        ),
      );
      expect(completenessSelection.status, FiscalSelectionStatus.partialAsk);
      expect(completenessSelection.snapshot, isNull);
      expect(persistence.saveCalls, 0);
      expect(jsonEncode(persistence.answers), before);
    });
  }

  final nonCertificateColdSources = <({
    String snapshotId,
    TaxDocumentKind kind,
    TaxAssessmentStatus status,
    ProfileDataSource expectedSource,
  })>[
    (
      snapshotId: _returnId,
      kind: TaxDocumentKind.taxpayerReturn,
      status: TaxAssessmentStatus.selfDeclared,
      expectedSource: ProfileDataSource.userInput,
    ),
    (
      snapshotId: _provisionalId,
      kind: TaxDocumentKind.provisionalBill,
      status: TaxAssessmentStatus.provisional,
      expectedSource: ProfileDataSource.estimated,
    ),
    (
      snapshotId: _finalBillId,
      kind: TaxDocumentKind.finalTaxBill,
      status: TaxAssessmentStatus.unknown,
      expectedSource: ProfileDataSource.estimated,
    ),
  ];
  for (final testCase in nonCertificateColdSources) {
    test(
        'cold provenance preserves ${testCase.kind.name} source ${testCase.expectedSource.name}',
        () async {
      FeatureFlags.typedTaxProfile = true;
      final persistence = _MemoryTaxPersistence();
      final writer = CoachProfileProvider(taxProfilePersistence: persistence);
      await writer.acceptTaxReview(
        _confirmation(
          _candidate(testCase.snapshotId),
          kind: testCase.kind,
          status: testCase.status,
          basedOnTaxYear:
              testCase.kind == TaxDocumentKind.provisionalBill ? 2024 : null,
        ),
      );
      final snapshot = writer.profile!.fiscal.snapshots.single;
      persistence.saveCalls = 0;
      final before = jsonEncode(persistence.answers);

      final cold = CoachProfileProvider(taxProfilePersistence: persistence);
      await cold.loadFromWizard();

      expect(cold.profile!.fiscal.snapshots, [snapshot]);
      final prefix = 'fiscal.snapshots.${testCase.snapshotId}.';
      final fiscalSources = Map<String, ProfileDataSource>.fromEntries(
        cold.profile!.dataSources.entries.where(
          (entry) => entry.key.startsWith(prefix),
        ),
      );
      expect(fiscalSources, isNotEmpty);
      expect(
        fiscalSources.values,
        everyElement(testCase.expectedSource),
      );
      expect(
        (persistence.answers['__provenance'] as Map)['${prefix}documentKind']
            ['source'],
        testCase.expectedSource.name,
      );
      expect(persistence.saveCalls, 0);
      expect(jsonEncode(persistence.answers), before);
    });
  }

  test(
      'cold provenance rogue fiscal leaf keeps history but blocks consumption without writes',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final persistence = _MemoryTaxPersistence();
    final writer = CoachProfileProvider(taxProfilePersistence: persistence);
    await writer.acceptTaxReview(
      _confirmation(_candidate(_assessmentId)),
    );
    final snapshot = writer.profile!.fiscal.snapshots.single;
    final provenance = Map<String, dynamic>.from(
      persistence.answers['__provenance'] as Map,
    );
    final exactPath = 'fiscal.snapshots.${snapshot.snapshotId}.taxYear';
    provenance['fiscal.snapshots.${snapshot.snapshotId}.rogueFiscalLeaf'] =
        Map<String, dynamic>.from(provenance[exactPath] as Map);
    persistence.answers['__provenance'] = provenance;
    persistence.saveCalls = 0;
    final before = jsonEncode(persistence.answers);

    final cold = CoachProfileProvider(taxProfilePersistence: persistence);
    await cold.loadFromWizard();

    expect(cold.profile!.fiscal.snapshots, [snapshot]);
    final selection = FiscalSnapshotSelector.selectAssessedBaseline(
      cold.profile!.fiscal,
      const FiscalSnapshotQuery.latestCompleteness(
        requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
      ),
    );
    expect(selection.status, FiscalSelectionStatus.partialAsk);
    expect(selection.snapshot, isNull);
    expect(persistence.saveCalls, 0);
    expect(jsonEncode(persistence.answers), before);
  });

  test(
      'cold provenance null sourceDate against dated snapshot blocks consumption without writes',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final persistence = _MemoryTaxPersistence();
    final writer = CoachProfileProvider(taxProfilePersistence: persistence);
    await writer.acceptTaxReview(
      _confirmation(_candidate(_assessmentId)),
    );
    final snapshot = writer.profile!.fiscal.snapshots.single;
    final provenance = Map<String, dynamic>.from(
      persistence.answers['__provenance'] as Map,
    );
    final path = 'fiscal.snapshots.${snapshot.snapshotId}.taxYear';
    provenance[path] = Map<String, dynamic>.from(provenance[path] as Map)
      ..['sourceDate'] = null;
    persistence.answers['__provenance'] = provenance;
    persistence.saveCalls = 0;
    final before = jsonEncode(persistence.answers);

    final cold = CoachProfileProvider(taxProfilePersistence: persistence);
    await cold.loadFromWizard();

    expect(cold.profile!.fiscal.snapshots, [snapshot]);
    final selection = FiscalSnapshotSelector.selectAssessedBaseline(
      cold.profile!.fiscal,
      const FiscalSnapshotQuery.latestCompleteness(
        requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
      ),
    );
    expect(selection.status, FiscalSelectionStatus.partialAsk);
    expect(selection.snapshot, isNull);
    expect(persistence.saveCalls, 0);
    expect(jsonEncode(persistence.answers), before);
  });

  test(
      'cold provenance dated sourceDate against null snapshot blocks consumption without writes',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final persistence = _MemoryTaxPersistence();
    final writer = CoachProfileProvider(taxProfilePersistence: persistence);
    await writer.acceptTaxReview(
      _confirmation(
        _candidate(_assessmentId),
        sourceDate: null,
      ),
    );
    final snapshot = writer.profile!.fiscal.snapshots.single;
    expect(snapshot.sourceDate, isNull);
    final provenance = Map<String, dynamic>.from(
      persistence.answers['__provenance'] as Map,
    );
    final path = 'fiscal.snapshots.${snapshot.snapshotId}.taxYear';
    provenance[path] = Map<String, dynamic>.from(provenance[path] as Map)
      ..['sourceDate'] = DateTime.utc(2026, 6, 20).toIso8601String();
    persistence.answers['__provenance'] = provenance;
    persistence.saveCalls = 0;
    final before = jsonEncode(persistence.answers);

    final cold = CoachProfileProvider(taxProfilePersistence: persistence);
    await cold.loadFromWizard();

    expect(cold.profile!.fiscal.snapshots, [snapshot]);
    final selection = FiscalSnapshotSelector.selectAssessedBaseline(
      cold.profile!.fiscal,
      const FiscalSnapshotQuery.latestCompleteness(
        requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
      ),
    );
    expect(selection.status, FiscalSelectionStatus.partialAsk);
    expect(selection.snapshot, isNull);
    expect(persistence.saveCalls, 0);
    expect(jsonEncode(persistence.answers), before);
  });

  test(
      'cold provenance filters one corrupt same-rank snapshot and keeps the exact peer selectable',
      () async {
    FeatureFlags.typedTaxProfile = true;
    const exactId = '44444444-4444-4444-8444-444444444444';
    final persistence = _MemoryTaxPersistence();
    final writer = CoachProfileProvider(taxProfilePersistence: persistence);
    await writer.acceptTaxReview(
      _confirmation(_candidate(_assessmentId)),
    );
    await writer.acceptTaxReview(
      _confirmation(
        _candidate(exactId),
        federalIncome: 95100,
      ),
    );
    final snapshots = writer.profile!.fiscal.snapshots;
    final provenance = Map<String, dynamic>.from(
      persistence.answers['__provenance'] as Map,
    )..remove('fiscal.snapshots.$_assessmentId.taxYear');
    persistence.answers['__provenance'] = provenance;
    persistence.saveCalls = 0;
    final before = jsonEncode(persistence.answers);

    final cold = CoachProfileProvider(taxProfilePersistence: persistence);
    await cold.loadFromWizard();

    expect(cold.profile!.fiscal.snapshots, snapshots);
    final selection = FiscalSnapshotSelector.selectAssessedBaseline(
      cold.profile!.fiscal,
      FiscalSnapshotQuery.precise(
        requestedField: TaxSnapshotField.federalTaxableIncomeChf,
        taxYear: 2025,
        cantonCode: 'VD',
        subjectScope: TaxSubjectScope.jointlyAssessedCouple,
      ),
    );
    expect(selection.status, FiscalSelectionStatus.available);
    expect(selection.snapshot?.snapshotId, exactId);
    expect(selection.conflictingSnapshotIds, isEmpty);
    expect(persistence.saveCalls, 0);
    expect(jsonEncode(persistence.answers), before);
  });

  test(
      'cold corrupt old snapshot stays ineligible when a new exact assessment is accepted and reloaded',
      () async {
    FeatureFlags.typedTaxProfile = true;
    const newAssessmentId = '66666666-6666-4666-8666-666666666666';
    final persistence = _MemoryTaxPersistence();
    final writer = CoachProfileProvider(taxProfilePersistence: persistence);
    await writer.acceptTaxReview(
      _confirmation(_candidate(_assessmentId)),
    );
    final oldSnapshot = writer.profile!.fiscal.snapshots.single;
    final corruptedProvenance = Map<String, dynamic>.from(
      persistence.answers['__provenance'] as Map,
    )..remove('fiscal.snapshots.$_assessmentId.taxYear');
    persistence.answers['__provenance'] = corruptedProvenance;
    persistence.saveCalls = 0;
    final corruptBytes = jsonEncode(persistence.answers);

    final cold = CoachProfileProvider(taxProfilePersistence: persistence);
    await cold.loadFromWizard();

    expect(cold.profile!.fiscal.snapshots, [oldSnapshot]);
    final oldBeforeWrite = FiscalSnapshotSelector.selectAssessedBaseline(
      cold.profile!.fiscal,
      FiscalSnapshotQuery.precise(
        requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
        taxYear: 2025,
        cantonCode: 'VD',
        subjectScope: TaxSubjectScope.jointlyAssessedCouple,
      ),
    );
    expect(oldBeforeWrite.status, FiscalSelectionStatus.partialAsk);
    expect(oldBeforeWrite.snapshot, isNull);
    expect(persistence.saveCalls, 0);
    expect(jsonEncode(persistence.answers), corruptBytes);

    await cold.acceptTaxReview(
      _confirmation(
        _candidate(newAssessmentId),
        taxYear: 2024,
        sourceDate: DateTime.utc(2025, 6, 20),
      ),
    );

    expect(persistence.saveCalls, 1);
    expect(cold.profile!.fiscal.snapshots, hasLength(2));
    final oldImmediate = FiscalSnapshotSelector.selectAssessedBaseline(
      cold.profile!.fiscal,
      FiscalSnapshotQuery.precise(
        requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
        taxYear: 2025,
        cantonCode: 'VD',
        subjectScope: TaxSubjectScope.jointlyAssessedCouple,
      ),
    );
    expect(oldImmediate.status, FiscalSelectionStatus.partialAsk);
    expect(oldImmediate.snapshot, isNull);
    final newImmediate = FiscalSnapshotSelector.selectAssessedBaseline(
      cold.profile!.fiscal,
      FiscalSnapshotQuery.precise(
        requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
        taxYear: 2024,
        cantonCode: 'VD',
        subjectScope: TaxSubjectScope.jointlyAssessedCouple,
      ),
    );
    expect(newImmediate.status, FiscalSelectionStatus.available);
    expect(newImmediate.snapshot?.snapshotId, newAssessmentId);

    final root = Map<String, dynamic>.from(
      jsonDecode(persistence.answers['_coach_tax_snapshots_v1'] as String)
          as Map,
    );
    expect(root['snapshots'], hasLength(2));
    final newSnapshot = cold.profile!.fiscal.snapshots.singleWhere(
      (snapshot) => snapshot.snapshotId == newAssessmentId,
    );
    final persistedProvenance = Map<String, dynamic>.from(
      persistence.answers['__provenance'] as Map,
    );
    expect(
      persistedProvenance.containsKey(
        'fiscal.snapshots.$_assessmentId.taxYear',
      ),
      isFalse,
    );
    const newPrefix = 'fiscal.snapshots.$newAssessmentId.';
    final expectedNewPaths = {
      for (final leafPath in TaxSnapshot.provenanceLeafPaths)
        if (leafPath == 'sourceDate' ||
            newSnapshot.provenanceValue(leafPath) != null)
          '$newPrefix$leafPath',
    };
    final persistedNewPaths = persistedProvenance.keys
        .where((path) => path.startsWith(newPrefix))
        .toSet();
    expect(persistedNewPaths, expectedNewPaths);
    for (final path in expectedNewPaths) {
      final envelope = Map<String, dynamic>.from(
        persistedProvenance[path] as Map,
      );
      expect(envelope.keys.toSet(), {'source', 'updatedAt', 'sourceDate'});
      expect(envelope['source'], ProfileDataSource.certificate.name);
      expect(
        DateTime.parse(envelope['updatedAt'] as String)
            .isAtSameMomentAs(newSnapshot.updatedAt),
        isTrue,
      );
      expect(
        DateTime.parse(envelope['sourceDate'] as String)
            .isAtSameMomentAs(newSnapshot.sourceDate!),
        isTrue,
      );
    }
    final acceptedBytes = jsonEncode(persistence.answers);

    final secondCold = CoachProfileProvider(
      taxProfilePersistence: persistence,
    );
    await secondCold.loadFromWizard();

    expect(secondCold.profile!.fiscal.snapshots, hasLength(2));
    final oldAfterReload = FiscalSnapshotSelector.selectAssessedBaseline(
      secondCold.profile!.fiscal,
      FiscalSnapshotQuery.precise(
        requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
        taxYear: 2025,
        cantonCode: 'VD',
        subjectScope: TaxSubjectScope.jointlyAssessedCouple,
      ),
    );
    expect(oldAfterReload.status, FiscalSelectionStatus.partialAsk);
    expect(oldAfterReload.snapshot, isNull);
    final newAfterReload = FiscalSnapshotSelector.selectAssessedBaseline(
      secondCold.profile!.fiscal,
      FiscalSnapshotQuery.precise(
        requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
        taxYear: 2024,
        cantonCode: 'VD',
        subjectScope: TaxSubjectScope.jointlyAssessedCouple,
      ),
    );
    expect(newAfterReload.status, FiscalSelectionStatus.available);
    expect(newAfterReload.snapshot?.snapshotId, newAssessmentId);
    expect(persistence.saveCalls, 1);
    expect(jsonEncode(persistence.answers), acceptedBytes);
  });

  test(
      'cold invalid quarantine is recovered without promoting its snapshot or provenance',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final quarantinedAt = DateTime.utc(2026, 7, 14, 12, 30);
    final persistence = _MemoryTaxPersistence();
    final writer = CoachProfileProvider(taxProfilePersistence: persistence);
    await writer.acceptTaxReview(
      _confirmation(_candidate(_assessmentId)),
    );
    final root = Map<String, dynamic>.from(
      jsonDecode(persistence.answers['_coach_tax_snapshots_v1'] as String)
          as Map,
    )..['legacyQuarantine'] = {
        'legacySchemaVersion': 0,
        'reasonCodes': ['legacy_unknown_provenance'],
        'values': {'q_revenu_net': 98500},
        'quarantinedAt': DateTime.utc(2026, 7, 14).toIso8601String(),
      };
    persistence.answers['_coach_tax_snapshots_v1'] = jsonEncode(root);
    final retainedNonFiscalProvenance = {
      'source': 'userInput',
      'updatedAt': DateTime.utc(2026, 7, 13).toIso8601String(),
      'sourceDate': null,
    };
    (persistence.answers['__provenance'] as Map<String, dynamic>)['canton'] =
        retainedNonFiscalProvenance;
    persistence.saveCalls = 0;
    final malformedRoot =
        persistence.answers['_coach_tax_snapshots_v1'] as String;
    final before = jsonEncode(persistence.answers);

    final cold = CoachProfileProvider(
      taxProfilePersistence: persistence,
      now: () => quarantinedAt,
    );
    await cold.loadFromWizard();

    expect(cold.profile!.fiscal.snapshots, isEmpty);
    expect(cold.profile!.fiscal.legacyDataNeedsReview, isFalse);
    expect(
      cold.profile!.dataSources.keys
          .where((path) => path.startsWith('fiscal.')),
      isEmpty,
    );
    expect(cold.canonicalProfileOwnerId, isNull);
    expect(persistence.saveCalls, 0);
    expect(jsonEncode(persistence.answers), before);
    expect(persistence.answers['_coach_tax_snapshots_v1'], malformedRoot);
    expect(
      (persistence.answers['__provenance'] as Map)['canton'],
      retainedNonFiscalProvenance,
    );
  });

  test('typed tax is default-off and refuses the unsafe legacy fallback',
      () async {
    expect(FeatureFlags.typedTaxProfile, isFalse);
    final persistence = _MemoryTaxPersistence();
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
    );

    await expectLater(
      provider.acceptTaxReview(_confirmation(_candidate(_assessmentId))),
      throwsA(isA<StateError>()),
    );
    expect(provider.profile, isNull);
    expect(persistence.saveCalls, 0);
  });

  test(
      'flag-off ignores seeded canonical and legacy tax without migration, baseline or publication',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final persistence = _MemoryTaxPersistence();
    final seedWriter = CoachProfileProvider(
      taxProfilePersistence: persistence,
    );
    await seedWriter.acceptTaxReview(
      _confirmation(_candidate(_assessmentId)),
    );
    persistence.answers['_coach_tax_taux_marginal'] = 31.5;
    final seededAnswers = _MemoryTaxPersistence._copy(persistence.answers);

    FeatureFlags.typedTaxProfile = false;
    final disabledSelection = FiscalSnapshotSelector.selectAssessedBaseline(
      seedWriter.profile!.fiscal,
      FiscalSnapshotQuery.precise(
        requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
        taxYear: 2025,
        cantonCode: 'VD',
        subjectScope: TaxSubjectScope.jointlyAssessedCouple,
      ),
    );
    expect(disabledSelection.status, FiscalSelectionStatus.partialAsk);
    expect(disabledSelection.snapshot, isNull);

    persistence.saveCalls = 0;
    final disabled = CoachProfileProvider(
      taxProfilePersistence: persistence,
    );
    var notifications = 0;
    disabled.addListener(() => notifications += 1);
    await expectLater(
      disabled.acceptTaxReview(_confirmation(_candidate(_provisionalId))),
      throwsA(isA<StateError>()),
    );
    expect(disabled.profile, isNull);
    expect(notifications, 0);
    expect(persistence.saveCalls, 0);
    expect(persistence.answers, seededAnswers);
    expect(
      persistence.answers.containsKey('__taxLegacyQuarantineV1'),
      isFalse,
    );
  });

  test(
      'flag-off cold loads canonical-plus-legacy and legacy-only stores byte-for-byte',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final canonicalAndLegacy = _MemoryTaxPersistence();
    final seedWriter = CoachProfileProvider(
      taxProfilePersistence: canonicalAndLegacy,
    );
    await seedWriter.acceptTaxReview(
      _confirmation(_candidate(_assessmentId)),
    );
    canonicalAndLegacy.answers['_coach_tax_revenu_imposable'] = 98500;
    canonicalAndLegacy.saveCalls = 0;

    final stores = <_MemoryTaxPersistence>[
      canonicalAndLegacy,
      _MemoryTaxPersistence({
        '_coach_profile_owner_v1': const CoachProfileOwnerRoot(
          _ownerId,
        ).toJsonString(),
        '_coach_tax_revenu_imposable': 98500,
        '_coach_tax_taux_marginal': 31.5,
        '_coach_tax_source': 'document_scan',
      }),
    ];
    FeatureFlags.typedTaxProfile = false;

    for (final persistence in stores) {
      final before = jsonEncode(persistence.answers);
      final cold = CoachProfileProvider(taxProfilePersistence: persistence);
      await cold.loadFromWizard();

      expect(cold.profile!.fiscal.snapshots, isEmpty);
      expect(
        cold.profile!.dataSources.keys.where(
          (path) => path == 'tauxMarginal' || path.startsWith('fiscal.'),
        ),
        isEmpty,
        reason: 'flag-off must expose neither canonical nor legacy tax facts',
      );
      final selection = FiscalSnapshotSelector.selectAssessedBaseline(
        cold.profile!.fiscal,
        FiscalSnapshotQuery.precise(
          requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
          taxYear: 2025,
          cantonCode: 'VD',
          subjectScope: TaxSubjectScope.jointlyAssessedCouple,
        ),
      );
      expect(selection.status, FiscalSelectionStatus.partialAsk);
      expect(selection.snapshot, isNull);
      expect(persistence.saveCalls, 0);
      expect(jsonEncode(persistence.answers), before);
      expect(
        persistence.answers.containsKey('__taxLegacyQuarantineV1'),
        isFalse,
      );
    }
  });

  test('malformed canonical roots preserve raw bytes without exposing facts',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final quarantinedAt = DateTime.utc(2026, 7, 14, 12, 30);
    final malformedRoots = <Object?>[
      null,
      '{not-valid-json',
      'true',
      'false',
      '123',
      '1.5',
      jsonEncode({
        'schemaVersion': 2,
        'snapshots': <Object>[],
        'legacyQuarantine': null,
      }),
    ];

    for (final malformedRoot in malformedRoots) {
      final persistence = _MemoryTaxPersistence({
        'q_birth_year': 1986,
        'q_canton': 'VD',
        '_coach_tax_snapshots_v1': malformedRoot,
        '_coach_tax_revenu_imposable': 98500,
        '_coach_tax_taux_marginal': 31.5,
        '_coach_tax_source': 'document_scan',
      });
      final before = jsonEncode(persistence.answers);
      final cold = CoachProfileProvider(
        taxProfilePersistence: persistence,
        now: () => quarantinedAt,
      );
      await cold.loadFromWizard();

      expect(cold.profile!.fiscal.snapshots, isEmpty);
      expect(
        cold.profile!.dataSources.keys.where(
          (path) => path == 'tauxMarginal' || path.startsWith('fiscal.'),
        ),
        isEmpty,
      );
      final selection = FiscalSnapshotSelector.selectAssessedBaseline(
        cold.profile!.fiscal,
        FiscalSnapshotQuery.precise(
          requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
          taxYear: 2025,
          cantonCode: 'VD',
          subjectScope: TaxSubjectScope.jointlyAssessedCouple,
        ),
      );
      expect(selection.status, FiscalSelectionStatus.partialAsk);
      expect(selection.snapshot, isNull);
      expect(cold.profile!.fiscal.legacyDataNeedsReview, isFalse);
      expect(cold.canonicalProfileOwnerId, isNull);
      expect(persistence.saveCalls, 0);
      expect(jsonEncode(persistence.answers), before);
      final backend =
          ReportPersistenceService.backendSafeAnswers(persistence.answers);
      expect(backend, {'q_birth_year': 1986, 'q_canton': 'VD'});
      expect(
        persistence.answers.containsKey('__taxLegacyQuarantineV1'),
        isFalse,
      );

      final secondCold = CoachProfileProvider(
        taxProfilePersistence: persistence,
        now: () => quarantinedAt.add(const Duration(days: 1)),
      );
      await secondCold.loadFromWizard();

      expect(secondCold.profile!.fiscal.snapshots, isEmpty);
      expect(
          secondCold.profile!.dataSources.keys.where(
            (path) => path == 'tauxMarginal' || path.startsWith('fiscal.'),
          ),
          isEmpty);
      expect(persistence.saveCalls, 0);
      expect(jsonEncode(persistence.answers), before);
    }
  });

  test('unreadable strict-secure placeholder is never overwritten', () async {
    FeatureFlags.typedTaxProfile = true;
    final persistence = _MemoryTaxPersistence({
      'q_birth_year': 1986,
      'q_canton': 'VD',
      '_coach_tax_snapshots_v1': '__secure__',
      '_coach_tax_revenu_imposable': 98500,
    });
    final before = jsonEncode(persistence.answers);
    final cold = CoachProfileProvider(
      taxProfilePersistence: persistence,
      now: () => DateTime.utc(2026, 7, 14, 12, 30),
    );

    await cold.loadFromWizard();

    expect(cold.profile!.fiscal.snapshots, isEmpty);
    expect(cold.profile!.fiscal.legacyDataNeedsReview, isFalse);
    expect(
      cold.profile!.dataSources.keys.where(
        (path) => path == 'tauxMarginal' || path.startsWith('fiscal.'),
      ),
      isEmpty,
    );
    expect(persistence.saveCalls, 0);
    expect(jsonEncode(persistence.answers), before);
    expect(persistence.answers['_coach_tax_snapshots_v1'], '__secure__');
    expect(
      ReportPersistenceService.backendSafeAnswers(persistence.answers),
      {'q_birth_year': 1986, 'q_canton': 'VD'},
    );
  });

  test(
      'assessment upserts one whole snapshot, exact provenance, cold reload and production selector oracle',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final persistence = _MemoryTaxPersistence({
      '_coach_profile_owner_v1': const CoachProfileOwnerRoot(
        _ownerId,
      ).toJsonString(),
    });
    final candidate = _candidate(_assessmentId);
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
    );

    await provider.acceptTaxReview(_confirmation(candidate));
    await provider.acceptTaxReview(
      _confirmation(candidate, federalIncome: 97100),
    );

    final immediate = provider.profile!;
    expect(immediate.fiscal.snapshots, hasLength(1));
    final snapshot = immediate.fiscal.snapshots.single;
    expect(snapshot.snapshotId, _assessmentId);
    expect(snapshot.profileOwnerId, isNotEmpty);
    expect(snapshot.taxYear, 2025);
    expect(snapshot.sourceDate, DateTime.utc(2026, 6, 20));
    expect(snapshot.cantonalCommunalTaxableIncomeChf, 98500);
    expect(snapshot.federalTaxableIncomeChf, 97100);
    expect(snapshot.explicitMarginalIncomeTaxRate, 0.325);
    expect(snapshot.explicitAverageIncomeTaxRate, 0.186);
    expect(snapshot.subjectScope, TaxSubjectScope.jointlyAssessedCouple);
    expect(immediate.conjoint, isNull,
        reason: 'missing partner is unknown, not zero');

    const path = 'fiscal.snapshots.$_assessmentId.federalTaxableIncomeChf';
    expect(immediate.dataSources[path], ProfileDataSource.certificate);
    expect(immediate.dataTimestamps[path], isNotNull);
    expect(immediate.dataSourceDates[path], DateTime.utc(2026, 6, 20));
    final envelope = Map<String, dynamic>.from(
      (persistence.answers['__provenance'] as Map)[path] as Map,
    );
    expect(envelope.keys.toSet(), {'source', 'updatedAt', 'sourceDate'});
    expect(envelope['source'], ProfileDataSource.certificate.name);
    expect(envelope['sourceDate'], '2026-06-20T00:00:00.000Z');

    for (final exactPath in [
      'fiscal.snapshots.$_assessmentId.sourceDate',
      'fiscal.snapshots.$_assessmentId.cantonalCommunalAssessedTax.amountChf',
      'fiscal.snapshots.$_assessmentId.cantonalCommunalAssessedTax.authorityScope',
      'fiscal.snapshots.$_assessmentId.cantonalCommunalAssessedTax.baseScope',
    ]) {
      final exactEnvelope = Map<String, dynamic>.from(
        (persistence.answers['__provenance'] as Map)[exactPath] as Map,
      );
      expect(exactEnvelope.keys.toSet(), {'source', 'updatedAt', 'sourceDate'});
      expect(exactEnvelope['source'], ProfileDataSource.certificate.name);
      expect(exactEnvelope['sourceDate'], '2026-06-20T00:00:00.000Z');
      expect(immediate.dataSources[exactPath], ProfileDataSource.certificate);
      expect(immediate.dataTimestamps[exactPath], isNotNull);
      expect(
        exactEnvelope['updatedAt'],
        immediate.dataTimestamps[exactPath]!.toIso8601String(),
      );
      expect(
        immediate.dataSourceDates[exactPath],
        DateTime.utc(2026, 6, 20),
      );
    }

    final persisted = jsonEncode(persistence.answers);
    expect(persistence.answers['_coach_tax_snapshots_v1'], isA<String>());
    final taxEnvelope = Map<String, dynamic>.from(
      jsonDecode(persistence.answers['_coach_tax_snapshots_v1'] as String)
          as Map,
    );
    expect(taxEnvelope['schemaVersion'], 1);
    expect(taxEnvelope['snapshots'], hasLength(1));
    expect(taxEnvelope['legacyQuarantine'], isNull);
    expect(persisted, isNot(contains('PII-NEVER-PERSIST')));
    expect(persistence.saveCalls, 2);

    final cold = CoachProfileProvider(taxProfilePersistence: persistence);
    await cold.loadFromWizard();
    expect(cold.profile!.fiscal.snapshots.single, snapshot);
    expect(
      cold.profile!.fiscal.snapshots.single.profileOwnerId,
      snapshot.profileOwnerId,
    );

    final selected = FiscalSnapshotSelector.selectAssessedBaseline(
      cold.profile!.fiscal,
      FiscalSnapshotQuery.precise(
        requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
        taxYear: 2025,
        cantonCode: 'VD',
        subjectScope: TaxSubjectScope.jointlyAssessedCouple,
      ),
    );
    expect(selected.status, FiscalSelectionStatus.available);
    expect(selected.snapshot?.snapshotId, _assessmentId);

    final confidence = ConfidenceScorer.score(cold.profile!);
    expect(
      confidence.prompts.where((p) => p.fieldPath == 'fiscal.assessedBaseline'),
      isEmpty,
      reason: 'removing/bypassing selectAssessedBaseline must fail this oracle',
    );
  });

  test('pending save publishes only after its single persistence completes',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final persistence = _MemoryTaxPersistence({
      '_coach_profile_owner_v1': const CoachProfileOwnerRoot(
        _ownerId,
      ).toJsonString(),
    })
      ..holdNextSave = true;
    final before = _MemoryTaxPersistence._copy(persistence.answers);
    final provider = CoachProfileProvider(taxProfilePersistence: persistence);
    var notifications = 0;
    provider.addListener(() => notifications += 1);

    final write = provider.acceptTaxReview(
      _confirmation(_candidate(_assessmentId)),
    );
    await Future<void>.delayed(Duration.zero);

    expect(persistence.saveCalls, 1);
    expect(persistence.answers, before);
    expect(provider.profile, isNull);
    expect(notifications, 0);

    persistence.completePendingSave();
    await write;
    expect(persistence.saveCalls, 1);
    expect(persistence.answers, isNotEmpty);
    expect(provider.profile!.fiscal.snapshots.single.snapshotId, _assessmentId);
    expect(notifications, 1);
  });

  test('failed replacement keeps old profile and store with exactly one call',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final persistence = _MemoryTaxPersistence();
    final provider = CoachProfileProvider(taxProfilePersistence: persistence);
    final candidate = _candidate(_assessmentId);
    await provider.acceptTaxReview(_confirmation(candidate));
    final oldProfile = provider.profile;
    final oldAnswers = _MemoryTaxPersistence._copy(persistence.answers);
    final callsBeforeFailure = persistence.saveCalls;
    var notifications = 0;
    provider.addListener(() => notifications += 1);
    persistence.failNextSave = true;

    await expectLater(
      provider.acceptTaxReview(
        _confirmation(candidate, federalIncome: 97100),
      ),
      throwsA(isA<StateError>()),
    );
    expect(identical(provider.profile, oldProfile), isTrue);
    expect(notifications, 0);
    expect(persistence.answers, oldAnswers);
    expect(persistence.saveCalls, callsBeforeFailure + 1);
  });

  test('legacy tax keys move into the one nested secure quarantine only',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final persistence = _MemoryTaxPersistence({
      '_coach_tax_revenu_imposable': 98500,
      '_coach_tax_taux_marginal': 22.3,
      '_coach_tax_source': 'document_scan',
    });
    final provider = CoachProfileProvider(taxProfilePersistence: persistence);

    await provider.loadFromWizard();

    expect(SecureWizardStore.isSensitive('_coach_tax_snapshots_v1'), isTrue);
    expect(
      persistence.answers.keys.where(
        (key) =>
            key.startsWith('_coach_tax_') && key != '_coach_tax_snapshots_v1',
      ),
      isEmpty,
    );
    expect(persistence.answers['_coach_tax_snapshots_v1'], isA<String>());
    final envelope = Map<String, dynamic>.from(
      jsonDecode(persistence.answers['_coach_tax_snapshots_v1'] as String)
          as Map,
    );
    expect(
      envelope.keys.toSet(),
      {'schemaVersion', 'snapshots', 'legacyQuarantine'},
    );
    expect(envelope['schemaVersion'], 1);
    expect(envelope['snapshots'], isEmpty);
    final quarantine = Map<String, dynamic>.from(
      envelope['legacyQuarantine'] as Map,
    );
    expect(quarantine['legacySchemaVersion'], 0);
    expect(quarantine['reasonCodes'], isNotEmpty);
    expect(
      quarantine['values'],
      containsPair('_coach_tax_taux_marginal', 22.3),
    );
    expect(quarantine['quarantinedAt'], isNotNull);
    expect(
      persistence.answers.keys.where((k) => k.contains('tax_quarantine')),
      isEmpty,
    );
    expect(
      persistence.answers.containsKey('__taxLegacyQuarantineV1'),
      isFalse,
    );
    expect(provider.profile!.fiscal.snapshots, isEmpty);
  });

  test(
      'canonical root unions loose legacy tax with existing quarantine without overwrite and stays idempotent',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final persistence = _MemoryTaxPersistence();
    final writer = CoachProfileProvider(taxProfilePersistence: persistence);
    await writer.acceptTaxReview(
      _confirmation(_candidate(_assessmentId)),
    );
    final canonicalBefore = TaxSnapshot.fromJson(
      Map<String, dynamic>.from(
        (jsonDecode(
          persistence.answers['_coach_tax_snapshots_v1'] as String,
        ) as Map)['snapshots']
            .single as Map,
      ),
    );
    const existingQuarantinedAt = '2026-07-01T00:00:00.000Z';
    final canonicalRoot = Map<String, dynamic>.from(
      jsonDecode(persistence.answers['_coach_tax_snapshots_v1'] as String)
          as Map,
    )..['legacyQuarantine'] = {
        'legacySchemaVersion': 0,
        'reasonCodes': ['prior_import_needs_review'],
        'values': {
          '_coach_tax_taux_marginal': 19.8,
          '_coach_tax_existing_note': 'preserve-me',
        },
        'quarantinedAt': existingQuarantinedAt,
      };
    persistence.answers['_coach_tax_snapshots_v1'] = jsonEncode(canonicalRoot);
    persistence.answers.addAll({
      '_coach_tax_revenu_imposable': 98500,
      '_coach_tax_taux_marginal': 22.3,
      '_coach_tax_source': 'document_scan',
    });
    persistence.saveCalls = 0;

    final firstCold = CoachProfileProvider(
      taxProfilePersistence: persistence,
    );
    await firstCold.loadFromWizard();

    expect(firstCold.profile!.fiscal.snapshots, [canonicalBefore]);
    expect(
      persistence.answers.keys.where(
        (key) =>
            key.startsWith('_coach_tax_') && key != '_coach_tax_snapshots_v1',
      ),
      isEmpty,
    );
    final migratedRoot = Map<String, dynamic>.from(
      jsonDecode(persistence.answers['_coach_tax_snapshots_v1'] as String)
          as Map,
    );
    expect(migratedRoot['snapshots'], hasLength(1));
    final quarantine = Map<String, dynamic>.from(
      migratedRoot['legacyQuarantine'] as Map,
    );
    expect(
      quarantine['values'],
      {
        '_coach_tax_revenu_imposable': 98500,
        '_coach_tax_taux_marginal': 19.8,
        '_coach_tax_source': 'document_scan',
        '_coach_tax_existing_note': 'preserve-me',
      },
    );
    expect(
      (quarantine['reasonCodes'] as List).toSet(),
      {'prior_import_needs_review', 'untyped_legacy_tax_facts'},
    );
    expect(quarantine['legacySchemaVersion'], 0);
    expect(quarantine['quarantinedAt'], existingQuarantinedAt);
    expect(persistence.saveCalls, 1);

    final afterFirstCold = jsonEncode(persistence.answers);
    final secondCold = CoachProfileProvider(
      taxProfilePersistence: persistence,
    );
    await secondCold.loadFromWizard();

    expect(secondCold.profile!.fiscal.snapshots, [canonicalBefore]);
    expect(jsonEncode(persistence.answers), afterFirstCold);
    expect(persistence.saveCalls, 1);
  });

  test(
      'same UUID replacement removes absent facts and their old provenance paths',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final persistence = _MemoryTaxPersistence();
    final provider = CoachProfileProvider(taxProfilePersistence: persistence);
    final candidate = _candidate(_assessmentId);
    await provider.acceptTaxReview(_confirmation(candidate));

    await provider.acceptTaxReview(
      _confirmation(
        candidate,
        federalIncome: null,
        subjectScope: TaxSubjectScope.individual,
      ),
    );

    expect(provider.profile!.fiscal.snapshots, hasLength(1));
    final replacement = provider.profile!.fiscal.snapshots.single;
    expect(replacement.snapshotId, _assessmentId);
    expect(replacement.federalTaxableIncomeChf, isNull);
    expect(replacement.subjectScope, TaxSubjectScope.individual);
    const removedPath =
        'fiscal.snapshots.$_assessmentId.federalTaxableIncomeChf';
    expect(provider.profile!.dataSources.containsKey(removedPath), isFalse);
    expect(provider.profile!.dataTimestamps.containsKey(removedPath), isFalse);
    expect(provider.profile!.dataSourceDates.containsKey(removedPath), isFalse);
    expect(
      (persistence.answers['__provenance'] as Map).containsKey(removedPath),
      isFalse,
    );
  });

  test(
      '2024 assessment and 2025 provisional coexist as whole cold snapshots without merge',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final persistence = _MemoryTaxPersistence();
    final writer = CoachProfileProvider(taxProfilePersistence: persistence);
    await writer.acceptTaxReview(
      _confirmation(
        _candidate(_assessmentId),
        taxYear: 2024,
        sourceDate: DateTime.utc(2025, 6, 20),
      ),
    );
    await writer.acceptTaxReview(
      _confirmation(
        _candidate(_provisionalId),
        kind: TaxDocumentKind.provisionalBill,
        status: TaxAssessmentStatus.provisional,
        taxYear: 2025,
        basedOnTaxYear: 2024,
        sourceDate: DateTime.utc(2026, 2, 5),
        cantonalIncome: null,
        federalIncome: null,
        cantonalWealth: null,
        cantonalTax: null,
        federalTax: AssessedTaxAmount(
          amountChf: 4200,
          authorityScope: TaxAuthorityScope.federalDirect,
          baseScope: TaxBaseScope.incomeOnly,
        ),
        marginalRate: null,
        averageRate: null,
      ),
    );

    final cold = CoachProfileProvider(taxProfilePersistence: persistence);
    await cold.loadFromWizard();
    expect(cold.profile!.fiscal.snapshots, hasLength(2));
    final byId = {
      for (final snapshot in cold.profile!.fiscal.snapshots)
        snapshot.snapshotId: snapshot,
    };
    expect(byId[_assessmentId]!.taxYear, 2024);
    expect(byId[_assessmentId]!.federalTaxableIncomeChf, 96200);
    expect(byId[_provisionalId]!.taxYear, 2025);
    expect(byId[_provisionalId]!.basedOnTaxYear, 2024);
    expect(byId[_provisionalId]!.federalTaxableIncomeChf, isNull);
    expect(byId[_provisionalId]!.cantonalCommunalAssessedTax, isNull);
    expect(byId[_provisionalId]!.federalDirectAssessedTax!.amountChf, 4200);

    final assessed2024 = FiscalSnapshotSelector.selectAssessedBaseline(
      cold.profile!.fiscal,
      FiscalSnapshotQuery.precise(
        requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
        taxYear: 2024,
        cantonCode: 'VD',
        subjectScope: TaxSubjectScope.jointlyAssessedCouple,
      ),
    );
    expect(assessed2024.status, FiscalSelectionStatus.available);
    expect(assessed2024.snapshot?.snapshotId, _assessmentId);
    final provisional2025 = FiscalSnapshotSelector.selectAssessedBaseline(
      cold.profile!.fiscal,
      FiscalSnapshotQuery.precise(
        requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
        taxYear: 2025,
        cantonCode: 'VD',
        subjectScope: TaxSubjectScope.jointlyAssessedCouple,
      ),
    );
    expect(provisional2025.status, FiscalSelectionStatus.partialAsk);
    expect(provisional2025.snapshot, isNull);
  });

  test('invalid document kind and assessment status pairs never save',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final persistence = _MemoryTaxPersistence();
    final provider = CoachProfileProvider(taxProfilePersistence: persistence);

    Future<void> submitInvalid(
      String id,
      TaxDocumentKind kind,
      TaxAssessmentStatus status,
    ) {
      return Future<void>.sync(() {
        final confirmation = _confirmation(
          _candidate(id),
          kind: kind,
          status: status,
        );
        return provider.acceptTaxReview(confirmation);
      });
    }

    await expectLater(
      submitInvalid(
        '66666666-6666-4666-8666-666666666666',
        TaxDocumentKind.taxpayerReturn,
        TaxAssessmentStatus.inForce,
      ),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      submitInvalid(
        '77777777-7777-4777-8777-777777777777',
        TaxDocumentKind.provisionalBill,
        TaxAssessmentStatus.assessedAppealable,
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(persistence.saveCalls, 0);
    expect(persistence.answers, isEmpty);
    expect(provider.profile, isNull);
  });

  test('assessments missing year or jurisdiction stay partial', () async {
    FeatureFlags.typedTaxProfile = true;
    final confirmations = <TaxReviewConfirmation Function()>[
      () => _confirmation(
            _candidate('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
            taxYear: null,
          ),
      () => _confirmation(
            _candidate('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
            cantonCode: null,
            municipalityId: null,
            municipalityLabel: null,
          ),
    ];

    for (final buildConfirmation in confirmations) {
      final persistence = _MemoryTaxPersistence();
      final writer = CoachProfileProvider(taxProfilePersistence: persistence);
      await writer.acceptTaxReview(buildConfirmation());
      final cold = CoachProfileProvider(taxProfilePersistence: persistence);
      await cold.loadFromWizard();
      final selection = FiscalSnapshotSelector.selectAssessedBaseline(
        cold.profile!.fiscal,
        FiscalSnapshotQuery.precise(
          requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
          taxYear: 2025,
          cantonCode: 'VD',
          subjectScope: TaxSubjectScope.jointlyAssessedCouple,
        ),
      );
      expect(selection.status, FiscalSelectionStatus.partialAsk);
      expect(selection.snapshot, isNull);
    }
  });

  test('non-UUIDv4 candidate identity is rejected before persistence',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final persistence = _MemoryTaxPersistence();
    final provider = CoachProfileProvider(taxProfilePersistence: persistence);

    await expectLater(
      Future<void>.sync(() {
        final invalidCandidate = _candidate('scan-session.PII-NEVER-ID');
        return provider.acceptTaxReview(_confirmation(invalidCandidate));
      }),
      throwsA(isA<ArgumentError>()),
    );
    expect(persistence.saveCalls, 0);
    expect(persistence.answers, isEmpty);
    expect(provider.profile, isNull);
  });

  test(
      'cold assessedAppealable baseline keeps prompt without a final reference',
      () async {
    FeatureFlags.typedTaxProfile = true;
    FeatureFlags.documentTaxAssessmentEnabled = true;
    final query = FiscalSnapshotQuery.precise(
      requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
      taxYear: 2025,
      cantonCode: 'VD',
      subjectScope: TaxSubjectScope.jointlyAssessedCouple,
    );

    final provisionalStore = _MemoryTaxPersistence();
    final provisionalWriter = CoachProfileProvider(
      taxProfilePersistence: provisionalStore,
    );
    await provisionalWriter.acceptTaxReview(
      _confirmation(
        _candidate(_provisionalId),
        kind: TaxDocumentKind.provisionalBill,
        status: TaxAssessmentStatus.provisional,
        basedOnTaxYear: 2024,
        marginalRate: null,
      ),
    );
    final provisionalCold = CoachProfileProvider(
      taxProfilePersistence: provisionalStore,
    );
    await provisionalCold.loadFromWizard();
    final incompleteSelection = FiscalSnapshotSelector.selectAssessedBaseline(
      provisionalCold.profile!.fiscal,
      query,
    );
    expect(incompleteSelection.status, FiscalSelectionStatus.partialAsk);
    expect(incompleteSelection.snapshot, isNull);
    final incompleteConfidence = ConfidenceScorer.score(
      provisionalCold.profile!,
    );
    final fiscalPrompts = incompleteConfidence.prompts
        .where((prompt) => prompt.fieldPath == 'fiscal.assessedBaseline')
        .toList();
    expect(fiscalPrompts, hasLength(1));
    expect(fiscalPrompts.single.category, 'fiscalite');
    expect(
      incompleteConfidence.prompts
          .where((prompt) => prompt.fieldPath == 'tauxMarginal'),
      isEmpty,
      reason: 'legacy scalar-source confidence must not bypass the selector',
    );

    final assessmentStore = _MemoryTaxPersistence();
    final assessmentWriter = CoachProfileProvider(
      taxProfilePersistence: assessmentStore,
    );
    await assessmentWriter.acceptTaxReview(
      _confirmation(_candidate(_assessmentId)),
    );
    final assessmentCold = CoachProfileProvider(
      taxProfilePersistence: assessmentStore,
    );
    await assessmentCold.loadFromWizard();
    final availableSelection = FiscalSnapshotSelector.selectAssessedBaseline(
      assessmentCold.profile!.fiscal,
      query,
    );
    expect(availableSelection.status, FiscalSelectionStatus.available);
    expect(availableSelection.snapshot?.snapshotId, _assessmentId);
    final availableConfidence = ConfidenceScorer.score(
      assessmentCold.profile!,
    );
    expect(
      availableConfidence.prompts
          .where((prompt) => prompt.fieldPath == 'fiscal.assessedBaseline'),
      hasLength(1),
      reason: 'an assessed baseline cannot replace a precise final reference',
    );
  });

  test('candidate UUID factory runs once and identical duplicates do not clash',
      () async {
    FeatureFlags.typedTaxProfile = true;
    var factoryCalls = 0;
    final first = _candidate(
      _assessmentId,
      onSnapshotIdFactory: () => factoryCalls += 1,
    );
    expect(factoryCalls, 1);
    expect(first.snapshotId, _assessmentId);
    expect(first.snapshotId, _assessmentId);
    expect(factoryCalls, 1);

    final persistence = _MemoryTaxPersistence();
    final provider = CoachProfileProvider(taxProfilePersistence: persistence);
    await provider.acceptTaxReview(_confirmation(first));
    await provider.acceptTaxReview(
      _confirmation(
        _candidate('88888888-8888-4888-8888-888888888888'),
      ),
    );
    final selection = FiscalSnapshotSelector.selectAssessedBaseline(
      provider.profile!.fiscal,
      FiscalSnapshotQuery.precise(
        requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
        taxYear: 2025,
        cantonCode: 'VD',
        subjectScope: TaxSubjectScope.jointlyAssessedCouple,
      ),
    );
    expect(selection.status, FiscalSelectionStatus.available);
    expect(selection.snapshot, isNotNull);
    expect(selection.conflictingSnapshotIds, isEmpty);
  });

  test('source mapping is document-kind owned and conflicts beat tie-breakers',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final persistence = _MemoryTaxPersistence();
    final provider = CoachProfileProvider(taxProfilePersistence: persistence);
    final assessment = _candidate(_assessmentId);
    final provisional = _candidate(_provisionalId);
    final taxpayerReturn = _candidate(_returnId);
    final finalBill = _candidate(_finalBillId);

    await provider.acceptTaxReview(_confirmation(assessment));
    await provider.acceptTaxReview(
      _confirmation(
        provisional,
        kind: TaxDocumentKind.provisionalBill,
        status: TaxAssessmentStatus.provisional,
        basedOnTaxYear: 2024,
        sourceDate: null,
        marginalRate: null,
      ),
    );
    await provider.acceptTaxReview(
      _confirmation(
        taxpayerReturn,
        kind: TaxDocumentKind.taxpayerReturn,
        status: TaxAssessmentStatus.selfDeclared,
        marginalRate: null,
      ),
    );
    await provider.acceptTaxReview(
      _confirmation(
        finalBill,
        kind: TaxDocumentKind.finalTaxBill,
        status: TaxAssessmentStatus.unknown,
        taxYear: 2023,
        marginalRate: 0.29,
      ),
    );

    final sources = provider.profile!.dataSources;
    expect(
      sources['fiscal.snapshots.$_assessmentId.taxYear'],
      ProfileDataSource.certificate,
    );
    expect(
      sources['fiscal.snapshots.$_provisionalId.taxYear'],
      ProfileDataSource.estimated,
    );
    expect(
      sources['fiscal.snapshots.$_returnId.taxYear'],
      ProfileDataSource.userInput,
    );
    expect(
      sources['fiscal.snapshots.$_finalBillId.taxYear'],
      ProfileDataSource.estimated,
    );
    expect(
      sources['fiscal.snapshots.$_finalBillId.explicitMarginalIncomeTaxRate'],
      ProfileDataSource.estimated,
    );
    const provisionalSourceDatePath =
        'fiscal.snapshots.$_provisionalId.sourceDate';
    expect(
        provider.profile!.dataSourceDates[provisionalSourceDatePath], isNull);
    final provisionalDateProvenance = Map<String, dynamic>.from(
      (persistence.answers['__provenance'] as Map)[provisionalSourceDatePath]
          as Map,
    );
    expect(provisionalDateProvenance['sourceDate'], isNull);

    final finalBillOnly = FiscalSnapshotSelector.selectAssessedBaseline(
      provider.profile!.fiscal,
      FiscalSnapshotQuery.precise(
        requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
        taxYear: 2023,
        cantonCode: 'VD',
        subjectScope: TaxSubjectScope.jointlyAssessedCouple,
      ),
    );
    expect(finalBillOnly.status, FiscalSelectionStatus.partialAsk);
    expect(finalBillOnly.snapshot, isNull);

    final assessedBaseline = FiscalSnapshotSelector.selectAssessedBaseline(
      provider.profile!.fiscal,
      FiscalSnapshotQuery.precise(
        requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
        taxYear: 2025,
        cantonCode: 'VD',
        subjectScope: TaxSubjectScope.jointlyAssessedCouple,
      ),
    );
    expect(assessedBaseline.status, FiscalSelectionStatus.available);
    expect(assessedBaseline.snapshot?.snapshotId, _assessmentId);

    final conflictCandidate = _candidate(
      '44444444-4444-4444-8444-444444444444',
    );
    await provider.acceptTaxReview(
      _confirmation(conflictCandidate, federalIncome: 95100),
    );
    final conflict = FiscalSnapshotSelector.selectAssessedBaseline(
      provider.profile!.fiscal,
      FiscalSnapshotQuery.precise(
        requestedField: TaxSnapshotField.federalTaxableIncomeChf,
        taxYear: 2025,
        cantonCode: 'VD',
        subjectScope: TaxSubjectScope.jointlyAssessedCouple,
      ),
    );
    expect(conflict.status, FiscalSelectionStatus.partialAsk);
    expect(conflict.snapshot, isNull);
    expect(conflict.conflictingSnapshotIds,
        containsAll({_assessmentId, conflictCandidate.snapshotId}));
  });

  test('assessment missing the requested field stays partial', () async {
    FeatureFlags.typedTaxProfile = true;
    final persistence = _MemoryTaxPersistence();
    final provider = CoachProfileProvider(taxProfilePersistence: persistence);
    await provider.acceptTaxReview(
      _confirmation(
        _candidate(_assessmentId),
        cantonalIncome: null,
      ),
    );

    final selection = FiscalSnapshotSelector.selectAssessedBaseline(
      provider.profile!.fiscal,
      FiscalSnapshotQuery.precise(
        requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
        taxYear: 2025,
        subjectScope: TaxSubjectScope.jointlyAssessedCouple,
        cantonCode: 'VD',
      ),
    );

    expect(selection.status, FiscalSelectionStatus.partialAsk);
    expect(selection.snapshot, isNull);
  });

  test('unknown authority and non-canonical bases are never consumable',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final invalidScopes = <(TaxAuthorityScope, TaxBaseScope)>[
      (TaxAuthorityScope.unknown, TaxBaseScope.incomeAndWealth),
      (TaxAuthorityScope.cantonalCommunalCombined, TaxBaseScope.unknown),
      (
        TaxAuthorityScope.cantonalCommunalCombined,
        TaxBaseScope.totalInvoice,
      ),
    ];
    for (final scope in invalidScopes) {
      final persistence = _MemoryTaxPersistence();
      final provider = CoachProfileProvider(taxProfilePersistence: persistence);
      await provider.acceptTaxReview(
        _confirmation(
          _candidate(_assessmentId),
          cantonalTax: AssessedTaxAmount(
            amountChf: 14520,
            authorityScope: scope.$1,
            baseScope: scope.$2,
          ),
        ),
      );

      final selection = FiscalSnapshotSelector.selectAssessedBaseline(
        provider.profile!.fiscal,
        FiscalSnapshotQuery.precise(
          requestedField: TaxSnapshotField.cantonalCommunalAssessedTax,
          taxYear: 2025,
          subjectScope: TaxSubjectScope.jointlyAssessedCouple,
          cantonCode: 'VD',
          authorityScope: scope.$1,
          baseScope: scope.$2,
        ),
      );

      expect(
        selection.status,
        FiscalSelectionStatus.partialAsk,
        reason: '$scope must not be a financial baseline',
      );
      expect(selection.snapshot, isNull);
    }
  });

  test('assessed-tax selector requires an exact authority and base scope',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final persistence = _MemoryTaxPersistence();
    final provider = CoachProfileProvider(taxProfilePersistence: persistence);
    await provider.acceptTaxReview(
      _confirmation(_candidate(_assessmentId)),
    );

    FiscalSelectionResult select({
      TaxAuthorityScope? authorityScope,
      TaxBaseScope? baseScope,
    }) {
      return FiscalSnapshotSelector.selectAssessedBaseline(
        provider.profile!.fiscal,
        FiscalSnapshotQuery.precise(
          requestedField: TaxSnapshotField.cantonalCommunalAssessedTax,
          taxYear: 2025,
          subjectScope: TaxSubjectScope.jointlyAssessedCouple,
          cantonCode: 'VD',
          authorityScope: authorityScope,
          baseScope: baseScope,
        ),
      );
    }

    final unspecified = select();
    expect(unspecified.status, FiscalSelectionStatus.partialAsk);
    expect(unspecified.snapshot, isNull);

    final exact = select(
      authorityScope: TaxAuthorityScope.cantonalCommunalCombined,
      baseScope: TaxBaseScope.incomeAndWealth,
    );
    expect(exact.status, FiscalSelectionStatus.available);
    expect(exact.snapshot?.snapshotId, _assessmentId);

    final mismatchedAuthority = select(
      authorityScope: TaxAuthorityScope.cantonalOnly,
      baseScope: TaxBaseScope.incomeAndWealth,
    );
    expect(mismatchedAuthority.status, FiscalSelectionStatus.partialAsk);
    expect(mismatchedAuthority.snapshot, isNull);

    final mismatchedBase = select(
      authorityScope: TaxAuthorityScope.cantonalCommunalCombined,
      baseScope: TaxBaseScope.incomeOnly,
    );
    expect(mismatchedBase.status, FiscalSelectionStatus.partialAsk);
    expect(mismatchedBase.snapshot, isNull);

    final federalQueryForCantonalField = select(
      authorityScope: TaxAuthorityScope.federalDirect,
      baseScope: TaxBaseScope.incomeOnly,
    );
    expect(
      federalQueryForCantonalField.status,
      FiscalSelectionStatus.partialAsk,
      reason: 'a valid federal slot must not satisfy the requested ICC field',
    );
    expect(federalQueryForCantonalField.snapshot, isNull);
  });
}
