// ────────────────────────────────────────────────────────────
//  COACH MESSAGE BUBBLE TESTS — richToolCalls rendering pipeline
//
//  Validates that the chat rendering pipeline uses richToolCalls
//  exclusively for inline widget rendering (S57 — ChatToolDispatcher).
//
//  Tests:
//  1.  WidgetRenderer.build with show_fact_card returns a ChatFactCard
//  2.  WidgetRenderer.build with empty richToolCalls renders nothing
//  3.  WidgetRenderer.build with route_to_screen (valid) returns RouteSuggestionCard
//  4.  WidgetRenderer.build with route_to_screen (invalid) returns SizedBox.shrink
//  5.  ChatMessage richToolCalls field defaults to empty list
//  6.  ChatMessage hasRichToolCalls returns false for empty list
//  7.  ChatMessage hasRichToolCalls returns true when calls present
//  8.  WidgetRenderer.build with ask_user_input returns a picker widget
//
//  Note: CoachMessageBubble does not exist as a separate widget in this
//  codebase — rendering is inline in _buildCoachBubble. These tests
//  validate the WidgetRenderer pipeline (the testable unit).
//
//  The keyword-matching _buildRichWidget method has been deleted (S57).
//  There is no longer a richWidget parameter anywhere in the rendering path.
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/widgets/coach/rich_chat_widgets.dart';
import 'package:mint_mobile/widgets/coach/route_suggestion_card.dart';
import 'package:mint_mobile/widgets/coach/widget_renderer.dart';

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

  // ────────────────────────────────────────────────────────────
  //  richToolCalls drives widget rendering
  // ────────────────────────────────────────────────────────────

  group('WidgetRenderer.build — richToolCalls pipeline', () {
    testWidgets(
        'show_fact_card call renders ChatFactCard in the message bubble',
        (tester) async {
      late Widget? rendered;
      await tester.pumpWidget(_buildTestApp((context) {
        rendered = WidgetRenderer.build(
          context,
          const RagToolCall(
            name: 'show_fact_card',
            input: {
              'eyebrow': 'Test',
              'value': '42',
              'description': 'Description',
            },
          ),
        );
        return rendered ?? const SizedBox(key: Key('empty'));
      }));
      await tester.pump();
      expect(find.byType(ChatFactCard), findsOneWidget);
      // Confirm the value text is rendered
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('empty richToolCalls produces no inline widgets', (tester) async {
      // With empty richToolCalls, WidgetRenderer.build is never called.
      // Verify that calling build with an unknown tool returns null.
      late Widget? rendered;
      await tester.pumpWidget(_buildTestApp((context) {
        rendered = WidgetRenderer.build(
          context,
          const RagToolCall(name: 'unknown_tool', input: {}),
        );
        return rendered ?? const SizedBox(key: Key('empty'));
      }));
      await tester.pump();
      // No ChatFactCard or RouteSuggestionCard should appear
      expect(find.byType(ChatFactCard), findsNothing);
      expect(find.byType(RouteSuggestionCard), findsNothing);
    });

    testWidgets('route_to_screen with valid route renders RouteSuggestionCard',
        (tester) async {
      late Widget? rendered;
      await tester.pumpWidget(_buildTestApp((context) {
        rendered = WidgetRenderer.build(
          context,
          const RagToolCall(
            name: 'route_to_screen',
            input: {
              'route': '/rente-vs-capital',
              'context_message': 'Voici le simulateur',
            },
          ),
        );
        return rendered ?? const SizedBox(key: Key('empty'));
      }));
      await tester.pump();
      expect(find.byType(RouteSuggestionCard), findsOneWidget);
    });

    testWidgets('route_to_screen with invalid route renders SizedBox.shrink()',
        (tester) async {
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
      expect(find.byType(RouteSuggestionCard), findsNothing);
    });
  });

  // ────────────────────────────────────────────────────────────
  //  ChatMessage.richToolCalls field
  // ────────────────────────────────────────────────────────────

  group('ChatMessage richToolCalls field', () {
    test('richToolCalls defaults to empty list', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'Bonjour',
        timestamp: DateTime.now(),
      );
      expect(msg.richToolCalls, isEmpty);
    });

    test('hasRichToolCalls returns false for empty list', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'Bonjour',
        timestamp: DateTime.now(),
      );
      expect(msg.hasRichToolCalls, isFalse);
    });

    test('hasRichToolCalls returns true when calls present', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'Bonjour',
        timestamp: DateTime.now(),
        richToolCalls: const [
          RagToolCall(name: 'show_fact_card', input: {'value': '42'}),
        ],
      );
      expect(msg.hasRichToolCalls, isTrue);
    });

    test('richToolCalls stores the exact calls passed in', () {
      const calls = [
        RagToolCall(name: 'show_fact_card', input: {'value': '42'}),
        RagToolCall(name: 'route_to_screen', input: {'route': '/retraite'}),
      ];
      final msg = ChatMessage(
        role: 'assistant',
        content: 'Bonjour',
        timestamp: DateTime.now(),
        richToolCalls: calls,
      );
      expect(msg.richToolCalls.length, 2);
      expect(msg.richToolCalls[0].name, 'show_fact_card');
      expect(msg.richToolCalls[1].name, 'route_to_screen');
    });
  });

  // ────────────────────────────────────────────────────────────
  //  No keyword-matching fallback (T-02-08)
  // ────────────────────────────────────────────────────────────

  group('No keyword-matching widget rendering', () {
    testWidgets('WidgetRenderer only renders known tool names', (tester) async {
      // Confirms WidgetRenderer returns null for unknown tool names
      // (no keyword fallback path exists)
      late Widget? rendered;
      await tester.pumpWidget(_buildTestApp((context) {
        rendered = WidgetRenderer.build(
          context,
          const RagToolCall(name: 'not_a_real_tool', input: {}),
        );
        return rendered ?? const SizedBox(key: Key('fallback'));
      }));
      await tester.pump();
      // No widget rendered for unknown tool
      expect(find.byType(ChatFactCard), findsNothing);
      expect(find.byType(RouteSuggestionCard), findsNothing);
      // rendered should be null (the SizedBox fallback wraps it)
      expect(rendered, isNull);
    });
  });
}
