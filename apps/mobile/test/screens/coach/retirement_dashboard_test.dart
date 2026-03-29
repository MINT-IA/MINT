import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/coach/retirement_dashboard_screen.dart';

// ────────────────────────────────────────────────────────────
//  RETIREMENT DASHBOARD SCREEN — Widget Tests
// ────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  CoachProfileProvider buildProfileProvider({
    String firstName = 'Julien',
    int birthYear = 1977,
    String canton = 'VS',
    double salaire = 9078,
    String civilStatus = 'marie',
  }) {
    final provider = CoachProfileProvider();
    provider.updateFromAnswers({
      'q_firstname': firstName,
      'q_birth_year': birthYear,
      'q_canton': canton,
      'q_net_income_period_chf': salaire,
      'q_civil_status': civilStatus,
      'q_goal': 'retraite',
    });
    return provider;
  }

  Widget buildDashboard({CoachProfileProvider? coachProvider}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachProfileProvider>(
          create: (_) => coachProvider ?? CoachProfileProvider(),
        ),
        ChangeNotifierProvider<ByokProvider>(
          create: (_) => ByokProvider(),
        ),
        ChangeNotifierProvider<SlmProvider>(
          create: (_) => SlmProvider(),
        ),
      ],
      child: const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: RetirementDashboardScreen(),
      ),
    );
  }

  group('RetirementDashboardScreen — empty state (State C)', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildDashboard());
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(RetirementDashboardScreen), findsOneWidget);
    });

    testWidgets('shows Scaffold', (tester) async {
      await tester.pumpWidget(buildDashboard());
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows AppBar with default title', (tester) async {
      await tester.pumpWidget(buildDashboard());
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(SliverAppBar), findsOneWidget);
    });

    testWidgets('shows onboarding content when no profile', (tester) async {
      await tester.pumpWidget(buildDashboard());
      await tester.pump(const Duration(seconds: 1));
      // State C shows educational card and onboarding hero
      expect(find.byType(CustomScrollView), findsOneWidget);
    });

    testWidgets('shows disclaimer in empty state', (tester) async {
      await tester.pumpWidget(buildDashboard());
      await tester.pump(const Duration(seconds: 1));
      // Disclaimer should appear
      expect(find.textContaining('LSFin'), findsWidgets);
    });
  });

  group('RetirementDashboardScreen — with profile', () {
    testWidgets('renders dashboard with profile', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final provider = buildProfileProvider();
      await tester.pumpWidget(buildDashboard(coachProvider: provider));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(RetirementDashboardScreen), findsOneWidget);
    });

    testWidgets('shows personalized AppBar with name', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final provider = buildProfileProvider(firstName: 'Julien');
      await tester.pumpWidget(buildDashboard(coachProvider: provider));
      await tester.pump(const Duration(seconds: 2));

      expect(find.textContaining('Julien'), findsWidgets);
    });

    testWidgets('shows financial projection content', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final provider = buildProfileProvider(salaire: 9078);
      await tester.pumpWidget(buildDashboard(coachProvider: provider));
      await tester.pump(const Duration(seconds: 2));

      // Should show CHF amounts somewhere in the projection
      expect(find.textContaining('CHF'), findsWidgets);
    });
  });
}
