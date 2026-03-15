// ────────────────────────────────────────────────────────────
//  SLM EXTRACTION SERVICE — On-device AI document enhancement
// ────────────────────────────────────────────────────────────
//
//  Uses Gemma 3n (on-device SLM) to extract financial fields
//  that the regex parser missed. Runs AFTER regex, not instead.
//
//  Pipeline:
//    1. Regex parser → ExtractionResult (fast, deterministic)
//    2. SLM enhancement → find missing fields (slow, probabilistic)
//    3. Hallucination guard → validate every SLM field
//    4. Merge → combined ExtractionResult
//
//  Privacy: 100% on-device. Zero network. LPD art. 6 compliant.
//
//  Reference: Plan vivid-petting-yao.md
// ────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/slm_extraction_validator.dart';
import 'package:mint_mobile/services/slm/slm_engine.dart';

/// Enhances regex-based document extraction with on-device SLM.
///
/// The SLM only searches for fields that the regex parser missed.
/// Every SLM-extracted field is validated through the 3-layer
/// hallucination guard before being accepted.
class SlmExtractionService {
  SlmExtractionService._();

  /// Minimum fields from regex before we skip SLM (already good enough).
  static const Map<DocumentType, int> _minFieldsThreshold = {
    DocumentType.lppCertificate: 5,
    DocumentType.taxDeclaration: 3,
    DocumentType.avsExtract: 2,
    DocumentType.salaryCertificate: 3,
  };

  /// All expected fields per document type, with labels for the prompt.
  static const Map<DocumentType, Map<String, String>> _expectedFields = {
    DocumentType.lppCertificate: {
      'lpp_total': 'Avoir de vieillesse total (CHF)',
      'lpp_obligatoire': 'Part obligatoire / Avoir LPP (CHF)',
      'lpp_surobligatoire': 'Part surobligatoire (CHF)',
      'lpp_insured_salary': 'Salaire assuré (CHF)',
      'lpp_determining_salary': 'Salaire déterminant (CHF)',
      'conversion_rate_oblig': 'Taux de conversion obligatoire (%)',
      'conversion_rate_suroblig': 'Taux de conversion surobligatoire (%)',
      'conversion_rate_at_65': 'Taux de conversion à 65 ans (%)',
      'remuneration_rate': 'Taux de rémunération / intérêts (%)',
      'projected_capital_65': 'Capital projeté à 65 ans (CHF)',
      'projected_rente': 'Rente de vieillesse projetée annuelle (CHF)',
      'disability_coverage': 'Rente d\'invalidité annuelle (CHF)',
      'death_coverage': 'Rente de conjoint / capital-décès (CHF)',
      'buyback_potential': 'Rachat maximal à 65 ans (CHF)',
      'buyback_early_retirement': 'Rachat retraite anticipée (CHF)',
      'employee_contribution': 'Cotisation employé annuelle (CHF)',
      'employer_contribution': 'Cotisation employeur annuelle (CHF)',
      'epl_max': 'Montant EPL / encouragement propriété (CHF)',
    },
    DocumentType.taxDeclaration: {
      'revenu_imposable': 'Revenu imposable (CHF)',
      'fortune_imposable': 'Fortune imposable (CHF)',
      'deductions_effectuees': 'Total des déductions (CHF)',
      'impot_cantonal': 'Impôt cantonal et communal (CHF)',
      'impot_federal': 'Impôt fédéral direct (CHF)',
      'taux_marginal_effectif': 'Taux marginal effectif (%)',
    },
    DocumentType.avsExtract: {
      'annees_cotisation': 'Nombre d\'années de cotisation',
      'ramd': 'Revenu annuel moyen déterminant (CHF)',
      'lacunes_cotisation': 'Nombre d\'années de lacunes',
      'bonifications_educatives': 'Nombre d\'années de bonifications éducatives',
    },
  };

