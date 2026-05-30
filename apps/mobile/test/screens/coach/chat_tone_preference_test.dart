import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/coach/coach_chat_screen.dart';
import 'package:mint_mobile/services/coach/coach_orchestrator.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/voice/voice_cursor_contract.dart'
    show VoicePreference;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

// ────────────────────────────────────────────────────────────
//  TONE PREFERENCE TESTS — CHAT-05 / Phase 39 cleanup
//
//  Verifies:
//  1. First conversation no longer shows inline tone chips
//  2. Default cash level is persisted-free direct mode
//  3. Already-set preference still suppresses the chips
// ────────────────────────────────────────────────────────────

void main() {
  CoachLlmService.registerOrchestrator(CoachOrchestrator.generateChat);

  CoachProfileProvider buildProfileProvider({bool withPreference = false}) {
    final provider = CoachProfileProvider();
    provider.updateFromAnswers({
      'q_firstname': 'Julien',
      'q_birth_year': 1977,
      'q_canton': 'VS',
      'q_net_income_period_chf': 9080,
      'q_civil_status': 'marie',
      'q_goal': 'retraite',
    });
    if (withPreference) {
      provider.setVoiceCursorPreference(VoicePreference.direct);
    }
    return provider;
  }

  Widget buildTestWidget({required CoachProfileProvider provider}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: provider),
        ChangeNotifierProvider(create: (_) => ByokProvider()),
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

  group('CHAT-05: Tone preference chips', () {
    setUp(() {
      // No cash level set = first time.
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('first conversation does not show inline tone chips',
        (tester) async {
      usePhoneViewport(tester);
      final provider = buildProfileProvider();
      await tester.pumpWidget(buildTestWidget(provider: provider));
      await pumpUntilSettled(tester);

      expect(find.textContaining('Comment je te parle'), findsNothing);
      expect(find.text('Doux'), findsNothing);
      expect(find.text('Direct'), findsNothing);
      expect(find.text('Sans filtre'), findsNothing);
    });

    testWidgets('first conversation keeps default cash level unset in prefs',
        (tester) async {
      usePhoneViewport(tester);
      final provider = buildProfileProvider();
      await tester.pumpWidget(buildTestWidget(provider: provider));
      await pumpUntilSettled(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('mint_coach_cash_level'), isNull);
    });

    testWidgets('stored cash level is not overwritten by default direct mode',
        (tester) async {
      usePhoneViewport(tester);
      // Set cash_level in SharedPreferences to simulate returning user
      SharedPreferences.setMockInitialValues({
        'mint_coach_cash_level': 5,
      });

      final provider = buildProfileProvider(withPreference: true);
      await tester.pumpWidget(buildTestWidget(provider: provider));
      await pumpUntilSettled(tester);

      // Chips should NOT be visible (preference already set)
      expect(find.text('Doux'), findsNothing);
      expect(find.text('Sans filtre'), findsNothing);
      // The tone preference question should not appear
      expect(
        find.textContaining('tu pr\u00e9f\u00e8res que je sois'),
        findsNothing,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('mint_coach_cash_level'), 5);
    });
  });
}
