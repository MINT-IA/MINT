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
// Post-S52: screens use i18n with sentence-case titles.
// =============================================================================

void main() {
  // ===========================================================================
  // 1. SIMULATOR 3A SCREEN
  // ===========================================================================

  group('Simulator3aScreen', () {
    Widget buildScreen({Profile? profile, CoachProfileProvider? coach}) {
      final provider = ProfileProvider();
      if (profile != null) {
        provider.setProfile(profile);
      }
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ProfileProvider>.value(value: provider),
          ChangeNotifierProvider<CoachProfileProvider>.value(
            value: coach ?? CoachProfileProvider(),
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

    testWidgets('displays i18n title in AppBar', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: sim3aTitle = "Ton 3e pilier"
      expect(find.textContaining('3e pilier'), findsWidgets);
    });

    testWidgets('displays coach section with French text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: sim3aCoachTitle = "Le conseil du Mentor"
      expect(find.textContaining('Mentor'), findsWidgets);
    });

    testWidgets('displays parameter inputs with French labels', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: sim3aContributionFieldLabel = "Cotisation annuelle"
      expect(find.textContaining('otisation'), findsWidgets);
      expect(find.textContaining('imposition'), findsWidgets);
      expect(find.textContaining('retraite'), findsWidgets);
    });

    testWidgets('displays result section with estimated tax impact',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: sim3aAnnualTaxSaved = "Impact fiscal estimé"
      expect(find.textContaining('mpact fiscal'), findsWidgets);
      // i18n: sim3aFinalCapital = "Capital au terme"
      expect(find.textContaining('apital au terme'), findsWidgets);
    });

    testWidgets('uses estimate-first language for 3a impact', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('Impact fiscal estimé'), findsWidgets);
      expect(find.text('Gain fiscal annuel'), findsNothing);
      expect(find.text('Stratégie gagnante'), findsNothing);
    });

    testWidgets('displays disclaimer text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: sim3aDisclaimer contains "ducative" or "LSFin"
      expect(find.textContaining('ducative'), findsWidgets);
    });

    testWidgets('displays education section with French text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: sim3aStratBankTitle = "Bancaire > Assurance"
      expect(find.textContaining('Bancaire'), findsOneWidget);
      // i18n: sim3aStrat5AccountsTitle = "La regle des 5 comptes"
      expect(find.textContaining('5 comptes'), findsOneWidget);
    });

    testWidgets('has modern inputs (chips + text field) for parameters',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // Sliders replaced: tax rate chips + return rate chips + contribution text field
      expect(find.byType(ChoiceChip), findsWidgets);
      expect(find.byType(TextField), findsWidgets);
    });

    // SALVAGE-01-02 / def-02: a CoachProfile with birthYear==0 (sentinel,
    // unknown age) must NOT pre-fill a fabricated 45yr horizon. The screen
    // renders without crash and the "profile pre-filled" indicator is NOT
    // shown (years stays editable / prompted, not projected).
    testWidgets('no-age profile (birthYear==0) does not pre-fill a horizon',
        (tester) async {
      final coach = CoachProfileProvider();
      // Minimal answers WITHOUT q_birth_year -> birthYear==0 sentinel,
      // so anneesAvantRetraite returns null and the pre-fill is skipped.
      coach.updateFromAnswers(<String, dynamic>{
        'q_canton': 'VD',
        'q_monthly_gross': 6000,
      });
      await tester.pumpWidget(buildScreen(coach: coach));
      await tester.pump();
      // Did not crash on null.clamp.
      expect(find.byType(Scaffold), findsOneWidget);
      // The "Prérempli depuis ton profil" success indicator must be absent
      // because no horizon was derived from an unknown age (def-02 skip,
      // not a fabricated 45yr projection).
      expect(find.textContaining('Prérempli'), findsNothing);
    });

    testWidgets('valid-age profile pre-fills horizon from real age',
        (tester) async {
      final coach = CoachProfileProvider();
      coach.updateFromAnswers(<String, dynamic>{
        'q_birth_year': DateTime.now().year - 34,
        'q_canton': 'VD',
        'q_net_income_period_chf': 7000,
      });

      await tester.pumpWidget(buildScreen(coach: coach));
      await tester.pump();

      expect(find.textContaining('Prérempli'), findsWidgets);
      expect(find.textContaining('31 ans'), findsWidgets);
      expect(find.textContaining('30 ans'), findsNothing);
    });
  });

  // ===========================================================================
  // 2. SIMULATOR LEASING SCREEN
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

    testWidgets('displays i18n title in AppBar', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: leasingTitle = "Analyse Anti-Leasing"
      expect(find.textContaining('easing'), findsWidgets);
    });

    testWidgets('displays coach section with French text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.textContaining('Mentor'), findsOneWidget);
      expect(find.textContaining('leasing'), findsWidgets);
    });

    testWidgets('displays input sliders with French labels', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.textContaining('Mensualit'), findsWidgets);
      expect(find.textContaining('leasing'), findsWidgets);
    });

    testWidgets('displays result section with opportunity cost',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.textContaining('opportunit'), findsWidgets);
    });

    testWidgets('displays alternatives section in French', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.textContaining('Occasion de Qualit'), findsOneWidget);
      expect(find.textContaining('Mobility'), findsOneWidget);
    });

    testWidgets('displays disclaimer text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.textContaining('analyse vise'), findsOneWidget);
    });

    testWidgets('has Slider widgets for inputs', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(Slider), findsNWidgets(4));
    });
  });

  // ===========================================================================
  // 3. SIMULATOR COMPOUND INTEREST SCREEN
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
      expect(find.textContaining('performances'), findsOneWidget);
      expect(find.textContaining('assurance de résultat'), findsOneWidget);
    });

    testWidgets('keeps the primary simulator surface to three visible inputs',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byType(Slider), findsNWidgets(3));

      await tester.scrollUntilVisible(
        find.textContaining('Rendement').first,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.textContaining('Rendement').first);
      await tester.pumpAndSettle();

      expect(find.byType(Slider), findsNWidgets(4));
    });
  });

  // ===========================================================================
  // 4. FISCAL COMPARATOR SCREEN
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
      expect(find.textContaining('imp'), findsWidgets);
      expect(find.textContaining('26 cantons'), findsOneWidget);
      expect(find.textContaining('nager'), findsWidgets);
    });

    testWidgets('displays revenue slider with French label', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.textContaining('Revenu'), findsWidgets);
    });

    testWidgets('displays civil status toggle in French', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.textContaining('tat civil'), findsWidgets);
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
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.textContaining('OMPOSITION FISCALE'), findsOneWidget);
    });

    testWidgets('displays effective rate after scrolling', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.textContaining('aux effectif'), findsWidgets);
    });

    testWidgets('displays disclaimer after scrolling down', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.textContaining('conseil fiscal'), findsWidgets);
    });

    testWidgets('displays fortune and church tax inputs after scrolling',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(find.textContaining('ortune'), findsWidgets);
    });

    testWidgets('displays national ranking after scrolling', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.textContaining('OSITION NATIONALE'), findsOneWidget);
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

    testWidgets('displays i18n title', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: genderGapAppBarTitle = "Lacune de prevoyance"
      expect(find.textContaining('acune'), findsWidgets);
    });

    testWidgets('displays header with French text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: genderGapHeaderTitle = "Lacune de prevoyance"
      expect(find.textContaining('acune'), findsWidgets);
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
      // i18n: genderGapTauxActivite = "Taux d'activite"
      expect(find.textContaining('activit'), findsWidgets);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('displays input parameters section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.scrollUntilVisible(
        find.textContaining('aram'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('aram'), findsWidgets);
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
        find.textContaining('omprendre la d'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('omprendre la d'), findsOneWidget);
    });

    testWidgets('displays OFS statistic after scrolling', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // GenderGapScreen uses SingleChildScrollView — scroll to OFS section
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -1000));
      await tester.pump();
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -500));
      await tester.pump();
      expect(find.textContaining('OFS'), findsWidgets);
    });

    testWidgets('displays disclaimer after scrolling', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.scrollUntilVisible(
        find.textContaining('stimations'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('stimations'), findsOneWidget);
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

    testWidgets('displays demo mode indicator after scrolling', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.scrollUntilVisible(
        find.textContaining('ode d'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('ode d'), findsWidgets);
    });
  });
}
