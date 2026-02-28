// ────────────────────────────────────────────────────────────
//  Feature Flags — migration toggles
// ────────────────────────────────────────────────────────────

class FeatureFlags {
  /// Use the new 3-state RetirementDashboardScreen instead of
  /// the monolith CoachDashboardScreen.
  static bool useNewDashboard = true;

  /// Use the new SmartOnboardingScreen instead of the legacy onboarding.
  static bool useNewOnboarding = true;

  /// Enable SLM-generated narratives (Track B, Phase P3).
  /// Requires ComplianceGuard validation.
  static bool enableSlmNarratives = false;
}
