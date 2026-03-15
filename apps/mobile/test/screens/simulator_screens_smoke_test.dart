import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Screens under test
import 'package:mint_mobile/screens/simulator_3a_screen.dart';
import 'package:mint_mobile/screens/simulator_leasing_screen.dart';
import 'package:mint_mobile/screens/simulator_compound_screen.dart';
import 'package:mint_mobile/screens/fiscal_comparator_screen.dart';
import 'package:mint_mobile/screens/gender_gap_screen.dart';

// Dependencies
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/models/profile.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

// =============================================================================
// SMOKE TESTS — Simulator & Comparator Screens
// =============================================================================
//
// Verifies each screen:
//   1. Renders without crash
//   2. Key UI elements are present
//   3. French text is displayed
//   4. Disclaimer is visible (when reachable in the scroll viewport)
//
// Convention: MaterialApp wrapper, minimal Provider when needed.
//
// Note on scrollable screens (FiscalComparatorScreen, GenderGapScreen):
//   These use NestedScrollView / CustomScrollView with slivers. Items below
//   the initial viewport are lazily built and not discoverable by `find.*`
//   without scrolling. Tests for these screens focus on elements visible in
//   the initial viewport and use scrollUntilVisible for deeper elements.
// =============================================================================

void main() {
  // ===========================================================================
  // 1. SIMULATOR 3A SCREEN
  // ===========================================================================
  //
  // Requires ProfileProvider (context.read + context.watch in build).
  // We provide a minimal ProfileProvider with no profile set (hasProfile=false).
  // ===========================================================================

  group('Simulator3aScreen', () {
    Widget buildScreen({Profile? profile}) {
      final provider = ProfileProvider();
      if (profile != null) {
        provider.setProfile(profile);
      }
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ProfileProvider>.value(value: provider),
          ChangeNotifierProvider<CoachProfileProvider>(
            create: (_) => CoachProfileProvider(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: Simulator3aScreen(),
        ),
      );
    }

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays French title in AppBar', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('Optimiseur Pilier 3a'), findsOneWidget);
    });

    testWidgets('displays coach section with French text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('Le conseil du Mentor'), findsOneWidget);
    });

    testWidgets('displays parameter sliders with French labels', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('Versement annuel'), findsOneWidget);
      expect(find.textContaining('imposition'), findsOneWidget);
      // "retraite" appears in both slider label and education section
      expect(find.textContaining('retraite'), findsWidgets);
      expect(find.textContaining('Rendement annuel'), findsOneWidget);
    });

    testWidgets('displays result section with Gain Fiscal', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('Gain Fiscal Annuel'), findsOneWidget);
      expect(find.text('Capital au terme'), findsOneWidget);
    });

    testWidgets('displays disclaimer text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(
        find.textContaining('cantonales'),
        findsOneWidget,
      );
    });

    testWidgets('displays education section with French text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      // Education items (SafeModeGate shows child when hasDebt=false)
      expect(find.textContaining('Bancaire'), findsOneWidget);
      expect(find.textContaining('5 comptes'), findsOneWidget);
    });

    testWidgets('has PDF export button', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
      expect(find.byTooltip('Exporter mon bilan'), findsOneWidget);
    });

    testWidgets('has Slider widgets for input parameters', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byType(Slider), findsNWidgets(4));
    });
  });

  // ===========================================================================
  // 2. SIMULATOR LEASING SCREEN
  // ===========================================================================
  //
  // No Provider dependency. Standalone screen with pure calculator functions.
  // Text uses French accents (e.g. "Mensualite prevue" with accent on e).
  // ===========================================================================

  group('SimulatorLeasingScreen', () {
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
        home: SimulatorLeasingScreen(),
      );
    }

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays French title in AppBar', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('Analyse Anti-Leasing'), findsOneWidget);
    });

    testWidgets('displays coach section with French text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      // "Reflexion du Mentor" — uses accent e
      expect(find.textContaining('Mentor'), findsOneWidget);
      expect(find.textContaining('leasing'), findsWidgets);
    });

    testWidgets('displays input sliders with French labels', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      // "Mensualite prevue" uses accent: "Mensualité prévue"
      expect(find.textContaining('Mensualit'), findsWidgets);
      expect(find.textContaining('leasing'), findsWidgets);
      // "Rendement alternatif espere" uses accent: "Rendement alternatif espéré"
      expect(find.textContaining('Rendement alternatif'), findsOneWidget);
    });

    testWidgets('displays result section with opportunity cost', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      // "Cout d'opportunite" uses accent: "Coût d'opportunité"
      expect(find.textContaining('opportunit'), findsWidgets);
    });

    testWidgets('displays alternatives section in French', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      // "Occasion de Qualite" uses accent: "Occasion de Qualité"
      expect(find.textContaining('Occasion de Qualit'), findsOneWidget);
      expect(find.textContaining('Mobility'), findsOneWidget);
    });

    testWidgets('displays disclaimer text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(
        find.textContaining('analyse vise'),
        findsOneWidget,
      );
    });

    testWidgets('has PDF export button', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
    });

    testWidgets('has three Slider widgets for inputs', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byType(Slider), findsNWidgets(4));
    });
  });

  // ===========================================================================
  // 3. SIMULATOR COMPOUND INTEREST SCREEN
  // ===========================================================================
  //
  // No Provider dependency. Uses InfoTooltip (glossary-backed) in coach section.
  // ===========================================================================

  group('SimulatorCompoundScreen', () {
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
        home: SimulatorCompoundScreen(),
      );
    }

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays French title in AppBar', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      // "Interets Composes" uses accents
      expect(find.textContaining('Compos'), findsOneWidget);
    });

    testWidgets('displays coach section with French text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.textContaining('Mentor'), findsOneWidget);
    });

    testWidgets('displays input sliders with French labels', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.textContaining('Capital'), findsWidgets);
      expect(find.textContaining('mensuelle'), findsOneWidget);
      expect(find.textContaining('Rendement'), findsOneWidget);
      expect(find.textContaining('Horizon'), findsOneWidget);
    });

    testWidgets('displays result section with final value', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.textContaining('Valeur Finale'), findsOneWidget);
    });

    testWidgets('displays education section in French', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.textContaining('Le temps est roi'), findsOneWidget);
      expect(find.textContaining('Discipline'), findsOneWidget);
    });

    testWidgets('displays disclaimer text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(
        find.textContaining('performances'),
        findsOneWidget,
      );
      expect(
        find.textContaining('garantissent'),
        findsOneWidget,
      );
    });

    testWidgets('has PDF export button', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
    });

    testWidgets('has four Slider widgets for inputs', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byType(Slider), findsNWidgets(4));
    });
  });

  // ===========================================================================
  // 4. FISCAL COMPARATOR SCREEN
  // ===========================================================================
  //
  // Uses GoRouter (context.pop), FiscalService, WealthTaxService, CommuneData,
  // GoogleFonts, TabController, TickerProviderStateMixin.
  //
  // CommuneData.load() tries to load an asset file that won't be available in
  // tests, but the screen handles this gracefully (CommuneData.isLoaded stays
  // false). FiscalService and WealthTaxService are static/pure-function
  // services — no mocking needed.
  //
  // Important: This screen uses NestedScrollView with SliverAppBar + TabBarView.
  // The TabBarView contains ListViews. Items further down in each list may not
  // be built until scrolled to. We use scrollUntilVisible where needed.
  // ===========================================================================

  group('FiscalComparatorScreen', () {
    Widget buildScreen() {
      return ChangeNotifierProvider<CoachProfileProvider>(
        create: (_) => CoachProfileProvider(),
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: FiscalComparatorScreen(),
        ),
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

      expect(find.text('Comparateur fiscal'), findsOneWidget);
    });

    testWidgets('displays three tabs with French labels', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('Mon impôt'), findsOneWidget);
      expect(find.text('26 cantons'), findsOneWidget);
      expect(find.text('Déménager'), findsOneWidget);
    });

    testWidgets('displays revenue slider with French label', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('Revenu brut annuel'), findsOneWidget);
    });

    testWidgets('displays civil status toggle in French', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('État civil'), findsOneWidget);
      expect(find.text('Célibataire'), findsOneWidget);
    });

    testWidgets('displays canton dropdown', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('Canton'), findsOneWidget);
    });

    testWidgets('displays children counter label', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('Enfants'), findsOneWidget);
    });

    testWidgets('displays tax breakdown after scrolling', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      // NestedScrollView creates multiple Scrollables. We need to drag the
      // body area to scroll the inner ListView of Tab 1.
      // Drag up (negative dy) on the screen center to scroll content down.
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('DÉCOMPOSITION FISCALE'), findsOneWidget);
      expect(find.text('Impôt fédéral'), findsOneWidget);
    });

    testWidgets('displays effective rate after scrolling', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      // Scroll to reveal the effective rate gauge
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('Taux effectif estimé'), findsOneWidget);
    });

    testWidgets('displays disclaimer after scrolling down', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      // Multiple drags to reach the disclaimer at the bottom of Tab 1
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.textContaining('conseil fiscal'), findsWidgets);
      expect(find.textContaining('spécialiste'), findsWidgets);
    });

    testWidgets('displays fortune and church tax inputs after scrolling',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      // Fortune and church inputs are in the inputs card -- scroll down
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -250));
      await tester.pumpAndSettle();

      expect(find.text('Fortune nette'), findsOneWidget);
      expect(find.textContaining('Église'), findsOneWidget);
    });

    testWidgets('displays national ranking after scrolling', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      // POSITION NATIONALE is after the tax breakdown
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('POSITION NATIONALE'), findsOneWidget);
    });

    testWidgets('has TabBar with 3 tabs', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(Tab), findsNWidgets(3));
    });
  });

  // ===========================================================================
  // 5. GENDER GAP SCREEN
  // ===========================================================================
  //
  // Uses GoRouter (context.pop), GenderGapService (static, pure functions),
  // GoogleFonts. No Provider needed.
  //
  // Uses CustomScrollView with SliverList. Items beyond the initial viewport
  // require scrolling to become visible.
  // ===========================================================================

  group('GenderGapScreen', () {
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
        home: GenderGapScreen(),
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

      expect(find.text('GENDER GAP PR\u00c9VOYANCE'), findsOneWidget);
    });

    testWidgets('displays header with French text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('Lacune de pr\u00e9voyance'), findsOneWidget);
      // "temps partiel" appears in both header subtitle and intro
      expect(find.textContaining('temps partiel'), findsWidgets);
    });

    testWidgets('displays intro about coordination deduction', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.textContaining('coordination'), findsWidgets);
    });

    testWidgets('displays activity rate slider', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.textContaining('activit\u00e9'), findsWidgets);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('displays input parameters section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      // Scroll down to the parameters section
      await tester.scrollUntilVisible(
        find.text('Param\u00e8tres'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Param\u00e8tres'), findsOneWidget);
      expect(find.textContaining('Revenu annuel'), findsOneWidget);
    });

    testWidgets('displays pension comparison results after scrolling',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.scrollUntilVisible(
        find.textContaining('Rente LPP'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.textContaining('Rente LPP'), findsOneWidget);
    });

    testWidgets('displays coordination explanation after scrolling',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.scrollUntilVisible(
        find.textContaining('Comprendre la d\u00e9duction'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.textContaining('Comprendre la d\u00e9duction'), findsOneWidget);
    });

    testWidgets('displays OFS statistic after scrolling', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Statistique OFS'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Statistique OFS'), findsOneWidget);
    });

    testWidgets('displays disclaimer after scrolling', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.scrollUntilVisible(
        find.textContaining('estimations simplifi\u00e9es'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.textContaining('estimations simplifi\u00e9es'), findsOneWidget);
    });

    testWidgets('displays legal sources footer after scrolling',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Sources'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Sources'), findsOneWidget);
      expect(find.textContaining('LPP art.'), findsWidgets);
    });

    testWidgets('displays demo mode indicator after scrolling',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.scrollUntilVisible(
        find.textContaining('Mode d\u00e9mo'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.textContaining('Mode d\u00e9mo'), findsOneWidget);
    });
  });
}
