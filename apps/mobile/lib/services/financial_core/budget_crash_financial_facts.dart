class BudgetCrashTotals {
  const BudgetCrashTotals({
    required this.totalNormal,
    required this.totalSurvival,
    required this.marginNormal,
    required this.marginSurvival,
    required this.saving,
  });

  final double totalNormal;
  final double totalSurvival;
  final double marginNormal;
  final double marginSurvival;
  final double saving;
}

class BudgetCrashFinancialFacts {
  const BudgetCrashFinancialFacts._();

  static const double _expensePlausibilityMarginMultiplier = 1.5;

  static bool isMonthlyExpensePlausible({
    required double monthlyExpense,
    required double grossMonthlyIncome,
    required double maximumExpenseRatio,
  }) {
    if (!monthlyExpense.isFinite || monthlyExpense <= 0) return false;
    if (grossMonthlyIncome <= 0) return true;
    if (!grossMonthlyIncome.isFinite ||
        !maximumExpenseRatio.isFinite ||
        maximumExpenseRatio <= 0) {
      return false;
    }
    final ceiling = grossMonthlyIncome *
        maximumExpenseRatio *
        _expensePlausibilityMarginMultiplier;
    return monthlyExpense <= ceiling;
  }

  static BudgetCrashTotals calculate({
    required double monthlyIncome,
    required double survivalIncome,
    required Iterable<double> normalAmounts,
    required Iterable<double> survivalAmounts,
  }) {
    final totalNormal =
        normalAmounts.fold<double>(0, (s, amount) => s + amount);
    final totalSurvival =
        survivalAmounts.fold<double>(0, (s, amount) => s + amount);
    return BudgetCrashTotals(
      totalNormal: totalNormal,
      totalSurvival: totalSurvival,
      marginNormal: monthlyIncome - totalNormal,
      marginSurvival: survivalIncome - totalSurvival,
      saving: totalNormal - totalSurvival,
    );
  }
}
