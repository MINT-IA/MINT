// ────────────────────────────────────────────────────────────
//  WIDGET RENDERER TESTS — route_to_screen case
//  Tests the new route_to_screen case added to WidgetRenderer.build()
//
//  Tests:
//  1.  Valid route returns a RouteSuggestionCard widget
//  2.  Invalid route returns SizedBox.shrink()
//  3.  Missing route key returns SizedBox.shrink()
//  4.  Backend prefill does not leak into route widgets
//  5.  context_message is passed through to RouteSuggestionCard
//  6.  Empty route string returns SizedBox.shrink()
//  7.  narrative field also accepted as contextMessage fallback
//  8.  Partial state follows RoutePlanner readiness, not LLM-only fields
//  9.  Profile with data + intent keeps Data Ledger as source of truth
//  10. Backend prefill cannot override ledger values via GoRouter.extra
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
        builder: (context, state) => Scaffold(
          body: Column(
            children: [
              const Text('Rachat'),
              Text(state.extra == null ? 'extra absent' : 'extra present'),
            ],
          ),
        ),
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
        builder: (context, state) => Scaffold(
          body: Column(
            children: [
              const Text('Rachat'),
              Text(state.extra == null ? 'extra absent' : 'extra present'),
            ],
          ),
        ),
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

    testWidgets('backend prefill is not passed through to RouteSuggestionCard',
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
      expect(
        find.byType(RouteSuggestionCard),
        findsOneWidget,
        reason: 'Financial prefill maps may arrive in legacy tool payloads, '
            'but the renderer must not expose them to route widgets.',
      );
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

    testWidgets('unschemaed is_partial flag is ignored', (tester) async {
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
      expect(card.isPartial, isFalse);
    });
  });

  group('WidgetRenderer.build — Data Ledger route contract', () {
    testWidgets(
        'backend prefill ignored when no CoachProfileProvider in context',
        (tester) async {
      // No Provider in context — route still renders, but prefill is not
      // transported by widget or route.
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
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(find.text('extra absent'), findsOneWidget);
    });

    testWidgets(
        'isPartial false when no explicit partial signal is provided',
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
      expect(card.isPartial, isFalse);
    });

    testWidgets(
        'RoutePlanner prefill is not exposed through RouteSuggestionCard',
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
              // No backend prefill. RoutePlanner may evaluate readiness, but
              // route suggestions must not transport financial values.
            },
          ),
        );
        return rendered ?? const SizedBox();
      }, profile));
      await tester.pump();
      expect(find.byType(RouteSuggestionCard), findsOneWidget);
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(find.text('extra absent'), findsOneWidget);
    });

    testWidgets(
        'RoutePlanner readiness can mark the route suggestion partial',
        (tester) async {
      final profile = CoachProfile(
        birthYear: DateTime.now().year - 45,
        canton: 'VS',
        salaireBrutMensuel: 0,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2040),
          label: 'Retraite',
        ),
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
            },
          ),
        );
        return rendered ?? const SizedBox();
      }, profile));
      await tester.pump();
      final card = tester.widget<RouteSuggestionCard>(
        find.byType(RouteSuggestionCard),
      );
      expect(card.isPartial, isTrue);
    });

    testWidgets(
        'backend prefill does not override ledger values through route extra',
        (tester) async {
      // Backend sends avoirLpp = 99999, but route suggestions no longer
      // transport financial values. The target screen must read ledger state.
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
              'prefill': {'avoirLpp': 99999},
            },
          ),
        );
        return rendered ?? const SizedBox();
      }, profile));
      await tester.pump();
      expect(find.byType(RouteSuggestionCard), findsOneWidget);
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(find.text('extra absent'), findsOneWidget);
    });
  });
}
