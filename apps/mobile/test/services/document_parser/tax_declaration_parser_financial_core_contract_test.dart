import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tax parser delegates its only retained ratio to financial_core', () {
    final source = File(
      'lib/services/document_parser/tax_declaration_parser.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(
        "import 'package:mint_mobile/services/financial_core/"
        "tax_document_ratio_calculator.dart';",
      ),
    );
    expect(
      RegExp(r'TaxDocumentRatioCalculator\.percentOf\(').allMatches(source),
      hasLength(1),
    );
    expect(source, isNot(matches(RegExp(r'totalImpot\s*/\s*revenu'))));
    expect(source, isNot(matches(RegExp(r'deductions\s*/\s*revenu'))));
  });
}
