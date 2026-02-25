import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/simulators/lpp_buyback_advanced_simulator.dart';

void main() {
  // =========================================================================
  // LPP BUYBACK ADVANCED SIMULATOR — Unit tests
  // =========================================================================
  //
  // Tests the advanced LPP buy-back strategy simulator:
  //   - Staggered buy-back over multiple years
  //   - Tax savings estimation (marginal rate heuristic)
  //   - Interest compounding on pension fund balance
  //   - Real annual return (IRR) calculation
  //   - Year-by-year breakdown structure
  //   - Edge cases (zero values, single year, max horizon)
  //
  // Swiss law references:
  //   - LPP art. 79b: rachat deductible du revenu imposable
  //   - LPP art. 79b al. 3: blocage 3 ans apres rachat (EPL)
  //   - OPP2 art. 5: EPL minimum 20'000 CHF
  //
  // Sources: LIFD art. 33 al. 1 let. d, LPP art. 79b.
  // =========================================================================

  group('LppBuybackAdvancedSimulator.simulate - structure du resultat', () {
    test('returns all expected fields', () {
      final result = LppBuybackAdvancedSimulator.simulate(
        totalBuybackPotential: 100000,
        yearsUntilRetirement: 10,
        staggeringYears: 5,
        annualInterestRate: 0.02,
        taxableIncome: 120000,
      );

      expect(result.totalInvestedBrut, isA<double>());
      expect(result.totalTaxSavings, isA<double>());
      expect(result.netEffort, isA<double>());
      expect(result.finalCapital, isA<double>());
      expect(result.totalValueGained, isA<double>());
      expect(result.realAnnualReturn, isA<double>());
      expect(result.breakdown, isA<List<StaggeredYearBreakdown>>());
    });

    test('totalInvestedBrut equals input totalBuybackPotential', () {
      final result = LppBuybackAdvancedSimulator.simulate(
        totalBuybackPotential: 200000,
        yearsUntilRetirement: 15,
        staggeringYears: 5,
        annualInterestRate: 0.02,
      );
      expect(result.totalInvestedBrut, 200000);
    });

    test('breakdown has yearsUntilRetirement entries', () {
      final result = LppBuybackAdvancedSimulator.simulate(
        totalBuybackPotential: 100000,
        yearsUntilRetirement: 13,
        staggeringYears: 5,
        annualInterestRate: 0.02,
      );
      expect(result.breakdown.length, 13);
    });

    test('breakdown years are sequential from 1 to N', () {
      final result = LppBuybackAdvancedSimulator.simulate(
        totalBuybackPotential: 100000,
        yearsUntilRetirement: 10,
        staggeringYears: 3,
        annualInterestRate: 0.02,
      );
      for (int i = 0; i < result.breakdown.length; i++) {
        expect(result.breakdown[i].year, i + 1);
      }
    });
  });

  group('LppBuybackAdvancedSimulator.simulate - staggering logic', () {
    test('contributions only in staggering years', () {
      final result = LppBuybackAdvancedSimulator.simulate(
        totalBuybackPotential: 100000,
        yearsUntilRetirement: 10,
        staggeringYears: 3,
        annualInterestRate: 0.02,
      );

      // First 3 years should have contributions
      for (int i = 0; i < 3; i++) {
        expect(result.breakdown[i].contribution, greaterThan(0),
            reason: 'Year ${i + 1} should have contribution');
      }
      // Remaining years should have zero contributions
      for (int i = 3; i < 10; i++) {
        expect(result.breakdown[i].contribution, 0,
            reason: 'Year ${i + 1} should have zero contribution');
      }
    });

    test('annual contribution equals totalBuyback / staggeringYears', () {
      final result = LppBuybackAdvancedSimulator.simulate(
        totalBuybackPotential: 150000,
        yearsUntilRetirement: 10,
        staggeringYears: 5,
        annualInterestRate: 0.02,
      );

      const expectedAnnual = 150000 / 5;
      for (int i = 0; i < 5; i++) {
        expect(result.breakdown[i].contribution, closeTo(expectedAnnual, 0.01));
      }
    });

    test('tax savings only in staggering years', () {
      final result = LppBuybackAdvancedSimulator.simulate(
        totalBuybackPotential: 100000,
        yearsUntilRetirement: 10,
        staggeringYears: 3,
        annualInterestRate: 0.02,
        taxableIncome: 120000,
      );

      for (int i = 0; i < 3; i++) {
        expect(result.breakdown[i].taxSaving, greaterThan(0),
            reason: 'Year ${i + 1} should have tax saving');
      }
      for (int i = 3; i < 10; i++) {
        expect(result.breakdown[i].taxSaving, 0,
            reason: 'Year ${i + 1} should have zero tax saving');
      }
    });
  });

  group('LppBuybackAdvancedSimulator.simulate - financial calculations', () {
    test('netEffort equals totalInvestedBrut minus totalTaxSavings', () {
      final result = LppBuybackAdvancedSimulator.simulate(
        totalBuybackPotential: 100000,
        yearsUntilRetirement: 10,
        staggeringYears: 5,
        annualInterestRate: 0.02,
        taxableIncome: 120000,
      );
      expect(result.netEffort,
          closeTo(result.totalInvestedBrut - result.totalTaxSavings, 0.01));
    });

    test('totalValueGained equals finalCapital minus netEffort', () {
      final result = LppBuybackAdvancedSimulator.simulate(
        totalBuybackPotential: 100000,
        yearsUntilRetirement: 10,
        staggeringYears: 5,
        annualInterestRate: 0.02,
        taxableIncome: 120000,
      );
      expect(result.totalValueGained,
          closeTo(result.finalCapital - result.netEffort, 0.01));
    });

    test('finalCapital is greater than totalInvestedBrut with positive interest', () {
      final result = LppBuybackAdvancedSimulator.simulate(
        totalBuybackPotential: 100000,
        yearsUntilRetirement: 10,
        staggeringYears: 5,
        annualInterestRate: 0.02,
      );
      // With 2% interest compounding, final capital should exceed input
      expect(result.finalCapital, greaterThan(result.totalInvestedBrut));
    });

    test('balance increases monotonically in breakdown', () {
      final result = LppBuybackAdvancedSimulator.simulate(
        totalBuybackPotential: 100000,
        yearsUntilRetirement: 10,
        staggeringYears: 5,
        annualInterestRate: 0.02,
      );
      for (int i = 1; i < result.breakdown.length; i++) {
        expect(result.breakdown[i].balance,
            greaterThanOrEqualTo(result.breakdown[i - 1].balance),
            reason: 'Balance should increase over time');
      }
    });

    test('real annual return is positive when interest is positive', () {
      final result = LppBuybackAdvancedSimulator.simulate(
        totalBuybackPotential: 100000,
        yearsUntilRetirement: 10,
        staggeringYears: 5,
        annualInterestRate: 0.02,
        taxableIncome: 120000,
      );
      // With interest + tax savings, real return should be > 0
      expect(result.realAnnualReturn, greaterThan(0));
    });

    test('higher interest rate produces higher final capital', () {
      final resultLow = LppBuybackAdvancedSimulator.simulate(
        totalBuybackPotential: 100000,
        yearsUntilRetirement: 15,
        staggeringYears: 5,
        annualInterestRate: 0.01,
        taxableIncome: 120000,
      );
      final resultHigh = LppBuybackAdvancedSimulator.simulate(
        totalBuybackPotential: 100000,
        yearsUntilRetirement: 15,
        staggeringYears: 5,
        annualInterestRate: 0.04,
        taxableIncome: 120000,
      );
      expect(resultHigh.finalCapital, greaterThan(resultLow.finalCapital));
    });
  });

  group('LppBuybackAdvancedSimulator.simulate - tax savings', () {
    test('tax savings are positive for income above 15k', () {
      final result = LppBuybackAdvancedSimulator.simulate(
        totalBuybackPotential: 50000,
        yearsUntilRetirement: 10,
        staggeringYears: 5,
        annualInterestRate: 0.02,
        taxableIncome: 120000,
      );
      expect(result.totalTaxSavings, greaterThan(0));
    });

    test('higher income generates higher tax savings (progressive rate)', () {
      final resultLow = LppBuybackAdvancedSimulator.simulate(
        totalBuybackPotential: 50000,
        yearsUntilRetirement: 10,
        staggeringYears: 5,
        annualInterestRate: 0.02,
        taxableIncome: 60000,
      );
      final resultHigh = LppBuybackAdvancedSimulator.simulate(
        totalBuybackPotential: 50000,
        yearsUntilRetirement: 10,
        staggeringYears: 5,
        annualInterestRate: 0.02,
        taxableIncome: 200000,
      );
      expect(resultHigh.totalTaxSavings,
          greaterThan(resultLow.totalTaxSavings));
    });

    test('tax savings less than total invested (sanity check)', () {
      final result = LppBuybackAdvancedSimulator.simulate(
        totalBuybackPotential: 100000,
        yearsUntilRetirement: 10,
        staggeringYears: 5,
        annualInterestRate: 0.02,
        taxableIncome: 200000,
      );
      // Max marginal rate is 42%, so savings < 42% of buyback
      expect(result.totalTaxSavings, lessThan(result.totalInvestedBrut * 0.45));
    });
  });

  group('LppBuybackAdvancedSimulator.simulate - edge cases', () {
    test('zero buyback potential returns zero values', () {
      final result = LppBuybackAdvancedSimulator.simulate(
        totalBuybackPotential: 0,
        yearsUntilRetirement: 10,
        staggeringYears: 5,
        annualInterestRate: 0.02,
      );
      expect(result.totalInvestedBrut, 0);
      expect(result.totalTaxSavings, 0);
      expect(result.netEffort, 0);
      expect(result.finalCapital, closeTo(0, 0.01));
    });

    test('zero interest rate means final capital equals invested amount', () {
      final result = LppBuybackAdvancedSimulator.simulate(
        totalBuybackPotential: 100000,
        yearsUntilRetirement: 10,
        staggeringYears: 10,
        annualInterestRate: 0.0,
        taxableIncome: 120000,
      );
      // With 0% interest, final balance = sum of contributions = totalBuyback
      expect(result.finalCapital, closeTo(100000, 0.01));
    });

    test('staggering over 1 year concentrates all in year 1', () {
      final result = LppBuybackAdvancedSimulator.simulate(
        totalBuybackPotential: 50000,
        yearsUntilRetirement: 10,
        staggeringYears: 1,
        annualInterestRate: 0.02,
      );
      expect(result.breakdown[0].contribution, 50000);
      for (int i = 1; i < result.breakdown.length; i++) {
        expect(result.breakdown[i].contribution, 0);
      }
    });

    test('staggering equals retirement years', () {
      final result = LppBuybackAdvancedSimulator.simulate(
        totalBuybackPotential: 100000,
        yearsUntilRetirement: 5,
        staggeringYears: 5,
        annualInterestRate: 0.02,
        taxableIncome: 120000,
      );
      // All 5 years should have contributions
      for (final entry in result.breakdown) {
        expect(entry.contribution, closeTo(20000, 0.01));
      }
    });

    test('very low income (below 15k) generates near-zero tax savings', () {
      final result = LppBuybackAdvancedSimulator.simulate(
        totalBuybackPotential: 50000,
        yearsUntilRetirement: 10,
        staggeringYears: 5,
        annualInterestRate: 0.02,
        taxableIncome: 10000,
      );
      // Rate at income < 15000 is 0%, so no tax saving
      expect(result.totalTaxSavings, closeTo(0, 0.01));
    });
  });

  group('LppBuybackAdvancedSimulator - scenario Julien', () {
    test('300k buyback over 5 years, 13 years horizon, 2% interest', () {
      // Based on the demo profile: Julien, 300k buyback potential
      final result = LppBuybackAdvancedSimulator.simulate(
        totalBuybackPotential: 300000,
        yearsUntilRetirement: 13,
        staggeringYears: 5,
        annualInterestRate: 0.02,
        taxableIncome: 120000,
      );

      // Buyback per year = 60k
      expect(result.breakdown[0].contribution, closeTo(60000, 0.01));

      // Final capital should be substantially above 300k due to compounding
      expect(result.finalCapital, greaterThan(300000));

      // Tax savings should be meaningful (at 120k income, ~27% marginal rate)
      expect(result.totalTaxSavings, greaterThan(50000));

      // Real annual return should be reasonable (> 2% due to tax boost)
      expect(result.realAnnualReturn, greaterThan(0.02));

      // Net effort should be less than 300k
      expect(result.netEffort, lessThan(300000));
    });
  });
}
