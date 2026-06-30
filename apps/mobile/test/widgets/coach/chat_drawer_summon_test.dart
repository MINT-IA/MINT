import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/arbitrage/rente_vs_capital_screen.dart';
import 'package:mint_mobile/screens/coach/retirement_dashboard_screen.dart';
import 'package:mint_mobile/screens/confidence/confidence_dashboard_screen.dart';
import 'package:mint_mobile/screens/fiscal_comparator_screen.dart';
import 'package:mint_mobile/screens/lpp_deep/rachat_echelonne_screen.dart';
import 'package:mint_mobile/screens/mortgage/affordability_screen.dart';
import 'package:mint_mobile/screens/simulator_3a_screen.dart';
import 'package:mint_mobile/widgets/coach/chat_drawer_host.dart';

// ────────────────────────────────────────────────────────────
//  CHAT DRAWER SUMMON TESTS — CHAT-02 (Phase 3)
//
//  Verifies:
//  1. showChatDrawer opens a bottom sheet with the target widget
//  2. resolveDrawerWidget maps known routes to real widgets
//  3. resolved widgets build inside the drawer app scope
//  4. resolveDrawerWidget returns null for unknown routes
//  5. Drawer dismisses back to underlying screen
// ────────────────────────────────────────────────────────────

void main() {
  group('ChatDrawerHost.resolveDrawerWidget', () {
    test('resolves /pilier-3a to a widget', () {
      final widget = ChatDrawerHost.resolveDrawerWidget('/pilier-3a');
      expect(widget, isA<Simulator3aScreen>());
    });

    test('resolves /retraite to a widget', () {
      final widget = ChatDrawerHost.resolveDrawerWidget('/retraite');
      expect(widget, isA<RetirementDashboardScreen>());
    });

    test('does not resolve /budget to a drawer target', () {
      final widget = ChatDrawerHost.resolveDrawerWidget('/budget');
      expect(widget, isNull);
    });

    test('returns null for unknown route', () {
      final widget = ChatDrawerHost.resolveDrawerWidget('/unknown/route');
      expect(widget, isNull);
    });

    test('returns null for empty route', () {
      final widget = ChatDrawerHost.resolveDrawerWidget('');
      expect(widget, isNull);
    });

    test('strips query params for matching', () {
      final widget =
          ChatDrawerHost.resolveDrawerWidget('/retraite?mode=preretraite');
      expect(widget, isA<RetirementDashboardScreen>());
    });

    testWidgets('resolved real drawer screens build in app scope',
        (tester) async {
      final routes = <String, Type>{
        '/pilier-3a': Simulator3aScreen,
        '/rachat-lpp': RachatEchelonneScreen,
        '/retraite': RetirementDashboardScreen,
        '/retraite/rente-vs-capital': RenteVsCapitalScreen,
        '/fiscal': FiscalComparatorScreen,
        '/hypotheque': AffordabilityScreen,
      };

      for (final entry in routes.entries) {
        await tester.pumpWidget(
          _buildDrawerTestApp(
            ChatDrawerHost.resolveDrawerWidget(entry.key)!,
          ),
        );
        await tester.pump();

        expect(find.byType(entry.value), findsOneWidget);
        expect(tester.takeException(), isNull, reason: entry.key);
      }
    });
  });

  group('showChatDrawer', () {
    testWidgets('opens a bottom sheet with drag handle', (tester) async {
      await tester.pumpWidget(
        _buildDrawerTestApp(
          Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showChatDrawer(
                    context: context,
                    child: const Text('Drawer Content'),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Drawer Content'), findsOneWidget);
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    });

    testWidgets('opens a resolved confidence drawer with provider scope',
        (tester) async {
      await tester.pumpWidget(
        _buildDrawerTestApp(
          Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showChatDrawer(
                    context: context,
                    child: ChatDrawerHost.resolveDrawerWidget('/confidence')!,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(ConfidenceDashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows optional title when provided', (tester) async {
      await tester.pumpWidget(
        _buildDrawerTestApp(
          Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showChatDrawer(
                    context: context,
                    child: const Text('Content'),
                    title: 'Mon 3a',
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Mon 3a'), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('dismisses on swipe down', (tester) async {
      await tester.pumpWidget(
        _buildDrawerTestApp(
          Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showChatDrawer(
                    context: context,
                    child: const Text('Drawer Content'),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Drawer Content'), findsOneWidget);

      await tester.drag(
        find.byType(DraggableScrollableSheet),
        const Offset(0, 500),
      );
      await tester.pumpAndSettle();

      expect(find.text('Drawer Content'), findsNothing);
    });
  });
}

Widget _buildDrawerTestApp(Widget child) {
  final provider = _TestCoachProfileProvider()
    ..setTestProfile(
      CoachProfile(
        birthYear: 1981,
        canton: 'VS',
        salaireBrutMensuel: 7500,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 70000,
          avoirLppObligatoire: 45000,
          avoirLppSurobligatoire: 25000,
          salaireAssure: 72000,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2045),
          label: 'Retraite',
        ),
      ),
    );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>.value(value: provider),
      ChangeNotifierProvider<ProfileProvider>(create: (_) => ProfileProvider()),
      ChangeNotifierProvider<SlmProvider>(create: (_) => SlmProvider()),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: child,
    ),
  );
}

class _TestCoachProfileProvider extends CoachProfileProvider {
  CoachProfile? _testProfile;

  void setTestProfile(CoachProfile? profile) {
    _testProfile = profile;
    notifyListeners();
  }

  @override
  CoachProfile? get profile => _testProfile;
}
