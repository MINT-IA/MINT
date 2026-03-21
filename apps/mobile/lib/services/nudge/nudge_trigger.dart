// ────────────────────────────────────────────────────────────
//  NUDGE TRIGGER — S61 / JITAI Proactive Nudges
// ────────────────────────────────────────────────────────────
//
// Defines all nudge trigger types used by NudgeEngine.
//
// Research basis:
//   JITAI = Just-In-Time Adaptive Intervention.
//   52% engagement boost at workflow boundaries (post-salary,
//   pre-tax-deadline). Nudges must be:
//   - Positive framing (never fear-based)
//   - Contextual (triggered by real events)
//   - Non-intrusive (never interrupt mid-task)
//   - Educational (never prescriptive)
//
// Source: Nahum-Shani et al. (2018), Liao et al. (2020).
// ────────────────────────────────────────────────────────────

/// All possible nudge trigger types.
enum NudgeTrigger {
  /// Monthly salary deposit window (1st–5th of month).
  /// Reminds user to transfer to 3a.
  salaryReceived,

  /// Approaching Swiss tax filing deadline.
  /// Triggers in February–March (March 31) and August–September (Sept 30).
  taxDeadlineApproach,

  /// December: "Il reste {days} jours pour verser sur ton 3a".
  /// Uses archetype-aware plafond (7'258 CHF vs 36'288 CHF).
  pillar3aDeadline,

  /// User reaches a retirement-relevant milestone age.
  /// Milestone ages: 25, 30, 35, 40, 45, 50, 55, 60, 65.
  birthdayMilestone,

  /// Profile confidence < 40% after 7+ days of account creation.
  /// Encourages data enrichment.
  profileIncomplete,

  /// No app activity recorded in the last 7 days.
  noActivityWeek,

  /// Active goal reached 50% or 100% progress threshold.
  goalProgress,

  /// One year anniversary of a life event recorded in profile.
  lifeEventAnniversary,

  /// Q4 (October–December): prompt LPP buyback window for eligible users.
  lppBuybackWindow,

  /// January 1–15: new year reset — new 3a envelope, new budget cycle.
  newYearReset,
}
