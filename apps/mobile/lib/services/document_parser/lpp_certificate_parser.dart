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
const String _numCapture = r"(-?\s*[CHFfr.\s]*\d[\d\s'’.,]*)";

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
    var cleaned = text
        .replaceAll(RegExp(r"CHF\s*", caseSensitive: false), "")
        .replaceAll(RegExp(r"Fr\.\s*", caseSensitive: false), "")
        .replaceAll("\u2019", "'")
        .replaceAll("\u00A0", " ")
        .trim();
    if (!RegExp(r"^-?\s*\d[\d\s'.,]*$").hasMatch(cleaned)) return null;

    var sign = '';
    if (cleaned.startsWith('-')) {
      sign = '-';
      cleaned = cleaned.substring(1).trim();
    }
    final dot = cleaned.lastIndexOf('.');
    final comma = cleaned.lastIndexOf(',');
    String integerPart;
    String? fractionPart;

    if (dot >= 0 && comma >= 0) {
      final decimalIndex = dot > comma ? dot : comma;
      final decimalSeparator = cleaned[decimalIndex];
      final groupingSeparator = decimalSeparator == '.' ? ',' : '.';
      integerPart = cleaned.substring(0, decimalIndex);
      fractionPart = cleaned.substring(decimalIndex + 1);
      if (fractionPart.isEmpty || fractionPart.length > 2) return null;
      if (integerPart.contains(decimalSeparator) ||
          !_validGroupedInteger(integerPart, groupingSeparator)) {
        return null;
      }
    } else {
      final separator = dot >= 0 ? '.' : (comma >= 0 ? ',' : null);
      if (separator == null) {
        integerPart = cleaned;
      } else {
        final parts = cleaned.split(separator);
        if (parts.length == 2 &&
            parts.last.isNotEmpty &&
            parts.last.length <= 2) {
          integerPart = parts.first;
          fractionPart = parts.last;
        } else if (parts.length >= 2 &&
            parts.first.isNotEmpty &&
            parts.skip(1).every((part) => part.length == 3)) {
          integerPart = cleaned;
        } else {
          return null;
        }
        if (!_validGroupedInteger(integerPart, separator)) return null;
      }
    }

    if (!_validGroupedInteger(integerPart, null)) return null;
    final digits = integerPart.replaceAll(RegExp(r"[\s'.,]"), '');
    final normalized =
        '$sign$digits${fractionPart == null ? '' : '.$fractionPart'}';
    return double.tryParse(normalized);
  }

  static bool _validGroupedInteger(String value, String? decimalGrouping) {
    var normalized = value.trim();
    if (normalized.isEmpty) return false;
    final separators = <String>{
      if (normalized.contains("'")) "'",
      if (normalized.contains(' ')) ' ',
      if (normalized.contains('.')) '.',
      if (normalized.contains(',')) ',',
    };
    if (decimalGrouping != null &&
        (normalized.contains('.') || normalized.contains(',')) &&
        !normalized.contains(decimalGrouping)) {
      return false;
    }
    if (separators.isEmpty) return RegExp(r"^\d+$").hasMatch(normalized);
    if (separators.length != 1) return false;
    final separator = separators.single;
    final parts = normalized.split(separator);
    return parts.first.isNotEmpty &&
        parts.first.length <= 3 &&
        parts.every((part) => RegExp(r"^\d+$").hasMatch(part)) &&
        parts.skip(1).every((part) => part.length == 3);
  }

  /// Parse a percentage: "6.80%", "6,80 %", "0.068".
  static double? _parsePercentage(String text) {
    if (!text.contains('%')) return null;
    var cleaned = text.replaceAll("%", "").trim();
    cleaned = cleaned.replaceAll(",", ".");
    cleaned = cleaned.replaceAll(RegExp(r"[^\d.\-]"), "");
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null) return null;
    return value;
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
            r"(?:avoir\s+de\s+vieillesse\s+total|total\s+avoir)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Altersguthaben\s+(?:total|gesamt)|Alterskapital\s+(?:total|gesamt))\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        RegExp(r"(?:Total\s+(?:des\s+)?avoirs?)\s*[:\s]*" + _numCapture,
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
      label: "Salaire assuré",
      profileField: "lppInsuredSalary",
      patterns: [
        RegExp(
            r"(?:salaire\s+(?:coordonn[e\u00e9]|assur[e\u00e9](?:\s+(?:total|global))?)|traitement\s+assur[e\u00e9](?:\s+(?:total|global))?)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Versicherter\s+(?:Lohn|Verdienst)(?:\s+(?:total|gesamt))?|Koordinierter\s+Lohn)\s*[:\s]*" +
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
                _numCapture +
                r"\s*(?:/\s*(?:an|ann[e\u00e9]e)|par\s+(?:an|ann[e\u00e9]e))",
            caseSensitive: false),
        RegExp(
            r"(?:Voraussichtliche\s+Altersrente|Altersrente\s+(?:ab|mit)\s+65)\s*[:\s]*" +
                _numCapture +
                r"\s*(?:/\s*Jahr|pro\s+Jahr|j[a\u00e4]hrlich)",
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

    // ── Capital invalidite (versement unique) ──
    _FieldPattern(
      fieldName: "disability_capital",
      label: "Disability capital",
      profileField: "lppDisabilityCapital",
      patterns: [
        RegExp(
            r"(?:capital\s+(?:d[' ]?)?invalidit[e\u00e9](?:\s*\([^)]*(?:versement\s+unique|capital)[^)]*\))?)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        RegExp(r"(?:Invalidit[a\u00e4]tskapital)\s*[:\s]*" + _numCapture,
            caseSensitive: false),
      ],
    ),

    // ── Rente d'invalidite annuelle ──
    _FieldPattern(
      fieldName: "disability_coverage",
      label: "Annual disability pension",
      profileField: "disabilityCoverage",
      patterns: [
        RegExp(
            r"(?:rente\s+d[' ]?invalidit[e\u00e9]\s+annuelle|rente\s+annuelle\s+d[' ]?invalidit[e\u00e9]|invalidit[e\u00e9]\s+rente\s+annuelle)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        RegExp(
            r"(?:rente\s+d[' ]?invalidit[e\u00e9]|invalidit[e\u00e9]\s+rente)\s*[:\s]*" +
                _numCapture +
                r"\s*(?:/\s*(?:an|ann[e\u00e9]e)|par\s+(?:an|ann[e\u00e9]e))",
            caseSensitive: false),
        RegExp(
            r"(?:prestation\s+d[' ]?invalidit[e\u00e9])\s*[:\s]*" +
                _numCapture +
                r"\s*(?:/\s*(?:an|ann[e\u00e9]e)|par\s+(?:an|ann[e\u00e9]e))",
            caseSensitive: false),
        RegExp(
            r"(?:Invalidenrente|Rente\s+bei\s+Invalidit[a\u00e4]t)\s*[:\s]*" +
                _numCapture +
                r"\s*(?:/\s*Jahr|pro\s+Jahr|j[a\u00e4]hrlich)",
            caseSensitive: false),
      ],
    ),

    // ── Prestation de deces ──
    _FieldPattern(
      fieldName: "death_coverage",
      label: "Prestation de décès",
      profileField: "deathCoverage",
      patterns: [
        RegExp(
            r"(?:capital[\-\s]*d[e\u00e9]c[e\u00e8]s)\s*[:\s]*" + _numCapture,
            caseSensitive: false),
        RegExp(r"(?:Todesfallkapital)\s*[:\s]*" + _numCapture,
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
            r"(?:rachat?\s+(?:possible|maximum|maximal)(?:\s+(?:ordinaire|courant))?|lacune\s+de\s+rachat|montant\s+(?:de\s+)?rachat)(?:\s*\([^)]*\))?\s*[:\s]*" +
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
      label: "Cotisation employé (mensuelle)",
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
        RegExp(r"taux\s+(?:de\s+)?r[ée]mun[ée]ration\s*[:\s]*([\d,.\s]+\s*%?)",
            caseSensitive: false),
        RegExp(r"(?:Verzinsung|Zinssatz)\s*[:\s]*([\d,.\s]+\s*%?)",
            caseSensitive: false),
        RegExp(r"tasso\s+(?:di\s+)?remunerazione\s*[:\s]*([\d,.\s]+\s*%?)",
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
    final documentText = _hasPersonalCertificateKind(text) ? text : '';

    for (final pattern in _knownFieldPatterns) {
      final result = _extractField(documentText, pattern);
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

  static bool _hasPersonalCertificateKind(String text) {
    final normalized = _normalizedSemanticText(text);
    final hasPersonalTitle = normalized.contains(
            'certificat de prevoyance') || // lint-ignore: LPP document-type lexeme, not UI copy
        normalized.contains('vorsorgeausweis') ||
        normalized.contains('vorsorgebescheinigung') ||
        normalized.contains('certificato di previdenza');
    final hasIndividualizationLabel = RegExp(
      r'(?:personne\s+assuree?|(?:^|\n)\s*assure(?:\(e\))?\s*:|n(?:o|°)\.?\s*(?:(?:d[\x27’]\s*)?assure|avs)|numero\s+(?:assure|avs)|nom\s*[-/]\s*prenom|versicherte\s+person|personalnummer|name\s*[-/]\s*vorname|persona\s+assicurata|numero\s+assicurato)',
      multiLine: true,
    ).hasMatch(normalized);
    return hasPersonalTitle && hasIndividualizationLabel;
  }

  /// Extract a single field from OCR text using pattern matching.
  static ExtractedField? _extractField(String text, _FieldPattern pattern) {
    if (pattern.fieldName == 'lpp_insured_salary') {
      return _extractUnambiguousInsuredSalary(text, pattern);
    }
    if (pattern.fieldName == 'buyback_potential') {
      return _extractOrdinaryBuyback(text, pattern);
    }
    for (final regex in pattern.patterns) {
      final match = regex.firstMatch(text);
      final field = _fieldFromMatch(pattern, match);
      if (field != null) return field;
    }
    return null;
  }

  static ExtractedField? _extractUnambiguousInsuredSalary(
    String text,
    _FieldPattern pattern,
  ) {
    final candidates = <({ExtractedField field, bool explicitCanonical})>[];
    for (final line in text.split(RegExp(r'[\r\n]+'))) {
      if (line.trim().isEmpty) continue;
      ExtractedField? field;
      for (final regex in pattern.patterns) {
        field = _fieldFromMatch(pattern, regex.firstMatch(line), line.trim());
        if (field != null) break;
      }
      if (field == null) continue;
      final normalized = _normalizedSemanticText(line);
      final hasSubtype = normalized.contains('risque') ||
          normalized.contains('risk') ||
          normalized.contains('epargne') ||
          normalized.contains('savings') ||
          normalized.contains('sparlohn');
      if (hasSubtype) continue;
      final explicitCanonical = normalized.contains('coordonn') ||
          normalized.contains('koordiniert') ||
          normalized.contains('total') ||
          normalized.contains('global') ||
          normalized.contains('gesamt');
      candidates.add((field: field, explicitCanonical: explicitCanonical));
    }
    if (candidates.length == 1) return candidates.single.field;
    final explicit = candidates
        .where((candidate) => candidate.explicitCanonical)
        .toList(growable: false);
    return explicit.length == 1 ? explicit.single.field : null;
  }

  static ExtractedField? _extractOrdinaryBuyback(
    String text,
    _FieldPattern pattern,
  ) {
    final lines = text.split(RegExp(r'[\r\n]+'));
    final candidates = <ExtractedField>[];
    String? previousNonEmpty;
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final heading =
          previousNonEmpty != null && !RegExp(r'\d').hasMatch(previousNonEmpty)
              ? previousNonEmpty
              : null;
      final context = heading == null ? line : '$heading\n$line';
      for (final regex in pattern.patterns) {
        final field = _fieldFromMatch(
          pattern,
          regex.firstMatch(line),
          context,
        );
        if (field == null) continue;
        if (!_isEarlyRetirementContext(context)) candidates.add(field);
        break;
      }
      previousNonEmpty = line;
    }
    return candidates.length == 1 ? candidates.single : null;
  }

  static ExtractedField? _fieldFromMatch(
    _FieldPattern pattern,
    RegExpMatch? match, [
    String? sourceText,
  ]) {
    if (match == null || match.groupCount < 1) return null;
    final rawValue = match.group(1)?.trim() ?? '';
    final dynamic parsedValue;
    double confidence;
    if (pattern.isPercentage) {
      final pct = _parsePercentage(rawValue);
      if (pct == null) return null;
      parsedValue = pct;
      confidence = (pct >= 1.0 && pct <= 25.0) ? 0.85 : 0.60;
    } else {
      final number = _parseSwissNumber(rawValue);
      if (number == null) return null;
      parsedValue = number;
      confidence = rawValue.contains(RegExp(r'[\d]')) ? 0.82 : 0.50;
      if (match.group(0)?.contains(RegExp(r'CHF|Fr\.')) ?? false) {
        confidence += 0.05;
      }
    }
    confidence = confidence.clamp(0.0, 0.95);
    return ExtractedField(
      fieldName: pattern.fieldName,
      label: pattern.label,
      value: parsedValue,
      confidence: confidence,
      sourceText: sourceText ?? match.group(0) ?? '',
      needsReview: confidence < 0.80,
      profileField: pattern.profileField,
    );
  }

  static bool _isEarlyRetirementContext(String value) {
    final normalized = _normalizedSemanticText(value);
    return normalized.contains('anticip') ||
        normalized.contains('bridge') ||
        normalized.contains('pont') ||
        normalized.contains('fruhpensionierung') ||
        normalized.contains('vorzeitig') ||
        normalized.contains('vorbezug');
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
