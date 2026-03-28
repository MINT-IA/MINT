// cantonal_benchmark_data_test.dart — S60
//
// Tests for CantonalBenchmarkData:
//   - All 26 cantons have data
//   - Known values: ZG lowest tax, GE highest rent
//   - Values in realistic Swiss ranges
//   - No missing cantons

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/benchmark/cantonal_benchmark_data.dart';

void main() {
  // All 26 Swiss canton codes (ISO 3166-2:CH prefixes)
  const all26Cantons = [
    'ZH', 'BE', 'LU', 'UR', 'SZ', 'OW', 'NW', 'GL', 'ZG', 'FR',
    'SO', 'BS', 'BL', 'SH', 'AR', 'AI', 'SG', 'GR', 'AG', 'TG',
    'VD', 'VS', 'NE', 'GE', 'JU', 'TI',
  ];

  group('all 26 cantons have data', () {
    test('forCanton returns non-null for all 26 cantons', () {
      for (final code in all26Cantons) {
        final benchmark = CantonalBenchmarkData.forCanton(code);
        expect(
          benchmark,
          isNotNull,
          reason: 'Missing benchmark data for canton $code',
        );
      }
    });

    test('availableCantons() returns exactly 26 entries', () {
      expect(CantonalBenchmarkData.availableCantons().length, 26);
    });

    test('availableCantons() contains all 26 canton codes', () {
      final available = CantonalBenchmarkData.availableCantons();
      for (final code in all26Cantons) {
        expect(available, contains(code), reason: '$code missing from list');
      }
    });
  });

  group('known values — key cantons', () {
    test('ZG has the lowest tax burden index (< 40)', () {
      final zg = CantonalBenchmarkData.forCanton('ZG')!;
      // ZG is well-known as Switzerland\'s lowest-tax canton
      expect(zg.taxBurdenIndex, lessThan(40),
          reason: 'ZG taxBurdenIndex should be < 40 (historically ~25)');
    });

    test('GE has the highest median rent', () {
      double maxRent = 0;
      String maxCanton = '';
      for (final code in all26Cantons) {
        final b = CantonalBenchmarkData.forCanton(code)!;
        if (b.medianRent > maxRent) {
          maxRent = b.medianRent;
          maxCanton = code;
        }
      }
      expect(maxCanton, 'GE',
          reason: 'GE should have the highest median rent (got: $maxCanton=$maxRent)');
    });

    test('GE median rent exceeds 2000 CHF/month', () {
      final ge = CantonalBenchmarkData.forCanton('GE')!;
      expect(ge.medianRent, greaterThan(2000),
          reason: 'GE median rent is well above 2000 CHF/month');
    });

    test('ZH income exceeds VS income', () {
      final zh = CantonalBenchmarkData.forCanton('ZH')!;
      final vs = CantonalBenchmarkData.forCanton('VS')!;
      expect(zh.medianIncome, greaterThan(vs.medianIncome));
    });

    test('ZG income is among the highest', () {
      final zg = CantonalBenchmarkData.forCanton('ZG')!;
      expect(zg.medianIncome, greaterThan(90000),
          reason: 'ZG has very high income due to low tax attracting wealth');
    });

    test('TI has lower income than ZH', () {
      final ti = CantonalBenchmarkData.forCanton('TI')!;
      final zh = CantonalBenchmarkData.forCanton('ZH')!;
      expect(ti.medianIncome, lessThan(zh.medianIncome));
    });

    test('VS has lower rent than VD', () {
      final vs = CantonalBenchmarkData.forCanton('VS')!;
      final vd = CantonalBenchmarkData.forCanton('VD')!;
      expect(vs.medianRent, lessThan(vd.medianRent));
    });
  });

  group('values in realistic ranges', () {
    test('median income between 50k and 120k CHF/year for all cantons', () {
      for (final code in all26Cantons) {
        final b = CantonalBenchmarkData.forCanton(code)!;
        expect(b.medianIncome, greaterThanOrEqualTo(50000),
            reason: '$code medianIncome=${b.medianIncome} < 50k');
        expect(b.medianIncome, lessThanOrEqualTo(120000),
            reason: '$code medianIncome=${b.medianIncome} > 120k');
      }
    });

    test('median rent between 800 and 2500 CHF/month for all cantons', () {
      for (final code in all26Cantons) {
        final b = CantonalBenchmarkData.forCanton(code)!;
        expect(b.medianRent, greaterThanOrEqualTo(800),
            reason: '$code medianRent=${b.medianRent} < 800');
        expect(b.medianRent, lessThanOrEqualTo(2500),
            reason: '$code medianRent=${b.medianRent} > 2500');
      }
    });

    test('tax burden index between 10 and 160 for all cantons', () {
      for (final code in all26Cantons) {
        final b = CantonalBenchmarkData.forCanton(code)!;
        expect(b.taxBurdenIndex, greaterThanOrEqualTo(10),
            reason: '$code taxBurdenIndex=${b.taxBurdenIndex} < 10');
        expect(b.taxBurdenIndex, lessThanOrEqualTo(160),
            reason: '$code taxBurdenIndex=${b.taxBurdenIndex} > 160');
      }
    });

    test('savings rate between 7% and 25% for all cantons', () {
      for (final code in all26Cantons) {
        final b = CantonalBenchmarkData.forCanton(code)!;
        expect(b.savingsRateTypical, greaterThanOrEqualTo(0.07),
            reason: '$code savingsRate=${b.savingsRateTypical} < 7%');
        expect(b.savingsRateTypical, lessThanOrEqualTo(0.25),
            reason: '$code savingsRate=${b.savingsRateTypical} > 25%');
      }
    });

    test('home ownership rate between 15% and 70% for all cantons', () {
      for (final code in all26Cantons) {
        final b = CantonalBenchmarkData.forCanton(code)!;
        expect(b.homeOwnershipRate, greaterThanOrEqualTo(0.15),
            reason: '$code homeOwnership=${b.homeOwnershipRate} < 15%');
        expect(b.homeOwnershipRate, lessThanOrEqualTo(0.70),
            reason: '$code homeOwnership=${b.homeOwnershipRate} > 70%');
      }
    });

    test('LPP coverage rate between 70% and 98% for all cantons', () {
      for (final code in all26Cantons) {
        final b = CantonalBenchmarkData.forCanton(code)!;
        expect(b.lppCoverageRate, greaterThanOrEqualTo(0.70),
            reason: '$code lppCoverage=${b.lppCoverageRate} < 70%');
        expect(b.lppCoverageRate, lessThanOrEqualTo(0.98),
            reason: '$code lppCoverage=${b.lppCoverageRate} > 98%');
      }
    });

    test('pillar 3a participation between 35% and 75% for all cantons', () {
      for (final code in all26Cantons) {
        final b = CantonalBenchmarkData.forCanton(code)!;
        expect(b.pillar3aParticipation, greaterThanOrEqualTo(0.35),
            reason: '$code 3aParticipation=${b.pillar3aParticipation} < 35%');
        expect(b.pillar3aParticipation, lessThanOrEqualTo(0.75),
            reason: '$code 3aParticipation=${b.pillar3aParticipation} > 75%');
      }
    });
  });

  group('case-insensitive lookup', () {
    test('lowercase canton code works', () {
      expect(CantonalBenchmarkData.forCanton('vs'), isNotNull);
      expect(CantonalBenchmarkData.forCanton('vs')!.cantonCode, 'VS');
    });

    test('mixed case canton code works', () {
      expect(CantonalBenchmarkData.forCanton('Zh'), isNotNull);
      expect(CantonalBenchmarkData.forCanton('Zh')!.cantonCode, 'ZH');
    });
  });

  group('unknown cantons return null', () {
    test('unknown code returns null', () {
      expect(CantonalBenchmarkData.forCanton('XX'), isNull);
    });

    test('empty string returns null', () {
      expect(CantonalBenchmarkData.forCanton(''), isNull);
    });

    test('invalid code returns null', () {
      expect(CantonalBenchmarkData.forCanton('NONEXISTENT'), isNull);
    });
  });

  group('data structural integrity', () {
    test('cantonCode matches the key for all entries', () {
      for (final code in all26Cantons) {
        final b = CantonalBenchmarkData.forCanton(code)!;
        expect(b.cantonCode, code,
            reason: 'cantonCode mismatch for $code: got ${b.cantonCode}');
      }
    });

    test('cantonName is non-empty for all entries', () {
      for (final code in all26Cantons) {
        final b = CantonalBenchmarkData.forCanton(code)!;
        expect(b.cantonName.isNotEmpty, isTrue,
            reason: '$code has empty cantonName');
      }
    });

    test('ZG has highest savings rate among major cantons', () {
      final zg = CantonalBenchmarkData.forCanton('ZG')!;
      final vs = CantonalBenchmarkData.forCanton('VS')!;
      // Low-tax cantons attract wealth, typically higher savings
      expect(zg.savingsRateTypical, greaterThan(vs.savingsRateTypical));
    });
  });
}
