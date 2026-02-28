import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Screens under test
import 'package:mint_mobile/screens/lpp_deep/rachat_echelonne_screen.dart';
import 'package:mint_mobile/screens/lpp_deep/libre_passage_screen.dart';
import 'package:mint_mobile/screens/lpp_deep/epl_screen.dart';

// =============================================================================
// SMOKE TESTS — LPP Deep Module Screens (3 screens)
// =============================================================================
//
// Verifies each screen:
//   1. Renders without crash
//   2. Key UI elements are present (titles, sections, sliders)
//   3. French text is displayed
//   4. Disclaimer is visible after scrolling
//   5. Interactive elements (sliders, choice chips, switches) are present
//   6. Legal references (LPP, LFLP, OEPL) are cited
//
// All screens use CustomScrollView with SliverAppBar + SliverList.
// Elements below the initial viewport require scrolling to become visible.
// =============================================================================

void main() {
  // ===========================================================================
  // 1. RACHAT ECHELONNE SCREEN
  // ===========================================================================
  //
  // No Provider dependency. Uses RachatEchelonneSimulator from lpp_deep_service.
  // Compares bloc vs staggered LPP buy-back with yearly plan table.
  // ===========================================================================

  group('RachatEchelonneScreen', () {
    Widget buildScreen() {
      return const MaterialApp(
        home: RachatEchelonneScreen(),
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

      expect(find.text('RACHAT LPP ECHELONNE'), findsOneWidget);
    });

    testWidgets('displays intro card with educational text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.textContaining('échelonner ses rachats'), findsOneWidget);
      expect(find.textContaining('progressif'), findsOneWidget);
    });

    testWidgets('has Slider widgets for input parameters', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      // At least 3 sliders visible in initial viewport
      expect(find.byType(Slider), findsWidgets);
    });

    testWidgets('has CustomScrollView for scrollable content', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byType(CustomScrollView), findsOneWidget);
    });
  });

  // ===========================================================================
  // 2. LIBRE PASSAGE SCREEN
  // ===========================================================================
  //
  // No Provider dependency. Uses LibrePassageAdvisor from lpp_deep_service.
  // Has ChoiceChips for situation selection, Switch for new employer,
  // and dynamic checklist/alerts/recommendations based on situation.
  // ===========================================================================

  group('LibrePassageScreen', () {
    Widget buildScreen() {
      return const MaterialApp(
        home: LibrePassageScreen(),
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

      expect(find.text('LIBRE PASSAGE'), findsOneWidget);
    });

    testWidgets('displays situation selector with choice chips',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('SITUATION'), findsOneWidget);
      expect(find.text('Changement d\'emploi'), findsOneWidget);
      expect(find.text('Depart de Suisse'), findsOneWidget);
      expect(find.text('Cessation d\'activite'), findsOneWidget);
    });

    testWidgets('has ChoiceChip widgets for situation', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byType(ChoiceChip), findsNWidgets(3));
    });

    testWidgets('displays new employer toggle', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('Nouvel employeur'), findsOneWidget);
      expect(find.textContaining('nouvel employeur'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('displays checklist section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();

      expect(find.text('CHECKLIST'), findsOneWidget);
    });

    testWidgets('displays urgency badges in checklist', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();

      // At least one urgency badge should be visible
      final urgencyBadges = find.textContaining(RegExp('Critique|Haute|Moyenne'));
      expect(urgencyBadges, findsWidgets);
    });

    testWidgets('displays Centrale du 2e pilier info', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();

      expect(find.textContaining('Centrale'), findsWidgets);
    });

    testWidgets('displays privacy note with nLPD', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();

      expect(find.textContaining('nLPD'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('displays disclaimer after scrolling', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();

      expect(find.byIcon(Icons.info_outline), findsWidgets);
    });

  });

  // ===========================================================================
  // 3. EPL SCREEN
  // ===========================================================================
  //
  // No Provider dependency. Uses EplSimulator from lpp_deep_service.
  // Has Switch for recent buy-back, conditional slider for years since buy-back.
  // Shows impact on risk benefits (invalidity, death).
  // ===========================================================================

  group('EplScreen', () {
    Widget buildScreen() {
      return const MaterialApp(
        home: EplScreen(),
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

      expect(find.text('RETRAIT EPL'), findsOneWidget);
    });

    testWidgets('displays intro card with educational text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.textContaining('Propriete du logement'), findsOneWidget);
      expect(find.textContaining('CHF 20\'000'), findsOneWidget);
    });

    testWidgets('displays parameters section with sliders', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();

      expect(find.text('PARAMETRES'), findsOneWidget);
      expect(find.text('Avoir LPP total'), findsOneWidget);
      expect(find.text('Age'), findsOneWidget);
      expect(find.text('Montant souhaite'), findsOneWidget);
    });

    testWidgets('has 3 Slider widgets (avoir, age, montant)', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();

      // 3 sliders: avoir total, age, montant souhaite
      expect(find.byType(Slider), findsNWidgets(3));
    });

    testWidgets('has Switch for recent buy-back toggle', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();

      expect(find.text('Rachats LPP recents'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('displays result section with amounts', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();

      expect(find.text('RESULTAT'), findsOneWidget);
      expect(find.text('Montant maximum retirable'), findsOneWidget);
      expect(find.text('Montant applicable'), findsOneWidget);
    });

    testWidgets('displays impact on benefits section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pump();

      expect(find.text('IMPACT SUR LES PRESTATIONS'), findsOneWidget);
      expect(find.textContaining('invalidite'), findsWidgets);
      expect(find.textContaining('deces'), findsWidgets);
    });

    testWidgets('displays tax estimation section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();

      expect(find.text('ESTIMATION FISCALE'), findsOneWidget);
      expect(find.textContaining('Impot estime'), findsOneWidget);
      expect(find.textContaining('Montant net'), findsOneWidget);
    });

    testWidgets('displays taux reduit explanation', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();

      expect(find.textContaining('taux reduit'), findsOneWidget);
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

    testWidgets('displays risk impact icons (accessible, heart)', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pump();

      expect(find.byIcon(Icons.accessible), findsOneWidget);
      expect(find.byIcon(Icons.heart_broken_outlined), findsOneWidget);
    });
  });
}