  /// Profile field mapping for SLM-extracted fields.
  static const Map<String, String> _profileFieldMap = {
    'lpp_total': 'avoirLppTotal',
    'lpp_obligatoire': 'lppObligatoire',
    'lpp_surobligatoire': 'lppSurobligatoire',
    'lpp_insured_salary': 'lppInsuredSalary',
    'lpp_determining_salary': 'salaireBrut',
    'conversion_rate_oblig': 'tauxConversionOblig',
    'conversion_rate_suroblig': 'tauxConversionSuroblig',
    'remuneration_rate': 'rendementCaisse',
    'projected_capital_65': 'projectedCapital65',
    'projected_rente': 'projectedRenteLpp',
    'disability_coverage': 'disabilityCoverage',
    'death_coverage': 'deathCoverage',
    'buyback_potential': 'buybackPotential',
    'employee_contribution': 'employeeLppContribution',
    'employer_contribution': 'employerLppContribution',
    'epl_max': 'eplMax',
  };

  // ── Main entry point ──────────────────────────────────────

  /// Enhance an [ExtractionResult] with SLM-extracted fields.
  ///
  /// Returns the original result unchanged if:
  /// - SLM engine is not available (not downloaded/initialized)
  /// - Regex already found enough fields (above threshold)
  /// - SLM returns no valid new fields
  ///
  /// [ocrText] is the raw OCR text from the document.
  /// [regexResult] is the result from the regex parser.
  /// [documentType] determines which fields to search for.
  static Future<ExtractionResult> enhance({
    required String ocrText,
    required ExtractionResult regexResult,
    required DocumentType documentType,
  }) async {
    // Check SLM availability
    final slm = SlmEngine.instance;
    if (!slm.isAvailable) {
      debugPrint('[SlmExtraction] SLM not available, returning regex result');
      return regexResult;
    }

    // Check if regex already found enough
    final threshold = _minFieldsThreshold[documentType] ?? 5;
    final expectedFieldNames =
        _expectedFields[documentType]?.keys.toSet() ?? {};
    final foundFieldNames =
        regexResult.fields.map((f) => f.fieldName).toSet();
    final missingFieldNames =
        expectedFieldNames.difference(foundFieldNames).toList();

    if (missingFieldNames.isEmpty) {
      debugPrint('[SlmExtraction] No missing fields, skipping SLM');
      return regexResult;
    }

    if (regexResult.fieldCount >= threshold && missingFieldNames.length <= 2) {
      debugPrint('[SlmExtraction] Regex found $threshold+ fields '
          'with only ${missingFieldNames.length} missing, skipping SLM');
      return regexResult;
    }

    // Compress OCR text to fit context window
    final compressedOcr = compressOcrText(
      ocrText,
      regexResult.fields,
    );

    // Build prompt
    final prompt = buildPrompt(compressedOcr, missingFieldNames, documentType);

    // Call SLM
    debugPrint('[SlmExtraction] Calling SLM for ${missingFieldNames.length} '
        'missing fields...');
    final result = await slm.generate(
      systemPrompt: prompt.system,
      userPrompt: prompt.user,
      maxTokens: 512,
      temperature: 0.1, // Extra deterministic for extraction
    );

    if (result == null || result.text.trim().isEmpty) {
      debugPrint('[SlmExtraction] SLM returned null/empty');
      return regexResult;
    }

    debugPrint('[SlmExtraction] SLM responded in ${result.durationMs}ms');

    // Parse SLM response
    final candidates = parseSlmResponse(result.text, documentType);

    // Validate each candidate through hallucination guard
    final validatedFields = <ExtractedField>[];
    for (final candidate in candidates) {
      // Skip if regex already found this field
      if (foundFieldNames.contains(candidate.fieldName)) continue;

      final validated =
          SlmExtractionValidator.validate(candidate, ocrText);
      if (validated != null) {
        validatedFields.add(validated);
        debugPrint('[SlmExtraction] ACCEPTED: ${validated.fieldName} = '
            '${validated.value} (confidence: ${validated.confidence})');
      }
    }

    if (validatedFields.isEmpty) {
      debugPrint('[SlmExtraction] No valid SLM fields after validation');
      return regexResult;
    }

    // Merge: regex fields + validated SLM fields
    final mergedFields = [...regexResult.fields, ...validatedFields];
    final mergedConfidence = mergedFields.isEmpty
        ? 0.0
        : mergedFields.map((f) => f.confidence).reduce((a, b) => a + b) /
            mergedFields.length;

    return ExtractionResult(
      documentType: regexResult.documentType,
      fields: mergedFields,
      overallConfidence: mergedConfidence,
      confidenceDelta: regexResult.confidenceDelta +
          validatedFields.length * 1.5, // Conservative delta per SLM field
      warnings: [
        ...regexResult.warnings,
        '${validatedFields.length} champ(s) extrait(s) par analyse IA '
            'on-device. Vérifie ces valeurs sur ton certificat.',
      ],
      disclaimer: regexResult.disclaimer,
      sources: regexResult.sources,
    );
  }

