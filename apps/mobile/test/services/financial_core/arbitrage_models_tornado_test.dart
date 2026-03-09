import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';

void main() {
  group('parseArbitrageTornado', () {
    test('parses normalized tornado keys and sorts by swing desc', () {
      final parsed = parseArbitrageTornado({
        'tornado_rendement_marche_base': 120000,
        'tornado_rendement_marche_low': 100000,
        'tornado_rendement_marche_high': 140000,
        'tornado_rendement_marche_swing': 40000,
        'tornado_rendement_marche_assumption_low': 0.03,
        'tornado_rendement_marche_assumption_high': 0.05,
        'tornado_taux_marginal_base': 120000,
        'tornado_taux_marginal_low': 112000,
        'tornado_taux_marginal_high': 128000,
        'tornado_taux_marginal_swing': 16000,
        'tornado_taux_marginal_assumption_low': 0.25,
        'tornado_taux_marginal_assumption_high': 0.29,
      });

      expect(parsed, hasLength(2));
      expect(parsed.first.key, 'rendement_marche');
      expect(parsed.first.swing, 40000);
      expect(parsed.first.lowLabel, '3.0%');
      expect(parsed.first.highLabel, '5.0%');
    });

    test('ignores incomplete variables', () {
      final parsed = parseArbitrageTornado({
        'tornado_rendement_marche_base': 100000,
        'tornado_rendement_marche_low': 90000,
        // missing `high`
      });

      expect(parsed, isEmpty);
    });

    test('formats CHF assumptions for capital_total', () {
      final parsed = parseArbitrageTornado({
        'tornado_capital_total_base': 50000,
        'tornado_capital_total_low': 45000,
        'tornado_capital_total_high': 55000,
        'tornado_capital_total_assumption_low': 450000,
        'tornado_capital_total_assumption_high': 550000,
      });

      expect(parsed.single.key, 'capital_total');
      expect(parsed.single.lowLabel, startsWith('CHF\u00a0'));
      expect(parsed.single.highLabel, startsWith('CHF\u00a0'));
    });
  });
}
