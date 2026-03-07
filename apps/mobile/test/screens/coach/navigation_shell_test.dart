import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

import 'package:mint_mobile/screens/main_navigation_shell.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/locale_provider.dart';
import 'package:mint_mobile/providers/user_activity_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/models/profile.dart';

// ────────────────────────────────────────────────────────────
//  NAVIGATION SHELL TESTS — Phase 5 / Quality hardening
//
//  MainNavigationShell embeds RetirementDashboardScreen as tab 0,
//  which has _pulseController..repeat(reverse: true) (infinite
//  animation). We MUST use pump(Duration) not pumpAndSettle().
// ────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      // Avoid SLM download prompt modal covering the nav bar during tests.
      'slm_auto_prompt_shown': true,
    });
  });

  CoachProfileProvider _buildCoachProvider() {
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

  Widget buildTestableShell() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ProfileProvider>(create: (_) {
          final p = ProfileProvider();
          p.setProfile(Profile(
            id: 'test-user',
            householdType: HouseholdType.single,
            goal: Goal.emergency,
            createdAt: DateTime(2025, 1, 1),
            birthYear: 1990,
            canton: 'VD',
            incomeNetMonthly: 6000,
          ));
          return p;
        }),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<ByokProvider>(create: (_) => ByokProvider()),
        ChangeNotifierProvider<DocumentProvider>(
            create: (_) => DocumentProvider()),
        ChangeNotifierProvider<BudgetProvider>(create: (_) => BudgetProvider()),
        ChangeNotifierProvider(create: (_) => _buildCoachProvider()),
        ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
        ChangeNotifierProvider<UserActivityProvider>(
            create: (_) => UserActivityProvider()),
        ChangeNotifierProvider<SlmProvider>(create: (_) => SlmProvider()),
      ],
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: const MainNavigationShell(),
      ),
    );
  }

  group('MainNavigationShell (Sprint C10 — 4 tabs)', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestableShell());
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(MainNavigationShell), findsOneWidget);
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('renders 4 tab items in bottom navigation', (tester) async {
      await tester.pumpWidget(buildTestableShell());
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Agir'), findsOneWidget);
      expect(find.text('Apprendre'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);
    });

    testWidgets('each tab label is correct', (tester) async {
      await tester.pumpWidget(buildTestableShell());
      await tester.pump(const Duration(seconds: 2));

      final expectedLabels = ['Dashboard', 'Agir', 'Apprendre', 'Profil'];
      for (final label in expectedLabels) {
        expect(find.text(label), findsOneWidget,
            reason: 'Tab label "$label" should appear exactly once');
      }

      expect(find.text('MAINTENANT'), findsNothing,
          reason: 'Old tab label MAINTENANT should be removed');
      expect(find.text('SUIVRE'), findsNothing,
          reason: 'Old tab label SUIVRE should be removed');
    });

    testWidgets('tapping each tab switches content', (tester) async {
      await tester.pumpWidget(buildTestableShell());
      await tester.pump(const Duration(seconds: 2));

      // Tab 0 (Dashboard) is active by default
      // RetirementDashboardScreen shows "Retraite · {name}" or "Ma retraite"
      expect(
        find.textContaining('etraite', findRichText: true),
        findsWidgets,
        reason: 'Dashboard tab shows retirement content',
      );

      // Tap Tab 1 (Agir)
      await tester.tap(find.text('Agir'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(Scaffold), findsWidgets,
          reason: 'Agir tab content should be visible');

      // Tap Tab 2 (Apprendre)
      await tester.tap(find.text('Apprendre'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(Scaffold), findsWidgets,
          reason: 'Apprendre tab content should be visible');

      // Tap Tab 3 (Profil)
      await tester.tap(find.text('Profil'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(Scaffold), findsWidgets,
          reason: 'Profil tab renders a Scaffold');
    });
  });
}
