// ────────────────────────────────────────────────────────────
//  WIDGET RENDERER TESTS — route_to_screen case
//  Tests the new route_to_screen case added to WidgetRenderer.build()
//
//  Tests:
//  1.  Valid route returns a RouteSuggestionCard widget
//  2.  Invalid route returns SizedBox.shrink()
//  3.  Missing route key returns SizedBox.shrink()
//  4.  Prefill data is passed through to RouteSuggestionCard
//  5.  context_message is passed through to RouteSuggestionCard
//  6.  Empty route string returns SizedBox.shrink()
//  7.  narrative field also accepted as contextMessage fallback
//  8.  Backend prefill present, no profile → backend prefill passed through
//  9.  Profile with data + intent → RoutePlanner prefill merged
//  10. Backend prefill wins over RoutePlanner on key conflict
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/widgets/coach/widget_renderer.dart';
import 'package:mint_mobile/widgets/coach/route_suggestion_card.dart';

// ────────────────────────────────────────────────────────────
//  TEST HELPERS
// ────────────────────────────────────────────────────────────

/// Wraps a widget in a minimal app with i18n and GoRouter stub.
Widget _buildTestApp(Widget Function(BuildContext) builder) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(body: builder(context)),
      ),
      GoRoute(
        path: '/rente-vs-capital',
        builder: (context, state) => const Scaffold(body: Text('Rente')),
      ),
      GoRoute(
        path: '/rachat-lpp',
        builder: (context, state) => const Scaffold(body: Text('Rachat')),
      ),
    ],
  );

  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr')],
  );
}

/// A test-only provider subclass that exposes a direct profile setter.
///
/// Avoids SharedPreferences / SecureStorage setup in widget tests.
class _TestCoachProfileProvider extends CoachProfileProvider {
  CoachProfile? _testProfile;

  void setTestProfile(CoachProfile p) {
    _testProfile = p;
    notifyListeners();
  }

  @override
  CoachProfile? get profile => _testProfile;
}

