import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/simulators/buyback_simulator.dart';

void main() {
  // ---------------------------------------------------------------------------
  // BuybackStaggeringResult data class
  // ---------------------------------------------------------------------------
  group('BuybackStaggeringResult — data class', () {
    test('holds all required fields', () {
      final result = BuybackStaggeringResult(
        singleShotTaxSaving: 10000,
        staggeredTotalTaxSaving: 12000,
        delta: 2000,
        disclaimer: 'test disclaimer',
      );
      expect(result.singleShotTaxSaving, 10000);
      expect(result.staggeredTotalTaxSaving, 12000);
      expect(result.delta, 2000);
      expect(result.disclaimer, 'test disclaimer');
    });
  });

  // ---------------------------------------------------------------------------
  // compareStaggering — tax deduction math
  // ---------------------------------------------------------------------------
  group('BuybackSimulator — compareStaggering', () {
    test('staggered saving >= single shot (progressive tax advantage)', () {
      final result = BuybackSimulator.compareStaggering(
        totalBuybackAmount: 100000,
        years: 5,
        taxableIncome: 150000,
        canton: 'VS',
        civilStatus: 'single',
      );
      // Due to tax progressivity, splitting deductions should save more
      expect(result.staggeredTotalTaxSaving,
          greaterThanOrEqualTo(result.singleShotTaxSaving));
    });

    test('delta = staggered - single shot', () {
      final result = BuybackSimulator.compareStaggering(
        totalBuybackAmount: 50000,
        years: 3,
        taxableIncome: 120000,
        canton: 'VS',
        civilStatus: 'single',
      );
      expect(result.delta,
          closeTo(result.staggeredTotalTaxSaving - result.singleShotTaxSaving, 0.01));
    });

    test('single year staggering equals single shot', () {
      final result = BuybackSimulator.compareStaggering(
        totalBuybackAmount: 50000,
        years: 1,
        taxableIncome: 120000,
        canton: 'VS',
        civilStatus: 'single',
      );
      // When years=1, yearly deduction = total, so results should be equal
      expect(result.singleShotTaxSaving,
          closeTo(result.staggeredTotalTaxSaving, 0.01));
      expect(result.delta, closeTo(0, 0.01));
    });

    test('higher income yields higher tax saving', () {
      final lowIncome = BuybackSimulator.compareStaggering(
        totalBuybackAmount: 50000,
        years: 3,
        taxableIncome: 60000,
        canton: 'VS',
        civilStatus: 'single',
      );
      final highIncome = BuybackSimulator.compareStaggering(
        totalBuybackAmount: 50000,
        years: 3,
        taxableIncome: 200000,
        canton: 'VS',
        civilStatus: 'single',
      );
      // Higher income = higher marginal rate = more tax saving
      expect(highIncome.singleShotTaxSaving,
          greaterThan(lowIncome.singleShotTaxSaving));
    });

    test('larger buyback yields larger absolute saving', () {
      final small = BuybackSimulator.compareStaggering(
        totalBuybackAmount: 20000,
        years: 3,
        taxableIncome: 120000,
        canton: 'VS',
        civilStatus: 'single',
      );
      final large = BuybackSimulator.compareStaggering(
        totalBuybackAmount: 100000,
        years: 3,
        taxableIncome: 120000,
        canton: 'VS',
        civilStatus: 'single',
      );
      expect(large.singleShotTaxSaving, greaterThan(small.singleShotTaxSaving));
    });

    test('more years of staggering increases delta advantage', () {
      final short = BuybackSimulator.compareStaggering(
        totalBuybackAmount: 100000,
        years: 2,
        taxableIncome: 150000,
        canton: 'VS',
        civilStatus: 'single',
      );
      final long = BuybackSimulator.compareStaggering(
        totalBuybackAmount: 100000,
        years: 10,
        taxableIncome: 150000,
        canton: 'VS',
        civilStatus: 'single',
      );
      // More years = smaller yearly deduction = stays in higher marginal bracket
      expect(long.delta, greaterThanOrEqualTo(short.delta));
    });

    test('disclaimer mentions pedagogical simulation', () {
      final result = BuybackSimulator.compareStaggering(
        totalBuybackAmount: 50000,
        years: 3,
        taxableIncome: 120000,
        canton: 'VS',
        civilStatus: 'single',
      );
      expect(result.disclaimer, contains('Simulation'));
      expect(result.disclaimer, contains('lissage'));
    });

    test('zero buyback amount returns zero savings', () {
      final result = BuybackSimulator.compareStaggering(
        totalBuybackAmount: 0,
        years: 3,
        taxableIncome: 120000,
        canton: 'VS',
        civilStatus: 'single',
      );
      expect(result.singleShotTaxSaving, 0);
      expect(result.staggeredTotalTaxSaving, 0);
      expect(result.delta, 0);
    });

    test('Julien golden test: 539k rachat over 5 years on 122k income', () {
      final result = BuybackSimulator.compareStaggering(
        totalBuybackAmount: 539414,
        years: 5,
        taxableIncome: 122207,
        canton: 'VS',
        civilStatus: 'married',
      );
      // Verify structure is valid and savings are positive
      expect(result.singleShotTaxSaving, greaterThan(0));
      expect(result.staggeredTotalTaxSaving, greaterThan(0));
      expect(result.delta, greaterThanOrEqualTo(0));
    });
  });
}
