import 'package:flutter/material.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/services/pillar_3a_calculator.dart';
import 'package:mint_mobile/services/tax_scales_loader.dart';

/// Point d'entrée de l'application MINT
///
/// Démarre l'app immédiatement (Progressive Disclosure)
/// et charge les services en arrière-plan
void main() {
  // Initialisation Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Chargement des données critiques en arrière-plan (non-bloquant)
  Future.wait([
    Pillar3aCalculator.loadLimits()
        .catchError((e) => debugPrint('⚠️ Err 3a: $e')),
    TaxScalesLoader.load().catchError((e) => debugPrint('⚠️ Err Tax: $e')),
  ]);

  // Lancement immédiat de l'app (UX first!)
  runApp(const MintApp());
}
