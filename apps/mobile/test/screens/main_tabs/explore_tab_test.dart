import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/main_tabs/explore_tab.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

// ────────────────────────────────────────────────────────────
//  EXPLORE TAB — Widget Tests
// ────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildExploreTab() {
    return ChangeNotifierProvider<CoachProfileProvider>(
      create: (_) => CoachProfileProvider(),
      child: const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(body: ExploreTab()),
      ),
    );
  }

  group('ExploreTab — rendering', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildExploreTab());
      await tester.pump();
      expect(find.byType(ExploreTab), findsOneWidget);
    });

    testWidgets('shows tab title in app bar', (tester) async {
      await tester.pumpWidget(buildExploreTab());
      await tester.pump();
      // The tab title from l10n key tabExplore
      expect(find.byType(SliverAppBar), findsOneWidget);
    });

    testWidgets('renders 7 hub cards', (tester) async {
      await tester.pumpWidget(buildExploreTab());
      await tester.pump();
      // 7 hubs = 7 MintSurface cards (inside _ExploreHubCard)
      expect(find.byType(MintSurface), findsNWidgets(7));
    });

    testWidgets('shows Retraite hub icon', (tester) async {
      await tester.pumpWidget(buildExploreTab());
      await tester.pump();
      expect(find.byIcon(Icons.beach_access_outlined), findsOneWidget);
    });

    testWidgets('shows Famille hub icon', (tester) async {
      await tester.pumpWidget(buildExploreTab());
      await tester.pump();
      expect(find.byIcon(Icons.family_restroom_outlined), findsOneWidget);
    });

    testWidgets('shows Travail hub icon', (tester) async {
      await tester.pumpWidget(buildExploreTab());
      await tester.pump();
      expect(find.byIcon(Icons.work_outline), findsOneWidget);
    });

    testWidgets('shows Logement hub icon', (tester) async {
      await tester.pumpWidget(buildExploreTab());
      await tester.pump();
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    });

    testWidgets('shows Fiscalite hub icon', (tester) async {
      await tester.pumpWidget(buildExploreTab());
      await tester.pump();
      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
    });

    testWidgets('shows Patrimoine hub icon', (tester) async {
      await tester.pumpWidget(buildExploreTab());
      await tester.pump();
      expect(find.byIcon(Icons.account_balance_outlined), findsOneWidget);
    });

    testWidgets('shows Sante hub icon', (tester) async {
      await tester.pumpWidget(buildExploreTab());
      await tester.pump();
      expect(find.byIcon(Icons.health_and_safety_outlined), findsOneWidget);
    });
  });

  group('ExploreTab — hub card structure', () {
    testWidgets('each hub card has forward arrow', (tester) async {
      await tester.pumpWidget(buildExploreTab());
      await tester.pump();
      // 7 hub cards each have an arrow_forward_rounded icon
      expect(find.byIcon(Icons.arrow_forward_rounded), findsNWidgets(7));
    });

    testWidgets('hub cards are tappable via GestureDetector', (tester) async {
      await tester.pumpWidget(buildExploreTab());
      await tester.pump();
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('uses CustomScrollView for scrolling', (tester) async {
      await tester.pumpWidget(buildExploreTab());
      await tester.pump();
      expect(find.byType(CustomScrollView), findsOneWidget);
    });
  });
}
