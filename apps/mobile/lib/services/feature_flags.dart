// ────────────────────────────────────────────────────────────
//  Feature Flags — migration toggles + phase rollout
// ────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:mint_mobile/services/api_service.dart';

class FeatureFlags {
  /// Timer for periodic backend refresh (set in main, cancellable).
  static Timer? periodicRefreshTimer;

  /// Start the periodic refresh timer. Idempotent — cancels existing timer first.
  static void startPeriodicRefresh() {
    periodicRefreshTimer?.cancel();
    periodicRefreshTimer = Timer.periodic(
      const Duration(hours: 6),
      (_) => refreshFromBackend(),
    );
  }

  /// Cancel the periodic refresh timer (call on app pause/detach).
  static void stopPeriodicRefresh() {
    periodicRefreshTimer?.cancel();
    periodicRefreshTimer = null;
  }

  // ── Existing (migration) ──────────────────────────────────

  /// Enable SLM-generated narratives (Track B, Phase P3).
  /// Requires ComplianceGuard validation.
  static bool enableSlmNarratives = true;

  // ── P2: Housing model ─────────────────────────────────────

  /// Anticipate 2028 reform: valeur locative = 0, but deductions = 0 too.
  /// Off until legislation passes.
  static bool valeurLocative2028Reform = false;

  // ── P4.5: Decision scaffold ───────────────────────────────

  /// Enable the 5 arbitrage modules (DECIDER pillar).
  /// Activated progressively per module.
  static bool enableDecisionScaffold = true;

  // ── P6: Billing tiers ─────────────────────────────────────

  /// Enable Couple+ tier in the paywall.
  /// Default: true. Server-driven value from GET /api/v1/config/feature-flags.
  /// If false, paywall shows only Free/Starter/Premium.
  static bool enableCouplePlusTier = true;

  // ── SLM runtime state ─────────────────────────────────────

  /// Set once at startup after FlutterGemma.initialize().
  /// Guards SLM narrative attempts — if false, skip SLM entirely.
  static bool slmPluginReady = false;

  // ── P7: SafeMode degraded fallback ────────────────────────

  /// When true, narratives use templates-only degraded mode.
  static bool safeModeDegraded = false;

  // ── V1 screen gating ───────────────────────────────────────
  // All enabled for V1 launch (S49). Server-driven override available.

  /// Coach Phase 2: refresh, succession, decaissement
  static bool enableCoachPhase2 = true;

  /// Life event screens: mariage, divorce, naissance, concubinage, etc.
  static bool enableLifeEventScreens = true;

  /// Advanced simulators: compound, leasing, credit
  static bool enableAdvancedSimulators = true;

  /// Mortgage tools: affordability, amortization, EPL, etc.
  static bool enableMortgageTools = true;

  /// Self-employed tools: AVS cotisations, IJM, 3a indep, etc.
  static bool enableIndependantTools = true;

  /// Open banking screens: hub, transactions, consents
  static bool enableOpenBanking = false;

  /// Admin screens: observability, analytics
  static bool enableAdminScreens = false;

  /// Apply flags from a backend response map.
  static void applyFromMap(Map<String, dynamic> data) {
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
    if (data.containsKey('safeModeDegraded')) {
      safeModeDegraded = data['safeModeDegraded'] == true;
    }
    // V1 screen gating flags
    if (data.containsKey('enableCoachPhase2')) {
      enableCoachPhase2 = data['enableCoachPhase2'] == true;
    }
    if (data.containsKey('enableLifeEventScreens')) {
      enableLifeEventScreens = data['enableLifeEventScreens'] == true;
    }
    if (data.containsKey('enableAdvancedSimulators')) {
      enableAdvancedSimulators = data['enableAdvancedSimulators'] == true;
    }
    if (data.containsKey('enableMortgageTools')) {
      enableMortgageTools = data['enableMortgageTools'] == true;
    }
    if (data.containsKey('enableIndependantTools')) {
      enableIndependantTools = data['enableIndependantTools'] == true;
    }
    if (data.containsKey('enableOpenBanking')) {
      enableOpenBanking = data['enableOpenBanking'] == true;
    }
    if (data.containsKey('enableAdminScreens')) {
      enableAdminScreens = data['enableAdminScreens'] == true;
    }
  }

  // ── Server-driven refresh ─────────────────────────────────

  /// Refresh server-driven flags from backend.
  /// Called at app launch + every 6 hours.
  static Future<void> refreshFromBackend() async {
    try {
      final data = await ApiService.get('/config/feature-flags');
      applyFromMap(data);
    } catch (_) {
      // Keep current values on failure — safe fallback
    }
  }
}
