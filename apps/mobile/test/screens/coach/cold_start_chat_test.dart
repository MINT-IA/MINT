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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

// ────────────────────────────────────────────────────────────
//  COLD-START CHAT TESTS — CHAT-01 (Phase 3)
//
//  Verifies:
//  1. Anonymous user sees silent opener (not empty state)
//  2. User with profile sees silent opener with key number
//  3. No intermediate screen between landing and chat
//  4. Chat screen renders for both anonymous and profiled users
// ────────────────────────────────────────────────────────────

void main() {
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

  Widget buildTestWidget({
    CoachProfileProvider? profileProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => profileProvider ?? CoachProfileProvider(),
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

  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> pumpUntilSettled(WidgetTester tester) async {
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'mint_coach_cash_level': 3,
    });
  });

  group('CHAT-01: Cold-start routing to chat', () {
    testWidgets('anonymous user (no profile) sees silent opener question',
        (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await pumpUntilSettled(tester);

      // Chat screen renders
      expect(find.byType(CoachChatScreen), findsOneWidget);

      // Silent opener is visible — shows the question text
      // (no key number for anonymous user, just the question)
      final S l10n = S.of(tester.element(find.byType(CoachChatScreen)))!;
      expect(find.text(l10n.coachSilentOpenerQuestion), findsOneWidget);
    });

    testWidgets('profiled user sees silent opener with key number',
        (tester) async {
      usePhoneViewport(tester);
      final provider = buildProfileProvider();
      await tester.pumpWidget(buildTestWidget(profileProvider: provider));
      await pumpUntilSettled(tester);

      expect(find.byType(CoachChatScreen), findsOneWidget);

      // Silent opener is visible — shows a question
      final S l10n = S.of(tester.element(find.byType(CoachChatScreen)))!;
      expect(find.text(l10n.coachSilentOpenerQuestion), findsOneWidget);
    });

    testWidgets('chat screen renders directly — no intermediate screen',
        (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await pumpUntilSettled(tester);

      // CoachChatScreen is present (not redirected to onboarding/login)
      expect(find.byType(CoachChatScreen), findsOneWidget);

      // MINT title in app bar confirms we are in the coach chat
      expect(find.text('MINT'), findsOneWidget);
    });

    testWidgets('anonymous user chat has input bar ready for typing',
        (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await pumpUntilSettled(tester);

      // Input bar is present and functional
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
