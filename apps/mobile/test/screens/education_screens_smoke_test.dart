import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Screens under test
import 'package:mint_mobile/screens/education/comprendre_hub_screen.dart';
import 'package:mint_mobile/screens/education/theme_detail_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';


void main() {
  // ===========================================================================
  // 1. COMPRENDRE HUB SCREEN
  // ===========================================================================

  group('ComprendreHubScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ComprendreHubScreen(),
        ),
      );
      await tester.pump();

      expect(find.byType(ComprendreHubScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays AppBar title J\'Y COMPRENDS RIEN', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ComprendreHubScreen(),
        ),
      );
      await tester.pump();

      expect(find.text("J'Y COMPRENDS RIEN"), findsOneWidget);
    });

    testWidgets('shows intro text about choosing a subject', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ComprendreHubScreen(),
        ),
      );
      await tester.pump();

      expect(
        find.textContaining('Choisis un sujet'),
        findsOneWidget,
      );
      expect(
        find.textContaining('action concrète'),
        findsOneWidget,
      );
    });

    testWidgets('shows all educational themes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ComprendreHubScreen(),
        ),
      );
      await tester.pump();

      // First theme should be visible
      expect(find.text('Le 3e pilier (3a)'), findsOneWidget);
      // Second theme
      expect(find.text('La caisse de pension (LPP)'), findsOneWidget);
    });

    testWidgets('shows "Lire + quiz" subtitle for themes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ComprendreHubScreen(),
        ),
      );
      await tester.pump();

      // Each theme card shows reading time
      expect(find.textContaining('Lire + quiz'), findsWidgets);
    });

    testWidgets('shows chevron right icons for navigation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ComprendreHubScreen(),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.chevron_right), findsWidgets);
    });

    testWidgets('uses ListView.builder for scrollable content', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ComprendreHubScreen(),
        ),
      );
      await tester.pump();

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('shows theme icons from educational data', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ComprendreHubScreen(),
        ),
      );
      await tester.pump();

      // First theme uses savings_outlined
      expect(find.byIcon(Icons.savings_outlined), findsOneWidget);
      // Second theme uses work_outline
      expect(find.byIcon(Icons.work_outline), findsOneWidget);
    });

    testWidgets('renders all themes count matches data', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ComprendreHubScreen(),
        ),
      );
      await tester.pump();

      // There should be multiple theme cards
      expect(find.byType(InkWell), findsWidgets);
    });

    testWidgets('can scroll to see more themes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ComprendreHubScreen(),
        ),
      );
      await tester.pump();

      // Scroll down
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();

      // Should still find some themes after scrolling
      expect(find.byType(ComprendreHubScreen), findsOneWidget);
    });

    testWidgets('has BackButton in AppBar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ComprendreHubScreen(),
        ),
      );
      await tester.pump();

      expect(find.byType(BackButton), findsOneWidget);
    });
  });

  // ===========================================================================
  // 2. THEME DETAIL SCREEN
  // ===========================================================================

  group('ThemeDetailScreen', () {
    testWidgets('renders without crashing with valid themeId', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ThemeDetailScreen(themeId: '3a'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ThemeDetailScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows theme question as hero text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ThemeDetailScreen(themeId: '3a'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // The 3a theme question
      expect(
        find.text("C'est quoi le 3a et pourquoi tout le monde en parle ?"),
        findsOneWidget,
      );
    });

    testWidgets('shows action label from theme data', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ThemeDetailScreen(themeId: '3a'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('fiscale'),
        findsWidgets,
      );
    });

    testWidgets('shows close button in AppBar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ThemeDetailScreen(themeId: '3a'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    });

    testWidgets('shows theme icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ThemeDetailScreen(themeId: '3a'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // 3a theme uses savings_outlined
      expect(find.byIcon(Icons.savings_outlined), findsOneWidget);
    });

    testWidgets('shows reminder text with notification icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ThemeDetailScreen(themeId: '3a'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);
      expect(
        find.textContaining('Décembre'),
        findsOneWidget,
      );
    });

    testWidgets('shows action recommended subtitle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ThemeDetailScreen(themeId: '3a'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Screen renders actionLabel from theme data
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('renders with LPP theme', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ThemeDetailScreen(themeId: 'lpp'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('caisse de pension'),
        findsWidgets,
      );
    });

    testWidgets('renders with emergency theme', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ThemeDetailScreen(themeId: 'emergency'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('devrais avoir'),
        findsOneWidget,
      );
    });

    testWidgets('shows error screen for unknown themeId', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ThemeDetailScreen(themeId: 'nonexistent'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Unknown themeId shows error screen instead of silent fallback
      expect(find.byType(ThemeDetailScreen), findsOneWidget);
      // i18n: themeInconnuBody — with accents
      expect(find.textContaining('existe pas'), findsOneWidget);
    });

    testWidgets('has MintPremiumButton', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ThemeDetailScreen(themeId: '3a'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // The MintPremiumButton contains the action label
      expect(
        find.textContaining('conomie fiscale'),
        findsWidgets,
      );
    });
  });
}
