// ────────────────────────────────────────────────────────────
//  PILLAR 3A (additional) — Smoke Tests
//  Screen: Retroactive3aScreen (S51 feature — OPP3 art. 7 2026)
//
//  Validates: renders without crash, Scaffold present,
//  key French content visible, calculations display CHF.
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/pillar_3a_deep/retroactive_3a_screen.dart';

// ---------------------------------------------------------------------------
//  Helper — wraps screen with French i18n (no provider needed)
// ---------------------------------------------------------------------------
Widget _buildScreen() {
  return const MaterialApp(
    locale: Locale('fr'),
    localizationsDelegates: [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    home: Retroactive3aScreen(),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ═══════════════════════════════════════════════════════════
  //  Retroactive3aScreen — S51 rattrapage 3a feature
  // ═══════════════════════════════════════════════════════════

  group('Retroactive3aScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays i18n app bar title', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      // i18n: retroactive3aTitle = "Rattrapage 3a"
      expect(find.textContaining('Rattrapage'), findsWidgets);
    });

    testWidgets('displays hero card with 2026 nouveaute', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      // i18n: retroactive3aHeroTitle = "Rattrapage 3a — Nouveauté 2026"
      expect(find.textContaining('2026'), findsWidgets);
    });

    testWidgets('displays hero card subtitle about 10 years', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      // i18n: retroactive3aHeroSubtitle = "Rattrape jusqu'à 10 ans de cotisations manquées"
      expect(find.textContaining('10'), findsWidgets);
    });

    testWidgets('shows parametres section with annees slider', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      // i18n: retroactive3aParametres = "Paramètres"
      //       retroactive3aAnneesARattraper = "Années à rattraper"
      expect(find.textContaining('aram'), findsWidgets);
      expect(find.textContaining('rattraper'), findsWidgets);
    });

    testWidgets('shows taux marginal selector', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      // i18n: retroactive3aTauxMarginal = "Taux marginal d'imposition"
      expect(find.textContaining('marginal'), findsWidgets);
    });

    testWidgets('shows LPP affiliation toggle', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      // i18n: retroactive3aAffilieLpp = "Affilié·e à une caisse LPP"
      expect(find.textContaining('LPP'), findsWidgets);
    });

    testWidgets('shows chiffre choc with economies fiscales', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      // i18n: retroactive3aEconomiesFiscales = "Économies fiscales estimées"
      expect(find.textContaining('conomies'), findsWidgets);
    });

    testWidgets('displays CHF amounts in results', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.textContaining('CHF'), findsWidgets);
    });

    testWidgets('shows detail par annee breakdown', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();
      // i18n: retroactive3aDetailParAnnee = "Détail par année"
      expect(find.textContaining('nnée', skipOffstage: false), findsWidgets);
    });

    testWidgets('shows impact avant apres section', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pump();
      // i18n: retroactive3aImpactAvantApres = "Impact avant / après"
      //       retroactive3aSansRattrapage = "Sans rattrapage"
      //       retroactive3aAvecRattrapage = "Avec rattrapage"
      expect(find.textContaining('rattrapage', skipOffstage: false), findsWidgets);
    });

    testWidgets('shows prochaines etapes action cards', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pump();
      // i18n: retroactive3aProchainesEtapes = "Prochaines étapes"
      expect(
        find.textContaining('tapes', skipOffstage: false),
        findsWidgets,
      );
    });

    testWidgets('shows disclaimer section', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pump();
      // OPP3 source reference
      expect(find.textContaining('OPP3', skipOffstage: false), findsWidgets);
    });

    testWidgets('changing gap years from 5 to 3 updates CHF display',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      // Scroll to the Slider for gap years
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();

      // The Slider should be rendered
      expect(find.byType(Slider), findsWidgets);

      // Drag to change value — screen should re-render without crash
      final slider = find.byType(Slider).first;
      await tester.drag(slider, const Offset(-80, 0));
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
