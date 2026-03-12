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
// =============================================================================
//
// Verifies each screen:
//   1. Renders without crash
//   2. Key UI elements are present (titles, sections, sliders)
//   3. French text is displayed
//   4. Disclaimer is visible after scrolling
//   5. Interactive elements (sliders, dropdowns, risk profile selector) present
//   6. Legal references (OPP3, LIFD) are cited
//
// All screens use CustomScrollView with SliverAppBar + SliverList.
// Elements below the initial viewport require scrolling to become visible.
// =============================================================================

void main() {
  // ===========================================================================
  // 1. STAGGERED WITHDRAWAL SCREEN
  // ===========================================================================
  //
  // No Provider dependency. Uses StaggeredWithdrawalSimulator from
  // pillar_3a_deep_service. Compares bloc vs staggered 3a withdrawal tax.
  // ===========================================================================

  group('StaggeredWithdrawalScreen', () {
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
        home: StaggeredWithdrawalScreen(),
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

      expect(find.text('RETRAIT 3A ÉCHELONNÉ'), findsOneWidget);
    });

    testWidgets('displays chiffre choc with economie estimee', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('Économie estimée'), findsOneWidget);
      expect(find.textContaining('CHF'), findsWidgets);
      expect(find.textContaining('comptes'), findsWidgets);
    });

    testWidgets('displays intro card with educational text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();

      expect(find.textContaining('échelonner les retraits 3a'), findsOneWidget);
      expect(find.textContaining('progressif'), findsOneWidget);
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

      expect(find.text('PARAMÈTRES'), findsOneWidget);
      expect(find.text('Avoir 3a total'), findsOneWidget);
      expect(find.text('Nombre de comptes 3a'), findsOneWidget);
      expect(find.text('Revenu imposable'), findsOneWidget);
    });

    testWidgets('has canton dropdown', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();

      expect(find.text('Canton'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });

    testWidgets('has age sliders for withdrawal window', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();

      expect(find.text('Âge début retraits'), findsOneWidget);
      expect(find.text('Âge dernier retrait'), findsOneWidget);
    });

    testWidgets('displays comparison section with bloc vs echelonne',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pump();

      expect(find.text('RÉSULTAT'), findsOneWidget);
      expect(find.text('EN BLOC'), findsOneWidget);
      expect(find.text('ÉCHELONNÉ'), findsOneWidget);
      expect(find.text('Impôt estimé'), findsWidgets);
    });

    testWidgets('displays yearly plan table', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pump();

      expect(find.text('PLAN ANNUEL'), findsOneWidget);
      expect(find.text('Age'), findsWidgets);
      expect(find.text('Retrait'), findsOneWidget);
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
  // 2. REAL RETURN SCREEN
  // ===========================================================================
  //
  // No Provider dependency. Uses RealReturnCalculator from
  // pillar_3a_deep_service. Compares 3a fintech vs savings account returns
  // including fiscal advantage.
  // ===========================================================================

  group('RealReturnScreen', () {
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
        home: RealReturnScreen(),
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

      expect(find.text('RENDEMENT REEL 3A'), findsOneWidget);
    });

    testWidgets('displays chiffre choc with rendement percentage',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('Taux equivalent sur effort net'), findsOneWidget);
      expect(find.textContaining('%'), findsWidgets);
      expect(find.textContaining('taux net 3a'), findsOneWidget);
    });

    testWidgets('displays parameters section with 5 sliders', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();

      expect(find.text('PARAMETRES'), findsOneWidget);
      expect(find.text('Versement annuel'), findsOneWidget);
      expect(find.text('Taux marginal'), findsOneWidget);
      expect(find.text('Rendement brut'), findsOneWidget);
      expect(find.text('Frais de gestion'), findsOneWidget);
      expect(find.text('Duree de placement'), findsOneWidget);
    });

    testWidgets('has 5 Slider widgets', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();

      expect(find.byType(Slider), findsNWidgets(5));
    });

    testWidgets('displays rendements compares section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();

      expect(find.text('RENDEMENTS COMPARES'), findsOneWidget);
      expect(find.textContaining('Rendement nominal 3a'), findsOneWidget);
      expect(find.textContaining('Rendement reel'), findsWidgets);
      expect(find.textContaining('Rendement compte epargne'), findsOneWidget);
    });

    testWidgets('displays capital final comparison bars', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump();

      expect(find.textContaining('CAPITAL FINAL'), findsOneWidget);
      expect(find.textContaining('3a Fintech'), findsOneWidget);
      expect(find.textContaining('Compte epargne'), findsOneWidget);
    });

    testWidgets('displays gain vs epargne classique', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();

      expect(find.textContaining('Gain vs epargne classique'), findsOneWidget);
    });

    testWidgets('has LinearProgressIndicator for comparison bars',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    });

    testWidgets('displays fiscal detail section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();

      expect(find.text('DETAIL ECONOMIE FISCALE'), findsOneWidget);
      expect(find.text('Total versements'), findsOneWidget);
      expect(find.textContaining('Economie fiscale cumulee'), findsOneWidget);
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
  // 3. PROVIDER COMPARATOR SCREEN
  // ===========================================================================
  //
  // No Provider dependency. Uses ProviderComparator from
  // pillar_3a_deep_service. Compares 5 provider types (fintech, bank,
  // insurance) with risk profile selector and assurance warning.
  // ===========================================================================

  group('ProviderComparatorScreen', () {
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
        home: ProviderComparatorScreen(),
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

      expect(find.text('COMPARATEUR 3A'), findsOneWidget);
    });

    testWidgets('displays chiffre choc with difference amount', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.textContaining('Difference sur'), findsOneWidget);
      expect(find.textContaining('CHF'), findsWidgets);
      expect(find.textContaining('plus et le moins performant'), findsOneWidget);
    });

    testWidgets('displays parameters section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();

      expect(find.text('PARAMETRES'), findsOneWidget);
      expect(find.text('Age'), findsWidgets);
      expect(find.text('Versement annuel'), findsOneWidget);
      expect(find.text('Duree'), findsOneWidget);
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

      expect(find.text('Profil de risque'), findsOneWidget);
      expect(find.text('Prudent'), findsOneWidget);
      expect(find.text('Equilibre'), findsOneWidget);
      expect(find.text('Dynamique'), findsOneWidget);
    });

    testWidgets('displays comparison section with provider cards',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();

      expect(find.text('COMPARAISON'), findsOneWidget);
      // Provider metrics
      expect(find.text('Rendement'), findsWidgets);
      expect(find.text('Frais'), findsWidgets);
      expect(find.text('Capital final'), findsWidgets);
    });


    testWidgets('displays assurance warning for age 30', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      // Default age is 30, which should trigger assurance warning
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();

      expect(find.textContaining('Assurance 3a'), findsWidgets);
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

      // Default is Dynamique (selected), tap Prudent
      await tester.tap(find.text('Prudent'));
      await tester.pump();

      // The screen should rebuild with new results
      expect(find.text('Prudent'), findsOneWidget);
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
