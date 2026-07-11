class WealthFinancialFacts {
  const WealthFinancialFacts._();

  static double propertyNetValue({
    required double propertyValue,
    required double mortgageBalance,
  }) {
    return propertyValue - mortgageBalance;
  }

  static double netWealth({
    required double totalAssets,
    required double totalDebts,
  }) {
    return totalAssets - totalDebts;
  }

  static double consumerDebt({
    required double consumerCredit,
    required double leasing,
  }) {
    return consumerCredit + leasing;
  }
}
