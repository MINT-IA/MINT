/// BudgetSnapshot — unified budget data model for MINT.
///
/// This is the single source of truth consumed by PulseScreen,
/// BudgetScreen, and any widget displaying budget/gap figures.
///
/// Computed by [BudgetLivingEngine] from a [CoachProfile].
/// All amounts in CHF/month.
library;

// ════════════════════════════════════════════════════════════
//  STAGE
// ════════════════════════════════════════════════════════════

/// Stage determines which information the UI can usefully display.
///
/// - [presentOnly]         Income and charges are known; no retirement data.
/// - [emergingRetirement]  Retirement income computed, but gap not yet
///                         meaningful (profile partial, confidence < 40%).
/// - [fullGapVisible]      Both present and retirement are computed and
///                         the gap is worth surfacing to the user.
enum BudgetStage { presentOnly, emergingRetirement, fullGapVisible }

// ════════════════════════════════════════════════════════════
//  SUB-MODELS
// ════════════════════════════════════════════════════════════

/// Present-day monthly budget breakdown.
///
/// [monthlyNet]       Household net income (main + partner if couple).
/// [monthlyCharges]   Sum of all fixed charges (housing, health, taxes,
///                    debt repayments, other fixed).
/// [monthlySavings]   Planned savings out-flows (3a + LPP buybacks).
/// [monthlyFree]      Remainder: net - charges - savings.
///                    Can be negative (deficit mode).
class PresentBudget {
  final double monthlyNet;
  final double monthlyCharges;
  final double monthlySavings;
  final double monthlyFree;

  const PresentBudget({
    required this.monthlyNet,
    required this.monthlyCharges,
    required this.monthlySavings,
    required this.monthlyFree,
  });

  /// True when the user is running a monthly deficit.
  bool get isDeficit => monthlyFree < 0;

  /// Charges as percentage of net income (0-100+).
  double get chargesRatio =>
      monthlyNet > 0 ? (monthlyCharges / monthlyNet * 100).clamp(0, 200) : 0;
}

/// Projected retirement monthly budget.
///
/// [monthlyIncome]  Total projected retirement income
///                  (AVS + LPP rente + 3a annualised + SWR on free).
/// [monthlyTax]     Estimated income tax on retirement rentes.
/// [monthlyNet]     After-tax net retirement income.
class RetirementBudget {
  final double monthlyIncome;
  final double monthlyTax;
  final double monthlyNet;

  const RetirementBudget({
    required this.monthlyIncome,
    required this.monthlyTax,
    required this.monthlyNet,
  });
}

/// The gap between present and projected retirement income.
///
/// [monthlyGap]     Present net minus retirement net income.
///                  Positive = gap (retirement worse than today).
///                  Negative = surplus (retirement better than today — rare).
/// [replacementRate]  Retirement income as % of current net income (0-200%).
/// [isSignificant]  True when gap > 20% of current net income.
class BudgetGap {
  final double monthlyGap;
  final double replacementRate;

  const BudgetGap({
    required this.monthlyGap,
    required this.replacementRate,
  });

  /// True when the gap is worth surfacing (> 20% of present net).
  bool isSignificant(double presentNet) =>
      presentNet > 0 && monthlyGap > presentNet * 0.20;

  /// True when retirement is expected to be better than today.
  bool get isSurplus => monthlyGap < 0;
}

/// The incremental monthly impact of activating a cap on the gap.
///
/// Represents one levier: "if you activate X, the gap shrinks by Y/month".
///
/// [capId]          Identifier of the cap (e.g. 'rachat_lpp', '3a_max').
/// [monthlyDelta]   Positive = reduces gap. Negative = widens gap (unusual).
/// [capLabel]       Human-readable label (ARB key, resolved by caller).
class BudgetCapImpact {
  final String capId;
  final double monthlyDelta;

  const BudgetCapImpact({
    required this.capId,
    required this.monthlyDelta,
  });
}

// ════════════════════════════════════════════════════════════
//  SNAPSHOT
// ════════════════════════════════════════════════════════════

/// The complete budget snapshot for a given profile.
///
/// Produced by [BudgetLivingEngine.compute]. Immutable.
class BudgetSnapshot {
  /// Present-day budget breakdown.
  final PresentBudget present;

  /// Projected retirement budget. Null when stage == presentOnly.
  final RetirementBudget? retirement;

  /// Budget gap. Null when stage == presentOnly.
  final BudgetGap? gap;

  /// Cap impacts — ordered by descending monthly delta (biggest lever first).
  final List<BudgetCapImpact> capImpacts;

  /// Stage determines which UI sections can be shown.
  final BudgetStage stage;

  /// Confidence score 0-100 from EnhancedConfidence (mandatory on projections).
  final double confidenceScore;

  const BudgetSnapshot({
    required this.present,
    this.retirement,
    this.gap,
    required this.capImpacts,
    required this.stage,
    required this.confidenceScore,
  });

  /// Convenience: monthlyFree (always available, even if stage == presentOnly).
  double get monthlyFree => present.monthlyFree;

  /// True if the full gap between present and retirement is surfaceable.
  bool get hasFullGap => stage == BudgetStage.fullGapVisible && gap != null;
}
