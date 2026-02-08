import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/tax_estimator_service.dart';
import 'package:mint_mobile/services/tax_scales_loader.dart';
import 'package:mint_mobile/data/average_tax_multipliers.dart';

void main() {
  group('TaxEstimatorService Tests', () {
    test('calculateMarginalTaxRate returns reasonable values for VD', () {
      final rate = TaxEstimatorService.estimateMarginalTaxRate(
        netMonthlyIncome: 8000.0, // ~96k annual net -> ~113k gross
        cantonCode: 'VD',
        civilStatus: 'single',
      );

      // VD is high tax. Gross ~113k.
      // Base rate ~15% * VD Factor 1.3 * Family 1.0 = ~19.5% effective.
      // Marginal ~ 1.4 * 19.5% = ~27%
      expect(rate, inInclusiveRange(0.20, 0.35));
    });

    test('calculateMarginalTaxRate lower for ZG', () {
      final rateZG = TaxEstimatorService.estimateMarginalTaxRate(
        netMonthlyIncome: 8000.0,
        cantonCode: 'ZG',
        civilStatus: 'single',
      );

      final rateVD = TaxEstimatorService.estimateMarginalTaxRate(
        netMonthlyIncome: 8000.0,
        cantonCode: 'VD',
        civilStatus: 'single',
      );

      expect(rateZG, lessThan(rateVD));
    });

    test('calculateTaxSavings returns correct amount', () {
      final savings = TaxEstimatorService.calculateTaxSavings(7000, 0.25);
      expect(savings, 1750.0);
    });
  });

  group('TaxScalesLoader tariff normalization', () {
    setUp(() {
      // Minimal fixture: VD uses "Single, with / no children" and "Married"
      // GE uses "All"
      TaxScalesLoader.init({
        'Vaud': [
          ["Income tax", "Married", "Canton", "100", "1.00", "1"],
          ["Income tax", "Married", "Canton", "1'600", "2.00", "16"],
          [
            "Income tax",
            "Single, with / no children",
            "Canton",
            "100",
            "1.00",
            "1"
          ],
          [
            "Income tax",
            "Single, with / no children",
            "Canton",
            "1'600",
            "2.00",
            "16"
          ],
        ],
        'Geneva': [
          ["Income tax", "All", "Canton", "0", "0.00", "0"],
          ["Income tax", "All", "Canton", "18'649", "7.30", "0"],
          ["Income tax", "All", "Canton", "22'469", "8.20", "279"],
        ],
      });
    });

    test('VD brackets are found (not fallback)', () {
      final brackets =
          TaxScalesLoader.getBrackets('Vaud', 'Single, no children');
      expect(brackets, isNotEmpty,
          reason: 'VD doit matcher avec normalisation');
    });

    test('VD married brackets are found', () {
      final brackets =
          TaxScalesLoader.getBrackets('Vaud', 'Married/Single, with children');
      expect(brackets, isNotEmpty,
          reason: 'VD Married doit matcher avec normalisation');
    });

    test('GE brackets are found (not fallback)', () {
      final brackets =
          TaxScalesLoader.getBrackets('Geneva', 'Single, no children');
      expect(brackets, isNotEmpty,
          reason: 'GE "All" doit matcher via fallback');
    });

    test('GE married brackets are found', () {
      final brackets = TaxScalesLoader.getBrackets(
          'Geneva', 'Married/Single, with children');
      expect(brackets, isNotEmpty,
          reason: 'GE "All" doit matcher via fallback pour maries aussi');
    });
  });

  group('AverageTaxMultipliers corrections', () {
    test('BS multiplicateur is 1.00', () {
      final mult = AverageTaxMultipliers.get('BS');
      expect(mult, 1.00);
    });

    test('LU multiplicateur is 3.35', () {
      final mult = AverageTaxMultipliers.get('LU');
      expect(mult, 3.35);
    });
  });

  group('GE splitting for married couples', () {
    setUp(() {
      // GE fixture: tariff "All" with progressive brackets
      TaxScalesLoader.init({
        'GE': [
          ["Income tax", "All", "Canton", "0", "0.00", "0"],
          ["Income tax", "All", "Canton", "18'649", "7.30", "0"],
          ["Income tax", "All", "Canton", "22'469", "8.20", "279"],
          ["Income tax", "All", "Canton", "26'962", "10.00", "668"],
          ["Income tax", "All", "Canton", "50'000", "12.00", "2'972"],
        ],
      });
    });

    test('GE married tax is lower than single (splitting effect)', () {
      final taxSingle = TaxEstimatorService.estimateAnnualTax(
        netMonthlyIncome: 8000,
        cantonCode: 'GE',
        civilStatus: 'single',
        childrenCount: 0,
        age: 40,
      );
      final taxMarried = TaxEstimatorService.estimateAnnualTax(
        netMonthlyIncome: 8000,
        cantonCode: 'GE',
        civilStatus: 'married',
        childrenCount: 0,
        age: 40,
      );
      expect(taxMarried, lessThan(taxSingle),
          reason: 'GE splitting should reduce ICC for married couples');
    });
  });

  group('IFD (impôt fédéral direct) — LIFD art. 36', () {
    test('IFD single 80k CHF', () {
      // Manual calculation from brackets:
      // 0-14500: 0, 14500-31600: 131.67, 31600-41400: 86.24,
      // 41400-55200: 364.32, 55200-72500: 513.81,
      // 72500-78100: 332.64, 78100-80000: 125.40
      // Total: ~1554
      final ifd =
          TaxEstimatorService.estimateFederalTax(80000, 'single');
      expect(ifd, closeTo(1554, 50));
    });

    test('IFD married 120k CHF', () {
      // Manual calculation from brackets:
      // 0-28300: 0, 28300-50900: 226, 50900-58400: 150,
      // 58400-75300: 507, 75300-90300: 600,
      // 90300-103400: 655, 103400-114700: 678,
      // 114700-120000: 371
      // Total: ~3187
      final ifd =
          TaxEstimatorService.estimateFederalTax(120000, 'married');
      expect(ifd, closeTo(3187, 50));
    });

    test('IFD single 0 = 0', () {
      final ifd =
          TaxEstimatorService.estimateFederalTax(0, 'single');
      expect(ifd, 0);
    });

    test('IFD with child deduction', () {
      final ifdNoChild =
          TaxEstimatorService.estimateFederalTax(80000, 'married');
      final ifd2Children =
          TaxEstimatorService.estimateFederalTax(80000, 'married',
              childrenCount: 2);
      // 2 children * 259 CHF = 518 CHF deduction
      expect(ifdNoChild - ifd2Children, closeTo(518, 1));
    });

    test('IFD child deduction cannot make tax negative', () {
      // Very low income married with children -> tax should be 0, not negative
      final ifd = TaxEstimatorService.estimateFederalTax(30000, 'married',
          childrenCount: 3);
      expect(ifd, greaterThanOrEqualTo(0));
    });
  });
}
