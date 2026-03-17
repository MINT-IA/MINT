// ────────────────────────────────────────────────────────────
//  LPP CERTIFICATE PARSER — Sprint S42-S43
// ────────────────────────────────────────────────────────────
//
//  Extracts structured financial fields from OCR text of a
//  Swiss LPP pension certificate (Certificat de prevoyance /
//  Vorsorgeausweis).
//
//  Handles both French and German certificate formats.
//  Parses Swiss number formatting (CHF 143'287.50).
//  Cross-validates obligatoire + surobligatoire ~ total.
//
//  Reference:
//    - DATA_ACQUISITION_STRATEGY.md — Channel 1, Document A
//    - LPP art. 14-16 (conversion rates, bonifications)
//    - OPP2 art. 5 (EPL minimum)
// ────────────────────────────────────────────────────────────

import 'package:mint_mobile/services/document_parser/document_models.dart';

/// Pattern definition for a known LPP certificate field.
class _FieldPattern {
  final String fieldName;
  final String label;
  final List<RegExp> patterns;
  final String? profileField;
  final bool isPercentage;

  const _FieldPattern({
    required this.fieldName,
    required this.label,
    required this.patterns,
    this.profileField,
    this.isPercentage = false,
  });
}

// Reusable regex fragment: Swiss number capture group
// Matches: CHF 143'287.50, Fr. 98 400, 44887.50, -25'000.00, etc.
// Requires at least one digit to avoid matching whitespace-only (e.g. section headers).
const String _numCapture = r"(-?\s*[CHFfr.\s]*\d[\d\s'.,]*)";

/// Service for parsing LPP certificate OCR text into structured fields.
///
/// Mirror of the backend service — all logic is pure Dart, no network calls.
/// Designed for on-device OCR (privacy-first: document never leaves phone).
class LppCertificateParser {
  LppCertificateParser._();

  // ── Swiss number parsing ──────────────────────────────────

  /// Parse a Swiss-formatted number: "143'287.50", "143 287", "CHF 143'287".
  /// Returns null if no valid number found.
  static double? _parseSwissNumber(String text) {
    // Remove currency prefixes and whitespace
    var cleaned = text
        .replaceAll(RegExp(r"CHF\s*", caseSensitive: false), "")
        .replaceAll(RegExp(r"Fr\.\s*", caseSensitive: false), "")
        .trim();

    // Remove thousand separators (apostrophe, space, thin space)
    // Swiss formats: 143'287.50 | 143'287,50 | 143 287.50 | 143287.50
    cleaned = cleaned.replaceAll("'", "");
    cleaned = cleaned.replaceAll("\u2019", ""); // Right single quotation mark
    cleaned = cleaned.replaceAll("\u00A0", ""); // Non-breaking space

    // Handle space as thousand separator (but not decimal)
    cleaned = cleaned.replaceAllMapped(
        RegExp(r"(\d)\s+(\d)"), (m) => "${m[1]}${m[2]}");

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

  /// Parse a percentage: "6.80%", "6,80 %", "0.068".
  static double? _parsePercentage(String text) {
    var cleaned = text.replaceAll("%", "").trim();
    cleaned = cleaned.replaceAll(",", ".");
    cleaned = cleaned.replaceAll(RegExp(r"[^\d.\-]"), "");
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null) return null;
    // If value > 1, it's already in percent form (e.g. 6.8)
    // If value <= 1, it might be in decimal form (e.g. 0.068)
    return value > 1 ? value : value * 100;
  }

  // ── Known field patterns (FR + DE) ────────────────────────

