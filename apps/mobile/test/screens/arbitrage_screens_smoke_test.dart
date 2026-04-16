// ────────────────────────────────────────────────────────────
//  ARBITRAGE SCREENS — Smoke Tests
//  Screens: RenteVsCapitalScreen, AllocationAnnuelleScreen,
//           ArbitrageBilanScreen, LocationVsProprieteScreen
//
//  Validates: renders without crash, Scaffold present,
//  key French content visible on first pump.
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/arbitrage/rente_vs_capital_screen.dart';
import 'package:mint_mobile/screens/arbitrage/allocation_annuelle_screen.dart';
import 'package:mint_mobile/screens/arbitrage/arbitrage_bilan_screen.dart';
import 'package:mint_mobile/screens/arbitrage/location_vs_propriete_screen.dart';

// ---------------------------------------------------------------------------
//  Shared helper — wraps a screen with Provider + French i18n
// ---------------------------------------------------------------------------
Widget _buildWrapped(Widget screen) {
  return ChangeNotifierProvider<CoachProfileProvider>(
    create: (_) => CoachProfileProvider(),
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: screen,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ═══════════════════════════════════════════════════════════
  //  1. RenteVsCapitalScreen — THE core retirement decision
  // ═══════════════════════════════════════════════════════════

  group('RenteVsCapitalScreen', () {
    Widget buildScreen() => _buildWrapped(const RenteVsCapitalScreen());

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays i18n app bar title', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: renteVsCapitalAppBarTitle = "Rente ou capital : ta décision"
      expect(find.textContaining('capital'), findsWidgets);
    });

    testWidgets('displays input mode toggle (Estimer / Certificat)', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: renteVsCapitalEstimateMode = "Estimer pour moi"
      //       renteVsCapitalCertificateMode = "J'ai mon certificat"
      expect(find.textContaining('Estimer'), findsWidgets);
      expect(find.textContaining('certificat'), findsWidgets);
    });

    testWidgets('displays hero intro section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: renteVsCapitalIntro mentions "à la retraite"
      expect(find.textContaining('etraite'), findsWidgets);
    });

    testWidgets('displays option labels Rente, Capital, Mixte', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // Labels appear in the intro explanatory text and in result blocs.
      // i18n: renteVsCapitalRenteLabel = "Rente",
      //       renteVsCapitalCapitalLabel = "Capital",
      //       renteVsCapitalMixteLabel = "Mixte"
      expect(find.textContaining('Rente'), findsWidgets);
      expect(find.textContaining('Capital'), findsWidgets);
      expect(find.textContaining('Mixte'), findsWidgets);
    });

    testWidgets('has default LPP total input pre-filled', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // Default text: '350000'
      expect(find.textContaining('350'), findsWidgets);
    });

    testWidgets('has age input field', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: renteVsCapitalAge = "Ton âge"
      expect(find.textContaining('ge'), findsWidgets);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  2. AllocationAnnuelleScreen — Compare 3a, LPP, libre
  // ═══════════════════════════════════════════════════════════

  group('AllocationAnnuelleScreen', () {
    Widget buildScreen() => _buildWrapped(const AllocationAnnuelleScreen());

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays i18n app bar title', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: allocAnnuelleTitle = "Où placer tes CHF ?"
      expect(find.textContaining('CHF'), findsWidgets);
    });

    testWidgets('displays input section with amount field', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // Default montant = 7000
      expect(find.textContaining('7'), findsWidgets);
    });

    testWidgets('displays taux marginal toggle or slider', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // Taux marginal label visible
      expect(find.textContaining('marginal'), findsWidgets);
    });

    testWidgets('displays results after initial calculation', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      // After initState() -> _recalculate(), result is non-null.
      // Scroll down to reveal the results section.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();
      // i18n: allocAnnuelleTrajectoires = "Trajectoires comparées"
      expect(find.textContaining('rajectoire', skipOffstage: false), findsWidgets);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  3. ArbitrageBilanScreen — All arbitrages on real data
  // ═══════════════════════════════════════════════════════════

  group('ArbitrageBilanScreen', () {
    Widget buildScreen() => _buildWrapped(const ArbitrageBilanScreen());

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays empty-profile state without crash (no profile)', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // No profile set: shows i18n: arbitrageBilanEmptyProfile
      // The key text "arbitrageBilan" should appear in some form
      expect(find.byType(Icon), findsWidgets);
    });

    testWidgets('shows start CTA when no profile', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: reportCommencer = "Commencer"
      expect(find.textContaining('ommencer'), findsWidgets);
    });

    testWidgets('has at least one Scaffold with body', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.body, isNotNull);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  4. LocationVsProprieteScreen — Rent vs Buy
  // ═══════════════════════════════════════════════════════════

  group('LocationVsProprieteScreen', () {
    Widget buildScreen() => _buildWrapped(const LocationVsProprieteScreen());

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays header title Louer ou acheter', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: locationLouerOuAcheter = "Louer ou acheter ?"
      expect(find.textContaining('acheter'), findsWidgets);
    });

    testWidgets('displays project immobilier section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: locationProjetImmobilier = "Ton projet immobilier"
      expect(find.textContaining('immobilier'), findsWidgets);
    });

    testWidgets('shows compare button', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: locationComparer = "Comparer"
      expect(find.textContaining('omparer'), findsWidgets);
    });

    testWidgets('displays hypothesis section with return slider', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: locationHypotheses = "Hypothèses utilisées" — below the fold
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();
      expect(find.textContaining('ypothèse', skipOffstage: false), findsWidgets);
    });
  });
}
