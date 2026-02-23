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

    test('small capital (50k) → base rate × 1.0', () {
      final tax = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: 50000,
        canton: 'ZH', // 6.5%
      );
      // 50000 * 0.065 * 1.0 = 3250
      expect(tax, closeTo(3250, 1));
    });

    test('medium capital (150k) → progressive brackets', () {
      final tax = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: 150000,
        canton: 'ZH', // 6.5%
      );
      // Bracket 1: 100k * 0.065 * 1.0 = 6500
      // Bracket 2: 50k * 0.065 * 1.15 = 3737.5
      // Total: 10237.5
      expect(tax, closeTo(10237.5, 1));
    });

    test('large capital (500k) → higher brackets', () {
      final tax = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: 500000,
        canton: 'ZH', // 6.5%
      );
      // 100k × 1.0 + 100k × 1.15 + 300k × 1.30 = 6500 + 7475 + 25350 = 39325
      expect(tax, closeTo(39325, 1));
    });

    test('married discount applied', () {
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
      // Married gets 15% discount on base rate
      expect(married, lessThan(single));
      expect(married / single, closeTo(0.85, 0.01));
    });

    test('VD has highest rate', () {
      final zh = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: 200000,
        canton: 'ZH', // 6.5%
      );
      final vd = RetirementTaxCalculator.capitalWithdrawalTax(
        capitalBrut: 200000,
        canton: 'VD', // 8.0%
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
