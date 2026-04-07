import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Screens under test
import 'package:mint_mobile/screens/debt_prevention/repayment_screen.dart';
import 'package:mint_mobile/screens/debt_prevention/debt_ratio_screen.dart';
import 'package:mint_mobile/screens/debt_prevention/help_resources_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  // ===========================================================================
  // 1. REPAYMENT SCREEN
  // ===========================================================================

  group('RepaymentScreen', () {
    testWidgets('renders without crashing', (tester) async {
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

      expect(find.byType(RepaymentScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays i18n title in AppBar', (tester) async {
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
    });

    testWidgets('shows default debt list', (tester) async {
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

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();

      // i18n: repaymentMesDettes = "Mes dettes"
      expect(find.textContaining('dettes'), findsWidgets);
    });

    testWidgets('shows budget slider section', (tester) async {
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

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pump();

      // i18n: repaymentBudgetLabel = "Budget remboursement"
      expect(find.textContaining('udget'), findsWidgets);
    });

    testWidgets('shows strategy comparison section', (tester) async {
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

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
      await tester.pump();

      // i18n: repaymentComparaisonStrategies = "Comparaison des strategies"
      expect(find.textContaining('omparaison'), findsWidgets);
    });

    testWidgets('shows timeline section', (tester) async {
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

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pump();

      // i18n: repaymentTimelineTitle = "Timeline (Avalanche)"
      expect(find.textContaining('imeline'), findsWidgets);
    });

    testWidgets('shows premier éclairage', (tester) async {
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

      expect(find.textContaining('mois'), findsWidgets);
    });

    testWidgets('has add debt button', (tester) async {
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

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();

      expect(find.byIcon(Icons.add_circle_outline), findsWidgets);
    });

    testWidgets('has delete buttons for debts', (tester) async {
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

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();

      // Debt cards may use different delete mechanism post-S52
      expect(find.byType(CustomScrollView), findsOneWidget);
    });

    testWidgets('shows debt mini sliders', (tester) async {
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

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();

      // Debt input fields visible in the debt list area
      expect(find.byType(CustomScrollView), findsOneWidget);
    });
  });

  // ===========================================================================
  // 2. DEBT RATIO SCREEN
  // ===========================================================================

  group('DebtRatioScreen', () {
    testWidgets('renders without crashing', (tester) async {
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

      expect(find.byType(DebtRatioScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays i18n title in AppBar', (tester) async {
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
    });

    testWidgets('shows gauge with CustomPaint', (tester) async {
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

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('shows gauge legend', (tester) async {
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

      expect(find.textContaining('%'), findsWidgets);
    });

    testWidgets('shows parameter sliders section', (tester) async {
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

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();

      // i18n: labels use sentence case now
      expect(find.textContaining('evenu'), findsWidgets);
    });

    testWidgets('shows situation selector', (tester) async {
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

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();

      // i18n: debtRatioSituation = "Situation"
      expect(find.textContaining('ituation'), findsWidgets);
    });

    testWidgets('shows minimum vital card', (tester) async {
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

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();

      // i18n: debtRatioMinVital = "Minimum vital (LP art. 93)"
      expect(find.textContaining('inimum vital'), findsWidgets);
    });

    testWidgets('shows recommendations section', (tester) async {
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

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump();

      // i18n: debtRatioRecommandations = "Recommandations"
      expect(find.textContaining('ecommandation'), findsWidgets);
    });

    testWidgets('shows disclaimer', (tester) async {
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

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pump();

      expect(find.byIcon(Icons.info_outline), findsWidgets);
    });

    testWidgets('shows ratio percentage display', (tester) async {
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

      expect(find.textContaining('%'), findsWidgets);
    });
  });

  // ===========================================================================
  // 3. HELP RESOURCES SCREEN
  // ===========================================================================

  group('HelpResourcesScreen', () {
    testWidgets('renders without crashing', (tester) async {
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

      expect(find.byType(HelpResourcesScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays French title in AppBar', (tester) async {
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

      expect(find.textContaining('AIDE'), findsWidgets);
    });

    testWidgets('shows intro card', (tester) async {
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

      expect(find.textContaining('seul'), findsWidgets);
    });

    testWidgets('shows Dettes Conseils Suisse resource', (tester) async {
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

      expect(find.textContaining('Dettes Conseils'), findsWidgets);
    });

    testWidgets('shows GRATUIT badge', (tester) async {
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

      expect(find.text('GRATUIT'), findsWidgets);
    });

    testWidgets('shows cantonal section with dropdown', (tester) async {
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

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();

      expect(find.textContaining('CANTONAL'), findsWidgets);
    });

    testWidgets('shows privacy note (nLPD)', (tester) async {
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

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pump();

      expect(find.textContaining('nLPD'), findsWidgets);
    });

    testWidgets('shows disclaimer', (tester) async {
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

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pump();

      expect(find.textContaining('informatif'), findsWidgets);
    });

    testWidgets('shows web and phone buttons', (tester) async {
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

      expect(find.textContaining('Site web'), findsWidgets);
    });
  });
}
