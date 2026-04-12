import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mint_mobile/screens/anonymous/anonymous_chat_screen.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

/// Wrap widget with MaterialApp + l10n for testing.
Widget _testApp({String? intent}) {
  return MaterialApp(
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    locale: const Locale('fr'),
    home: AnonymousChatScreen(intent: intent),
  );
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('AnonymousChatScreen', () {
    testWidgets('renders with intent parameter', (tester) async {
      await tester.pumpWidget(_testApp(intent: 'Je veux y voir clair'));
      await tester.pumpAndSettle();

      // The screen should exist and show the back button
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('renders without intent parameter', (tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      // Back button should be present
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      // Send button should be present
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });

    testWidgets('send button is visible when not locked', (tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      final sendButton = find.byIcon(Icons.send_rounded);
      expect(sendButton, findsOneWidget);
    });

    testWidgets('input field accepts text', (tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      // Find the TextField and enter text
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, 'Test message');
      expect(find.text('Test message'), findsOneWidget);
    });

    testWidgets('displays user message in chat after sending with intent',
        (tester) async {
      await tester.pumpWidget(_testApp(intent: 'Mon test'));
      // Pump once to trigger initState postFrameCallback
      await tester.pump();
      // Pump again to process setState from _sendMessage
      await tester.pump();

      // The intent text should appear as a user message
      expect(find.text('Mon test'), findsOneWidget);
    });
  });
}
