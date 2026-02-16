import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/screens/coach/coach_chat_screen.dart';

// ────────────────────────────────────────────────────────────
//  COACH CHAT SCREEN TESTS — Sprint C8
// ────────────────────────────────────────────────────────────

void main() {
  Widget buildTestWidget() {
    return const MaterialApp(
      home: CoachChatScreen(),
    );
  }

  group('CoachChatScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CoachChatScreen), findsOneWidget);
    });

    testWidgets('shows Coach MINT title', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Coach MINT'), findsOneWidget);
    });

    testWidgets('shows educational subtitle', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Conversation educative'), findsOneWidget);
    });

    testWidgets('shows disclaimer text', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.textContaining('Outil educatif'),
        findsOneWidget,
      );
    });

    testWidgets('shows initial greeting with name', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Bonjour Julien'), findsOneWidget);
    });

    testWidgets('shows initial greeting with coach identity', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('coach financier MINT'), findsOneWidget);
    });

    testWidgets('shows input field with placeholder', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Pose ta question...'), findsOneWidget);
    });

    testWidgets('shows send button', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('shows settings button for BYOK config', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('shows back button', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('shows suggested action chips', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      // The initial greeting should have suggested actions
      expect(find.byType(ActionChip), findsWidgets);
    });

    testWidgets('can type in input field', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextField), 'Parle-moi du 3a');
      expect(find.text('Parle-moi du 3a'), findsOneWidget);
    });

    testWidgets('sends message when pressing send button', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      // Type a unique message that won't collide with chip text
      await tester.enterText(find.byType(TextField), 'Parle-moi du 3a');
      await tester.pump();

      // Tap send
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // User message should appear as a bubble
      expect(find.text('Parle-moi du 3a'), findsOneWidget);
    });

    testWidgets('shows coach response after sending message', (tester) async {
      await tester.pumpWidget(buildTestWidget());
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
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      // Coach avatar uses the psychology icon
      expect(find.byIcon(Icons.psychology), findsOneWidget);
    });

    testWidgets('disclaimer mentions LSFin', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('LSFin'), findsOneWidget);
    });
  });
}
