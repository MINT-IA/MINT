import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';

void main() {
  group('AvsCalculator.computeMonthlyRente', () {
    test('high income full career → max rente 2520', () {
      final rente = AvsCalculator.computeMonthlyRente(
        currentAge: 45,
        retirementAge: 65,
        grossAnnualSalary: 120000, // > 88200 → max
      );
      expect(rente, closeTo(avsRenteMaxMensuelle, 1));
    });

    test('low income full career → RAMD interpolation', () {
      final rente = AvsCalculator.computeMonthlyRente(
        currentAge: 45,
        retirementAge: 65,
        grossAnnualSalary: 40000, // Between 14700 and 88200
      );
      expect(rente, greaterThan(avsRenteMinMensuelle));
      expect(rente, lessThan(avsRenteMaxMensuelle));
    });

    test('zero income → zero rente (no salary data)', () {
      final rente = AvsCalculator.computeMonthlyRente(
        currentAge: 45,
        retirementAge: 65,
        grossAnnualSalary: 0,
      );
      expect(rente, equals(0.0));
    });

    test('expat arrivalAge 35 → fewer contribution years', () {
      final native = AvsCalculator.computeMonthlyRente(
        currentAge: 45,
        retirementAge: 65,
        grossAnnualSalary: 100000,
      );
      final expat = AvsCalculator.computeMonthlyRente(
        currentAge: 45,
        retirementAge: 65,
        arrivalAge: 35,
        grossAnnualSalary: 100000,
      );
      expect(expat, lessThan(native));
      // Expat: 45-35=10 current + 20 future = 30/44 ≈ 68%
      // Native: 45-20=25 current + 20 future = 44/44 = 100%
      expect(expat / native, closeTo(30 / 44, 0.05));
    });

    test('early retirement 63 → 13.6% penalty', () {
      final normal = AvsCalculator.computeMonthlyRente(
        currentAge: 55,
        retirementAge: 65,
        grossAnnualSalary: 100000,
      );
      final early = AvsCalculator.computeMonthlyRente(
        currentAge: 55,
        retirementAge: 63,
        grossAnnualSalary: 100000,
      );
      // 2 years early × 6.8% = 13.6% penalty
      expect(early / normal, closeTo(1 - 0.068 * 2, 0.02));
    });

    test('early retirement 64 → 6.8% penalty', () {
      final normal = AvsCalculator.computeMonthlyRente(
        currentAge: 55,
        retirementAge: 65,
        grossAnnualSalary: 100000,
      );
      final early = AvsCalculator.computeMonthlyRente(
        currentAge: 55,
        retirementAge: 64,
        grossAnnualSalary: 100000,
      );
      expect(early / normal, closeTo(1 - 0.068, 0.02));
    });

    test('retirement before 63 → returns 0', () {
      final rente = AvsCalculator.computeMonthlyRente(
        currentAge: 55,
        retirementAge: 60,
        grossAnnualSalary: 100000,
      );
      expect(rente, equals(0.0));
    });

    test('deferred retirement 67 → bonus', () {
      final normal = AvsCalculator.computeMonthlyRente(
        currentAge: 55,
        retirementAge: 65,
        grossAnnualSalary: 100000,
      );
      final deferred = AvsCalculator.computeMonthlyRente(
        currentAge: 55,
        retirementAge: 67,
        grossAnnualSalary: 100000,
      );
      expect(deferred, greaterThan(normal));
      // 2 years deferral → +10.6%
      expect(deferred / normal, closeTo(1.106, 0.02));
    });

    test('lacunes reduce rente proportionally', () {
      final full = AvsCalculator.computeMonthlyRente(
        currentAge: 45,
        retirementAge: 65,
        grossAnnualSalary: 100000,
      );
      final withLacunes = AvsCalculator.computeMonthlyRente(
        currentAge: 45,
        retirementAge: 65,
        lacunes: 4,
        grossAnnualSalary: 100000,
      );
      // 4 lacunes: (44-4)/44 = 40/44 ratio
      expect(withLacunes / full, closeTo(40 / 44, 0.02));
    });
  });

  group('AvsCalculator.renteFromRAMD — Echelle 44', () {
    test('Julien (122207) → max rente 2520 (above RAMD max)', () {
      expect(AvsCalculator.renteFromRAMD(122207), equals(2520.0));
    });

    test('Lauren (67000) → ~2187 via Echelle 44 lookup', () {
      // 67000 is between 64680 (2142) and 67620 (2199)
      // ratio = (67000 - 64680) / (67620 - 64680) = 2320/2940 ≈ 0.789
      // rente = 2142 + 0.789 * (2199 - 2142) = 2142 + 45.0 ≈ 2187
      final rente = AvsCalculator.renteFromRAMD(67000);
      expect(rente, closeTo(2187, 2));
    });

    test('high income → max rente', () {
      expect(AvsCalculator.renteFromRAMD(100000), equals(avsRenteMaxMensuelle));
    });

    test('low income below RAMD min → min rente 1260', () {
      // RAMD < 14700 → minimum rente (LAVS art. 34)
      expect(AvsCalculator.renteFromRAMD(10000), equals(avsRenteMinMensuelle));
    });

    test('RAMD min exact → min rente 1260', () {
      expect(AvsCalculator.renteFromRAMD(14700), equals(1260.0));
    });

    test('RAMD max exact → max rente 2520', () {
      expect(AvsCalculator.renteFromRAMD(88200), equals(2520.0));
    });

    test('zero → zero', () {
      expect(AvsCalculator.renteFromRAMD(0), equals(0.0));
    });

    test('negative → zero', () {
      expect(AvsCalculator.renteFromRAMD(-5000), equals(0.0));
    });

    test('between two table points: 50000 → between 1857 and 1914', () {
      // 50000 is between 49980 (1857) and 52920 (1914)
      // ratio = (50000 - 49980) / (52920 - 49980) = 20/2940 ≈ 0.0068
      // rente = 1857 + 0.0068 * 57 ≈ 1857.39
      final rente = AvsCalculator.renteFromRAMD(50000);
      expect(rente, greaterThanOrEqualTo(1857));
      expect(rente, lessThanOrEqualTo(1914));
      expect(rente, closeTo(1857.4, 1));
    });

    test('Echelle 44 is concave: middle incomes differ from naive linear', () {
      // With old linear interpolation: mid = (14700+88200)/2 = 51450
      // Old linear rente at 51450 = 1260 + (2520-1260) * (51450-14700)/(88200-14700) = 1890
      // Echelle 44 at 51450: between 49980 (1857) and 52920 (1914)
      // ratio = (51450-49980)/(52920-49980) = 1470/2940 = 0.5 → 1857+28.5 = 1885.5
      // The concave table gives a DIFFERENT result than naive linear
      final rente = AvsCalculator.renteFromRAMD(51450);
      expect(rente, closeTo(1885.5, 1));
      // The key assertion: not equal to naive linear (1890)
      expect(rente, isNot(closeTo(1890, 2)));
    });

    test('all table exact points return exact values', () {
      for (final row in avsEchelle44) {
        if (row[0] == 0) continue; // skip (0, 0) — handled by <= 0 guard
        expect(
          AvsCalculator.renteFromRAMD(row[0]),
          equals(row[1]),
          reason: 'RAMD ${row[0]} should give rente ${row[1]}',
        );
      }
    });

    test('monotonically increasing: higher salary → higher rente', () {
      double prevRente = 0;
      for (final row in avsEchelle44) {
        if (row[0] == 0) continue;
        final rente = AvsCalculator.renteFromRAMD(row[0]);
        expect(rente, greaterThanOrEqualTo(prevRente),
            reason: 'Rente should not decrease at RAMD ${row[0]}');
        prevRente = rente;
      }
    });
  });

  group('AvsCalculator.computeCouple', () {
    test('married couple capped at 3780', () {
      final result = AvsCalculator.computeCouple(
        avsUser: 2520,
        avsConjoint: 2520,
        isMarried: true,
      );
      expect(result.total, equals(avsRenteCoupleMaxMensuelle));
      expect(result.user, closeTo(1890, 1)); // 2520 * 3780/5040
      expect(result.conjoint, closeTo(1890, 1));
    });

    test('concubin couple NOT capped', () {
      final result = AvsCalculator.computeCouple(
        avsUser: 2520,
        avsConjoint: 2520,
        isMarried: false,
      );
      expect(result.total, equals(5040));
      expect(result.user, equals(2520));
      expect(result.conjoint, equals(2520));
    });

    test('married below cap → no reduction', () {
      final result = AvsCalculator.computeCouple(
        avsUser: 1500,
        avsConjoint: 1500,
        isMarried: true,
      );
      expect(result.total, equals(3000));
      expect(result.user, equals(1500));
    });
  });

  group('AvsCalculator.annualRente — 13e rente', () {
    test('rente max × 13 = 32760', () {
      final r = AvsCalculator.annualRente(avsRenteMaxMensuelle);
      expect(r, closeTo(avsRenteMaxMensuelle * 13, 0.01));
    });
    test('rente min × 13 = 16380', () {
      final r = AvsCalculator.annualRente(avsRenteMinMensuelle);
      expect(r, closeTo(avsRenteMinMensuelle * 13, 0.01));
    });
    test('couple max × 13 = 49140', () {
      final r = AvsCalculator.annualRente(avsRenteCoupleMaxMensuelle);
      expect(r, closeTo(avsRenteCoupleMaxMensuelle * 13, 0.01));
    });
    test('partial rente × 13', () {
      final r = AvsCalculator.annualRente(1890);
      expect(r, closeTo(1890 * 13, 0.01));
    });
    test('include13eme=false → × 12', () {
      final r = AvsCalculator.annualRente(avsRenteMaxMensuelle, include13eme: false);
      expect(r, closeTo(avsRenteMaxMensuelle * 12, 0.01));
    });
  });

  // F2-7: AVS21 gender-aware reference age tests (LAVS art. 21 al. 1)
  group('AvsCalculator — AVS21 gender-aware reference age', () {
    test('woman born 1960 → reference age 64 (pre-AVS21)', () {
      final refAge = avsReferenceAge(birthYear: 1960, isFemale: true);
      expect(refAge, equals(64));
    });

    test('woman born 1961 → reference age 64 (transitional +3 months)', () {
      final refAge = avsReferenceAge(birthYear: 1961, isFemale: true);
      expect(refAge, equals(64));
    });

    test('woman born 1962 → reference age 64 (transitional +6 months)', () {
      final refAge = avsReferenceAge(birthYear: 1962, isFemale: true);
      expect(refAge, equals(64));
    });

    test('woman born 1963 → reference age 65 (transitional +9 months)', () {
      final refAge = avsReferenceAge(birthYear: 1963, isFemale: true);
      expect(refAge, equals(65));
    });

    test('woman born 1964+ → reference age 65 (full AVS21 alignment)', () {
      final refAge = avsReferenceAge(birthYear: 1964, isFemale: true);
      expect(refAge, equals(65));
    });

    test('computeMonthlyRente uses gender-aware refAge for woman born 1960', () {
      // Woman born 1960 retiring at 64 → no penalty (refAge = 64)
      final renteAt64 = AvsCalculator.computeMonthlyRente(
        currentAge: 55,
        retirementAge: 64,
        grossAnnualSalary: 100000,
        isFemale: true,
        birthYear: 1960,
      );
      // Woman born 1960 retiring at 65 → same income, no early penalty
      final renteAt65 = AvsCalculator.computeMonthlyRente(
        currentAge: 55,
        retirementAge: 65,
        grossAnnualSalary: 100000,
        isFemale: true,
        birthYear: 1960,
      );
      // At 64 she is at her refAge → no penalty, but one fewer contribution year
      // At 65 she is 1 year past refAge → deferral bonus
      expect(renteAt65, greaterThan(renteAt64));
    });

    test('computeMonthlyRente: man at 64 has penalty, woman born 1960 at 64 does not', () {
      // Man retiring at 64 → 1 year early penalty (refAge 65)
      final renteMan = AvsCalculator.computeMonthlyRente(
        currentAge: 55,
        retirementAge: 64,
        grossAnnualSalary: 100000,
        isFemale: false,
        birthYear: 1960,
      );
      // Woman born 1960 retiring at 64 → no penalty (refAge 64)
      final renteWoman = AvsCalculator.computeMonthlyRente(
        currentAge: 55,
        retirementAge: 64,
        grossAnnualSalary: 100000,
        isFemale: true,
        birthYear: 1960,
      );
      // Woman gets more because no early retirement penalty
      expect(renteWoman, greaterThan(renteMan));
    });
  });
}
