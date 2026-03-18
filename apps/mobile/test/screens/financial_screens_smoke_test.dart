import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Mortgage suite
import 'package:mint_mobile/screens/mortgage/affordability_screen.dart';
import 'package:mint_mobile/screens/mortgage/saron_vs_fixed_screen.dart';
import 'package:mint_mobile/screens/mortgage/amortization_screen.dart';

// Independants suite
import 'package:mint_mobile/screens/independants/avs_cotisations_screen.dart';
import 'package:mint_mobile/screens/independants/dividende_vs_salaire_screen.dart';
import 'package:mint_mobile/screens/independants/ijm_screen.dart';

// Debt prevention
import 'package:mint_mobile/screens/debt_prevention/repayment_screen.dart';
import 'package:mint_mobile/screens/debt_prevention/debt_ratio_screen.dart';
import 'package:mint_mobile/screens/debt_prevention/help_resources_screen.dart';

// LPP Deep
import 'package:mint_mobile/screens/lpp_deep/rachat_echelonne_screen.dart';
import 'package:mint_mobile/screens/lpp_deep/libre_passage_screen.dart';

// Insurance
import 'package:mint_mobile/screens/lamal_franchise_screen.dart';
import 'package:mint_mobile/screens/coverage_check_screen.dart';

// Disability gap
import 'package:mint_mobile/screens/disability/disability_gap_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import '../test_helpers.dart';

void main() {
  // =========================================================================
  // MORTGAGE SUITE
  // =========================================================================

  group('Mortgage screens', () {
    testWidgets('AffordabilityScreen renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: AffordabilityScreen(),
        ),
      );
      await tester.pump();

      // Title in SliverAppBar
      expect(find.text("CAPACITÉ D'ACHAT"), findsOneWidget);
      // Sections present (i18n: PARAMÈTRES has accent; may be offstage in sliver)
      expect(find.textContaining('INDICATEURS', skipOffstage: false), findsOneWidget);
      expect(find.textContaining('PARAMÈTRES', skipOffstage: false), findsOneWidget);
    });

    testWidgets('SaronVsFixedScreen renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: SaronVsFixedScreen(),
        ),
      );
      await tester.pump();

      // Title in SliverAppBar
      expect(find.text('SARON VS FIXE'), findsOneWidget);
      // Check widget tree builds (Slider controls exist offstage)
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('AmortizationScreen renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: AmortizationScreen(),
        ),
      );
      await tester.pump();

      // Title in SliverAppBar
      expect(find.text('DIRECT VS INDIRECT'), findsOneWidget);
      // Intro text
      expect(
        find.textContaining('Amortissement : direct ou indirect'),
        findsOneWidget,
      );
    });
  });

  // =========================================================================
  // INDEPENDANTS SUITE
  // =========================================================================

  group('Independants screens', () {
    testWidgets('AvsCotisationsScreen renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: AvsCotisationsScreen(),
        ),
      );
      await tester.pump();

      // Title in SliverAppBar
      expect(find.text('Cotisations AVS'), findsOneWidget);
      // Slider label
      expect(find.textContaining('Ton revenu net annuel'), findsOneWidget);
    });

    testWidgets('DividendeVsSalaireScreen renders without error',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: DividendeVsSalaireScreen(),
        ),
      );
      await tester.pump();

      // Title in SliverAppBar
      expect(find.text('Dividende vs Salaire'), findsOneWidget);
      // Slider label
      expect(find.textContaining('Bénéfice total'), findsOneWidget);
    });

    testWidgets('IjmScreen renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: IjmScreen(),
        ),
      );
      await tester.pump();

      // Title in SliverAppBar
      expect(find.text('Assurance IJM'), findsOneWidget);
      // Carence toggle section
      expect(find.textContaining('Délai de carence'), findsOneWidget);
    });
  });

  // =========================================================================
  // DEBT PREVENTION SUITE
  // =========================================================================

  group('Debt prevention screens', () {
    testWidgets('RepaymentScreen renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: RepaymentScreen(),
        ),
      );
      await tester.pump();

      // Title in SliverAppBar
      expect(find.text('PLAN DE REMBOURSEMENT'), findsOneWidget);
      // Smoke: scaffold rendered successfully
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('DebtRatioScreen renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: DebtRatioScreen(),
        ),
      );
      await tester.pump();

      // Title in SliverAppBar
      expect(find.text('DIAGNOSTIC DETTE'), findsOneWidget);
      // Gauge label
      expect(find.textContaining('Ratio dette'), findsOneWidget);
    });

    testWidgets('HelpResourcesScreen renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: HelpResourcesScreen(),
        ),
      );
      await tester.pump();

      // Title in SliverAppBar
      expect(find.text('AIDE EN CAS DE DETTE'), findsOneWidget);
      // Intro text
      expect(find.textContaining('Vous n\'êtes pas seul'), findsOneWidget);
    });
  });

  // =========================================================================
  // LPP DEEP SUITE
  // =========================================================================

  group('LPP Deep screens', () {
    testWidgets('RachatEchelonneScreen renders without error', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const RachatEchelonneScreen()),
      );
      await tester.pump();

      // Title in SliverAppBar
      expect(find.text('RACHAT LPP ECHELONNE'), findsOneWidget);
      // Intro text
      expect(
        find.textContaining('Pourquoi échelonner ses rachats'),
        findsOneWidget,
      );
    });

    testWidgets('LibrePassageScreen renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: LibrePassageScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Title in SliverAppBar
      expect(find.text('LIBRE PASSAGE'), findsOneWidget);
      // Situation section
      expect(find.textContaining('SITUATION'), findsOneWidget);
      // Checklist section (may be below fold — skipOffstage: false)
      expect(
        find.textContaining('CHECKLIST', skipOffstage: false),
        findsOneWidget,
      );
    });
  });

  // =========================================================================
  // INSURANCE SUITE
  // =========================================================================

  group('Insurance screens', () {
    testWidgets('LamalFranchiseScreen renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: LamalFranchiseScreen(),
        ),
      );
      await tester.pump();

      // Header title
      expect(
        find.textContaining('Optimiseur franchise LAMal'),
        findsOneWidget,
      );
      // Toggle
      expect(find.text('Adulte'), findsOneWidget);
      expect(find.text('Enfant'), findsOneWidget);
    });

    testWidgets('CoverageCheckScreen renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: CoverageCheckScreen(),
        ),
      );
      await tester.pump();

      // Header title
      expect(find.textContaining('Check-up couverture'), findsOneWidget);
      // Profile section
      expect(find.textContaining('Ton profil'), findsOneWidget);
      // Coverage section
      expect(find.textContaining('Ma couverture actuelle'), findsOneWidget);
    });
  });

  // =========================================================================
  // DISABILITY GAP SUITE
  // =========================================================================

  group('Disability gap screen', () {
    testWidgets('DisabilityGapScreen renders without error',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: DisabilityGapScreen(),
        ),
      );
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