/// Wraps a widget with a [_TestCoachProfileProvider] pre-loaded with [profile].
Widget _buildTestAppWithProfile(
  Widget Function(BuildContext) builder,
  CoachProfile profile,
) {
  final provider = _TestCoachProfileProvider()..setTestProfile(profile);

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(body: builder(context)),
      ),
      GoRoute(
        path: '/rente-vs-capital',
        builder: (context, state) => const Scaffold(body: Text('Rente')),
      ),
      GoRoute(
        path: '/rachat-lpp',
        builder: (context, state) => const Scaffold(body: Text('Rachat')),
      ),
    ],
  );

  return ChangeNotifierProvider<CoachProfileProvider>.value(
    value: provider,
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr')],
    ),
  );
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WidgetRenderer.build — route_to_screen', () {
    testWidgets('valid route returns RouteSuggestionCard', (tester) async {
      late Widget? rendered;
      await tester.pumpWidget(_buildTestApp((context) {
        rendered = WidgetRenderer.build(
          context,
          const RagToolCall(
            name: 'route_to_screen',
            input: {
              'route': '/rente-vs-capital',
              'context_message': 'Voici ton simulateur',
            },
          ),
        );
        return rendered ?? const SizedBox();
      }));
      await tester.pump();
      expect(find.byType(RouteSuggestionCard), findsOneWidget);
    });

    testWidgets('invalid route returns SizedBox.shrink()', (tester) async {
      late Widget? rendered;
      await tester.pumpWidget(_buildTestApp((context) {
        rendered = WidgetRenderer.build(
          context,
          const RagToolCall(
            name: 'route_to_screen',
            input: {'route': '/admin/evil'},
          ),
        );
        return rendered ?? const SizedBox(key: Key('outer'));
      }));
      await tester.pump();
      // SizedBox.shrink() has zero size — RouteSuggestionCard should NOT appear
      expect(find.byType(RouteSuggestionCard), findsNothing);
    });

    testWidgets('missing route key returns SizedBox.shrink()', (tester) async {
      late Widget? rendered;
      await tester.pumpWidget(_buildTestApp((context) {
        rendered = WidgetRenderer.build(
          context,
          const RagToolCall(
            name: 'route_to_screen',
            input: {},
          ),
        );
        return rendered ?? const SizedBox(key: Key('outer'));
      }));
      await tester.pump();
      expect(find.byType(RouteSuggestionCard), findsNothing);
    });

    testWidgets('prefill data is passed through to RouteSuggestionCard',
        (tester) async {
      late Widget? rendered;
      await tester.pumpWidget(_buildTestApp((context) {
        rendered = WidgetRenderer.build(
          context,
          const RagToolCall(
            name: 'route_to_screen',
            input: {
              'route': '/rachat-lpp',
              'prefill': {'avoirLpp': 70377},
            },
          ),
        );
        return rendered ?? const SizedBox();
      }));
      await tester.pump();
      expect(find.byType(RouteSuggestionCard), findsOneWidget);
      final card = tester.widget<RouteSuggestionCard>(
        find.byType(RouteSuggestionCard),
      );
      expect(card.prefill, {'avoirLpp': 70377});
    });

    testWidgets('context_message is passed to RouteSuggestionCard',
        (tester) async {
      late Widget? rendered;
      await tester.pumpWidget(_buildTestApp((context) {
        rendered = WidgetRenderer.build(
          context,
          const RagToolCall(
            name: 'route_to_screen',
            input: {
              'route': '/rente-vs-capital',
              'context_message': 'Message de contexte',
            },
          ),
        );
        return rendered ?? const SizedBox();
      }));
      await tester.pump();
      final card = tester.widget<RouteSuggestionCard>(
        find.byType(RouteSuggestionCard),
      );
      expect(card.contextMessage, 'Message de contexte');
    });

    testWidgets('empty route string returns SizedBox.shrink()', (tester) async {
      late Widget? rendered;
      await tester.pumpWidget(_buildTestApp((context) {
        rendered = WidgetRenderer.build(
          context,
          const RagToolCall(
            name: 'route_to_screen',
            input: {'route': ''},
          ),
        );
        return rendered ?? const SizedBox(key: Key('outer'));
      }));
      await tester.pump();
      expect(find.byType(RouteSuggestionCard), findsNothing);
    });

    testWidgets('narrative field accepted as contextMessage fallback',
        (tester) async {
      late Widget? rendered;
      await tester.pumpWidget(_buildTestApp((context) {
        rendered = WidgetRenderer.build(
          context,
          const RagToolCall(
            name: 'route_to_screen',
            input: {
              'route': '/rente-vs-capital',
              'narrative': 'Narration de secours',
            },
          ),
        );
        return rendered ?? const SizedBox();
      }));
      await tester.pump();
      final card = tester.widget<RouteSuggestionCard>(
        find.byType(RouteSuggestionCard),
      );
      expect(card.contextMessage, 'Narration de secours');
    });

    testWidgets('is_partial flag is passed through', (tester) async {
      late Widget? rendered;
      await tester.pumpWidget(_buildTestApp((context) {
        rendered = WidgetRenderer.build(
          context,
          const RagToolCall(
            name: 'route_to_screen',
            input: {
              'route': '/rente-vs-capital',
              'is_partial': true,
            },
          ),
        );
        return rendered ?? const SizedBox();
      }));
      await tester.pump();
      final card = tester.widget<RouteSuggestionCard>(
        find.byType(RouteSuggestionCard),
      );
      expect(card.isPartial, isTrue);
    });
  });

  group('WidgetRenderer.build — prefill pipeline (T-06-01)', () {
    testWidgets(
        'backend prefill preserved when no CoachProfileProvider in context',
        (tester) async {
      // No Provider in context — catch block fires, backend prefill kept.
      late Widget? rendered;
      await tester.pumpWidget(_buildTestApp((context) {
        rendered = WidgetRenderer.build(
          context,
          const RagToolCall(
            name: 'route_to_screen',
            input: {
              'route': '/rachat-lpp',
              'prefill': {'avoirLpp': 70377, 'salaireBrut': 91967},
            },
          ),
        );
        return rendered ?? const SizedBox();
      }));
      await tester.pump();
      expect(find.byType(RouteSuggestionCard), findsOneWidget);
      final card = tester.widget<RouteSuggestionCard>(
        find.byType(RouteSuggestionCard),
      );
      expect(card.prefill, {'avoirLpp': 70377, 'salaireBrut': 91967});
    });

    testWidgets(
        'isPartial true when mergedPrefill is null (no backend prefill, no profile)',
        (tester) async {
      late Widget? rendered;
      await tester.pumpWidget(_buildTestApp((context) {
        rendered = WidgetRenderer.build(
          context,
          const RagToolCall(
            name: 'route_to_screen',
            input: {
              'route': '/rente-vs-capital',
              // No prefill key, no intent key
              'context_message': 'Test',
            },
          ),
        );
        return rendered ?? const SizedBox();
      }));
      await tester.pump();
      expect(find.byType(RouteSuggestionCard), findsOneWidget);
      final card = tester.widget<RouteSuggestionCard>(
        find.byType(RouteSuggestionCard),
      );
      expect(card.isPartial, isTrue);
    });

    testWidgets(
        'RoutePlanner prefill injected when profile has required fields',
        (tester) async {
      // Build a minimal CoachProfile with fields that `lpp_buyback` entry needs.
      // lpp_buyback requiredFields: ['salaireBrut', 'age', 'canton']
      // RoutePlanner._resolveProfileValue('salaireBrut') → salaireBrutMensuel
      final profile = CoachProfile(
        birthYear: DateTime.now().year - 45, // age = 45
        canton: 'VS',
        salaireBrutMensuel: 7500,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2040),
          label: 'Retraite',
        ),
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 70000),
      );

      late Widget? rendered;
      await tester.pumpWidget(_buildTestAppWithProfile((context) {
        rendered = WidgetRenderer.build(
          context,
          const RagToolCall(
            name: 'route_to_screen',
            input: {
              'route': '/rachat-lpp',
              'intent': 'lpp_buyback',
              // No backend prefill — Flutter-side RoutePlanner should supply it
            },
          ),
        );
        return rendered ?? const SizedBox();
      }, profile));
      await tester.pump();
      expect(find.byType(RouteSuggestionCard), findsOneWidget);
      final card = tester.widget<RouteSuggestionCard>(
        find.byType(RouteSuggestionCard),
      );
      // RoutePlanner should have populated at least the 'salaireBrut' key
      expect(card.prefill, isNotNull);
      expect(card.prefill, isA<Map<String, dynamic>>());
    });

    testWidgets(
        'backend prefill wins over RoutePlanner prefill on same key',
        (tester) async {
      // Backend sends avoirLpp = 99999 — should override RoutePlanner's value.
      final profile = CoachProfile(
        birthYear: DateTime.now().year - 45,
        canton: 'VS',
        salaireBrutMensuel: 7500,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2040),
          label: 'Retraite',
        ),
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 70000),
      );

      late Widget? rendered;
      await tester.pumpWidget(_buildTestAppWithProfile((context) {
        rendered = WidgetRenderer.build(
          context,
          const RagToolCall(
            name: 'route_to_screen',
            input: {
              'route': '/rachat-lpp',
              'intent': 'lpp_buyback',
              'prefill': {'avoirLpp': 99999}, // backend value — must win
            },
          ),
        );
        return rendered ?? const SizedBox();
      }, profile));
      await tester.pump();
      expect(find.byType(RouteSuggestionCard), findsOneWidget);
      final card = tester.widget<RouteSuggestionCard>(
        find.byType(RouteSuggestionCard),
      );
      expect(card.prefill, isNotNull);
      // Backend value MUST override RoutePlanner value for this key
      expect(card.prefill!['avoirLpp'], 99999);
    });
  });
}
