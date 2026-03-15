// ────────────────────────────────────────────────────────────
//  LPP CERTIFICATE PARSER — Sprint S42-S43 + S48 rewrite
// ────────────────────────────────────────────────────────────
//
//  Extracts structured financial fields from OCR text of a
//  Swiss LPP pension certificate (Certificat de prevoyance /
//  Vorsorgeausweis).
//
//  Handles:
//  - Standard single-column certificates
//  - CPE-style Bonus/Base two-column tabular format (sums both)
//  - Projection tables by age (extracts age 65 row)
//  - French and German certificate formats
//  - Swiss number formatting (CHF 143'287.50)
//
//  Golden test: test/golden/Julien/ — CPE Caisse de Pension Energie
//
//  Reference:
//    - DATA_ACQUISITION_STRATEGY.md — Channel 1, Document A
//    - LPP art. 14-16 (conversion rates, bonifications)
//    - OPP2 art. 5 (EPL minimum)
// ────────────────────────────────────────────────────────────

import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/document_parser_utils.dart';

/// Service for parsing LPP certificate OCR text into structured fields.
///
/// Handles both standard single-column and CPE-style Bonus/Base formats.
/// All logic is pure Dart, no network calls (privacy-first).
class LppCertificateParser {
  LppCertificateParser._();

  // ── Main parsing method ───────────────────────────────────

  /// Parse OCR text from an LPP certificate into structured fields.
  ///
  /// [text] is the raw OCR output from the certificate image/PDF.
  /// Returns an [ExtractionResult] with all detected fields,
  /// confidence scores, cross-validation warnings, and compliance info.
  static ExtractionResult parseLppCertificate(String text) {
    final fields = <ExtractedField>[];
    final warnings = <String>[];

    // ── Phase 1: Extract simple regex-matched fields ──
    for (final pattern in _knownFieldPatterns) {
      final result = _extractField(text, pattern);
      if (result != null) {
        fields.add(result);
      }
    }

    // ── Phase 2: Extract tabular Bonus/Base fields ──
    // Real Swiss certificates (CPE, Baloise, Swiss Life, etc.) often
    // split values into Bonus + Base columns that must be summed.
    _extractBonusBaseFields(text, fields);

    // ── Phase 3: Extract projection tables (age 65) ──
    _extractProjectionAtAge65(text, fields);

    // ── Phase 4: Extract "Prestation de sortie" section ──
    _extractPrestationDeSortie(text, fields, warnings);

    // ── Phase 5: Extract rachat (buyback) amounts ──
    _extractRachats(text, fields);

    // ── Phase 6: Extract taux de rémunération from Intérêts line ──
    _extractTauxRemuneration(text, fields);

    // ── Phase 7: Extract invalidité / décès from real labels ──
    _extractRiskBenefits(text, fields);

    // ── Phase 8: Extract cotisations (risque + épargne = total) ──
    _extractCotisations(text, fields);

    // ── Cross-validation ──
    _crossValidate(fields, warnings);

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

  // ── Swiss number parsing (delegates to shared utils) ─────

  static double? _parseSwissNumber(String text) => parseSwissNumber(text);
  static double? _parsePercentage(String text) => parsePercentage(text);

  // ── Known field patterns (FR + DE) ────────────────────────
  //
  // These match "standard" single-column certificate formats.
  // The Bonus/Base and CPE-specific logic is in the Phase 2+ methods.

  static final List<_FieldPattern> _knownFieldPatterns = [
    // ── Avoir de vieillesse total ──
    _FieldPattern(
      fieldName: "lpp_total",
      label: "Avoir de vieillesse total",
      profileField: "avoirLppTotal",
      patterns: [
        // Standard: "Avoir de vieillesse total: CHF 70'376.60"
        // HOTELA: "Capital total 19'620.30"
        RegExp(
            r"(?:avoir\s+de\s+vieillesse\s+total|total\s+(?:des\s+)?avoirs?|capital\s+de\s+vieillesse\s+total|capital\s+total)\s*[:\s]*" +
                numCapture,
            caseSensitive: false),
        // German
        RegExp(
            r"(?:Altersguthaben\s+(?:total|gesamt)|Alterskapital\s+(?:total|gesamt))\s*[:\s]*" +
                numCapture,
            caseSensitive: false),
      ],
    ),

    // ── Part obligatoire ──
    _FieldPattern(
      fieldName: "lpp_obligatoire",
      label: "Part obligatoire (LPP)",
      profileField: "lppObligatoire",
      patterns: [
        // Standard: "Part obligatoire: CHF 30'243.80"
        RegExp(
            r"(?:part\s+obligatoire|avoir\s+obligatoire|partie?\s+obligatoire|avoirs?\s+(?:de\s+vieillesse\s+)?obligatoire)\s*[:\s]*" +
                numCapture,
            caseSensitive: false),
        // CPE: "Avoir de vieillesse LPP 30'243.80"
        // HOTELA: "Minimum LPP 10'203.25"
        RegExp(
            r"(?:avoir\s+de\s+vieillesse\s+LPP|minimum\s+LPP)\s*[:\s]*" +
                numCapture,
            caseSensitive: false),
        // German
        RegExp(
            r"(?:Obligatorischer\s+Teil|obligatorische[sr]?\s+Altersguthaben|BVG[\-\s]*Guthaben)\s*[:\s]*" +
                numCapture,
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
                numCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Ueberobligatorischer?\s+Teil|ueberobligatorische[sr]?\s+Altersguthaben|Zusatzguthaben)\s*[:\s]*" +
                numCapture,
            caseSensitive: false),
      ],
    ),

    // ── Salaire assuré ──
    _FieldPattern(
      fieldName: "lpp_insured_salary",
      label: "Salaire assuré",
      profileField: "lppInsuredSalary",
      patterns: [
        // Standard: "Salaire assuré: CHF 91'967"
        RegExp(
            r"(?:salaire\s+assur[eé](?:\s*/\s*salaire\s+d['']épargne)?|salaire\s+coordonn[eé]|traitement\s+assur[eé])\s*[:\s]*" +
                numCapture,
            caseSensitive: false),
        // German
        RegExp(
            r"(?:Versicherter\s+(?:Lohn|Verdienst)|Koordinierter\s+Lohn)\s*[:\s]*" +
                numCapture,
            caseSensitive: false),
      ],
    ),

    // ── Salaire déterminant / brut AVS ──
    _FieldPattern(
      fieldName: "lpp_determining_salary",
      label: "Salaire déterminant",
      profileField: "salaireBrut",
      patterns: [
        // Standard: "Salaire déterminant 122'206.80"
        RegExp(
            r"(?:salaire\s+d[eé]terminant)\s*[:\s]*" + numCapture,
            caseSensitive: false),
        // HOTELA: "Salaire annuel brut AVS 67'000.00"
        RegExp(
            r"(?:salaire\s+annuel\s+brut\s+AVS)\s*[:\s]*" + numCapture,
            caseSensitive: false),
        // German
        RegExp(
            r"(?:Massgebender\s+(?:Lohn|Verdienst))\s*[:\s]*" + numCapture,
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
            r"(?:taux\s+de\s+bonification|bonification\s+de\s+vieillesse)\s*[:\s]*([\d,.\s]+\s*%?)",
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
        // "Taux de conversion (obligatoire): 6.80 %"
        RegExp(
            r"taux\s+de\s+conversion\s*\(?\s*(?:oblig\w*|LPP|minimum|l[eé]gal\w*)\s*\)?\s*[:\s]*([\d,.\s]+\s*%?)",
            caseSensitive: false),
        RegExp(
            r"Umwandlungssatz\s*\(?\s*(?:oblig\w*|BVG|Mindest|gesetzlich\w*)\s*\)?\s*[:\s]*([\d,.\s]+\s*%?)",
            caseSensitive: false),
        // Generic: "taux de conversion" followed by 6.8 or similar
        RegExp(
            r"taux\s+de\s+conversion\s*[:\s]*(6[,.]8\d*\s*%?)",
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
            r"taux\s+de\s+conversion\s*\(?\s*(?:sur[\-]?oblig\w*|enveloppe)\s*\)?\s*[:\s]*([\d,.\s]+\s*%?)",
            caseSensitive: false),
        RegExp(
            r"Umwandlungssatz\s*\(?\s*(?:[uü]beroblig\w*|Huelle)\s*\)?\s*[:\s]*([\d,.\s]+\s*%?)",
            caseSensitive: false),
      ],
    ),

    // ── Rente de vieillesse projetée (standard format) ──
    _FieldPattern(
      fieldName: "projected_rente",
      label: "Rente de vieillesse projetée",
      profileField: "projectedRenteLpp",
      patterns: [
        RegExp(
            r"(?:rente\s+de\s+vieillesse\s+(?:projet[eé]e|pr[eé]visible|estim[eé]e))\s*[:\s]*" +
                numCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Voraussichtliche\s+Altersrente|Altersrente\s+(?:ab|mit)\s+65)\s*[:\s]*" +
                numCapture,
            caseSensitive: false),
      ],
    ),

    // ── Capital projeté à 65 (standard format) ──
    _FieldPattern(
      fieldName: "projected_capital_65",
      label: "Capital projeté à 65 ans",
      profileField: "projectedCapital65",
      patterns: [
        RegExp(
            r"(?:capital\s+(?:de\s+vieillesse\s+)?(?:projet[eé]|pr[eé]visible|estim[eé])\s*(?:[aà]\s*65)?)\s*[:\s]*" +
                numCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Voraussichtliches\s+Alterskapital|Alterskapital\s+(?:ab|mit)\s+65)\s*[:\s]*" +
                numCapture,
            caseSensitive: false),
      ],
    ),

