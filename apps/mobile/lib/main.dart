import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/coach/coach_orchestrator.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
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

  // Initialize SLM plugin runtime once at startup (5s — model check is I/O).
  try {
    final ready = await SlmDownloadService.instance
        .initializePlugin()
        .timeout(const Duration(seconds: 5));
    FeatureFlags.slmPluginReady = ready;
  } catch (e) {
    FeatureFlags.slmPluginReady = false;
    if (kDebugMode) debugPrint('Err SLM plugin: $e');
  }

  // Pre-load SLM engine into RAM (async, non-blocking).
  // This way the first chat message doesn't wait for model loading.
  if (FeatureFlags.slmPluginReady) {
    SlmEngine.instance.initialize().then((ok) {
      if (kDebugMode) debugPrint('SLM engine pre-init: $ok');
    }).catchError((e) {
      if (kDebugMode) debugPrint('SLM engine pre-init err: $e');
    });
  }

  // Pull server feature flags before first frame so kill-switches
  // apply immediately (especially narrative degradation flags).
  try {
    await FeatureFlags.refreshFromBackend().timeout(
      const Duration(seconds: 2),
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
  CoachLlmService.registerOrchestrator(CoachOrchestrator.generateChat);

  // Sentry error tracking — DSN injected via dart-define in CI/production
  // flutter run --dart-define=SENTRY_DSN=https://xxx@sentry.io/xxx
  const sentryDsn = String.fromEnvironment('SENTRY_DSN');
  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 0.1;
        options.sendDefaultPii = false; // nLPD compliance
        options.environment = kDebugMode ? 'development' : 'production';
      },
      appRunner: () => runApp(const MintApp()),
    );
  } else {
    runApp(const MintApp());
  }
}
