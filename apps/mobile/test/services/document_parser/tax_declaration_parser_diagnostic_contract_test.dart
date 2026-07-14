import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/tax_declaration_parser.dart';

void main() {
  test('typed diagnostic constructors make payload states coherent', () {
    const percent = ExtractionDiagnostic.percentUnit(101);
    const wealth = ExtractionDiagnostic.negativeWealth(-25000);
    const average = ExtractionDiagnostic.averageNotMarginal(20);

    expect(percent.code, ExtractionDiagnosticCode.taxPercentUnitOutOfRange);
    expect(percent.ratePercent, 101);
    expect(percent.amountChf, isNull);
    expect(
      wealth.code,
      ExtractionDiagnosticCode.taxNegativeWealthNeedsLabelReview,
    );
    expect(wealth.amountChf, -25000);
    expect(wealth.ratePercent, isNull);
    expect(
      average.code,
      ExtractionDiagnosticCode.taxComputedAverageRateNotMarginal,
    );
    expect(average.ratePercent, 20);
    expect(average.amountChf, isNull);
  });

  test('tax parser emits typed labels and no visible service copy', () {
    final result = TaxDeclarationParser.parseTaxDeclaration(
      TaxDeclarationParser.sampleOcrText,
    );

    expect(result.warnings, isEmpty);
    expect(result.disclaimer, isEmpty);
    expect(result.sources, isEmpty);
    expect(
      result.fields.map((field) => field.labelCode),
      everyElement(isNotNull),
    );
  });

  test('each explicit rate outside 0...100 emits a typed diagnostic', () {
    for (final fixture in const {
      'Taux marginal effectif: 101.0 %': 101.0,
      'Taux marginal effectif: -2.0 %': -2.0,
      "Taux moyen d'imposition: 101.0 %": 101.0,
      "Taux moyen d'imposition: -2.0 %": -2.0,
    }.entries) {
      final result = TaxDeclarationParser.parseTaxDeclaration(fixture.key);

      expect(result.diagnostics, hasLength(1), reason: fixture.key);
      expect(
        result.diagnostics.single.code,
        ExtractionDiagnosticCode.taxPercentUnitOutOfRange,
        reason: fixture.key,
      );
      expect(
        result.diagnostics.single.ratePercent,
        fixture.value,
        reason: fixture.key,
      );
    }
  });

  test('negative wealth stays reviewable but is not promoted to typed facts',
      () {
    final result = TaxDeclarationParser.parseTaxDeclaration(
      "Fortune imposable: CHF -25'000.00",
    );
    final field = result.fields.single;

    expect(field.value, -25000);
    expect(
      result.diagnostics.single.code,
      ExtractionDiagnosticCode.taxNegativeWealthNeedsLabelReview,
    );
    expect(result.diagnostics.single.amountChf, -25000);

    final candidate = TaxDeclarationParser.parseTaxDocument(
      "Fortune imposable ICC: CHF -25'000.00",
      snapshotIdFactory: () => '11111111-1111-4111-8111-111111111111',
    );
    expect(candidate.cantonalCommunalTaxableWealthChf, isNull);
  });

  test('computed tax-to-income ratio is typed as average, never marginal', () {
    final result = TaxDeclarationParser.parseTaxDeclaration('''
Revenu imposable: CHF 100'000.00
Impôt cantonal et communal: CHF 15'000.00
Impôt fédéral direct: CHF 5'000.00
''');

    expect(result.diagnostics, hasLength(1));
    expect(
      result.diagnostics.single.code,
      ExtractionDiagnosticCode.taxComputedAverageRateNotMarginal,
    );
    expect(result.diagnostics.single.ratePercent, 20);
    expect(
      result.fields.where(
        (field) => field.profileField == 'actualMarginalRate',
      ),
      isEmpty,
    );
    expect(
      result.fields.where(
        (field) => field.profileField == 'actualAverageRate',
      ),
      isEmpty,
    );
  });

  test('unsourced low, high and deduction heuristics are absent', () {
    for (final text in [
      '''
Revenu imposable: CHF 100'000.00
Impôt cantonal et communal: CHF 1'000.00
Impôt fédéral direct: CHF 1'000.00
''',
      '''
Revenu imposable: CHF 100'000.00
Impôt cantonal et communal: CHF 70'000.00
Impôt fédéral direct: CHF 10'000.00
''',
      '''
Revenu imposable: CHF 100'000.00
Total des déductions effectuées: CHF 70'000.00
''',
    ]) {
      final result = TaxDeclarationParser.parseTaxDeclaration(text);
      expect(
        result.diagnostics.map((diagnostic) => diagnostic.code),
        everyElement(
          ExtractionDiagnosticCode.taxComputedAverageRateNotMarginal,
        ),
      );
    }
  });

  test('cantonal-only and combined tax labels use distinct typed codes', () {
    final cantonalOnly = TaxDeclarationParser.parseTaxDeclaration(
      "Impôt cantonal: CHF 10'000.00",
    ).fields.single;
    final combined = TaxDeclarationParser.parseTaxDeclaration(
      "ICC: CHF 14'520.00",
    ).fields.single;

    expect(
      cantonalOnly.labelCode,
      ExtractionFieldLabelCode.taxCantonalOnlyTax,
    );
    expect(
      combined.labelCode,
      ExtractionFieldLabelCode.taxCantonalCommunalTax,
    );
  });

  test('scan-session sanitization preserves typed labels and diagnostics', () {
    final extraction = TaxDeclarationParser.parseTaxDeclaration(
      "Fortune imposable: CHF -25'000.00",
    );
    final sessions = ScanSessionProvider();
    final id = sessions.retainExtraction(extraction);

    expect(
      sessions.retainImpact(
        id,
        extraction: extraction,
        previousConfidence: 0,
      ),
      isTrue,
    );
    final retained = sessions.byId(id)!.extraction;
    expect(
      retained.fields.single.labelCode,
      ExtractionFieldLabelCode.taxTaxableWealth,
    );
    expect(
      retained.diagnostics.single.code,
      ExtractionDiagnosticCode.taxNegativeWealthNeedsLabelReview,
    );
    expect(retained.fields.single.sourceText, isEmpty);
  });
}
