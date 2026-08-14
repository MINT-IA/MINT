// ────────────────────────────────────────────────────────────
//  Feature Flags — migration toggles + phase rollout
// ────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:mint_mobile/services/preview_shell_policy.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/e2e_runtime_flags.dart';
import 'package:mint_mobile/services/sentry_breadcrumbs.dart';

class FeatureFlags {
  static const _mintNext3aDecisionDeadline = Duration(milliseconds: 700);
  static int _refreshGeneration = 0;

  @visibleForTesting
  static Future<Map<String, dynamic>> Function()? debugBackendFetcher;

  @visibleForTesting
  static Duration? debugBackendRefreshTimeout;

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

  /// Les types de faits dont le jumeau est l'AUTORITE.
  ///
  /// Vide : rien ne change — le registre reste vide, les canonicalisations
  /// retombent sur le coffre, et le comportement est celui d'hier. Un type
  /// present : chaque ecriture d'ecran de ce fait entre au jumeau, et c'est
  /// lui qui repond.
  ///
  /// Un ENSEMBLE plutot qu'un drapeau par fait : la bascule se fait fait par
  /// fait, sans multiplier les interrupteurs a tenir coherents.
  static Set<String> twinOwnedFactTypes = <String>{'logement', 'revenu'};

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

  /// Bring-your-own-key (BYOK): user pastes their own Anthropic / OpenAI /
  /// Mistral API key. Out-of-scope for MVP per `project_byok_scope.md` —
  /// current builds use ServerKey (MINT's Anthropic key on Railway). The
  /// settings entry was visible in v2.x QA builds and confused testers
  /// (« do I need to bring a key? »). v2.14 hides the menu entry until
  /// BYOK lands; the underlying screen + service remain available behind
  /// `/profile/byok` for internal testing.
  static bool enableByok = false;

  /// MVP wedge onboarding — storyboard v2 locked (2026-04-22).
  /// 9-step flow with 4 intents, dossier densification, and 3 N2 scenes
  /// (RenteTrouee / CapaciteAchat / 3aLevier) before magic-link sealing.
  /// When true, the landing CTA routes new users into `/onb` instead of
  /// the legacy coach anonymous flow.
  ///
  /// **Default: `false`** — rolled out via backend `applyFromMap` for staged
  /// enablement (10% → 50% → 100%). Flip locally via GET
  /// `/api/v1/config/feature-flags` returning `{"enableMvpWedgeOnboarding": true}`.
  /// Kill-switch: backend set to false, no app redeploy needed.
  static bool enableMvpWedgeOnboarding = false;

  /// Mint 2 first experience: three-axis T2 under `/onb`.
  ///
  /// Default-off until the Slice 2B/2C first-entry contract has runtime proof.
  /// When false, `/onb` keeps the existing MVP wedge intent cards.
  static bool enableMint2FirstExperienceEntry = false;

  /// Product handoff from the 3a learning flow to one explicit next action.
  ///
  /// This flag is intentionally fail-closed. Every backend refresh resets it
  /// before doing I/O; only the latest successful response containing the
  /// exact boolean `true` may open the gate.
  static final ValueNotifier<bool> _mintNext3aProductHandoff =
      ValueNotifier<bool>(false);

  static bool get enableMintNext3aProductHandoff =>
      _mintNext3aProductHandoff.value;
  static set enableMintNext3aProductHandoff(bool value) =>
      _mintNext3aProductHandoff.value = value;

  static ValueListenable<bool> get mintNext3aProductHandoffListenable =>
      _mintNext3aProductHandoff;

  static final ValueNotifier<bool> _mintNextHousing =
      ValueNotifier<bool>(PreviewShellPolicy.previewDefine);

  static final ValueNotifier<bool> _mintNextDomicile =
      ValueNotifier<bool>(PreviewShellPolicy.previewDefine);

  static bool get enableMintNextDomicile => _mintNextDomicile.value;
  static set enableMintNextDomicile(bool value) =>
      _mintNextDomicile.value = value;

  static ValueListenable<bool> get mintNextDomicileListenable =>
      _mintNextDomicile;

  static final ValueNotifier<bool> _mintNextEtatCivil =
      ValueNotifier<bool>(PreviewShellPolicy.previewDefine);

  static bool get enableMintNextEtatCivil => _mintNextEtatCivil.value;
  static set enableMintNextEtatCivil(bool value) =>
      _mintNextEtatCivil.value = value;