    // ── EPL (encouragement propriété logement) ──
    _FieldPattern(
      fieldName: "epl_max",
      label: "Montant max EPL",
      profileField: "eplMax",
      patterns: [
        // "Somme maximale disponible pour l'encouragement à la propriété du logement 60'075.25"
        RegExp(
            r"(?:somme\s+maximale\s+disponible\s+pour\s+l['']encouragement\s+[àa]\s+la\s+propri[eé]t[eé]\s+du\s+logement)\s*[:\s]*" +
                numCapture,
            caseSensitive: false),
        // Shorter: "encouragement à la propriété du logement: CHF XX"
        RegExp(
            r"(?:encouragement\s+[àa]\s+la\s+propri[eé]t[eé]\s+du\s+logement)\s*[:\s]*" +
                numCapture,
            caseSensitive: false),
        // German
        RegExp(
            r"(?:Wohneigentumsf[oö]rderung|WEF[\-\s]*Betrag)\s*[:\s]*" +
                numCapture,
            caseSensitive: false),
      ],
    ),
  ];

  // ── Phase 2: Bonus/Base tabular extraction ──────────────

  /// Detect and extract fields from CPE-style Bonus/Base two-column format.
  ///
  /// Real certificates (CPE, Baloise, etc.) often show:
  ///   "Avoir de vieillesse au 08.03.2026    855.35    69'521.25"
  /// We need to sum Bonus + Base to get the total.
  static void _extractBonusBaseFields(
      String text, List<ExtractedField> fields) {
    final existingNames = fields.map((f) => f.fieldName).toSet();

    // Pattern: label followed by two Swiss numbers on the same line
    // This captures "Avoir de vieillesse au DD.MM.YYYY  NUM1  NUM2"
    final twoColumnPattern = RegExp(
        r"^(.+?)\s+([\d'., ]+\.\d{2})\s+([\d'., ]+\.\d{2})\s*$",
        multiLine: true);

    for (final match in twoColumnPattern.allMatches(text)) {
      final label = match.group(1)?.trim() ?? "";
      final val1 = _parseSwissNumber(match.group(2) ?? "");
      final val2 = _parseSwissNumber(match.group(3) ?? "");
      if (val1 == null || val2 == null) continue;
      final total = val1 + val2;
      final labelLower = label.toLowerCase();

      // Salaire déterminant — take Base column only (Bonus is often 0)
      if (labelLower.contains("salaire déterminant") ||
          labelLower.contains("salaire determinant")) {
        if (!existingNames.contains("lpp_determining_salary") && val2 > 0) {
          fields.add(_makeField(
            "lpp_determining_salary",
            "Salaire déterminant",
            val2,
            match.group(0) ?? "",
            profileField: "salaireBrut",
            confidence: 0.90,
          ));
          existingNames.add("lpp_determining_salary");
        }
      }

      // Salaire assuré / salaire d'épargne — take Base column
      if ((labelLower.contains("salaire assuré") ||
              labelLower.contains("salaire assure")) &&
          (labelLower.contains("épargne") || labelLower.contains("epargne"))) {
        if (!existingNames.contains("lpp_insured_salary") && val2 > 0) {
          fields.add(_makeField(
            "lpp_insured_salary",
            "Salaire assuré",
            val2,
            match.group(0) ?? "",
            profileField: "lppInsuredSalary",
            confidence: 0.90,
          ));
          existingNames.add("lpp_insured_salary");
        }
      }

      // Avoir de vieillesse au DD.MM.YYYY — sum Bonus + Base
      if (labelLower.contains("avoir de vieillesse au") &&
          RegExp(r"\d{2}\.\d{2}\.\d{4}").hasMatch(label)) {
        // This is the current total (not projected)
        // Only use if we don't have a "prestation de sortie" total yet
        if (!existingNames.contains("lpp_total")) {
          fields.add(_makeField(
            "lpp_total",
            "Avoir de vieillesse total",
            total,
            match.group(0) ?? "",
            profileField: "avoirLppTotal",
            confidence: 0.88,
          ));
          existingNames.add("lpp_total");
        }
      }

      // Cotisation d'épargne (employé)
      if (labelLower.contains("cotisation d") &&
          labelLower.contains("pargne")) {
        // Check if we're in "Cotisations du salarié" or "de l'employeur" section
        // We'll handle this in the dedicated _extractCotisations method
      }
    }
  }

  // ── Phase 3: Projection tables ──────────────────────────

  /// Extract projected capital and rente at age 65 from projection tables.
  ///
  /// CPE format:
  ///   "Projection de l'avoir de vieillesse    Bonus    Base"
  ///   "âge 65    1'200.00    676'647.00"
  ///
  ///   "Projection de la rente de vieillesse annuelle    TdC*    Bonus    Base"
  ///   "âge 65    5.00%    60.00    33'832.00"
  static void _extractProjectionAtAge65(
      String text, List<ExtractedField> fields) {
    final existingNames = fields.map((f) => f.fieldName).toSet();

    // ── Capital projection at age 65 ──
    if (!existingNames.contains("projected_capital_65")) {
      // CPE format: "Projection de l'avoir de vieillesse" section with "âge 65  NUM  NUM"
      final capitalSectionPattern = RegExp(
          r"Projection\s+de\s+l['']avoir\s+de\s+vieillesse",
          caseSensitive: false);
      final capitalSectionMatch = capitalSectionPattern.firstMatch(text);

      if (capitalSectionMatch != null) {
        final afterSection = text.substring(capitalSectionMatch.end);
        final age65Pattern = RegExp(
            r"[âa]ge\s+65\s+([\d'., ]+\.\d{2})\s+([\d'., ]+\.\d{2})",
            caseSensitive: false);
        final age65Match = age65Pattern.firstMatch(afterSection);

        if (age65Match != null) {
          final bonus = _parseSwissNumber(age65Match.group(1) ?? "");
          final base = _parseSwissNumber(age65Match.group(2) ?? "");
          if (bonus != null && base != null) {
            fields.add(_makeField(
              "projected_capital_65",
              "Capital projeté à 65 ans",
              bonus + base,
              "âge 65: ${age65Match.group(0)}",
              profileField: "projectedCapital65",
              confidence: 0.88,
            ));
            existingNames.add("projected_capital_65");
          }
        }
      }

      // HOTELA format: "Capital retraite 138'610.75 147'651.40 ... 184'958.15"
      // Last number = age 65. Split on whitespace between numbers.
      if (!existingNames.contains("projected_capital_65")) {
        final capitalRetraitePattern = RegExp(
            r"Capital\s+retraite\s+(.+)",
            caseSensitive: false);
        final crMatch = capitalRetraitePattern.firstMatch(text);
        if (crMatch != null) {
          final numbersStr = crMatch.group(1) ?? "";
          // Split by 2+ spaces or single space between digit groups
          final numbers = RegExp(r"\d[\d'.]*\.\d{2}")
              .allMatches(numbersStr)
              .map((m) => _parseSwissNumber(m.group(0) ?? ""))
              .whereType<double>()
              .where((n) => n > 1000) // Filter out small noise numbers
              .toList();
          if (numbers.isNotEmpty) {
            final lastValue = numbers.last; // Last column = age 65
            fields.add(_makeField(
              "projected_capital_65",
              "Capital projeté à 65 ans",
              lastValue,
              "Capital retraite (âge 65)",
              profileField: "projectedCapital65",
              confidence: 0.85,
            ));
            existingNames.add("projected_capital_65");
          }
        }
      }
    }

    // ── Rente projection at age 65 ──
    // Match "âge 65  5.00%  60.00  33'832.00" (TdC + Bonus + Base)
    if (!existingNames.contains("projected_rente")) {
      final renteSectionPattern = RegExp(
          r"Projection\s+de\s+la\s+rente\s+de\s+vieillesse",
          caseSensitive: false);
      final renteSectionMatch = renteSectionPattern.firstMatch(text);

      if (renteSectionMatch != null) {
        final afterSection = text.substring(renteSectionMatch.end);
        // Pattern: âge 65  5.00%  60.00  33'832.00
        final age65RentePattern = RegExp(
            r"[âa]ge\s+65\s+([\d,.]+\s*%?)\s+([\d'., ]+\.\d{2})\s+([\d'., ]+\.\d{2})",
            caseSensitive: false);
        final age65RenteMatch = age65RentePattern.firstMatch(afterSection);

        if (age65RenteMatch != null) {
          final bonus = _parseSwissNumber(age65RenteMatch.group(2) ?? "");
          final base = _parseSwissNumber(age65RenteMatch.group(3) ?? "");
          if (bonus != null && base != null) {
            final total = bonus + base;
            fields.add(_makeField(
              "projected_rente",
              "Rente de vieillesse projetée (annuelle)",
              total,
              "âge 65: ${age65RenteMatch.group(0)}",
              profileField: "projectedRenteLpp",
              confidence: 0.88,
            ));
            existingNames.add("projected_rente");
          }

          // Also extract the TdC (taux de conversion) at 65
          if (!existingNames.contains("conversion_rate_at_65")) {
            final tdcStr = age65RenteMatch.group(1) ?? "";
            final tdc = _parsePercentage(tdcStr);
            if (tdc != null && tdc >= 3.0 && tdc <= 8.0) {
              fields.add(_makeField(
                "conversion_rate_at_65",
                "Taux de conversion à 65 ans",
                tdc,
                "TdC âge 65: $tdcStr",
                isPercentage: true,
                confidence: 0.85,
              ));
              existingNames.add("conversion_rate_at_65");
            }
          }
        }
      }
    }
  }

  // ── Phase 4: Prestation de sortie section ─────────────────

  /// Extract from the "Prestation de sortie" section found in CPE certificates.
  ///
  /// Format:
  ///   "Prestation de sortie au DD.MM.YYYY"
  ///   "Avoir de vieillesse         70'376.60"
  ///   "Montant minimum             66'526.15"
  ///   "Avoir de vieillesse LPP     30'243.80    Prestation de sortie    70'376.60"
  static void _extractPrestationDeSortie(
      String text, List<ExtractedField> fields, List<String> warnings) {
    final existingNames = fields.map((f) => f.fieldName).toSet();

    // Find the section (CPE: "Prestation de sortie au DD.MM.YYYY")
    final sectionPattern = RegExp(
        r"Prestation\s+de\s+sortie\s+au\s+\d{2}\.\d{2}\.\d{4}",
        caseSensitive: false);
    final sectionMatch = sectionPattern.firstMatch(text);

    // HOTELA fallback: "Prestation de sortie 19'620.30" (standalone line)
    if (sectionMatch == null) {
      if (!existingNames.contains("lpp_total")) {
        final standalonePattern = RegExp(
            r"Prestation\s+de\s+sortie\s+([\d'., ]+\.\d{2})",
            caseSensitive: false);
        final standaloneMatch = standalonePattern.firstMatch(text);
        if (standaloneMatch != null) {
          final value = _parseSwissNumber(standaloneMatch.group(1) ?? "");
          if (value != null && value > 100) {
            // Only use if no total found yet from Phase 1 regex
            if (!existingNames.contains("lpp_total")) {
              fields.add(_makeField(
                "lpp_total",
                "Avoir de vieillesse total",
                value,
                "Prestation de sortie: ${standaloneMatch.group(0)}",
                profileField: "avoirLppTotal",
                confidence: 0.90,
              ));
              existingNames.add("lpp_total");
            }
          }
        }
      }
      // Infer surobligatoire if we now have total and obligatoire
      _inferSurobligatoire(fields, existingNames);
      return;
    }

    final afterSection = text.substring(sectionMatch.end);
    // Limit to ~500 chars to avoid matching in other sections
    final sectionText =
        afterSection.substring(0, afterSection.length.clamp(0, 500));

    // "Avoir de vieillesse  70'376.60" (the total in this section)
    final avoirPattern = RegExp(
        r"Avoir\s+de\s+vieillesse\s+([\d'., ]+\.\d{2})",
        caseSensitive: false);
    final avoirMatch = avoirPattern.firstMatch(sectionText);

    if (avoirMatch != null && !existingNames.contains("lpp_total")) {
      final total = _parseSwissNumber(avoirMatch.group(1) ?? "");
      if (total != null && total > 1000) {
        fields.add(_makeField(
          "lpp_total",
          "Avoir de vieillesse total",
          total,
          "Prestation de sortie: ${avoirMatch.group(0)}",
          profileField: "avoirLppTotal",
          confidence: 0.92,
        ));
        existingNames.add("lpp_total");
      }
    }

    // "Avoir de vieillesse LPP  30'243.80" (the obligatoire part)
    final lppPattern = RegExp(
        r"Avoir\s+de\s+vieillesse\s+LPP\s+([\d'., ]+\.\d{2})",
        caseSensitive: false);
    final lppMatch = lppPattern.firstMatch(sectionText);

    if (lppMatch != null && !existingNames.contains("lpp_obligatoire")) {
      final oblig = _parseSwissNumber(lppMatch.group(1) ?? "");
      if (oblig != null && oblig > 0) {
        fields.add(_makeField(
          "lpp_obligatoire",
          "Part obligatoire (LPP)",
          oblig,
          "Prestation de sortie: ${lppMatch.group(0)}",
          profileField: "lppObligatoire",
          confidence: 0.92,
        ));
        existingNames.add("lpp_obligatoire");
      }
    }

    // "Prestation de sortie  70'376.60" (confirmation of total)
    final prestationPattern = RegExp(
        r"Prestation\s+de\s+sortie\s+([\d'., ]+\.\d{2})",
        caseSensitive: false);
    final prestationMatch = prestationPattern.firstMatch(sectionText);

    if (prestationMatch != null) {
      final sortie = _parseSwissNumber(prestationMatch.group(1) ?? "");
      final currentTotal = _findFieldValue(fields, "lpp_total");
      if (sortie != null && currentTotal != null) {
        final diff = (sortie - currentTotal).abs();
        if (diff > 1.0) {
          warnings.add(
            "La prestation de sortie (${sortie.toStringAsFixed(0)} CHF) diffère "
            "de l'avoir de vieillesse (${currentTotal.toStringAsFixed(0)} CHF). "
            "Écart: ${diff.toStringAsFixed(0)} CHF. Vérifie sur ton certificat.",
          );
        }
      }
    }

    // "Montant minimum  66'526.15"
    final minimumPattern = RegExp(
        r"Montant\s+minimum\s+([\d'., ]+\.\d{2})",
        caseSensitive: false);
    final minimumMatch = minimumPattern.firstMatch(sectionText);

    if (minimumMatch != null && !existingNames.contains("lpp_minimum")) {
      final minimum = _parseSwissNumber(minimumMatch.group(1) ?? "");
      if (minimum != null) {
        fields.add(_makeField(
          "lpp_minimum",
          "Montant minimum LPP",
          minimum,
          minimumMatch.group(0) ?? "",
          confidence: 0.90,
        ));
        existingNames.add("lpp_minimum");
      }
    }

    // Infer surobligatoire = total - obligatoire
    final total = _findFieldValue(fields, "lpp_total");
    final oblig = _findFieldValue(fields, "lpp_obligatoire");
    if (total != null &&
        oblig != null &&
        !existingNames.contains("lpp_surobligatoire")) {
      final suroblig = total - oblig;
      if (suroblig >= 0) {
        fields.add(_makeField(
          "lpp_surobligatoire",
          "Part surobligatoire (déduit)",
          suroblig,
          "Calculé: total ($total) - obligatoire ($oblig)",
          profileField: "lppSurobligatoire",
          confidence: 0.85,
          needsReview: true,
        ));
        existingNames.add("lpp_surobligatoire");
      }
    }
  }

  /// Infer surobligatoire = total - obligatoire when both are known.
  static void _inferSurobligatoire(
      List<ExtractedField> fields, Set<String> existingNames) {
    final total = _findFieldValue(fields, "lpp_total");
    final oblig = _findFieldValue(fields, "lpp_obligatoire");
    if (total != null &&
        oblig != null &&
        !existingNames.contains("lpp_surobligatoire")) {
      final suroblig = total - oblig;
      if (suroblig >= 0) {
        fields.add(_makeField(
          "lpp_surobligatoire",
          "Part surobligatoire (déduit)",
          suroblig,
          "Calculé: total ($total) - obligatoire ($oblig)",
          profileField: "lppSurobligatoire",
          confidence: 0.85,
          needsReview: true,
        ));
        existingNames.add("lpp_surobligatoire");
      }
    }
  }

  // ── Phase 5: Rachat extraction ────────────────────────────

  /// Extract buyback (rachat) amounts.
  ///
  /// CPE format:
  ///   "Rachat en vue de la retraite ordinaire à l'âge de 65 ans  539'413.70"
  ///   "Rachat en vue de la retraite anticipée à l'âge de 58...   703'066.90"
  static void _extractRachats(String text, List<ExtractedField> fields) {
    final existingNames = fields.map((f) => f.fieldName).toSet();

    // Rachat ordinaire (retraite à 65)
    if (!existingNames.contains("buyback_potential")) {
      final rachatPatterns = [
        // CPE: "Rachat en vue de la retraite ordinaire à l'âge de 65 ans 539'413.70"
        // Standard: "Rachat possible (montant maximum): CHF 45'000.00"
        RegExp(
            r"(?:rachat\s+en\s+vue\s+de\s+la\s+retraite\s+ordinaire|rachat\s+(?:possible|maximum|maximal)|lacune\s+de\s+rachat|montant\s+(?:de\s+)?rachat)\s*(?:\([^)]*\))?\s*(?:[àa]\s+l['']?[aâ]ge\s+de\s+\d+\s+ans?)?\s*[:\s]*" +
                numCapture,
            caseSensitive: false),
        // HOTELA: "Possibilités de rachat" section → "Montant maximum 52'948.55"
        RegExp(
            r"(?:Montant\s+maximum)\s*[:\s]*" + numCapture,
            caseSensitive: false),
        // German
        RegExp(
            r"(?:(?:M[oö]glicher?\s+)?Einkauf(?:spotential)?|Einkaufsm[oö]glichkeit)\s*[:\s]*([\d'., ]+(?:\.\d{2})?)",
            caseSensitive: false),
      ];

      for (final pattern in rachatPatterns) {
        final match = pattern.firstMatch(text);
        if (match != null && match.groupCount >= 1) {
          final value = _parseSwissNumber(match.group(1) ?? "");
          if (value != null && value > 100) {
            fields.add(_makeField(
              "buyback_potential",
              "Lacune de rachat (rachat possible)",
              value,
              match.group(0) ?? "",
              profileField: "buybackPotential",
              confidence: 0.90,
            ));
            existingNames.add("buyback_potential");
            break;
          }
        }
      }
    }

    // Rachat anticipé (retraite anticipée)
    if (!existingNames.contains("buyback_early_retirement")) {
      final earlyPattern = RegExp(
          r"(?:rachat\s+en\s+vue\s+de\s+la\s+retraite\s+anticip[eé]e)\s*(?:[àa]\s+l['']?[aâ]ge\s+de\s+\d+)?\s*(?:,\s*rente[\-\s]*pont\s+comprise)?\s*" +
              numCapture,
          caseSensitive: false);
      final match = earlyPattern.firstMatch(text);
      if (match != null) {
        final value = _parseSwissNumber(match.group(1) ?? "");
        if (value != null && value > 100) {
          fields.add(_makeField(
            "buyback_early_retirement",
            "Rachat retraite anticipée (rente-pont comprise)",
            value,
            match.group(0) ?? "",
            confidence: 0.88,
          ));
          existingNames.add("buyback_early_retirement");
        }
      }
    }
  }

  // ── Phase 6: Taux de rémunération ─────────────────────────

  /// Extract remuneration rate from "Intérêts (taux X.XX%)" format.
  ///
  /// CPE shows: "Intérêts (taux 5.00%)"
  /// Also: "rémunère les avoirs ... au taux de 5.00%"
  static void _extractTauxRemuneration(
      String text, List<ExtractedField> fields) {
    final existingNames = fields.map((f) => f.fieldName).toSet();
    if (existingNames.contains("remuneration_rate")) return;

    final patterns = [
      // "Intérêts (taux 5.00%)"
      RegExp(
          r"[Ii]nt[eé]r[eê]ts?\s*\(\s*taux\s+([\d,.\s]+\s*%?)\s*\)",
          caseSensitive: false),
      // "rémunère ... au taux de 5.00%"
      RegExp(
          r"r[eé]mun[eè]re\s+.*?(?:au\s+)?taux\s+(?:de\s+)?([\d,.\s]+\s*%?)",
          caseSensitive: false),
      // "taux de rémunération: 5.00%"
      RegExp(
          r"taux\s+(?:de\s+)?r[eé]mun[eé]ration\s*[:\s]*([\d,.\s]+\s*%?)",
          caseSensitive: false),
      // German
      RegExp(
          r"(?:Verzinsung|Zinssatz)\s*[:\s]*([\d,.\s]+\s*%?)",
          caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        final pct = _parsePercentage(match.group(1) ?? "");
        if (pct != null && pct >= 0.5 && pct <= 15.0) {
          fields.add(_makeField(
            "remuneration_rate",
            "Taux de rémunération",
            pct,
            match.group(0) ?? "",
            profileField: "rendementCaisse",
            isPercentage: true,
            confidence: 0.90,
          ));
          return;
        }
      }
    }
  }

  // ── Phase 7: Risk benefits (invalidité, décès) ────────────

  /// Extract disability and death benefits from real certificate labels.
  ///
  /// CPE format:
  ///   "Rente d'invalidité annuelle jusqu'à l'âge de 65 ans  2'388.00  55'188.00"
  ///   "Rente de conjoint/de partenaire annuelle              1'596.00  36'792.00"
  static void _extractRiskBenefits(String text, List<ExtractedField> fields) {
    final existingNames = fields.map((f) => f.fieldName).toSet();

    // ── Rente d'invalidité ──
    if (!existingNames.contains("disability_coverage")) {
      // Two-column: "Rente d'invalidité annuelle ... NUM1  NUM2"
      final invalidityTwoCol = RegExp(
          r"[Rr]ente\s+d['']invalidit[eé]\s+annuelle\s+.*?([\d'., ]+\.\d{2})\s+([\d'., ]+\.\d{2})",
          caseSensitive: false);
      final match2 = invalidityTwoCol.firstMatch(text);
      if (match2 != null) {
        final bonus = _parseSwissNumber(match2.group(1) ?? "");
        final base = _parseSwissNumber(match2.group(2) ?? "");
        if (bonus != null && base != null) {
          fields.add(_makeField(
            "disability_coverage",
            "Rente d'invalidité annuelle",
            bonus + base,
            match2.group(0) ?? "",
            profileField: "disabilityCoverage",
            confidence: 0.88,
          ));
          existingNames.add("disability_coverage");
        }
      }

      // Single-column fallback (HOTELA: "Rente annuelle d'invalidité 10'240.20")
      if (!existingNames.contains("disability_coverage")) {
        final invaliditySingle = RegExp(
            r"(?:rente?\s+(?:annuelle\s+)?d['']invalidit[eé]|prestation\s+d['']invalidit[eé])\s*[:\s]*" +
                numCapture,
            caseSensitive: false);
        final match1 = invaliditySingle.firstMatch(text);
        if (match1 != null) {
          final value = _parseSwissNumber(match1.group(1) ?? "");
          if (value != null && value > 100) {
            fields.add(_makeField(
              "disability_coverage",
              "Rente d'invalidité",
              value,
              match1.group(0) ?? "",
              profileField: "disabilityCoverage",
              confidence: 0.85,
            ));
            existingNames.add("disability_coverage");
          }
        }
      }
    }

    // ── Rente de conjoint / capital-décès ──
    if (!existingNames.contains("death_coverage")) {
      // Two-column: "Rente de conjoint/de partenaire annuelle  NUM1  NUM2"
      final deathTwoCol = RegExp(
          r"[Rr]ente\s+de\s+conjoint.*?annuelle\s+.*?([\d'., ]+\.\d{2})\s+([\d'., ]+\.\d{2})",
          caseSensitive: false);
      final match2 = deathTwoCol.firstMatch(text);
      if (match2 != null) {
        final bonus = _parseSwissNumber(match2.group(1) ?? "");
        final base = _parseSwissNumber(match2.group(2) ?? "");
        if (bonus != null && base != null) {
          fields.add(_makeField(
            "death_coverage",
            "Rente de conjoint annuelle",
            bonus + base,
            match2.group(0) ?? "",
            profileField: "deathCoverage",
            confidence: 0.88,
          ));
          existingNames.add("death_coverage");
        }
      }

      // Single-column: "Rente annuelle de partenaire 5'150.30" (HOTELA)
      if (!existingNames.contains("death_coverage")) {
        final partnerSingle = RegExp(
            r"(?:rente\s+annuelle\s+de\s+(?:partenaire|conjoint))\s*[:\s]*" +
                numCapture,
            caseSensitive: false);
        final matchPartner = partnerSingle.firstMatch(text);
        if (matchPartner != null) {
          final value = _parseSwissNumber(matchPartner.group(1) ?? "");
          if (value != null && value > 100) {
            fields.add(_makeField(
              "death_coverage",
              "Rente annuelle de partenaire",
              value,
              matchPartner.group(0) ?? "",
              profileField: "deathCoverage",
              confidence: 0.85,
            ));
            existingNames.add("death_coverage");
          }
        }
      }

      // Single-column fallback: capital-décès
      if (!existingNames.contains("death_coverage")) {
        final deathSingle = RegExp(
            r"(?:capital[\-\s]*d[eé]c[eè]s|prestation\s+de\s+d[eé]c[eè]s)\s*[:\s]*" +
                numCapture,
            caseSensitive: false);
        final match1 = deathSingle.firstMatch(text);
        if (match1 != null) {
          final value = _parseSwissNumber(match1.group(1) ?? "");
          if (value != null && value > 100) {
            fields.add(_makeField(
              "death_coverage",
              "Capital-décès",
              value,
              match1.group(0) ?? "",
              profileField: "deathCoverage",
              confidence: 0.85,
            ));
            existingNames.add("death_coverage");
          }
        }
      }
    }
  }

  // ── Phase 8: Cotisations ──────────────────────────────────

  /// Extract employee and employer contributions.
  ///
  /// CPE format has risque + épargne split across Bonus/Base columns.
  /// We sum all components per party (salarié / employeur).
  static void _extractCotisations(String text, List<ExtractedField> fields) {
    final existingNames = fields.map((f) => f.fieldName).toSet();

    // ── Employee contribution ──
    if (!existingNames.contains("employee_contribution")) {
      // Find "Cotisations du salarié" section and sum all lines
      final salarieSectionPattern = RegExp(
          r"Cotisations?\s+du\s+salari[eé]\s+par\s+an",
          caseSensitive: false);
      final salarieSectionMatch = salarieSectionPattern.firstMatch(text);

      if (salarieSectionMatch != null) {
        final afterSection = text.substring(salarieSectionMatch.end);
        // Sum all two-column lines until next section header
        final total = _sumSectionLines(afterSection);
        if (total > 0) {
          fields.add(_makeField(
            "employee_contribution",
            "Cotisation employé (annuelle)",
            total,
            "Section: Cotisations du salarié par an",
            profileField: "employeeLppContribution",
            confidence: 0.88,
          ));
          existingNames.add("employee_contribution");
        }
      }

      // Fallback: single-line pattern
      if (!existingNames.contains("employee_contribution")) {
        final pattern = RegExp(
            r"(?:cotisation\s+(?:de\s+l['']?)?employ[eé]e?|part\s+(?:de\s+l['']?)?employ[eé]e?)\s*(?:mensuelle|annuelle)?\s*[:\s]*" +
                numCapture,
            caseSensitive: false);
        final match = pattern.firstMatch(text);
        if (match != null) {
          final value = _parseSwissNumber(match.group(1) ?? "");
          if (value != null && value > 0) {
            fields.add(_makeField(
              "employee_contribution",
              "Cotisation employé",
              value,
              match.group(0) ?? "",
              profileField: "employeeLppContribution",
              confidence: 0.82,
            ));
            existingNames.add("employee_contribution");
          }
        }
      }
    }

    // ── Employer contribution ──
    if (!existingNames.contains("employer_contribution")) {
      final employeurSectionPattern = RegExp(
          r"Cotisations?\s+de\s+l['']employeur\s+par\s+an",
          caseSensitive: false);
      final employeurSectionMatch = employeurSectionPattern.firstMatch(text);

      if (employeurSectionMatch != null) {
        final afterSection = text.substring(employeurSectionMatch.end);
        final total = _sumSectionLines(afterSection);
        if (total > 0) {
          fields.add(_makeField(
            "employer_contribution",
            "Cotisation employeur (annuelle)",
            total,
            "Section: Cotisations de l'employeur par an",
            profileField: "employerLppContribution",
            confidence: 0.88,
          ));
          existingNames.add("employer_contribution");
        }
      }

      // Fallback: single-line pattern
      if (!existingNames.contains("employer_contribution")) {
        final pattern = RegExp(
            r"(?:cotisation\s+(?:de\s+l['']?)?employeur|part\s+(?:de\s+l['']?)?employeur)\s*(?:mensuelle|annuelle)?\s*[:\s]*" +
                numCapture,
            caseSensitive: false);
        final match = pattern.firstMatch(text);
        if (match != null) {
          final value = _parseSwissNumber(match.group(1) ?? "");
          if (value != null && value > 0) {
            fields.add(_makeField(
              "employer_contribution",
              "Cotisation employeur",
              value,
              match.group(0) ?? "",
              profileField: "employerLppContribution",
              confidence: 0.82,
            ));
            existingNames.add("employer_contribution");
          }
        }
      }
    }
  }

  /// Sum all two-column numeric lines in a section until the next section header.
  ///
  /// Used for cotisations sections where risque + épargne lines need summing.
  /// Returns total of (val1 + val2) for all matched lines.
  static double _sumSectionLines(String sectionText) {
    double total = 0;
    final lines = sectionText.split('\n');
    // Track how many value lines we've found to limit scope
    int valueLinesFound = 0;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Stop at known section boundaries
      if (trimmed.startsWith("Les cotisations")) break;
      if (trimmed.startsWith("Evolution de")) break;
      if (trimmed.startsWith("Prestation de")) break;
      if (trimmed.startsWith("Projection de")) break;
      if (trimmed.startsWith("Prestations en")) break;
      if (trimmed.startsWith("Rachats")) break;
      if (trimmed.startsWith("Informations")) break;
      // Next section header: "Cotisations de l'employeur par an" or "Cotisations du salarié par an"
      if (RegExp(r"^Cotisations?\s+(de\s+l|du\s+salari)", caseSensitive: false)
          .hasMatch(trimmed)) {
        break;
      }

      // Skip header lines like "Bonus Base"
      if (RegExp(r"^\s*Bonus\s+Base\s*$", caseSensitive: false)
          .hasMatch(trimmed)) {
        continue;
      }

      // Match two numbers at the end of the line (Bonus + Base)
      final twoNum = RegExp(
              r"([\d'., ]+\.\d{2})\s+([\d'., ]+\.\d{2})\s*$")
          .firstMatch(trimmed);
      if (twoNum != null) {
        final v1 = _parseSwissNumber(twoNum.group(1) ?? "");
        final v2 = _parseSwissNumber(twoNum.group(2) ?? "");
        if (v1 != null && v2 != null) {
          total += v1 + v2;
          valueLinesFound++;
        }
      }

      // Safety: don't sum more than 10 lines (avoid runaway parsing)
      if (valueLinesFound >= 10) break;
    }
    return total;
  }

  // ── Cross-validation ──────────────────────────────────────

  static void _crossValidate(
      List<ExtractedField> fields, List<String> warnings) {
    final total = _findFieldValue(fields, "lpp_total");
    final oblig = _findFieldValue(fields, "lpp_obligatoire");
    final suroblig = _findFieldValue(fields, "lpp_surobligatoire");

    if (total != null && oblig != null && suroblig != null) {
      final sum = oblig + suroblig;
      final diff = (total - sum).abs();
      final tolerance = total * 0.05;
      if (diff > tolerance) {
        warnings.add(
          "Attention\u00a0: la somme obligatoire (${oblig.toStringAsFixed(0)}) + surobligatoire "
          "(${suroblig.toStringAsFixed(0)}) = ${sum.toStringAsFixed(0)} ne correspond pas "
          "exactement au total (${total.toStringAsFixed(0)}). "
          "Écart\u00a0: ${diff.toStringAsFixed(0)} CHF. Vérifie les montants sur ton certificat.",
        );
      }
    } else if (total != null && oblig != null && suroblig == null) {
      // Infer surobligatoire
      final inferred = total - oblig;
      if (inferred >= 0) {
        fields.add(_makeField(
          "lpp_surobligatoire",
          "Part surobligatoire (déduit)",
          inferred,
          "Calculé: total - obligatoire",
          profileField: "lppSurobligatoire",
          confidence: 0.70,
          needsReview: true,
        ));
        warnings.add(
          "La part surobligatoire a été déduite (total - obligatoire = "
          "${inferred.toStringAsFixed(0)} CHF). Vérifie sur ton certificat.",
        );
      }
    }

    // Cross-validate conversion rate
    final convOblig = _findFieldValue(fields, "conversion_rate_oblig");
    if (convOblig != null && (convOblig < 5.0 || convOblig > 8.0)) {
      warnings.add(
        "Le taux de conversion obligatoire (${convOblig.toStringAsFixed(2)}%) "
        "semble inhabituel. Le minimum légal est 6.80% (LPP art. 14 al. 2). "
        "Vérifie sur ton certificat.",
      );
    }
  }

  // ── Field extraction helpers ──────────────────────────────

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
          confidence = (pct >= 1.0 && pct <= 25.0) ? 0.85 : 0.60;
        } else {
          final num = _parseSwissNumber(rawValue);
          if (num == null) continue;
          parsedValue = num;
          confidence = rawValue.contains(RegExp(r"[\d]")) ? 0.82 : 0.50;
          if (match.group(0)?.contains(RegExp(r"CHF|Fr\.")) ?? false) {
            confidence += 0.05;
          }
        }

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

  /// Create an ExtractedField with sensible defaults.
  static ExtractedField _makeField(
    String fieldName,
    String label,
    double value,
    String sourceText, {
    String? profileField,
    double confidence = 0.85,
    bool isPercentage = false,
    bool needsReview = false,
  }) {
    return ExtractedField(
      fieldName: fieldName,
      label: label,
      value: value,
      confidence: confidence.clamp(0.0, 0.95),
      sourceText: sourceText,
      needsReview: needsReview || confidence < 0.80,
      profileField: profileField,
    );
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

  static double _estimateConfidenceDeltaFromFields(
      List<ExtractedField> fields) {
    double delta = 0;
    final fieldNames = fields.map((f) => f.fieldName).toSet();

    if (fieldNames.contains("lpp_total")) delta += 5;
    if (fieldNames.contains("lpp_obligatoire")) delta += 4;
    if (fieldNames.contains("lpp_surobligatoire")) delta += 4;
    if (fieldNames.contains("conversion_rate_oblig")) delta += 2;
    if (fieldNames.contains("conversion_rate_suroblig")) delta += 2;
    if (fieldNames.contains("conversion_rate_at_65")) delta += 2;
    if (fieldNames.contains("buyback_potential")) delta += 3;
    if (fieldNames.contains("projected_rente")) delta += 2;
    if (fieldNames.contains("projected_capital_65")) delta += 2;
    if (fieldNames.contains("disability_coverage")) delta += 1;
    if (fieldNames.contains("death_coverage")) delta += 1;
    if (fieldNames.contains("employee_contribution")) delta += 1;
    if (fieldNames.contains("employer_contribution")) delta += 0.5;
    if (fieldNames.contains("lpp_insured_salary")) delta += 1;
    if (fieldNames.contains("lpp_determining_salary")) delta += 1;
    if (fieldNames.contains("epl_max")) delta += 0.5;

    return delta.clamp(0, 30);
  }

  /// Estimate confidence delta given an extraction result and the current
  /// user profile fields.
  static double estimateConfidenceDelta(
    ExtractionResult result,
    Map<String, dynamic> currentProfile,
  ) {
    double delta = 0;
    for (final field in result.fields) {
      final currentValue = currentProfile[field.profileField];
      if (currentValue == null || currentValue == 0) {
        delta += _fieldImpact(field.fieldName);
      } else {
        delta += _fieldImpact(field.fieldName) * 0.5;
      }
    }
    return delta.clamp(0, 30);
  }

  static double _fieldImpact(String fieldName) {
    const impacts = {
      "lpp_total": 5.0,
      "lpp_obligatoire": 4.0,
      "lpp_surobligatoire": 4.0,
      "conversion_rate_oblig": 2.0,
      "conversion_rate_suroblig": 2.0,
      "conversion_rate_at_65": 2.0,
      "buyback_potential": 3.0,
      "buyback_early_retirement": 1.0,
      "projected_rente": 2.0,
      "projected_capital_65": 2.0,
      "disability_coverage": 1.0,
      "death_coverage": 1.0,
      "employee_contribution": 1.0,
      "employer_contribution": 0.5,
      "lpp_insured_salary": 1.0,
      "lpp_determining_salary": 1.0,
      "lpp_bonification_rate": 1.5,
      "epl_max": 0.5,
      "lpp_minimum": 0.5,
    };
    return impacts[fieldName] ?? 1.0;
  }

  // ── Sample OCR text — real CPE certificate format ─────────

  /// Sample OCR text based on a real Swiss CPE certificate (golden test).
  /// Used for the prototype "Simuler un scan" button.
  static const String sampleOcrText = """
CPE Caisse de Pension Energie

Certificat de prévoyance au 08.03.2026 établi le 08.03.2026

Données personnelles
Employeur FMV SA
Numéro AVS 756.6979.9560.43 Date de naissance 12.01.1977
Etat civil Marié Taux d'occupation 100.00%
Entrée au 01.04.2024 Epargne volontaire Maxi

Données salariales Bonus Base
Salaire déterminant 0.00 122'206.80
Salaire assuré / salaire de risque 3'974.40 91'967.00
Salaire assuré / salaire d'épargne 0.00 91'967.00

Cotisations du salarié par an Bonus Base
Cotisation de risque 4.20 91.80
Cotisation d'épargne 0.00 13'868.40

Cotisations de l'employeur par an Bonus Base
Cotisation de risque 6.00 138.00
Cotisation d'épargne 0.00 15'276.00

Les cotisations sont prélevées mensuellement.

Evolution de l'avoir de vieillesse Bonus Base
Avoir de vieillesse au 01.01.2026 847.45 59'320.10
Versements 0.00 5'004.20
Prélèvements 0.00 0.00
Intérêts (taux 5.00%) 7.90 598.55
Cotisations d'épargne 0.00 4'598.40
Avoir de vieillesse au 08.03.2026 855.35 69'521.25

Prestation de sortie au 08.03.2026
Avoir de vieillesse 70'376.60
Montant minimum 66'526.15
Avoir de vieillesse LPP 30'243.80 Prestation de sortie 70'376.60

Projection de l'avoir de vieillesse Bonus Base
âge 58 1'044.00 376'930.00
âge 59 1'065.00 417'246.00
âge 60 1'086.00 458'368.00
âge 61 1'108.00 500'312.00
âge 62 1'130.00 543'095.00
âge 63 1'153.00 586'733.00
âge 64 1'176.00 631'245.00
âge 65 1'200.00 676'647.00

Projection de la rente de vieillesse annuelle TdC* Bonus Base
âge 58 4.21% 44.00 15'869.00
âge 59 4.31% 46.00 17'983.00
âge 60 4.41% 48.00 20'214.00
âge 61 4.52% 50.00 22'614.00
âge 62 4.63% 52.00 25'145.00
âge 63 4.75% 55.00 27'870.00
âge 64 4.87% 57.00 30'742.00
âge 65 5.00% 60.00 33'832.00

Prestations en cas d'incapacité de gain Bonus Base
Rente d'invalidité annuelle jusqu'à l'âge de 65 ans 2'388.00 55'188.00
Rente d'enfant d'invalide annuelle par enfant 480.00 11'040.00

Prestations en cas de décès Bonus Base
Rente de conjoint/de partenaire annuelle 1'596.00 36'792.00
Rente d'orphelin annuelle par enfant 480.00 11'040.00

Rachats possibles
Rachat en vue de la retraite ordinaire à l'âge de 65 ans 539'413.70
Rachat en vue de la retraite anticipée à l'âge de 58, rente-pont comprise 703'066.90

Informations complémentaires
Somme maximale disponible pour l'encouragement à la propriété du logement 60'075.25
Prestation de libre passage au moment du mariage 0.00
""";
}

// ── Private field pattern class ─────────────────────────────

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
