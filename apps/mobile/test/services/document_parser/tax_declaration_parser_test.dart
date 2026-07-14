import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/tax_declaration_parser.dart';

/// Unit tests for TaxDeclarationParser
///
/// Tests OCR text parsing of Swiss tax declarations (Declaration fiscale /
/// Steuererklarung) and tax assessment notices (Avis de taxation /
/// Steuerveranlagung) into structured ExtractedField objects.
///
/// Legal basis: LIFD art. 25-31, 33-33a, 38
void main() {
  // ── Helper ──────────────────────────────────────────────────
  ExtractedField? findField(ExtractionResult r, String fieldName) {
    try {
      return r.fields.firstWhere((f) => f.fieldName == fieldName);
    } catch (_) {
      return null;
    }
  }

  // ── Sample OCR text (well-formatted) ───────────────────────
  group('parseTaxDeclaration — sample OCR text', () {
    late ExtractionResult result;

    setUp(() {
      result = TaxDeclarationParser.parseTaxDeclaration(
        TaxDeclarationParser.sampleOcrText,
      );
    });

    test('returns correct document type', () {
      expect(result.documentType, DocumentType.taxDeclaration);
    });

    test('extracts revenu imposable = 95800', () {
      final field = findField(result, 'revenu_imposable');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(95800.0, 0.01));
      expect(field.profileField, 'actualTaxableIncome');
    });

    test('extracts fortune imposable = 245000', () {
      final field = findField(result, 'fortune_imposable');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(245000.0, 0.01));
      expect(field.profileField, 'actualTaxableWealth');
    });

    test('extracts deductions effectuees = 18750', () {
      final field = findField(result, 'deductions_effectuees');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(18750.0, 0.01));
    });

    test('extracts impot cantonal et communal = 14520', () {
      final field = findField(result, 'impot_cantonal');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(14520.0, 0.01));
    });

    test('extracts impot federal direct = 3840', () {
      final field = findField(result, 'impot_federal');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(3840.0, 0.01));
    });

    test('extracts taux marginal effectif = 32.5%', () {
      final field = findField(result, 'taux_marginal_effectif');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(32.5, 0.1));
    });

    test('keeps user-facing copy out of the parser result', () {
      expect(result.warnings, isEmpty);
      expect(result.disclaimer, isEmpty);
      expect(result.sources, isEmpty);
    });

    test('overall confidence is above 0.80', () {
      expect(result.overallConfidence, greaterThanOrEqualTo(0.80));
    });

    test('confidence delta stays zero until canonical post-save scoring', () {
      expect(result.confidenceDelta, 0);
    });
  });

  // ── Swiss number formats ───────────────────────────────────
  group('parseTaxDeclaration — Swiss number formats', () {
    test('parses apostrophe thousands: 85\'400', () {
      const text = "Revenu imposable: CHF 85'400.00";
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      final field = findField(result, 'revenu_imposable');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(85400.0, 0.01));
    });

    test('parses space as thousand separator: 245 000', () {
      const text = "Fortune imposable: CHF 245 000";
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      final field = findField(result, 'fortune_imposable');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(245000.0, 1.0));
    });

    test('parses comma decimal (Swiss German): 14520,00', () {
      const text = "Kantonssteuer: 14520,00";
      // This won't match FR patterns but tests the parser doesn't crash
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      // Kantonssteuer matches the German pattern
      final field = findField(result, 'impot_cantonal');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(14520.0, 0.01));
    });

    test('parses Fr. prefix', () {
      const text = "Revenu imposable: Fr. 110'000.00";
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      final field = findField(result, 'revenu_imposable');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(110000.0, 0.01));
    });
  });

  // ── German (DE) format ─────────────────────────────────────
  group('parseTaxDeclaration — German format', () {
    test('parses Steuerbares Einkommen (DE)', () {
      const text = "Steuerbares Einkommen: CHF 120'000.00";
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      final field = findField(result, 'revenu_imposable');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(120000.0, 0.01));
    });

    test('parses Steuerbares Vermogen (DE)', () {
      const text = "Steuerbares Vermögen: CHF 500'000.00";
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      final field = findField(result, 'fortune_imposable');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(500000.0, 0.01));
    });

    test('parses Total Abzüge (DE)', () {
      const text = "Total Abzüge: CHF 22'000.00";
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      final field = findField(result, 'deductions_effectuees');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(22000.0, 0.01));
    });

    test('parses Direkte Bundessteuer (DE)', () {
      const text = "Direkte Bundessteuer: CHF 5'200.00";
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      final field = findField(result, 'impot_federal');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(5200.0, 0.01));
    });

    test('parses Grenzsteuersatz (DE)', () {
      const text = "Grenzsteuersatz: 35.2 %";
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      final field = findField(result, 'taux_marginal_effectif');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(35.2, 0.1));
    });
  });

  // ── Cross-validation ───────────────────────────────────────
  group('parseTaxDeclaration — cross-validation', () {
    test('emits only a typed ratio diagnostic for a low read ratio', () {
      const text = """
Revenu imposable: CHF 200'000.00
Impôt cantonal et communal: CHF 3'000.00
Impôt fédéral direct: CHF 1'000.00
""";
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      expect(result.warnings, isEmpty);
      expect(
        result.diagnostics.single.code,
        ExtractionDiagnosticCode.taxComputedAverageRateNotMarginal,
      );
      expect(result.diagnostics.single.ratePercent, 2);
    });

    test('emits only a typed ratio diagnostic for a high read ratio', () {
      const text = """
Revenu imposable: CHF 100'000.00
Impôt cantonal et communal: CHF 40'000.00
Impôt fédéral direct: CHF 15'000.00
""";
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      expect(result.warnings, isEmpty);
      expect(
        result.diagnostics.single.code,
        ExtractionDiagnosticCode.taxComputedAverageRateNotMarginal,
      );
      expect(result.diagnostics.single.ratePercent, closeTo(55, 0.000001));
    });

    test('emits the same typed ratio diagnostic for a 20 percent read ratio',
        () {
      const text = """
Revenu imposable: CHF 100'000.00
Impôt cantonal et communal: CHF 15'000.00
Impôt fédéral direct: CHF 5'000.00
""";
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      expect(result.warnings, isEmpty);
      expect(
        result.diagnostics.single.code,
        ExtractionDiagnosticCode.taxComputedAverageRateNotMarginal,
      );
      expect(result.diagnostics.single.ratePercent, 20);
    });

    test('does not invent a jurisdiction-free marginal-rate floor', () {
      const text = "Taux marginal effectif: 3.0 %";
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      expect(result.diagnostics, isEmpty);
    });

    test('does not invent a jurisdiction-free marginal-rate ceiling', () {
      const text = "Taux marginal effectif: 60.0 %";
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      expect(result.diagnostics, isEmpty);
    });

    test('types an explicit percentage that exceeds its storage unit', () {
      const text = "Taux marginal effectif: 101.0 %";
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      expect(
        result.diagnostics.single.code,
        ExtractionDiagnosticCode.taxPercentUnitOutOfRange,
      );
      expect(result.diagnostics.single.ratePercent, 101);
    });

    test('retains negative wealth for review with a typed diagnostic', () {
      const text = "Fortune imposable: CHF -25'000.00";
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      expect(findField(result, 'fortune_imposable')?.value, -25000);
      expect(
        result.diagnostics.single.code,
        ExtractionDiagnosticCode.taxNegativeWealthNeedsLabelReview,
      );
    });

    test('does not apply an unsourced deductions-to-income heuristic', () {
      const text = """
Revenu imposable: CHF 100'000.00
Total des déductions effectuées: CHF 70'000.00
""";
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      expect(result.warnings, isEmpty);
      expect(result.diagnostics, isEmpty);
    });

    test('never promotes a computed tax-to-income ratio to marginal', () {
      const text = """
Revenu imposable: CHF 100'000.00
Impôt cantonal et communal: CHF 15'000.00
Impôt fédéral direct: CHF 5'000.00
""";
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      final field = findField(result, 'taux_marginal_effectif');
      expect(
        field,
        isNull,
        reason:
            '(ICC + IFD) / revenu is an average rate, never a marginal rate',
      );
    });

    test('average and effective labels never map to actualMarginalRate', () {
      for (final text in const [
        "Taux moyen d'imposition: 22.3 %",
        'Effektiver Steuersatz: 19.4 %',
      ]) {
        final result = TaxDeclarationParser.parseTaxDeclaration(text);
        expect(
          result.fields.where((f) => f.profileField == 'actualMarginalRate'),
          isEmpty,
          reason:
              'average/effective rates require their own typed field: $text',
        );
      }
    });

    test('cantonal-only and combined ICC labels stay distinguishable', () {
      final cantonalOnly = findField(
        TaxDeclarationParser.parseTaxDeclaration(
          "Impôt cantonal: CHF 10'000.00",
        ),
        'impot_cantonal',
      );
      final combinedIcc = findField(
        TaxDeclarationParser.parseTaxDeclaration("ICC: CHF 14'520.00"),
        'impot_cantonal',
      );

      expect(cantonalOnly, isNotNull);
      expect(combinedIcc, isNotNull);
      expect(
        cantonalOnly!.labelCode,
        isNot(combinedIcc!.labelCode),
        reason:
            'cantonalOnly must not be presented as cantonalCommunalCombined',
      );
    });
  });

  // ── Empty / malformed input ────────────────────────────────
  group('parseTaxDeclaration — edge cases', () {
    test('empty string produces zero fields and zero confidence', () {
      final result = TaxDeclarationParser.parseTaxDeclaration('');
      expect(result.fields, isEmpty);
      expect(result.overallConfidence, 0.0);
      expect(result.confidenceDelta, 0.0);
      expect(result.warnings, isEmpty);
      expect(result.documentType, DocumentType.taxDeclaration);
    });

    test('random text produces zero fields', () {
      final result = TaxDeclarationParser.parseTaxDeclaration(
        'The quick brown fox jumps over the lazy dog.',
      );
      expect(result.fields, isEmpty);
      expect(result.overallConfidence, 0.0);
    });

    test('handles whitespace-only input', () {
      final result = TaxDeclarationParser.parseTaxDeclaration('   \n\n  ');
      expect(result.fields, isEmpty);
      expect(result.overallConfidence, 0.0);
    });

    test('text with labels but no numeric values produces zero fields', () {
      final result = TaxDeclarationParser.parseTaxDeclaration(
        'Revenu imposable: \nFortune imposable: ',
      );
      expect(result.fields, isEmpty);
    });
  });

  // ── Confidence metadata ────────────────────────────────────
  group('parseTaxDeclaration — confidence metadata', () {
    test('CHF-prefixed amount has confidence boost', () {
      const text = "Revenu imposable: CHF 95'800.00";
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      final field = findField(result, 'revenu_imposable');
      expect(field, isNotNull);
      expect(field!.confidence, greaterThanOrEqualTo(0.82));
    });

    test('percentage in reasonable range has confidence >= 0.83', () {
      const text = "Taux marginal effectif: 32.5 %";
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      final field = findField(result, 'taux_marginal_effectif');
      expect(field, isNotNull);
      expect(field!.confidence, greaterThanOrEqualTo(0.83));
    });

    test('hasFieldsNeedingReview is false when all fields high confidence', () {
      const text = """
Revenu imposable: CHF 95'800.00
Impôt fédéral direct: CHF 3'840.00
""";
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      // All CHF-prefixed should be high confidence
      for (final f in result.highConfidenceFields) {
        expect(f.confidence, greaterThanOrEqualTo(0.80));
      }
    });
  });

  // ── Confidence is awarded only after canonical ledger save ──────────
  group('estimateConfidenceDelta', () {
    test('returns zero for empty and populated profiles', () {
      final result = TaxDeclarationParser.parseTaxDeclaration(
        TaxDeclarationParser.sampleOcrText,
      );
      expect(
        TaxDeclarationParser.estimateConfidenceDelta(
          result,
          <String, dynamic>{},
        ),
        0,
      );
      expect(
        TaxDeclarationParser.estimateConfidenceDelta(
          result,
          <String, dynamic>{'actualTaxableIncome': 90000.0},
        ),
        0,
      );
    });
  });

  // ── French variant patterns ────────────────────────────────
  group('parseTaxDeclaration — French variant patterns', () {
    test('parses "revenu net imposable"', () {
      const text = "Revenu net imposable: CHF 88'000.00";
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      final field = findField(result, 'revenu_imposable');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(88000.0, 0.01));
    });

    test('parses "total des revenus imposable"', () {
      const text = "Total des revenus imposable: CHF 92'000.00";
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      final field = findField(result, 'revenu_imposable');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(92000.0, 0.01));
    });

    test('parses "ICC" for cantonal tax', () {
      const text = "ICC: CHF 12'000.00";
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      final field = findField(result, 'impot_cantonal');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(12000.0, 0.01));
    });

    test('parses "IFD" for federal tax', () {
      const text = "IFD: CHF 4'100.00";
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      final field = findField(result, 'impot_federal');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(4100.0, 0.01));
    });

    test('parses "déductions admises"', () {
      const text = "Déductions admises: CHF 15'000.00";
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      final field = findField(result, 'deductions_effectuees');
      expect(field, isNotNull);
      expect((field!.value as double), closeTo(15000.0, 0.01));
    });

    test('does not parse "taux moyen d\'imposition" as marginal', () {
      const text = "Taux moyen d'imposition: 22.3 %";
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      final field = findField(result, 'taux_marginal_effectif');
      expect(field, isNull);
    });
  });
}