  static ValueListenable<bool> get mintNextEtatCivilListenable =>
      _mintNextEtatCivil;

  static final ValueNotifier<bool> _mintNextRevenu = ValueNotifier<bool>(PreviewShellPolicy.previewDefine);

  static bool get enableMintNextRevenu => _mintNextRevenu.value;
  static set enableMintNextRevenu(bool value) =>
      _mintNextRevenu.value = value;

  static ValueListenable<bool> get mintNextRevenuListenable =>
      _mintNextRevenu;

  static final ValueNotifier<bool> _mintNextLppAffiliation =
      ValueNotifier<bool>(PreviewShellPolicy.previewDefine);

  static bool get enableMintNextLppAffiliation =>
      _mintNextLppAffiliation.value;
  static set enableMintNextLppAffiliation(bool value) =>
      _mintNextLppAffiliation.value = value;

  static ValueListenable<bool> get mintNextLppAffiliationListenable =>
      _mintNextLppAffiliation;

  static final ValueNotifier<bool> _mintNextVersements3a =
      ValueNotifier<bool>(PreviewShellPolicy.previewDefine);

  static bool get enableMintNextVersements3a => _mintNextVersements3a.value;
  static set enableMintNextVersements3a(bool value) =>
      _mintNextVersements3a.value = value;

  static ValueListenable<bool> get mintNextVersements3aListenable =>
      _mintNextVersements3a;

  static final ValueNotifier<bool> _mintNextMarge3a = ValueNotifier<bool>(PreviewShellPolicy.previewDefine);

  static bool get enableMintNextMarge3a => _mintNextMarge3a.value;
  static set enableMintNextMarge3a(bool value) =>
      _mintNextMarge3a.value = value;

  static ValueListenable<bool> get mintNextMarge3aListenable =>
      _mintNextMarge3a;

  static final ValueNotifier<bool> _mintNextVertical3a =
      ValueNotifier<bool>(false);

  static bool get enableMintNextVertical3a => _mintNextVertical3a.value;
  static set enableMintNextVertical3a(bool value) =>
      _mintNextVertical3a.value = value;

  static ValueListenable<bool> get mintNextVertical3aListenable =>
      _mintNextVertical3a;

  static bool get enableMintNextHousing => _mintNextHousing.value;
  static set enableMintNextHousing(bool value) =>
      _mintNextHousing.value = value;

  static ValueListenable<bool> get mintNextHousingListenable =>
      _mintNextHousing;

  /// Sub-phase 01.5 archetype HARD GATE kill switch (Codex R5 release-blocker).
  ///
  /// **Default: `true`** — gate is active. Non-supported archetypes
  /// (expat_us via FATCA self-declaration, expat_eu, cross_border,
  /// independent_no_lpp, etc.) are routed to `/waitlist` at the coach
  /// entry (coach_chat_screen.dart `_buildCoachContext` primary site,
  /// Mapper §7.2) AND refused at the orchestrator layer
  /// (coach_orchestrator.dart `_calibratedArchetypes` defense-in-depth,
  /// Mapper §7.4).
  ///
  /// Set to `false` server-side via GET `/api/v1/config/feature-flags`
  /// ONLY in emergency rollback scenarios (e.g. mass false-positive
  /// routing of swiss_native users to /waitlist due to a detection
  /// bug). Flipping to false re-opens the FATCA / LSFin compliance
  /// window documented in 01.5-SECURITY-fatca-scope.md — use with
  /// caution. The true → false transition emits a Sentry warning so
  /// on-call can detect rollback activations (T-01.5-42 mitigation).
  ///
  /// Shipping with default=false would defeat the entire phase per
  /// plan 02-04 objective; the test
  /// `feature_flags_coach_hard_gate_test.dart::default is true` pins
  /// this invariant.
  static bool enableCoachHardGate = true;

  /// Test-only observable hook for the `enableCoachHardGate` true → false
  /// transition. When set, it replaces the production Sentry warning
  /// path (`Sentry.captureMessage`) so widget / unit tests can assert
  /// the rollback was logged without mocking sentry_flutter.
  ///
  /// Production code path is unchanged (hook null → Sentry call as
  /// designed). The hook is only set by tests in
  /// `feature_flags_coach_hard_gate_test.dart`.
  @visibleForTesting
  static void Function(String message)? debugCoachHardGateWarningHook;

