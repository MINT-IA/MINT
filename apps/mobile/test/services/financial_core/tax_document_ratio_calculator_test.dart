import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/tax_document_ratio_calculator.dart';

void main() {
  test('percentOf preserves the parser arithmetic without policy rules', () {
    expect(
      TaxDocumentRatioCalculator.percentOf(amount: 20, reference: 100),
      20,
    );
    expect(
      TaxDocumentRatioCalculator.percentOf(amount: 0, reference: 100),
      0,
    );
    expect(
      TaxDocumentRatioCalculator.percentOf(amount: -5, reference: 100),
      -5,
    );
  });
}
