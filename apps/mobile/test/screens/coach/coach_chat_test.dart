import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/user_activity_provider.dart';
import 'package:mint_mobile/screens/coach/coach_chat_screen.dart';

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

    testWidgets('shows educational subtitle', (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Conversation éducative'), findsOneWidget);
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

    testWidgets('shows key icon when BYOK not configured', (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));
      // Without BYOK configured, shows key icon instead of settings
      expect(find.byIcon(Icons.key), findsOneWidget);
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

      // Coach response about 3a should appear
      expect(find.textContaining('7\'258'), findsOneWidget);
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

    testWidgets('shows sources section after 3a response', (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      // Send a 3a message
      await tester.enterText(find.byType(TextField), 'Mon 3a');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Sources section should appear with legal reference
      expect(find.text('Sources'), findsOneWidget);
      // OPP3 appears in both response text and source section
      expect(find.textContaining('OPP3'), findsWidgets);
    });

    testWidgets('shows source icon in sources section', (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      // Send a LPP message
      await tester.enterText(find.byType(TextField), 'Ma LPP');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Source section should have description icon
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
      // LPP art. 79b appears in both response text and source section
      expect(find.textContaining('LPP art. 79b'), findsWidgets);
    });
  });

  group('CoachChatScreen — BYOK CTA', () {
    testWidgets('shows BYOK CTA when not configured', (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      // CTA card should be visible
      expect(find.text('Configure ton coach IA'), findsOneWidget);
      expect(find.text('Configurer'), findsOneWidget);
    });

    testWidgets('BYOK CTA has smart_toy icon', (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
    });

    testWidgets('BYOK CTA subtitle mentions API key', (tester) async {
      await tester.pumpWidget(buildTestWidget(withProfile: true));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.textContaining('clé API'),
        findsOneWidget,
      );
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
