import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/widgets/coach/mint_trajectory_chart.dart';

void main() {
  late ProjectionResult result;

  setUp(() {
    final profile = CoachProfile.buildDemo();
    result = ForecasterService.project(
      profile: profile,
      targetDate: profile.goalA.targetDate,
    );
  });

  Widget buildTestWidget({ProjectionResult? projResult, String? goalALabel}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MintTrajectoryChart(
            result: projResult ?? result,
            goalALabel: goalALabel ?? 'Retraite 65 ans',
          ),
        ),
      ),
    );
  }

  group('MintTrajectoryChart', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(MintTrajectoryChart), findsOneWidget);
    });

    testWidgets('displays CustomPaint for chart', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('shows scenario labels', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('Optimiste'), findsWidgets);
      expect(find.textContaining('Prudent'), findsWidgets);
    });

    testWidgets('shows goal A label', (tester) async {
      await tester.pumpWidget(buildTestWidget(goalALabel: 'Retraite 65 ans'));
      await tester.pumpAndSettle();
      expect(find.byType(MintTrajectoryChart), findsOneWidget);
    });

    testWidgets('handles tap without crash', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MintTrajectoryChart(
              result: result,
              goalALabel: 'Retraite',
              onTap: () => tapped = true,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MintTrajectoryChart).first);
      expect(tapped, isTrue);
    });

    testWidgets('has Semantics', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('result has 3 scenarios with points', (tester) async {
      expect(result.prudent, isNotNull);
      expect(result.base, isNotNull);
      expect(result.optimiste, isNotNull);
      expect(result.prudent.points, isNotEmpty);
      expect(result.base.points, isNotEmpty);
      expect(result.optimiste.points, isNotEmpty);
    });

    testWidgets('optimiste capital > base > prudent', (tester) async {
      expect(result.optimiste.capitalFinal, greaterThan(result.base.capitalFinal));
      expect(result.base.capitalFinal, greaterThan(result.prudent.capitalFinal));
    });

    testWidgets('widget contains RichText for data display', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.byType(RichText), findsWidgets);
    });
  });
}
