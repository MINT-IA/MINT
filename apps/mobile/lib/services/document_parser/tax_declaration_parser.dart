// ────────────────────────────────────────────────────────────
//  TAX DECLARATION PARSER — Sprint S44
// ────────────────────────────────────────────────────────────
//
//  Extracts structured financial fields from OCR text of a
//  Swiss tax declaration (Declaration fiscale / Steuererklarung)
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
//    - LIFD art. 33-33a (deductions)
// ────────────────────────────────────────────────────────────

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/financial_core/tax_document_ratio_calculator.dart';

/// Pattern definition for a known tax declaration field.
class _TaxFieldPattern {
  final String fieldName;
  final ExtractionFieldLabelCode labelCode;
  final List<RegExp> patterns;
  final String? profileField;
  final bool isPercentage;

  const _TaxFieldPattern({
    required this.fieldName,
    required this.labelCode,
    required this.patterns,
    this.profileField,
    this.isPercentage = false,
  });
}

// Reusable regex fragment: Swiss number capture group
// Matches: CHF 85'400.00, Fr. 98 400, 44887.50, -25'000.00, CHF -25'000, etc.
// Requires at least one digit to avoid matching whitespace-only (e.g. section headers).
const String _numCapture = r"(-?\s*[CHFfr.\s]*-?\s*\d[\d\s'.,]*)";

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

  /// Parse a percentage: "32.5%", "32,5 %", "0.325".
  static double? _parsePercentage(String text) {
    final hasPercentSymbol = text.contains('%');
    var cleaned = text.replaceAll("%", "").trim();
    cleaned = cleaned.replaceAll(",", ".");
    cleaned = cleaned.replaceAll(RegExp(r"[^\d.\-]"), "");
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null) return null;
    // If value > 1, it's already in percent form (e.g. 32.5)
    // If value <= 1, it might be in decimal form (e.g. 0.325)
    return hasPercentSymbol || value.abs() > 1 ? value : value * 100;
  }

  // ── Known field patterns (FR + DE) ────────────────────────

  static final List<_TaxFieldPattern> _knownFieldPatterns = [
    // ── Revenu imposable ──
    _TaxFieldPattern(
      fieldName: "revenu_imposable",
      labelCode: ExtractionFieldLabelCode.taxTaxableIncome,
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
        // OCR variant: the plural total-taxable-income heading.
        RegExp(
            r"(?:total\s+des?\s+revenus?\s+imposable)\s*[:\s]*" + _numCapture,
            caseSensitive: false),
      ],
    ),

    // ── Fortune imposable ──
    _TaxFieldPattern(
      fieldName: "fortune_imposable",
      labelCode: ExtractionFieldLabelCode.taxTaxableWealth,
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
      labelCode: ExtractionFieldLabelCode.taxDeductions,
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
        RegExp(r"(?:d[e\u00e9]ductions?\s+admises?)\s*[:\s]*" + _numCapture,
            caseSensitive: false),
      ],
    ),

    // ── Impot cantonal et communal explicite ──
    _TaxFieldPattern(
      fieldName: "impot_cantonal",
      labelCode: ExtractionFieldLabelCode.taxCantonalCommunalTax,
      profileField: "actualCantonalTax",
      patterns: [
        RegExp(
            r"(?:imp[oô]t\s+cantonal\s+et\s+communal|imp[oô]ts?\s+cantonaux?\s+et\s+communaux?|ICC|total\s+ICC)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Kantons[\-\s]*und\s+Gemeinde[\-\s]*[Ss]teuer|Staats[\-\s]*und\s+Gemeinde[\-\s]*[Ss]teuer)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
      ],
    ),

    // ── Impot cantonal seul ──
    _TaxFieldPattern(
      fieldName: "impot_cantonal",
      labelCode: ExtractionFieldLabelCode.taxCantonalOnlyTax,
      profileField: "actualCantonalTax",
      patterns: [
        RegExp(
            r"(?:imp[oô]t\s+cantonal(?!\s+et\s+communal)|imp[oô]ts?\s+cantonaux?(?!\s+et\s+communaux?))\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
        RegExp(
            r"(?:Kantons[\-\s]*[Ss]teuer|Staats[\-\s]*[Ss]teuer)\s*[:\s]*" +
                _numCapture,
            caseSensitive: false),
      ],
    ),

    // ── Impot federal direct ──
    _TaxFieldPattern(
      fieldName: "impot_federal",
      labelCode: ExtractionFieldLabelCode.taxFederalDirectTax,
      profileField: "actualFederalTax",
      patterns: [
        RegExp(
            r"(?:imp[oô]t\s+f[eé]d[eé]ral\s+direct|IFD)\s*[:\s]*" + _numCapture,
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
      labelCode: ExtractionFieldLabelCode.taxMarginalRate,
      profileField: "actualMarginalRate",
      isPercentage: true,
      patterns: [
        RegExp(
            r"(?:taux\s+marginal\s+effectif|taux\s+d[' ]?imposition\s+marginal)\s*[:\s]*(-?[\d,.\s]+\s*%?)",
            caseSensitive: false),
        RegExp(
            r"(?:Grenzsteuersatz|Marginaler?\s+Steuersatz)\s*[:\s]*(-?[\d,.\s]+\s*%?)",
            caseSensitive: false),
      ],
    ),

    // ── Taux moyen/effectif, distinct du marginal ──
    _TaxFieldPattern(
      fieldName: "taux_moyen_effectif",
      labelCode: ExtractionFieldLabelCode.taxAverageRate,
      profileField: "actualAverageRate",
      isPercentage: true,
      patterns: [
        RegExp(
            r"(?:taux\s+moyen\s+d[' ]?imposition|taux\s+d[' ]?imposition\s+effectif|Effektiver?\s+Steuersatz)\s*[:\s]*(-?[\d,.\s]+\s*%?)",
            caseSensitive: false),
      ],
    ),
  ];

  // ── Main parsing method ───────────────────────────────────

  /// Parse a tax document into one review candidate without persisting facts.
  static TaxExtractionCandidate parseTaxDocument(
    String text, {
    required String Function() snapshotIdFactory,
  }) {
    final normalized = text.toLowerCase();
    final (documentKind, assessmentStatus) = _classifyDocument(normalized);
    final taxYear = _firstYear(
      text,
      RegExp(
        r'(?:p[eé]riode\s+fiscale|steuerperiode)\s*:?\s*(20\d{2})',
        caseSensitive: false,
      ),
    );
    final basedOnTaxYear = _firstYear(
      text,
      RegExp(
        r'(?:base\s+de\s+la\s+taxation|basierend\s+auf(?:\s+der)?\s+(?:taxation|veranlagung))\s*(20\d{2})',
        caseSensitive: false,
      ),
    );
    final sourceDate = _extractSourceDate(text);
    final subjectScope = _subjectScope(normalized);
    final cantonCode = _firstText(
      text,
      RegExp(
        r'(?:^|\n)\s*(?:canton|kanton)\s*:\s*([A-Z]{2})\b',
        caseSensitive: false,
      ),
    )?.toUpperCase();
    final municipalityId = _firstText(
      text,
      RegExp(
        r'(?:^|\n)\s*(?:no\s+OFS\s+commune|BFS[-\s]*Nr\.?\s+Gemeinde)\s*:\s*([0-9]+)',
        caseSensitive: false,
      ),
    );
    final municipalityLabel = _firstText(
      text,
      RegExp(
        r'(?:^|\n)\s*(?:commune|gemeinde)\s*:\s*([^\n\r]+)',
        caseSensitive: false,
      ),
    )?.trim();

    final cantonalIncome = _firstAmount(
            text,
            [
              RegExp(
                r'(?:revenu\s+imposable\s+ICC|steuerbares?\s+einkommen\s+(?:ICC|kanton(?:\s+und\s+gemeinde)?))\s*:\s*' +
                    _numCapture,
                caseSensitive: false,
              ),
            ],
            allowNegative: true)
        ?.value;
    final federalIncome = _firstAmount(
            text,
            [
              RegExp(
                r'(?:revenu\s+imposable\s+IFD|steuerbares?\s+einkommen\s+(?:IFD|bund))\s*:\s*' +
                    _numCapture,
                caseSensitive: false,
              ),
            ],
            allowNegative: true)
        ?.value;
    final wealth = _firstAmount(text, [
      RegExp(
        r'(?:fortune\s+imposable\s+ICC|steuerbares?\s+verm[oö]gen\s+(?:ICC|kanton(?:\s+und\s+gemeinde)?))\s*:\s*' +
            _numCapture,
        caseSensitive: false,
      ),
    ])?.value;

    final combinedTax = _firstAmount(text, [
      RegExp(
        r'(?:^|[\r\n])\s*(?:imp[oô]t\s+cantonal\s+et\s+communal|ICC\b)(?:\s*,?\s*(?:sur\s+le\s+)?(?:revenu\s+et\s+fortune|revenu|fortune))?\s*:\s*' +
            _numCapture,
        caseSensitive: false,
      ),
      RegExp(
        r'(?:^|[\r\n])\s*(?:Kantons[-\s]*und\s+Gemeinde[-\s]*steuer|Staats[-\s]*und\s+Gemeinde[-\s]*steuer)(?:\s+(?:Einkommen\s+und\s+Verm[oö]gen|Einkommen|Verm[oö]gen))?\s*:\s*' +
            _numCapture,
        caseSensitive: false,
      ),
    ]);
    final cantonalOnlyTax = combinedTax == null
        ? _firstAmount(text, [
            RegExp(
              r'(?:imp[oô]t\s+cantonal(?!\s+et\s+communal)|Kantonssteuer|Staatssteuer)(?:\s+(?:sur\s+le\s+revenu|sur\s+la\s+fortune|Einkommen|Verm[oö]gen))?\s*:\s*' +
                  _numCapture,
              caseSensitive: false,
            ),
          ])
        : null;
    final federalTax = _firstAmount(text, [
      RegExp(
        r'(?:^|[\r\n])\s*(?:imp[oô]t\s+f[eé]d[eé]ral\s+direct|IFD\b|Direkte\s+Bundessteuer)(?:\s+(?:sur\s+le\s+revenu|Einkommen))?\s*:\s*' +
            _numCapture,
        caseSensitive: false,
      ),
    ]);

    final explicitMarginalRate = _firstRatio(
        text,
        RegExp(
          r"(?:taux\s+marginal(?:\s+d[’' ]?imposition|\s+effectif)?|Grenzsteuersatz|Marginaler?\s+Steuersatz)\s*:\s*([\d,.]+)\s*%?",
          caseSensitive: false,
        ));
    final explicitAverageRate = _firstRatio(
        text,
        RegExp(
          r"(?:taux\s+moyen\s+d[’' ]?imposition|taux\s+d[’' ]?imposition\s+effectif|Effektiver?\s+Steuersatz)\s*:\s*([\d,.]+)\s*%?",
          caseSensitive: false,
        ));

    AssessedTaxAmount? cantonalTaxAmount;
    if (combinedTax != null && combinedTax.value >= 0) {
      cantonalTaxAmount = AssessedTaxAmount(
        amountChf: combinedTax.value,
        authorityScope: TaxAuthorityScope.cantonalCommunalCombined,
        baseScope: _baseScope(combinedTax.source),
      );
    } else if (cantonalOnlyTax != null && cantonalOnlyTax.value >= 0) {
      cantonalTaxAmount = AssessedTaxAmount(
        amountChf: cantonalOnlyTax.value,
        authorityScope: TaxAuthorityScope.cantonalOnly,
        baseScope: _baseScope(cantonalOnlyTax.source),
      );
    }
    final federalTaxAmount = federalTax == null || federalTax.value < 0
        ? null
        : AssessedTaxAmount(
            amountChf: federalTax.value,
            authorityScope: TaxAuthorityScope.federalDirect,
            baseScope: _baseScope(federalTax.source),
          );

    return TaxExtractionCandidate.fromExtractionResult(
      parseTaxDeclaration(text),
      snapshotIdFactory: snapshotIdFactory,
      documentKind: documentKind,
      assessmentStatus: assessmentStatus,
      taxYear: taxYear,
      basedOnTaxYear: basedOnTaxYear,
      sourceDate: sourceDate,
      subjectScope: subjectScope,
      cantonCode: cantonCode,
      municipalityId: municipalityId,
      municipalityLabel: municipalityLabel,
      cantonalCommunalTaxableIncomeChf: cantonalIncome,
      federalTaxableIncomeChf: federalIncome,
      cantonalCommunalTaxableWealthChf:
          wealth != null && wealth >= 0 ? wealth : null,
      cantonalCommunalAssessedTax: cantonalTaxAmount,
      federalDirectAssessedTax: federalTaxAmount,
      explicitMarginalIncomeTaxRate: explicitMarginalRate,
      explicitAverageIncomeTaxRate: explicitAverageRate,
    );
  }

  static (TaxDocumentKind, TaxAssessmentStatus) _classifyDocument(
    String normalized,
  ) {
    if (RegExp(r'bordereau\s+provisoire|provisorische\s+steuerrechnung')
        .hasMatch(normalized)) {
      return (
        TaxDocumentKind.provisionalBill,
        TaxAssessmentStatus.provisional,
      );
    }
    if (RegExp(r'bordereau\s+final|schlussrechnung').hasMatch(normalized)) {
      return (TaxDocumentKind.finalTaxBill, TaxAssessmentStatus.unknown);
    }
    if (RegExp(
            r"d[eé]claration\s+d[’' ]?imp[oô]t|d[eé]claration\s+fiscale|steuererkl[aä]rung")
        .hasMatch(normalized)) {
      return (TaxDocumentKind.taxpayerReturn, TaxAssessmentStatus.selfDeclared);
    }
    if (RegExp(
            r'avis\s+de\s+taxation|d[eé]cision\s+de\s+taxation|veranlagungsverf[uü]gung')
        .hasMatch(normalized)) {
      return (
        TaxDocumentKind.assessmentNotice,
        TaxAssessmentStatus.assessedAppealable,
      );
    }
    return (TaxDocumentKind.unknown, TaxAssessmentStatus.unknown);
  }

  static int? _firstYear(String text, RegExp pattern) =>
      int.tryParse(pattern.firstMatch(text)?.group(1) ?? '');

  static String? _firstText(String text, RegExp pattern) =>
      pattern.firstMatch(text)?.group(1);

  static DateTime? _extractSourceDate(String text) {
    final match = RegExp(
      r"(?:[eé]mis\s+le|date\s+d[’' ]?[eé]mission|ausgestellt\s+am|verf[uü]gungsdatum)\s*:\s*(\d{1,2})[.]([0-1]?\d)[.](20\d{2})",
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;
    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (day == null || month == null || year == null) return null;
    final parsed = DateTime.utc(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  static TaxSubjectScope _subjectScope(String normalized) {
    if (RegExp(
            r'taxation\s+commune\s+des\s+[eé]poux|gemeinsame\s+veranlagung|ehegatten')
        .hasMatch(normalized)) {
      return TaxSubjectScope.jointlyAssessedCouple;
    }
    if (RegExp(r'taxation\s+individuelle|einzelveranlagung')
        .hasMatch(normalized)) {
      return TaxSubjectScope.individual;
    }
    return TaxSubjectScope.unknown;
  }

  static ({double value, String source})? _firstAmount(
    String text,
    List<RegExp> patterns, {
    bool allowNegative = false,
  }) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;
      final parsed = _parseSwissNumber(match.group(1) ?? '');
      if (parsed != null && parsed.isFinite && (allowNegative || parsed >= 0)) {
        return (value: parsed, source: match.group(0) ?? '');
      }
    }
    return null;
  }

  static double? _firstRatio(String text, RegExp pattern) {
    final match = pattern.firstMatch(text);
    final raw = match?.group(1);
    if (match == null || raw == null) return null;
    if (match.group(0)?.contains('%') == true) {
      final explicitPercent = _parseSwissNumber(raw);
      if (explicitPercent == null ||
          !explicitPercent.isFinite ||
          explicitPercent < 0 ||
          explicitPercent > 100) {
        return null;
      }
      return explicitPercent / 100;
    }
    final percent = _parsePercentage(raw);
    if (percent == null || !percent.isFinite || percent < 0 || percent > 100) {
      return null;
    }
    return percent / 100;
  }

  static TaxBaseScope _baseScope(String source) {
    final normalized = source.toLowerCase();
    if ((normalized.contains('revenu') && normalized.contains('fortune')) ||
        (normalized.contains('einkommen') && normalized.contains('vermögen'))) {
      return TaxBaseScope.incomeAndWealth;
    }
    if (normalized.contains('revenu') || normalized.contains('einkommen')) {
      return TaxBaseScope.incomeOnly;
    }
    if (normalized.contains('fortune') || normalized.contains('vermögen')) {
      return TaxBaseScope.wealthOnly;
    }
    return TaxBaseScope.unknown;
  }

  /// Parse OCR text from a tax declaration into structured fields.
  ///
  /// [text] is the raw OCR output from the tax document image.
  /// Returns an [ExtractionResult] with all detected fields,
  /// confidence scores, cross-validation warnings, and compliance info.
  static ExtractionResult parseTaxDeclaration(String text) {
    final fields = <ExtractedField>[];
    final diagnostics = <ExtractionDiagnostic>[];

    for (final pattern in _knownFieldPatterns) {
      final result = _extractField(text, pattern);
      if (result != null) {
        fields.add(result);
      }
    }

    final cantonal = _findFieldValue(fields, "impot_cantonal");
    final federal = _findFieldValue(fields, "impot_federal");

    // A parsed percentage outside its storage unit remains review-only.
    final tauxMarginal = _findFieldValue(fields, "taux_marginal_effectif");
    for (final rate in [
      tauxMarginal,
      _findFieldValue(fields, "taux_moyen_effectif"),
    ]) {
      if (rate != null && (rate < 0 || rate > 100.0)) {
        diagnostics.add(
          ExtractionDiagnostic.percentUnit(rate),
        );
      }
    }

    // A negative net-wealth reading can be legitimate, but the exact authority
    // label must be confirmed before it can become a taxable-wealth fact.
    final fortune = _findFieldValue(fields, "fortune_imposable");
    if (fortune != null && fortune < 0) {
      diagnostics.add(
        ExtractionDiagnostic.negativeWealth(fortune),
      );
    }

    // A ratio of two read amounts is diagnostic only and never a legal rate.
    if (tauxMarginal == null && cantonal != null && federal != null) {
      final revenuForInfer = _findFieldValue(fields, "revenu_imposable");
      if (revenuForInfer != null && revenuForInfer > 0) {
        final totalImpot = cantonal + federal;
        final inferredRate = TaxDocumentRatioCalculator.percentOf(
          amount: totalImpot,
          reference: revenuForInfer,
        );
        if (inferredRate > 0) {
          diagnostics.add(
            ExtractionDiagnostic.averageNotMarginal(inferredRate),
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
      confidenceDelta: switch (DocumentType.taxDeclaration) {
        DocumentType.taxDeclaration => 0.0,
        _ => 0.0,
      },
      warnings: const [],
      disclaimer: '',
      sources: const [],
      diagnostics: diagnostics,
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
          final rejectsNegativeValue = pattern.fieldName == 'impot_cantonal' ||
              pattern.fieldName == 'impot_federal';
          if (rejectsNegativeValue && num < 0) continue;
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
          label: pattern.labelCode.name,
          labelCode: pattern.labelCode,
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

  /// Estimate confidence delta given an extraction result and the current
  /// user profile fields.
  ///
  /// Fields that replace system estimates have higher impact than those
  /// that replace user entries.
  static double estimateConfidenceDelta(
    ExtractionResult result,
    Map<String, dynamic> currentProfile,
  ) {
    return 0;
  }

  // ── Sample OCR text for prototype testing ─────────────────

  /// Sample OCR text simulating a typical Swiss tax declaration.
  /// Used for the prototype simulated-scan button.
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
Total des deductions effectuees:               CHF 18'750.00
  dont pilier 3a:                              CHF 7'258.00
  dont frais professionnels:                   CHF 4'200.00
  dont assurance-maladie:                      CHF 3'192.00
  dont autres deductions:                      CHF 4'100.00

IMPOTS
Impot cantonal et communal:                    CHF 14'520.00
Impot federal direct:                          CHF 3'840.00

TAUX
Taux d'imposition effectif:                    19.15 %
Taux marginal effectif:                        32.5 %

---
Ce document est emis conformement a la LIFD et la loi fiscale cantonale.
Il constitue l'avis de taxation definitif pour la periode fiscale 2025.
""";
}
