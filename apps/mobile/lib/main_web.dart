import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/pillar_3a_calculator.dart';
import 'package:mint_mobile/services/tax_scales_loader.dart';
import 'package:mint_mobile/data/commune_data.dart';

/// Web entry point — no SLM (on-device model not available on web).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ApiService.ensureReachableBaseUrl();

  // No SLM on web
  FeatureFlags.slmPluginReady = false;

  try {
    await FeatureFlags.refreshFromBackend().timeout(
      const Duration(seconds: 2),
    );
  } catch (_) {}

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
  ]);

  Timer.periodic(const Duration(hours: 6), (_) {
    FeatureFlags.refreshFromBackend();
  });

  runApp(const MintApp());
}
