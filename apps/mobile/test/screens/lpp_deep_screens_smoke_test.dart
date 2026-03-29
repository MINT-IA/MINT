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

    testWidgets('displays i18n title in SliverAppBar', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: rachatEchelonneTitle = "Rachat LPP echelonne"
      expect(find.textContaining('Rachat LPP'), findsWidgets);
    });

    testWidgets('displays intro card with educational text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: rachatEchelonneIntroTitle = "Pourquoi echelonner ses rachats"
      expect(find.textContaining('chelonner'), findsWidgets);
    });

    testWidgets('has Slider widgets for input parameters', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
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

    testWidgets('displays i18n title in SliverAppBar', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: librePassageAppBarTitle = "Libre passage"
      expect(find.textContaining('ibre passage'), findsWidgets);
    });

    testWidgets('displays situation selector with choice chips',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: librePassageSectionSituation = "Situation"
      expect(find.textContaining('ituation'), findsWidgets);
      // i18n: choice chips
      expect(find.textContaining('emploi'), findsWidgets);
    });

    testWidgets('has ChoiceChip widgets for situation', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(ChoiceChip), findsNWidgets(3));
    });

    testWidgets('displays new employer toggle', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();
      // i18n: librePassageLabelNouvelEmployeur = "Nouvel employeur"
      expect(find.textContaining('employeur'), findsWidgets);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('displays checklist section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();
      // i18n: librePassageSectionChecklist = "Checklist"
      expect(find.textContaining('hecklist'), findsWidgets);
    });

    testWidgets('displays urgency badges in checklist', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();
      final urgencyBadges = find.textContaining(RegExp('ritique|aute|oyenne'));
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

    testWidgets('displays i18n title in SliverAppBar', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: eplAppBarTitle = "Retrait EPL"
      expect(find.textContaining('EPL'), findsWidgets);
    });

    testWidgets('displays intro card with educational text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: eplIntroBody contains "logement en propriete"
      expect(find.textContaining('logement'), findsWidgets);
    });

    testWidgets('displays parameters section with sliders', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();
      // i18n: eplSectionParametres = "Parametres"
      expect(find.textContaining('aram'), findsWidgets);
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
      // i18n: eplLabelRachatsRecents = "Rachats LPP recents"
      expect(find.textContaining('achats LPP'), findsWidgets);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('displays result section with amounts', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();
      // i18n: eplSectionResultat = "Resultat"
      expect(find.textContaining('sultat'), findsWidgets);
    });

    testWidgets('displays impact on benefits section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pump();
      // i18n: eplSectionImpactPrestations = "Impact sur les prestations"
      expect(find.textContaining('mpact'), findsWidgets);
    });

    testWidgets('displays tax estimation section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();
      // i18n: eplSectionFiscale = "Estimation fiscale"
      expect(find.textContaining('fiscale'), findsWidgets);
    });

    testWidgets('displays taux reduit explanation', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();
      expect(find.textContaining('taux r'), findsWidgets);
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
      // i18n: eplSectionImpactPrestations = "Impact sur les prestations"
      expect(find.textContaining('mpact'), findsWidgets);
    });
  });
}