  // ── OCR compression ───────────────────────────────────────

  /// Compress OCR text to fit within SLM context window.
  ///
  /// Strategy (no chunking — too slow for SLM):
  /// 1. Remove blank lines and decorative characters
  /// 2. Remove sections where regex already extracted values
  /// 3. Keep section headers for structural context
  /// 4. Truncate from bottom if still too long
  ///
  /// [maxChars] ~1600 tokens × 3.5 chars/token = 5600 chars.
  @visibleForTesting
  static String compressOcrText(
    String ocrText,
    List<ExtractedField> alreadyFound, {
    int maxChars = 5600,
  }) {
    final lines = ocrText.split('\n');
    final result = <String>[];

    // Collect source texts from already-found fields for removal
    final foundSourceTexts = alreadyFound
        .map((f) => f.sourceText.toLowerCase().trim())
        .where((s) => s.length > 10) // Only remove substantial matches
        .toSet();

    for (final line in lines) {
      final trimmed = line.trim();

      // Skip empty lines
      if (trimmed.isEmpty) continue;

      // Skip decorative lines
      if (RegExp(r'^[─═━\-_]{3,}$').hasMatch(trimmed)) continue;

      // Skip page numbers
      if (RegExp(r'^\d+/\d+$').hasMatch(trimmed)) continue;

      // Skip URLs and addresses (noise for SLM)
      if (RegExp(r'^(https?://|www\.)').hasMatch(trimmed)) continue;
      if (RegExp(r'Freigutstrasse|Postfach|Case postale',
              caseSensitive: false)
          .hasMatch(trimmed)) {
        continue;
      }

      // Skip lines whose content was already extracted by regex
      final lineLower = trimmed.toLowerCase();
      final isAlreadyExtracted = foundSourceTexts.any(
          (source) => lineLower.contains(source) || source.contains(lineLower));
      if (isAlreadyExtracted && !_isSectionHeader(trimmed)) continue;

      result.add(trimmed);
    }

    var compressed = result.join('\n');

    // Truncate from bottom if too long (critical data is at the top)
    if (compressed.length > maxChars) {
      compressed = compressed.substring(0, maxChars);
      // Don't cut in the middle of a line
      final lastNewline = compressed.lastIndexOf('\n');
      if (lastNewline > maxChars * 0.8) {
        compressed = compressed.substring(0, lastNewline);
      }
      compressed += '\n[...]'; // Signal truncation
    }

    return compressed;
  }

  /// Check if a line is a section header (should be preserved).
  static bool _isSectionHeader(String line) {
    return RegExp(
            r'^(Données|Cotisations?|Evolution|Prestation|Projection|Rachats?|Informations|Prestations)',
            caseSensitive: false)
        .hasMatch(line.trim());
  }

  // ── Prompt building ───────────────────────────────────────

