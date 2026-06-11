import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/divorce_simulator_screen.dart';
import 'package:provider/provider.dart';

/// Widget tests pour le simulateur divorce (cadre_divorce_hypo-5).
///
/// Vérifie : (1) un champ « avoir au mariage » est présent pour chaque conjoint ;
/// (2) sans cette donnée, le simulateur n'affiche pas de montant de transfert
/// comme certain — il affiche l'état « donnée requise » (CC art. 122 / LFLP
/// art. 22a : le partage ne porte que sur la part acquise pendant le mariage).
Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => CoachProfileProvider()),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  testWidgets(
      'un champ « avoir au mariage » est présent pour chaque conjoint',
      (tester) async {
    await tester.pumpWidget(_wrap(const DivorceSimulatorScreen()));
    await tester.pumpAndSettle();

    final fr = await S.delegate.load(const Locale('fr'));

    // Les deux labels « avoir au mariage » sont rendus (un par conjoint).
    expect(find.text(fr.divorceAvoirAuMariage1), findsOneWidget);
    expect(find.text(fr.divorceAvoirAuMariage2), findsOneWidget);
  });

  testWidgets(
      'sans avoir au mariage saisi → état « donnée requise », pas de transfert certain',
      (tester) async {
    await tester.pumpWidget(_wrap(const DivorceSimulatorScreen()));
    await tester.pumpAndSettle();

    final fr = await S.delegate.load(const Locale('fr'));

    // Lancer la simulation sans renseigner l'avoir au mariage.
    final simulateBtn = find.text(fr.divorceSimuler);
    expect(simulateBtn, findsWidgets);
    await tester.ensureVisible(simulateBtn.first);
    await tester.tap(simulateBtn.first);
    await tester.pumpAndSettle();

    // Le message « donnée requise » est affiché à la place d'un transfert.
    expect(find.text(fr.divorceSplitDonneeRequise), findsWidgets);
  });
}
