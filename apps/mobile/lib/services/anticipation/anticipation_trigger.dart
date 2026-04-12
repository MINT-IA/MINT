// ────────────────────────────────────────────────────────────
//  ANTICIPATION TRIGGER — Phase 04 / Moteur d'Anticipation
// ────────────────────────────────────────────────────────────
//
// Defines all anticipation trigger types used by AnticipationEngine.
//
// Each trigger maps to an educational alert format (ANT-03)
// with title + fact + legal source + simulator link.
//
// Design: Pure enum, zero LLM, zero async (ANT-08).
// Pattern: Follows NudgeTrigger from S61.
// ────────────────────────────────────────────────────────────

/// All possible anticipation trigger types.
///
/// Each trigger detects a time-sensitive financial event
/// and produces an [AnticipationSignal] via [AnticipationEngine].
enum AnticipationTrigger {
  /// December: 3a versement deadline approaching (Dec 31).
  /// Uses archetype-aware plafond (7'258 CHF vs 36'288 CHF).
  fiscal3aDeadline,

  /// Cantonal tax declaration deadline approaching.
  /// Fires 45 days before canton-specific deadline.
  cantonalTaxDeadline,

  /// Q4 (October-December): LPP rachat (buyback) window.
  /// Tax-deductible before year-end for eligible users.
  lppRachatWindow,

  /// Salary increase detected (>5% or >2'000 CHF).
  /// Recalculate 3a strategy with new income.
  salaryIncrease3aRecalc,

  /// User crosses an LPP bonification bracket boundary (35, 45, 55).
  /// New contribution rate applies — review pension strategy.
  ageMilestoneLppBonification,
}
