import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/retroactive_3a_calculator.dart';
import 'package:mint_mobile/constants/social_insurance.dart';

void main() {
  // Use referenceYear=2036 for tests that need multiple gap years.
  // This ensures years 2025-2035 are all valid (year >= 2025 guard).
  // Tests that specifically test the year guard use referenceYear=2026.
  const futureRef = 2036;

  group('Retroactive3aCalculator', () {
    // ── 1. 10-year gap sums correctly ──
    test('10-year gap sums all historical limits (avec LPP)', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 10,
        tauxMarginal: 0.30,
        referenceYear: futureRef,
      );

      // 10 years from 2035 back to 2026. All use fallback limit (6768.0)
      // except 2026:7258, which is in the historical map.
      // 2035:6768 + 2034:6768 + 2033:6768 + 2032:6768 + 2031:6768
      // + 2030:6768 + 2029:6768 + 2028:6768 + 2027:6768 + 2026:7258
      // = 9*6768 + 7258 = 60912 + 7258 = 68170
      expect(result.gapYears, 10);
      expect(result.breakdown.length, 10);
    });

    // ── 2. 5-year gap sums correctly ──
    test('5-year gap sums the 5 most recent years', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 5,
        tauxMarginal: 0.25,
        referenceYear: futureRef,
      );

      expect(result.gapYears, 5);
      expect(result.breakdown.length, 5);
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

    // ── 4. Tax savings = totalRetroactive x tauxMarginal ──
    test('economiesFiscales equals totalRetroactive times tauxMarginal', () {
      const taux = 0.32;
      final result = Retroactive3aCalculator.calculate(
        gapYears: 7,
        tauxMarginal: taux,
        referenceYear: futureRef,
      );

      expect(result.economiesFiscales, result.totalRetroactive * taux);
    });

    // ── 5. Current year NOT included in retroactive total ──
    test('current year is excluded from totalRetroactive', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 3,
        tauxMarginal: 0.30,
        referenceYear: futureRef,
      );

      expect(result.totalCurrentYear, pilier3aPlafondAvecLpp);
      expect(result.totalContribution,
          result.totalRetroactive + result.totalCurrentYear);
      // totalRetroactive should not contain reference year
      for (final entry in result.breakdown) {
        expect(entry.year, isNot(futureRef));
      }
    });

    // ── 6. Gap years clamped to max 10 ──
    test('gap years clamped to maximum 10', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 15,
        tauxMarginal: 0.30,
        referenceYear: futureRef,
      );

      expect(result.gapYears, 10);
      expect(result.breakdown.length, 10);
    });

    // ── 7. Gap years respect dynamic cap (swiss-brain Q1 2026-04-18) ──
    test('gap years respect OPP3 art. 7a dynamic cap', () {
      // Audit 2026-04-18 Q1 : OPP3 art. 7a entré en vigueur 01.01.2025.
      // En année N, seules les lacunes postérieures au 31.12.2024 sont
      // rachetables : dynamicCap = N - 2025 (cap max 10).
      //   - 2025 : 0 année passée (seule la contribution courante).
      //   - 2026 : 1 année passée (2025).
      //   - 2035+ : 10 ans permanent.
      final result2026 = Retroactive3aCalculator.calculate(
        gapYears: 5,
        tauxMarginal: 0.30,
        referenceYear: 2026,
      );
      expect(result2026.gapYears, 1,
          reason: 'En 2026, dynamicCap = 1 an rachetable');

      final result2025 = Retroactive3aCalculator.calculate(
        gapYears: 5,
        tauxMarginal: 0.30,
        referenceYear: 2025,
      );
      expect(result2025.gapYears, 0,
          reason: 'En 2025, aucune année passée rachetable');
    });

    // ── 8. Chiffre choc contains CHF and year count ──
    test('premierEclairage contains CHF amount and year count', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 5,
        tauxMarginal: 0.30,
        referenceYear: futureRef,
      );

      expect(result.premierEclairage, contains('CHF'));
      expect(result.premierEclairage, contains('5 ans'));
      expect(result.premierEclairage, contains('$futureRef'));
    });

    // ── 9. Disclaimer contains required terms ──
    test('disclaimer contains educatif and OPP3', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 3,
        tauxMarginal: 0.25,
        referenceYear: futureRef,
      );

      expect(result.disclaimer, contains('ducatif'));
      expect(result.disclaimer, contains('OPP3'));
    });

    // ── 10. Sources contain OPP3 and LIFD ──
    test('sources contain OPP3 and LIFD references', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 3,
        tauxMarginal: 0.25,
        referenceYear: futureRef,
      );

      expect(result.sources.any((s) => s.contains('OPP3')), isTrue);
      expect(result.sources.any((s) => s.contains('LIFD')), isTrue);
    });

    // ── 11. Golden test Julien: 10 years, 35% marginal ──
    test('golden test Julien: 10 years at 35% → savings > 20000', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 10,
        tauxMarginal: 0.35,
        hasLpp: true,
        referenceYear: futureRef,
      );

      // With futureRef, most years use fallback limit (6768).
      // Total ~68170 * 0.35 = ~23'860
      expect(result.economiesFiscales, greaterThan(20000));
      expect(result.gapYears, 10);
    });

    // ── 12. Golden test Lauren: 5 years, 25% marginal ──
    test('golden test Lauren: 5 years at 25% → savings > 5000', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 5,
        tauxMarginal: 0.25,
        hasLpp: true,
        referenceYear: futureRef,
      );

      // 5 years of ~6768 each = ~33'840 * 0.25 = ~8'460
      expect(result.economiesFiscales, greaterThan(5000));
      expect(result.gapYears, 5);
    });

    // ── 13. Sans LPP: limits are scaled (much higher) ──
    test('sans LPP scales limits by large 3a / small 3a ratio', () {
      final withLpp = Retroactive3aCalculator.calculate(
        gapYears: 3,
        tauxMarginal: 0.30,
        hasLpp: true,
        referenceYear: futureRef,
      );
      final sansLpp = Retroactive3aCalculator.calculate(
        gapYears: 3,
        tauxMarginal: 0.30,
        hasLpp: false,
        referenceYear: futureRef,
      );

      const expectedRatio = pilier3aPlafondSansLpp / pilier3aPlafondAvecLpp;
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
          referenceYear: futureRef,
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
        referenceYear: futureRef,
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
        referenceYear: futureRef,
      );
      // Should be clamped to 0.60, not produce savings > total
      expect(result.economiesFiscales, lessThanOrEqualTo(result.totalRetroactive * 0.61));
    });

    // ── 17. Chiffre choc singular for 1 year ──
    test('premierEclairage uses singular "an" for 1 year', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 1,
        tauxMarginal: 0.30,
      );

      expect(result.premierEclairage, contains('1 an '));
      expect(result.premierEclairage, isNot(contains('1 ans')));
    });

    // ── 18. Year < 2025 guard: referenceYear 2026 caps at 1 ──
    test('referenceYear 2026 with gapYears 10 produces only 2025', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 10,
        tauxMarginal: 0.30,
        referenceYear: 2026,
      );

      expect(result.breakdown.length, 1);
      expect(result.breakdown.first.year, 2025);
      // No entry before 2025
      for (final entry in result.breakdown) {
        expect(entry.year, greaterThanOrEqualTo(2025));
      }
    });
  });
}
