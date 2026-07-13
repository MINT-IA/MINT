import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/financial_core/avs_reference_age.dart';

import 'avs_couple_test_fixtures.dart';

void main() {
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

  group('AvsCalculator.computeCouplePensions', () {
    test('married couple capped at 3780', () {
      final result = officialScale44AvsCouple(
        selfPension: 2520,
        partnerPension: 2520,
        legalStatus: AvsCoupleLegalStatus.married,
      );
      expect(
        result.householdMonthlyPension,
        equals(avsRenteCoupleMaxMensuelle),
      );
      expect(result.self.cappedMonthlyPension, closeTo(1890, 1));
      expect(result.partner.cappedMonthlyPension, closeTo(1890, 1));
    });

    test('concubin couple NOT capped', () {
      final result = officialScale44AvsCouple(
        selfPension: 2520,
        partnerPension: 2520,
        legalStatus: AvsCoupleLegalStatus.cohabiting,
      );
      expect(result.householdMonthlyPension, equals(5040));
      expect(result.self.cappedMonthlyPension, equals(2520));
      expect(result.partner.cappedMonthlyPension, equals(2520));
    });

    test('married below cap → no reduction', () {
      final result = officialScale44AvsCouple(
        selfPension: 1500,
        partnerPension: 1500,
        legalStatus: AvsCoupleLegalStatus.married,
      );
      expect(result.householdMonthlyPension, equals(3000));
      expect(result.self.cappedMonthlyPension, equals(1500));
    });
  });

  group('AvsCalculator.ordinaryRecurringLifetimeLoss', () {
    test('uses twelve ordinary monthly payments per modeled year', () {
      final loss = AvsCalculator.ordinaryRecurringLifetimeLoss(200, 20);

      expect(loss, closeTo(200 * 12 * 20, 0.01));
    });

    test('rejects non-finite or non-positive monthly losses', () {
      for (final monthlyLoss in [
        double.nan,
        double.infinity,
        double.negativeInfinity,
        0.0,
        -1.0,
      ]) {
        expect(
          AvsCalculator.ordinaryRecurringLifetimeLoss(monthlyLoss, 20),
          0,
        );
      }
    });

    test('rejects non-positive modeled retirement years', () {
      for (final years in [0, -1]) {
        expect(
          AvsCalculator.ordinaryRecurringLifetimeLoss(200, years),
          0,
        );
      }
    });
  });

  // F2-7: AVS21 gender-aware reference age tests (LAVS art. 21 al. 1)
  group('AvsCalculator — AVS21 gender-aware reference age', () {
    test('women born 1961-1963 expose exact AVS21 reference months', () {
      expect(
        avsReferenceAgeMonths(birthYear: 1961, isFemale: true),
        equals(64 * 12 + 3),
      );
      expect(
        avsReferenceAgeMonths(birthYear: 1962, isFemale: true),
        equals(64 * 12 + 6),
      );
      expect(
        avsReferenceAgeMonths(birthYear: 1963, isFemale: true),
        equals(64 * 12 + 9),
      );
    });

    test('woman born 1962 exposes a 64.5-year reference age', () {
      expect(
        avsReferenceAgeYears(birthYear: 1962, isFemale: true),
        equals(64.5),
      );
    });

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

    test('same cohort keeps distinct male and female reference ages', () {
      expect(
        avsReferenceAgeYears(birthYear: 1960, isFemale: true),
        equals(64),
      );
      expect(
        avsReferenceAgeYears(birthYear: 1960, isFemale: false),
        equals(65),
      );
    });

  });
}
