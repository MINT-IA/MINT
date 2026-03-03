import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Screens under test
import 'package:mint_mobile/screens/job_comparison_screen.dart';
import 'package:mint_mobile/screens/coaching_screen.dart';
import 'package:mint_mobile/screens/lamal_franchise_screen.dart';

void main() {
  Widget buildTestable(Widget child) {
    return MaterialApp(home: child);
  }

  // ===========================================================================
  // 1. JOB COMPARISON SCREEN
  // ===========================================================================

  group('JobComparisonScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(
        buildTestable(const JobComparisonScreen()),
      );
      await tester.pump();

      expect(find.byType(JobComparisonScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays AppBar title in French', (tester) async {
      await tester.pumpWidget(
        buildTestable(const JobComparisonScreen()),
      );
      await tester.pump();

      expect(
        find.textContaining('Comparer deux emplois'),
        findsWidgets,
      );
    });

    testWidgets('shows header with salaire invisible subtitle',
        (tester) async {
      await tester.pumpWidget(
        buildTestable(const JobComparisonScreen()),
      );
      await tester.pump();

      expect(
        find.textContaining('salaire invisible'),
        findsWidgets,
      );
    });

    testWidgets('shows intro card with educational text', (tester) async {
      await tester.pumpWidget(
        buildTestable(const JobComparisonScreen()),
      );
      await tester.pump();

      expect(
        find.textContaining('Le salaire brut ne dit pas tout'),
        findsOneWidget,
      );
    });

    testWidgets('shows age slider section', (tester) async {
      await tester.pumpWidget(
        buildTestable(const JobComparisonScreen()),
      );
      await tester.pump();

      expect(find.textContaining('Ton age'), findsOneWidget);
      expect(find.byType(Slider), findsWidgets);
    });

    testWidgets('shows EMPLOI ACTUEL section', (tester) async {
      await tester.pumpWidget(
        buildTestable(const JobComparisonScreen()),
      );
      await tester.pump();

      expect(find.text('EMPLOI ACTUEL'), findsOneWidget);
    });

    testWidgets('shows EMPLOI ENVISAGE section', (tester) async {
      await tester.pumpWidget(
        buildTestable(const JobComparisonScreen()),
      );
      await tester.pump();

      // Scroll down to find second job section
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -800),
      );
      await tester.pump();

      expect(find.text('EMPLOI ENVISAGE'), findsOneWidget);
    });

    testWidgets('shows part employeur chips in expanded sections',
        (tester) async {
      await tester.pumpWidget(
        buildTestable(const JobComparisonScreen()),
      );
      await tester.pump();

      // Both sections are expanded by default
      expect(find.textContaining('Part employeur LPP'), findsWidgets);
      expect(find.textContaining('Salaire brut annuel'), findsWidgets);
    });

    testWidgets('shows IJM switch in expanded sections', (tester) async {
      await tester.pumpWidget(
        buildTestable(const JobComparisonScreen()),
      );
      await tester.pump();

      expect(find.textContaining('IJM collective incluse'), findsWidgets);
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('has Comparer button', (tester) async {
      await tester.pumpWidget(
        buildTestable(const JobComparisonScreen()),
      );
      await tester.pump();

      // Scroll to compare button
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1500),
      );
      await tester.pump();

      expect(find.text('Comparer'), findsOneWidget);
    });

    testWidgets('shows educational expandable tiles', (tester) async {
      await tester.pumpWidget(
        buildTestable(const JobComparisonScreen()),
      );
      await tester.pump();

      // Scroll to educational section
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2000),
      );
      await tester.pump();

      expect(find.text('COMPRENDRE'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsWidgets);
    });

    testWidgets('shows disclaimer with legal text', (tester) async {
      await tester.pumpWidget(
        buildTestable(const JobComparisonScreen()),
      );
      await tester.pump();

      // Scroll to disclaimer
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2500),
      );
      await tester.pump();

      expect(
        find.textContaining('ne constituent pas un conseil'),
        findsOneWidget,
      );
    });
  });

  // ===========================================================================
  // 2. COACHING SCREEN
  // ===========================================================================

  group('CoachingScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(
        buildTestable(const CoachingScreen()),
      );
      await tester.pump();

      expect(find.byType(CoachingScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows coaching header with title', (tester) async {
      await tester.pumpWidget(
        buildTestable(const CoachingScreen()),
      );
      await tester.pump();

      expect(find.text('Coaching proactif'), findsOneWidget);
      expect(find.textContaining('suggestions personnalisees'), findsWidgets);
    });

    testWidgets('shows intro info card', (tester) async {
      await tester.pumpWidget(
        buildTestable(const CoachingScreen()),
      );
      await tester.pump();

      expect(
        find.textContaining('Suggestions personnalisees basees'),
        findsOneWidget,
      );
    });

    testWidgets('displays coaching tip cards', (tester) async {
      await tester.pumpWidget(
        buildTestable(const CoachingScreen()),
      );
      await tester.pump();

      // Scroll to see tip cards
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -200),
      );
      await tester.pump();

      // Tips should have priority badges and action buttons
      expect(find.byType(TextButton), findsWidgets);
    });

    testWidgets('shows app bar with COACHING PROACTIF title', (tester) async {
      await tester.pumpWidget(
        buildTestable(const CoachingScreen()),
      );
      await tester.pump();

      expect(find.text('COACHING PROACTIF'), findsOneWidget);
    });
  });

  // ===========================================================================
  // 3. LAMAL FRANCHISE SCREEN
  // ===========================================================================

  group('LamalFranchiseScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(
        buildTestable(const LamalFranchiseScreen()),
      );
      await tester.pump();

      expect(find.byType(LamalFranchiseScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows header with LAMal text', (tester) async {
      await tester.pumpWidget(
        buildTestable(const LamalFranchiseScreen()),
      );
      await tester.pump();

      expect(
        find.textContaining('Optimiseur franchise LAMal'),
        findsWidgets,
      );
    });

    testWidgets('shows demo mode badge', (tester) async {
      await tester.pumpWidget(
        buildTestable(const LamalFranchiseScreen()),
      );
      await tester.pump();

      expect(find.text('MODE DEMO'), findsOneWidget);
    });

    testWidgets('shows intro info card', (tester) async {
      await tester.pumpWidget(
        buildTestable(const LamalFranchiseScreen()),
      );
      await tester.pump();

      expect(
        find.textContaining('franchise elevee reduit ta prime'),
        findsOneWidget,
      );
    });

    testWidgets('shows adult/child toggle', (tester) async {
      await tester.pumpWidget(
        buildTestable(const LamalFranchiseScreen()),
      );
      await tester.pump();

      expect(find.text('Adulte'), findsOneWidget);
      expect(find.text('Enfant'), findsOneWidget);
    });

    testWidgets('shows prime slider', (tester) async {
      await tester.pumpWidget(
        buildTestable(const LamalFranchiseScreen()),
      );
      await tester.pump();

      expect(
        find.textContaining('Prime mensuelle'),
        findsOneWidget,
      );
      expect(find.byType(Slider), findsWidgets);
    });

    testWidgets('shows depenses slider', (tester) async {
      await tester.pumpWidget(
        buildTestable(const LamalFranchiseScreen()),
      );
      await tester.pump();

      // Scroll to see depenses slider
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -200),
      );
      await tester.pump();

      expect(
        find.textContaining('Frais de sante'),
        findsOneWidget,
      );
    });

    testWidgets('auto-computes and shows comparison cards', (tester) async {
      await tester.pumpWidget(
        buildTestable(const LamalFranchiseScreen()),
      );
      await tester.pump();

      // Scroll to comparison cards
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -500),
      );
      await tester.pump();

      expect(
        find.textContaining('COMPARAISON DES FRANCHISES'),
        findsOneWidget,
      );
    });

    testWidgets('shows RECOMMANDEE badge on optimal franchise', (tester) async {
      await tester.pumpWidget(
        buildTestable(const LamalFranchiseScreen()),
      );
      await tester.pump();

      // Scroll to comparison cards
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -600),
      );
      await tester.pump();

      expect(find.text('RECOMMANDEE'), findsOneWidget);
    });

    testWidgets('shows alert reminder about deadline', (tester) async {
      await tester.pumpWidget(
        buildTestable(const LamalFranchiseScreen()),
      );
      await tester.pump();

      // Scroll to find the alert card
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -1500),
      );
      await tester.pump();

      expect(
        find.textContaining('30 novembre'),
        findsOneWidget,
      );
    });

    testWidgets('shows disclaimer', (tester) async {
      await tester.pumpWidget(
        buildTestable(const LamalFranchiseScreen()),
      );
      await tester.pump();

      // Scroll to disclaimer
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -2000),
      );
      await tester.pump();

      expect(
        find.textContaining('indicative'),
        findsOneWidget,
      );
    });

    testWidgets('shows sources footer with LAMal references', (tester) async {
      await tester.pumpWidget(
        buildTestable(const LamalFranchiseScreen()),
      );
      await tester.pump();

      // Scroll to sources
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -2500),
      );
      await tester.pump();

      expect(find.text('Sources'), findsOneWidget);
    });
  });
}
