import 'package:flutter/foundation.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';

/// The acquisition boundary that determines the exact accepted LPP vocabulary
/// and percentage scale. It is never inferred from labels or magnitudes.
enum LppAcquisitionSource {
  localParser,
  backendVision,
}

enum LppExtractionRejection {
  duplicateCanonicalFact,
  mixedSourceVocabulary,
  invalidCanonicalValue,
  incoherentCanonicalFacts,
}

@immutable
class LppExtractionFact {
  const LppExtractionFact({
    required this.key,
    required this.value,
    required this.confidence,
    required this.needsReview,
    required this.derived,
  });

  final LppEvidenceFactKey key;
  final double value;
  final double confidence;
  final bool needsReview;
  final bool derived;

  LppEvidenceUnit get unit => key.unit;
}

/// Strict, raw-free LPP candidate retained only for the review route.
@immutable
class LppExtractionCandidate {
  LppExtractionCandidate({
    required this.source,
    required Map<LppEvidenceFactKey, LppExtractionFact> facts,
    required this.sourceDate,
    required this.overallConfidence,
  }) : facts = Map.unmodifiable(facts);

  final LppAcquisitionSource source;
  final Map<LppEvidenceFactKey, LppExtractionFact> facts;
  final DateTime? sourceDate;
  final double overallConfidence;

  LppExtractionFact? factFor(LppEvidenceFactKey key) => facts[key];
}

@immutable
class LppExtractionAdaptation {
  const LppExtractionAdaptation.accepted(this.candidate) : rejection = null;

  const LppExtractionAdaptation.rejected(this.rejection) : candidate = null;

  final LppExtractionCandidate? candidate;
  final LppExtractionRejection? rejection;
}

abstract final class LppExtractionAdapter {
  static const _localVocabulary = <String, LppEvidenceFactKey>{
    'lpp_total': LppEvidenceFactKey.vestedBenefitsCapitalChf,
    'lpp_obligatoire': LppEvidenceFactKey.mandatoryVestedBenefitsCapitalChf,
    'lpp_surobligatoire':
        LppEvidenceFactKey.extraMandatoryVestedBenefitsCapitalChf,
    'lpp_insured_salary': LppEvidenceFactKey.insuredSalaryAnnualChf,
    'buyback_potential': LppEvidenceFactKey.maximumBuybackCapitalChf,
    'conversion_rate_oblig': LppEvidenceFactKey.mandatoryConversionRateRatio,
    'conversion_rate_suroblig':
        LppEvidenceFactKey.extraMandatoryConversionRateRatio,
    'remuneration_rate': LppEvidenceFactKey.fundReturnRateRatio,
    'projected_rente': LppEvidenceFactKey.retirementPensionAnnualChf,
    'projected_capital_65': LppEvidenceFactKey.retirementCapitalLumpSumChf,
    'disability_coverage': LppEvidenceFactKey.disabilityPensionAnnualChf,
    'disability_capital': LppEvidenceFactKey.disabilityCapitalLumpSumChf,
    'death_coverage': LppEvidenceFactKey.deathCapitalLumpSumChf,
  };

  static const _backendVisionVocabulary = <String, LppEvidenceFactKey>{
    'avoirLppTotal': LppEvidenceFactKey.vestedBenefitsCapitalChf,
    'avoirLppObligatoire': LppEvidenceFactKey.mandatoryVestedBenefitsCapitalChf,
    'avoirLppSurobligatoire':
        LppEvidenceFactKey.extraMandatoryVestedBenefitsCapitalChf,
    'salaireAssure': LppEvidenceFactKey.insuredSalaryAnnualChf,
    'rachatMaximum': LppEvidenceFactKey.maximumBuybackCapitalChf,
  };

  static const _derivedExtraMarker =
      'Calculé: total - obligatoire'; // lint-ignore: LPP parser marker, not UI copy

  static LppExtractionAdaptation adapt({
    required LppAcquisitionSource source,
    required double sourceOverallConfidence,
    required List<ExtractedField> fields,
    DateTime? sourceDate,
  }) {
    if (!sourceOverallConfidence.isFinite ||
        sourceOverallConfidence < 0 ||
        sourceOverallConfidence > 1) {
      return const LppExtractionAdaptation.rejected(
        LppExtractionRejection.invalidCanonicalValue,
      );
    }
    final vocabulary = _vocabularyFor(source);
    final facts = <LppEvidenceFactKey, LppExtractionFact>{};

    for (final field in fields) {
      final key = vocabulary[field.fieldName];
      if (key == null) {
        if (_belongsToAnotherVocabulary(field.fieldName, source)) {
          return const LppExtractionAdaptation.rejected(
            LppExtractionRejection.mixedSourceVocabulary,
          );
        }
        continue;
      }
      if (key == LppEvidenceFactKey.maximumBuybackCapitalChf &&
          _isEarlyRetirementBuyback(field.sourceText)) {
        continue;
      }
      if (key == LppEvidenceFactKey.insuredSalaryAnnualChf &&
          _isAmbiguousInsuredSalary(field.sourceText)) {
        continue;
      }
      if (facts.containsKey(key)) {
        return const LppExtractionAdaptation.rejected(
          LppExtractionRejection.duplicateCanonicalFact,
        );
      }
      final rawValue = field.value;
      if (rawValue is! num) {
        return const LppExtractionAdaptation.rejected(
          LppExtractionRejection.invalidCanonicalValue,
        );
      }
      var value = rawValue.toDouble();
      if (!value.isFinite || value < 0) {
        return const LppExtractionAdaptation.rejected(
          LppExtractionRejection.invalidCanonicalValue,
        );
      }
      final confidence = field.confidence;
      if (!confidence.isFinite || confidence < 0 || confidence > 1) {
        return const LppExtractionAdaptation.rejected(
          LppExtractionRejection.invalidCanonicalValue,
        );
      }
      if (value == 0 && !_hasExplicitNumericZero(field.sourceText)) {
        continue;
      }
      if (key.unit == LppEvidenceUnit.ratio) {
        if (source == LppAcquisitionSource.backendVision) {
          if (value > 1) {
            return const LppExtractionAdaptation.rejected(
              LppExtractionRejection.invalidCanonicalValue,
            );
          }
        } else {
          if (value > 100) {
            return const LppExtractionAdaptation.rejected(
              LppExtractionRejection.invalidCanonicalValue,
            );
          }
          value /= 100;
        }
      }
      facts[key] = LppExtractionFact(
        key: key,
        value: value,
        confidence: confidence,
        needsReview:
            field.needsReview || confidence < key.reviewConfidenceThreshold,
        derived: source == LppAcquisitionSource.localParser &&
            key == LppEvidenceFactKey.extraMandatoryVestedBenefitsCapitalChf &&
            field.sourceText == _derivedExtraMarker,
      );
    }

    if (!LppBalanceCoherence.isCoherent({
      for (final entry in facts.entries) entry.key: entry.value.value,
    })) {
      return const LppExtractionAdaptation.rejected(
        LppExtractionRejection.incoherentCanonicalFacts,
      );
    }

    return LppExtractionAdaptation.accepted(
      LppExtractionCandidate(
        source: source,
        facts: facts,
        sourceDate: sourceDate,
        overallConfidence: _conservativeOverallConfidence(
          sourceOverallConfidence,
          facts,
        ),
      ),
    );
  }

