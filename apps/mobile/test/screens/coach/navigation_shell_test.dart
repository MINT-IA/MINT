import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:mint_mobile/screens/main_navigation_shell.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/models/profile.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Wraps the shell with all required providers and localization.
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
        ChangeNotifierProvider<BudgetProvider>(
            create: (_) => BudgetProvider()),
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
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(MainNavigationShell), findsOneWidget);
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('renders 4 tab items in bottom navigation', (tester) async {
      await tester.pumpWidget(buildTestableShell());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Exactly 4 tab labels must be present
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Agir'), findsOneWidget);
      expect(find.text('Apprendre'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);
    });

    testWidgets('each tab label is correct', (tester) async {
      await tester.pumpWidget(buildTestableShell());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify all 4 expected labels and none of the old ones
      final expectedLabels = ['Dashboard', 'Agir', 'Apprendre', 'Profil'];
      for (final label in expectedLabels) {
        expect(find.text(label), findsOneWidget,
            reason: 'Tab label "$label" should appear exactly once');
      }

      // Old tab labels should NOT appear as tab labels
      expect(find.text('MAINTENANT'), findsNothing,
          reason: 'Old tab label MAINTENANT should be removed');
      expect(find.text('SUIVRE'), findsNothing,
          reason: 'Old tab label SUIVRE should be removed');
    });

    testWidgets('tapping each tab switches content', (tester) async {
      await tester.pumpWidget(buildTestableShell());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Tab 0 (Dashboard) is active by default — check for dashboard content
      expect(find.textContaining('Bonjour'), findsWidgets,
          reason: 'Dashboard shows greeting');

      // Tap Tab 1 (Agir)
      await tester.tap(find.text('Agir'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Agir tab should show its content (AGIR header or timeline)
      expect(find.text('AGIR'), findsOneWidget,
          reason: 'Agir tab content should be visible');

      // Tap Tab 2 (Apprendre)
      await tester.tap(find.text('Apprendre'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Apprendre tab should show explorer content
      expect(find.text('EXPLORER'), findsOneWidget,
          reason: 'Apprendre tab shows EXPLORER header');

      // Tap Tab 3 (Profil)
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Profil tab should show profile content
      expect(find.byType(Scaffold), findsWidgets,
          reason: 'Profil tab renders a Scaffold');
    });
  });
}