  /// Phase 96 D-01 — chat tab visibility in MintShell.NavigationBar.
  ///
  /// Per 96-CONTEXT.md D-21: Phase 96 ships the kill-switch via feature flag;
  /// permanent route removal after a 4-week soak with zero rollback signal.
  /// Default `true` (no behavior change in user nav) until staging
  /// baseline-pull per D-11 authorises the flip. When set to `false` (via
  /// `/config/feature-flags` server override), MintShell.NavigationBar drops
  /// index 2 (`tabCoach`), leaving a 3-tab nav (Aujourd'hui / Mon Argent /
  /// Explorer). The GoRouter branch + CoachChatScreen route STAY registered
  /// (D-02) so MintChatOverlay can route to it.
  ///
  /// Server-overridable via the existing `/config/feature-flags` endpoint
  /// (applyFromMap below).
  static bool chatTabVisible = true;

  // Phase 32 D-10 — local-only gate for /admin/*.
  // Combined with compile-time ENABLE_ADMIN=1 via AdminGate.
  // NO backend call (D-10 v4 kills proposed /api/v1/admin/me).
  //
  // Phase 32: equals compile-time flag (hardcoded true when ENABLE_ADMIN=1).
  // Phase 33 may refactor FeatureFlags to ChangeNotifier — `isAdmin`
  // would then become an instance-level getter.
  static const String _adminCompileTimeValue = String.fromEnvironment(
    'ENABLE_ADMIN',
    defaultValue: 'false',
  );
  static bool get isAdmin =>
      _adminCompileTimeValue == 'true' || _adminCompileTimeValue == '1';

