import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Screens under test
import 'package:mint_mobile/screens/mortgage/affordability_screen.dart';
import 'package:mint_mobile/screens/mortgage/saron_vs_fixed_screen.dart';
import 'package:mint_mobile/screens/mortgage/imputed_rental_screen.dart';
import 'package:mint_mobile/screens/mortgage/amortization_screen.dart';
import 'package:mint_mobile/screens/mortgage/epl_combined_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

import '../test_helpers.dart';

// =============================================================================
// SMOKE TESTS — Mortgage Module Screens (5 screens)
// =============================================================================
//
// Verifies each screen:
//   1. Renders without crash
//   2. Key UI elements are present (titles, sections, sliders)
//   3. French text is displayed
//   4. Disclaimer is visible after scrolling
//   5. Interactive elements (sliders, dropdowns) are present
//
// All screens use CustomScrollView with SliverAppBar + SliverList.
// Elements below the initial viewport require scrolling to become visible.
// =============================================================================

void main() {
  // ===========================================================================
  // 1. AFFORDABILITY SCREEN
  // ===========================================================================
  //
  // No Provider dependency. Uses AffordabilityCalculator from mortgage_service.
  // Stateful widget with sliders for income, price, savings, 3a, LPP, canton.
  // ===========================================================================

  group('AffordabilityScreen', () {
    Widget buildScreen() {
      return const MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: AffordabilityScreen(),
      );
    }

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays French title in SliverAppBar', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('CAPACITÉ D\'ACHAT'), findsOneWidget);
    });

    testWidgets('displays chiffre choc card with CHF amount', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.textContaining('CHF'), findsWidgets);
    });

    testWidgets('displays indicators section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      // Scroll to reveal indicators
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();

      expect(find.text('INDICATEURS'), findsOneWidget);
    });

    testWidgets('displays ratio charges gauge', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();

      expect(find.textContaining('Ratio charges'), findsOneWidget);
      expect(find.text('Max 33%'), findsOneWidget);
    });

    testWidgets('displays fonds propres gauge', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();

      expect(find.textContaining('Fonds propres'), findsWidgets);
      expect(find.text('Min 20%'), findsOneWidget);
    });

    testWidgets('displays parameters section with sliders', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();

      expect(find.text('PARAMÈTRES'), findsOneWidget);
      expect(find.text('Canton'), findsOneWidget);
      expect(find.text('Revenu brut annuel'), findsOneWidget);
    });

    testWidgets('has Slider widgets for input parameters', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();

      // 5 sliders: revenu, prix achat, epargne, avoir 3a, avoir LPP
      expect(find.byType(Slider), findsNWidgets(5));
    });

    testWidgets('has canton dropdown', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();

      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });

    testWidgets('displays detail section after scrolling', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump();

      expect(find.text('DÉTAIL DU CALCUL'), findsOneWidget);
    });

    testWidgets('displays disclaimer after scrolling', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();

      expect(find.byIcon(Icons.info_outline), findsWidgets);
    });

    testWidgets('displays legal source reference', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();

      expect(find.textContaining('directive ASB'), findsWidgets);
    });
  });

  // ===========================================================================
  // 2. SARON VS FIXED SCREEN
  // ===========================================================================
  //
  // No Provider dependency. Uses SaronVsFixedCalculator.
  // Contains CustomPainter chart for 3 mortgage cost curves.
  // ===========================================================================

  group('SaronVsFixedScreen', () {
    Widget buildScreen() {
      return const MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: SaronVsFixedScreen(),
      );
    }

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays French title in SliverAppBar', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('SARON VS FIXE'), findsOneWidget);
    });

    testWidgets('displays chiffre choc with CHF amount', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.textContaining('CHF'), findsWidgets);
      expect(find.byIcon(Icons.compare_arrows), findsOneWidget);
    });

    testWidgets('displays chart section with legend', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();

      expect(find.textContaining('COUT CUMULE'), findsOneWidget);
      expect(find.text('Fixe'), findsOneWidget);
      expect(find.text('SARON stable'), findsOneWidget);
      expect(find.text('SARON hausse'), findsOneWidget);
    });

    testWidgets('displays parameters section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();

      expect(find.text('PARAMETRES'), findsOneWidget);
      expect(find.text('Montant hypothecaire'), findsOneWidget);
      expect(find.text('Duree'), findsOneWidget);
    });

    testWidgets('has slider and duration dropdown', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();

      expect(find.byType(Slider), findsOneWidget);
      expect(find.byType(DropdownButton<int>), findsOneWidget);
    });

    testWidgets('displays cost comparison section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pump();

      expect(find.text('COMPARAISON DES COUTS'), findsOneWidget);
    });

    testWidgets('displays BNS policy note', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pump();

      expect(find.textContaining('BNS'), findsOneWidget);
    });

    testWidgets('contains CustomPaint widget for chart', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('displays disclaimer after scrolling', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();

      expect(find.textContaining('conseil hypothecaire'), findsWidgets);
    });
  });

  // ===========================================================================
  // 3. IMPUTED RENTAL SCREEN
  // ===========================================================================
  //
  // No Provider dependency. Uses ImputedRentalCalculator.
  // Has Switch for bien ancien, plus multiple sliders.
  // ===========================================================================

  group('ImputedRentalScreen', () {
    Widget buildScreen() {
      return const MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: ImputedRentalScreen(),
      );
    }

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays French title in SliverAppBar', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('VALEUR LOCATIVE'), findsOneWidget);
    });

    testWidgets('displays intro card with educational text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.textContaining('valeur locative'), findsWidgets);
      expect(find.textContaining('propriétaires'), findsOneWidget);
    });

    testWidgets('displays chiffre choc with fiscal impact', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();

      expect(find.textContaining('/an'), findsWidgets);
    });

    testWidgets('displays decomposition section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();

      expect(find.text('DÉCOMPOSITION'), findsOneWidget);
    });

    testWidgets('displays valeur locative vs deductions bar', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();

      expect(find.textContaining('Déductions'), findsWidgets);
    });

    testWidgets('displays parameters section with sliders', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pump();

      expect(find.text('PARAMÈTRES'), findsOneWidget);
      expect(find.text('Canton'), findsOneWidget);
    });

    testWidgets('has Switch for bien ancien toggle', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump();

      expect(find.byType(Switch), findsOneWidget);
      expect(find.textContaining('Bien ancien'), findsOneWidget);
    });

    testWidgets('displays LIFD legal reference', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();

      expect(find.textContaining('LIFD art.'), findsWidgets);
    });
  });

  // ===========================================================================
  // 4. AMORTIZATION SCREEN
  // ===========================================================================
  //
  // No Provider dependency. Uses AmortizationCalculator.
  // Contains CustomPainter chart for direct vs indirect amortization.
  // ===========================================================================

  group('AmortizationScreen', () {
    Widget buildScreen() {
      return const MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: AmortizationScreen(),
      );
    }

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays French title in SliverAppBar', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('DIRECT VS INDIRECT'), findsOneWidget);
    });

    testWidgets('displays intro card with educational text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.textContaining('direct ou indirect'), findsOneWidget);
      expect(find.textContaining('amortissement indirect'), findsWidgets);
    });

    testWidgets('displays two method cards (Direct / Indirect)', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('Direct'), findsOneWidget);
      expect(find.text('Indirect'), findsOneWidget);
    });

    testWidgets('displays chiffre choc after scrolling', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();

      expect(find.textContaining('CHF'), findsWidgets);
    });

    testWidgets('displays chart section with legend', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();

      expect(find.textContaining('ÉVOLUTION SUR'), findsOneWidget);
      expect(find.text('Capital 3a'), findsOneWidget);
    });

    testWidgets('displays parameters section with 4 sliders', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump();

      expect(find.text('PARAMÈTRES'), findsOneWidget);
      expect(find.text('Montant hypothécaire'), findsOneWidget);
      expect(find.byType(Slider), findsNWidgets(4));
    });

    testWidgets('displays comparison section after scrolling', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();

      expect(find.text('COMPARAISON DÉTAILLÉE'), findsOneWidget);
      expect(find.text('Amortissement direct'), findsOneWidget);
      expect(find.text('Amortissement indirect'), findsOneWidget);
    });

    testWidgets('displays OPP3 legal reference', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();

      expect(find.textContaining('OPP3'), findsWidgets);
    });

    testWidgets('contains CustomPaint widget for chart', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  // ===========================================================================
  // 5. EPL COMBINED SCREEN
  // ===========================================================================
  //
  // No Provider dependency. Uses EplCombinedCalculator.
  // Contains CustomPainter pie chart for funding sources.
  // ===========================================================================

  group('EplCombinedScreen', () {
    Widget buildScreen() {
      return const MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: EplCombinedScreen(),
      );
    }

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays French title in SliverAppBar', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('EPL MULTI-SOURCES'), findsOneWidget);
    });

    testWidgets('displays chiffre choc with percentage', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      // The chiffre choc shows a percentage of coverage
      expect(find.textContaining('%'), findsWidgets);
    });

    testWidgets('displays pie chart section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();

      expect(find.text('REPARTITION DES FONDS PROPRES'), findsOneWidget);
    });

    testWidgets('displays funding source legend items', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();

      // Pie chart legend items for cash, 3a, LPP
      expect(find.textContaining('du prix'), findsWidgets);
    });

    testWidgets('displays parameters section with sliders', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();

      expect(find.text('PARAMETRES'), findsOneWidget);
      expect(find.text('Canton'), findsOneWidget);
    });

    testWidgets('has canton dropdown', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();

      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });

    testWidgets('displays sources detail section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pump();

      expect(find.text('DETAIL DES SOURCES'), findsOneWidget);
    });

    testWidgets('displays recommended order section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();

      expect(find.text('ORDRE RECOMMANDE'), findsOneWidget);
    });

    testWidgets('displays LPP legal reference', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();

      expect(find.textContaining('LPP art. 30c'), findsWidgets);
    });

    testWidgets('contains CustomPaint widget for pie chart', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
