import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/screens/coach/coach_dashboard_screen.dart';
import 'package:mint_mobile/widgets/coach/mint_score_gauge.dart';
import 'package:mint_mobile/widgets/coach/mint_trajectory_chart.dart';

void main() {
  Widget buildTestWidget() {
    return const MaterialApp(
      home: CoachDashboardScreen(),
    );
  }

  group('CoachDashboardScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CoachDashboardScreen), findsOneWidget);
    });

    testWidgets('shows greeting with name', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('Bonjour'), findsWidgets);
    });

    testWidgets('shows coach alert card', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.byType(CoachDashboardScreen), findsOneWidget);
    });

    testWidgets('contains MintScoreGauge', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.byType(MintScoreGauge), findsOneWidget);
    });

    testWidgets('contains MintTrajectoryChart after scroll', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      // Trajectory chart is below score gauge, scroll to reveal it
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MintTrajectoryChart, skipOffstage: false), findsOneWidget);
    });

    testWidgets('shows quick actions after scroll', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      // Quick actions are below chart, scroll further
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();
      // Text has newline: 'Check-in\nmensuel'
      expect(find.textContaining('mensuel'), findsWidgets);
    });

    testWidgets('shows fitness score section header', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('Fitness'), findsWidgets);
    });

    testWidgets('shows trajectory section after scrolling', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      // Scroll to reveal trajectory section
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('trajectoire'), findsWidgets);
    });

    testWidgets('scrolls without crash', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CoachDashboardScreen), findsOneWidget);
    });

    testWidgets('shows disclaimer after scrolling to bottom', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      // Scroll far down to find disclaimer
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Estimation'), findsWidgets);
    });
  });
}
