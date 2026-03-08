// ────────────────────────────────────────────────────────────
//  LIFE EVENT SCREENS V2 — Smoke Tests
//  Sprint S22+ screens: Mariage, Naissance, Concubinage,
//  Donation, Housing Sale
//
//  Validates: renders without crash, tabs present, French
//  content, disclaimer/sources visible.
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/screens/mariage_screen.dart';
import 'package:mint_mobile/screens/naissance_screen.dart';
import 'package:mint_mobile/screens/concubinage_screen.dart';
import 'package:mint_mobile/screens/donation_screen.dart';
import 'package:mint_mobile/screens/housing_sale_screen.dart';

void main() {
  // ═══════════════════════════════════════════════════════════
  //  1. MariageScreen — S22, 4 tabs
  // ═══════════════════════════════════════════════════════════

  group('MariageScreen', () {
    Widget buildMariageScreen() {
      return const MaterialApp(
        home: MariageScreen(),
      );
    }

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildMariageScreen());
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays screen title in French', (tester) async {
      await tester.pumpWidget(buildMariageScreen());
      await tester.pumpAndSettle();
      expect(find.text('Mariage & fiscalite'), findsOneWidget);
    });

    testWidgets('all 4 tabs are present', (tester) async {
      await tester.pumpWidget(buildMariageScreen());
      await tester.pumpAndSettle();
      expect(find.text('Impots'), findsOneWidget);
      expect(find.text('Regime'), findsOneWidget);
      expect(find.text('Protection'), findsOneWidget);
      expect(find.text('Checklist'), findsOneWidget);
    });

    testWidgets('Tab 1 (Impots) shows fiscal content', (tester) async {
      await tester.pumpWidget(buildMariageScreen());
      await tester.pumpAndSettle();
      // Default tab is Impots — should show revenue sliders and comparison
      expect(find.text('Revenu 1'), findsOneWidget);
      expect(find.text('Revenu 2'), findsOneWidget);
      expect(find.text('Canton'), findsOneWidget);
      expect(find.text('Enfants'), findsOneWidget);
    });

    testWidgets('Tab 1 (Impots) has disclaimer after scrolling',
        (tester) async {
      await tester.pumpWidget(buildMariageScreen());
      await tester.pumpAndSettle();
      // Disclaimer is at the bottom of a long ListView inside a
      // NestedScrollView. We need to scroll within the inner scrollable
      // to make it visible.
      final listFinder = find.byType(Scrollable).last;
      await tester.scrollUntilVisible(
        find.textContaining('ne constitue pas'),
        200,
        scrollable: listFinder,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('ne constitue pas'), findsWidgets);
    });

    testWidgets('Tab 1 (Impots) shows fiscal comparison card',
        (tester) async {
      await tester.pumpWidget(buildMariageScreen());
      await tester.pumpAndSettle();
      expect(find.text('COMPARAISON FISCALE'), findsOneWidget);
    });

    testWidgets('Tab 2 (Regime) renders without crash', (tester) async {
      await tester.pumpWidget(buildMariageScreen());
      await tester.pumpAndSettle();
      // Tap Regime tab
      await tester.tap(find.text('Regime'));
      await tester.pumpAndSettle();
      expect(find.text('REGIME MATRIMONIAL'), findsOneWidget);
      expect(find.text('Participation aux acquets'), findsOneWidget);
      expect(find.text('Separation de biens'), findsOneWidget);
      expect(find.text('Communaute de biens'), findsOneWidget);
    });

    testWidgets('Tab 3 (Protection) renders without crash', (tester) async {
      await tester.pumpWidget(buildMariageScreen());
      await tester.pumpAndSettle();
      // Tap Protection tab
      await tester.tap(find.text('Protection'));
      await tester.pumpAndSettle();
      // Check for content that should be visible at the top of the tab
      expect(
        find.textContaining('Que se passe-t-il', skipOffstage: false),
        findsWidgets,
      );
    });

    testWidgets('Tab 4 (Checklist) renders without crash', (tester) async {
      await tester.pumpWidget(buildMariageScreen());
      await tester.pumpAndSettle();
      // Tap Checklist tab
      await tester.tap(find.text('Checklist'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('demarches', skipOffstage: false),
        findsWidgets,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  2. NaissanceScreen — S22, 4 tabs
  // ═══════════════════════════════════════════════════════════

  group('NaissanceScreen', () {
    Widget buildNaissanceScreen() {
      return const MaterialApp(
        home: NaissanceScreen(),
      );
    }

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildNaissanceScreen());
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays screen title in French', (tester) async {
      await tester.pumpWidget(buildNaissanceScreen());
      await tester.pumpAndSettle();
      expect(find.text('Naissance & famille'), findsOneWidget);
    });

    testWidgets('all 4 tabs are present', (tester) async {
      await tester.pumpWidget(buildNaissanceScreen());
      await tester.pumpAndSettle();
      expect(find.text('Conge'), findsOneWidget);
      expect(find.text('Allocations'), findsOneWidget);
      expect(find.text('Impact'), findsOneWidget);
      expect(find.text('Checklist'), findsOneWidget);
    });

    testWidgets('Tab 1 (Conge) shows parental leave content', (tester) async {
      await tester.pumpWidget(buildNaissanceScreen());
      await tester.pumpAndSettle();
      // Default tab is Conge — should show salary slider and type toggle
      expect(find.text('Type de conge'), findsOneWidget);
      expect(find.text('Salaire mensuel brut'), findsOneWidget);
    });

    testWidgets('Tab 1 (Conge) shows Mere/Pere toggle', (tester) async {
      await tester.pumpWidget(buildNaissanceScreen());
      await tester.pumpAndSettle();
      expect(find.text('Mere'), findsOneWidget);
      expect(find.text('Pere'), findsOneWidget);
    });

    testWidgets('Tab 1 (Conge) has disclaimer after scrolling',
        (tester) async {
      await tester.pumpWidget(buildNaissanceScreen());
      await tester.pumpAndSettle();
      // Drag Tab 1 ListView to the bottom to force-build the lazy disclaimer.
      // scrollUntilVisible requires a unique finder; drag is safer here because
      // the screen has multiple 'ne constitue pas' instances.
      final listFinder = find.byType(ListView).first;
      await tester.drag(listFinder, const Offset(0, -5000));
      await tester.pumpAndSettle();
      expect(find.textContaining('ne constitue pas'), findsWidgets);
    });

    testWidgets('Tab 2 (Allocations) renders without crash', (tester) async {
      await tester.pumpWidget(buildNaissanceScreen());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allocations'));
      await tester.pumpAndSettle();
      // Canton selector should be visible at the top of the Allocations tab
      expect(
        find.text('Canton', skipOffstage: false),
        findsWidgets,
      );
    });

    testWidgets('Tab 3 (Impact) renders without crash', (tester) async {
      await tester.pumpWidget(buildNaissanceScreen());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Impact'));
      await tester.pumpAndSettle();
      expect(
        find.text('Revenu annuel brut', skipOffstage: false),
        findsWidgets,
      );
    });

    testWidgets('Tab 4 (Checklist) renders without crash', (tester) async {
      await tester.pumpWidget(buildNaissanceScreen());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Checklist'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('demarches', skipOffstage: false),
        findsWidgets,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  3. ConcubinageScreen — S22, 2 tabs
  // ═══════════════════════════════════════════════════════════

  group('ConcubinageScreen', () {
    Widget buildConcubinageScreen() {
      return const MaterialApp(
        home: ConcubinageScreen(),
      );
    }

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildConcubinageScreen());
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays screen title in French', (tester) async {
      await tester.pumpWidget(buildConcubinageScreen());
      await tester.pumpAndSettle();
      expect(find.text('Mariage vs Concubinage'), findsOneWidget);
    });

    testWidgets('both tabs are present', (tester) async {
      await tester.pumpWidget(buildConcubinageScreen());
      await tester.pumpAndSettle();
      expect(find.text('Comparateur'), findsOneWidget);
      expect(find.text('Checklist'), findsOneWidget);
    });

    testWidgets('Tab 1 (Comparateur) shows decision matrix', (tester) async {
      await tester.pumpWidget(buildConcubinageScreen());
      await tester.pumpAndSettle();
      expect(find.text('MATRICE DE DECISION'), findsOneWidget);
      expect(find.text('Mariage'), findsWidgets);
      expect(find.text('Concubinage'), findsWidgets);
    });

    testWidgets('Tab 1 (Comparateur) shows input sliders', (tester) async {
      await tester.pumpWidget(buildConcubinageScreen());
      await tester.pumpAndSettle();
      expect(find.text('Revenu 1'), findsOneWidget);
      expect(find.text('Revenu 2'), findsOneWidget);
      expect(find.text('Patrimoine total'), findsOneWidget);
    });

    testWidgets('Tab 1 (Comparateur) has disclaimer after scrolling',
        (tester) async {
      await tester.pumpWidget(buildConcubinageScreen());
      await tester.pumpAndSettle();
      // Disclaimer is at the bottom of a long ListView inside a
      // NestedScrollView. We need to scroll within the inner scrollable
      // to make it visible.
      final listFinder = find.byType(Scrollable).last;
      await tester.scrollUntilVisible(
        find.textContaining('ne constitue pas'),
        200,
        scrollable: listFinder,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('ne constitue pas'), findsWidgets);
    });

    testWidgets('Tab 1 (Comparateur) shows neutral conclusion after scrolling',
        (tester) async {
      await tester.pumpWidget(buildConcubinageScreen());
      await tester.pumpAndSettle();
      // The neutral conclusion is deep in a ListView inside a
      // NestedScrollView — scroll to bring it into view.
      final listFinder = find.byType(Scrollable).last;
      await tester.scrollUntilVisible(
        find.textContaining('Aucune option'),
        200,
        scrollable: listFinder,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Aucune option'), findsOneWidget);
    });

    testWidgets('Tab 2 (Checklist) renders without crash', (tester) async {
      await tester.pumpWidget(buildConcubinageScreen());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Checklist'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('protections', skipOffstage: false),
        findsWidgets,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  4. DonationScreen — S24, single scroll (no tabs)
  // ═══════════════════════════════════════════════════════════

  group('DonationScreen', () {
    Widget buildDonationScreen() {
      return const MaterialApp(
        home: DonationScreen(),
      );
    }

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildDonationScreen());
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays screen title', (tester) async {
      await tester.pumpWidget(buildDonationScreen());
      await tester.pumpAndSettle();
      // AppBar title
      expect(find.textContaining('Donation'), findsWidgets);
    });

    testWidgets('shows header with French content', (tester) async {
      await tester.pumpWidget(buildDonationScreen());
      await tester.pumpAndSettle();
      expect(find.text('Simuler une donation'), findsOneWidget);
    });

    testWidgets('shows intro educational text', (tester) async {
      await tester.pumpWidget(buildDonationScreen());
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Les donations en Suisse'),
        findsOneWidget,
      );
    });

    testWidgets('shows donation input section', (tester) async {
      await tester.pumpWidget(buildDonationScreen());
      await tester.pumpAndSettle();
      expect(find.text('DONATION'), findsOneWidget);
      expect(find.text('Montant de la donation'), findsOneWidget);
      expect(find.text('Lien de parente'), findsOneWidget);
    });

    testWidgets('shows succession context section', (tester) async {
      await tester.pumpWidget(buildDonationScreen());
      await tester.pumpAndSettle();
      // CONTEXTE SUCCESSORAL may be off-screen in a long scroll
      expect(
        find.text('CONTEXTE SUCCESSORAL', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('has Calculer button in widget tree', (tester) async {
      await tester.pumpWidget(buildDonationScreen());
      await tester.pumpAndSettle();
      expect(
        find.text('Calculer', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('has disclaimer after scrolling', (tester) async {
      await tester.pumpWidget(buildDonationScreen());
      await tester.pumpAndSettle();
      // Disclaimer may be at bottom of a long scroll — scroll to it
      await tester.scrollUntilVisible(
        find.textContaining('ne constitue pas'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('ne constitue pas'), findsWidgets);
    });

    testWidgets('has educational footer in widget tree', (tester) async {
      await tester.pumpWidget(buildDonationScreen());
      await tester.pumpAndSettle();
      expect(
        find.text('COMPRENDRE', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('shows lien parente chips', (tester) async {
      await tester.pumpWidget(buildDonationScreen());
      await tester.pumpAndSettle();
      expect(find.text('Conjoint(e)'), findsOneWidget);
      expect(find.text('Enfant / Descendant(e)'), findsOneWidget);
    });

    testWidgets('tapping Calculer produces results without crash',
        (tester) async {
      await tester.pumpWidget(buildDonationScreen());
      await tester.pumpAndSettle();

      // Scroll down to make Calculer button visible, then tap
      await tester.scrollUntilVisible(
        find.text('Calculer'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calculer'));
      await tester.pumpAndSettle();

      // After calculation, result cards should appear in widget tree
      expect(
        find.text('IMPOT SUR LA DONATION', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.textContaining('RESERVE HEREDITAIRE', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('QUOTITE DISPONIBLE', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('IMPACT SUR LA SUCCESSION', skipOffstage: false),
        findsOneWidget,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  5. HousingSaleScreen — S24, single scroll (no tabs)
  // ═══════════════════════════════════════════════════════════

  group('HousingSaleScreen', () {
    Widget buildHousingSaleScreen() {
      return const MaterialApp(
        home: HousingSaleScreen(),
      );
    }

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildHousingSaleScreen());
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays screen title', (tester) async {
      await tester.pumpWidget(buildHousingSaleScreen());
      await tester.pumpAndSettle();
      expect(find.text('Vente immobiliere'), findsOneWidget);
    });

    testWidgets('shows header with French content', (tester) async {
      await tester.pumpWidget(buildHousingSaleScreen());
      await tester.pumpAndSettle();
      expect(find.text('Simuler ta vente immobiliere'), findsOneWidget);
    });

    testWidgets('shows intro educational text', (tester) async {
      await tester.pumpWidget(buildHousingSaleScreen());
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Vendre un bien immobilier'),
        findsOneWidget,
      );
    });

    testWidgets('shows bien immobilier section', (tester) async {
      await tester.pumpWidget(buildHousingSaleScreen());
      await tester.pumpAndSettle();
      expect(find.text('BIEN IMMOBILIER'), findsOneWidget);
      expect(find.text('Prix d\'achat'), findsOneWidget);
      expect(find.text('Prix de vente'), findsOneWidget);
    });

    testWidgets('has financement section in widget tree', (tester) async {
      await tester.pumpWidget(buildHousingSaleScreen());
      await tester.pumpAndSettle();
      expect(
        find.text('FINANCEMENT', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('has EPL section in widget tree', (tester) async {
      await tester.pumpWidget(buildHousingSaleScreen());
      await tester.pumpAndSettle();
      expect(
        find.textContaining('EPL', skipOffstage: false),
        findsWidgets,
      );
    });

    testWidgets('has remploi section in widget tree', (tester) async {
      await tester.pumpWidget(buildHousingSaleScreen());
      await tester.pumpAndSettle();
      expect(
        find.text('REMPLOI', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('has Calculer button in widget tree', (tester) async {
      await tester.pumpWidget(buildHousingSaleScreen());
      await tester.pumpAndSettle();
      expect(
        find.text('Calculer', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('has disclaimer after scrolling', (tester) async {
      await tester.pumpWidget(buildHousingSaleScreen());
      await tester.pumpAndSettle();
      // Disclaimer may be at bottom of a long scroll — scroll to it
      await tester.scrollUntilVisible(
        find.textContaining('ne constitue pas'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('ne constitue pas'), findsWidgets);
    });

    testWidgets('has educational footer in widget tree', (tester) async {
      await tester.pumpWidget(buildHousingSaleScreen());
      await tester.pumpAndSettle();
      expect(
        find.text('COMPRENDRE', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('tapping Calculer produces results without crash',
        (tester) async {
      await tester.pumpWidget(buildHousingSaleScreen());
      await tester.pumpAndSettle();

      // Scroll down to make Calculer button visible, then tap
      await tester.scrollUntilVisible(
        find.text('Calculer'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calculer'));
      await tester.pumpAndSettle();

      // After calculation, result cards should appear in widget tree
      expect(
        find.text('PLUS-VALUE IMMOBILIERE', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('PRODUIT NET DE LA VENTE', skipOffstage: false),
        findsOneWidget,
      );
    });
  });
}
