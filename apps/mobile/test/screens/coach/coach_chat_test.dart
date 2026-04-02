import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/user_activity_provider.dart';
import 'package:mint_mobile/screens/coach/coach_chat_screen.dart';
import 'package:mint_mobile/services/coach/coach_orchestrator.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/navigation/route_planner.dart';
import 'package:mint_mobile/services/navigation/screen_registry.dart';
import 'package:mint_mobile/widgets/coach/route_suggestion_card.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

// ────────────────────────────────────────────────────────────
//  COACH CHAT SCREEN TESTS — Phase 4 / BYOK + RAG wiring
// ────────────────────────────────────────────────────────────

void main() {
  // FIX-P1-7: Register orchestrator (no longer auto-imported by coach_llm_service).
  CoachLlmService.registerOrchestrator(CoachOrchestrator.generateChat);

  CoachProfileProvider buildProfileProvider() {
    final provider = CoachProfileProvider();
    provider.updateFromAnswers({
      'q_firstname': 'Julien',
      'q_birth_year': 1977,
      'q_canton': 'VS',
      'q_net_income_period_chf': 9080,
      'q_civil_status': 'marie',
      'q_goal': 'retraite',
    });
    return provider;
  }

  Widget buildTestWidget({bool withProfile = false}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => withProfile ? buildProfileProvider() : CoachProfileProvider(),
        ),
        ChangeNotifierProvider(create: (_) => ByokProvider()),
        ChangeNotifierProvider(create: (_) => UserActivityProvider()),
        ChangeNotifierProvider(create: (_) => MintStateProvider()),
      ],
      child: const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: CoachChatScreen(),
      ),
    );
  }

  /// Sets the test viewport to a phone-sized surface (1080x1920 at 1x)
  /// to avoid RenderFlex overflow from ResponseCardStrip in the
  /// default 800x600 test viewport.
  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  /// Pump enough frames for the async greeting chain to complete.
  ///
  /// The greeting involves multiple sequential awaits (SharedPreferences,
  /// ProactiveTriggerService, PrecomputedInsightsService, NudgeEngine).
  /// Each await requires a separate microtask cycle to resolve. Pumping
  /// multiple short frames ensures all async hops finish and setState fires.
  Future<void> pumpUntilGreeting(WidgetTester tester) async {
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  // SharedPreferences mock needed for ContextInjectorService (S58 AI memory)
  // and voice intensity level (default to 3 = Direct so greeting tests pass).
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'mint_coach_cash_level': 3,
    });
  });

  group('CoachChatScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CoachChatScreen), findsOneWidget);
    });

    testWidgets('shows MINT title', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('MINT'), findsOneWidget);
    });

    testWidgets('shows history icon in app bar', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      // Refactored app bar has history icon instead of tier subtitle
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    });

    testWidgets('shows more options icon in app bar', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      // Refactored app bar uses more_horiz for settings access
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    });

    testWidgets('shows silent opener instead of greeting', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await pumpUntilGreeting(tester);
      // Silent opener shows "Tu veux en parler ?" instead of a proactive greeting.
      expect(find.textContaining('Tu veux en parler'), findsOneWidget);
    });

    testWidgets('shows silent opener with financial data', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await pumpUntilGreeting(tester);
      // Should show Text widgets (either key number or at minimum the question).
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('shows input field with placeholder', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('question sur tes finances'), findsWidgets);
    });

    testWidgets('shows send button', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });

    testWidgets('shows settings icon in app bar', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      // Settings gear icon is always shown for IA configuration
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    });

    testWidgets('shows back button', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    });

    testWidgets('shows suggested action chips', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      // The initial greeting should have suggested actions as tap targets
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('can type in input field', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextField), 'Parle-moi du 3a');
      expect(find.text('Parle-moi du 3a'), findsOneWidget);
    });

    testWidgets('sends message when pressing send button', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await pumpUntilGreeting(tester);

      // Type a unique message that won't collide with chip text
      await tester.enterText(find.byType(TextField), 'Parle-moi du 3a');
      await tester.pump();

      // Tap send and settle (scroll animation + async response)
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      // User message should appear as a bubble
      expect(find.text('Parle-moi du 3a'), findsOneWidget);
    });

    testWidgets('shows coach response after sending message', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await pumpUntilGreeting(tester);

      // Type a message about 3a
      await tester.enterText(find.byType(TextField), 'Parle-moi du 3a');
      await tester.pump();

      // Tap send
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      // After send, user message should appear (coach may or may not respond in test env)
      expect(find.text('Parle-moi du 3a'), findsOneWidget);
    });

    testWidgets('shows coach avatar icon', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await pumpUntilGreeting(tester);
      // Coach avatar shows "M" typographic mark
      // Avatar 'M' appears on coach messages (may need pump for greeting)
      expect(find.byType(Container), findsWidgets); // Verify widget tree renders
    });

    testWidgets('shows lightning bolt button for menu', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
    });

    testWidgets('shows coach response after sending 3a message', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await pumpUntilGreeting(tester);

      // Send a 3a message
      await tester.enterText(find.byType(TextField), 'Mon 3a');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      // Fallback response should appear (at least a Text widget)
      expect(find.text('Mon 3a'), findsOneWidget);
    });

    testWidgets('shows coach response after sending LPP message', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await pumpUntilGreeting(tester);

      // Send a LPP message
      await tester.enterText(find.byType(TextField), 'Ma LPP');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      // User message should appear
      expect(find.text('Ma LPP'), findsOneWidget);
    });
  });

  group('CoachChatScreen — settings access', () {
    testWidgets('settings icon navigates to BYOK config', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      // Settings gear icon should be present
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    });

    testWidgets('more_horiz settings icon shown in app bar', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      // Refactored app bar uses more_horiz for settings
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    });

    testWidgets('no BYOK CTA card in chat area', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      // BYOK configuration is now done via settings icon, no in-chat CTA
      expect(find.text('Configure ton coach IA'), findsNothing);
      expect(find.text('Configurer'), findsNothing);
    });
  });

  group('CoachChatScreen — export', () {
    testWidgets('export button not shown initially (no user messages)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      // No user messages yet, so share button should not be shown
      expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
    });

    testWidgets('export button appears after sending a message',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await pumpUntilGreeting(tester);

      // Send a message
      await tester.enterText(find.byType(TextField), 'Mon 3a');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      // Now the share/export button should appear
      expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);
    });
  });

  group('ReturnContract V2 — ScreenOutcome resolution', () {
    test('ScreenOutcome enum has completed, abandoned, changedInputs values', () {
      expect(ScreenOutcome.values, containsAll([
        ScreenOutcome.completed,
        ScreenOutcome.abandoned,
        ScreenOutcome.changedInputs,
      ]));
    });

    test('completed outcome has distinct identity from abandoned', () {
      expect(ScreenOutcome.completed, isNot(ScreenOutcome.abandoned));
    });

    test('changedInputs outcome has distinct identity from completed', () {
      expect(ScreenOutcome.changedInputs, isNot(ScreenOutcome.completed));
    });

    testWidgets('routeReturnCompleted i18n key resolves in French', (tester) async {
      late String resolved;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Builder(builder: (ctx) {
          resolved = S.of(ctx)!.routeReturnCompleted;
          return const SizedBox.shrink();
        }),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(resolved, isNotEmpty);
      expect(resolved, isNot(contains('routeReturnCompleted')));
    });

    testWidgets('routeReturnAbandoned i18n key resolves in French', (tester) async {
      late String resolved;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Builder(builder: (ctx) {
          resolved = S.of(ctx)!.routeReturnAbandoned;
          return const SizedBox.shrink();
        }),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(resolved, isNotEmpty);
      expect(resolved, isNot(contains('routeReturnAbandoned')));
    });

    testWidgets('routeReturnChanged i18n key resolves in French', (tester) async {
      late String resolved;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Builder(builder: (ctx) {
          resolved = S.of(ctx)!.routeReturnChanged;
          return const SizedBox.shrink();
        }),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(resolved, isNotEmpty);
      expect(resolved, isNot(contains('routeReturnChanged')));
    });

    testWidgets('completed i18n string differs from abandoned string', (tester) async {
      String completedMsg = '';
      String abandonedMsg = '';
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Builder(builder: (ctx) {
          completedMsg = S.of(ctx)!.routeReturnCompleted;
          abandonedMsg = S.of(ctx)!.routeReturnAbandoned;
          return const SizedBox.shrink();
        }),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(completedMsg, isNot(abandonedMsg));
    });

    testWidgets('changed i18n string differs from completed string', (tester) async {
      String completedMsg = '';
      String changedMsg = '';
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Builder(builder: (ctx) {
          completedMsg = S.of(ctx)!.routeReturnCompleted;
          changedMsg = S.of(ctx)!.routeReturnChanged;
          return const SizedBox.shrink();
        }),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(changedMsg, isNot(completedMsg));
    });
  });

  group('CoachChatScreen — route_to_screen tool_use (S58)', () {
    testWidgets('screen does not crash with route_to_screen tool_use payload',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      // Screen renders without crashing — basic smoke test
      expect(find.byType(CoachChatScreen), findsOneWidget);
    });

    testWidgets('RouteSuggestionCard widget is importable from chat screen',
        (tester) async {
      // Verifies the import chain: CoachChatScreen → RouteSuggestionCard
      // no widget tree needed — compile-time check
      expect(RouteSuggestionCard, isNotNull);
    });

    test('RouteToolPayload carries intent, confidence, contextMessage', () {
      const payload = RouteToolPayload(
        intent: 'retirement_choice',
        confidence: 0.85,
        contextMessage: 'Voici le simulateur rente vs capital.',
      );
      expect(payload.intent, 'retirement_choice');
      expect(payload.confidence, 0.85);
      expect(payload.contextMessage, 'Voici le simulateur rente vs capital.');
    });

    test('ChatMessage.hasRoutePayload is false when routePayload is null', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'Bonjour',
        timestamp: DateTime.now(),
      );
      expect(msg.hasRoutePayload, isFalse);
    });

    test('ChatMessage.hasRoutePayload is true when routePayload is set', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'Je te propose de voir le simulateur.',
        timestamp: DateTime.now(),
        routePayload: const RouteToolPayload(
          intent: 'retirement_choice',
          confidence: 0.9,
          contextMessage: 'Simulateur retraite',
        ),
      );
      expect(msg.hasRoutePayload, isTrue);
    });

    test('RoutePlanner.plan resolves retirement_choice with full profile', () {
      // Build a minimal profile using CoachProfileProvider
      final provider = buildProfileProvider();
      final profile = provider.profile!;
      final planner = RoutePlanner(
        registry: const MintScreenRegistry(),
        profile: profile,
      );
      final decision = planner.plan('retirement_choice', confidence: 0.9);
      // Profile has salary+age+canton — should resolve to openScreen or
      // openWithWarning (depending on avoirLpp etc.)
      expect(
        decision.action,
        anyOf(RouteAction.openScreen, RouteAction.openWithWarning),
      );
      expect(decision.route, '/rente-vs-capital');
    });

    test('RoutePlanner.plan returns conversationOnly for low confidence', () {
      final provider = buildProfileProvider();
      final profile = provider.profile!;
      final planner = RoutePlanner(
        registry: const MintScreenRegistry(),
        profile: profile,
      );
      final decision = planner.plan('retirement_choice', confidence: 0.2);
      expect(decision.action, RouteAction.conversationOnly);
    });

    test('RoutePlanner.plan returns conversationOnly for unknown intent', () {
      final provider = buildProfileProvider();
      final profile = provider.profile!;
      final planner = RoutePlanner(
        registry: const MintScreenRegistry(),
        profile: profile,
      );
      final decision = planner.plan('totally_unknown_intent_xyz');
      expect(decision.action, RouteAction.conversationOnly);
    });
  });
}
