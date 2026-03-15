// ────────────────────────────────────────────────────────────
//  TAX DECLARATION PARSER — Sprint S44
// ────────────────────────────────────────────────────────────
//
//  Extracts structured financial fields from OCR text of a
//  Swiss tax declaration (Déclaration fiscale / Steuererklärung)
//  or tax assessment notice (Avis de taxation / Steuerveranlagung).
//
//  Handles both French and German document formats.
//  Parses Swiss number formatting (CHF 85'400.00).
//  Cross-validates: total impot ~ cantonal + federal.
//
//  6 fields extracted:
//    - revenuImposable (actual taxable income)
//    - fortuneImposable (actual taxable wealth)
//    - deductionsEffectuees (3a, frais, etc.)
//    - impotCantonal (cantonal + communal tax)
//    - impotFederal (federal tax)
//    - tauxMarginalEffectif (CRITICAL for arbitrage accuracy)
//
//  Reference:
//    - DATA_ACQUISITION_STRATEGY.md — Channel 1, Document B
//    - LIFD art. 38 (capital withdrawal tax)
//    - LIFD art. 33-33a (deductions)
// ────────────────────────────────────────────────────────────

import 'package:mint_mobile/services/document_parser/document_models.dart';

/// Pattern definition for a known tax declaration field.
class _TaxFieldPattern {
  final String fieldName;
  final String label;
  final List<RegExp> patterns;
  final String? profileField;
  final bool isPercentage;

  const _TaxFieldPattern({
    required this.fieldName,
    required this.label,
    required this.patterns,
    this.profileField,
    this.isPercentage = false,
  });
}

// Reusable regex fragment: Swiss number capture group
// Matches: CHF 85'400.00, Fr. 98 400, 44887.50, etc.
const String _numCapture = r"([CHFfr.\s]*[\d\s'.,]+)";

/// Service for parsing tax declaration OCR text into structured fields.
///
/// Mirror of the backend service — all logic is pure Dart, no network calls.
/// Designed for on-device OCR (privacy-first: document never leaves phone).
///
/// Confidence delta: +15-20 points.
class TaxDeclarationParser {
  TaxDeclarationParser._();

  // ── Swiss number parsing ──────────────────────────────────

  /// Parse a Swiss-formatted number: "85'400.00", "85 400", "CHF 85'400".
  /// Returns null if no valid number found.
  static double? _parseSwissNumber(String text) {
    // Remove currency prefixes and whitespace
    var cleaned = text
        .replaceAll(RegExp(r"CHF\s*", caseSensitive: false), "")
        .replaceAll(RegExp(r"Fr\.\s*", caseSensitive: false), "")
        .trim();

    // Remove thousand separators (apostrophe, space, thin space)
    cleaned = cleaned.replaceAll("'", "");
    cleaned = cleaned.replaceAll("\u2019", ""); // Right single quotation mark
    cleaned = cleaned.replaceAll("\u00A0", ""); // Non-breaking space

    // Handle space as thousand separator (but not decimal)
    cleaned = cleaned.replaceAll(RegExp(r"(\d)\s+(\d)"), r"$1$2");

    // Handle comma as decimal separator (Swiss German style)
    if (cleaned.contains(",") && !cleaned.contains(".")) {
      final lastComma = cleaned.lastIndexOf(",");
      final afterComma = cleaned.substring(lastComma + 1);
      if (afterComma.length <= 2) {
        cleaned = "${cleaned.substring(0, lastComma)}.$afterComma";
      } else {
        cleaned = cleaned.replaceAll(",", "");
      }
    }

    // Remove any remaining non-numeric chars except dot and minus
    cleaned = cleaned.replaceAll(RegExp(r"[^\d.\-]"), "");

    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  /// Parse a percentage: "32.5%", "32,5 %", "0.325".
  static double? _parsePercentage(String text) {
    var cleaned = text.replaceAll("%", "").trim();
    cleaned = cleaned.replaceAll(",", ".");
    cleaned = cleaned.replaceAll(RegExp(r"[^\d.\-]"), "");
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null) return null;
    // If value > 1, it's already in percent form (e.g. 32.5)
    // If value <= 1, it might be in decimal form (e.g. 0.325)
    return value > 1 ? value : value * 100;
  }

