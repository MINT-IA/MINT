// ────────────────────────────────────────────────────────────
//  SALARY CERTIFICATE PARSER — Sprint S45
// ────────────────────────────────────────────────────────────
//
//  Extracts structured fields from OCR text of a Swiss
//  salary slip (fiche de salaire / Lohnausweis).
//
//  Handles both French and German payslip formats.
//  Parses Swiss number formatting (CHF 7'083.35).
//
//  Extracted fields:
//    - Salaire brut mensuel (base)
//    - 13ème salaire (prorata or annual)
//    - Bonus / gratification
//    - Taux d'activité
//    - Cotisations AVS/AI/APG
//    - Cotisation AC (chômage)
//    - Cotisation LPP employé·e
//    - AANP (accident non professionnel)
//    - IJM (indemnité journalière maladie)
//    - Allocations familiales
//    - Salaire net versé
//    - Employeur
//
//  Confidence boost: +20 points.
//
//  Reference:
//    - LAVS art. 5 (cotisations salariales)
//    - LPP art. 66 (parité cotisations)
//    - LACI art. 3 (cotisation chômage)
// ────────────────────────────────────────────────────────────

import 'package:mint_mobile/services/document_parser/document_models.dart';

// Reusable regex fragment: Swiss number capture group
const String _numCapture = "([CHFfr.\\s]*[\\d\\s'.,\u2019]+)";

/// Service for parsing salary certificate OCR text into structured fields.
///
/// All logic is pure Dart, no network calls.
/// On-device OCR: document never leaves phone (LPD compliance).
class SalaryCertificateParser {
  SalaryCertificateParser._();

  /// Confidence boost for salary certificate scan.
  static const int confidenceImpact = 20;

  // ── Swiss number parsing ──────────────────────────────────

  static double? _parseSwissNumber(String text) {
    var cleaned = text
        .replaceAll(RegExp(r"CHF\s*", caseSensitive: false), "")
        .replaceAll(RegExp(r"Fr\.\s*", caseSensitive: false), "")
        .trim();

    cleaned = cleaned.replaceAll("'", "");
    cleaned = cleaned.replaceAll("\u2019", "");
    cleaned = cleaned.replaceAll("\u00A0", "");
    cleaned = cleaned.replaceAll(RegExp(r"(\d)\s+(\d)"), r"$1$2");

    if (cleaned.contains(",") && !cleaned.contains(".")) {
      final lastComma = cleaned.lastIndexOf(",");
      final afterComma = cleaned.substring(lastComma + 1);
      if (afterComma.length <= 2) {
        cleaned = "${cleaned.substring(0, lastComma)}.$afterComma";
      } else {
        cleaned = cleaned.replaceAll(",", "");
      }
    }

    cleaned = cleaned.replaceAll(RegExp(r"[^\d.\-]"), "");
    if (cleaned.isEmpty) return null;

    return double.tryParse(cleaned);
  }

  static double? _parsePercentage(String text) {
    final cleaned = text.replaceAll("%", "").trim();
    final value = _parseSwissNumber(cleaned);
    if (value == null) return null;
    return value > 1 ? value : value * 100;
  }

  // ── Field patterns ──────────────────────────────────────

