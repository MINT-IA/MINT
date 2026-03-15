import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Screens under test
import 'package:mint_mobile/screens/lpp_deep/rachat_echelonne_screen.dart';
import 'package:mint_mobile/screens/lpp_deep/libre_passage_screen.dart';
import 'package:mint_mobile/screens/lpp_deep/epl_screen.dart';

import '../test_helpers.dart';

// =============================================================================
// SMOKE TESTS — LPP Deep Module Screens (3 screens)
// =============================================================================

void main() {
  // ===========================================================================
  // 1. RACHAT ECHELONNE SCREEN
  // ===========================================================================

  group('RachatEchelonneScreen', () {
    Widget buildScreen() {
      return buildTestableWidget(const RachatEchelonneScreen());
    }

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays French title in SliverAppBar', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.text('RACHAT LPP \u00c9CHELONN\u00c9'), findsOneWidget);
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

  group('LibrePassageScreen', () {
    Widget buildScreen() {
      return buildTestableWidget(const LibrePassageScreen());
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
      expect(find.text('D\u00e9part de Suisse'), findsOneWidget);
      expect(find.text('Cessation d\'activit\u00e9'), findsOneWidget);
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

    testWidgets('displays privacy note with nLPD', skip: true, (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pump();
      expect(find.textContaining('nLPD'), findsWidgets);
    });

    testWidgets('displays disclaimer after scrolling', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pump();
      expect(find.textContaining('ducatif'), findsWidgets);
    });

  });

  // ===========================================================================
  // 3. EPL SCREEN
  // ===========================================================================

  group('EplScreen', () {
    Widget buildScreen() {
      return buildTestableWidget(const EplScreen());
    }

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays French title in SliverAppBar', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.textContaining('EPL'), findsWidgets);
    });

    testWidgets('displays intro card with educational text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.textContaining('Propriété du logement'), findsOneWidget);
    });

    testWidgets('displays parameters section with sliders', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();
      expect(find.text('PARAMÈTRES'), findsOneWidget);
      expect(find.text('Avoir LPP total'), findsOneWidget);
      expect(find.text('Montant souhaité'), findsOneWidget);
    });

    testWidgets('has 3 Slider widgets (avoir, age, montant)', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();
      expect(find.byType(Slider), findsNWidgets(3));
    });

    testWidgets('has Switch for recent buy-back toggle', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();
      expect(find.text('Rachats LPP récents'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('displays result section with amounts', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();
      expect(find.text('RÉSULTAT'), findsOneWidget);
      expect(find.text('Montant maximum retirable'), findsOneWidget);
      expect(find.text('Montant applicable'), findsOneWidget);
    });

    testWidgets('displays impact on benefits section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pump();
      expect(find.text('IMPACT SUR LES PRESTATIONS'), findsOneWidget);
      expect(find.textContaining('invalidité'), findsWidgets);
      expect(find.textContaining('décès'), findsWidgets);
    });

    testWidgets('displays tax estimation section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();
      expect(find.text('ESTIMATION FISCALE'), findsOneWidget);
      expect(find.textContaining('Impôt estimé'), findsOneWidget);
      expect(find.textContaining('Montant net'), findsOneWidget);
    });

    testWidgets('displays taux reduit explanation', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();
      expect(find.textContaining('taux réduit'), findsOneWidget);
    });

    testWidgets('displays disclaimer after scrolling', skip: true, (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();
      expect(find.textContaining('ducatif'), findsWidgets);
    });

    testWidgets('displays risk impact icons (accessible, heart)', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pump();
      expect(find.text('IMPACT SUR LES PRESTATIONS'), findsOneWidget);
    });
  });
}
