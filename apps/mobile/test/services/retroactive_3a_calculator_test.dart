import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/retroactive_3a_calculator.dart';
import 'package:mint_mobile/constants/social_insurance.dart';

void main() {
  group('Retroactive3aCalculator', () {
    // ── 1. 10-year gap sums correctly ──
    test('10-year gap sums all historical limits (avec LPP)', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 10,
        tauxMarginal: 0.30,
      );

      // 2025:7258 + 2024:7056 + 2023:6883 + 2022:6826 + 2021:6826
      // + 2020:6826 + 2019:6826 + 2018:6826 + 2017:6768 + 2016:6768
      // = 68'863
      expect(result.totalRetroactive, 68863.0);
      expect(result.gapYears, 10);
    });

    // ── 2. 5-year gap sums correctly ──
    test('5-year gap sums the 5 most recent years', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 5,
        tauxMarginal: 0.25,
      );

      // 2025:7258 + 2024:7056 + 2023:6883 + 2022:6826 + 2021:6826
      // = 34'849
      expect(result.totalRetroactive, 34849.0);
      expect(result.gapYears, 5);
    });

    // ── 3. 1-year gap = single year limit ──
    test('1-year gap returns single year limit', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 1,
        tauxMarginal: 0.30,
      );

      expect(result.totalRetroactive, 7258.0); // 2025 limit
      expect(result.gapYears, 1);
      expect(result.breakdown.length, 1);
      expect(result.breakdown.first.year, 2025);
    });

    // ── 4. Tax savings = totalRetroactive × tauxMarginal ──
    test('economiesFiscales equals totalRetroactive times tauxMarginal', () {
      const taux = 0.32;
      final result = Retroactive3aCalculator.calculate(
        gapYears: 7,
        tauxMarginal: taux,
      );

      expect(result.economiesFiscales, result.totalRetroactive * taux);
    });

    // ── 5. Current year NOT included in retroactive total ──
    test('current year is excluded from totalRetroactive', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 3,
        tauxMarginal: 0.30,
      );

      expect(result.totalCurrentYear, pilier3aPlafondAvecLpp);
      expect(result.totalContribution,
          result.totalRetroactive + result.totalCurrentYear);
      // totalRetroactive should not contain 2026 limit
      for (final entry in result.breakdown) {
        expect(entry.year, isNot(2026));
      }
    });

    // ── 6. Gap years clamped to max 10 ──
    test('gap years clamped to maximum 10', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 15,
        tauxMarginal: 0.30,
      );

      expect(result.gapYears, 10);
      expect(result.breakdown.length, 10);
    });

    // ── 7. Gap years clamped to min 1 ──
    test('gap years clamped to minimum 1', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 0,
        tauxMarginal: 0.30,
      );

      expect(result.gapYears, 1);
      expect(result.breakdown.length, 1);
    });

    // ── 8. Chiffre choc contains CHF and year count ──
    test('chiffreChoc contains CHF amount and year count', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 5,
        tauxMarginal: 0.30,
      );

      expect(result.chiffreChoc, contains('CHF'));
      expect(result.chiffreChoc, contains('5 ans'));
      expect(result.chiffreChoc, contains('2026'));
    });

    // ── 9. Disclaimer contains required terms ──
    test('disclaimer contains educatif and OPP3', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 3,
        tauxMarginal: 0.25,
      );

      expect(result.disclaimer, contains('ducatif'));
      expect(result.disclaimer, contains('OPP3'));
    });

    // ── 10. Sources contain OPP3 and LIFD ──
    test('sources contain OPP3 and LIFD references', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 3,
        tauxMarginal: 0.25,
      );

      expect(result.sources.any((s) => s.contains('OPP3')), isTrue);
      expect(result.sources.any((s) => s.contains('LIFD')), isTrue);
    });

    // ── 11. Golden test Julien: 10 years, 35% marginal ──
    test('golden test Julien: 10 years at 35% → savings > 24000', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 10,
        tauxMarginal: 0.35,
        hasLpp: true,
      );

      // 68'863 * 0.35 = 24'102.05
      expect(result.economiesFiscales, greaterThan(24000));
      expect(result.gapYears, 10);
    });

    // ── 12. Golden test Lauren: 5 years, 25% marginal ──
    test('golden test Lauren: 5 years at 25% → savings > 8000', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 5,
        tauxMarginal: 0.25,
        hasLpp: true,
      );

      // 34'849 * 0.25 = 8'712.25
      expect(result.economiesFiscales, greaterThan(8000));
      expect(result.gapYears, 5);
    });

    // ── 13. Sans LPP: limits are scaled (much higher) ──
    test('sans LPP scales limits by large 3a / small 3a ratio', () {
      final withLpp = Retroactive3aCalculator.calculate(
        gapYears: 3,
        tauxMarginal: 0.30,
        hasLpp: true,
      );
      final sansLpp = Retroactive3aCalculator.calculate(
        gapYears: 3,
        tauxMarginal: 0.30,
        hasLpp: false,
      );

      final expectedRatio = pilier3aPlafondSansLpp / pilier3aPlafondAvecLpp;
      expect(sansLpp.totalRetroactive,
          closeTo(withLpp.totalRetroactive * expectedRatio, 1.0));
      expect(sansLpp.totalRetroactive, greaterThan(withLpp.totalRetroactive));
      expect(sansLpp.totalCurrentYear, pilier3aPlafondSansLpp);
    });

    // ── 14. Breakdown has correct number of entries ──
    test('breakdown length matches effective gap years', () {
      for (final gap in [1, 3, 5, 7, 10]) {
        final result = Retroactive3aCalculator.calculate(
          gapYears: gap,
          tauxMarginal: 0.30,
        );
        expect(result.breakdown.length, gap);
      }
    });

    // ── 15. Sans LPP with income cap: 20% rule applied ──
    test('sans LPP with revenuNetAnnuel applies 20% income cap', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 3,
        tauxMarginal: 0.30,
        hasLpp: false,
        revenuNetAnnuel: 80000, // 20% = 16'000 < grand limit ~34k
      );
      // Each year should be capped at 16'000 (20% of 80K)
      for (final entry in result.breakdown) {
        expect(entry.limit, closeTo(16000, 1));
      }
      expect(result.totalRetroactive, closeTo(48000, 10));
    });

    // ── 16. Taux marginal clamped to 0.60 max ──
    test('taux marginal clamped to prevent absurd results', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 5,
        tauxMarginal: 1.5, // absurd value
      );
      // Should be clamped to 0.60, not produce savings > total
      expect(result.economiesFiscales, lessThanOrEqualTo(result.totalRetroactive * 0.61));
    });

    // ── 17. Chiffre choc singular for 1 year ──
    test('chiffreChoc uses singular "an" for 1 year', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 1,
        tauxMarginal: 0.30,
      );

      expect(result.chiffreChoc, contains('1 an '));
      expect(result.chiffreChoc, isNot(contains('1 ans')));
    });
  });
}
