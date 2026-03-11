// ────────────────────────────────────────────────────────────
//  AVS EXTRACT PARSER — Sprint S45
// ────────────────────────────────────────────────────────────
//
//  Extracts structured financial fields from OCR text of a
//  Swiss AVS individual account extract (Extrait de compte
//  individuel CI / Individueller Kontoauszug IK).
//
//  Handles both French and German extract formats.
//  Parses Swiss number formatting.
//  Cross-validates: annees + lacunes <= age - 20.
//
//  4 fields extracted:
//    - anneesCotisation (exact contribution years)
//    - ramd (Revenu annuel moyen determinant — CRITICAL for rente)
//    - lacunesCotisation (years with gaps)
//    - bonificationsEducatives (education credits)
//
//  Reference:
//    - DATA_ACQUISITION_STRATEGY.md — Channel 1, Document C
//    - LAVS art. 29ter-30 (RAMD, annees de cotisation)
//    - LAVS art. 29sexies (bonifications educatives)
//    - LAVS art. 34-35 (rente calculation)
// ────────────────────────────────────────────────────────────

import 'package:mint_mobile/services/document_parser/document_models.dart';

/// Pattern definition for a known AVS extract field.
class _AvsFieldPattern {
  final String fieldName;
  final String label;
  final List<RegExp> patterns;
  final String? profileField;
  final bool isInteger;

  const _AvsFieldPattern({
    required this.fieldName,
    required this.label,
    required this.patterns,
    this.profileField,
    this.isInteger = false,
  });
}

// Reusable regex fragment: Swiss number capture group
const String _numCapture = r"([CHFfr.\s]*[\d\s'.,]+)";

// Integer capture group for years
const String _intCapture = r"(\d{1,2})";

/// Service for parsing AVS extract OCR text into structured fields.
///
/// Mirror of the backend service — all logic is pure Dart, no network calls.
/// Designed for on-device OCR (privacy-first: document never leaves phone).
///
/// Confidence delta: +20-25 points.
class AvsExtractParser {
  AvsExtractParser._();

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

  /// Parse an integer value (for years).
  static int? _parseInteger(String text) {
    final cleaned = text.replaceAll(RegExp(r"[^\d]"), "");
    if (cleaned.isEmpty) return null;
    return int.tryParse(cleaned);
  }

  // ── Known field patterns (FR + DE) ────────────────────────

  static final List<_AvsFieldPattern> _knownFieldPatterns = [
    // ── Annees de cotisation ──
    _AvsFieldPattern(
      fieldName: "annees_cotisation",
      label: "Annees de cotisation",
      profileField: "avsContributionYears",
      isInteger: true,
      patterns: [
        RegExp(
            r"(?:ann[e\u00e9]es?\s+de\s+cotisation|dur[e\u00e9]e\s+de\s+cotisation|ann[e\u00e9]es?\s+d[' ]?assurance)\s*[:\s]*" +
                _intCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Beitragsjahre|Beitragsdauer|Versicherungsjahre|Versicherungsdauer)\s*[:\s]*" +
                _intCapture,
            caseSensitive: false),
        // Variante: "nombre d'annees: 22"
        RegExp(
            r"(?:nombre\s+d[' ]?ann[e\u00e9]es?)\s*[:\s]*" + _intCapture,
            caseSensitive: false),
        // Variante: "22 annees de cotisation"
        RegExp(
            r"" + _intCapture + r"\s+ann[e\u00e9]es?\s+(?:de\s+)?cotisation",
            caseSensitive: false),
      ],
    ),

    // ── RAMD (Revenu annuel moyen determinant) ──
    _AvsFieldPattern(
      fieldName: "ramd",
      label: "Revenu annuel moyen determinant (RAMD)",
      profileField: "avsRamd",
      patterns: [
        RegExp(
            r"(?:revenu\s+annuel\s+moyen\s+d[e\u00e9]terminant|RAMD|revenu\s+moyen)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Massgebendes?\s+durchschnittliches?\s+Jahreseinkommen|MDJE|Durchschnittliches?\s+Jahreseinkommen)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        // Variante: "revenu determinant moyen"
        RegExp(
            r"(?:revenu\s+d[e\u00e9]terminant\s+moyen)\s*[:\s]*" + _numCapture,
            caseSensitive: false),
      ],
    ),

    // ── Lacunes de cotisation ──
    _AvsFieldPattern(
      fieldName: "lacunes_cotisation",
      label: "Lacunes de cotisation",
      profileField: "avsGaps",
      isInteger: true,
      patterns: [
        RegExp(
            r"(?:lacunes?\s+de\s+cotisation|ann[e\u00e9]es?\s+manquantes?|ann[e\u00e9]es?\s+sans\s+cotisation)\s*[:\s]*" +
                _intCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Beitragsl[u\u00fc]cken?|Fehlende\s+(?:Beitrags[\-]?)?[Jj]ahre|Jahre\s+ohne\s+Beitr[a\u00e4]ge)\s*[:\s]*" +
                _intCapture,
            caseSensitive: false),
        // Variante: "0 lacune" or "2 lacunes"
        RegExp(
            r"" + _intCapture + r"\s+lacunes?\s*(?:de\s+cotisation)?",
            caseSensitive: false),
      ],
    ),

