import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Screens under test
import 'package:mint_mobile/screens/debt_prevention/repayment_screen.dart';
import 'package:mint_mobile/screens/debt_prevention/debt_ratio_screen.dart';
import 'package:mint_mobile/screens/debt_prevention/help_resources_screen.dart';

void main() {
  // ===========================================================================
  // 1. REPAYMENT SCREEN
  // ===========================================================================

  group('RepaymentScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RepaymentScreen(),
        ),
      );
      await tester.pump();

      expect(find.byType(RepaymentScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays French title in AppBar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RepaymentScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('PLAN DE REMBOURSEMENT'), findsOneWidget);
    });

    testWidgets('shows default debt list', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RepaymentScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('MES DETTES'), findsOneWidget);
      // Two default debts are provided in initState
      expect(find.text('Credit conso'), findsOneWidget);
      expect(find.text('Leasing auto'), findsOneWidget);
    });

    testWidgets('shows budget slider section', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RepaymentScreen(),
        ),
      );
      await tester.pump();

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -400),
      );
      await tester.pump();

      expect(find.text('BUDGET MENSUEL REMBOURSEMENT'), findsOneWidget);
    });

    testWidgets('shows strategy comparison section', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RepaymentScreen(),
        ),
      );
      await tester.pump();

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -600),
      );
      await tester.pump();

      expect(find.text('COMPARAISON DES STRATEGIES'), findsOneWidget);
      expect(find.text('AVALANCHE'), findsOneWidget);
      expect(find.text('BOULE DE NEIGE'), findsOneWidget);
    });

    testWidgets('shows timeline section', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RepaymentScreen(),
        ),
      );
      await tester.pump();

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -900),
      );
      await tester.pump();

      expect(find.text('TIMELINE (AVALANCHE)'), findsOneWidget);
    });

    testWidgets('shows chiffre choc', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RepaymentScreen(),
        ),
      );
      await tester.pump();

      expect(find.textContaining('mois'), findsWidgets);
    });

    testWidgets('has add debt button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RepaymentScreen(),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    });

    testWidgets('has delete buttons for debts', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RepaymentScreen(),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
    });

    testWidgets('shows debt mini sliders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RepaymentScreen(),
        ),
      );
      await tester.pump();

      expect(find.byType(Slider), findsWidgets);
    });
  });

  // ===========================================================================
  // 2. DEBT RATIO SCREEN
  // ===========================================================================

  group('DebtRatioScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DebtRatioScreen(),
        ),
      );
      await tester.pump();

      expect(find.byType(DebtRatioScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays French title in AppBar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DebtRatioScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('DIAGNOSTIC DETTE'), findsOneWidget);
    });

    testWidgets('shows gauge with CustomPaint', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DebtRatioScreen(),
        ),
      );
      await tester.pump();

      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.textContaining('Ratio dette'), findsOneWidget);
    });

    testWidgets('shows gauge legend', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DebtRatioScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('< 15%'), findsOneWidget);
      expect(find.text('15-30%'), findsOneWidget);
      expect(find.text('> 30%'), findsOneWidget);
    });

    testWidgets('shows parameter sliders section', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DebtRatioScreen(),
        ),
      );
      await tester.pump();

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -300),
      );
      await tester.pump();

      expect(find.text('PARAMETRES'), findsOneWidget);
      expect(find.text('Revenu mensuel net'), findsOneWidget);
      expect(find.text('Charges de dette mensuelles'), findsOneWidget);
      expect(find.text('Loyer'), findsOneWidget);
      expect(find.text('Autres charges fixes'), findsOneWidget);
    });

    testWidgets('shows celibataire switch', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DebtRatioScreen(),
        ),
      );
      await tester.pump();

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -400),
      );
      await tester.pump();

      expect(find.text('Celibataire'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('shows minimum vital card', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DebtRatioScreen(),
        ),
      );
      await tester.pump();

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -600),
      );
      await tester.pump();

      expect(find.text('MINIMUM VITAL (LP ART. 93)'), findsOneWidget);
      expect(find.text('Minimum vital'), findsOneWidget);
      expect(find.text('Marge disponible'), findsOneWidget);
    });

    testWidgets('shows recommendations section', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DebtRatioScreen(),
        ),
      );
      await tester.pump();

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -800),
      );
      await tester.pump();

      expect(find.text('RECOMMANDATIONS'), findsOneWidget);
    });

    testWidgets('shows disclaimer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DebtRatioScreen(),
        ),
      );
      await tester.pump();

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -1200),
      );
      await tester.pump();

      // Disclaimer comes from the service, check for icon
      expect(find.byIcon(Icons.info_outline), findsWidgets);
    });

    testWidgets('shows ratio percentage display', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DebtRatioScreen(),
        ),
      );
      await tester.pump();

      // The ratio percentage is displayed in the gauge section
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
          home: HelpResourcesScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('AIDE EN CAS DE DETTE'), findsOneWidget);
    });

    testWidgets('shows intro card', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HelpResourcesScreen(),
        ),
      );
      await tester.pump();

      expect(
        find.textContaining('Vous n\'etes pas seul'),
        findsOneWidget,
      );
      expect(
        find.textContaining('MINT ne transmet aucune donnee'),
        findsWidgets,
      );
    });

    testWidgets('shows Dettes Conseils Suisse resource', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HelpResourcesScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Dettes Conseils Suisse'), findsOneWidget);
      expect(find.text('0800 40 40 40'), findsOneWidget);
    });

    testWidgets('shows GRATUIT badge', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HelpResourcesScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('GRATUIT'), findsWidgets);
    });

    testWidgets('shows cantonal section with dropdown', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HelpResourcesScreen(),
        ),
      );
      await tester.pump();

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -500),
      );
      await tester.pump();

      expect(find.text('SERVICE CANTONAL'), findsOneWidget);
      expect(find.text('Votre canton'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });

    testWidgets('shows privacy note (nLPD)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HelpResourcesScreen(),
        ),
      );
      await tester.pump();

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -700),
      );
      await tester.pump();

      expect(find.text('Protection des donnees (nLPD)'), findsOneWidget);
      expect(
        find.textContaining('confidentielle'),
        findsOneWidget,
      );
    });

    testWidgets('shows disclaimer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HelpResourcesScreen(),
        ),
      );
      await tester.pump();

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -900),
      );
      await tester.pump();

      expect(
        find.textContaining('informatif et pedagogique'),
        findsOneWidget,
      );
    });

    testWidgets('shows web and phone buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HelpResourcesScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Site web'), findsWidgets);
    });
  });
}