  static final _patterns = <_FieldDef>[
    _FieldDef(
      fieldName: 'salaire_brut',
      label: 'Salaire brut mensuel',
      profileField: 'salaireBrutMensuel',
      patterns: [
        RegExp(r"salaire\s+(?:de\s+)?base\s*:?\s*" + _numCapture, caseSensitive: false),
        RegExp(r"brut(?:to)?\s*(?:mensuel|monatl)?\s*:?\s*" + _numCapture, caseSensitive: false),
        RegExp(r"grundlohn\s*:?\s*" + _numCapture, caseSensitive: false),
        RegExp(r"monatslohn\s*:?\s*" + _numCapture, caseSensitive: false),
      ],
    ),
    _FieldDef(
      fieldName: 'treizieme_salaire',
      label: '13ème salaire',
      profileField: null,
      patterns: [
        RegExp(r"13[eè]me\s+salaire\s*:?\s*" + _numCapture, caseSensitive: false),
        RegExp(r"gratification\s+annuelle\s*:?\s*" + _numCapture, caseSensitive: false),
        RegExp(r"13\.?\s*monatslohn\s*:?\s*" + _numCapture, caseSensitive: false),
      ],
    ),
    _FieldDef(
      fieldName: 'bonus',
      label: 'Bonus / gratification',
      profileField: null,
      patterns: [
        RegExp(r"bonus\s*:?\s*" + _numCapture, caseSensitive: false),
        RegExp(r"prime\s*(?:de\s+performance)?\s*:?\s*" + _numCapture, caseSensitive: false),
        RegExp(r"gratifikation\s*:?\s*" + _numCapture, caseSensitive: false),
      ],
    ),
    _FieldDef(
      fieldName: 'taux_activite',
      label: 'Taux d\'activité',
      profileField: 'tauxActivite',
      isPercentage: true,
      patterns: [
        RegExp(r"taux\s+(?:d[''e]\s*)?activit[ée]\s*:?\s*([\d.,]+)\s*%?", caseSensitive: false),
        RegExp(r"besch[äa]ftigungsgrad\s*:?\s*([\d.,]+)\s*%?", caseSensitive: false),
        RegExp(r"pensum\s*:?\s*([\d.,]+)\s*%?", caseSensitive: false),
      ],
    ),
    _FieldDef(
      fieldName: 'cotisation_avs',
      label: 'Cotisation AVS/AI/APG',
      profileField: null,
      patterns: [
        RegExp(r"AVS\s*[/+]\s*AI\s*[/+]\s*APG\s*:?\s*-?\s*" + _numCapture, caseSensitive: false),
        RegExp(r"AHV\s*[/+]\s*IV\s*[/+]\s*EO\s*:?\s*-?\s*" + _numCapture, caseSensitive: false),
      ],
    ),
    _FieldDef(
      fieldName: 'cotisation_ac',
      label: 'Cotisation AC (chômage)',
      profileField: null,
      patterns: [
        RegExp(r"AC\s*(?:\(ch[ôo]mage\))?\s*:?\s*-?\s*" + _numCapture, caseSensitive: false),
        RegExp(r"ALV\s*:?\s*-?\s*" + _numCapture, caseSensitive: false),
      ],
    ),
    _FieldDef(
      fieldName: 'cotisation_lpp',
      label: 'Cotisation LPP employé·e',
      profileField: 'cotisationLppEmploye',
      patterns: [
        RegExp(r"LPP\s*(?:employ[ée](?:[·.]?e)?)?\s*:?\s*-?\s*" + _numCapture, caseSensitive: false),
        RegExp(r"BVG\s*(?:Arbeitnehmer)?\s*:?\s*-?\s*" + _numCapture, caseSensitive: false),
        RegExp(r"pr[ée]voyance\s+prof(?:essionnelle)?\s*:?\s*-?\s*" + _numCapture, caseSensitive: false),
        RegExp(r"2[eè]me\s+pilier\s*:?\s*-?\s*" + _numCapture, caseSensitive: false),
      ],
    ),
    _FieldDef(
      fieldName: 'aanp',
      label: 'AANP (accident non prof.)',
      profileField: null,
      patterns: [
        RegExp(r"AANP\s*:?\s*-?\s*" + _numCapture, caseSensitive: false),
        RegExp(r"accident\s+non\s+prof(?:essionnel)?\s*:?\s*-?\s*" + _numCapture, caseSensitive: false),
        RegExp(r"NBU\s*:?\s*-?\s*" + _numCapture, caseSensitive: false),
      ],
    ),
    _FieldDef(
      fieldName: 'ijm',
      label: 'IJM (maladie)',
      profileField: null,
      patterns: [
        RegExp(r"IJM\s*:?\s*-?\s*" + _numCapture, caseSensitive: false),
        RegExp(r"indemnit[ée]\s+journali[èe]re\s*(?:maladie)?\s*:?\s*-?\s*" + _numCapture, caseSensitive: false),
        RegExp(r"KTG\s*:?\s*-?\s*" + _numCapture, caseSensitive: false),
      ],
    ),
    _FieldDef(
      fieldName: 'allocations_familiales',
      label: 'Allocations familiales',
      profileField: null,
      patterns: [
        RegExp(r"alloc(?:ation)?s?\s+famili(?:ales|ères)\s*:?\s*" + _numCapture, caseSensitive: false),
        RegExp(r"Familienzulage(?:n)?\s*:?\s*" + _numCapture, caseSensitive: false),
        RegExp(r"Kinderzulage(?:n)?\s*:?\s*" + _numCapture, caseSensitive: false),
      ],
    ),
    _FieldDef(
      fieldName: 'salaire_net',
      label: 'Salaire net versé',
      profileField: null,
      patterns: [
        RegExp(r"(?:salaire\s+)?net\s+(?:vers[ée]|pay[ée]|à\s+payer)\s*:?\s*" + _numCapture, caseSensitive: false),
        RegExp(r"net(?:to)?\s*(?:lohn|auszahlung)\s*:?\s*" + _numCapture, caseSensitive: false),
        RegExp(r"virement\s*:?\s*" + _numCapture, caseSensitive: false),
      ],
    ),
    _FieldDef(
      fieldName: 'impot_source',
      label: 'Impôt à la source',
      profileField: null,
      patterns: [
        RegExp(r"imp[ôo]t\s+(?:[àa]\s+la\s+)?source\s*:?\s*-?\s*" + _numCapture, caseSensitive: false),
        RegExp(r"Quellensteuer\s*:?\s*-?\s*" + _numCapture, caseSensitive: false),
      ],
    ),
  ];

  // ── Employer extraction ──────────────────────────────────

