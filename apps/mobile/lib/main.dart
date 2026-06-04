import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/coach/coach_orchestrator.dart';
import 'package:mint_mobile/services/coach/e2e_coach_route_fixture.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/error_boundary.dart';
import 'package:mint_mobile/services/frame_timing_capture.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/observability/sentry_scrub.dart';
import 'package:mint_mobile/services/pillar_3a_calculator.dart';
import 'package:mint_mobile/services/slm/slm_download_service.dart';
import 'package:mint_mobile/services/slm/slm_engine.dart';
import 'package:mint_mobile/services/tax_scales_loader.dart';
import 'package:mint_mobile/data/commune_data.dart';
import 'package:mint_mobile/services/regulatory_sync_service.dart';
import 'package:mint_mobile/services/snapshot_service.dart';

/// Point d'entrée de l'application MINT
///
/// Démarre l'app immédiatement (Progressive Disclosure)
/// et charge les services en arrière-plan
Future<void> main() async {
  // Initialisation Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Phase 02 D-MOB side-finding fix — replace hardcoded ApiService._appVersion='1.0.0'
  // with real pubspec.yaml version (X-App-Version header + mobile L1 audit trail).
  await ApiService.initAppVersion();

  // STAMP-03 (Phase 89 v2.12) — register frame timing capture for jank
  // measurement when the dart-define MINT_FRAME_TIMING_CAPTURE=true is
  // set (debug/profile only ; release short-circuits). No-op in normal
  // builds. Walker greps `[MINT_FRAME_TIMING]` log lines to aggregate
  // the % > 16ms metric.
  MintFrameTimingCapture.register();

  // OBS-02 (Phase 31-01) — install the 3-prong global error boundary
  // BEFORE SentryFlutter.init so PlatformDispatcher.onError + FlutterError
  // .onError + Isolate.addErrorListener are already live when the SDK
  // attaches. Single allowed source of Sentry.captureException — enforced
  // by tools/checks/sentry_capture_single_source.py.
  installGlobalErrorBoundary();

  // Lock portrait orientation globally (landscape only in fullscreen chart overlay)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Select a reachable API endpoint (defined URL first, then fallbacks).
  await ApiService.ensureReachableBaseUrl();

  // STARTUP CONTRACT:
  // 1. loadFromDisk() is BLOCKING — loads last-session cache from SharedPreferences
  //    so reg() has data before any calculator runs.
  // 2. fetchConstants() is FIRE-AND-FORGET — updates cache from backend API.
  //    If it completes before a calculator runs, reg() returns fresh data.
  //    If not, reg() returns last-session data (or hardcoded fallback on first install).
  await RegulatorySyncService.loadFromDisk();

  // STAMP-02 (Phase 89 v2.12) — SLM plugin init was previously awaited
  // (up to 5s I/O for model file check) and contributed materially to
  // cold-launch P50. Now fire-and-forget : kick off in background, set
  // the flag when ready, then chain SlmEngine pre-load. The first chat
  // message may briefly fall back to ServerKey/cloud routing if SLM
  // hasn't finished init by then ; subsequent messages use SLM.
  // FeatureFlags.slmPluginReady defaults to false ; the cloud-first
  // fallback path is operational without SLM (no functional regression).
  unawaited(
    SlmDownloadService.instance
        .initializePlugin()
        .timeout(const Duration(seconds: 5))
        .then((ready) {
          FeatureFlags.slmPluginReady = ready;
          if (ready) {
            // Pre-load SLM engine into RAM (still chained async).
            SlmEngine.instance.initialize().then((ok) {
              if (kDebugMode) debugPrint('SLM engine pre-init: $ok');
            }).catchError((e) {
              if (kDebugMode) debugPrint('SLM engine pre-init err: $e');
            });
          }
        })
        .catchError((e) {
          FeatureFlags.slmPluginReady = false;
          if (kDebugMode) debugPrint('Err SLM plugin: $e');
        }),
  );

  // Pull server feature flags before first frame so kill-switches
  // apply immediately (especially narrative degradation flags).
  // STAMP-02 (Phase 89 v2.12) — timeout reduced from 2s to 800ms to
  // keep cold-launch P50 under the 2.5s gate. If backend is slow,
  // the app falls back to local defaults — same behaviour as the
  // 2s-timeout path.
  try {
    await FeatureFlags.refreshFromBackend().timeout(
      const Duration(milliseconds: 800),
    );
  } catch (_) {
    // Keep local defaults when backend is unavailable.
  }

  // Chargement des données critiques en arrière-plan (non-bloquant)
  Future.wait([
    Pillar3aCalculator.loadLimits().catchError((e) {
      if (kDebugMode) debugPrint('Err 3a: $e');
    }),
    TaxScalesLoader.load().catchError((e) {
      if (kDebugMode) debugPrint('Err Tax: $e');
    }),
    CommuneData.load().catchError((e) {
      if (kDebugMode) debugPrint('Err Communes: $e');
    }),
    // FIX-164: Removed redundant FeatureFlags.refreshFromBackend()
    // Already awaited at L58 with 2s timeout. Double call was overwriting results.
    RegulatorySyncService.fetchConstants().catchError((e) {
      if (kDebugMode) debugPrint('Err Regulatory: $e');
      return <String, double>{};
    }),
    // W15: Load snapshots from backend (fire-and-forget, non-blocking)
    SnapshotService.loadFromBackend().catchError((e) {
      if (kDebugMode) debugPrint('Err Snapshots: $e');
    }),
  ]);

  // Periodic refresh of server-driven feature flags (every 6 hours).
  // Cancelled/restarted by WidgetsBindingObserver in app.dart on lifecycle changes.
  FeatureFlags.startPeriodicRefresh();

  // FIX-P1-7: Register orchestrator chat function to break circular dependency
  // (coach_llm_service ↔ coach_orchestrator). Must happen before first chat.
  CoachLlmService.registerOrchestrator(
    E2eCoachRouteFixture.orchestratorOrNull() ?? CoachOrchestrator.generateChat,
  );

  // Sentry error tracking — DSN injected via dart-define in CI/production
  // flutter run --dart-define=SENTRY_DSN=https://xxx@sentry.io/xxx
  // CTX-05 spike (Phase 30.6-02) — sentry_flutter 9.14.0 + Session Replay
  // with nLPD-safe masks (A1 PITFALLS.md: maskAllText + maskAllImages
  // NON-NEGOCIABLE — any user PII visible on screen would leak otherwise).
  const sentryDsn = String.fromEnvironment('SENTRY_DSN');
  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 0.1;
        options.sendDefaultPii = false; // nLPD compliance
        // S98 Phase 2 — second-line PII scrubber (Swiss-compliance panel
        // non-negotiable). Strips AVS, IBAN_CH, email, phone +41 + drops
        // Claude payload keys (prompt/completion/messages/response/coach_*).
        // Contract tests : test/services/observability/sentry_scrub_test.dart.
        options.beforeSend = MintSentryScrub.beforeSend;
        // D-02 Option A (CONTEXT.md) — single Sentry project with env tag.
        // MINT_ENV dart-define drives the 3-way split (development /
        // staging / production). Staging CI/TestFlight builds MUST pass
        // --dart-define=MINT_ENV=staging to be tagged correctly; absence
        // defaults to 'production' (see MINT_ENV_DART_DEFINE contract in
        // .planning/phases/31-instrumenter/31-01-SUMMARY.md).
        options.environment = kDebugMode
            ? 'development'
            : const String.fromEnvironment(
                'MINT_ENV',
                defaultValue: 'production',
              );
        // Session Replay (sentry_flutter 9.x) — D-01 Option C (CONTEXT.md).
        // Error-only in prod (0.0 session + 1.0 onError) keeps crash signal
        // while cutting Replay quota risk (Pitfall A2). Staging gets 10%
        // sessions for debugging; dev is full (1.0) so local runs always
        // capture. Prod flip to >0 is gated by OBS-06 PII audit sign-off.
        if (kDebugMode) {
          options.replay.sessionSampleRate = 1.0;
        } else if (options.environment == 'staging') {
          options.replay.sessionSampleRate = 0.10;
        } else {
          options.replay.sessionSampleRate = 0.0;
        }
        options.replay.onErrorSampleRate = 1.0;
        // Privacy — masks MUST stay true (nLPD, A1 PITFALLS.md).
        // Defaults are already true in sentry_flutter 9.14.0, but we pin
        // them explicitly for audit/grep verification on any future edit.
        options.privacy.maskAllText = true;
        options.privacy.maskAllImages = true;
        // Trace propagation allowlist — narrow from default `.*` to MINT
        // backends only (avoids leaking sentry-trace headers to third-parties).
        options.tracePropagationTargets
          ..clear()
          ..addAll([
            'api.mint.app',
            'mint-staging.up.railway.app',
            'mint-production.up.railway.app',
          ]);
      },
      appRunner: () => runApp(SentryWidget(child: const MintApp())),
    );
  } else {
    runApp(const MintApp());
  }
}
