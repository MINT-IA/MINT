import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/l10n/confidence_prompt_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FeatureFlags.typedTaxProfile = true;
    FeatureFlags.documentTaxAssessmentEnabled = false;
  });

  tearDown(() {
    FeatureFlags.typedTaxProfile = false;
    FeatureFlags.documentTaxAssessmentEnabled = false;
  });

  test('tax acquisition prompt requires both independent kill switches', () {
    for (final flags in const [
      (typed: false, document: false),
      (typed: true, document: false),
      (typed: false, document: true),
    ]) {
      FeatureFlags.typedTaxProfile = flags.typed;
      FeatureFlags.documentTaxAssessmentEnabled = flags.document;
      final result = ConfidenceScorer.score(CoachProfile.defaults());

      expect(
        result.prompts.where(
          (prompt) =>
              prompt.copyCode == EnrichmentPromptCopyCode.taxDocument ||
              prompt.machineCode == 'tax.document.review' ||
              prompt.fieldPath == 'fiscal.assessedBaseline',
        ),
        isEmpty,
        reason: 'typed=${flags.typed}, document=${flags.document}',
      );
    }
  });

  test('enabled tax prompt keeps identity and copy at the UI boundary',
      () async {
    FeatureFlags.typedTaxProfile = true;
    FeatureFlags.documentTaxAssessmentEnabled = true;
    final result = ConfidenceScorer.score(CoachProfile.defaults());
    final prompt = result.prompts.singleWhere(
      (candidate) => candidate.fieldPath == 'fiscal.assessedBaseline',
    );

    expect(prompt.copyCode, EnrichmentPromptCopyCode.taxDocument);
    expect(prompt.copyArgument, isNull);
    expect(prompt.machineCode, 'tax.document.review');
    expect(prompt.fieldPath, 'fiscal.assessedBaseline');
    expect(prompt.category, 'fiscalite');
    expect(prompt.impact, 8);
    expect(prompt.label, isEmpty);
    expect(prompt.action, isEmpty);
    expect(
      prompt.machineDescriptor,
      'code=tax.document.review;field=fiscal.assessedBaseline;impact=8;category=fiscalite',
    );
    expect('/data-block/${prompt.category}', '/data-block/fiscalite');

    const forbiddenUniversalClaims = [
      'taux marginal',
      'marginal rate',
      'grenzsteuersatz',
      'tipo marginal',
      'aliquota marginale',
      'taxa marginal',
      'lifd',
      'art. 38',
      '60%',
      '130%',
      'garanti',
      'guaranteed',
      'garantiert',
      'garantizado',
      'garantito',
      'garantido',
    ];
    for (final locale in const ['fr', 'en', 'de', 'es', 'it', 'pt']) {
      final l10n = await S.delegate.load(Locale(locale));
      final label = prompt.localizedLabel(l10n);
      final action = prompt.localizedAction(l10n);
      final copy = '$label $action'.toLowerCase();

      expect(label, isNotEmpty, reason: locale);
      expect(action, isNotEmpty, reason: locale);
      expect(copy, isNot(contains(prompt.machineCode)), reason: locale);
      for (final claim in forbiddenUniversalClaims) {
        expect(copy, isNot(contains(claim)), reason: '$locale: $claim');
      }
    }
  });

  test('tax prompt closes only for the exact coherent tax reference', () {
    FeatureFlags.typedTaxProfile = true;
    FeatureFlags.documentTaxAssessmentEnabled = true;
    final selected = _assessedTaxSnapshot();
    final conflicting = _assessedTaxSnapshot(
      snapshotId: '22222222-2222-4222-8222-222222222222',
      taxableIncome: 112000,
    );
    final cases = <({
      String name,
      List<TaxSnapshot> snapshots,
      String? referenceId,
      bool promptExpected,
    })>[
      (
        name: 'exact reference',
        snapshots: [selected],
        referenceId: selected.snapshotId,
        promptExpected: false,
      ),
      (
        name: 'missing reference',
        snapshots: [selected],
        referenceId: null,
        promptExpected: true,
      ),
      (
        name: 'snapshot identity mismatch',
        snapshots: [selected],
        referenceId: '99999999-9999-4999-8999-999999999999',
        promptExpected: true,
      ),
      (
        name: 'same-rank snapshot conflict',
        snapshots: [selected, conflicting],
        referenceId: selected.snapshotId,
        promptExpected: true,
      ),
    ];

    final actualPromptPresence = <bool>[];
    for (final testCase in cases) {
      final result = ConfidenceScorer.score(
        _profileWithTaxReference(
          snapshots: testCase.snapshots,
          referenceId: testCase.referenceId,
        ),
      );
      final taxPrompts = result.prompts.where(
        (prompt) => prompt.fieldPath == 'fiscal.assessedBaseline',
      );
      actualPromptPresence.add(taxPrompts.isNotEmpty);
    }
    expect(
      actualPromptPresence,
      cases.map((testCase) => testCase.promptExpected).toList(),
      reason: cases.map((testCase) => testCase.name).join(', '),
    );
  });
}

TaxSnapshot _assessedTaxSnapshot({
  String snapshotId = '11111111-1111-4111-8111-111111111111',
  double taxableIncome = 98500,
}) {
  return TaxSnapshot(
    snapshotId: snapshotId,
    profileOwnerId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
    taxYear: 2025,
    basedOnTaxYear: null,
    sourceDate: DateTime.utc(2026, 6, 20),
    documentKind: TaxDocumentKind.assessmentNotice,
    assessmentStatus: TaxAssessmentStatus.inForce,
    inForceAttested: true,
    subjectScope: TaxSubjectScope.individual,
    cantonCode: 'VD',
    municipalityId: null,
    municipalityLabel: null,
    cantonalCommunalTaxableIncomeChf: taxableIncome,
    federalTaxableIncomeChf: null,
    cantonalCommunalTaxableWealthChf: null,
    cantonalCommunalAssessedTax: null,
    federalDirectAssessedTax: null,
    explicitMarginalIncomeTaxRate: null,
    explicitAverageIncomeTaxRate: null,
    updatedAt: DateTime.utc(2026, 7, 1),
  );
}

CoachProfile _profileWithTaxReference({
  required List<TaxSnapshot> snapshots,
  required String? referenceId,
}) {
  final reference = referenceId == null
      ? null
      : CoachProfile.fromJson({
          ...CoachProfile.defaults().toJson(),
          'latestTaxDecisionReference': <String, Object?>{
            'referenceId': referenceId,
            'kind': 'taxAssessmentDecision',
            'ownerKind': 'self',
            'source': 'certificate',
            'sourceDate': '2026-06-20',
            'legalYear': 2025,
            'confirmedAt': '2026-07-01T00:00:00.000Z',
            'taxYear': 2025,
            'jurisdiction': 'VD',
            'subject': 'individual',
          },
        }).latestTaxDecisionReference;
  if (referenceId != null && reference == null) {
    throw StateError('test reference must satisfy the persisted contract');
  }
  return CoachProfile.defaults().copyWith(
    commune: 'Lausanne',
    fiscal: FiscalProfile(
      snapshots: snapshots,
      provenanceValidatedSnapshotIds:
          snapshots.map((snapshot) => snapshot.snapshotId).toSet(),
    ),
    latestTaxDecisionReference: reference,
  );
}
