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
import 'package:mint_mobile/services/voice/voice_cursor_contract.dart'
    show VoicePreference;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

// ────────────────────────────────────────────────────────────
//  TONE PREFERENCE TESTS — CHAT-05 (Phase 3)
//
//  Verifies:
//  1. First conversation shows 3 tone chips after first assistant message
//  2. Tapping "Doux" sets VoicePreference.soft
//  3. Tapping "Direct" sets VoicePreference.direct
//  4. Tapping "Sans filtre" sets VoicePreference.unfiltered
//  5. Already-set preference suppresses the chips
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

  group('CHAT-05: Tone preference chips', () {
    setUp(() {
      // No cash level set = first time, show tone preference chips
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('first conversation shows 3 tone chips', (tester) async {
      usePhoneViewport(tester);
      final provider = buildProfileProvider();
      await tester.pumpWidget(buildTestWidget(provider: provider));
      await pumpUntilSettled(tester);

      // Silent opener is shown first — tap to engage and trigger first message
      // The chips appear after the first assistant message.
      // Since _intensityChosen is false and _cashLevelLoaded is true,
      // the chips should appear in the message list once the opener is dismissed.

      // The tone preference question text — shortened 2026-04-17 from
      // "Au fait, tu préfères que je sois plutôt…" to "Comment je te parle ?"
      // (commit d1ce63b5: the trailing ellipsis read as a truncation bug and
      // the 3 chips below already enumerate the options).
      expect(
        find.textContaining('Comment je te parle'),
        findsOneWidget,
      );

      // All 3 chips visible
      expect(find.text('Doux'), findsOneWidget);
      expect(find.text('Direct'), findsOneWidget);
      expect(find.text('Sans filtre'), findsOneWidget);
    });

    testWidgets('tapping "Doux" stores VoicePreference.soft', (tester) async {
      usePhoneViewport(tester);
      final provider = buildProfileProvider();
      await tester.pumpWidget(buildTestWidget(provider: provider));
      await pumpUntilSettled(tester);

      // Tap "Doux"
      await tester.tap(find.text('Doux'));
      await pumpUntilSettled(tester);

      // VoicePreference should be soft
      expect(provider.profile?.voiceCursorPreference, VoicePreference.soft);

      // Confirmation message visible
      expect(find.textContaining('tout en douceur'), findsOneWidget);
    });

    testWidgets('tapping "Direct" stores VoicePreference.direct',
        (tester) async {
      usePhoneViewport(tester);
      final provider = buildProfileProvider();
      await tester.pumpWidget(buildTestWidget(provider: provider));
      await pumpUntilSettled(tester);

      await tester.tap(find.text('Direct'));
      await pumpUntilSettled(tester);

      expect(provider.profile?.voiceCursorPreference, VoicePreference.direct);
      expect(find.textContaining('droit au but'), findsOneWidget);
    });

    testWidgets('tapping "Sans filtre" stores VoicePreference.unfiltered',
        (tester) async {
      usePhoneViewport(tester);
      final provider = buildProfileProvider();
      await tester.pumpWidget(buildTestWidget(provider: provider));
      await pumpUntilSettled(tester);

      await tester.tap(find.text('Sans filtre'));
      await pumpUntilSettled(tester);

      expect(
          provider.profile?.voiceCursorPreference, VoicePreference.unfiltered);
      expect(find.textContaining('je ne filtre rien'), findsOneWidget);
    });

    testWidgets('already-set preference hides the chips', (tester) async {
      usePhoneViewport(tester);
      // Set cash_level in SharedPreferences to simulate returning user
      SharedPreferences.setMockInitialValues({
        'mint_coach_cash_level': 3,
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
    });
  });
}
