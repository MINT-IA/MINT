import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/lpp_extraction_adapter.dart';

ExtractedField _field(
  String name,
  double value, {
  String sourceText = '',
  double confidence = 1,
  bool needsReview = false,
}) {
  return ExtractedField(
    fieldName: name,
    label: 'untrusted label',
    value: value,
    confidence: confidence,
    sourceText: sourceText,
    needsReview: needsReview,
  );
}

void main() {
  group('LppBalanceCoherence', () {
    test('allows the exact CHF 1 rounding tolerance', () {
      expect(
        LppBalanceCoherence.isCoherent(const {
          LppEvidenceFactKey.vestedBenefitsCapitalChf: 100000,
          LppEvidenceFactKey.mandatoryVestedBenefitsCapitalChf: 60000,
          LppEvidenceFactKey.extraMandatoryVestedBenefitsCapitalChf: 39999,
        }),
        isTrue,
      );
    });

    test('allows otherwise partial balance sets', () {
      for (final values in <Map<LppEvidenceFactKey, double>>[
        const {
          LppEvidenceFactKey.mandatoryVestedBenefitsCapitalChf: 60000,
          LppEvidenceFactKey.extraMandatoryVestedBenefitsCapitalChf: 45000,
        },
        const {
          LppEvidenceFactKey.vestedBenefitsCapitalChf: 100000,
          LppEvidenceFactKey.mandatoryVestedBenefitsCapitalChf: 60000,
        },
        const {
          LppEvidenceFactKey.vestedBenefitsCapitalChf: 100000,
          LppEvidenceFactKey.extraMandatoryVestedBenefitsCapitalChf: 45000,
        },
      ]) {
        expect(LppBalanceCoherence.isCoherent(values), isTrue);
      }
    });
  });

  group('LppExtractionAdapter', () {
    test('source overall confidence cannot be upgraded by accepted facts', () {
      final result = LppExtractionAdapter.adapt(
        source: LppAcquisitionSource.backendVision,
        sourceOverallConfidence: 0.61,
        fields: [
          _field('avoirLppTotal', 125000, confidence: 0.95),
        ],
      );

      expect(result.rejection, isNull);
      expect(result.candidate!.overallConfidence, 0.61);
    });

    test('invalid source overall confidence fails closed for every source', () {
      for (final source in LppAcquisitionSource.values) {
        final fieldName = switch (source) {
          LppAcquisitionSource.localParser => 'lpp_total',
          LppAcquisitionSource.backendVision => 'avoirLppTotal',
        };
        for (final confidence in <double>[
          double.nan,
          double.infinity,
          -0.01,
          1.01,
        ]) {
          final result = LppExtractionAdapter.adapt(
            source: source,
            sourceOverallConfidence: confidence,
            fields: [_field(fieldName, 125000)],
          );
          expect(result.candidate, isNull,
              reason: '${source.name}:$confidence');
          expect(
            result.rejection,
            LppExtractionRejection.invalidCanonicalValue,
            reason: '${source.name}:$confidence',
          );
        }
      }
    });

    test('explicit source review flag survives high numeric confidence', () {
      final result = LppExtractionAdapter.adapt(
        source: LppAcquisitionSource.backendVision,
        sourceOverallConfidence: 0.99,
        fields: [
          _field(
            'avoirLppTotal',
            125000,
            confidence: 0.99,
            needsReview: true,
          ),
        ],
      );

      expect(result.rejection, isNull);
      expect(
        result.candidate!
            .factFor(LppEvidenceFactKey.vestedBenefitsCapitalChf)!
            .needsReview,
        isTrue,
      );
    });

    test('local percentage points are normalized once, including 0.50%', () {
      final result = LppExtractionAdapter.adapt(
        source: LppAcquisitionSource.localParser,
        sourceOverallConfidence: 1,
        fields: [
          _field('conversion_rate_oblig', 6.8),
          _field('conversion_rate_suroblig', 0.50),
        ],
      );

      expect(result.rejection, isNull);
      expect(
        result.candidate!
            .factFor(
              LppEvidenceFactKey.mandatoryConversionRateRatio,
            )!
            .value,
        closeTo(0.068, 1e-12),
      );
      expect(
        result.candidate!
            .factFor(
              LppEvidenceFactKey.extraMandatoryConversionRateRatio,
            )!
            .value,
        closeTo(0.005, 1e-12),
      );
    });

    test('candidate retains validated raw-free confidence and honest mean', () {
      final result = LppExtractionAdapter.adapt(
        source: LppAcquisitionSource.localParser,
        sourceOverallConfidence: 1,
        fields: [
          _field('lpp_total', 125000, confidence: 0.40),
          _field('lpp_insured_salary', 92000, confidence: 0.95),
        ],
      );

      expect(result.rejection, isNull);
      expect(
        result.candidate!
            .factFor(LppEvidenceFactKey.vestedBenefitsCapitalChf)!
            .confidence,
        0.40,
      );
      expect(result.candidate!.overallConfidence, closeTo(0.675, 1e-12));
    });

    test('invalid confidence fails closed instead of being clamped', () {
      for (final confidence in <double>[
        double.nan,
        double.infinity,
        -0.01,
        1.01,
      ]) {
        final result = LppExtractionAdapter.adapt(
          source: LppAcquisitionSource.localParser,
          sourceOverallConfidence: 1,
          fields: [
            _field('lpp_total', 125000, confidence: confidence),
          ],
        );
        expect(result.candidate, isNull, reason: '$confidence');
        expect(
          result.rejection,
          LppExtractionRejection.invalidCanonicalValue,
          reason: '$confidence',
        );
      }
    });

    test('backend Vision keeps only exact safe non-zero fields', () {
      final result = LppExtractionAdapter.adapt(
        source: LppAcquisitionSource.backendVision,
        sourceOverallConfidence: 1,
        fields: [
          _field('avoirLppTotal', 125000),
          _field('salaireAssure', 92000),
        ],
      );

      expect(result.rejection, isNull);
      expect(
        result.candidate!
            .factFor(
              LppEvidenceFactKey.vestedBenefitsCapitalChf,
            )!
            .value,
        125000,
      );
      expect(
        result.candidate!
            .factFor(
              LppEvidenceFactKey.insuredSalaryAnnualChf,
            )!
            .value,
        92000,
      );

      final ratio = LppExtractionAdapter.adapt(
        source: LppAcquisitionSource.backendVision,
        sourceOverallConfidence: 1,
        fields: [_field('mandatoryConversionRateRatio', 0.068)],
      );
      expect(
        ratio.candidate?.factFor(
          LppEvidenceFactKey.mandatoryConversionRateRatio,
        ),
        isNull,
        reason: 'unreviewed backend aliases must not become facts',
      );
    });

    test('zero requires an explicit numeric zero in the source snippet', () {
      for (final source in LppAcquisitionSource.values) {
        final fieldName = switch (source) {
          LppAcquisitionSource.localParser => 'lpp_total',
          LppAcquisitionSource.backendVision => 'avoirLppTotal',
        };
        for (final sourceText in const [
          '',
          'Aucun avoir indiqué',
          'Certificat 2020 identifiant 000',
        ]) {
          final result = LppExtractionAdapter.adapt(
            source: source,
            sourceOverallConfidence: 1,
            fields: [_field(fieldName, 0, sourceText: sourceText)],
          );

          expect(
            result.candidate!
                .factFor(LppEvidenceFactKey.vestedBenefitsCapitalChf),
            isNull,
            reason: '${source.name}:$sourceText',
          );
        }
        for (final sourceText in const [
          '0',
          '0.00',
          '0,00',
          'Avoir total: CHF 0.00',
          'Avoir total = 0,00 CHF',
        ]) {
          final result = LppExtractionAdapter.adapt(
            source: source,
            sourceOverallConfidence: 1,
            fields: [_field(fieldName, 0, sourceText: sourceText)],
          );

          expect(
            result.candidate!
                .factFor(LppEvidenceFactKey.vestedBenefitsCapitalChf)
                ?.value,
            0,
            reason: '${source.name}:$sourceText',
          );
        }
      }
    });

    test('duplicate canonical facts fail closed', () {
      final result = LppExtractionAdapter.adapt(
        source: LppAcquisitionSource.backendVision,
        sourceOverallConfidence: 1,
        fields: [
          _field('avoirLppTotal', 125000),
          _field('avoirLppTotal', 126000),
        ],
      );

      expect(result.candidate, isNull);
      expect(
        result.rejection,
        LppExtractionRejection.duplicateCanonicalFact,
      );
    });

    test('incoherent canonical balances fail closed for every source', () {
      for (final source in LppAcquisitionSource.values) {
        final names = switch (source) {
          LppAcquisitionSource.localParser => const (
              total: 'lpp_total',
              mandatory: 'lpp_obligatoire',
              extra: 'lpp_surobligatoire',
            ),
          LppAcquisitionSource.backendVision => const (
              total: 'avoirLppTotal',
              mandatory: 'avoirLppObligatoire',
              extra: 'avoirLppSurobligatoire',
            ),
        };
        for (final fields in <List<ExtractedField>>[
          [
            _field(names.total, 100000),
            _field(names.mandatory, 100001),
          ],
          [
            _field(names.total, 100000),
            _field(names.mandatory, 60000),
            _field(names.extra, 39998),
          ],
        ]) {
          final result = LppExtractionAdapter.adapt(
            source: source,
            sourceOverallConfidence: 1,
            fields: fields,
          );
          expect(result.candidate, isNull, reason: source.name);
          expect(
            result.rejection,
            LppExtractionRejection.incoherentCanonicalFacts,
            reason: source.name,
          );
        }

        final rounded = LppExtractionAdapter.adapt(
          source: source,
          sourceOverallConfidence: 1,
          fields: [
            _field(names.total, 100000),
            _field(names.mandatory, 60000),
            _field(names.extra, 39999),
          ],
        );
        expect(rounded.rejection, isNull, reason: source.name);
      }
    });

    test('mixing source vocabularies fails closed instead of guessing scale',
        () {
      final result = LppExtractionAdapter.adapt(
        source: LppAcquisitionSource.backendVision,
        sourceOverallConfidence: 1,
        fields: [
          _field('avoirLppTotal', 125000),
          _field('conversion_rate_oblig', 6.8),
        ],
      );

      expect(result.candidate, isNull);
      expect(
        result.rejection,
        LppExtractionRejection.mixedSourceVocabulary,
      );
    });

    test('backend generic conversion and bonification aliases produce no fact',
        () {
      final result = LppExtractionAdapter.adapt(
        source: LppAcquisitionSource.backendVision,
        sourceOverallConfidence: 1,
        fields: [
          _field('tauxConversion', 0.068),
          _field('bonificationVieillesse', 0.18),
        ],
      );

      expect(result.rejection, isNull);
      expect(result.candidate!.facts, isEmpty);
    });

    test('plan-like and loose aliases produce zero facts', () {
      final result = LppExtractionAdapter.adapt(
        source: LppAcquisitionSource.backendVision,
        sourceOverallConfidence: 1,
        fields: [
          _field('tauxConversionOblig', 0.068),
          _field('tauxConversionSuroblig', 0.05),
          _field('capitalProjete65', 480000),
          _field('avoirBase', 75000),
          _field('avoirBonus', 50000),
        ],
      );

      expect(result.rejection, isNull);
      expect(result.candidate!.facts, isEmpty);
    });

    test(
        'early-retirement and bridge buyback snippets never become ordinary buyback',
        () {
      for (final sourceText in const [
        'Rachat en vue de la retraite anticipée',
        'Montant bridge / pont jusqu’à la retraite',
        'Einkauf bei Frühpensionierung',
        'Vorbezug',
      ]) {
        final result = LppExtractionAdapter.adapt(
          source: LppAcquisitionSource.localParser,
          sourceOverallConfidence: 1,
          fields: [
            _field('buyback_potential', 24000, sourceText: sourceText),
          ],
        );

        expect(
          result.candidate!
              .factFor(LppEvidenceFactKey.maximumBuybackCapitalChf),
          isNull,
          reason: sourceText,
        );
      }
    });

    test('risk and savings salaries without a total insured salary stay absent',
        () {
      final result = LppExtractionAdapter.adapt(
        source: LppAcquisitionSource.backendVision,
        sourceOverallConfidence: 1,
        fields: [
          _field('salaireAssure', 92000, sourceText: 'Salaire risque'),
          _field('salaireAssure', 76000, sourceText: 'Salaire épargne'),
        ],
      );

      expect(result.rejection, isNull);
      expect(
        result.candidate!.factFor(LppEvidenceFactKey.insuredSalaryAnnualChf),
        isNull,
      );
    });

    test('local exact vocabulary covers all 13 facts and marks derived extra',
        () {
      final result = LppExtractionAdapter.adapt(
        source: LppAcquisitionSource.localParser,
        sourceOverallConfidence: 1,
        sourceDate: DateTime.utc(2026, 6, 30),
        fields: [
          _field('lpp_total', 125000),
          _field('lpp_obligatoire', 75000),
          _field(
            'lpp_surobligatoire',
            50000,
            sourceText: 'Calculé: total - obligatoire',
          ),
          _field('lpp_insured_salary', 92000),
          _field('buyback_potential', 24000),
          _field('conversion_rate_oblig', 6.8),
          _field('conversion_rate_suroblig', 5.1),
          _field('remuneration_rate', 1.25),
          _field('projected_rente', 31450),
          _field('projected_capital_65', 480000),
          _field('disability_coverage', 26000),
          _field('disability_capital', 175000),
          _field('death_coverage', 210000),
        ],
      );

      expect(result.rejection, isNull);
      expect(result.candidate!.facts, hasLength(13));
      expect(result.candidate!.sourceDate, DateTime.utc(2026, 6, 30));
      expect(
        result.candidate!
            .factFor(
              LppEvidenceFactKey.extraMandatoryVestedBenefitsCapitalChf,
            )!
            .derived,
        isTrue,
      );
    });
  });
}
