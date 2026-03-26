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

  group('AvsCalculator.renteFromRAMD', () {
    test('high income → max rente', () {
      expect(AvsCalculator.renteFromRAMD(100000), equals(avsRenteMaxMensuelle));
    });

    test('low income → min rente', () {
      expect(AvsCalculator.renteFromRAMD(10000), equals(avsRenteMinMensuelle));
    });

    test('mid income → interpolated', () {
      const mid = (avsRAMDMin + avsRAMDMax) / 2; // 51450
      final rente = AvsCalculator.renteFromRAMD(mid);
      const expected = (avsRenteMinMensuelle + avsRenteMaxMensuelle) / 2;
      expect(rente, closeTo(expected, 1));
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
