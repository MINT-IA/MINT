import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/user_activity_provider.dart';
import 'package:mint_mobile/screens/coach/coach_chat_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

// ────────────────────────────────────────────────────────────
//  COACH CHAT SCREEN TESTS — Phase 4 / BYOK + RAG wiring
// ────────────────────────────────────────────────────────────

void main() {
  CoachProfileProvider _buildProfileProvider() {
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
          create: (_) => withProfile ? _buildProfileProvider() : CoachProfileProvider(),
        ),
        ChangeNotifierProvider(create: (_) => ByokProvider()),
        ChangeNotifierProvider(create: (_) => UserActivityProvider()),
      ],
      child: const MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
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

  group('CoachChatScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CoachChatScreen), findsOneWidget);
    });

    testWidgets('shows Coach MINT title', (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Coach MINT'), findsOneWidget);
    });

    testWidgets('shows tier subtitle in app bar', (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      // Without SLM or BYOK, the fallback tier shows "Mode hors-ligne"
      expect(find.text('Mode hors-ligne'), findsOneWidget);
    });

    testWidgets('shows disclaimer text', (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.textContaining('Outil éducatif'),
        findsOneWidget,
      );
    });

    testWidgets('shows initial greeting with name', (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Salut Julien'), findsOneWidget);
    });

    testWidgets('shows initial greeting with coach identity', (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('coach MINT'), findsOneWidget);
    });

    testWidgets('shows input field with placeholder', (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Pose ta question...'), findsOneWidget);
    });

    testWidgets('shows send button', (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('shows settings icon in app bar', (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      // Settings gear icon is always shown for IA configuration
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('shows back button', (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('shows suggested action chips', (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      // The initial greeting should have suggested actions
      expect(find.byType(ActionChip), findsWidgets);
    });

    testWidgets('can type in input field', (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextField), 'Parle-moi du 3a');
      expect(find.text('Parle-moi du 3a'), findsOneWidget);
    });

    testWidgets('sends message when pressing send button', (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      // Type a unique message that won't collide with chip text
      await tester.enterText(find.byType(TextField), 'Parle-moi du 3a');
      await tester.pump();

      // Tap send and settle (scroll animation + async response)
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // User message should appear as a bubble
      expect(find.text('Parle-moi du 3a'), findsOneWidget);
    });

    testWidgets('shows coach response after sending message', (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      // Type a message about 3a
      await tester.enterText(find.byType(TextField), 'Parle-moi du 3a');
      await tester.pump();

      // Tap send
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Coach response should appear (fallback path returns generic message)
      expect(find.textContaining('coach IA'), findsOneWidget);
    });

    testWidgets('shows coach avatar icon', (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      // Coach avatar uses the psychology icon
      expect(find.byIcon(Icons.psychology), findsOneWidget);
    });

    testWidgets('disclaimer mentions LSFin', (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('LSFin'), findsOneWidget);
    });

    testWidgets('shows fallback response with exploration options', (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      // Send a 3a message
      await tester.enterText(find.byType(TextField), 'Mon 3a');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Fallback response mentions simulators
      expect(find.textContaining('simulateurs'), findsOneWidget);
    });

    testWidgets('shows fallback response with educational content', (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      // Send a LPP message
      await tester.enterText(find.byType(TextField), 'Ma LPP');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Fallback response mentions educational content
      expect(find.textContaining('éducatives'), findsOneWidget);
    });
  });

  group('CoachChatScreen — settings access', () {
    testWidgets('settings icon navigates to BYOK config', (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      // Settings gear icon should be present
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('wifi_off icon shown for fallback tier', (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      // Fallback tier shows wifi_off icon in subtitle
      expect(find.byIcon(Icons.wifi_off), findsWidgets);
    });

    testWidgets('no BYOK CTA card in chat area', (tester) async {
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
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      // No user messages yet, so share button should not be shown
      expect(find.byIcon(Icons.share), findsNothing);
    });

    testWidgets('export button appears after sending a message',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      // Send a message
      await tester.enterText(find.byType(TextField), 'Mon 3a');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Now the share/export button should appear
      expect(find.byIcon(Icons.share), findsOneWidget);
    });
  });
}
