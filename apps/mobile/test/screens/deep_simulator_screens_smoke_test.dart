import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Screens under test
import 'package:mint_mobile/screens/divorce_simulator_screen.dart';
import 'package:mint_mobile/screens/succession_simulator_screen.dart';
import 'package:mint_mobile/screens/simulator_disability_gap_screen.dart';
import 'package:mint_mobile/domain/disability_gap_calculator.dart';
import 'package:mint_mobile/screens/simulator_rente_capital_screen.dart';
import 'package:mint_mobile/screens/coverage_check_screen.dart';

void main() {
  Widget buildTestable(Widget child) {
    return MaterialApp(home: child);
  }

  // ===========================================================================
  // 1. DIVORCE SIMULATOR SCREEN
  // ===========================================================================

  group('DivorceSimulatorScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(
        buildTestable(const DivorceSimulatorScreen()),
      );
      await tester.pump();

      expect(find.byType(DivorceSimulatorScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays AppBar title in French', (tester) async {
      await tester.pumpWidget(
        buildTestable(const DivorceSimulatorScreen()),
      );
      await tester.pump();

      expect(
        find.textContaining('Divorce'),
        findsWidgets,
      );
    });

    testWidgets('shows header with impact text', (tester) async {
      await tester.pumpWidget(
        buildTestable(const DivorceSimulatorScreen()),
      );
      await tester.pump();

      expect(
        find.textContaining('Impact financier'),
        findsWidgets,
      );
    });

    testWidgets('shows intro card with educational text', (tester) async {
      await tester.pumpWidget(
        buildTestable(const DivorceSimulatorScreen()),
      );
      await tester.pump();

      expect(
        find.textContaining('consequences financieres'),
        findsWidgets,
      );
    });

    testWidgets('shows situation familiale section with sliders',
        (tester) async {
      await tester.pumpWidget(
        buildTestable(const DivorceSimulatorScreen()),
      );
      await tester.pump();

      expect(find.text('SITUATION FAMILIALE'), findsOneWidget);
      expect(find.textContaining('Duree du mariage'), findsWidgets);
      expect(find.byType(Slider), findsWidgets);
    });

    testWidgets('shows matrimonial regime chips', (tester) async {
      await tester.pumpWidget(
        buildTestable(const DivorceSimulatorScreen()),
      );
      await tester.pump();

      expect(find.text('Regime matrimonial'), findsOneWidget);
      expect(
        find.textContaining('Participation aux acquets'),
        findsOneWidget,
      );
      expect(find.textContaining('Separation de biens'), findsOneWidget);
    });

    testWidgets('shows revenus and prevoyance sections', (tester) async {
      await tester.pumpWidget(
        buildTestable(const DivorceSimulatorScreen()),
      );
      await tester.pump();

      expect(find.text('REVENUS'), findsOneWidget);
      expect(find.text('PREVOYANCE'), findsOneWidget);
    });

    testWidgets('has Simuler button', (tester) async {
      await tester.pumpWidget(
        buildTestable(const DivorceSimulatorScreen()),
      );
      await tester.pump();

      expect(find.text('Simuler'), findsWidgets);
    });

    testWidgets('shows disclaimer text', (tester) async {
      await tester.pumpWidget(
        buildTestable(const DivorceSimulatorScreen()),
      );
      await tester.pump();

      // Scroll down to find disclaimer
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1500),
      );
      await tester.pump();

      expect(
        find.textContaining('ne constituent pas un conseil'),
        findsOneWidget,
      );
    });

    testWidgets('shows educational expandable tiles', (tester) async {
      await tester.pumpWidget(
        buildTestable(const DivorceSimulatorScreen()),
      );
      await tester.pump();

      // Scroll down to educational section
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1500),
      );
      await tester.pump();

      expect(find.text('COMPRENDRE'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsWidgets);
    });

  });

  // ===========================================================================
  // 2. SUCCESSION SIMULATOR SCREEN
  // ===========================================================================

  group('SuccessionSimulatorScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SuccessionSimulatorScreen()),
      );
      await tester.pump();

      expect(find.byType(SuccessionSimulatorScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays AppBar title in French', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SuccessionSimulatorScreen()),
      );
      await tester.pump();

      expect(
        find.textContaining('Succession'),
        findsWidgets,
      );
    });

    testWidgets('shows header with planning text', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SuccessionSimulatorScreen()),
      );
      await tester.pump();

      expect(
        find.textContaining('Planifier ma succession'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Nouveau droit successoral 2023'),
        findsOneWidget,
      );
    });

    testWidgets('shows civil status chips', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SuccessionSimulatorScreen()),
      );
      await tester.pump();

      expect(find.text('SITUATION PERSONNELLE'), findsOneWidget);
      expect(find.text('Statut civil'), findsOneWidget);
      expect(find.textContaining('Marie'), findsOneWidget);
      expect(find.textContaining('Celibataire'), findsOneWidget);
    });

    testWidgets('shows fortune section with sliders', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SuccessionSimulatorScreen()),
      );
      await tester.pump();

      expect(find.text('FORTUNE'), findsOneWidget);
      expect(find.textContaining('Fortune totale'), findsOneWidget);
      expect(find.textContaining('Avoirs 3a'), findsOneWidget);
      expect(find.byType(Slider), findsWidgets);
    });

    testWidgets('shows testament section with switch', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SuccessionSimulatorScreen()),
      );
      await tester.pump();

      expect(find.text('TESTAMENT'), findsOneWidget);
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('shows canton dropdown', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SuccessionSimulatorScreen()),
      );
      await tester.pump();

      expect(find.text('Canton'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });

    testWidgets('has Simuler button', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SuccessionSimulatorScreen()),
      );
      await tester.pump();

      expect(find.text('Simuler'), findsWidgets);
    });

    testWidgets('shows educational footer with expandable tiles',
        (tester) async {
      await tester.pumpWidget(
        buildTestable(const SuccessionSimulatorScreen()),
      );
      await tester.pump();

      // Scroll to educational section
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2000),
      );
      await tester.pump();

      expect(find.text('COMPRENDRE'), findsOneWidget);
    });

    testWidgets('shows disclaimer text', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SuccessionSimulatorScreen()),
      );
      await tester.pump();

      // Scroll down to disclaimer
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2000),
      );
      await tester.pump();

      expect(
        find.textContaining('ne constituent pas un conseil'),
        findsOneWidget,
      );
    });
  });

  // ===========================================================================
  // 3. SIMULATOR DISABILITY GAP SCREEN
  // ===========================================================================

  group('SimulatorDisabilityGapScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SimulatorDisabilityGapScreen()),
      );
      await tester.pump();

      expect(find.byType(SimulatorDisabilityGapScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays AppBar title in French', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SimulatorDisabilityGapScreen()),
      );
      await tester.pump();

      expect(
        find.textContaining('filet de s'),
        findsWidgets,
      );
    });

    testWidgets('shows header with disability question', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SimulatorDisabilityGapScreen()),
      );
      await tester.pump();

      expect(
        find.textContaining('ne peux plus travailler'),
        findsOneWidget,
      );
    });

    testWidgets('shows input section with sliders', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SimulatorDisabilityGapScreen()),
      );
      await tester.pump();

      expect(find.textContaining('Revenu mensuel net'), findsOneWidget);
      expect(find.byType(Slider), findsWidgets);
    });

    testWidgets('shows canton dropdown and status selector', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SimulatorDisabilityGapScreen()),
      );
      await tester.pump();

      expect(find.text('Canton'), findsOneWidget);
      expect(find.text('Statut professionnel'), findsOneWidget);
      expect(find.byType(SegmentedButton<EmploymentStatusType>), findsOneWidget);
    });

    testWidgets('auto-calculates results on init', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SimulatorDisabilityGapScreen()),
      );
      await tester.pump();

      // Results should be visible since _calculate is called in initState
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pump();

      expect(find.textContaining('Evolution de ta couverture'), findsOneWidget);
    });

    testWidgets('shows risk level badge', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SimulatorDisabilityGapScreen()),
      );
      await tester.pump();

      // Scroll to gap alert card
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -700),
      );
      await tester.pump();

      expect(find.textContaining('GAP MENSUEL MAXIMAL'), findsOneWidget);
    });

    testWidgets('shows phase detail cards', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SimulatorDisabilityGapScreen()),
      );
      await tester.pump();

      // Scroll to phase cards
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1000),
      );
      await tester.pump();

      expect(find.textContaining('Phase 1'), findsWidgets);
    });

    testWidgets('shows IJM switch for employee', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SimulatorDisabilityGapScreen()),
      );
      await tester.pump();

      expect(
        find.textContaining('IJM collective'),
        findsOneWidget,
      );
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('shows educational section', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SimulatorDisabilityGapScreen()),
      );
      await tester.pump();

      // Scroll far down
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2000),
      );
      await tester.pump();

      expect(find.text('COMPRENDRE'), findsOneWidget);
    });

    testWidgets('shows disclaimer', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SimulatorDisabilityGapScreen()),
      );
      await tester.pump();

      // Scroll far down
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2500),
      );
      await tester.pump();

      expect(
        find.textContaining('estimations indicatives'),
        findsOneWidget,
      );
    });
  });

  // ===========================================================================
  // 4. SIMULATOR RENTE VS CAPITAL SCREEN
  // ===========================================================================

  group('SimulatorRenteCapitalScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SimulatorRenteCapitalScreen()),
      );
      await tester.pump();

      expect(find.byType(SimulatorRenteCapitalScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays AppBar title in French', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SimulatorRenteCapitalScreen()),
      );
      await tester.pump();

      expect(
        find.text('Rente vs Capital'),
        findsWidgets,
      );
    });

    testWidgets('shows header with LPP subtitle', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SimulatorRenteCapitalScreen()),
      );
      await tester.pump();

      expect(
        find.textContaining('LPP'),
        findsWidgets,
      );
    });

    testWidgets('shows input section with sliders', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SimulatorRenteCapitalScreen()),
      );
      await tester.pump();

      expect(find.textContaining('Avoir obligatoire'), findsOneWidget);
      expect(find.textContaining('Avoir surobligatoire'), findsOneWidget);
      expect(find.textContaining('Taux de conversion'), findsOneWidget);
      expect(find.textContaining('Age de la retraite'), findsOneWidget);
      expect(find.byType(Slider), findsWidgets);
    });

    testWidgets('shows canton dropdown and civil status selector',
        (tester) async {
      await tester.pumpWidget(
        buildTestable(const SimulatorRenteCapitalScreen()),
      );
      await tester.pump();

      expect(find.text('Canton'), findsOneWidget);
      expect(find.text('Statut civil'), findsOneWidget);
      expect(find.byType(SegmentedButton<String>), findsOneWidget);
    });

    testWidgets('auto-calculates and shows result cards', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SimulatorRenteCapitalScreen()),
      );
      await tester.pump();

      // Scroll to result cards
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pump();

      expect(find.textContaining('Rente viagere'), findsOneWidget);
      expect(find.textContaining('Capital net'), findsOneWidget);
    });

    testWidgets('shows break-even section', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SimulatorRenteCapitalScreen()),
      );
      await tester.pump();

      // Scroll to break-even section
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1200),
      );
      await tester.pump();

      expect(find.text('POINTS CLES'), findsOneWidget);
      expect(find.textContaining('Break-even'), findsWidgets);
    });

    testWidgets('shows educational section', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SimulatorRenteCapitalScreen()),
      );
      await tester.pump();

      // Scroll far down
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2500),
      );
      await tester.pump();

      expect(find.text('COMPRENDRE'), findsOneWidget);
    });

    testWidgets('shows disclaimer', (tester) async {
      await tester.pumpWidget(
        buildTestable(const SimulatorRenteCapitalScreen()),
      );
      await tester.pump();

      // Scroll to bottom
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -3000),
      );
      await tester.pump();

      expect(
        find.textContaining('ne constituent pas un conseil'),
        findsOneWidget,
      );
    });
  });

  // ===========================================================================
  // 5. COVERAGE CHECK SCREEN
  // ===========================================================================

  group('CoverageCheckScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(
        buildTestable(const CoverageCheckScreen()),
      );
      await tester.pump();

      expect(find.byType(CoverageCheckScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows header with check-up text', (tester) async {
      await tester.pumpWidget(
        buildTestable(const CoverageCheckScreen()),
      );
      await tester.pump();

      expect(
        find.textContaining('Check-up couverture'),
        findsWidgets,
      );
    });

    testWidgets('shows demo mode badge', (tester) async {
      await tester.pumpWidget(
        buildTestable(const CoverageCheckScreen()),
      );
      await tester.pump();

      expect(find.text('MODE DEMO'), findsOneWidget);
    });

    testWidgets('shows profile section with statut chips', (tester) async {
      await tester.pumpWidget(
        buildTestable(const CoverageCheckScreen()),
      );
      await tester.pump();

      expect(find.text('Votre profil'), findsOneWidget);
      expect(find.text('Statut professionnel'), findsOneWidget);
    });

    testWidgets('shows coverage section with switches', (tester) async {
      await tester.pumpWidget(
        buildTestable(const CoverageCheckScreen()),
      );
      await tester.pump();

      // Scroll to coverage section
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -400),
      );
      await tester.pump();

      expect(find.text('Ma couverture actuelle'), findsOneWidget);
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('auto-computes and shows score gauge', (tester) async {
      await tester.pumpWidget(
        buildTestable(const CoverageCheckScreen()),
      );
      await tester.pump();

      // Scroll to score section
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -800),
      );
      await tester.pump();

      expect(find.textContaining('Score de couverture'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows checklist with ANALYSE DETAILLEE', (tester) async {
      await tester.pumpWidget(
        buildTestable(const CoverageCheckScreen()),
      );
      await tester.pump();

      // Scroll to checklist
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -1200),
      );
      await tester.pump();

      expect(find.textContaining('ANALYSE DETAILLEE'), findsOneWidget);
    });

    testWidgets('shows profile switches for specific options', (tester) async {
      await tester.pumpWidget(
        buildTestable(const CoverageCheckScreen()),
      );
      await tester.pump();

      expect(find.textContaining('Hypotheque en cours'), findsOneWidget);
      expect(find.textContaining('Personnes a charge'), findsOneWidget);
      expect(find.textContaining('Locataire'), findsOneWidget);
    });
  });
}
