import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/document_parser/tax_declaration_parser.dart';

const _snapshotId = '11111111-1111-4111-8111-111111111111';

void main() {
  test('machine regex source preserves readable OCR lexemes and captures', () {
    final source = File(
      'lib/services/document_parser/tax_declaration_parser.dart',
    ).readAsStringSync();
    final machineStart = source.indexOf(
      'static final List<_TaxFieldPattern> _knownFieldPatterns',
    );
    final machineEnd = source.indexOf(
      'static ExtractionResult parseTaxDeclaration',
    );

    expect(machineStart, greaterThanOrEqualTo(0));
    expect(machineEnd, greaterThan(machineStart));
    final machineSource = source.substring(machineStart, machineEnd);
    for (final expectedFragment in const [
      r'p[eé]riode\s+fiscale',
      r'imp[oô]t\s+cantonal\s+et\s+communal',
      r'imp[oô]t\s+cantonal(?!\s+et\s+communal)',
      r'imp[oô]t\s+f[eé]d[eé]ral\s+direct',
      r"d[eé]claration\s+d[’' ]?imp[oô]t",
      r'd[eé]cision\s+de\s+taxation',
      r'[eé]mis\s+le',
      r'taxation\s+commune\s+des\s+[eé]poux',
    ]) {
      expect(machineSource, contains(expectedFragment));
    }
  });

  test('readable patterns preserve accented French and German OCR matches', () {
    final candidate = TaxDeclarationParser.parseTaxDocument(
      '''
Décision de taxation
Période fiscale: 2025
Émis le: 12.03.2026
Taxation commune des époux
Revenu imposable ICC: CHF 100'000
Fortune imposable ICC: CHF 250'000
Impôt cantonal et communal, sur le revenu et fortune: CHF 18'000
Impôt fédéral direct sur le revenu: CHF 4'000
''',
      snapshotIdFactory: () => _snapshotId,
    );

    expect(candidate.documentKind, TaxDocumentKind.assessmentNotice);
    expect(candidate.taxYear, 2025);
    expect(candidate.sourceDate, DateTime.utc(2026, 3, 12));
    expect(candidate.subjectScope, TaxSubjectScope.jointlyAssessedCouple);
    expect(candidate.cantonalCommunalTaxableIncomeChf, 100000);
    expect(candidate.cantonalCommunalTaxableWealthChf, 250000);
    expect(candidate.cantonalCommunalAssessedTax?.amountChf, 18000);
    expect(candidate.federalDirectAssessedTax?.amountChf, 4000);

    final german = TaxDeclarationParser.parseTaxDocument(
      '''
Steuererklärung
Steuerbares Vermögen Kanton: CHF 300'000
Kantons- und Gemeindesteuer Vermögen: CHF 2'500
''',
      snapshotIdFactory: () => _snapshotId,
    );
    expect(german.documentKind, TaxDocumentKind.taxpayerReturn);
    expect(german.cantonalCommunalTaxableWealthChf, 300000);
    expect(german.cantonalCommunalAssessedTax?.amountChf, 2500);
  });
}
