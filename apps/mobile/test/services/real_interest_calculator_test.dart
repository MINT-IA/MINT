import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/simulators/real_interest_calculator.dart';

void main() {
  // ---------------------------------------------------------------------------
  // RealInterestSimulationResult data class
  // ---------------------------------------------------------------------------
  group('RealInterestSimulationResult — structure', () {
    test('contains netInvested and 3 scenarios', () {
      final result = RealInterestCalculator.simulate(
        amountInvested: 7258,
        marginalTaxRate: 0.25,
        investmentDurationYears: 20,
      );
      expect(result.netInvested, isNotNull);
      expect(result.pessimistic, isNotNull);
      expect(result.neutral, isNotNull);
      expect(result.optimistic, isNotNull);
    });

    test('assumptions map contains expected keys', () {
      final result = RealInterestCalculator.simulate(
        amountInvested: 7258,
        marginalTaxRate: 0.25,
        investmentDurationYears: 20,
      );
      expect(result.assumptions.containsKey('tax_rate_used'), isTrue);
      expect(result.assumptions.containsKey('pessimistic_rate'), isTrue);
      expect(result.assumptions.containsKey('neutral_rate'), isTrue);
      expect(result.assumptions.containsKey('optimistic_rate'), isTrue);
      expect(result.assumptions.containsKey('duration_years'), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Net invested calculation (tax lever effect)
  // ---------------------------------------------------------------------------
  group('RealInterestCalculator — net invested', () {
    test('net = amount - (amount * taxRate)', () {
      final result = RealInterestCalculator.simulate(
        amountInvested: 7258,
        marginalTaxRate: 0.25,
        investmentDurationYears: 20,
      );
      // 7258 - (7258 * 0.25) = 7258 - 1814.5 = 5443.5
      expect(result.netInvested, closeTo(5443.5, 0.1));
    });

    test('zero tax rate means net = gross', () {
      final result = RealInterestCalculator.simulate(
        amountInvested: 10000,
        marginalTaxRate: 0.0,
        investmentDurationYears: 10,
      );
      expect(result.netInvested, 10000);
    });

    test('100% tax rate means net = 0', () {
      final result = RealInterestCalculator.simulate(
        amountInvested: 10000,
        marginalTaxRate: 1.0,
        investmentDurationYears: 10,
      );
      expect(result.netInvested, 0);
    });

    test('Julien golden: 30% marginal on 7258 CHF 3a', () {
      final result = RealInterestCalculator.simulate(
        amountInvested: 7258,
        marginalTaxRate: 0.30,
        investmentDurationYears: 16, // 49 yo -> 65
      );
      // Net = 7258 * 0.70 = 5080.6
      expect(result.netInvested, closeTo(5080.6, 0.1));
    });
  });

  // ---------------------------------------------------------------------------
  // Compound interest (capital growth)
  // ---------------------------------------------------------------------------
  group('RealInterestCalculator — compound interest', () {
    test('pessimistic < neutral < optimistic capital', () {
      final result = RealInterestCalculator.simulate(
        amountInvested: 10000,
        marginalTaxRate: 0.25,
        investmentDurationYears: 20,
      );
      expect(result.pessimistic.totalCapital,
          lessThan(result.neutral.totalCapital));
      expect(result.neutral.totalCapital,
          lessThan(result.optimistic.totalCapital));
    });

    test('capital with 0 years = principal unchanged', () {
      final result = RealInterestCalculator.simulate(
        amountInvested: 10000,
        marginalTaxRate: 0.25,
        investmentDurationYears: 0,
      );
      // Compound interest with 0 years returns principal
      expect(result.neutral.totalCapital, closeTo(10000, 0.01));
    });

    test('default rates are 2%, 4%, 6%', () {
      final result = RealInterestCalculator.simulate(
        amountInvested: 10000,
        marginalTaxRate: 0.0,
        investmentDurationYears: 10,
      );
      // With 0% tax, net = 10000 = gross
      // Pessimistic: 10000 * 1.02^10
      expect(result.pessimistic.totalCapital,
          closeTo(10000 * pow(1.02, 10), 0.01));
      // Neutral: 10000 * 1.04^10
      expect(result.neutral.totalCapital,
          closeTo(10000 * pow(1.04, 10), 0.01));
      // Optimistic: 10000 * 1.06^10
      expect(result.optimistic.totalCapital,
          closeTo(10000 * pow(1.06, 10), 0.01));
    });

    test('custom yield rates override defaults', () {
      final result = RealInterestCalculator.simulate(
        amountInvested: 10000,
        marginalTaxRate: 0.0,
        investmentDurationYears: 10,
        customYieldPessimistic: 0.01,
        customYieldNeutral: 0.03,
        customYieldOptimistic: 0.05,
      );
      expect(result.pessimistic.totalCapital,
          closeTo(10000 * pow(1.01, 10), 0.01));
      expect(result.neutral.totalCapital,
          closeTo(10000 * pow(1.03, 10), 0.01));
      expect(result.optimistic.totalCapital,
          closeTo(10000 * pow(1.05, 10), 0.01));
    });
  });

  // ---------------------------------------------------------------------------
  // Effective yield (CAGR on net invested)
  // ---------------------------------------------------------------------------
  group('RealInterestCalculator — effective yield (CAGR)', () {
    test('effective yield > market yield due to tax lever', () {
      final result = RealInterestCalculator.simulate(
        amountInvested: 10000,
        marginalTaxRate: 0.30,
        investmentDurationYears: 20,
      );
      // With 30% tax saving, net = 7000 but capital grows on 10000
      // So effective yield (based on net) > nominal market yield
      expect(result.neutral.effectiveYield, greaterThan(0.04));
    });

    test('effective yield equals market yield when tax rate = 0', () {
      final result = RealInterestCalculator.simulate(
        amountInvested: 10000,
        marginalTaxRate: 0.0,
        investmentDurationYears: 20,
      );
      // No tax lever: effective yield = market yield
      expect(result.neutral.effectiveYield, closeTo(0.04, 0.001));
    });

    test('effective yield is 0 when duration is 0', () {
      final result = RealInterestCalculator.simulate(
        amountInvested: 10000,
        marginalTaxRate: 0.25,
        investmentDurationYears: 0,
      );
      // CAGR with 0 years returns 0
      expect(result.neutral.effectiveYield, 0.0);
    });

    test('effective yield is 0 when net invested is 0 (100% tax)', () {
      final result = RealInterestCalculator.simulate(
        amountInvested: 10000,
        marginalTaxRate: 1.0,
        investmentDurationYears: 20,
      );
      // start <= 0, CAGR returns 0
      expect(result.neutral.effectiveYield, 0.0);
    });
  });
}
