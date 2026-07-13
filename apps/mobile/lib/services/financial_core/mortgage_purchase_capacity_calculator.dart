import 'dart:math' show min;

import 'package:mint_mobile/constants/social_insurance.dart';

/// Canonical income-and-equity constraints for a Swiss home purchase.
///
/// The rates come from the regulatory registry. Callers remain responsible
/// for deciding whether zero-valued inputs mean "known zero" or "missing".
class MortgagePurchaseCapacityCalculator {
  MortgagePurchaseCapacityCalculator._();

  static ({double maximumPurchasePrice, bool isRevenueConstrained}) calculate({
    required double annualGrossIncome,
    required double liquidSavings,
    required double pillar3aAssets,
    required double pensionFundAssets,
  }) {
    final income = annualGrossIncome.clamp(0.0, 1000000.0);
    final savings = liquidSavings.clamp(0.0, 5000000.0);
    final pillar3a = pillar3aAssets.clamp(0.0, 1000000.0);
    final pensionFund = pensionFundAssets.clamp(0.0, 2000000.0);

    final theoreticalRate =
        reg('mortgage.theoretical_rate', hypothequeTauxTheorique);
    final amortizationRate =
        reg('mortgage.amortization_rate', hypothequeTauxAmortissement);
    final totalChargesRate =
        reg('mortgage.total_charges_rate', hypothequeTauxChargesTotal);
    final maximumChargeRatio =
        reg('mortgage.max_charge_ratio', hypothequeRatioChargesMax);
    final minimumEquityRatio =
        reg('mortgage.min_equity_ratio', hypothequeFondsPropresMin);
    final maximumPensionFundRatio =
        reg('mortgage.max_2nd_pillar_ratio', hypothequePart2ePilierMax);
    final mortgageChargesRate = theoreticalRate + amortizationRate;
    final hardEquity = savings + pillar3a;

    double maximumPriceByIncome;
    if (income <= 0) {
      maximumPriceByIncome = 0;
    } else {
      final fullPensionFundPrice = (income * maximumChargeRatio +
              (hardEquity + pensionFund) * mortgageChargesRate) /
          totalChargesRate;
      if (pensionFund <= fullPensionFundPrice * maximumPensionFundRatio) {
        maximumPriceByIncome = fullPensionFundPrice;
      } else {
        final effectiveRate =
            totalChargesRate - maximumPensionFundRatio * mortgageChargesRate;
        maximumPriceByIncome =
            (income * maximumChargeRatio + hardEquity * mortgageChargesRate) /
                effectiveRate;
      }
    }

    final fullEquityPrice = (hardEquity + pensionFund) / minimumEquityRatio;
    final maximumPriceByEquity =
        pensionFund <= fullEquityPrice * maximumPensionFundRatio
            ? fullEquityPrice
            : hardEquity > 0
                ? hardEquity / (minimumEquityRatio - maximumPensionFundRatio)
                : 0.0;

    return (
      maximumPurchasePrice: min(maximumPriceByIncome, maximumPriceByEquity),
      isRevenueConstrained: maximumPriceByIncome < maximumPriceByEquity,
    );
  }
}
