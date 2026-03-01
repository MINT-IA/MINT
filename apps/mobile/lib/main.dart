import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/pillar_3a_calculator.dart';
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

  // Chargement des données critiques en arrière-plan (non-bloquant)
  Future.wait([
    Pillar3aCalculator.loadLimits()
        .catchError((e) { if (kDebugMode) debugPrint('Err 3a: $e'); }),
    TaxScalesLoader.load().catchError((e) { if (kDebugMode) debugPrint('Err Tax: $e'); }),
    CommuneData.load().catchError((e) { if (kDebugMode) debugPrint('Err Communes: $e'); }),
    FeatureFlags.refreshFromBackend()
        .catchError((e) { if (kDebugMode) debugPrint('Err Flags: $e'); }),
  ]);

  // Periodic refresh of server-driven feature flags (every 6 hours)
  Timer.periodic(const Duration(hours: 6), (_) {
    FeatureFlags.refreshFromBackend();
  });

  // Lancement immédiat de l'app (UX first!)
  runApp(const MintApp());
}