  static double _conservativeOverallConfidence(
    double sourceOverallConfidence,
    Map<LppEvidenceFactKey, LppExtractionFact> facts,
  ) {
    if (facts.isEmpty) return 0;
    final acceptedFactMean = facts.values
            .map((fact) => fact.confidence)
            .reduce((left, right) => left + right) /
        facts.length;
    return sourceOverallConfidence < acceptedFactMean
        ? sourceOverallConfidence
        : acceptedFactMean;
  }

  static Map<String, LppEvidenceFactKey> _vocabularyFor(
    LppAcquisitionSource source,
  ) {
    return switch (source) {
      LppAcquisitionSource.localParser => _localVocabulary,
      LppAcquisitionSource.backendVision => _backendVisionVocabulary,
    };
  }

  static bool _belongsToAnotherVocabulary(
    String fieldName,
    LppAcquisitionSource source,
  ) {
    if (source != LppAcquisitionSource.localParser &&
        _localVocabulary.containsKey(fieldName)) {
      return true;
    }
    if (source != LppAcquisitionSource.backendVision &&
        _backendVisionVocabulary.containsKey(fieldName)) {
      return true;
    }
    return false;
  }

  static bool _isEarlyRetirementBuyback(String sourceText) {
    final normalized = _normalizedSemanticText(sourceText);
    return normalized.contains('anticip') ||
        normalized.contains('bridge') ||
        normalized.contains('pont') ||
        normalized.contains('fruhpensionierung') ||
        normalized.contains('vorzeitig') ||
        normalized.contains('vorbezug');
  }

  static bool _hasExplicitNumericZero(String sourceText) {
    const zero = r'0(?:[\.,]0+)?';
    const unit = r'(?:CHF|Fr\.|%)';
    final trimmed = sourceText.trim();
    if (RegExp(
      '^\\s*(?:$unit\\s*)?$zero(?:\\s*$unit)?\\s*\$',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return true;
    }
    return RegExp(
      '(?:[:=]\\s*|$unit\\s+)$zero(?:\\s*$unit)?(?:\\s|\$)',
      caseSensitive: false,
    ).hasMatch(trimmed);
  }

  static bool _isAmbiguousInsuredSalary(String sourceText) {
    final normalized = _normalizedSemanticText(sourceText);
    final hasSubtype = normalized.contains('risque') ||
        normalized.contains('risk') ||
        normalized.contains('epargne') ||
        normalized.contains('savings') ||
        normalized.contains('sparlohn');
    final hasExplicitTotal = normalized.contains('total') ||
        normalized.contains('global') ||
        normalized.contains('gesamt');
    return hasSubtype && !hasExplicitTotal;
  }

  static String _normalizedSemanticText(String value) {
    return value
        .toLowerCase()
        .replaceAll(
            'é', 'e') // lint-ignore: OCR normalization token, not UI copy
        .replaceAll(
            'è', 'e') // lint-ignore: OCR normalization token, not UI copy
        .replaceAll(
            'ê', 'e') // lint-ignore: OCR normalization token, not UI copy
        .replaceAll('ä', 'a')
        .replaceAll('ö', 'o')
        .replaceAll(
            'ü', 'u'); // lint-ignore: OCR normalization token, not UI copy
  }
}

extension LppEvidenceReviewConfidence on LppEvidenceFactKey {
  double get reviewConfidenceThreshold => switch (this) {
        LppEvidenceFactKey.vestedBenefitsCapitalChf ||
        LppEvidenceFactKey.mandatoryVestedBenefitsCapitalChf ||
        LppEvidenceFactKey.extraMandatoryVestedBenefitsCapitalChf ||
        LppEvidenceFactKey.mandatoryConversionRateRatio ||
        LppEvidenceFactKey.extraMandatoryConversionRateRatio =>
          0.95,
        LppEvidenceFactKey.maximumBuybackCapitalChf ||
        LppEvidenceFactKey.insuredSalaryAnnualChf =>
          0.90,
        _ => 0.80,
      };
}
