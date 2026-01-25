import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/simulators/buyback_simulator.dart';

void main() {
  group('BuybackSimulator (Staggered)', () {
    test('Single shot vs Staggered comparison', () {
      final result = BuybackSimulator.compareStaggering(
        totalBuybackAmount: 100000,
        years: 5,
        taxableIncome: 150000,
        canton: 'VD',
        civilStatus: 'married',
      );

      // Single Shot: 150k - 100k = 50k taxable.
      // Tax on 150k: High. Tax on 50k: Low. Delta is valid saving.

      // Staggered: 150k - 20k (x5 years).
      // Tax on 130k is higher than on 50k, but paid 5 times.
      // Due to progressivity, saving 20k off the top bracket 5 times
      // is usually NOT better than saving 100k off the top??
      // WAIT. In Swiss tax, breaking progressivity usually means:
      // Avoiding the very high brackets in a single year?
      // Actually, deducting 100k in one year might bring you to a very low bracket (effective rate drops massive).
      // Deducting 20k 5 times keeps you in a relatively high bracket but reduces taxable base.

      // CORRECTION: Standard advice is staggering withdrawals (to avoid high capital tax).
      // For BUYBACKS (deductions), is it better to stagger?
      // Generally YES if it allows staying under a certain break point, OR
      // NO if you want to crush the income to zero?
      // Actually, for buybacks, since tax is progressive, a massive deduction MIGHT be less efficient if it "wastes" the deduction on low-tax-rate income portions.
      // Actually, for buybacks, since tax is progressive, a massive deduction MIGHT be less efficient if it "wastes" the deduction on low-tax-rate-income portions.
      // Example: Income 100k. Tax 10k.
      // Deduct 100k -> Income 0. Save 10k.
      // Deduct 20k (Income 80k) -> Tax 7k. Save 3k. x 5 years = Save 15k.
      // YES! Staggering buybacks IS usually better because you deduct against the highest marginal rate every year,
      // instead of using the deduction against lower brackets in a single year.

      print('Delta: ${result.delta}');
      expect(result.delta, greaterThan(0),
          reason: 'Delta should be positive (Staggered > Single)');
    });

    test('Disclaimer existence', () {
      final result = BuybackSimulator.compareStaggering(
        totalBuybackAmount: 10000,
        years: 3,
        taxableIncome: 100000,
        canton: 'GE',
        civilStatus: 'single',
      );

      expect(result.disclaimer, contains("Sous réserve d'acceptation"));
    });
  });
}