  /// Build system + user prompts for SLM extraction.
  ///
  /// The system prompt lists only the MISSING fields (not all fields).
  /// The user prompt contains the compressed OCR text.
  @visibleForTesting
  static ({String system, String user}) buildPrompt(
    String compressedOcr,
    List<String> missingFieldNames,
    DocumentType documentType,
  ) {
    final fieldDescriptions = _expectedFields[documentType] ?? {};

    // Build the missing fields list for the prompt
    final fieldsList = missingFieldNames
        .where((name) => fieldDescriptions.containsKey(name))
        .map((name) => '- "$name": ${fieldDescriptions[name]}')
        .join('\n');

    final system = '''Tu es un extracteur de données de documents financiers suisses.

RÈGLES ABSOLUES :
1. Extrais UNIQUEMENT les valeurs VISIBLES dans le texte OCR ci-dessous.
2. N'INVENTE JAMAIS un chiffre. Si une valeur n'est pas dans le texte, ne l'inclus pas.
3. Réponds UNIQUEMENT en JSON valide. Aucun texte avant ou après.
4. Pour chaque valeur, cite le texte source EXACT copié du certificat.
5. Les montants sont en CHF sans apostrophes (ex: 70376.60, pas 70'376.60).
6. Les taux en pourcentage (ex: 5.0, pas 0.05).
7. Si deux colonnes (Bonus + Base), additionne-les.

CHAMPS RECHERCHÉS :
$fieldsList

FORMAT DE RÉPONSE :
{"fields":[{"name":"field_name","value":12345.67,"source":"texte exact"}]}

Si aucun champ trouvé : {"fields":[]}''';

    final user = 'TEXTE OCR DU CERTIFICAT :\n$compressedOcr';

    return (system: system, user: user);
  }

  // ── Response parsing ──────────────────────────────────────

  /// Parse SLM JSON response into candidate ExtractedField objects.
  ///
  /// Handles:
  /// - Valid JSON with fields array
  /// - JSON wrapped in markdown code blocks
  /// - Malformed JSON → empty list (graceful degradation)
  /// - Null values → filtered out
  /// - Unknown field names → ignored
  @visibleForTesting
  static List<ExtractedField> parseSlmResponse(
    String slmOutput,
    DocumentType documentType,
  ) {
    // Strip markdown code blocks if present
    var cleaned = slmOutput.trim();
    cleaned = cleaned.replaceAll(RegExp(r'^```(?:json)?\s*', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*```$', multiLine: true), '');
    cleaned = cleaned.trim();

    // Find JSON object in the response
    final jsonStart = cleaned.indexOf('{');
    final jsonEnd = cleaned.lastIndexOf('}');
    if (jsonStart < 0 || jsonEnd <= jsonStart) {
      debugPrint('[SlmExtraction] No valid JSON found in SLM response');
      return [];
    }
    cleaned = cleaned.substring(jsonStart, jsonEnd + 1);

    // Parse JSON
    final Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[SlmExtraction] JSON parse error: $e');
      return [];
    }

    final fieldsList = parsed['fields'];
    if (fieldsList is! List) return [];

    final knownFields = _expectedFields[documentType]?.keys.toSet() ?? {};
    final results = <ExtractedField>[];

    for (final field in fieldsList) {
      if (field is! Map<String, dynamic>) continue;

      final name = field['name'] as String?;
      final value = field['value'];
      final source = field['source'] as String? ?? '';

      // Skip null values, unknown fields, non-numeric values
      if (name == null || value == null) continue;
      if (!knownFields.contains(name)) continue;

      double? numericValue;
      if (value is num) {
        numericValue = value.toDouble();
      } else if (value is String) {
        // Try parsing string as number (SLM sometimes returns "70376.60")
        numericValue = double.tryParse(value.replaceAll("'", ""));
      }
      if (numericValue == null) continue;

      final label = _expectedFields[documentType]?[name] ?? name;

      results.add(ExtractedField(
        fieldName: name,
        label: label,
        value: numericValue,
        confidence: 0.65, // Will be adjusted by validator
        sourceText: source,
        needsReview: true,
        profileField: _profileFieldMap[name],
      ));
    }

    return results;
  }
}
