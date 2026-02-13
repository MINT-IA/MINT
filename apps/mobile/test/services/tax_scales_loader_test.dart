import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/tax_scales_loader.dart';
import 'package:mint_mobile/models/tax_scale.dart';

/// Unit tests for TaxScalesLoader
///
/// Tests the tax scale loading, caching, canton resolution, tariff
/// normalization, and cumulative-to-bracket-width conversion logic.
void main() {
  // Reset the static cache before each test to ensure isolation.
  setUp(() {
    // Re-init with empty data to clear any previous state
    TaxScalesLoader.init({});
  });

  group('init and basic loading', () {
    test('init with sample data makes getBrackets return correct brackets', () {
      TaxScalesLoader.init({
        'Zurich': [
          ['Income tax', 'Single, no children', 'Canton', "6'900", '0.00'],
          ['Income tax', 'Single, no children', 'Canton', "4'900", '2.00'],
          ['Income tax', 'Single, no children', 'Canton', "6'100", '3.00'],
        ],
      });

      final brackets = TaxScalesLoader.getBrackets('Zurich', 'Single, no children');
      expect(brackets.length, 3);
      expect(brackets[0].incomeThreshold, 6900.0);
      expect(brackets[0].rate, 0.0);
      expect(brackets[1].incomeThreshold, 4900.0);
      expect(brackets[1].rate, 2.0);
      expect(brackets[2].incomeThreshold, 6100.0);
      expect(brackets[2].rate, 3.0);
    });

    test('init with empty map results in empty cache', () {
      TaxScalesLoader.init({});
      final brackets = TaxScalesLoader.getBrackets('Zurich', 'Single, no children');
      expect(brackets, isEmpty);
    });

    test('init overwrites previous data', () {
      TaxScalesLoader.init({
        'Zurich': [
          ['Income tax', 'All', 'Canton', "10'000", '5.00'],
        ],
      });
      expect(TaxScalesLoader.getBrackets('Zurich', 'All').length, 1);

      // Re-init with different data
      TaxScalesLoader.init({
        'Bern': [
          ['Income tax', 'All', 'Canton', "8'000", '3.00'],
        ],
      });
      expect(TaxScalesLoader.getBrackets('Zurich', 'All'), isEmpty);
      expect(TaxScalesLoader.getBrackets('Bern', 'All').length, 1);
    });
  });

  group('canton code resolution', () {
    test('resolves VD to Vaud', () {
      TaxScalesLoader.init({
        'Vaud': [
          ['Income tax', 'Single, with / no children', 'Canton', "5'000", '1.50'],
        ],
      });

      final brackets = TaxScalesLoader.getBrackets('VD', 'Single, with / no children');
      expect(brackets.length, 1);
      expect(brackets[0].canton, 'Vaud');
    });

    test('resolves GE to Geneva', () {
      // GE is a cumulative canton, but we can still test resolution
      TaxScalesLoader.init({
        'Geneva': [
          ['Income tax', 'All', 'Canton', '0', '0.00'],
          ['Income tax', 'All', 'Canton', "100'000", '10.00'],
        ],
      });

      final brackets = TaxScalesLoader.getBrackets('GE', 'All');
      expect(brackets.isNotEmpty, true);
    });

    test('resolves BS to Basel-Stadt', () {
      TaxScalesLoader.init({
        'Basel-Stadt': [
          ['Income tax', 'All', 'Canton', '0', '0.00'],
          ['Income tax', 'All', 'Canton', "50'000", '5.00'],
        ],
      });

      final brackets = TaxScalesLoader.getBrackets('BS', 'All');
      expect(brackets.isNotEmpty, true);
    });

    test('resolves ZH to Zurich', () {
      TaxScalesLoader.init({
        'Zurich': [
          ['Income tax', 'All', 'Canton', "10'000", '2.00'],
        ],
      });

      final brackets = TaxScalesLoader.getBrackets('ZH', 'All');
      expect(brackets.length, 1);
    });

    test('full name works directly without code mapping', () {
      TaxScalesLoader.init({
        'Zurich': [
          ['Income tax', 'All', 'Canton', "10'000", '2.00'],
        ],
      });

      final brackets = TaxScalesLoader.getBrackets('Zurich', 'All');
      expect(brackets.length, 1);
    });

    test('unknown canton returns empty list', () {
      TaxScalesLoader.init({
        'Zurich': [
          ['Income tax', 'All', 'Canton', "10'000", '2.00'],
        ],
      });

      final brackets = TaxScalesLoader.getBrackets('Atlantis', 'All');
      expect(brackets, isEmpty);
    });

    test('unknown canton code returns empty list', () {
      TaxScalesLoader.init({
        'Zurich': [
          ['Income tax', 'All', 'Canton', "10'000", '2.00'],
        ],
      });

      final brackets = TaxScalesLoader.getBrackets('XX', 'All');
      expect(brackets, isEmpty);
    });
  });

  group('tariff normalization for Vaud (VD)', () {
    test('normalizes "Single, no children" to "Single, with / no children" for VD', () {
      TaxScalesLoader.init({
        'Vaud': [
          ['Income tax', 'Single, with / no children', 'Canton', "5'000", '1.50'],
          ['Income tax', 'Single, with / no children', 'Canton', "10'000", '3.00'],
        ],
      });

      final brackets = TaxScalesLoader.getBrackets('VD', 'Single, no children');
      expect(brackets.length, 2);
      expect(brackets[0].tariff, 'Single, with / no children');
    });

    test('normalizes "Married/Single, with children" to "Married" for VD', () {
      TaxScalesLoader.init({
        'Vaud': [
          ['Income tax', 'Married', 'Canton', "8'000", '2.00'],
          ['Income tax', 'Married', 'Canton', "12'000", '4.00'],
        ],
      });

      final brackets = TaxScalesLoader.getBrackets('VD', 'Married/Single, with children');
      expect(brackets.length, 2);
      expect(brackets[0].tariff, 'Married');
    });

    test('non-VD canton does not normalize tariff', () {
      TaxScalesLoader.init({
        'Zurich': [
          ['Income tax', 'Single, no children', 'Canton', "5'000", '1.50'],
        ],
      });

      // This should match directly, no normalization
      final brackets = TaxScalesLoader.getBrackets('ZH', 'Single, no children');
      expect(brackets.length, 1);
    });
  });

  group('fallback to All tariff', () {
    test('falls back to All when specific tariff not found', () {
      TaxScalesLoader.init({
        'Zurich': [
          ['Income tax', 'All', 'Canton', "10'000", '2.00'],
          ['Income tax', 'All', 'Canton', "20'000", '4.00'],
        ],
      });

      final brackets = TaxScalesLoader.getBrackets('ZH', 'Some Unknown Tariff');
      expect(brackets.length, 2);
      expect(brackets[0].tariff, 'All');
    });

    test('returns specific tariff when available, not All', () {
      TaxScalesLoader.init({
        'Zurich': [
          ['Income tax', 'Single, no children', 'Canton', "5'000", '1.00'],
          ['Income tax', 'All', 'Canton', "10'000", '2.00'],
        ],
      });

      final brackets = TaxScalesLoader.getBrackets('ZH', 'Single, no children');
      expect(brackets.length, 1);
      expect(brackets[0].tariff, 'Single, no children');
      expect(brackets[0].rate, 1.0);
    });

    test('returns empty when neither specific tariff nor All exists', () {
      TaxScalesLoader.init({
        'Zurich': [
          ['Income tax', 'Single, no children', 'Canton', "5'000", '1.00'],
        ],
      });

      final brackets = TaxScalesLoader.getBrackets('ZH', 'Married');
      expect(brackets, isEmpty);
    });
  });

  group('cumulative threshold conversion (BS/GE)', () {
    test('converts Basel-Stadt cumulative thresholds to bracket widths', () {
      TaxScalesLoader.init({
        'Basel-Stadt': [
          ['Income tax', 'All', 'Canton', '0', '0.00'],
          ['Income tax', 'All', 'Canton', "50'000", '5.00'],
          ['Income tax', 'All', 'Canton', "100'000", '10.00'],
        ],
      });

      final brackets = TaxScalesLoader.getBrackets('Basel-Stadt', 'All');
      expect(brackets.length, 3);

      // First bracket: width = next threshold - current = 50000 - 0 = 50000
      expect(brackets[0].incomeThreshold, 50000.0);
      expect(brackets[0].rate, 0.0);

      // Second bracket: width = 100000 - 50000 = 50000
      expect(brackets[1].incomeThreshold, 50000.0);
      expect(brackets[1].rate, 5.0);

      // Last bracket: catch-all (very large width)
      expect(brackets[2].incomeThreshold, 999999999.0);
      expect(brackets[2].rate, 10.0);
    });

    test('converts Geneva cumulative thresholds to bracket widths', () {
      TaxScalesLoader.init({
        'Geneva': [
          ['Income tax', 'All', 'Canton', '0', '0.00'],
          ['Income tax', 'All', 'Canton', "75'000", '8.00'],
          ['Income tax', 'All', 'Canton', "150'000", '12.00'],
          ['Income tax', 'All', 'Canton', "300'000", '15.00'],
        ],
      });

      final brackets = TaxScalesLoader.getBrackets('GE', 'All');
      expect(brackets.length, 4);

      // Widths: 75000, 75000, 150000, 999999999
      expect(brackets[0].incomeThreshold, 75000.0);
      expect(brackets[1].incomeThreshold, 75000.0);
      expect(brackets[2].incomeThreshold, 150000.0);
      expect(brackets[3].incomeThreshold, 999999999.0);
    });

    test('cumulative conversion handles single bracket gracefully', () {
      TaxScalesLoader.init({
        'Basel-Stadt': [
          ['Income tax', 'All', 'Canton', "10'000", '3.00'],
        ],
      });

      // Single bracket: group.length < 2 -> returned as-is
      final brackets = TaxScalesLoader.getBrackets('BS', 'All');
      expect(brackets.length, 1);
      expect(brackets[0].incomeThreshold, 10000.0);
    });

    test('cumulative conversion handles multiple tariffs independently', () {
      TaxScalesLoader.init({
        'Basel-Stadt': [
          ['Income tax', 'Single', 'Canton', '0', '0.00'],
          ['Income tax', 'Single', 'Canton', "40'000", '5.00'],
          ['Income tax', 'Married', 'Canton', '0', '0.00'],
          ['Income tax', 'Married', 'Canton', "80'000", '3.00'],
        ],
      });

      final single = TaxScalesLoader.getBrackets('BS', 'Single');
      expect(single.length, 2);
      expect(single[0].incomeThreshold, 40000.0); // 40000 - 0
      expect(single[1].incomeThreshold, 999999999.0);

      final married = TaxScalesLoader.getBrackets('BS', 'Married');
      expect(married.length, 2);
      expect(married[0].incomeThreshold, 80000.0); // 80000 - 0
      expect(married[1].incomeThreshold, 999999999.0);
    });

    test('non-cumulative canton is not converted', () {
      TaxScalesLoader.init({
        'Zurich': [
          ['Income tax', 'All', 'Canton', '0', '0.00'],
          ['Income tax', 'All', 'Canton', "50'000", '5.00'],
          ['Income tax', 'All', 'Canton', "100'000", '10.00'],
        ],
      });

      final brackets = TaxScalesLoader.getBrackets('Zurich', 'All');
      // Zurich is NOT cumulative, so thresholds stay as-is (bracket widths)
      expect(brackets[0].incomeThreshold, 0.0);
      expect(brackets[1].incomeThreshold, 50000.0);
      expect(brackets[2].incomeThreshold, 100000.0);
    });

    test('code-based cumulative canton (BS code) is also converted', () {
      // Using the code 'BS' directly as key (test fixture scenario)
      TaxScalesLoader.init({
        'BS': [
          ['Income tax', 'All', 'Canton', '0', '1.00'],
          ['Income tax', 'All', 'Canton', "20'000", '3.00'],
          ['Income tax', 'All', 'Canton', "60'000", '6.00'],
        ],
      });

      final brackets = TaxScalesLoader.getBrackets('BS', 'All');
      expect(brackets.length, 3);
      // Widths: 20000, 40000, 999999999
      expect(brackets[0].incomeThreshold, 20000.0);
      expect(brackets[1].incomeThreshold, 40000.0);
      expect(brackets[2].incomeThreshold, 999999999.0);
    });
  });

  group('getBrackets before init', () {
    test('returns empty list if not loaded', () {
      // After setUp, data is loaded (empty). Re-create a scenario
      // where _isLoaded would be false. Since init always sets _isLoaded=true,
      // the only way to test "not loaded" is indirectly.
      // After init({}) the cache is empty, so any query returns empty.
      final brackets = TaxScalesLoader.getBrackets('Zurich', 'All');
      expect(brackets, isEmpty);
    });
  });

  group('multiple cantons', () {
    test('handles multiple cantons simultaneously', () {
      TaxScalesLoader.init({
        'Zurich': [
          ['Income tax', 'All', 'Canton', "10'000", '2.00'],
        ],
        'Bern': [
          ['Income tax', 'All', 'Canton', "8'000", '3.00'],
        ],
        'Vaud': [
          ['Income tax', 'Single, with / no children', 'Canton', "5'000", '1.50'],
        ],
      });

      expect(TaxScalesLoader.getBrackets('ZH', 'All').length, 1);
      expect(TaxScalesLoader.getBrackets('BE', 'All').length, 1);
      expect(TaxScalesLoader.getBrackets('VD', 'Single, no children').length, 1);
    });
  });

  group('TaxScale.fromCsvRow parsing', () {
    test('parses standard 5-element row correctly', () {
      final scale = TaxScale.fromCsvRow('Zurich', [
        'Income tax',
        'Single, no children',
        'Canton',
        "6'900",
        '2.50',
      ]);
      expect(scale.canton, 'Zurich');
      expect(scale.tariff, 'Single, no children');
      expect(scale.incomeThreshold, 6900.0);
      expect(scale.rate, 2.5);
    });

    test('parses 4-element row (flat tax, e.g. Uri) correctly', () {
      final scale = TaxScale.fromCsvRow('Uri', [
        'Income tax',
        'All',
        'Canton',
        '1.50',
      ]);
      expect(scale.canton, 'Uri');
      expect(scale.tariff, 'All');
      expect(scale.incomeThreshold, 0.0); // Flat tax = 0 threshold
      expect(scale.rate, 1.5);
    });

    test('handles Swiss number formatting with apostrophes', () {
      final scale = TaxScale.fromCsvRow('Bern', [
        'Income tax',
        'All',
        'Canton',
        "212'500",
        '11.50',
      ]);
      expect(scale.incomeThreshold, 212500.0);
      expect(scale.rate, 11.5);
    });
  });
}
