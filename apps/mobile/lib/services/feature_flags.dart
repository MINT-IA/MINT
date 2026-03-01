// ────────────────────────────────────────────────────────────
//  Feature Flags — migration toggles + phase rollout
// ────────────────────────────────────────────────────────────

import 'package:mint_mobile/services/api_service.dart';

class FeatureFlags {
  // ── Existing (migration) ──────────────────────────────────

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

  /// Enable the 5 arbitrage modules (DECIDER pillar).
  /// Activated progressively per module.
  static bool enableDecisionScaffold = false;

  // ── P6: Billing tiers ─────────────────────────────────────

  /// Enable Couple+ tier in the paywall.
  /// Default: true. Server-driven value from GET /api/v1/config/feature-flags.
  /// If false, paywall shows only Free/Starter/Premium.
  static bool enableCouplePlusTier = true;

  // ── Server-driven refresh ─────────────────────────────────

  /// Refresh server-driven flags from backend.
  /// Called at app launch + every 6 hours.
  static Future<void> refreshFromBackend() async {
    try {
      final data = await ApiService.get('/config/feature-flags');
      if (data.containsKey('enableCouplePlusTier')) {
        enableCouplePlusTier = data['enableCouplePlusTier'] == true;
      }
      if (data.containsKey('enableSlmNarratives')) {
        enableSlmNarratives = data['enableSlmNarratives'] == true;
      }
      if (data.containsKey('enableDecisionScaffold')) {
        enableDecisionScaffold = data['enableDecisionScaffold'] == true;
      }
      if (data.containsKey('valeurLocative2028Reform')) {
        valeurLocative2028Reform = data['valeurLocative2028Reform'] == true;
      }
    } catch (_) {
      // Keep current values on failure — safe fallback
    }
  }
}
