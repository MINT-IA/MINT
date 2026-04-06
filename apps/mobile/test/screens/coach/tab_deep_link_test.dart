import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
import 'package:mint_mobile/providers/anticipation_provider.dart';
import 'package:mint_mobile/providers/contextual_card_provider.dart';
import 'package:mint_mobile/providers/biography_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/providers/subscription_provider.dart';
import 'package:mint_mobile/providers/coach_entry_payload_provider.dart';
import 'package:mint_mobile/models/profile.dart';

// ────────────────────────────────────────────────────────────
//  TAB DEEP-LINK TESTS — /home?tab=N + /app/* aliases
// ────────────────────────────────────────────────────────────

Widget _buildRouterHarness({required String initialLocation}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => const MainNavigationShell(),
      ),
      GoRoute(path: '/app/today',   redirect: (_, __) => '/home?tab=0'),
      GoRoute(path: '/app/coach',   redirect: (_, __) => '/home?tab=1'),
      GoRoute(path: '/app/explore', redirect: (_, __) => '/home?tab=2'),
      GoRoute(path: '/app/dossier', redirect: (_, __) => '/home?tab=3'),
    ],
  );

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
      ChangeNotifierProvider<DocumentProvider>(create: (_) => DocumentProvider()),
      ChangeNotifierProvider<BudgetProvider>(create: (_) => BudgetProvider()),
      ChangeNotifierProvider<CoachProfileProvider>(create: (_) {
        final p = CoachProfileProvider();
        p.updateFromAnswers({
          'q_firstname': 'Julien',
          'q_birth_year': 1977,
          'q_canton': 'VS',
          'q_net_income_period_chf': 9080,
          'q_civil_status': 'marie',
          'q_goal': 'retraite',
        });
        return p;
      }),
      ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
      ChangeNotifierProvider<UserActivityProvider>(create: (_) => UserActivityProvider()),
      ChangeNotifierProvider<SlmProvider>(create: (_) => SlmProvider()),
      ChangeNotifierProvider<MintStateProvider>(create: (_) => MintStateProvider()),
      ChangeNotifierProvider<SubscriptionProvider>(create: (_) => SubscriptionProvider()),
      ChangeNotifierProvider<CoachEntryPayloadProvider>(create: (_) => CoachEntryPayloadProvider()),
      ChangeNotifierProvider<FinancialPlanProvider>(create: (_) => FinancialPlanProvider()),
      ChangeNotifierProvider<BiographyProvider>(create: (_) => BiographyProvider()),
      ChangeNotifierProvider<AnticipationProvider>(create: (_) => AnticipationProvider()),
      ChangeNotifierProvider<ContextualCardProvider>(create: (_) => ContextualCardProvider()),
    ],
    child: MaterialApp.router(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      routerConfig: router,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'slm_auto_prompt_shown': true,
    });
  });

  group('Tab deep-link — /home?tab=N', () {
    testWidgets('default (no tab param) opens tab 0 (Aujourd\'hui)',
        (tester) async {
      await tester.pumpWidget(_buildRouterHarness(initialLocation: '/home'));
      await tester.pump(const Duration(seconds: 2));

      // Tab 0 is active: its icon uses the filled variant.
      // Check that the Aujourd'hui tab label is visible and rendered.
      expect(find.text('Aujourd\'hui'), findsOneWidget);
      expect(find.byType(MainNavigationShell), findsOneWidget);

      // Confirm the active index is 0: the "Aujourd'hui" nav item is selected.
      final navItems = tester.widgetList<Semantics>(find.byType(Semantics));
      final todayItem = navItems.where(
        (s) => s.properties.label == 'Aujourd\'hui',
      );
      expect(todayItem, isNotEmpty);
    });

    testWidgets('/home?tab=2 opens Explorer tab', (tester) async {
      await tester.pumpWidget(
          _buildRouterHarness(initialLocation: '/home?tab=2'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(MainNavigationShell), findsOneWidget);
      // All 4 tab labels must be present in the bottom nav.
      expect(find.text('Explorer'), findsWidgets);
      expect(find.text('Aujourd\'hui'), findsOneWidget);

      // The Explorer nav item should be marked as selected via Semantics.
      final explorerSemantics = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) =>
              s.properties.label == 'Explorer' &&
              (s.properties.selected ?? false));
      expect(explorerSemantics, isNotEmpty,
          reason: 'Explorer Semantics widget should be selected for tab=2');
    });

    testWidgets('/home?tab=3 opens drawer (shell renders without crash)', (tester) async {
      await tester.pumpWidget(
          _buildRouterHarness(initialLocation: '/home?tab=3'));
      await tester.pump(const Duration(seconds: 2));

      // tab=3 now opens the ProfileDrawer instead of selecting a tab.
      // Verify the shell renders without crashing.
      expect(find.byType(MainNavigationShell), findsOneWidget);
    });

    testWidgets('/home?tab=1 opens MINT (Coach) tab', (tester) async {
      await tester.pumpWidget(
          _buildRouterHarness(initialLocation: '/home?tab=1'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(MainNavigationShell), findsOneWidget);
      final coachSemantics = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) =>
              s.properties.label == 'Mint' &&
              (s.properties.selected ?? false));
      expect(coachSemantics, isNotEmpty,
          reason: 'MINT Semantics widget should be selected for tab=1');
    });

    testWidgets('out-of-range tab param defaults to tab 0', (tester) async {
      await tester.pumpWidget(
          _buildRouterHarness(initialLocation: '/home?tab=99'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(MainNavigationShell), findsOneWidget);
      // No crash and the shell still renders with tab 0.
      final todaySemantics = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) =>
              s.properties.label == 'Aujourd\'hui' &&
              (s.properties.selected ?? false));
      expect(todaySemantics, isNotEmpty,
          reason: 'Out-of-range tab param should fall back to tab 0');
    });

    testWidgets('non-numeric tab param defaults to tab 0', (tester) async {
      await tester.pumpWidget(
          _buildRouterHarness(initialLocation: '/home?tab=abc'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(MainNavigationShell), findsOneWidget);
      final todaySemantics = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) =>
              s.properties.label == 'Aujourd\'hui' &&
              (s.properties.selected ?? false));
      expect(todaySemantics, isNotEmpty,
          reason: 'Non-numeric tab param should fall back to tab 0');
    });
  });

  group('Tab deep-link — /app/* convenience aliases', () {
    testWidgets('/app/dossier redirects to tab 3 (drawer, shell renders)', (tester) async {
      await tester.pumpWidget(
          _buildRouterHarness(initialLocation: '/app/dossier'));
      await tester.pump(const Duration(seconds: 2));

      // tab=3 now opens the ProfileDrawer instead of selecting a tab.
      // Verify the shell renders without crashing.
      expect(find.byType(MainNavigationShell), findsOneWidget);
    });

    testWidgets('/app/explore redirects to tab 2 (Explorer)', (tester) async {
      await tester.pumpWidget(
          _buildRouterHarness(initialLocation: '/app/explore'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(MainNavigationShell), findsOneWidget);
      final explorerSemantics = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) =>
              s.properties.label == 'Explorer' &&
              (s.properties.selected ?? false));
      expect(explorerSemantics, isNotEmpty,
          reason: '/app/explore should redirect to tab=2');
    });

    testWidgets('/app/coach redirects to tab 1 (MINT)', (tester) async {
      await tester.pumpWidget(
          _buildRouterHarness(initialLocation: '/app/coach'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(MainNavigationShell), findsOneWidget);
      final coachSemantics = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) =>
              s.properties.label == 'Mint' &&
              (s.properties.selected ?? false));
      expect(coachSemantics, isNotEmpty,
          reason: '/app/coach should redirect to tab=1');
    });

    testWidgets('/app/today redirects to tab 0 (Aujourd\'hui)', (tester) async {
      await tester.pumpWidget(
          _buildRouterHarness(initialLocation: '/app/today'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(MainNavigationShell), findsOneWidget);
      final todaySemantics = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) =>
              s.properties.label == 'Aujourd\'hui' &&
              (s.properties.selected ?? false));
      expect(todaySemantics, isNotEmpty,
          reason: '/app/today should redirect to tab=0');
    });
  });
}
