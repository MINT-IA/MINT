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

  /// Local kill switch for the unfinished guided-sequence runtime.
  ///
  /// This must not be hydrated from backend flags: G1 keeps the dormant path
  /// fail-closed until it has a complete product and runtime proof.
  static bool enableGuidedSequences = false;

  /// Local-only kill switch for the bounded G1 EPL/rente-capital cache.
  ///
  /// It stays outside [applyFromMap]. Turning it off makes the production
  /// provider purge the encrypted cache before publishing no scenario state.
  static bool scenarioSessionCacheEnabled = const bool.fromEnvironment(
    'MINT_TEST_G1_SCENARIO_SESSIONS',
    defaultValue: false,
  );

  /// Local kill switch for the Flutter-owned first financial-plan setup.
  ///
  /// `MINT_TEST_FINANCIAL_PLAN_SETUP` is a TEST-ONLY compile-time opt-in used
  /// by the exact-archive production-entrypoint runtime review. Its default is
  /// fail-closed, and this flag stays outside [applyFromMap] so the backend
  /// cannot activate the unfinished G1 path.
  static bool financialPlanSetupEnabled = const bool.fromEnvironment(
    'MINT_TEST_FINANCIAL_PLAN_SETUP',
    defaultValue: false,
  );

  /// Local-only G1 succession evidence collector; never backend-hydrated.
  static bool successionEvidenceCollectionEnabled = const bool.fromEnvironment(
    'MINT_TEST_SUCCESSION_EVIDENCE_COLLECTION',
    defaultValue: false,
  );

  /// Local-only gate for the illustrative 13th AVS scenario cash-flow.
  ///
  /// It must remain absent from [applyFromMap]: backend flags cannot turn
  /// an educational scenario into evidence of an AVS fund entitlement.
  static bool enableAvsThirteenthScenarioCashflow = false;

  /// Local kill switch for the typed tax snapshot ledger.
  /// Backend configuration must not activate this path before its gates pass.
  static bool typedTaxProfile = false;

  /// Local kill switch for the person-owned typed LPP evidence root.
  /// Backend configuration cannot activate this path.
  static bool typedLppEvidence = false;

  /// Local kill switch for the reviewed LPP capital-notice deadline.
  ///
  /// It remains outside [applyFromMap] so technical readiness cannot expose
  /// the unfinished acquisition or consumer path.
  static bool lppCapitalNoticeDeadlineEnabled = false;

  /// Local kill switch for the reviewed LPP regulation reference.
  /// Backend configuration cannot activate this path.
  static bool lppRegulationReferenceEnabled = false;

  /// Local kill switch for the contract-scoped 3a beneficiary reference.
  /// Backend configuration cannot activate this path.
  static bool pillar3aBeneficiaryClauseReferenceEnabled = false;

  /// Local kill switch for every LPP-document acquisition surface.
  /// Backend configuration cannot activate this path.
  static bool documentLppEvidenceEnabled = false;

  /// Local kill switch for the represented-authorization accountability path.
  /// It deliberately stays outside [applyFromMap]: technical GREEN cannot
  /// activate the partner journey while the external legal/privacy facts are
  /// unresolved.
  static bool partnerLppAccountabilityEnabled = false;

  static bool get lppEvidenceIngestionEnabled =>
      typedLppEvidence && documentLppEvidenceEnabled;

  /// Local-only composite gate for reviewed pension-regulation acquisition.
  /// It stays absent from [applyFromMap] until the G1 runtime gates are closed.
  static bool get lppRegulationAcquisitionEnabled =>
      typedLppEvidence &&
      documentLppEvidenceEnabled &&
      lppRegulationReferenceEnabled;

  /// Local-only composite gate for the optional capital-notice acquisition.
  ///
  /// It stays absent from [applyFromMap]. Regulation acquisition remains
  /// independently available when this stricter four-flag composite is off.
  static bool get lppCapitalNoticeAcquisitionEnabled =>
      typedLppEvidence &&
      documentLppEvidenceEnabled &&
      lppRegulationReferenceEnabled &&
      lppCapitalNoticeDeadlineEnabled;

  /// Local kill switch for every tax-document acquisition surface.
  ///
  /// This flag deliberately stays out of [applyFromMap]. The UI is exposed
  /// only when the typed ledger is enabled too, so the product cannot present
  /// a tax review flow whose canonical writer is still disabled.
  static bool documentTaxAssessmentEnabled = false;

  static bool get taxAssessmentIngestionEnabled =>
      documentTaxAssessmentEnabled && typedTaxProfile;

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
