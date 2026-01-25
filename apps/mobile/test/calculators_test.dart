import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/domain/calculators.dart';

void main() {
  group('Compound Interest Calculator', () {
    test('basic compound interest calculation', () {
      final result = calculateCompoundInterest(
        principal: 10000,
        monthlyContribution: 0,
        annualRate: 5.0,
        years: 10,
      );

      // 10000 * (1 + 0.05/12)^120 ≈ 16470
      expect(result['finalValue'], greaterThan(16000));
      expect(result['finalValue'], lessThan(17000));
      expect(result['totalInvested'], equals(10000));
      expect(result['gains'], greaterThan(6000));
    });

    test('compound with monthly contributions', () {
      final result = calculateCompoundInterest(
        principal: 0,
        monthlyContribution: 500,
        annualRate: 5.0,
        years: 20,
      );

      // Total invested = 500 * 240 = 120000
      expect(result['totalInvested'], equals(120000));
      // With 5% compound, should be significantly more
      expect(result['finalValue'], greaterThan(200000));
      expect(result['gains'], greaterThan(80000));
    });

    test('zero rate returns sum of contributions', () {
      final result = calculateCompoundInterest(
        principal: 1000,
        monthlyContribution: 100,
        annualRate: 0,
        years: 5,
      );

      // Should just sum up: 1000 + 100 * 60 = 7000
      expect(result['finalValue'], equals(7000));
      expect(result['gains'], equals(0));
    });
  });

  group('Leasing Opportunity Cost Calculator', () {
    test('calculates total leasing cost', () {
      final result = calculateLeasingOpportunityCost(
        monthlyPayment: 400,
        durationMonths: 48,
        alternativeAnnualRate: 5.0,
      );

      expect(result['totalLeasingCost'], equals(400 * 48));
    });

    test('returns opportunity cost for multiple projections', () {
      final result = calculateLeasingOpportunityCost(
        monthlyPayment: 400,
        durationMonths: 48,
        alternativeAnnualRate: 5.0,
      );

      final opportunityCost = result['opportunityCost'] as Map<String, double>;
      expect(opportunityCost.containsKey('5y'), isTrue);
      expect(opportunityCost.containsKey('10y'), isTrue);
      expect(opportunityCost.containsKey('20y'), isTrue);
      
      // 10 year opportunity cost should be significant
      expect(opportunityCost['10y'], greaterThan(50000));
    });
  });

  group('3a Tax Benefit Calculator', () {
    test('calculates annual tax savings', () {
      final result = calculate3aTaxBenefit(
        annualContribution: 7056,
        marginalTaxRate: 0.25,
        years: 30,
        annualReturn: 4.0,
      );

      // Annual tax saved = 7056 * 0.25 = 1764
      expect(result['annualTaxSaved'], equals(1764.0));
    });

    test('calculates total tax savings over period', () {
      final result = calculate3aTaxBenefit(
        annualContribution: 7056,
        marginalTaxRate: 0.25,
        years: 30,
        annualReturn: 4.0,
      );

      // Total tax saved = 1764 * 30 = 52920
      expect(result['totalTaxSavedOverPeriod'], equals(1764 * 30));
    });

    test('calculates total contributions', () {
      final result = calculate3aTaxBenefit(
        annualContribution: 7056,
        marginalTaxRate: 0.25,
        years: 30,
        annualReturn: 4.0,
      );

      expect(result['totalContributions'], equals(7056 * 30));
    });

    test('calculates potential final value with compound', () {
      final result = calculate3aTaxBenefit(
        annualContribution: 7056,
        marginalTaxRate: 0.25,
        years: 30,
        annualReturn: 4.0,
      );

      // With 4% return over 30 years, should be > 400k
      expect(result['potentialFinalValue'], greaterThan(400000));
    });
  });
}
