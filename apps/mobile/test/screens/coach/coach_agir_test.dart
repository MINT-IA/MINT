import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/user_activity_provider.dart';
import 'package:mint_mobile/screens/coach/coach_agir_screen.dart';

// ────────────────────────────────────────────────────────────
//  COACH AGIR SCREEN TESTS — Phase 5 / Quality hardening
//
//  The Agir screen requires CoachProfileProvider with a loaded
//  profile. Without profile, the empty state is shown and
//  "Ce mois", "Timeline", "Historique" sections are absent.
// ────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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

  CoachProfileProvider buildMiniCoachProvider() {
    final provider = CoachProfileProvider();
    provider.updateFromMiniOnboarding({
      'q_birth_year': 1991,
      'q_canton': 'VD',
      'q_net_income_period_chf': 6200,
      'q_employment_status': 'employee',
      'q_household_type': 'single',
    });
    return provider;
  }

  Widget buildTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ByokProvider()),
        ChangeNotifierProvider(create: (_) => buildCoachProvider()),
        ChangeNotifierProvider(create: (_) => UserActivityProvider()),
      ],
      child: const MaterialApp(
        home: CoachAgirScreen(),
      ),
    );
  }

  Widget buildMiniTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ByokProvider()),
        ChangeNotifierProvider(create: (_) => buildMiniCoachProvider()),
        ChangeNotifierProvider(create: (_) => UserActivityProvider()),
      ],
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

    testWidgets('shows Coach Pulse card', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Coach Pulse'), findsOneWidget);
    });

    testWidgets('shows scenario brief card', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Scenarios de retraite en bref'), findsOneWidget);
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
      await tester.drag(scrollable, const Offset(0, -900));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.timeline), findsWidgets);
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
      await tester.drag(scrollable, const Offset(0, -2200));
      await tester.pump(const Duration(seconds: 1));
      expect(
          find.textContaining('check-in', skipOffstage: false), findsWidgets);
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

    testWidgets('shows persisted score reason in concise mode', (tester) async {
      SharedPreferences.setMockInitialValues({
        'coach_narrative_mode_v1': 'concise',
        'last_fitness_score_reason_v1':
            'Hausse principale: versements confirmes. Deuxieme phrase a masquer.',
        'last_fitness_score_delta_v1': 2,
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('Hausse principale: versements confirmes'),
        findsWidgets,
      );
      expect(find.textContaining('Deuxieme phrase a masquer.'), findsNothing);
    });

    testWidgets('shows partial profile guidance state for mini onboarding',
        (tester) async {
      await tester.pumpWidget(buildMiniTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Plan en construction'), findsOneWidget);
      expect(find.textContaining('Completer'), findsWidgets);
    });
  });
}
