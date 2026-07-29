import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

void main() {
  group('RetirementTaxCalculator.capitalWithdrawalTax', () {
    test('zero capital → zero tax', () {
      final tax = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: 0,
        canton: 'ZH',
      );
      expect(tax, equals(0));
    });

    test('small capital (50k) → interpolation sous 100k', () {
      final tax = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: 50000,
        canton: 'ZH',
      );
      // v2 -2i2 : ZH 50000 — IFD art. 38 (1/5) + cantonal ESTV interpolé
      expect(tax, closeTo(2220.168, 1));
    });

    test('medium capital (150k) → progressif', () {
      final tax = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: 150000,
        canton: 'ZH',
      );
      // v2 -2i2 : ZH 150000
      expect(tax, closeTo(7835.128, 1));
    });

    test('large capital (500k) → progressif', () {
      final tax = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: 500000,
        canton: 'ZH',
      );
      // v2 -2i2 : ZH 500000
      expect(tax, closeTo(35067.688, 1));
    });

    test('married differentiation per cantonal ESTV schedule', () {
      // Triage AnnAssign #1095 + CAP-1 #1098 : grille 7 noeuds (350k ajouté).
      // ZH 300000 interpole 250k->350k où ZH marié == célibataire au cantonal
      // -> seule l'IFD marié réduit -> ratio 0.9865 (plus proche d'1 qu'avant :
      // ESTV ne réduit pas ZH ≤ 350k au cantonal).
      final single = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: 300000,
        canton: 'ZH',
        isMarried: false,
      );
      final married = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: 300000,
        canton: 'ZH',
        isMarried: true,
      );
      expect(married, lessThan(single));
      expect(married / single, closeTo(0.9865, 0.01));

      // VS 300000 : ratio 0.9731, DIFFÉRENT de ZH -> la différenciation par
      // canton (effet de barème ESTV) est préservée.
      final marriedVS = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: 300000, canton: 'VS', isMarried: true,
      );
      final singleVS = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: 300000, canton: 'VS', isMarried: false,
      );
      expect(marriedVS / singleVS, closeTo(0.9731, 0.01));
    });

    test('VD has highest rate', () {
      final zh = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: 200000,
        canton: 'ZH',
      );
      final vd = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: 200000,
        canton: 'VD',
      );
      expect(vd, greaterThan(zh));
    });
  });

  group('RetirementTaxCalculator.progressiveTax', () {
    test('bracket boundaries', () {
      // At 100k boundary: all at 1.0×
      final at100k = RetirementTaxCalculator.progressiveTax(100000, 0.065);
      expect(at100k, closeTo(6500, 1));

      // At 200k: 100k×1.0 + 100k×1.15
      final at200k = RetirementTaxCalculator.progressiveTax(200000, 0.065);
      expect(at200k, closeTo(13975, 1));
    });
  });
}
