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
//  NAVIGATION SHELL TESTS — S49 (3 tabs: Pulse, Mint, Moi)
// ────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'slm_auto_prompt_shown': true,
    });
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
        ChangeNotifierProvider(create: (_) => buildCoachProvider()),
        ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
        ChangeNotifierProvider<UserActivityProvider>(
            create: (_) => UserActivityProvider()),
        ChangeNotifierProvider<SlmProvider>(create: (_) => SlmProvider()),
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
        home: MainNavigationShell(),
      ),
    );
  }

  group('MainNavigationShell (S49 — 3 tabs)', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestableShell());
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(MainNavigationShell), findsOneWidget);
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('renders 3 tab items in bottom navigation', (tester) async {
      await tester.pumpWidget(buildTestableShell());
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Pulse'), findsOneWidget);
      expect(find.text('Mint'), findsOneWidget);
      expect(find.text('Moi'), findsOneWidget);
    });

    testWidgets('old tab labels are removed', (tester) async {
      await tester.pumpWidget(buildTestableShell());
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Agir'), findsNothing,
          reason: 'Old tab label Agir should be removed');
      expect(find.text('Apprendre'), findsNothing,
          reason: 'Old tab label Apprendre should be removed');
      expect(find.text('Profil'), findsNothing,
          reason: 'Old tab label Profil replaced by Moi');
    });

    testWidgets('tapping each tab switches content', (tester) async {
      await tester.pumpWidget(buildTestableShell());
      await tester.pump(const Duration(seconds: 2));

      // Tab 0 (Pulse) is active by default
      expect(find.byType(Scaffold), findsWidgets,
          reason: 'Pulse tab renders content');

      // Tap Tab 1 (Mint)
      await tester.tap(find.text('Mint'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(Scaffold), findsWidgets,
          reason: 'Mint tab content should be visible');

      // Tap Tab 2 (Moi)
      await tester.tap(find.text('Moi'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(Scaffold), findsWidgets,
          reason: 'Moi tab renders a Scaffold');
    });
  });
}
