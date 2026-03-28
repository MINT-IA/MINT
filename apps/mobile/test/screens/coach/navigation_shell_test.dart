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
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/models/profile.dart';

// ────────────────────────────────────────────────────────────
//  NAVIGATION SHELL TESTS — S52 (4 tabs: Aujourd'hui, Coach, Explorer, Dossier)
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
        ChangeNotifierProvider<MintStateProvider>(
            create: (_) => MintStateProvider()),
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

  group('MainNavigationShell (S52 — 4 tabs)', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestableShell());
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(MainNavigationShell), findsOneWidget);
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('renders 4 tab items in bottom navigation', (tester) async {
      await tester.pumpWidget(buildTestableShell());
      await tester.pump(const Duration(seconds: 2));

      // S52: 4 tabs — Aujourd'hui, MINT (Coach), Explorer, Dossier
      expect(find.text('Aujourd\'hui'), findsOneWidget);
      expect(find.text('Mint'), findsOneWidget);
      expect(find.text('Explorer'), findsOneWidget);
      expect(find.text('Dossier'), findsOneWidget);
    });

    testWidgets('old tab labels are removed', (tester) async {
      await tester.pumpWidget(buildTestableShell());
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Pulse'), findsNothing,
          reason: 'Old tab label Pulse replaced by Aujourd\'hui');
      expect(find.text('Coach'), findsNothing,
          reason: 'Old tab label Coach replaced by Mint');
      expect(find.text('Moi'), findsNothing,
          reason: 'Old tab label Moi replaced by Dossier');
    });

    testWidgets('tapping each tab switches content', (tester) async {
      await tester.pumpWidget(buildTestableShell());
      await tester.pump(const Duration(seconds: 2));

      // Tab 0 (Aujourd'hui) is active by default
      expect(find.byType(Scaffold), findsWidgets);

      // Tap Tab 1 (MINT)
      await tester.tap(find.text('Mint'));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(Scaffold), findsWidgets);

      // Tap Tab 2 (Explorer)
      await tester.tap(find.text('Explorer'));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(Scaffold), findsWidgets);

      // Tap Tab 3 (Dossier)
      await tester.tap(find.text('Dossier'));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}
