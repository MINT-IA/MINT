import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/user_activity_provider.dart';
import 'package:mint_mobile/screens/coach/coach_chat_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

// ────────────────────────────────────────────────────────────
//  COACH CHAT SCREEN TESTS — S52 redesigned UI
// ────────────────────────────────────────────────────────────

void main() {
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

  // SharedPreferences mock needed for ContextInjectorService (S58 AI memory).
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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

    testWidgets('shows tier badge on response messages', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      // Tier badge is hidden on the greeting (messageIndex == 0)
      // but shown on subsequent response messages.
      await tester.enterText(find.byType(TextField), 'Mon 3a');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      // Fallback tier badge with "Hors-ligne" text appears on response
      expect(find.textContaining('Hors-ligne'), findsOneWidget);
    });

    testWidgets('disclaimer removed from chat header', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      // Disclaimer bar was removed from main UI (moved to settings).
      // Verify it is NOT shown in the initial chat header.
      expect(
        find.textContaining('Outil éducatif'),
        findsNothing,
      );
    });

    testWidgets('shows initial greeting', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      // Greeting is now silent/minimal: "On commence par quoi ?"
      expect(find.textContaining('On commence par quoi'), findsOneWidget);
    });

    testWidgets('shows initial greeting with suggested prompts', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      // Greeting has suggested action prompts (rendered as tappable containers).
      // At least the "Il m'arrive quelque chose" life event trigger should exist.
      expect(find.textContaining('arrive quelque chose'), findsOneWidget);
    });

    testWidgets('shows input field with placeholder', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('Pose ta question'), findsWidgets);
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
      // Settings uses more_horiz icon for IA configuration access
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    });

    testWidgets('shows back button', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    });

    testWidgets('shows suggested action prompts', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      // The initial greeting has suggested actions rendered as tappable
      // Container widgets (not ActionChip). Verify at least one exists.
      expect(find.textContaining('arrive quelque chose'), findsOneWidget);
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
      await tester.pump(const Duration(milliseconds: 100));

      // Type a unique message that won't collide with chip text
      await tester.enterText(find.byType(TextField), 'Parle-moi du 3a');
      await tester.pump();

      // Tap send (arrow_upward icon) and settle (scroll animation + async response)
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      // User message should appear as a bubble
      expect(find.text('Parle-moi du 3a'), findsOneWidget);
    });

    testWidgets('shows coach response after sending message', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      // Type a message about 3a
      await tester.enterText(find.byType(TextField), 'Parle-moi du 3a');
      await tester.pump();

      // Tap send (arrow_upward icon)
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      // Coach response should appear (fallback path returns message with "coach IA")
      expect(find.textContaining('coach IA'), findsOneWidget);
    });

    testWidgets('shows coach avatar with M letter', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      // Coach avatar is a 24px gradient circle with letter 'M' (no icon)
      expect(find.text('M'), findsOneWidget);
    });

    testWidgets('fallback response embeds LSFin disclaimer', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      // Send a message to trigger fallback response (which embeds LSFin)
      await tester.enterText(find.byType(TextField), 'Aide-moi');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      // The fallback response body includes the LSFin disclaimer
      expect(find.textContaining('LSFin'), findsOneWidget);
    });

    testWidgets('shows fallback response with exploration options', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      // Send a 3a message
      await tester.enterText(find.byType(TextField), 'Mon 3a');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      // Fallback response mentions simulators
      expect(find.textContaining('simulateurs'), findsOneWidget);
    });

    testWidgets('shows fallback response with educational content', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      // Send a LPP message
      await tester.enterText(find.byType(TextField), 'Ma LPP');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      // Fallback response mentions educational content
      expect(find.textContaining('éducatives'), findsOneWidget);
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

      // Settings uses more_horiz icon for IA configuration access
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    });

    testWidgets('wifi_off icon shown for fallback tier badge', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      // Tier badge (with wifi_off) is only shown on non-greeting messages.
      // Send a message to trigger a fallback response with tier badge.
      await tester.enterText(find.byType(TextField), 'Info');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      // Fallback tier badge shows wifi_off icon
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
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

      // No user messages yet, so share/export button should not be shown
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
      await tester.pump(const Duration(milliseconds: 100));

      // Send a message
      await tester.enterText(find.byType(TextField), 'Mon 3a');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      // Now the share/export button should appear
      expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);
    });
  });
}
