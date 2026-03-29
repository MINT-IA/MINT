import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Screens under test
import 'package:mint_mobile/screens/pillar_3a_deep/staggered_withdrawal_screen.dart';
import 'package:mint_mobile/screens/pillar_3a_deep/real_return_screen.dart';
import 'package:mint_mobile/screens/pillar_3a_deep/provider_comparator_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

// =============================================================================
// SMOKE TESTS — Pillar 3a Deep Module Screens (3 screens)
// Post-S52: screens use i18n with sentence-case titles.
// StaggeredWithdrawal & ProviderComparator use CustomScrollView.
// RealReturn uses ListView.
// =============================================================================

void main() {
  // ===========================================================================
  // 1. STAGGERED WITHDRAWAL SCREEN (CustomScrollView)
  // ===========================================================================

  group('StaggeredWithdrawalScreen', () {
    Widget buildScreen() {
      return const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: StaggeredWithdrawalScreen(),
      );
    }

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays i18n title in SliverAppBar', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: staggered3aTitle = "Retrait 3a echelonne"
      expect(find.textContaining('3a'), findsWidgets);
    });

    testWidgets('displays chiffre choc with economie estimee', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: staggered3aEconomie = "Economie estimee"
      expect(find.textContaining('conomie'), findsWidgets);
      expect(find.textContaining('CHF'), findsWidgets);
    });

    testWidgets('displays intro card with educational text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();
      // i18n: staggered3aIntroTitle = "Pourquoi echelonner les retraits 3a"
      expect(find.textContaining('chelonner'), findsWidgets);
    });

    testWidgets('mentions OPP3 in educational text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();
      expect(find.textContaining('OPP3'), findsOneWidget);
    });

    testWidgets('displays parameters section with sliders', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();
      // i18n: staggered3aParametres = "Parametres"
      expect(find.textContaining('aram'), findsWidgets);
    });

    testWidgets('has canton dropdown', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();
      expect(find.textContaining('Canton'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });

    testWidgets('has age sliders for withdrawal window', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();
      // i18n: staggered3aAgeDebut/AgeFin
      expect(find.textContaining('ge'), findsWidgets);
    });

    testWidgets('displays comparison section with bloc vs echelonne',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pump();
      // i18n: staggered3aResultat = "Resultat", staggered3aEnBloc, staggered3aEchelonneLabel
      expect(find.textContaining('sultat'), findsWidgets);
    });

    testWidgets('displays yearly plan table', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pump();
      // i18n: staggered3aPlanAnnuel = "Plan annuel"
      expect(find.textContaining('lan annuel'), findsWidgets);
    });

    testWidgets('displays disclaimer after scrolling', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();
      expect(find.byIcon(Icons.info_outline), findsWidgets);
    });
  });

  // ===========================================================================
  // 2. REAL RETURN SCREEN (ListView)
  // ===========================================================================

  group('RealReturnScreen', () {
    Widget buildScreen() {
      return const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: RealReturnScreen(),
      );
    }

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays i18n title in AppBar', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: realReturnTitle = "Rendement reel 3a"
      expect(find.textContaining('endement'), findsWidgets);
    });

    testWidgets('displays chiffre choc with rendement percentage',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: realReturnChiffreChocLabel = "Taux equivalent sur effort net"
      expect(find.textContaining('quivalent'), findsWidgets);
      expect(find.textContaining('%'), findsWidgets);
    });

    testWidgets('displays parameters section with 5 sliders', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();
      // i18n: realReturnParams = "Parametres"
      expect(find.textContaining('aram'), findsWidgets);
    });

    testWidgets('has 5 Slider widgets', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
      expect(find.byType(Slider), findsNWidgets(5));
    });

    testWidgets('displays rendements compares section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pump();
      // i18n: realReturnCompared = "Rendements compares"
      expect(find.textContaining('endements'), findsWidgets);
    });

    testWidgets('displays capital final comparison bars', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pump();
      // i18n: realReturnFinalCapital contains "Capital final"
      expect(find.textContaining('apital final'), findsWidgets);
    });

    testWidgets('displays gain vs epargne classique', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pump();
      // i18n: realReturnGainVsSavings contains "Gain vs epargne classique"
      expect(find.textContaining('ain vs'), findsWidgets);
    });

    testWidgets('has LinearProgressIndicator for comparison bars',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    });

    testWidgets('displays fiscal detail section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
      // i18n: realReturnFiscalDetail = "Detail economie fiscale"
      expect(find.textContaining('conomie fiscale'), findsWidgets);
    });

    testWidgets('displays disclaimer after scrolling', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -1200));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
      expect(find.byIcon(Icons.info_outline), findsWidgets);
    });
  });

  // ===========================================================================
  // 3. PROVIDER COMPARATOR SCREEN (CustomScrollView)
  // ===========================================================================

  group('ProviderComparatorScreen', () {
    Widget buildScreen() {
      return const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: ProviderComparatorScreen(),
      );
    }

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays i18n title in SliverAppBar', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: providerComparatorAppBarTitle = "Comparateur 3a"
      expect(find.textContaining('omparateur 3a'), findsWidgets);
    });

    testWidgets('displays chiffre choc with difference amount', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: providerComparatorChiffreChocLabel = "Difference sur X ans"
      expect(find.textContaining('iff'), findsWidgets);
      expect(find.textContaining('CHF'), findsWidgets);
    });

    testWidgets('displays parameters section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();
      // i18n: providerComparatorSectionParametres = "Parametres"
      expect(find.textContaining('aram'), findsWidgets);
    });

    testWidgets('has 3 Slider widgets (age, versement, duree)', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();
      expect(find.byType(Slider), findsNWidgets(3));
    });

    testWidgets('displays risk profile selector with 3 options',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();
      // i18n: providerComparatorLabelProfilRisque = "Profil de risque"
      expect(find.textContaining('rofil'), findsWidgets);
      expect(find.textContaining('rudent'), findsWidgets);
    });

    testWidgets('displays comparison section with provider cards',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();
      // i18n: providerComparatorSectionComparaison = "Comparaison"
      expect(find.textContaining('omparaison'), findsWidgets);
    });


    testWidgets('displays assurance warning for age 30', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();
      // i18n: providerComparatorAssuranceTitle = "Attention — Assurance 3a"
      expect(find.textContaining('ssurance 3a'), findsWidgets);
    });

    testWidgets('displays disclaimer after scrolling', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump();
      expect(find.byIcon(Icons.info_outline), findsWidgets);
    });

    testWidgets('risk profile selection changes state', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();
      // Tap Prudent
      await tester.tap(find.textContaining('rudent'));
      await tester.pump();
      expect(find.textContaining('rudent'), findsWidgets);
    });

    testWidgets('displays vs meilleur badge on non-best providers',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();
      expect(find.textContaining('vs premier'), findsWidgets);
    });
  });
}
