// Coach tool choreography — end-to-end rendering test (STAB-11 / 07-02).
//
// Facade-sans-cablage guard: proves that every one of the 4 coach tools
// reaches the user as a visible widget in CoachMessageBubble.
//
// Chain exercised per test:
//   RagToolCall (as-if-from-Claude)
//     → ChatMessage(richToolCalls: [...])
//     → CoachMessageBubble.build()
//     → WidgetRenderer.build()
//     → real widget found by finder (NOT SizedBox.shrink)
//
// If any renderer case for the 4 tools is removed or reverts to
// SizedBox.shrink, the corresponding test will fail. This is the
// guard we lacked in v2.0.
//
// Scope: STAB-01 (route_to_screen), STAB-02 (generate_document),
// STAB-03 (generate_financial_plan), STAB-04 (record_check_in).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/widgets/coach/check_in_summary_card.dart';
import 'package:mint_mobile/widgets/coach/coach_message_bubble.dart';
import 'package:mint_mobile/widgets/coach/plan_preview_card.dart';
import 'package:mint_mobile/widgets/coach/route_suggestion_card.dart';

// ────────────────────────────────────────────────────────────
//  Test scaffolding
// ────────────────────────────────────────────────────────────

Widget _wrap({
  required Widget child,
  CoachProfileProvider? coachProvider,
  FinancialPlanProvider? planProvider,
}) {
  // Minimal GoRouter — the renderer calls context.push on a few paths
  // (/documents for generate_document). A stub root route is enough.
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => Scaffold(body: child)),
      GoRoute(path: '/documents', builder: (_, __) => const Scaffold()),
      GoRoute(path: '/budget', builder: (_, __) => const Scaffold()),
      GoRoute(path: '/rente-vs-capital', builder: (_, __) => const Scaffold()),
      GoRoute(path: '/retraite', builder: (_, __) => const Scaffold()),
    ],
  );

  final coach = coachProvider ?? CoachProfileProvider();
  final plan = planProvider ?? FinancialPlanProvider();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>.value(value: coach),
      ChangeNotifierProvider<FinancialPlanProvider>.value(value: plan),
    ],
    child: MaterialApp.router(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr')],
      routerConfig: router,
    ),
  );
}

ChatMessage _msgWithToolCall(RagToolCall call) {
  return ChatMessage(
    role: 'assistant',
    content: 'Voici ce que je te propose.',
    timestamp: DateTime.now(),
    tier: ChatTier.byok,
    richToolCalls: [call],
  );
}

Future<void> _pumpBubble(
  WidgetTester tester,
  RagToolCall call, {
  CoachProfileProvider? coachProvider,
  FinancialPlanProvider? planProvider,
}) async {
  final msg = _msgWithToolCall(call);
  await tester.pumpWidget(_wrap(
    coachProvider: coachProvider,
    planProvider: planProvider,
    child: SingleChildScrollView(
      child: CoachMessageBubble(
        message: msg,
        messageIndex: 1,
      ),
    ),
  ));
  // Let async providers settle.
  await tester.pump();
}

// ────────────────────────────────────────────────────────────
//  Tests
// ────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Coach tool choreography (STAB-11 / 07-02)', () {
    testWidgets(
      'STAB-01: route_to_screen with intent tag renders a RouteSuggestionCard',
      (tester) async {
        // Backend contract: {intent, confidence, context_message}
        // NO explicit route — mobile resolves via ChatToolDispatcher +
        // MintScreenRegistry.
        const call = RagToolCall(
          name: 'route_to_screen',
          input: {
            'intent': 'retirement_choice',
            'confidence': 0.9,
            'context_message':
                'Tu approches un choix rente vs capital. Ouvre cet outil.',
          },
        );

        await _pumpBubble(tester, call);

        expect(
          find.byType(RouteSuggestionCard),
          findsOneWidget,
          reason:
              'route_to_screen with intent=retirement_choice must resolve '
              'to /rente-vs-capital via MintScreenRegistry and render a '
              'RouteSuggestionCard (not SizedBox.shrink). Facade audit STAB-01.',
        );
      },
    );

    testWidgets(
      'STAB-02: generate_document renders a document generation card',
      (tester) async {
        const call = RagToolCall(
          name: 'generate_document',
          input: {
            'document_type': 'lpp_buyback_request',
            'context': 'Preparation de ta demande de rachat LPP.',
          },
        );

        await _pumpBubble(tester, call);

        // Minimal generate_document card surfaces the document type label
        // and the 'Preparer le document' CTA. Presence of the CTA text
        // proves the renderer case fires and the widget is visible
        // (not SizedBox.shrink).
        expect(
          find.text('Demande de rachat LPP'),
          findsOneWidget,
          reason:
              'generate_document must render the document type label '
              '(facade audit STAB-02).',
        );
        expect(
          find.text('Pr\u00e9parer le document'),
          findsOneWidget,
          reason:
              'generate_document must expose a tappable CTA routing to '
              '/documents (facade audit STAB-02).',
        );
      },
    );

    testWidgets(
      'STAB-03: generate_financial_plan renders a PlanPreviewCard',
      (tester) async {
        const call = RagToolCall(
          name: 'generate_financial_plan',
          input: {
            'goal': 'Preparer la retraite',
            'monthly_amount': 500.0,
            'narrative': 'Plan de progression vers la retraite.',
          },
        );

        // generate_financial_plan reads CoachProfileProvider for the
        // async plan generation fallback. Use a default provider — the
        // renderer shows a fallback PlanPreviewCard immediately.
        await _pumpBubble(tester, call);

        expect(
          find.byType(PlanPreviewCard),
          findsOneWidget,
          reason:
              'generate_financial_plan must render a PlanPreviewCard '
              '(facade audit STAB-03). Renderer case at widget_renderer.dart:70 '
              'exists — this test guards that the BYOK exposure (commit e782a437) '
              'keeps it reachable.',
        );
      },
    );

    testWidgets(
      'STAB-04: record_check_in renders a CheckInSummaryCard',
      (tester) async {
        const call = RagToolCall(
          name: 'record_check_in',
          input: {
            'month': '2026-04',
            'versements': {'3a': 604.0, 'lpp': 250.0},
            'summary_message': 'Versement 3a enregistre pour avril.',
          },
        );

        // record_check_in requires a profile to persist the check-in.
        // Use a default profile.
        final coachProvider = CoachProfileProvider();
        coachProvider.createFromRemoteProfile({
          'birth_year': 1985,
          'canton': 'VS',
        });

        await _pumpBubble(tester, call, coachProvider: coachProvider);

        expect(
          find.byType(CheckInSummaryCard),
          findsOneWidget,
          reason:
              'record_check_in must render a CheckInSummaryCard '
              '(facade audit STAB-04). Renderer case at widget_renderer.dart:74 '
              'exists — this test guards that the BYOK exposure keeps it '
              'reachable.',
        );
      },
    );
  });
}