  /// Local simulator proof overrides. Release builds ignore these through
  /// [E2eRuntimeFlags].
  static void applyRuntimeOverrides() {
    if (E2eRuntimeFlags.mint2FirstExperienceEntry) {
      enableMint2FirstExperienceEntry = true;
    }
    if (E2eRuntimeFlags.mintNext3aHarness) {
      final remoteDecision = E2eRuntimeFlags.mintNext3aRemoteFlag;
      if (remoteDecision != null) {
        enableMintNext3aProductHandoff = remoteDecision;
      }
    }
    if (E2eRuntimeFlags.mintNextHousing) {
      enableMintNextHousing = true;
    }
    if (E2eRuntimeFlags.mintNextDomicile) {
      enableMintNextDomicile = true;
    }
    if (E2eRuntimeFlags.mintNextEtatCivil) {
      enableMintNextEtatCivil = true;
    }
    if (E2eRuntimeFlags.mintNextRevenu) {
      enableMintNextRevenu = true;
    }
    if (E2eRuntimeFlags.mintNextLppAffiliation) {
      enableMintNextLppAffiliation = true;
    }
    if (E2eRuntimeFlags.mintNextVersements3a) {
      enableMintNextVersements3a = true;
    }
    if (E2eRuntimeFlags.mintNextMarge3a) {
      enableMintNextMarge3a = true;
    }
    if (E2eRuntimeFlags.mintNextVertical3a) {
      enableMintNextVertical3a = true;
    }
  }

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
    if (data.containsKey('enableMvpWedgeOnboarding')) {
      enableMvpWedgeOnboarding = data['enableMvpWedgeOnboarding'] == true;
    }
    if (data.containsKey('enableMint2FirstExperienceEntry')) {
      enableMint2FirstExperienceEntry =
          data['enableMint2FirstExperienceEntry'] == true ||
              E2eRuntimeFlags.mint2FirstExperienceEntry;
    }
    if (data.containsKey('enableMintNext3aProductHandoff')) {
      enableMintNext3aProductHandoff =
          data['enableMintNext3aProductHandoff'] == true;
    }
    if (data.containsKey('enableMintNextHousing')) {
      enableMintNextHousing = data['enableMintNextHousing'] == true;
    }
    if (data.containsKey('enableMintNextDomicile')) {
      enableMintNextDomicile = data['enableMintNextDomicile'] == true;
    }
    if (data.containsKey('enableMintNextEtatCivil')) {
      enableMintNextEtatCivil = data['enableMintNextEtatCivil'] == true;
    }
    if (data.containsKey('enableMintNextRevenu')) {
      enableMintNextRevenu = data['enableMintNextRevenu'] == true;
    }
    if (data.containsKey('enableMintNextLppAffiliation')) {
      enableMintNextLppAffiliation =
          data['enableMintNextLppAffiliation'] == true;
    }
    if (data.containsKey('enableMintNextVersements3a')) {
      enableMintNextVersements3a =
          data['enableMintNextVersements3a'] == true;
    }
    if (data.containsKey('enableMintNextMarge3a')) {
      enableMintNextMarge3a = data['enableMintNextMarge3a'] == true;
    }
    if (data.containsKey('enableMintNextVertical3a')) {
      enableMintNextVertical3a = data['enableMintNextVertical3a'] == true;
    }
    // Phase 96 D-01 — chat tab visibility server override.
    if (data.containsKey('chatTabVisible')) {
      chatTabVisible = data['chatTabVisible'] == true;
    }
    // Sub-phase 01.5 W02-T04 R5 — archetype HARD GATE kill switch.
    // Emit a Sentry warning on the true → false transition so on-call
    // can detect when the FATCA / LSFin gate is bypassed via server
    // override (T-01.5-42 — repudiation mitigation).
    if (data.containsKey('enableCoachHardGate')) {
      final newValue = data['enableCoachHardGate'] == true;
      if (enableCoachHardGate == true && newValue == false) {
        const warning =
            'enableCoachHardGate disabled via server feature-flags override — '
            'FATCA / LSFin archetype gate is OFF';
        final hook = debugCoachHardGateWarningHook;
        if (hook != null) {
          hook(warning);
        } else {
          Sentry.captureMessage(warning, level: SentryLevel.warning);
        }
      }
      enableCoachHardGate = newValue;
    }
  }

  // ── Server-driven refresh ─────────────────────────────────

  /// Refresh server-driven flags from backend.
  /// Called at app launch + every 6 hours.
  static Future<void> refreshFromBackend() async {
    final generation = ++_refreshGeneration;
    enableMintNext3aProductHandoff = false;
    enableMintNextHousing = false;
    enableMintNextDomicile = false;
    enableMintNextEtatCivil = false;
    enableMintNextRevenu = false;
    enableMintNextLppAffiliation = false;
    enableMintNextVersements3a = false;
    enableMintNextMarge3a = false;
    enableMintNextVertical3a = false;
    final decisionClock = Stopwatch()..start();
    try {
      // Debug seams are ignored by compiled release builds. Production always
      // uses ApiService and its established 30-second transport timeout.
      final fetcher = kReleaseMode ? null : debugBackendFetcher;
      final request =
          fetcher == null ? ApiService.get('/config/feature-flags') : fetcher();
      final data = await request;
      if (generation != _refreshGeneration) return;
      final decisionDeadline =
          !kReleaseMode && debugBackendRefreshTimeout != null
              ? debugBackendRefreshTimeout!
              : _mintNext3aDecisionDeadline;
      final handoffMayOpen = decisionClock.elapsed <= decisionDeadline &&
          data['enableMintNext3aProductHandoff'] == true;
      // Do not discard the shared config response: the deadline is scoped
      // only to this new product gate. A late response may refresh legacy
      // flags but must never transiently notify an open Mint Next handoff.
      final sharedFlags = Map<String, dynamic>.of(data)
        ..remove('enableMintNext3aProductHandoff');
      applyFromMap(sharedFlags);
      enableMintNext3aProductHandoff = handoffMayOpen;
      // OBS-05 — feature_flags breadcrumb on success (D-03 4-level).
      MintBreadcrumbs.featureFlagsRefresh(
        success: true,
        flagCount: data.length,
      );
    } on TimeoutException {
      if (generation == _refreshGeneration) {
        enableMintNext3aProductHandoff = false;
        enableMintNextHousing = false;
        enableMintNextDomicile = false;
        enableMintNextEtatCivil = false;
        enableMintNextRevenu = false;
        enableMintNextLppAffiliation = false;
        enableMintNextVersements3a = false;
      }
      MintBreadcrumbs.featureFlagsRefresh(
        success: false,
        errorCode: 'network_timeout',
      );
    } catch (e) {
      if (generation == _refreshGeneration) {
        enableMintNext3aProductHandoff = false;
        enableMintNextHousing = false;
        enableMintNextDomicile = false;
        enableMintNextEtatCivil = false;
        enableMintNextRevenu = false;
        enableMintNextLppAffiliation = false;
        enableMintNextVersements3a = false;
      }
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
    applyRuntimeOverrides();
  }
}
