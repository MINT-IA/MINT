import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/screens/concubinage_screen.dart';
import 'package:mint_mobile/screens/divorce_simulator_screen.dart';
import 'package:mint_mobile/screens/mariage_screen.dart';
import 'package:mint_mobile/screens/naissance_screen.dart';
import 'package:provider/provider.dart';

/// Tier B smoke — lot B1 Famille : preuve d'ancre régionale C1.
///
/// Chaque écran life-event famille porte une ancre `Semantics(identifier:
/// '<event>-anchor')` posée sur le TITRE de l'AppBar (motif régional profond,
/// jamais le wrapper racine — leçon ADR AX iOS 26.2). Les flows Maestro
/// `flow_tierb_famille_<event>.yaml` s'appuient dessus pour le gate C1
/// « atteignable ». Ce test prouve la PRÉSENCE de l'ancre dans l'arbre de
/// widgets (indépendamment de l'effondrement AX runtime sur iOS 26.2, qui est
/// une dette AX séparée non corrigée ici) : un renommage / retrait de l'ancre
/// casse le flow — ce test le rattrape avant.
class _FakeProvider extends CoachProfileProvider {
  _FakeProvider(this._injected);
  final CoachProfile? _injected;
  @override
  CoachProfile? get profile => _injected;
}

Finder _byIdentifier(String identifier) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == identifier,
    );

Future<void> _pump(WidgetTester tester, Widget screen) async {
  await tester.binding.setSurfaceSize(const Size(1200, 9000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<CoachProfileProvider>.value(
      value: _FakeProvider(null),
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: screen,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('mariage_screen porte les ancres C1 + C4 (anchor + back)',
      (tester) async {
    await _pump(tester, const MariageScreen());
    expect(_byIdentifier('mariage-anchor'), findsOneWidget);
    expect(_byIdentifier('mariage-back'), findsOneWidget);
  });

  testWidgets('naissance_screen porte les ancres C1 + C4 (anchor + back)',
      (tester) async {
    await _pump(tester, const NaissanceScreen());
    expect(_byIdentifier('naissance-anchor'), findsOneWidget);
    expect(_byIdentifier('naissance-back'), findsOneWidget);
  });

  testWidgets('concubinage_screen porte les ancres C1 + C4 (anchor + back)',
      (tester) async {
    await _pump(tester, const ConcubinageScreen());
    expect(_byIdentifier('concubinage-anchor'), findsOneWidget);
    expect(_byIdentifier('concubinage-back'), findsOneWidget);
  });

  testWidgets('divorce_simulator_screen porte les ancres C1 + C4 (anchor + back)',
      (tester) async {
    await _pump(tester, const DivorceSimulatorScreen());
    expect(_byIdentifier('divorce-anchor'), findsOneWidget);
    expect(_byIdentifier('divorce-back'), findsOneWidget);
  });
}
