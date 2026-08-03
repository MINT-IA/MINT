import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/lpp_deep/rachat_echelonne_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildRachatScreen({int? birthYear}) {
    final provider = CoachProfileProvider();
    if (birthYear != null) {
      provider.updateProfile(CoachProfile(
        firstName: 'Sam',
        birthYear: birthYear,
        canton: 'VD',
        salaireBrutMensuel: 9000,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2045),
          label: 'Retraite',
        ),
      ));
    }
    return ChangeNotifierProvider<CoachProfileProvider>.value(
      value: provider,
      child: const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: RachatEchelonneScreen(),
      ),
    );
  }

  testWidgets('RachatEchelonneScreen renders and shows CHF amounts', (tester) async {
    await tester.pumpWidget(buildRachatScreen());
    await tester.pump();
    expect(find.byType(RachatEchelonneScreen), findsOneWidget);
    expect(find.textContaining('CHF'), findsWidgets);
  });

  group('fenêtre 79b al. 3 — rendu (beads -a6e, panel design)', () {
    testWidgets('âge 63 : badge tranche + scénario capital visibles (320pt)',
        (tester) async {
      // Surface étroite : attrape aussi l'overflow de la ligne
      // conditionnelle détecté par le panel engineering.
      tester.view.physicalSize = const Size(320, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final currentYear = DateTime.now().year;
      await tester.pumpWidget(
          buildRachatScreen(birthYear: currentYear - 63));
      await tester.pump(const Duration(milliseconds: 400));

      final l = await S.delegate.load(const Locale('fr'));
      // P0 2026-08-03 : depuis que le gate SafeMode n'est plus verrouillé à tort
      // pour un profil partiel, l'écran est plein hauteur et le « Plan annuel »
      // (badge / note 79b) vit SOUS le pli. Le corps est un CustomScrollView
      // paresseux (SliverChildListDelegate ne monte que viewport + cache) : il
      // faut le faire défiler à l'écran avant d'asserter. Contenu RÉEL rendu sur
      // device — aucune assertion affaiblie, aucun contournement.
      await tester.scrollUntilVisible(
        find.text(l.rachatEchelonneFenetre79bNote, skipOffstage: false),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(l.rachatEchelonneFenetre79bBadge, skipOffstage: false),
        findsWidgets,
        reason: 'à 63 ans, des tranches du plan sont à moins de 3 ans du '
            'retrait capital -> badge visible',
      );
      expect(
        find.textContaining('Impact fiscal si retrait en capital',
            skipOffstage: false),
        findsOneWidget,
        reason: 'la ligne scénario capital doit accompagner le total',
      );
      expect(
        find.text(l.rachatEchelonneFenetre79bNote, skipOffstage: false),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull,
          reason: 'pas de RenderFlex overflow à 320pt');
    });

    testWidgets('âge 40 : aucun marquage 79b', (tester) async {
      tester.view.physicalSize = const Size(320, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final currentYear = DateTime.now().year;
      await tester.pumpWidget(
          buildRachatScreen(birthYear: currentYear - 40));
      await tester.pump(const Duration(milliseconds: 400));

      final l = await S.delegate.load(const Locale('fr'));
      expect(
        find.text(l.rachatEchelonneFenetre79bBadge, skipOffstage: false),
        findsNothing,
      );
      expect(
        find.textContaining('Impact fiscal si retrait en capital',
            skipOffstage: false),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  });
}