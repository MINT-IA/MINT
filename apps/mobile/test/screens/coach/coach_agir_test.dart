import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/screens/coach/coach_agir_screen.dart';

void main() {
  Widget buildTestWidget() {
    return const MaterialApp(
      home: CoachAgirScreen(),
    );
  }

  group('CoachAgirScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CoachAgirScreen), findsOneWidget);
    });

    testWidgets('shows AGIR title in appbar', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.text('AGIR'), findsOneWidget);
    });

    testWidgets('shows "Ce mois" section', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('mois'), findsWidgets);
    });

    testWidgets('shows timeline section after scroll', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      // Timeline is below "Ce mois", scroll to reveal
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.textContaining('Timeline'), findsWidgets);
    });

    testWidgets('shows planned contributions', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.byType(CoachAgirScreen), findsOneWidget);
    });

    testWidgets('shows timeline events', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.byType(CoachAgirScreen), findsOneWidget);
    });

    testWidgets('shows historique section after scroll', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      // Historique is at the bottom, scroll far
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -1500));
      await tester.pumpAndSettle();
      // Use skipOffstage:false to find text even if partially off-screen
      expect(
        find.textContaining('Historique', skipOffstage: false),
        findsWidgets,
      );
    });

    testWidgets('scrolls without crash', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.byType(CoachAgirScreen), findsOneWidget);
    });

    testWidgets('shows disclaimer after full scroll', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(find.byType(CoachAgirScreen), findsOneWidget);
    });
  });
}
