// ────────────────────────────────────────────────────────────
//  SLM EXTRACTION VALIDATOR — Anti-hallucination guard
// ────────────────────────────────────────────────────────────
//
//  3-layer validation for SLM-extracted financial fields.
//  Every field the SLM returns MUST pass all 3 layers
//  before being accepted into the ExtractionResult.
//
//  Layer 1: Source text exists in original OCR
//  Layer 2: Parsed value matches claimed value (±1%)
//  Layer 3: Value within semantic bounds for field type
//
//  Reference: Plan vivid-petting-yao.md
// ────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/document_parser_utils.dart';

/// Validates SLM-extracted fields against the original OCR text.
///
/// Rejects hallucinated values — the SLM can and will invent numbers.
/// Only fields passing all 3 layers are accepted.
class SlmExtractionValidator {
  SlmExtractionValidator._();

  /// Validate a single SLM-extracted field against the original OCR text.
  ///
  /// Returns a validated [ExtractedField] with adjusted confidence,
  /// or null if the field fails validation (hallucination detected).
  static ExtractedField? validate(
    ExtractedField candidate,
    String originalOcrText,
  ) {
    final value = candidate.value;
    if (value is! double && value is! int) return null;
    final numericValue = (value is int) ? value.toDouble() : value as double;

    // Layer 1: Source text verification
    final sourceCheck = verifySourceInOcr(candidate.sourceText, originalOcrText);
    if (!sourceCheck.found) {
      debugPrint('[SlmValidator] REJECT ${candidate.fieldName}: '
          'source text not found in OCR');
      return null;
    }

    // Layer 2: Value-source consistency
    if (!verifyValueSourceConsistency(numericValue, candidate.sourceText)) {
      debugPrint('[SlmValidator] REJECT ${candidate.fieldName}: '
          'value $numericValue does not match source "${candidate.sourceText}"');
      return null;
    }

    // Layer 3: Semantic bounds
    if (!checkSemanticBounds(candidate.fieldName, numericValue)) {
      debugPrint('[SlmValidator] REJECT ${candidate.fieldName}: '
          'value $numericValue outside semantic bounds');
      return null;
    }

    // All layers passed — compute adjusted confidence
    double confidence = 0.65; // Base SLM confidence
    if (sourceCheck.exact) {
      confidence += 0.10; // Exact source match bonus
    } else {
      confidence -= 0.10; // Fuzzy match penalty
    }
    confidence += 0.05; // Value-source consistency bonus (always true here)

    // Penalize values near semantic bounds
    if (_isNearBound(candidate.fieldName, numericValue)) {
      confidence -= 0.15;
    }

    confidence = confidence.clamp(0.50, 0.75);

    return ExtractedField(
      fieldName: candidate.fieldName,
      label: candidate.label,
      value: numericValue,
      confidence: confidence,
      sourceText: candidate.sourceText,
      needsReview: true, // SLM fields ALWAYS need review
      profileField: candidate.profileField,
    );
  }

  // ── Layer 1: Source text in OCR ────────────────────────────

  /// Check if the SLM's claimed source text exists in the original OCR.
  ///
  /// Returns `found: true` if the source is present (exact or fuzzy).
  /// Returns `exact: true` if the match is verbatim.
  @visibleForTesting
  static ({bool found, bool exact}) verifySourceInOcr(
    String sourceText,
    String ocrText,
  ) {
    if (sourceText.isEmpty) return (found: false, exact: false);

    // Normalize whitespace for comparison
    final normalizedSource = _normalize(sourceText);
    final normalizedOcr = _normalize(ocrText);

    // Exact match
    if (normalizedOcr.contains(normalizedSource)) {
      return (found: true, exact: true);
    }

    // Fuzzy match: try with numbers only (OCR can garble labels but not digits)
    final sourceNumbers = _extractNumbers(sourceText);
    if (sourceNumbers.isNotEmpty) {
      // Check if all numbers from the source appear in the OCR
      final ocrNumbers = _extractNumbers(ocrText);
      final allFound = sourceNumbers.every(
          (n) => ocrNumbers.any((o) => (n - o).abs() < 0.01));
      if (allFound) {
        return (found: true, exact: false);
      }
    }

    return (found: false, exact: false);
  }

  // ── Layer 2: Value-source consistency ─────────────────────

