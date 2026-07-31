import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/coach/retirement_dashboard_screen.dart';
import 'package:mint_mobile/services/coach/coach_profile_seeds.dart';
import 'package:provider/provider.dart';

/// Preuve runtime (widget) — le dashboard /retraite honore la rente AVS
/// DÉCLARÉE au lieu d'afficher tout à zéro pour un retraité déjà en régime.
///
/// AVANT le correctif : `ForecasterService.project` retournait un scénario VIDE
/// pour `retraite_lausanne` (date de retraite 2023, passée → `months <= 0`),
/// d'où AVS ≈ 0, taux 0 %, revenu 0 sur tout le dashboard.
///
/// APRÈS : revenu de retraite évalué depuis les soldes courants, rente AVS
/// déclarée (2'000 échelle 44, honorée au niveau brut → 2'167 mensuel effectif
/// avec la 13e rente), taux de remplacement en continuité (~100 %).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  CoachProfileProvider seeded() => CoachProfileProvider()
    ..updateFromAnswers(
        CoachProfileSeeds.registry['retraite_lausanne']!.toWizardAnswers());

  Widget harness(CoachProfileProvider coach) => MultiProvider(
        providers: [
          ChangeNotifierProvider<CoachProfileProvider>.value(value: coach),
          ChangeNotifierProvider<ByokProvider>(create: (_) => ByokProvider()),
          ChangeNotifierProvider<SlmProvider>(create: (_) => SlmProvider()),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: RetirementDashboardScreen(),
        ),
      );

  testWidgets(
      '/retraite : ligne AVS chiffrée (2 000) + taux non-nul pour un retraité',
      (tester) async {
    // Filtre : seuls les débordements de layout au width de test sont avalés.
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
        return;
      }
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);

    await tester.binding.setSurfaceSize(const Size(1200, 9000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(harness(seeded()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // La ligne AVS montre la rente déclarée 2'000 (avant : « CHF 0 »).
    expect(find.text('CHF 2167'), findsWidgets,
        reason: 'la ligne AVS du dashboard doit afficher la rente déclarée');

    // Le taux de remplacement héroïque n'est plus 0 % (continuité ~100 %).
    expect(find.text('0 %'), findsNothing,
        reason: 'taux 0 % trompeur pour un retraité — doit être non-nul');
    expect(find.text('100 %'), findsWidgets,
        reason: 'continuité de revenu pour un retraité déjà en régime');
  });
}
