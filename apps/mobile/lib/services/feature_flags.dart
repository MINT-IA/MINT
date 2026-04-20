// ────────────────────────────────────────────────────────────
//  Feature Flags — migration toggles + phase rollout
// ────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/sentry_breadcrumbs.dart';

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
  // F7: enableCoachPhase2, enableLifeEventScreens, enableAdvancedSimulators,
  //     enableMortgageTools, enableIndependantTools REMOVED — always true
  //     since V1 launch (S49), no consumers in codebase.

  /// Open banking screens: hub, transactions, consents
  static bool enableOpenBanking = false;

  /// Pension Fund Connect (institutional API pilot)
  static bool enablePensionFundConnect = false;

  /// Expert Tier (human specialist marketplace)
  static bool enableExpertTier = false;

  /// Admin screens: observability, analytics
  static bool enableAdminScreens = false;

  // Phase 32 D-10 — local-only gate for /admin/*.
  // Combined with compile-time ENABLE_ADMIN=1 via AdminGate.
  // NO backend call (D-10 v4 kills proposed /api/v1/admin/me).
  //
  // Phase 32: equals compile-time flag (hardcoded true when ENABLE_ADMIN=1).
  // Phase 33 may refactor FeatureFlags to ChangeNotifier — `isAdmin`
  // would then become an instance-level getter.
  static bool get isAdmin =>
      const bool.fromEnvironment('ENABLE_ADMIN', defaultValue: false);

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
    // V1 screen gating flags — F7: 5 dead flags removed (always true, no consumers)
    if (data.containsKey('enableOpenBanking')) {
      enableOpenBanking = data['enableOpenBanking'] == true;
    }
    if (data.containsKey('enablePensionFundConnect')) {
      enablePensionFundConnect = data['enablePensionFundConnect'] == true;
    }
    if (data.containsKey('enableExpertTier')) {
      enableExpertTier = data['enableExpertTier'] == true;
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
      // OBS-05 — feature_flags breadcrumb on success (D-03 4-level).
      MintBreadcrumbs.featureFlagsRefresh(
        success: true,
        flagCount: data.length,
      );
    } on TimeoutException {
      // Keep current values on failure — safe fallback
      MintBreadcrumbs.featureFlagsRefresh(
        success: false,
        errorCode: 'network_timeout',
      );
    } catch (e) {
      // Keep current values on failure — safe fallback
      // OBS-05 — feature_flags breadcrumb on failure branch (D-03 4-level
      // literal `failure`, NOT `error`). Error code enum only — no raw
      // exception message (may contain PII / stack detail).
      final code = e is FormatException
          ? 'parse_error'
          : (e is ApiException && e.isOffline ? 'offline' : 'unknown');
      MintBreadcrumbs.featureFlagsRefresh(
        success: false,
        errorCode: code,
      );
    }
  }
}
