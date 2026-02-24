/// Models for the minimal onboarding flow (Sprint S31).
///
/// MinimalProfileResult holds the computed financial snapshot from just
/// 3 inputs (age, salary, canton) plus optional enrichment fields.
/// ChiffreChoc represents the single impactful number shown to the user.
library;

/// Result of the minimal profile computation.
///
/// Contains retirement projections, tax saving estimates, and liquidity data.
/// Fields marked as estimated are tracked in [estimatedFields] for
/// confidence scoring.
class MinimalProfileResult {
  /// Monthly AVS rente at retirement (1st pillar).
  final double avsMonthlyRente;

  /// Projected LPP annual rente at retirement (2nd pillar).
  final double lppAnnualRente;

  /// Monthly LPP rente (lppAnnualRente / 12).
  final double lppMonthlyRente;

  /// Total monthly retirement income (AVS + LPP).
  final double totalMonthlyRetirement;

  /// Current gross monthly salary.
  final double grossMonthlySalary;

  /// Retirement replacement rate (totalMonthlyRetirement / grossMonthlySalary).
  final double replacementRate;

  /// Retirement income gap in CHF/month (salary - retirement income).
  final double retirementGapMonthly;

  /// Annual tax saving from maxing out 3a contributions.
  final double taxSaving3a;

  /// Estimated marginal tax rate for this profile.
  final double marginalTaxRate;

  /// Estimated current savings (liquid reserves).
  final double currentSavings;

  /// Monthly expenses estimate (for liquidity analysis).
  final double estimatedMonthlyExpenses;

  /// Liquidity coverage in months (currentSavings / monthlyExpenses).
  final double liquidityMonths;

  /// Canton code used for the computation.
  final String canton;

  /// Age used for the computation.
  final int age;

  /// Gross annual salary used for the computation.
  final double grossAnnualSalary;

  /// Household type used ('single', 'couple', 'family').
  final String householdType;

  /// Whether the user is a property owner.
  final bool isPropertyOwner;

  /// Existing 3a balance.
  final double existing3a;

  /// Existing LPP balance.
  final double existingLpp;

  /// List of fields that were estimated (not provided by the user).
  final List<String> estimatedFields;

  /// Number of data points actually provided by the user.
  int get providedFieldsCount {
    // Base 3 fields (age, salary, canton) are always provided.
    // Additional fields reduce estimatedFields count.
    const totalOptionalFields = 5; // household, savings, property, 3a, lpp
    return 3 + (totalOptionalFields - estimatedFields.length);
  }

  const MinimalProfileResult({
    required this.avsMonthlyRente,
    required this.lppAnnualRente,
    required this.lppMonthlyRente,
    required this.totalMonthlyRetirement,
    required this.grossMonthlySalary,
    required this.replacementRate,
    required this.retirementGapMonthly,
    required this.taxSaving3a,
    required this.marginalTaxRate,
    required this.currentSavings,
    required this.estimatedMonthlyExpenses,
    required this.liquidityMonths,
    required this.canton,
    required this.age,
    required this.grossAnnualSalary,
    required this.householdType,
    required this.isPropertyOwner,
    required this.existing3a,
    required this.existingLpp,
    required this.estimatedFields,
  });
}

/// Types of chiffre choc that can be selected.
enum ChiffreChocType {
  /// Liquidity reserve dangerously low (< 2 months expenses).
  liquidityAlert,

  /// Retirement replacement rate below 55% of current income.
  retirementGap,

  /// Potential annual tax saving from 3a contributions.
  taxSaving3a,

  /// Retirement income projection (fallback / positive).
  retirementIncome,
}

/// A single impactful number to show the user.
///
/// Selected by [ChiffreChocSelector] based on priority rules.
class ChiffreChoc {
  /// The type of chiffre choc.
  final ChiffreChocType type;

  /// The main number to display (formatted for display).
  final String value;

  /// The raw numeric value (for animations).
  final double rawValue;

  /// Short title above the number.
  final String title;

  /// Contextual subtitle below the number.
  final String subtitle;

  /// Icon suggestion for the card.
  final String iconName;

  /// Color suggestion key ('warning', 'success', 'info', 'error').
  final String colorKey;

  const ChiffreChoc({
    required this.type,
    required this.value,
    required this.rawValue,
    required this.title,
    required this.subtitle,
    required this.iconName,
    required this.colorKey,
  });
}
