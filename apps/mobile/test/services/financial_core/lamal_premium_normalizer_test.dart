import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/lamal_premium_normalizer.dart';

void main() {
  group('LamalPremiumNormalizer', () {
    const savingsVs300 = <int, double>{
      300: 0.0,
      500: 0.05,
      1000: 0.13,
      1500: 0.19,
      2000: 0.24,
      2500: 0.28,
    };

    test('lifts an actual adult premium back to the CHF 300 baseline', () {
      final normalized = LamalPremiumNormalizer.toFranchise300MonthlyPremium(
        monthlyPremium: 390,
        currentFranchise: 2500,
        isChild: false,
        premiumSavingsVs300: savingsVs300,
      );

      expect(normalized, closeTo(390 / 0.72, 0.01));
    });

    test('leaves CHF 300, child, unknown, and invalid inputs unchanged', () {
      expect(
        LamalPremiumNormalizer.toFranchise300MonthlyPremium(
          monthlyPremium: 540,
          currentFranchise: 300,
          isChild: false,
          premiumSavingsVs300: savingsVs300,
        ),
        540,
      );
      expect(
        LamalPremiumNormalizer.toFranchise300MonthlyPremium(
          monthlyPremium: 110,
          currentFranchise: 500,
          isChild: true,
          premiumSavingsVs300: savingsVs300,
        ),
        110,
      );
      expect(
        LamalPremiumNormalizer.toFranchise300MonthlyPremium(
          monthlyPremium: 540,
          currentFranchise: 999,
          isChild: false,
          premiumSavingsVs300: savingsVs300,
        ),
        540,
      );
      expect(
        LamalPremiumNormalizer.toFranchise300MonthlyPremium(
          monthlyPremium: 0,
          currentFranchise: 2500,
          isChild: false,
          premiumSavingsVs300: savingsVs300,
        ),
        0,
      );
    });
  });
}