    // ── Bonifications educatives ──
    _AvsFieldPattern(
      fieldName: "bonifications_educatives",
      label: "Bonifications pour taches educatives",
      profileField: "avsEducationCredits",
      isInteger: true,
      patterns: [
        RegExp(
            r"(?:bonifications?\s+(?:pour\s+)?(?:t[a\u00e2]ches?\s+)?[e\u00e9]ducatives?|bonifications?\s+pour\s+[e\u00e9]ducation)\s*[:\s]*" +
                _intCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Erziehungsgutschriften?|Gutschriften?\s+f[u\u00fc]r\s+Erziehung)\s*[:\s]*" +
                _intCapture,
            caseSensitive: false),
        // Variante: nombre d'annees de bonifications
        RegExp(
            r"(?:ann[e\u00e9]es?\s+de\s+bonifications?\s+[e\u00e9]ducatives?)\s*[:\s]*" +
                _intCapture,
            caseSensitive: false),
      ],
    ),
  ];

  // ── Main parsing method ───────────────────────────────────

  /// Parse OCR text from an AVS extract into structured fields.
  ///
  /// [text] is the raw OCR output from the AVS extract image.
  /// [userAge] is optional — if provided, enables cross-validation
  /// of annees + lacunes <= age - 20.
  /// Returns an [ExtractionResult] with all detected fields,
  /// confidence scores, cross-validation warnings, and compliance info.
  static ExtractionResult parseAvsExtract(String text, {int? userAge}) {
    final fields = <ExtractedField>[];
    final warnings = <String>[];

    for (final pattern in _knownFieldPatterns) {
      final result = _extractField(text, pattern);
      if (result != null) {
        fields.add(result);
      }
    }

    // ── Cross-validation: annees + lacunes <= age - 20 ──
    final annees = _findFieldIntValue(fields, "annees_cotisation");
    final lacunes = _findFieldIntValue(fields, "lacunes_cotisation");

    if (annees != null && userAge != null) {
      final maxPossibleYears = userAge - 20; // AVS cotisation starts at 20
      if (maxPossibleYears > 0 && annees > maxPossibleYears) {
        warnings.add(
          "Le nombre d'années de cotisation ($annees) dépasse le maximum "
          "possible pour ton âge ($userAge ans = $maxPossibleYears années max). "
          "Vérifie sur ton extrait de compte AVS.",
        );
      }

      if (lacunes != null) {
        final totalYears = annees + lacunes;
        if (maxPossibleYears > 0 && totalYears > maxPossibleYears) {
          warnings.add(
            "La somme années ($annees) + lacunes ($lacunes) = $totalYears "
            "dépasse le maximum possible pour ton âge ($maxPossibleYears). "
            "Vérifie les chiffres sur ton extrait.",
          );
        }
      }
    }

    // ── Cross-validation: RAMD plausibility ──
    final ramd = _findFieldDoubleValue(fields, "ramd");
    if (ramd != null) {
      // AVS rente max = 30'240 CHF/an -> RAMD max ~ 88'200 (2x plafond)
      if (ramd > 100000) {
        warnings.add(
          "Le RAMD (${ramd.toStringAsFixed(0)} CHF) semble élevé. "
          "Le RAMD est plafonné à environ 88'200 CHF (2x rente max AVS). "
          "Vérifie sur ton extrait de compte.",
        );
      }
      if (ramd < 1000 && ramd > 0) {
        warnings.add(
          "Le RAMD (${ramd.toStringAsFixed(0)} CHF) semble très bas. "
          "Vérifie s'il s'agit bien du revenu annuel moyen et non d'un autre montant.",
        );
      }
    }

    // ── Cross-validation: bonifications educatives plausibility ──
    final bonifications =
        _findFieldIntValue(fields, "bonifications_educatives");
    if (bonifications != null && bonifications > 16) {
      // Max educative credits: 16 years per child
      warnings.add(
        "Les bonifications éducatives ($bonifications années) semblent élevées. "
        "Le maximum usuel est de 16 ans par enfant (LAVS art. 29sexies). "
        "Vérifie sur ton extrait.",
      );
    }

    // ── Overall confidence ──
    final overallConfidence = fields.isEmpty
        ? 0.0
        : fields.map((f) => f.confidence).reduce((a, b) => a + b) /
            fields.length;

    return ExtractionResult(
      documentType: DocumentType.avsExtract,
      fields: fields,
      overallConfidence: overallConfidence,
      confidenceDelta: _estimateConfidenceDeltaFromFields(fields),
      warnings: warnings,
      disclaimer:
          "Outil éducatif \u2014 ne constitue pas un conseil en prévoyance. "
          "Vérifie toujours les valeurs avec ton extrait de compte AVS original. "
          "MINT ne stocke jamais l'image du document (LSFin).",
      sources: [
        "LAVS art. 29ter-30 (RAMD, années de cotisation)",
        "LAVS art. 29sexies (bonifications éducatives)",
        "LAVS art. 34-35 (calcul de la rente)",
        "LAVS art. 40 (rente anticipée / différée)",
      ],
    );
  }

  /// Extract a single field from OCR text using pattern matching.
  static ExtractedField? _extractField(String text, _AvsFieldPattern pattern) {
    for (final regex in pattern.patterns) {
      final match = regex.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        final rawValue = match.group(1)?.trim() ?? "";
        final dynamic parsedValue;
        double confidence;

        if (pattern.isInteger) {
          final intVal = _parseInteger(rawValue);
          if (intVal == null) continue;
          parsedValue = intVal.toDouble(); // Store as double for consistency
          // High confidence for clean integer extraction
          confidence = 0.88;
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

  /// Find a specific field's integer value from the extraction results.
  static int? _findFieldIntValue(List<ExtractedField> fields, String name) {
    try {
      final field = fields.firstWhere((f) => f.fieldName == name);
      if (field.value is double) return (field.value as double).round();
      if (field.value is int) return field.value as int;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Find a specific field's double value from the extraction results.
  static double? _findFieldDoubleValue(
      List<ExtractedField> fields, String name) {
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
  /// (Channel 1, Document C): +20-25 points.
  static double _estimateConfidenceDeltaFromFields(
      List<ExtractedField> fields) {
    double delta = 0;
    final fieldNames = fields.map((f) => f.fieldName).toSet();

    // Annees de cotisation: +6 points
    if (fieldNames.contains("annees_cotisation")) delta += 6;

    // RAMD: +8 points (CRITICAL for AVS rente calculation)
    if (fieldNames.contains("ramd")) delta += 8;

    // Lacunes de cotisation: +5 points
    if (fieldNames.contains("lacunes_cotisation")) delta += 5;

    // Bonifications educatives: +3 points
    if (fieldNames.contains("bonifications_educatives")) delta += 3;

    return delta.clamp(0, 25);
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
    return delta.clamp(0, 25);
  }

  /// Impact weight of each field on overall confidence.
  static double _fieldImpact(String fieldName) {
    const impacts = {
      "annees_cotisation": 6.0,
      "ramd": 8.0,
      "lacunes_cotisation": 5.0,
      "bonifications_educatives": 3.0,
    };
    return impacts[fieldName] ?? 1.0;
  }

  // ── Sample OCR text for prototype testing ─────────────────

  /// Sample OCR text simulating a typical Swiss AVS individual account extract.
  /// Used for the prototype "Simuler un scan" button.
  static const String sampleOcrText = """
EXTRAIT DE COMPTE INDIVIDUEL (CI)
Caisse de compensation AVS — Caisse cantonale vaudoise

Assure(e): Dupont Marie
No. AVS: 756.1234.5678.90
Date de naissance: 15.03.1988

RECAPITULATIF
Annees de cotisation:                          22
Revenu annuel moyen determinant (RAMD):        CHF 72'450.00
Lacunes de cotisation:                         0
Bonifications pour taches educatives:          3

DETAIL DES COTISATIONS
2003:  CHF 12'400.00   (premiere cotisation)
2004:  CHF 28'500.00
2005:  CHF 35'200.00
...
2024:  CHF 95'800.00
2025:  CHF 98'400.00

REMARQUES
- Aucune lacune de cotisation detectee.
- 3 annees de bonifications educatives comptabilisees (2018-2020).
- Rente estimee a 65 ans (echelle 44): CHF 2'390/mois.

---
Cet extrait est etabli conformement a la LAVS.
Disponible gratuitement sur www.ahv-iv.ch.
""";
}
