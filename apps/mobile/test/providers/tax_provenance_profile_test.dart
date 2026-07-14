import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';

const _assessmentId = '11111111-1111-4111-8111-111111111111';
const _provisionalId = '22222222-2222-4222-8222-222222222222';
const _returnId = '33333333-3333-4333-8333-333333333333';
const _finalBillId = '55555555-5555-4555-8555-555555555555';
const _useDefaultSourceDate = Object();

class _MemoryTaxPersistence implements TaxProfilePersistence {
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
  final extraction = ExtractionResult(
    documentType: DocumentType.taxDeclaration,
    fields: const [
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
    warnings: const [],
    disclaimer: '',
    sources: const [],
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
  int? taxYear = 2025,
  int? basedOnTaxYear,
  Object? sourceDate = _useDefaultSourceDate,
  String? cantonCode = 'VD',
  String? municipalityId = '5586',
  String? municipalityLabel = 'Lausanne',
  double? cantonalIncome = 98500,
  double? federalIncome = 96200,
  double? cantonalWealth = 245000,
  AssessedTaxAmount? cantonalTax = const AssessedTaxAmount(
    amountChf: 14520,
    authorityScope: TaxAuthorityScope.cantonalCommunalCombined,
    baseScope: TaxBaseScope.incomeAndWealth,
  ),
  AssessedTaxAmount? federalTax = const AssessedTaxAmount(
    amountChf: 3840,
    authorityScope: TaxAuthorityScope.federalDirect,
    baseScope: TaxBaseScope.incomeOnly,
  ),
  double? marginalRate = 0.325,
  double? averageRate = 0.186,
  TaxSubjectScope subjectScope = TaxSubjectScope.jointlyAssessedCouple,
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
    subjectScope: subjectScope,
    cantonCode: cantonCode,
    municipalityId: municipalityId,
    municipalityLabel: municipalityLabel,
    cantonalCommunalTaxableIncomeChf: cantonalIncome,
    federalTaxableIncomeChf: federalIncome,
    cantonalCommunalTaxableWealthChf: cantonalWealth,
    cantonalCommunalAssessedTax: cantonalTax,
    federalDirectAssessedTax: federalTax,
    explicitMarginalIncomeTaxRate: marginalRate,
    explicitAverageIncomeTaxRate: averageRate,
  );
}

void main() {
  tearDown(() {
    FeatureFlags.typedTaxProfile = false;
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
      const FiscalSnapshotQuery(
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
        const FiscalSnapshotQuery(
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

  test('malformed canonical tax roots fail closed without legacy fallback',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final malformedRoots = <String>[
      '{not-valid-json',
      jsonEncode({
        'schemaVersion': 2,
        'snapshots': <Object>[],
        'legacyQuarantine': null,
      }),
    ];

    for (final malformedRoot in malformedRoots) {
      final persistence = _MemoryTaxPersistence({
        '_coach_tax_snapshots_v1': malformedRoot,
        '_coach_tax_revenu_imposable': 98500,
        '_coach_tax_taux_marginal': 31.5,
        '_coach_tax_source': 'document_scan',
      });
      final before = jsonEncode(persistence.answers);
      final cold = CoachProfileProvider(taxProfilePersistence: persistence);
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
        const FiscalSnapshotQuery(
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

  test(
      'assessment upserts one whole snapshot, exact provenance, cold reload and production selector oracle',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final persistence = _MemoryTaxPersistence();
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

    final path = 'fiscal.snapshots.$_assessmentId.federalTaxableIncomeChf';
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
      const FiscalSnapshotQuery(
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
    final persistence = _MemoryTaxPersistence()..holdNextSave = true;
    final provider = CoachProfileProvider(taxProfilePersistence: persistence);
    var notifications = 0;
    provider.addListener(() => notifications += 1);

    final write = provider.acceptTaxReview(
      _confirmation(_candidate(_assessmentId)),
    );
    await Future<void>.delayed(Duration.zero);

    expect(persistence.saveCalls, 1);
    expect(persistence.answers, isEmpty);
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
    final removedPath =
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
        federalTax: const AssessedTaxAmount(
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
      const FiscalSnapshotQuery(
        taxYear: 2024,
        cantonCode: 'VD',
        subjectScope: TaxSubjectScope.jointlyAssessedCouple,
      ),
    );
    expect(assessed2024.status, FiscalSelectionStatus.available);
    expect(assessed2024.snapshot?.snapshotId, _assessmentId);
    final provisional2025 = FiscalSnapshotSelector.selectAssessedBaseline(
      cold.profile!.fiscal,
      const FiscalSnapshotQuery(
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
        const FiscalSnapshotQuery(
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
      'two cold reloads make ConfidenceScorer follow assessed-baseline availability',
      () async {
    FeatureFlags.typedTaxProfile = true;
    const query = FiscalSnapshotQuery(
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
      isEmpty,
      reason: 'bypassing the production selector must fail this A/B oracle',
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
      const FiscalSnapshotQuery(
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
    final provisionalSourceDatePath =
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
      const FiscalSnapshotQuery(
        taxYear: 2023,
        cantonCode: 'VD',
        subjectScope: TaxSubjectScope.jointlyAssessedCouple,
      ),
    );
    expect(finalBillOnly.status, FiscalSelectionStatus.partialAsk);
    expect(finalBillOnly.snapshot, isNull);

    final assessedBaseline = FiscalSnapshotSelector.selectAssessedBaseline(
      provider.profile!.fiscal,
      const FiscalSnapshotQuery(
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
      const FiscalSnapshotQuery(
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
}
