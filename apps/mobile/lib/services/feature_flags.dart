// ────────────────────────────────────────────────────────────
//  Feature Flags — migration toggles + phase rollout
// ────────────────────────────────────────────────────────────

class FeatureFlags {
  // ── Existing (migration) ──────────────────────────────────

  /// Use the new 3-state RetirementDashboardScreen instead of
  /// the monolith CoachDashboardScreen.
  static bool useNewDashboard = true;

  /// Use the new SmartOnboardingScreen instead of the legacy onboarding.
  static bool useNewOnboarding = true;

  /// Enable SLM-generated narratives (Track B, Phase P3).
  /// Requires ComplianceGuard validation.
  static bool enableSlmNarratives = false;

  // ── P2: Housing model ─────────────────────────────────────

  /// Anticipate 2028 reform: valeur locative = 0, but deductions = 0 too.
  /// Off until legislation passes.
  static bool valeurLocative2028Reform = false;

  // ── P4.5: Decision scaffold ───────────────────────────────

  /// Enable the 5 arbitrage modules (DÉCIDER pillar).
  /// Activated progressively per module.
  static bool enableDecisionScaffold = false;

  // ── P6: Billing tiers ─────────────────────────────────────

  /// Enable Couple+ tier in the paywall.
  /// Default: true (hardcoded). P6 will replace with server-driven
  /// value from GET /api/v1/config/feature-flags (endpoint TODO P6).
  /// If false, paywall shows only Free/Starter/Premium.
  static bool enableCouplePlusTier = true;
}
