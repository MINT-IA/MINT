import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/wealth_tax_service.dart';

/// Unit tests for WealthTaxService
///
/// Tests the Swiss wealth tax (impot sur la fortune) and church tax
/// (impot ecclesiastique) calculations across cantons.
/// Sources: OFS Charge Fiscale 2024, lois fiscales cantonales.
void main() {
  group('WealthTaxService.estimateWealthTax', () {
    test('basic estimation — single, 500k, ZG', () {
      final result = WealthTaxService.estimateWealthTax(
        fortune: 500000,
        canton: 'ZG',
      );
      expect(result['canton'], 'ZG');
      expect(result['cantonNom'], 'Zoug');
      expect(result['fortuneNette'], 500000);
      // ZG has 0 exemption, so fortuneImposable = 500000
      expect(result['fortuneImposable'], 500000);
      // Rate at 500k = 1.10 per mille, adjustment = 1.0
      // impot = 500000 * 1.10 / 1000 = 550
      expect(result['impotFortune'], closeTo(550, 1));
      expect(result['tauxEffectifPermille'], closeTo(1.10, 0.01));
    });

    test('all 26 cantons have rates', () {
      expect(WealthTaxService.effectiveWealthTaxRates500k.length, 26);
    });

    test('all 26 cantons have exemption thresholds', () {
      expect(WealthTaxService.wealthTaxExemptions.length, 26);
    });

    test('NW is the cheapest canton (0.75 per mille)', () {
      const rates = WealthTaxService.effectiveWealthTaxRates500k;
      final minRate = rates.values.reduce((a, b) => a < b ? a : b);
      expect(minRate, 0.75);
      expect(rates['NW'], 0.75);
    });

    test('BS is the most expensive canton (5.10 per mille)', () {
      const rates = WealthTaxService.effectiveWealthTaxRates500k;
      final maxRate = rates.values.reduce((a, b) => a > b ? a : b);
      expect(maxRate, 5.10);
      expect(rates['BS'], 5.10);
    });

    test('exemption threshold works — ZH (77k), fortune below', () {
      final result = WealthTaxService.estimateWealthTax(
        fortune: 50000,
        canton: 'ZH',
      );
      expect(result['fortuneImposable'], 0.0);
      expect(result['impotFortune'], 0.0);
    });

    test('exemption threshold works — ZH (77k), fortune above', () {
      final result = WealthTaxService.estimateWealthTax(
        fortune: 100000,
        canton: 'ZH',
      );
      // fortuneImposable = 100000 - 77000 = 23000
      expect(result['fortuneImposable'], 23000);
      expect((result['impotFortune'] as double) > 0, true);
    });

    test('married doubles exemption', () {
      final singleResult = WealthTaxService.estimateWealthTax(
        fortune: 150000,
        canton: 'BE', // exemption = 97000
        etatCivil: 'celibataire',
      );
      final marriedResult = WealthTaxService.estimateWealthTax(
        fortune: 150000,
        canton: 'BE', // exemption doubled = 194000
        etatCivil: 'marie',
      );
      // Single: fortuneImposable = 150000 - 97000 = 53000 > 0
      expect((singleResult['fortuneImposable'] as double) > 0, true);
      // Married: fortuneImposable = 150000 - 194000 = 0 (clamped)
      expect(marriedResult['fortuneImposable'], 0.0);
      expect(marriedResult['impotFortune'], 0.0);
    });

    test('zero fortune = zero tax', () {
      final result = WealthTaxService.estimateWealthTax(
        fortune: 0,
        canton: 'VD',
      );
      expect(result['fortuneImposable'], 0.0);
      expect(result['impotFortune'], 0.0);
    });

    test('high fortune (5M) applies adjustment factor', () {
      final result = WealthTaxService.estimateWealthTax(
        fortune: 5000000,
        canton: 'BS', // highest rate 5.10
      );
      // BS exemption = 100000, fortuneImposable = 4900000
      expect(result['fortuneImposable'], 4900000);
      // Rate = 5.10 * 1.35 (5M adjustment) * 1.0 (single) = 6.885
      expect(result['tauxEffectifPermille'], closeTo(6.885, 0.01));
      // impot = 4900000 * 6.885 / 1000 = 33736.5
      expect(result['impotFortune'], closeTo(33736.5, 1));
    });

    test('low fortune (100k) applies 0.60 adjustment', () {
      final result = WealthTaxService.estimateWealthTax(
        fortune: 100000,
        canton: 'LU', // exemption = 0
      );
      // LU rate = 1.70, adjustment at 100k = 0.60
      // effective rate = 1.70 * 0.60 = 1.02
      expect(result['tauxEffectifPermille'], closeTo(1.02, 0.01));
      // impot = 100000 * 1.02 / 1000 = 102
      expect(result['impotFortune'], closeTo(102, 1));
    });

    test('married gets 10% discount on rate', () {
      final single = WealthTaxService.estimateWealthTax(
        fortune: 500000,
        canton: 'GR', // exemption = 0
        etatCivil: 'celibataire',
      );
      final married = WealthTaxService.estimateWealthTax(
        fortune: 500000,
        canton: 'GR',
        etatCivil: 'marie',
      );
      // Married rate = single rate * 0.90
      final singleRate = single['tauxEffectifPermille'] as double;
      final marriedRate = married['tauxEffectifPermille'] as double;
      expect(marriedRate, closeTo(singleRate * 0.90, 0.001));
    });

    test('canton with zero exemption (LU) taxes from first franc', () {
      final result = WealthTaxService.estimateWealthTax(
        fortune: 10000,
        canton: 'LU',
      );
      expect(result['fortuneImposable'], 10000);
      expect((result['impotFortune'] as double) > 0, true);
    });

    test('unknown canton uses default rate 2.0', () {
      final result = WealthTaxService.estimateWealthTax(
        fortune: 500000,
        canton: 'XX',
      );
      expect(result['tauxEffectifPermille'], closeTo(2.0, 0.01));
    });
  });

  group('WealthTaxService.estimateChurchTax', () {
    test('church tax basic — ZH, 10% of cantonal base', () {
      final result = WealthTaxService.estimateChurchTax(
        impotCantonalCommunal: 10000,
        canton: 'ZH',
      );
      expect(result['churchTaxRate'], 0.10);
      // With default multiplier 1.0: base = 10000, church = 10000 * 0.10 = 1000
      expect(result['impotEglise'], 1000);
      expect(result['isMandatory'], true);
    });

    test('church tax exempt cantons (TI, VD, NE, GE) = 0', () {
      for (final canton in ['TI', 'VD', 'NE', 'GE']) {
        final result = WealthTaxService.estimateChurchTax(
          impotCantonalCommunal: 10000,
          canton: canton,
        );
        expect(result['churchTaxRate'], 0.0,
            reason: '$canton should have 0 church tax rate');
        expect(result['impotEglise'], 0.0,
            reason: '$canton should have 0 church tax');
        expect(result['isMandatory'], false,
            reason: '$canton should not have mandatory church tax');
      }
    });

    test('church tax — SG rate (12%)', () {
      final result = WealthTaxService.estimateChurchTax(
        impotCantonalCommunal: 10000,
        canton: 'SG',
      );
      expect(result['churchTaxRate'], 0.12);
      expect(result['impotEglise'], 1200);
    });

    test('church tax — VS rate (10%)', () {
      final result = WealthTaxService.estimateChurchTax(
        impotCantonalCommunal: 10000,
        canton: 'VS',
        communeMultiplier: 2.35, // Sion
      );
      expect(result['churchTaxRate'], 0.10);
      // base = 10000 / 2.35 ≈ 4255, church = 4255 * 0.10 ≈ 426
      expect((result['impotEglise'] as double), closeTo(426, 1));
    });

    test('all 26 cantons have church tax rates', () {
      expect(WealthTaxService.churchTaxRates.length, 26);
    });
  });

  group('WealthTaxService.compareAllCantons', () {
    test('returns 26 cantons', () {
      final results = WealthTaxService.compareAllCantons(fortune: 500000);
      expect(results.length, 26);
    });

    test('results are sorted ascending by impotFortune', () {
      final results = WealthTaxService.compareAllCantons(fortune: 500000);
      for (int i = 0; i < results.length - 1; i++) {
        expect(
          (results[i]['impotFortune'] as double) <=
              (results[i + 1]['impotFortune'] as double),
          true,
          reason:
              '${results[i]['canton']} should be <= ${results[i + 1]['canton']}',
        );
      }
    });

    test('first canton has rang 1', () {
      final results = WealthTaxService.compareAllCantons(fortune: 500000);
      expect(results.first['rang'], 1);
    });

    test('first canton has differenceVsPremier = 0', () {
      final results = WealthTaxService.compareAllCantons(fortune: 500000);
      expect(results.first['differenceVsPremier'], 0.0);
    });

    test('NW should be ranked first or very low at 500k', () {
      final results = WealthTaxService.compareAllCantons(fortune: 500000);
      final nw = results.firstWhere((c) => c['canton'] == 'NW');
      // NW has the lowest rate (0.75) — should be near the top
      expect((nw['rang'] as int) <= 3, true);
    });

    test('BS should be ranked last or near last at 500k', () {
      final results = WealthTaxService.compareAllCantons(fortune: 500000);
      final bs = results.firstWhere((c) => c['canton'] == 'BS');
      // BS has the highest rate (5.10) — should be near bottom
      expect((bs['rang'] as int) >= 24, true);
    });

    test('zero fortune returns all zeros', () {
      final results = WealthTaxService.compareAllCantons(fortune: 0);
      for (final r in results) {
        expect(r['impotFortune'], 0.0);
      }
    });
  });
}
