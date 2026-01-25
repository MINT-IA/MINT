import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/tax_estimator_service.dart';

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
}
