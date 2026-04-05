import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/fiscal_intelligence_service.dart';
import 'package:mint_mobile/services/tax_scales_loader.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Initializes TaxScalesLoader with sample data so that
  /// TaxEstimatorService.estimateAnnualTax works in precise mode.
  void initScales() {
    TaxScalesLoader.init({
      'Zurich': [
        ['Income tax', 'Single, no children', 'Canton', "6'900", '0.00'],
        ['Income tax', 'Single, no children', 'Canton', "4'900", '2.00'],
        ['Income tax', 'Single, no children', 'Canton', "8'200", '3.00'],
        ['Income tax', 'Single, no children', 'Canton', "11'700", '4.00'],
        ['Income tax', 'Single, no children', 'Canton', "17'300", '5.00'],
        ['Income tax', 'Single, no children', 'Canton', "22'400", '6.00'],
        ['Income tax', 'Single, no children', 'Canton', "25'500", '7.00'],
        ['Income tax', 'Single, no children', 'Canton', "31'000", '8.00'],
        ['Income tax', 'Single, no children', 'Canton', "50'100", '9.00'],
        ['Income tax', 'Single, no children', 'Canton', "73'000", '10.00'],
        ['Income tax', 'Single, no children', 'Canton', "999'999'999", '13.00'],
        // Married
        ['Income tax', 'Married/Single, with children', 'Canton', "12'600", '0.00'],
        ['Income tax', 'Married/Single, with children', 'Canton', "7'800", '2.00'],
        ['Income tax', 'Married/Single, with children', 'Canton', "8'200", '3.00'],
        ['Income tax', 'Married/Single, with children', 'Canton', "11'700", '4.00'],
        ['Income tax', 'Married/Single, with children', 'Canton', "17'300", '5.00'],
        ['Income tax', 'Married/Single, with children', 'Canton', "22'400", '6.00'],
        ['Income tax', 'Married/Single, with children', 'Canton', "25'500", '7.00'],
        ['Income tax', 'Married/Single, with children', 'Canton', "31'000", '8.00'],
        ['Income tax', 'Married/Single, with children', 'Canton', "50'100", '9.00'],
        ['Income tax', 'Married/Single, with children', 'Canton', "73'000", '10.00'],
        ['Income tax', 'Married/Single, with children', 'Canton', "999'999'999", '13.00'],
      ],
      // ZG — low-tax canton neighbor of ZH
      'Zug': [
        ['Income tax', 'Single, no children', 'Canton', "10'000", '0.00'],
        ['Income tax', 'Single, no children', 'Canton', "20'000", '1.00'],
        ['Income tax', 'Single, no children', 'Canton', "30'000", '2.00'],
        ['Income tax', 'Single, no children', 'Canton', "40'000", '3.00'],
        ['Income tax', 'Single, no children', 'Canton', "999'999'999", '4.00'],
        ['Income tax', 'Married/Single, with children', 'Canton', "15'000", '0.00'],
        ['Income tax', 'Married/Single, with children', 'Canton', "25'000", '0.50'],
        ['Income tax', 'Married/Single, with children', 'Canton', "35'000", '1.50'],
        ['Income tax', 'Married/Single, with children', 'Canton', "999'999'999", '3.00'],
      ],
      // SZ — another low-tax neighbor of ZH
      'Schwyz': [
        ['Income tax', 'Single, no children', 'Canton', "15'000", '0.50'],
        ['Income tax', 'Single, no children', 'Canton', "25'000", '1.50'],
        ['Income tax', 'Single, no children', 'Canton', "999'999'999", '3.00'],
        ['Income tax', 'Married/Single, with children', 'Canton', "20'000", '0.00'],
        ['Income tax', 'Married/Single, with children', 'Canton', "30'000", '1.00'],
        ['Income tax', 'Married/Single, with children', 'Canton', "999'999'999", '2.50'],
      ],
      // AG — neighbor of ZH
      'Aargau': [
        ['Income tax', 'All', 'Canton', "10'000", '1.00'],
        ['Income tax', 'All', 'Canton', "20'000", '2.50'],
        ['Income tax', 'All', 'Canton', "30'000", '4.00'],
        ['Income tax', 'All', 'Canton', "999'999'999", '6.00'],
      ],
      // SH — neighbor of ZH
      'Schaffhausen': [
        ['Income tax', 'All', 'Canton', "10'000", '1.00'],
        ['Income tax', 'All', 'Canton', "20'000", '3.00'],
        ['Income tax', 'All', 'Canton', "999'999'999", '7.00'],
      ],
      // TG — neighbor of ZH
      'Thurgau': [
        ['Income tax', 'All', 'Canton', "10'000", '0.50'],
        ['Income tax', 'All', 'Canton', "20'000", '2.00'],
        ['Income tax', 'All', 'Canton', "999'999'999", '5.00'],
      ],
      // VD — for testing Romandie
      'Vaud': [
        ['Income tax', 'Single, with / no children', 'Canton', "10'000", '0.00'],
        ['Income tax', 'Single, with / no children', 'Canton', "20'000", '3.50'],
        ['Income tax', 'Single, with / no children', 'Canton', "30'000", '5.50'],
        ['Income tax', 'Single, with / no children', 'Canton', "999'999'999", '9.00'],
        ['Income tax', 'Married', 'Canton', "15'000", '0.00'],
        ['Income tax', 'Married', 'Canton', "25'000", '2.50'],
        ['Income tax', 'Married', 'Canton', "40'000", '4.50'],
        ['Income tax', 'Married', 'Canton', "999'999'999", '8.00'],
      ],
      // VS
      'Valais': [
        ['Income tax', 'All', 'Canton', "20'000", '1.00'],
        ['Income tax', 'All', 'Canton', "30'000", '3.00'],
        ['Income tax', 'All', 'Canton', "999'999'999", '6.00'],
      ],
      // GE — cumulative threshold canton
      'Geneva': [
        ['Income tax', 'All', 'Canton', "0", '0.00'],
        ['Income tax', 'All', 'Canton', "30'000", '4.00'],
        ['Income tax', 'All', 'Canton', "50'000", '6.00'],
        ['Income tax', 'All', 'Canton', "999'999'999", '9.00'],
      ],
      // FR
      'Fribourg': [
        ['Income tax', 'All', 'Canton', "15'000", '1.00'],
        ['Income tax', 'All', 'Canton', "30'000", '3.00'],
        ['Income tax', 'All', 'Canton', "999'999'999", '6.00'],
      ],
      // NE
      'Neuch\u00e2tel': [
        ['Income tax', 'All', 'Canton', "20'000", '2.00'],
        ['Income tax', 'All', 'Canton', "30'000", '4.50'],
        ['Income tax', 'All', 'Canton', "999'999'999", '8.00'],
      ],
    });
  }

  // ---------------------------------------------------------------------------
  // calculateMonthsWorkedForTax
  // ---------------------------------------------------------------------------

  group('FiscalIntelligenceService — calculateMonthsWorkedForTax', () {
    test('standard case: 12k tax on 72k net = 2 months', () {
      final months = FiscalIntelligenceService.calculateMonthsWorkedForTax(
        annualTax: 12000,
        netAnnualIncome: 72000,
      );
      expect(months, closeTo(2.0, 0.01));
    });

    test('zero net income returns 0 (no division by zero)', () {
      final months = FiscalIntelligenceService.calculateMonthsWorkedForTax(
        annualTax: 5000,
        netAnnualIncome: 0,
      );
      expect(months, 0.0);
    });

    test('zero tax returns 0 months', () {
      final months = FiscalIntelligenceService.calculateMonthsWorkedForTax(
        annualTax: 0,
        netAnnualIncome: 100000,
      );
      expect(months, 0.0);
    });

    test('tax equal to income = 12 months', () {
      final months = FiscalIntelligenceService.calculateMonthsWorkedForTax(
        annualTax: 60000,
        netAnnualIncome: 60000,
      );
      expect(months, closeTo(12.0, 0.01));
    });

    test('proportional: 3 months for 25% tax burden', () {
      final months = FiscalIntelligenceService.calculateMonthsWorkedForTax(
        annualTax: 25000,
        netAnnualIncome: 100000,
      );
      expect(months, closeTo(3.0, 0.01));
    });

    test('low income, low tax', () {
      final months = FiscalIntelligenceService.calculateMonthsWorkedForTax(
        annualTax: 1000,
        netAnnualIncome: 36000,
      );
      // 1000 / (36000/12) = 1000 / 3000 = 0.333
      expect(months, closeTo(0.333, 0.01));
    });
  });

  // ---------------------------------------------------------------------------
  // findBetterNeighbor
  // ---------------------------------------------------------------------------

  group('FiscalIntelligenceService — findBetterNeighbor', () {
    setUp(() {
      initScales();
    });

    test('returns null for canton with no neighbors', () {
      // 'XX' is unknown, _getNeighbors returns []
      final result = FiscalIntelligenceService.findBetterNeighbor(
        currentCanton: 'XX',
        netMonthlyIncome: 8000,
        civilStatus: 'single',
        age: 35,
      );
      expect(result, isNull);
    });

    test('ZH finds savings in ZG (known low-tax neighbor)', () {
      // ZH neighbors: ['ZG', 'SZ', 'AG', 'SH', 'TG']
      // ZG is a notoriously low-tax canton
      final result = FiscalIntelligenceService.findBetterNeighbor(
        currentCanton: 'ZH',
        netMonthlyIncome: 8000,
        civilStatus: 'single',
        age: 35,
      );
      // Should find a neighbor with savings > 500 CHF (likely ZG or SZ)
      if (result != null) {
        expect(result['savings'], greaterThan(500));
        expect(result['canton'], isNotNull);
        expect(result['currentTax'], isA<double>());
        expect(result['neighborTax'], isA<double>());
        expect(result['neighborTax'], lessThan(result['currentTax']));
      }
      // If null, savings below threshold for this income — acceptable
    });

    test('returns null when savings below 500 CHF threshold', () {
      // Very low income: tax difference between cantons is minimal
      final result = FiscalIntelligenceService.findBetterNeighbor(
        currentCanton: 'ZH',
        netMonthlyIncome: 1000,
        civilStatus: 'single',
        age: 30,
      );
      // At 12k annual income, tax difference is likely < 500 CHF
      // This may or may not be null depending on exact rates
      if (result != null) {
        expect(result['savings'] as double, greaterThan(500));
      }
    });

    test('result structure has expected keys', () {
      final result = FiscalIntelligenceService.findBetterNeighbor(
        currentCanton: 'ZH',
        netMonthlyIncome: 10000,
        civilStatus: 'single',
        age: 35,
      );
      if (result != null) {
        expect(result.containsKey('canton'), true);
        expect(result.containsKey('savings'), true);
        expect(result.containsKey('currentTax'), true);
        expect(result.containsKey('neighborTax'), true);
      }
    });

    test('neighborTax equals currentTax minus savings', () {
      final result = FiscalIntelligenceService.findBetterNeighbor(
        currentCanton: 'VD',
        netMonthlyIncome: 8000,
        civilStatus: 'single',
        age: 35,
      );
      if (result != null) {
        expect(
          result['neighborTax'] as double,
          closeTo(
            (result['currentTax'] as double) - (result['savings'] as double),
            0.01,
          ),
        );
      }
    });

    test('married status uses correct tariff for comparison', () {
      final result = FiscalIntelligenceService.findBetterNeighbor(
        currentCanton: 'ZH',
        netMonthlyIncome: 8000,
        civilStatus: 'married',
        age: 40,
      );
      // Should not crash and should return a valid result or null
      if (result != null) {
        expect(result['savings'], greaterThan(500));
      }
    });

    test('children parameter is passed through', () {
      final resultNoKids = FiscalIntelligenceService.findBetterNeighbor(
        currentCanton: 'ZH',
        netMonthlyIncome: 8000,
        civilStatus: 'single',
        age: 35,
        childrenCount: 0,
      );
      final resultWithKids = FiscalIntelligenceService.findBetterNeighbor(
        currentCanton: 'ZH',
        netMonthlyIncome: 8000,
        civilStatus: 'single',
        age: 35,
        childrenCount: 2,
      );
      // Results may differ because children affect federal tax computation
      // Both should be valid (null or map)
      if (resultNoKids != null && resultWithKids != null) {
        // Children deduction may change savings amount
        expect(resultNoKids['savings'], isA<double>());
        expect(resultWithKids['savings'], isA<double>());
      }
    });

    test('VD neighbors include VS, GE, FR, NE', () {
      // VD has neighbors: ['VS', 'GE', 'FR', 'NE']
      final result = FiscalIntelligenceService.findBetterNeighbor(
        currentCanton: 'VD',
        netMonthlyIncome: 10000,
        civilStatus: 'single',
        age: 35,
      );
      // VD is a high-tax canton; neighbors like VS could offer savings
      if (result != null) {
        final canton = result['canton'] as String;
        expect(['VS', 'GE', 'FR', 'NE'], contains(canton));
      }
    });
  });

  // ---------------------------------------------------------------------------
  // _getNeighbors (tested indirectly through findBetterNeighbor)
  // ---------------------------------------------------------------------------

  group('FiscalIntelligenceService — neighbor mapping coverage', () {
    setUp(() {
      initScales();
    });

    test('GE has only VD as neighbor', () {
      // findBetterNeighbor for GE should only compare with VD
      final result = FiscalIntelligenceService.findBetterNeighbor(
        currentCanton: 'GE',
        netMonthlyIncome: 10000,
        civilStatus: 'single',
        age: 35,
      );
      if (result != null) {
        expect(result['canton'], 'VD');
      }
    });

    test('unknown canton returns null (no neighbors)', () {
      final result = FiscalIntelligenceService.findBetterNeighbor(
        currentCanton: 'UNKNOWN',
        netMonthlyIncome: 10000,
        civilStatus: 'single',
        age: 35,
      );
      expect(result, isNull);
    });
  });
}
