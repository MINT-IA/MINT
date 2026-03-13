import 'package:flutter/material.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/web/web_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ApiService.ensureReachableBaseUrl();

  try {
    await FeatureFlags.refreshFromBackend().timeout(
      const Duration(seconds: 2),
    );
  } catch (_) {}

  runApp(const MintWebApp());
}