  /// Parse the source text and verify the SLM's claimed value matches.
  ///
  /// Tolerance: ±1% or ±1.0 CHF (whichever is larger).
  @visibleForTesting
  static bool verifyValueSourceConsistency(
    double claimedValue,
    String sourceText,
  ) {
    // Try parsing the source text as a Swiss number
    final parsed = parseSwissNumber(sourceText);
    if (parsed == null) {
      // Source might contain the number among other text
      // Extract all numbers and see if any match
      final numbers = _extractNumbers(sourceText);
      return numbers.any(
          (n) => _valuesMatch(claimedValue, n));
    }
    return _valuesMatch(claimedValue, parsed);
  }

  /// Check if two values match within tolerance (±1% or ±1.0).
  static bool _valuesMatch(double claimed, double parsed) {
    final tolerance = (parsed.abs() * 0.01).clamp(1.0, double.infinity);
    return (claimed - parsed).abs() <= tolerance;
  }

  // ── Layer 3: Semantic bounds ──────────────────────────────

  /// Domain-specific sanity bounds for Swiss financial certificate fields.
  ///
  /// Any value outside these bounds is almost certainly a hallucination.
  @visibleForTesting
  static bool checkSemanticBounds(String fieldName, double value) {
    final bounds = _semanticBounds[fieldName];
    if (bounds == null) {
      // Unknown field — accept but with note
      return value > 0 && value < 10000000; // Generic: 0 < x < 10M
    }
    return value >= bounds.min && value <= bounds.max;
  }

  /// Check if a value is within 10% of its semantic bounds.
  static bool _isNearBound(String fieldName, double value) {
    final bounds = _semanticBounds[fieldName];
    if (bounds == null) return false;
    final range = bounds.max - bounds.min;
    final margin = range * 0.10;
    return value < (bounds.min + margin) || value > (bounds.max - margin);
  }

  /// Semantic bounds per field type (Swiss financial reality).
  static const Map<String, ({double min, double max})> _semanticBounds = {
    // Avoirs LPP
    'lpp_total': (min: 0, max: 5000000), // No Swiss pension > 5M
    'lpp_obligatoire': (min: 0, max: 3000000),
    'lpp_surobligatoire': (min: 0, max: 3000000),
    'lpp_minimum': (min: 0, max: 3000000),

    // Salaires
    'lpp_insured_salary': (min: 3780, max: 500000), // Min coordonné to extreme
    'lpp_determining_salary': (min: 22680, max: 1000000), // LPP threshold to extreme

    // Taux
    'conversion_rate_oblig': (min: 3.0, max: 8.0), // Legal: 6.8%, some plans lower
    'conversion_rate_suroblig': (min: 2.0, max: 8.0),
    'conversion_rate_at_65': (min: 3.0, max: 8.0),
    'remuneration_rate': (min: 0.0, max: 15.0),
    'lpp_bonification_rate': (min: 1.0, max: 25.0),

    // Projections
    'projected_capital_65': (min: 0, max: 10000000),
    'projected_rente': (min: 0, max: 500000), // Annual rente

    // Prestations de risque
    'disability_coverage': (min: 0, max: 500000), // Annual
    'death_coverage': (min: 0, max: 2000000),

    // Rachat
    'buyback_potential': (min: 0, max: 3000000),
    'buyback_early_retirement': (min: 0, max: 5000000),

    // Cotisations
    'employee_contribution': (min: 0, max: 100000), // Annual
    'employer_contribution': (min: 0, max: 100000),

    // EPL
    'epl_max': (min: 0, max: 2000000),

    // Tax fields
    'revenu_imposable': (min: 0, max: 5000000),
    'fortune_imposable': (min: 0, max: 50000000),
    'impot_cantonal': (min: 0, max: 500000),
    'impot_federal': (min: 0, max: 200000),
    'taux_marginal_effectif': (min: 0, max: 50.0),

    // AVS fields
    'annees_cotisation': (min: 0, max: 44),
    'ramd': (min: 0, max: 200000),
    'lacunes_cotisation': (min: 0, max: 44),
  };

  // ── Helpers ───────────────────────────────────────────────

  /// Normalize text for comparison: lowercase, collapse whitespace.
  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Extract all parseable numbers from a text string.
  static List<double> _extractNumbers(String text) {
    final numbers = <double>[];
    // Match Swiss number patterns: 70'376.60, 539'413.70, 5.00, etc.
    final numberPattern = RegExp(r"[\d'., ]+\.?\d+");
    for (final match in numberPattern.allMatches(text)) {
      final parsed = parseSwissNumber(match.group(0) ?? "");
      if (parsed != null && parsed > 0) {
        numbers.add(parsed);
      }
    }
    return numbers;
  }
}
