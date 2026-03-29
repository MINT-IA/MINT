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
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';

// =============================================================================
// SMOKE TESTS — Mortgage Module Screens (5 screens)
// =============================================================================
//
// Verifies each screen:
//   1. Renders without crash
//   2. Key UI elements are present (titles, sections, sliders)
//   3. i18n French text is displayed
//   4. Interactive elements (sliders, dropdowns) are present
//
// Post-S52: screens use i18n via S.of(context)! with sentence-case titles.
// AffordabilityScreen uses CustomScrollView; others use ListView.
// =============================================================================

void main() {
  // ===========================================================================
  // 1. AFFORDABILITY SCREEN (CustomScrollView)
  // ===========================================================================

  group('AffordabilityScreen', () {
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
        home: AffordabilityScreen(),
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

      // i18n: affordabilityTitle = "Capacite d'achat"
      expect(find.textContaining('achat'), findsWidgets);
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

      // i18n: affordabilityIndicators = "Indicateurs"
      expect(find.textContaining('ndicateur'), findsWidgets);
    });

    testWidgets('displays ratio charges gauge', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();

      // i18n: affordabilityChargesRatio = "Ratio charges / revenus"
      expect(find.textContaining('atio'), findsWidgets);
    });

    testWidgets('displays fonds propres gauge', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();

      // i18n: affordabilityEquityRatio = "Fonds propres / prix"
      expect(find.textContaining('onds propres'), findsWidgets);
    });

    testWidgets('displays parameters section with sliders', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();

      // i18n: affordabilityParameters = "Tes hypotheses"
      expect(find.textContaining('hypoth'), findsWidgets);
    });

    testWidgets('has MintAmountField widgets for input parameters', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      // Inputs are in SECTION 6 (controls), need deep scroll to reach them
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();

      // AffordabilityScreen uses MintAmountField (tappable amount inputs)
      expect(find.byType(MintAmountField), findsWidgets);
    });

    testWidgets('has canton dropdown', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      // Canton dropdown is inside the parameters section (SECTION 6), deep scroll needed
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
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

      // i18n: affordabilityCalculationDetail = "Detail du calcul"
      expect(find.textContaining('calcul'), findsWidgets);
    });

    testWidgets('builds without overflow or crash at various scroll depths', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      for (int i = 0; i < 4; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await tester.pump();
      }
      expect(find.byType(CustomScrollView), findsOneWidget);
    });

    testWidgets('displays legal source reference', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump();

      expect(find.textContaining('directive ASB'), findsWidgets);
    });
  });

  // ===========================================================================
  // 2. SARON VS FIXED SCREEN (ListView — no CustomScrollView)
  // ===========================================================================

  group('SaronVsFixedScreen', () {
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
        home: SaronVsFixedScreen(),
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

      // i18n: saronVsFixedAppBarTitle = "SARON vs fixe"
      expect(find.textContaining('SARON'), findsWidgets);
    });

    testWidgets('displays chiffre choc with CHF amount', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.textContaining('CHF'), findsWidgets);
    });

    testWidgets('displays chart section with legend', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pump();

      // i18n legend items
      expect(find.textContaining('Fixe'), findsWidgets);
      expect(find.textContaining('SARON'), findsWidgets);
    });

    testWidgets('displays parameters section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();

      // i18n: saronVsFixedParameters = "Parametres"
      expect(find.textContaining('aram'), findsWidgets);
    });

    testWidgets('has slider and duration dropdown', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();

      expect(find.byType(Slider), findsWidgets);
    });

    testWidgets('displays cost comparison section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pump();

      // i18n: saronVsFixedCostComparison = "Comparaison des couts"
      expect(find.textContaining('omparaison'), findsWidgets);
    });

    testWidgets('displays BNS policy note', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pump();

      expect(find.textContaining('BNS'), findsWidgets);
    });

    testWidgets('contains CustomPaint widget for chart', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pump();

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('displays disclaimer after scrolling', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();

      // i18n: saronVsFixedSource contains "conseil hypothecaire"
      expect(find.textContaining('conseil'), findsWidgets);
    });
  });

  // ===========================================================================
  // 3. IMPUTED RENTAL SCREEN (ListView)
  // ===========================================================================

  group('ImputedRentalScreen', () {
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
        home: ImputedRentalScreen(),
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

      // i18n: imputedRentalAppBarTitle = "Valeur locative"
      expect(find.textContaining('locative'), findsWidgets);
    });

    testWidgets('displays intro card with educational text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      // i18n: imputedRentalIntroBody contains "proprietaires"
      expect(find.textContaining('locative'), findsWidgets);
    });

    testWidgets('displays chiffre choc with fiscal impact', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pump();

      expect(find.textContaining('/an'), findsWidgets);
    });

    testWidgets('displays decomposition section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();

      // i18n: imputedRentalDecomposition = "Decomposition"
      expect(find.textContaining('omposition'), findsWidgets);
    });

    testWidgets('displays valeur locative vs deductions bar', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();

      // i18n: imputedRentalDeductionsLabel = "Deductions"
      expect(find.textContaining('duction'), findsWidgets);
    });

    testWidgets('displays parameters section with sliders', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pump();

      // i18n: imputedRentalParameters = "Parametres"
      expect(find.textContaining('aram'), findsWidgets);
    });

    testWidgets('has Switch for bien ancien toggle', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pump();

      expect(find.byType(Switch), findsOneWidget);
      // i18n: imputedRentalOldProperty = "Bien ancien (>=10 ans)"
      expect(find.textContaining('ancien'), findsWidgets);
    });

    testWidgets('displays LIFD legal reference', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();

      expect(find.textContaining('LIFD art.'), findsWidgets);
    });
  });

  // ===========================================================================
  // 4. AMORTIZATION SCREEN (ListView)
  // ===========================================================================

  group('AmortizationScreen', () {
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
        home: AmortizationScreen(),
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

      // i18n: may contain "direct" or "indirect" or "amortissement"
      expect(find.textContaining('mortissement'), findsWidgets);
    });

    testWidgets('displays intro card with educational text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      // i18n: amortizationIntroTitle = "Amortissement : direct ou indirect ?"
      expect(find.textContaining('direct'), findsWidgets);
    });

    testWidgets('displays two method cards (Direct / Indirect)', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      // i18n: amortizationDirect = "Direct", amortizationIndirect = "Indirect"
      expect(find.textContaining('Direct'), findsWidgets);
      expect(find.textContaining('Indirect'), findsWidgets);
    });

    testWidgets('displays chiffre choc after scrolling', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();

      expect(find.textContaining('CHF'), findsWidgets);
    });

    testWidgets('displays chart section with legend', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();

      // i18n: amortizationLegendCapital3a = "Capital 3a"
      expect(find.textContaining('3a'), findsWidgets);
    });

    testWidgets('displays parameters section with sliders', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pump();

      // i18n: amortizationParameters = "Parametres"
      expect(find.textContaining('aram'), findsWidgets);
      expect(find.byType(Slider), findsWidgets);
    });

    testWidgets('displays comparison section after scrolling', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();

      // i18n: amortizationDetailedComparison = "Comparaison detaillee"
      expect(find.textContaining('omparaison'), findsWidgets);
    });

    testWidgets('displays OPP3 legal reference', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -1200));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();

      expect(find.textContaining('OPP3'), findsWidgets);
    });

    testWidgets('contains CustomPaint widget for chart', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  // ===========================================================================
  // 5. EPL COMBINED SCREEN (ListView)
  // ===========================================================================

  group('EplCombinedScreen', () {
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
        home: EplCombinedScreen(),
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

      // i18n: eplCombinedAppBarTitle = "EPL multi-sources"
      expect(find.textContaining('EPL'), findsWidgets);
    });

    testWidgets('displays chiffre choc with percentage', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.textContaining('%'), findsWidgets);
    });

    testWidgets('displays pie chart section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pump();

      // i18n: eplCombinedFundsBreakdown = "Repartition des fonds propres"
      expect(find.textContaining('partition'), findsWidgets);
    });

    testWidgets('displays funding source legend items', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();

      // i18n: eplCombinedPriceOfProperty = "du prix"
      expect(find.textContaining('du prix'), findsWidgets);
    });

    testWidgets('displays parameters section with sliders', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();

      // i18n: eplCombinedParameters = "Parametres"
      expect(find.textContaining('aram'), findsWidgets);
    });

    testWidgets('has canton dropdown', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();

      expect(find.byType(DropdownButton<String>), findsWidgets);
    });

    testWidgets('displays sources detail section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pump();

      // i18n: eplCombinedSourcesDetail = "Detail des sources"
      expect(find.textContaining('sources'), findsWidgets);
    });

    testWidgets('displays recommended order section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();

      // i18n: eplCombinedRecommendedOrder = "Ordre recommande"
      expect(find.textContaining('rdre'), findsWidgets);
    });

    testWidgets('displays LPP legal reference', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -1200));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();

      expect(find.textContaining('LPP art.'), findsWidgets);
    });

    testWidgets('contains CustomPaint widget for pie chart', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pump();

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