  static final List<_FieldPattern> _knownFieldPatterns = [
    // ── Avoir de vieillesse total ──
    _FieldPattern(
      fieldName: "lpp_total",
      label: "Avoir de vieillesse total",
      profileField: "avoirLppTotal",
      patterns: [
        RegExp(
            r"(?:avoir\s+de\s+vieillesse\s+total|total\s+avoir|capital?\s+de\s+vieillesse)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Altersguthaben\s+(?:total|gesamt)|Alterskapital\s+(?:total|gesamt))\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Total\s+(?:des\s+)?avoirs?)\s*[:\s]*" + _numCapture,
            caseSensitive: false),
      ],
    ),

    // ── Part obligatoire ──
    _FieldPattern(
      fieldName: "lpp_obligatoire",
      label: "Part obligatoire",
      profileField: "lppObligatoire",
      patterns: [
        RegExp(
            r"(?:part\s+obligatoire|avoir\s+obligatoire|partie?\s+obligatoire|avoirs?\s+(?:de\s+vieillesse\s+)?obligatoire)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Obligatorischer\s+Teil|obligatorische[sr]?\s+Altersguthaben|BVG[\-\s]*Guthaben)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
      ],
    ),

    // ── Part surobligatoire ──
    _FieldPattern(
      fieldName: "lpp_surobligatoire",
      label: "Part surobligatoire",
      profileField: "lppSurobligatoire",
      patterns: [
        RegExp(
            r"(?:part\s+sur[\-]?obligatoire|avoir\s+sur[\-]?obligatoire|partie?\s+sur[\-]?obligatoire)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Ueberobligatorischer?\s+Teil|ueberobligatorische[sr]?\s+Altersguthaben|Zusatzguthaben)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
      ],
    ),

    // ── Salaire assure ──
    _FieldPattern(
      fieldName: "lpp_insured_salary",
      label: "Salaire assure",
      profileField: "lppInsuredSalary",
      patterns: [
        RegExp(
            r"(?:salaire\s+(?:coordonn[e\u00e9]|assur[e\u00e9])|traitement\s+assur[e\u00e9])\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Versicherter\s+(?:Lohn|Verdienst)|Koordinierter\s+Lohn)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
      ],
    ),

    // ── Taux de bonification ──
    _FieldPattern(
      fieldName: "lpp_bonification_rate",
      label: "Taux de bonification",
      isPercentage: true,
      patterns: [
        RegExp(
            r"(?:taux\s+de\s+bonification(?:\s+de\s+vieillesse)?|bonification\s+de\s+vieillesse)\s*[:\s]*([\d,.\s]+\s*%?)",
            caseSensitive: false),
        RegExp(
            r"(?:Altersgutschrift(?:en)?[\-\s]*(?:Satz|Rate))\s*[:\s]*([\d,.\s]+\s*%?)",
            caseSensitive: false),
      ],
    ),

    // ── Taux de conversion obligatoire ──
    _FieldPattern(
      fieldName: "conversion_rate_oblig",
      label: "Taux de conversion (obligatoire)",
      profileField: "tauxConversionOblig",
      isPercentage: true,
      patterns: [
        RegExp(
            r"(?:taux\s+de\s+conversion\s*[\(]?oblig[a-z]*[\)]?)\s*[:\s]*([\d,.\s]+\s*%?)",
            caseSensitive: false),
        RegExp(
            r"(?:taux\s+de\s+conversion\s*[\(]?(?:LPP|minimum|l[eé]gal)[a-z]*[\)]?)\s*[:\s]*([\d,.\s]+\s*%?)",
            caseSensitive: false),
        RegExp(
            r"(?:Umwandlungssatz\s*[\(]?(?:oblig[a-z]*|BVG|Mindest|gesetzlich)[a-z]*[\)]?)\s*[:\s]*([\d,.\s]+\s*%?)",
            caseSensitive: false),
        // Generic: "taux de conversion" followed by 6.8 or similar
        RegExp(
            r"(?:taux\s+de\s+conversion)\s*[:\s]*(6[,.]8\d*\s*%?)",
            caseSensitive: false),
      ],
    ),

    // ── Taux de conversion surobligatoire ──
    _FieldPattern(
      fieldName: "conversion_rate_suroblig",
      label: "Taux de conversion (surobligatoire)",
      profileField: "tauxConversionSuroblig",
      isPercentage: true,
      patterns: [
        RegExp(
            r"(?:taux\s+de\s+conversion\s*[\(]?sur[\-]?oblig[a-z]*[\)]?)\s*[:\s]*([\d,.\s]+\s*%?)",
            caseSensitive: false),
        RegExp(
            r"(?:taux\s+de\s+conversion\s*[\(]?enveloppe[a-z]*[\)]?)\s*[:\s]*([\d,.\s]+\s*%?)",
            caseSensitive: false),
        RegExp(
            r"(?:Umwandlungssatz\s*[\(]?(?:[u\u00fc]beroblig[a-z]*|Huelle)[\)]?)\s*[:\s]*([\d,.\s]+\s*%?)",
            caseSensitive: false),
      ],
    ),

    // ── Rente de vieillesse projetee ──
    _FieldPattern(
      fieldName: "projected_rente",
      label: "Rente de vieillesse projetée",
      profileField: "projectedRenteLpp",
      patterns: [
        RegExp(
            r"(?:rente\s+de\s+vieillesse\s+(?:projet[e\u00e9]e|pr[e\u00e9]visible|estim[e\u00e9]e))\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Voraussichtliche\s+Altersrente|Altersrente\s+(?:ab|mit)\s+65)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
      ],
    ),

    // ── Capital projete a 65 ──
    _FieldPattern(
      fieldName: "projected_capital_65",
      label: "Capital projeté à 65 ans",
      profileField: "projectedCapital65",
      patterns: [
        RegExp(
            r"(?:capital\s+(?:de\s+vieillesse\s+)?(?:projet[e\u00e9]|pr[e\u00e9]visible|estim[e\u00e9])\s*(?:[a\u00e0]\s*65)?)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Voraussichtliches\s+Alterskapital|Alterskapital\s+(?:ab|mit)\s+65)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
      ],
    ),

    // ── Prestation d'invalidite ──
    _FieldPattern(
      fieldName: "disability_coverage",
      label: "Prestation d'invalidite",
      profileField: "disabilityCoverage",
      patterns: [
        RegExp(
            r"(?:rente?\s+d[' ]?invalidit[e\u00e9]|prestation\s+d[' ]?invalidit[e\u00e9]|invalidit[e\u00e9]\s+rente)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Invalidenrente|Rente\s+bei\s+Invalidit[a\u00e4]t)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
      ],
    ),

    // ── Prestation de deces ──
    _FieldPattern(
      fieldName: "death_coverage",
      label: "Prestation de deces",
      profileField: "deathCoverage",
      patterns: [
        RegExp(
            r"(?:capital[\-\s]*d[e\u00e9]c[e\u00e8]s|prestation\s+de\s+d[e\u00e9]c[e\u00e8]s)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Todesfallkapital|Todesfallleistung)\s*[:\s]*" + _numCapture,
            caseSensitive: false),
      ],
    ),

    // ── Lacune de rachat ──
    _FieldPattern(
      fieldName: "buyback_potential",
      label: "Lacune de rachat (rachat possible)",
      profileField: "buybackPotential",
      patterns: [
        RegExp(
            r"(?:rachat?\s+(?:possible|maximum|maximal)|lacune\s+de\s+rachat|montant\s+(?:de\s+)?rachat)(?:\s*\([^)]*\))?\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        RegExp(
            r"(?:(?:M[o\u00f6]glicher?\s+)?Einkauf(?:spotential)?|Einkaufsm[o\u00f6]glichkeit)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
      ],
    ),

    // ── Cotisation employe ──
    _FieldPattern(
      fieldName: "employee_contribution",
      label: "Cotisation employe (mensuelle)",
      profileField: "employeeLppContribution",
      patterns: [
        RegExp(
            r"(?:cotisation\s+(?:de\s+l[' ]?)?employ[e\u00e9]e?|part\s+(?:de\s+l[' ]?)?employ[e\u00e9]e?)\s*(?:mensuelle)?\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Arbeitnehmer[\-\s]*Beitrag|Beitrag\s+Arbeitnehmer)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
      ],
    ),

    // ── Cotisation employeur ──
    _FieldPattern(
      fieldName: "employer_contribution",
      label: "Cotisation employeur (mensuelle)",
      profileField: "employerLppContribution",
      patterns: [
        RegExp(
            r"(?:cotisation\s+(?:de\s+l[' ]?)?employeur|part\s+(?:de\s+l[' ]?)?employeur)\s*(?:mensuelle)?\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Arbeitgeber[\-\s]*Beitrag|Beitrag\s+Arbeitgeber)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
      ],
    ),

    // ── Taux de rémunération ──
    _FieldPattern(
      fieldName: "remuneration_rate",
      label: "Taux de rémunération",
      profileField: "rendementCaisse",
      isPercentage: true,
      patterns: [
        RegExp(
            r"(?:int[ée]r[êe]ts?|r[ée]mun[ée]r[ée])\s*[\(\:]?\s*(?:taux\s+(?:de\s+)?)?([\d,.\s]+\s*%?)",
            caseSensitive: false),
        RegExp(
            r"taux\s+(?:de\s+)?r[ée]mun[ée]ration\s*[:\s]*([\d,.\s]+\s*%?)",
            caseSensitive: false),
        RegExp(
            r"(?:Verzinsung|Zinssatz)\s*[:\s]*([\d,.\s]+\s*%?)",
            caseSensitive: false),
        RegExp(
            r"tasso\s+(?:di\s+)?remunerazione\s*[:\s]*([\d,.\s]+\s*%?)",
            caseSensitive: false),
      ],
    ),
  ];

  // ── Main parsing method ───────────────────────────────────

  /// Parse OCR text from an LPP certificate into structured fields.
  ///
  /// [text] is the raw OCR output from the certificate image.
  /// Returns an [ExtractionResult] with all detected fields,
  /// confidence scores, cross-validation warnings, and compliance info.
  static ExtractionResult parseLppCertificate(String text) {
    final fields = <ExtractedField>[];
    final warnings = <String>[];

    for (final pattern in _knownFieldPatterns) {
      final result = _extractField(text, pattern);
      if (result != null) {
        fields.add(result);
      }
    }

    // ── Cross-validation: oblig + suroblig ~ total ──
    final total = _findFieldValue(fields, "lpp_total");
    final oblig = _findFieldValue(fields, "lpp_obligatoire");
    final suroblig = _findFieldValue(fields, "lpp_surobligatoire");

    if (total != null && oblig != null && suroblig != null) {
      final sum = oblig + suroblig;
      final diff = (total - sum).abs();
      final tolerance = total * 0.05; // 5% tolerance for rounding
      if (diff > tolerance) {
        warnings.add(
          "Attention : la somme obligatoire ($oblig) + surobligatoire ($suroblig) = "
          "${sum.toStringAsFixed(0)} ne correspond pas exactement au total "
          "(${total.toStringAsFixed(0)}). Écart: ${diff.toStringAsFixed(0)} CHF. "
          "Vérifie les montants sur ton certificat.",
        );
      }
    } else if (total != null && oblig != null && suroblig == null) {
      // Can infer surobligatoire
      final inferred = total - oblig;
      if (inferred >= 0) {
        fields.add(ExtractedField(
          fieldName: "lpp_surobligatoire",
          label: "Part surobligatoire (déduit)",
          value: inferred,
          confidence: 0.70, // Lower confidence — inferred
          sourceText: "Calculé: total - obligatoire",
          needsReview: true,
          profileField: "lppSurobligatoire",
        ));
        warnings.add(
          "La part surobligatoire a été déduite (total - obligatoire = "
          "${inferred.toStringAsFixed(0)} CHF). Vérifie sur ton certificat.",
        );
      }
    }

    // ── Cross-validation: conversion rate obligatoire should be ~6.8% ──
    final convOblig = _findFieldValue(fields, "conversion_rate_oblig");
    if (convOblig != null && (convOblig < 5.0 || convOblig > 8.0)) {
      warnings.add(
        "Le taux de conversion obligatoire (${convOblig.toStringAsFixed(2)}%) "
        "semble inhabituel. Le minimum légal est 6.80% (LPP art. 14 al. 2). "
        "Vérifie sur ton certificat.",
      );
    }

    // ── Overall confidence ──
    final overallConfidence = fields.isEmpty
        ? 0.0
        : fields.map((f) => f.confidence).reduce((a, b) => a + b) /
            fields.length;

    return ExtractionResult(
      documentType: DocumentType.lppCertificate,
      fields: fields,
      overallConfidence: overallConfidence,
      confidenceDelta: _estimateConfidenceDeltaFromFields(fields),
      warnings: warnings,
      disclaimer:
          "Outil éducatif \u2014 ne constitue pas un conseil en prévoyance. "
          "Vérifie toujours les valeurs avec ton certificat original. "
          "MINT ne stocke jamais l'image du document (LSFin).",
      sources: [
        "LPP art. 14 al. 2 (taux de conversion minimum)",
        "LPP art. 15-16 (bonifications de vieillesse)",
        "OPP2 art. 5 (EPL minimum)",
        "LPP art. 79b al. 3 (rachat, blocage 3 ans)",
      ],
    );
  }

  /// Extract a single field from OCR text using pattern matching.
  static ExtractedField? _extractField(String text, _FieldPattern pattern) {
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
          confidence = (pct >= 1.0 && pct <= 25.0) ? 0.85 : 0.60;
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
  /// Based on which fields were extracted and the DATA_ACQUISITION_STRATEGY
  /// impact table (Channel 1, Document A).
  static double _estimateConfidenceDeltaFromFields(
      List<ExtractedField> fields) {
    double delta = 0;
    final fieldNames = fields.map((f) => f.fieldName).toSet();

    // LPP total: +5 points
    if (fieldNames.contains("lpp_total")) delta += 5;

    // Oblig/suroblig split: +8 points (CRITICAL for rente vs capital)
    if (fieldNames.contains("lpp_obligatoire")) delta += 4;
    if (fieldNames.contains("lpp_surobligatoire")) delta += 4;

    // Conversion rates: +4 points
    if (fieldNames.contains("conversion_rate_oblig")) delta += 2;
    if (fieldNames.contains("conversion_rate_suroblig")) delta += 2;

    // Buyback potential: +3 points
    if (fieldNames.contains("buyback_potential")) delta += 3;

    // Projected values: +2 points each
    if (fieldNames.contains("projected_rente")) delta += 2;
    if (fieldNames.contains("projected_capital_65")) delta += 2;

    // Coverage: +1 point each
    if (fieldNames.contains("disability_coverage")) delta += 1;
    if (fieldNames.contains("death_coverage")) delta += 1;

    // Contributions + salary: +2 points
    if (fieldNames.contains("employee_contribution")) delta += 1;
    if (fieldNames.contains("employer_contribution")) delta += 0.5;
    if (fieldNames.contains("lpp_insured_salary")) delta += 1;

    return delta.clamp(0, 30);
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
    return delta.clamp(0, 30);
  }

  /// Impact weight of each field on overall confidence.
  static double _fieldImpact(String fieldName) {
    const impacts = {
      "lpp_total": 5.0,
      "lpp_obligatoire": 4.0,
      "lpp_surobligatoire": 4.0,
      "conversion_rate_oblig": 2.0,
      "conversion_rate_suroblig": 2.0,
      "buyback_potential": 3.0,
      "projected_rente": 2.0,
      "projected_capital_65": 2.0,
      "disability_coverage": 1.0,
      "death_coverage": 1.0,
      "employee_contribution": 1.0,
      "employer_contribution": 0.5,
      "lpp_insured_salary": 1.0,
      "lpp_bonification_rate": 1.5,
    };
    return impacts[fieldName] ?? 1.0;
  }

  // ── Sample OCR text for prototype testing ─────────────────

  /// Sample OCR text simulating a typical Swiss LPP certificate.
  /// Used for the prototype "Simuler un scan" button.
  static const String sampleOcrText = """
CERTIFICAT DE PREVOYANCE 2025
Caisse de pension XY \u2014 Fondation collective LPP

Nom: Dupont Marie
Date de naissance: 15.03.1988
No. assure: 12345-678

AVOIR DE VIEILLESSE
Avoir de vieillesse total:                    CHF 143'287.50
  Part obligatoire:                            CHF 98'400.00
  Part surobligatoire:                         CHF 44'887.50

SALAIRE ET COTISATIONS
Salaire assure:                                CHF 72'540.00
Taux de bonification de vieillesse:            15.0 %
Cotisation de l'employe mensuelle:             CHF 452.50
Cotisation de l'employeur mensuelle:           CHF 543.00

TAUX DE CONVERSION
Taux de conversion (obligatoire):              6.80 %
Taux de conversion (surobligatoire):           5.20 %

PRESTATIONS PROJETEES A 65 ANS
Rente de vieillesse projetee:                  CHF 31'450.00 / an
Capital de vieillesse projete a 65:            CHF 485'200.00

PRESTATIONS DE RISQUE
Prestation d'invalidite:                       CHF 36'800.00 / an
Capital-deces:                                 CHF 220'500.00

RACHAT
Rachat possible (montant maximum):             CHF 45'000.00

---
Ce document a ete etabli conformement aux dispositions de la LPP.
Il ne constitue pas un engagement contractuel.
""";
}
