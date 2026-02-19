import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Screens under test
import 'package:mint_mobile/screens/coach/coach_dashboard_screen.dart';
import 'package:mint_mobile/screens/coach/coach_agir_screen.dart';
import 'package:mint_mobile/screens/coach/coach_checkin_screen.dart';

// Providers
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/byok_provider.dart';

void main() {
  // ── Helpers ──────────────────────────────────────────────────
  Widget buildTestable(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CoachProfileProvider()),
        ChangeNotifierProvider(create: (_) => ByokProvider()),
      ],
      child: MaterialApp(home: child),
    );
  }

  Widget buildWithProfile(Widget child) {
    final provider = CoachProfileProvider();
    // Seed a full profile via answers
    // Keys must match fromWizardAnswers expectations (q_ prefix)
    provider.updateFromAnswers({
      'q_birth_year': 1990,
      'q_canton': 'ZH',
      'q_net_income_period_chf': 7000.0,
      'q_employment_status': 'employee',
      'q_civil_status': 'celibataire',
      'q_children': 0,
      'q_housing_cost_period_chf': 1500.0,
      'q_has_pension_fund': 'yes',
      'q_has_3a': 'yes',
      'q_3a_annual_contribution': 7056.0,
      'q_emergency_fund': 'yes_3months',
      'q_goal_type': 'retraite',
      'q_goal_date': '2055-12-31',
    });

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: provider),
        ChangeNotifierProvider(create: (_) => ByokProvider()),
      ],
      child: MaterialApp(home: child),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ═══════════════════════════════════════════════════════════════
  //  DASHBOARD SMOKE TESTS
  // ═══════════════════════════════════════════════════════════════

  group('CoachDashboardScreen', () {
    testWidgets('renders without profile (empty state)', (tester) async {
      await tester.pumpWidget(
        buildTestable(const CoachDashboardScreen()),
      );
      await tester.pump();

      expect(find.byType(CoachDashboardScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('renders with full profile', (tester) async {
      await tester.pumpWidget(
        buildWithProfile(const CoachDashboardScreen()),
      );
      await tester.pump();

      expect(find.byType(CoachDashboardScreen), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  AGIR SCREEN SMOKE TESTS
  // ═══════════════════════════════════════════════════════════════

  group('CoachAgirScreen', () {
    testWidgets('renders without profile (empty state)', (tester) async {
      await tester.pumpWidget(
        buildTestable(const CoachAgirScreen()),
      );
      await tester.pump();

      expect(find.byType(CoachAgirScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('renders with full profile', (tester) async {
      await tester.pumpWidget(
        buildWithProfile(const CoachAgirScreen()),
      );
      await tester.pump();

      expect(find.byType(CoachAgirScreen), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  CHECK-IN SCREEN SMOKE TESTS
  // ═══════════════════════════════════════════════════════════════

  group('CoachCheckinScreen', () {
    testWidgets('renders without profile', (tester) async {
      await tester.pumpWidget(
        buildTestable(const CoachCheckinScreen()),
      );
      await tester.pump();

      expect(find.byType(CoachCheckinScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('renders with full profile', (tester) async {
      await tester.pumpWidget(
        buildWithProfile(const CoachCheckinScreen()),
      );
      await tester.pump();

      expect(find.byType(CoachCheckinScreen), findsOneWidget);
    });
  });
}
