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
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
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
}
