import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/mortgage_purchase_capacity_calculator.dart';

void main() {
  group('MortgagePurchaseCapacityCalculator', () {
    test('requires both income and own funds', () {
      final withoutIncome = MortgagePurchaseCapacityCalculator.calculate(
        annualGrossIncome: 0,
        liquidSavings: 100000,
        pillar3aAssets: 20000,
        pensionFundAssets: 50000,
      );
      final withoutEquity = MortgagePurchaseCapacityCalculator.calculate(
        annualGrossIncome: 96000,
        liquidSavings: 0,
        pillar3aAssets: 0,
        pensionFundAssets: 0,
      );

      expect(withoutIncome.maximumPurchasePrice, 0);
      expect(withoutEquity.maximumPurchasePrice, 0);
    });

    test('never returns a negative purchase price', () {
      final result = MortgagePurchaseCapacityCalculator.calculate(
        annualGrossIncome: -1,
        liquidSavings: -1,
        pillar3aAssets: -1,
        pensionFundAssets: -1,
      );

      expect(result.maximumPurchasePrice, 0);
    });

    test('uses the regulatory income and equity constraints', () {
      final result = MortgagePurchaseCapacityCalculator.calculate(
        annualGrossIncome: 96000,
        liquidSavings: 80000,
        pillar3aAssets: 20000,
        pensionFundAssets: 50000,
      );

      expect(result.maximumPurchasePrice, closeTo(585714.2857142857, 0.01));
      expect(result.isRevenueConstrained, isTrue);
    });

    test('caps second-pillar assets under the existing mortgage rules', () {
      final result = MortgagePurchaseCapacityCalculator.calculate(
        annualGrossIncome: 200000,
        liquidSavings: 50000,
        pillar3aAssets: 30000,
        pensionFundAssets: 500000,
      );

      expect(result.maximumPurchasePrice, closeTo(800000, 0.01));
      expect(result.isRevenueConstrained, isFalse);
    });
  });
}
