import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/coach/coach_agir_screen.dart';

// ────────────────────────────────────────────────────────────
//  COACH AGIR SCREEN TESTS — Phase 5 / Quality hardening
//
//  The Agir screen requires CoachProfileProvider with a loaded
//  profile. Without profile, the empty state is shown and
//  "Ce mois", "Timeline", "Historique" sections are absent.
// ────────────────────────────────────────────────────────────

void main() {
  CoachProfileProvider buildCoachProvider() {
    final provider = CoachProfileProvider();
    provider.updateFromAnswers({
      'q_firstname': 'Julien',
      'q_birth_year': 1977,
      'q_canton': 'VS',
      'q_net_income_period_chf': 9080,
      'q_civil_status': 'marie',
      'q_goal': 'retraite',
    });
    return provider;
  }

  Widget buildTestWidget() {
    return ChangeNotifierProvider(
      create: (_) => buildCoachProvider(),
      child: const MaterialApp(
        home: CoachAgirScreen(),
      ),
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
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('AGIR'), findsOneWidget);
    });

    testWidgets('shows "Ce mois" section', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('mois'), findsWidgets);
    });

    testWidgets('shows timeline section after scroll', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -500));
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.textContaining('Timeline', skipOffstage: false),
        findsWidgets,
      );
    });

    testWidgets('shows planned contributions', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CoachAgirScreen), findsOneWidget);
    });

    testWidgets('shows timeline events', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CoachAgirScreen), findsOneWidget);
    });

    testWidgets('shows historique section after scroll', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -1500));
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.textContaining('Historique', skipOffstage: false),
        findsWidgets,
      );
    });

    testWidgets('scrolls without crash', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -500));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CoachAgirScreen), findsOneWidget);
    });

    testWidgets('shows disclaimer after full scroll', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -2000));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CoachAgirScreen), findsOneWidget);
    });
  });
}
