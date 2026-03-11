import 'dart:math';

import 'package:mint_mobile/services/financial_core/financial_core.dart';

class LppAdvancedResult {
  final double totalInvestedBrut;
  final double totalTaxSavings;
  final double netEffort;
  final double finalCapital;
  final double totalValueGained; // finalCapital - netEffort
  final double realAnnualReturn; // IRR effectively
  final List<StaggeredYearBreakdown> breakdown;

  LppAdvancedResult({
    required this.totalInvestedBrut,
    required this.totalTaxSavings,
    required this.netEffort,
    required this.finalCapital,
    required this.totalValueGained,
    required this.realAnnualReturn,
    required this.breakdown,
  });
}

class StaggeredYearBreakdown {
  final int year;
  final double contribution;
  final double taxSaving;
  final double balance;

  StaggeredYearBreakdown({
    required this.year,
    required this.contribution,
    required this.taxSaving,
    required this.balance,
  });
}

class LppBuybackAdvancedSimulator {
  /// Simulates an advanced LPP buy-back strategy.
  ///
  /// [totalBuybackPotential]: Total amount to buy back (e.g. 300,000)
  /// [yearsUntilRetirement]: Horizon until withdrawal (e.g. 13)
  /// [staggeringYears]: Over how many years to spread the buy-back (e.g. 5)
  /// [annualInterestRate]: Interest rate of the pension fund (e.g. 0.02)
  /// [taxableIncome]: Current taxable income for marginal rate estimate
  static LppAdvancedResult simulate({
    required double totalBuybackPotential,
    required int yearsUntilRetirement,
    required int staggeringYears,
    required double annualInterestRate,
    double taxableIncome = 120000,
    String canton = 'ZH',
  }) {
    double totalTaxSavings = 0;
    double currentBalance = 0;
    List<StaggeredYearBreakdown> breakdown = [];

    final buybackPerYear = totalBuybackPotential / staggeringYears;

    for (int y = 1; y <= yearsUntilRetirement; y++) {
      double contribution = 0;
      double currentYearTaxSaving = 0;

      if (y <= staggeringYears) {
        contribution = buybackPerYear;
        // Estimate tax saving for this year's slice
        currentYearTaxSaving = RetirementTaxCalculator.estimateTaxSaving(income: taxableIncome, deduction: contribution, canton: canton);
        totalTaxSavings += currentYearTaxSaving;
      }

      // Add contribution and interests
      currentBalance =
          (currentBalance + contribution) * (1 + annualInterestRate);

      breakdown.add(StaggeredYearBreakdown(
        year: y,
        contribution: contribution,
        taxSaving: currentYearTaxSaving,
        balance: currentBalance,
      ));
    }

    final netEffort = totalBuybackPotential - totalTaxSavings;
    final totalValueGained = currentBalance - netEffort;

    // Calculate IRR (Real Annual Return)
    // We search for 'i' such that NetEffort * (1+i)^years = CurrentBalance
    // This is a simplified IRR assuming net effort is central or all at the start for pedagogy.
    // For a more precise IRR, we'd need to root-find the CF.
    // Let's use the simplified formula for the "Real internal rate of return" over the whole period
    double realReturn = 0;
    if (netEffort > 0 && yearsUntilRetirement > 0) {
      realReturn =
          pow(currentBalance / netEffort, 1 / yearsUntilRetirement) - 1;
    }

    return LppAdvancedResult(
      totalInvestedBrut: totalBuybackPotential,
      totalTaxSavings: totalTaxSavings,
      netEffort: netEffort,
      finalCapital: currentBalance,
      totalValueGained: totalValueGained,
      realAnnualReturn: realReturn,
      breakdown: breakdown,
    );
  }

}
