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

      // i18n: affordabilityTitle = "Capacite d'achat"
      expect(find.textContaining('achat'), findsWidgets);
      expect(find.byType(Scaffold), findsOneWidget);
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

      // i18n: saronVsFixedAppBarTitle = "SARON vs fixe"
      expect(find.textContaining('SARON'), findsWidgets);
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

      // i18n: amortizationAppBarTitle = "Direct vs indirect"
      expect(find.textContaining('direct'), findsWidgets);
      // i18n: amortizationIntroTitle = "Amortissement : direct ou indirect ?"
      expect(find.textContaining('mortissement'), findsWidgets);
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

      // i18n: avsCotisationsTitle = "Cotisations AVS"
      expect(find.textContaining('Cotisations AVS'), findsOneWidget);
      expect(find.textContaining('revenu'), findsWidgets);
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

      // i18n: dividendeVsSalaireTitle = "Dividende vs Salaire"
      expect(find.textContaining('Dividende'), findsWidgets);
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

      // i18n: ijmTitle = "Assurance IJM"
      expect(find.textContaining('IJM'), findsWidgets);
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

      // i18n: repaymentTitle = "Plan de remboursement"
      expect(find.textContaining('remboursement'), findsWidgets);
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

      // i18n: debtRatioTitle = "Diagnostic dette"
      expect(find.textContaining('iagnostic'), findsWidgets);
      expect(find.byType(Scaffold), findsOneWidget);
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

      // Still hardcoded: 'AIDE EN CAS DE DETTE'
      expect(find.textContaining('AIDE'), findsWidgets);
      expect(find.textContaining('seul'), findsWidgets);
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

      // i18n: rachatEchelonneTitle = "Rachat LPP echelonne"
      expect(find.textContaining('Rachat LPP'), findsWidgets);
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

      // i18n: librePassageAppBarTitle = "Libre passage"
      expect(find.textContaining('ibre passage'), findsWidgets);
      expect(find.byType(Scaffold), findsOneWidget);
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

      // i18n: lamalFranchiseAppBarTitle = "Franchise LAMal"
      expect(find.textContaining('LAMal'), findsWidgets);
      expect(find.byType(Scaffold), findsOneWidget);
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

      // i18n: coverageCheckAppBarTitle = "Check-up couverture" (may appear twice)
      expect(find.textContaining('Check-up couverture'), findsWidgets);
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  // =========================================================================
  // DISABILITY GAP SUITE
  // =========================================================================

  group('Disability gap screen', () {
    testWidgets('DisabilityGapScreen renders without error',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const DisabilityGapScreen()),
      );
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