  static String? _extractEmployer(String ocrText) {
    final lines = ocrText.split('\n').take(10).toList();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      // Skip lines that look like dates, amounts, or short labels
      if (RegExp(r'^\d{2}[./]\d{2}[./]\d{4}').hasMatch(trimmed)) continue;
      if (RegExp(r'^CHF\s').hasMatch(trimmed)) continue;
      if (trimmed.length < 3) continue;
      // Company names often contain SA, Sàrl, AG, GmbH
      if (RegExp(r'\b(SA|S[àa]rl|AG|GmbH|Sàrl|Ltd|Inc)\b', caseSensitive: false)
          .hasMatch(trimmed)) {
        return trimmed;
      }
    }
    // Fallback: first non-empty line
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && trimmed.length > 5) return trimmed;
    }
    return null;
  }

  // ── Main parse method ──────────────────────────────────

  /// Parse salary certificate OCR text and extract structured fields.
  ///
  /// Returns an [ExtractionResult] with all identified fields,
  /// confidence scores, and compliance warnings.
  static ExtractionResult parse(String ocrText) {
    final fields = <ExtractedField>[];
    final warnings = <String>[];

    // Try each field pattern
    for (final def in _patterns) {
      ExtractedField? bestMatch;
      double bestConfidence = 0;

      for (final pattern in def.patterns) {
        final match = pattern.firstMatch(ocrText);
        if (match == null) continue;

        final rawText = match.group(1) ?? match.group(0) ?? '';
        final value = def.isPercentage
            ? _parsePercentage(rawText)
            : _parseSwissNumber(rawText);

        if (value == null || value <= 0) continue;

        // Confidence based on pattern specificity
        final confidence = pattern.pattern.length > 30 ? 0.90 : 0.75;
        if (confidence > bestConfidence) {
          bestConfidence = confidence;
          bestMatch = ExtractedField(
            fieldName: def.fieldName,
            label: def.label,
            value: value,
            confidence: confidence,
            sourceText: rawText.trim(),
            needsReview: confidence < 0.80,
            profileField: def.profileField,
          );
        }
      }

      if (bestMatch != null) {
        fields.add(bestMatch);
      }
    }

    // Extract employer name (heuristic)
    final employer = _extractEmployer(ocrText);
    if (employer != null) {
      fields.add(ExtractedField(
        fieldName: 'employeur',
        label: 'Employeur',
        value: employer,
        confidence: 0.60,
        sourceText: employer,
        needsReview: true,
        profileField: 'employeur',
      ));
    }

    // ── Cross-validation ──

    final brut = _fieldValue(fields, 'salaire_brut');
    final net = _fieldValue(fields, 'salaire_net');
    final avs = _fieldValue(fields, 'cotisation_avs');
    final ac = _fieldValue(fields, 'cotisation_ac');
    final lpp = _fieldValue(fields, 'cotisation_lpp');
    final aanp = _fieldValue(fields, 'aanp');
    final ijm = _fieldValue(fields, 'ijm');
    final impotSource = _fieldValue(fields, 'impot_source');
    final allocs = _fieldValue(fields, 'allocations_familiales');

    if (brut != null && net != null) {
      final totalDeductions = (avs ?? 0) + (ac ?? 0) + (lpp ?? 0) +
          (aanp ?? 0) + (ijm ?? 0) + (impotSource ?? 0);
      final expectedNet = brut - totalDeductions + (allocs ?? 0);
      final delta = (expectedNet - net).abs();
      if (delta > brut * 0.05) {
        warnings.add(
          'Le net calculé (${expectedNet.toStringAsFixed(0)}) diffère du '
          'net lu (${net.toStringAsFixed(0)}) de ${delta.toStringAsFixed(0)} CHF. '
          'Vérifie les déductions.',
        );
      }
    }

    // Activity rate sanity check
    final tauxActivite = _fieldValue(fields, 'taux_activite');
    if (tauxActivite != null && (tauxActivite < 10 || tauxActivite > 100)) {
      warnings.add(
        'Taux d\'activité de ${tauxActivite.toStringAsFixed(0)}% semble '
        'inhabituel. Vérifie cette valeur.',
      );
    }

    // Overall confidence
    final overallConfidence = fields.isEmpty
        ? 0.0
        : fields.map((f) => f.confidence).reduce((a, b) => a + b) /
            fields.length;

    return ExtractionResult(
      documentType: DocumentType.salaryCertificate,
      fields: fields,
      overallConfidence: overallConfidence,
      confidenceDelta: confidenceImpact.toDouble(),
      warnings: warnings,
      disclaimer:
          'Extraction automatique de la fiche de salaire. '
          'Les montants doivent être vérifiés par l\'utilisateur. '
          'Outil éducatif — ne constitue pas un conseil (LSFin).',
      sources: [
        'LAVS art. 5 (cotisations salariales)',
        'LPP art. 66 (parité cotisations)',
        'LACI art. 3 (cotisation chômage)',
      ],
    );
  }

  static double? _fieldValue(List<ExtractedField> fields, String name) {
    try {
      final field = fields.firstWhere((f) => f.fieldName == name);
      return field.value is num ? (field.value as num).toDouble() : null;
    } catch (_) {
      return null;
    }
  }
}

/// Internal field definition for pattern matching.
class _FieldDef {
  final String fieldName;
  final String label;
  final String? profileField;
  final List<RegExp> patterns;
  final bool isPercentage;

  const _FieldDef({
    required this.fieldName,
    required this.label,
    required this.patterns,
    this.profileField,
    this.isPercentage = false,
  });
}
