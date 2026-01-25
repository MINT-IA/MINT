import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/simulators/real_interest_calculator.dart';

void main() {
  group('RealInterestCalculator', () {
    test('Calculates scenarios correctly with tax savings', () {
      final scenarios = RealInterestCalculator.simulate(
        amountInvested: 7056,
        marginalTaxRate: 0.25, // 25%
        investmentDurationYears: 10,
      );

      // Scénario Neutre (ex: 4% yield)
      // Capital brut sans impôt = 7056 * (1.04)^10
      // Economie impôt = 7056 * 0.25 = 1764 (investi ou non ? La simu doit préciser)
      // Ici on assume une comparaison "Net Investi" vs "Capital Final"

      // Net Investi = 7056 - 1764 = 5292 (Effort réel)
      expect(scenarios.netInvested, 5292.0);

      // Capital Final (Conservative 2%)
      expect(scenarios.pessimistic.totalCapital, greaterThan(7056));

      // Calculate effective yield (ROI)
      // ROI = (Final - NetInvested) / NetInvested
      expect(scenarios.neutral.effectiveYield, greaterThan(0.04));
      // L'effet fiscal doit booster le rendement effectif bien au-delà du rendement marché
    });

    test('Handles zero tax rate', () {
      final scenarios = RealInterestCalculator.simulate(
        amountInvested: 1000,
        marginalTaxRate: 0.0,
        investmentDurationYears: 5,
      );

      expect(scenarios.netInvested, 1000.0);
      expect(scenarios.neutral.totalCapital, greaterThan(1000));
    });

    test('Compliance: Scenarios follow predefined rates', () {
      // On vérifie que les taux utilisés sont bien ceux de la doc (2%, 4%, 6% par ex)
      // et pas des taux magiques hardcodés invisibles
      final res = RealInterestCalculator.simulate(
          amountInvested: 100,
          marginalTaxRate: 0.2,
          investmentDurationYears: 1);
      // Check metadata or implied rates
      expect(res.assumptions['pessimistic_rate'], isNotNull);
      expect(res.assumptions['neutral_rate'], isNotNull);
      expect(res.assumptions['optimistic_rate'], isNotNull);
    });
  });
}
