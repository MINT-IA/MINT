import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/pillar_3a_calculator.dart';
import 'package:mint_mobile/services/slm/slm_download_service.dart';
import 'package:mint_mobile/services/slm/slm_engine.dart';
import 'package:mint_mobile/services/tax_scales_loader.dart';
import 'package:mint_mobile/data/commune_data.dart';

/// Point d'entrée de l'application MINT
///
/// Démarre l'app immédiatement (Progressive Disclosure)
/// et charge les services en arrière-plan
Future<void> main() async {
  // Initialisation Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Select a reachable API endpoint (defined URL first, then fallbacks).
  await ApiService.ensureReachableBaseUrl();

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
    FeatureFlags.refreshFromBackend().catchError((e) {
      if (kDebugMode) debugPrint('Err Flags: $e');
    }),
  ]);

  // Periodic refresh of server-driven feature flags (every 6 hours).
  // Timer stored on FeatureFlags so WidgetsBindingObserver can cancel on detach.
  FeatureFlags.periodicRefreshTimer = Timer.periodic(
    const Duration(hours: 6),
    (_) => FeatureFlags.refreshFromBackend(),
  );

  // Lancement immédiat de l'app (UX first!)
  runApp(const MintApp());
}