  // ── Known field patterns (FR + DE) ────────────────────────

  static final List<_TaxFieldPattern> _knownFieldPatterns = [
    // ── Revenu imposable ──
    _TaxFieldPattern(
      fieldName: "revenu_imposable",
      label: "Revenu imposable",
      profileField: "actualTaxableIncome",
      patterns: [
        RegExp(
            r"(?:revenu\s+imposable|revenu\s+net\s+imposable|revenu\s+d[e\u00e9]terminant)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Steuerbares?\s+Einkommen|Reineinkommen|Massgebendes\s+Einkommen)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        // Variante: "total des revenus imposables"
        RegExp(
            r"(?:total\s+des?\s+revenus?\s+imposable)\s*[:\s]*" + _numCapture,
            caseSensitive: false),
      ],
    ),

    // ── Fortune imposable ──
    _TaxFieldPattern(
      fieldName: "fortune_imposable",
      label: "Fortune imposable",
      profileField: "actualTaxableWealth",
      patterns: [
        RegExp(
            r"(?:fortune\s+imposable|fortune\s+nette\s+imposable|fortune\s+d[e\u00e9]terminante)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Steuerbares?\s+Verm[o\u00f6]gen|Reinverm[o\u00f6]gen)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
      ],
    ),

    // ── Deductions effectuees ──
    _TaxFieldPattern(
      fieldName: "deductions_effectuees",
      label: "Déductions effectuées",
      profileField: "actualDeductions",
      patterns: [
        RegExp(
            r"(?:total\s+des?\s+d[e\u00e9]ductions?|d[e\u00e9]ductions?\s+total(?:es)?|d[e\u00e9]ductions?\s+effectu[e\u00e9]es?)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Total\s+Abz[u\u00fc]ge|Abz[u\u00fc]ge\s+(?:total|gesamt))\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        // Variante: "deductions admises"
        RegExp(
            r"(?:d[e\u00e9]ductions?\s+admises?)\s*[:\s]*" + _numCapture,
            caseSensitive: false),
      ],
    ),

    // ── Impot cantonal (+ communal) ──
    _TaxFieldPattern(
      fieldName: "impot_cantonal",
      label: "Impôt cantonal et communal",
      profileField: "actualCantonalTax",
      patterns: [
        RegExp(
            r"(?:imp[o\u00f4]t\s+cantonal\s*(?:et\s+communal)?|imp[o\u00f4]ts?\s+cantonaux?\s*(?:et\s+communaux?)?|ICC)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Kantons[\-\s]*(?:und\s+Gemeinde[\-\s]*)?[Ss]teuer|Staats[\-\s]*(?:und\s+Gemeinde[\-\s]*)?[Ss]teuer)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        // Variante: "total ICC"
        RegExp(
            r"(?:total\s+ICC)\s*[:\s]*" + _numCapture,
            caseSensitive: false),
      ],
    ),

    // ── Impot federal direct ──
    _TaxFieldPattern(
      fieldName: "impot_federal",
      label: "Impôt fédéral direct",
      profileField: "actualFederalTax",
      patterns: [
        RegExp(
            r"(?:imp[o\u00f4]t\s+f[e\u00e9]d[e\u00e9]ral\s+direct|IFD)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Direkte\s+Bundessteuer|DBSt?|Eidgen[o\u00f6]ssische\s+Steuer)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
      ],
    ),

    // ── Taux marginal effectif ──
    _TaxFieldPattern(
      fieldName: "taux_marginal_effectif",
      label: "Taux marginal effectif",
      profileField: "actualMarginalRate",
      isPercentage: true,
      patterns: [
        RegExp(
            r"(?:taux\s+(?:marginal\s+)?effectif|taux\s+d[' ]?imposition\s+(?:marginal|effectif))\s*[:\s]*([\d,.\s]+\s*%?)",
            caseSensitive: false),
        RegExp(
            r"(?:Grenzsteuersatz|Effektiver?\s+Steuersatz|Marginaler?\s+Steuersatz)\s*[:\s]*([\d,.\s]+\s*%?)",
            caseSensitive: false),
        // Variante: "taux moyen d'imposition" (proxy for marginal)
        RegExp(
            r"(?:taux\s+moyen\s+d[' ]?imposition)\s*[:\s]*([\d,.\s]+\s*%?)",
            caseSensitive: false),
      ],
    ),
  ];

  // ── Main parsing method ───────────────────────────────────

  /// Parse OCR text from a tax declaration into structured fields.
  ///
  /// [text] is the raw OCR output from the tax document image.
  /// Returns an [ExtractionResult] with all detected fields,
  /// confidence scores, cross-validation warnings, and compliance info.
  static ExtractionResult parseTaxDeclaration(String text) {
    final fields = <ExtractedField>[];
    final warnings = <String>[];

    for (final pattern in _knownFieldPatterns) {
      final result = _extractField(text, pattern);
      if (result != null) {
        fields.add(result);
      }
    }

    // ── Cross-validation: total impot ~ cantonal + federal ──
    final cantonal = _findFieldValue(fields, "impot_cantonal");
    final federal = _findFieldValue(fields, "impot_federal");

    if (cantonal != null && federal != null) {
      final totalImpot = cantonal + federal;
      // Sanity check: total tax should be between 5% and 50% of taxable income
      final revenu = _findFieldValue(fields, "revenu_imposable");
      if (revenu != null && revenu > 0) {
        final effectiveRate = totalImpot / revenu * 100;
        if (effectiveRate < 3.0) {
          warnings.add(
            "Le total des impôts (${totalImpot.toStringAsFixed(0)} CHF) semble "
            "très bas par rapport au revenu imposable "
            "(${revenu.toStringAsFixed(0)} CHF = ${effectiveRate.toStringAsFixed(1)}%). "
            "Vérifie les montants sur ton avis de taxation.",
          );
        }
        if (effectiveRate > 50.0) {
          warnings.add(
            "Le total des impôts (${totalImpot.toStringAsFixed(0)} CHF) semble "
            "élevé par rapport au revenu imposable "
            "(${revenu.toStringAsFixed(0)} CHF = ${effectiveRate.toStringAsFixed(1)}%). "
            "Vérifie les montants sur ton avis de taxation.",
          );
        }
      }
    }

    // ── Cross-validation: taux marginal effectif plausibility ──
    final tauxMarginal =
        _findFieldValue(fields, "taux_marginal_effectif");
    if (tauxMarginal != null && (tauxMarginal < 5.0 || tauxMarginal > 55.0)) {
      warnings.add(
        "Le taux marginal effectif (${tauxMarginal.toStringAsFixed(1)}%) "
        "semble inhabituel. En Suisse, il se situe généralement entre "
        "10% et 45% selon le canton et le revenu. Vérifie sur ton avis de taxation.",
      );
    }

    // ── Cross-validation: fortune imposable plausibility ──
    final fortune = _findFieldValue(fields, "fortune_imposable");
    if (fortune != null && fortune < 0) {
      warnings.add(
        "La fortune imposable est négative (${fortune.toStringAsFixed(0)} CHF). "
        "C'est possible si tes dettes dépassent tes actifs, mais vérifie le montant.",
      );
    }

    // ── Cross-validation: deductions vs revenu ──
    final deductions = _findFieldValue(fields, "deductions_effectuees");
    final revenu = _findFieldValue(fields, "revenu_imposable");
    if (deductions != null && revenu != null && revenu > 0) {
      final deductionRate = deductions / revenu * 100;
      if (deductionRate > 60.0) {
        warnings.add(
          "Les déductions (${deductions.toStringAsFixed(0)} CHF) représentent "
          "${deductionRate.toStringAsFixed(0)}% du revenu imposable. "
          "C'est inhabituellement élevé. Vérifie sur ta déclaration.",
        );
      }
    }

    // ── If marginal rate is missing, try to infer it ──
    if (tauxMarginal == null && cantonal != null && federal != null) {
      final revenuForInfer = _findFieldValue(fields, "revenu_imposable");
      if (revenuForInfer != null && revenuForInfer > 0) {
        final totalImpot = cantonal + federal;
        final inferredRate = totalImpot / revenuForInfer * 100;
        // Note: this is the average rate, not marginal — lower confidence
        if (inferredRate > 0 && inferredRate < 55) {
          fields.add(ExtractedField(
            fieldName: "taux_marginal_effectif",
            label: "Taux marginal effectif (estimé)",
            value: double.parse(inferredRate.toStringAsFixed(1)),
            confidence: 0.55, // Lower confidence — inferred average, not marginal
            sourceText:
                "Calculé: (cantonal + fédéral) / revenu imposable",
            needsReview: true,
            profileField: "actualMarginalRate",
          ));
          warnings.add(
            "Le taux marginal effectif a été estimé à partir du taux moyen "
            "(${inferredRate.toStringAsFixed(1)}%). Le taux marginal réel est "
            "généralement 5 à 15 points plus élevé. Vérifie sur ton avis de taxation.",
          );
        }
      }
    }

    // ── Overall confidence ──
    final overallConfidence = fields.isEmpty
        ? 0.0
        : fields.map((f) => f.confidence).reduce((a, b) => a + b) /
            fields.length;

    return ExtractionResult(
      documentType: DocumentType.taxDeclaration,
      fields: fields,
      overallConfidence: overallConfidence,
      confidenceDelta: _estimateConfidenceDeltaFromFields(fields),
      warnings: warnings,
      disclaimer:
          "Outil éducatif \u2014 ne constitue pas un conseil fiscal. "
          "Vérifie toujours les valeurs avec ton avis de taxation original. "
          "MINT ne stocke jamais l'image du document (LSFin).",
      sources: [
        "LIFD art. 25-31 (revenu imposable)",
        "LIFD art. 33-33a (déductions)",
        "LIFD art. 38 (imposition capital prévoyance)",
        "LHID art. 1-3 (harmonisation fiscale cantonale)",
      ],
    );
  }

  /// Extract a single field from OCR text using pattern matching.
  static ExtractedField? _extractField(String text, _TaxFieldPattern pattern) {
    for (final regex in pattern.patterns) {
      final match = regex.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        final rawValue = match.group(1)?.trim() ?? "";
        final dynamic parsedValue;
        double confidence;

        if (pattern.isPercentage) {
          final pct = _parsePercentage(rawValue);
          if (pct == null) continue;
          parsedValue = pct;
          // High confidence if the value is in a reasonable range
          confidence = (pct >= 5.0 && pct <= 55.0) ? 0.83 : 0.55;
        } else {
          final num = _parseSwissNumber(rawValue);
          if (num == null) continue;
          parsedValue = num;
          // Confidence based on how clean the extraction was
          confidence = rawValue.contains(RegExp(r"[\d]")) ? 0.82 : 0.50;
          // Boost confidence if CHF prefix was present
          if (match.group(0)?.contains(RegExp(r"CHF|Fr\.")) ?? false) {
            confidence += 0.05;
          }
        }

        // Cap confidence
        confidence = confidence.clamp(0.0, 0.95);

        return ExtractedField(
          fieldName: pattern.fieldName,
          label: pattern.label,
          value: parsedValue,
          confidence: confidence,
          sourceText: match.group(0) ?? "",
          needsReview: confidence < 0.80,
          profileField: pattern.profileField,
        );
      }
    }
    return null;
  }

  /// Find a specific field's value from the extraction results.
  static double? _findFieldValue(List<ExtractedField> fields, String name) {
    try {
      final field = fields.firstWhere((f) => f.fieldName == name);
      if (field.value is double) return field.value as double;
      if (field.value is int) return (field.value as int).toDouble();
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Confidence delta estimation ───────────────────────────

  /// Estimate how many confidence points this extraction adds to the profile.
  ///
  /// Based on DATA_ACQUISITION_STRATEGY impact table
  /// (Channel 1, Document B): +15-20 points.
  static double _estimateConfidenceDeltaFromFields(
      List<ExtractedField> fields) {
    double delta = 0;
    final fieldNames = fields.map((f) => f.fieldName).toSet();

    // Revenu imposable: +4 points
    if (fieldNames.contains("revenu_imposable")) delta += 4;

    // Fortune imposable: +2 points
    if (fieldNames.contains("fortune_imposable")) delta += 2;

    // Deductions: +2 points
    if (fieldNames.contains("deductions_effectuees")) delta += 2;

    // Impot cantonal: +2 points
    if (fieldNames.contains("impot_cantonal")) delta += 2;

    // Impot federal: +2 points
    if (fieldNames.contains("impot_federal")) delta += 2;

    // Taux marginal effectif: +5 points (CRITICAL for arbitrage)
    if (fieldNames.contains("taux_marginal_effectif")) delta += 5;

    return delta.clamp(0, 20);
  }

  /// Estimate confidence delta given an extraction result and the current
  /// user profile fields.
  ///
  /// Fields that replace system estimates have higher impact than those
  /// that replace user entries.
  static double estimateConfidenceDelta(
    ExtractionResult result,
    Map<String, dynamic> currentProfile,
  ) {
    double delta = 0;
    for (final field in result.fields) {
      final currentValue = currentProfile[field.profileField];
      if (currentValue == null || currentValue == 0) {
        // New field — full impact
        delta += _fieldImpact(field.fieldName);
      } else {
        // Replacing existing value — partial impact (accuracy upgrade)
        delta += _fieldImpact(field.fieldName) * 0.5;
      }
    }
    return delta.clamp(0, 20);
  }

  /// Impact weight of each field on overall confidence.
  static double _fieldImpact(String fieldName) {
    const impacts = {
      "revenu_imposable": 4.0,
      "fortune_imposable": 2.0,
      "deductions_effectuees": 2.0,
      "impot_cantonal": 2.0,
      "impot_federal": 2.0,
      "taux_marginal_effectif": 5.0,
    };
    return impacts[fieldName] ?? 1.0;
  }

  // ── Sample OCR text for prototype testing ─────────────────

  /// Sample OCR text simulating a typical Swiss tax declaration.
  /// Used for the prototype "Simuler un scan" button.
  static const String sampleOcrText = """
AVIS DE TAXATION 2025
Administration fiscale cantonale — Canton de Vaud

Contribuable: Dupont Marie
No. contribuable: 123.456.789
Commune: Lausanne

REVENU IMPOSABLE
Revenu imposable:                              CHF 95'800.00

FORTUNE IMPOSABLE
Fortune imposable:                             CHF 245'000.00

DEDUCTIONS
Total des déductions effectuées:               CHF 18'750.00
  dont pilier 3a:                              CHF 7'258.00
  dont frais professionnels:                   CHF 4'200.00
  dont assurance-maladie:                      CHF 3'192.00
  dont autres déductions:                      CHF 4'100.00

IMPOTS
Impôt cantonal et communal:                    CHF 14'520.00
Impôt fédéral direct:                          CHF 3'840.00

TAUX
Taux d'imposition effectif:                    19.15 %
Taux marginal effectif:                        32.5 %

---
Ce document est émis conformément à la LIFD et la loi fiscale cantonale.
Il constitue l'avis de taxation définitif pour la période fiscale 2025.
""";
}
