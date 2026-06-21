import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/screens/anonymous/anonymous_chat_screen.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
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
    SharedPreferences.setMockInitialValues({});
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

    testWidgets('suggestion chips do not use a clipped horizontal rail',
        (tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ListView && widget.scrollDirection == Axis.horizontal,
        ),
        findsNothing,
      );
      expect(find.text("J'ai un projet d'achat"), findsOneWidget);
      expect(find.text('Je change de boulot'), findsOneWidget);
      expect(find.text('Je veux y voir clair'), findsOneWidget);
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

    testWidgets('restored conversation keeps first bubble visible',
        (tester) async {
      ConversationStore.setCurrentUserId(null);
      final store = ConversationStore();
      await store.saveConversation('anonymous_restore_visibility', [
        ChatMessage(
          role: 'user',
          content: 'Message restaure',
          timestamp: DateTime(2026, 6, 1, 8, 0),
        ),
        ChatMessage(
          role: 'assistant',
          content: 'Reponse restauree',
          timestamp: DateTime(2026, 6, 1, 8, 1),
        ),
      ]);

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.text('Message restaure'), findsOneWidget);
      expect(find.text('Reponse restauree'), findsOneWidget);

      final fades = tester.widgetList<FadeTransition>(find.ancestor(
        of: find.text('Message restaure'),
        matching: find.byType(FadeTransition),
      ));
      expect(fades.map((fade) => fade.opacity.value), everyElement(1.0));
    });

    testWidgets('restored conversation can be cleared into a new discussion',
        (tester) async {
      ConversationStore.setCurrentUserId(null);
      final store = ConversationStore();
      await store.saveConversation('anonymous_restore_clear', [
        ChatMessage(
          role: 'user',
          content: 'Ancienne question',
          timestamp: DateTime(2026, 6, 1, 8, 0),
        ),
        ChatMessage(
          role: 'assistant',
          content: 'Ancienne réponse',
          timestamp: DateTime(2026, 6, 1, 8, 1),
        ),
      ]);

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.text('Ancienne question'), findsOneWidget);
      expect(find.text('Ancienne réponse'), findsOneWidget);
      expect(find.text('Nouvelle discussion'), findsOneWidget);

      await tester.tap(find.text('Nouvelle discussion'));
      await tester.pumpAndSettle();

      expect(find.text('Ancienne question'), findsNothing);
      expect(find.text('Ancienne réponse'), findsNothing);
      expect(
        find.text(
          'Salut. Dis-moi ce qui te trotte en tête côté finances en ce moment — un projet, une question, un truc flou.',
        ),
        findsOneWidget,
      );
      expect(find.text('Nouvelle discussion'), findsNothing);
      expect(await store.listConversations(), isEmpty);
    });

    testWidgets(
        'restored conversation reset opens auth gate when quota is spent',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'anonfb_anonymous_message_count': '3',
      });
      ConversationStore.setCurrentUserId(null);
      final store = ConversationStore();
      await store.saveConversation('anonymous_restore_quota_spent', [
        ChatMessage(
          role: 'user',
          content: 'Ancienne question quota',
          timestamp: DateTime(2026, 6, 1, 8, 0),
        ),
        ChatMessage(
          role: 'assistant',
          content: 'Ancienne réponse quota',
          timestamp: DateTime(2026, 6, 1, 8, 1),
        ),
      ]);

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nouvelle discussion'));
      await tester.pumpAndSettle();

      expect(find.text('Ancienne question quota'), findsNothing);
      expect(find.text('Ancienne réponse quota'), findsNothing);
      expect(
        find.text(
          'Salut. Dis-moi ce qui te trotte en tête côté finances en ce moment — un projet, une question, un truc flou.',
        ),
        findsNothing,
      );
      expect(
        find.text(
          'Je peux garder tout ça en mémoire pour toi — il te suffit de créer un compte.',
        ),
        findsOneWidget,
      );
      expect(await store.listConversations(), isEmpty);
    });

    testWidgets('quota-spent auth gate fits a short viewport', (tester) async {
      tester.view.physicalSize = const Size(390, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({
        'anonfb_anonymous_message_count': '3',
      });
      ConversationStore.setCurrentUserId(null);
      final store = ConversationStore();
      await store.saveConversation('anonymous_restore_short_viewport', [
        ChatMessage(
          role: 'user',
          content: 'Ancienne question viewport',
          timestamp: DateTime(2026, 6, 1, 8, 0),
        ),
        ChatMessage(
          role: 'assistant',
          content: 'Ancienne réponse viewport',
          timestamp: DateTime(2026, 6, 1, 8, 1),
        ),
      ]);

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nouvelle discussion'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Je peux garder tout ça en mémoire pour toi — il te suffit de créer un compte.',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Plus tard'));
      await tester.pumpAndSettle();
      expect(find.text('Plus tard'), findsOneWidget);
    });
  });

  group('Anonymous conversation eager persistence', () {
    test(
        'saveConversation stores data under unprefixed keys when userId is null',
        () async {
      SharedPreferences.setMockInitialValues({});

      // Simulate the eager persistence path: null userId = anonymous (unprefixed).
      ConversationStore.setCurrentUserId(null);
      final store = ConversationStore();
      const conversationId = 'anonymous_1234567890';

      final messages = [
        ChatMessage(
          role: 'user',
          content: 'Je me sens perdu financierement',
          timestamp: DateTime(2026, 4, 12, 10, 0),
        ),
        ChatMessage(
          role: 'assistant',
          content: 'Ce sentiment est normal et courant.',
          timestamp: DateTime(2026, 4, 12, 10, 1),
        ),
      ];

      await store.saveConversation(conversationId, messages);

      // Verify: SharedPreferences should contain unprefixed conversation data.
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('_chat_conversations_$conversationId');
      expect(raw, isNotNull,
          reason: 'Conversation data should be in SharedPreferences');

      final decoded = jsonDecode(raw!) as List<dynamic>;
      expect(decoded.length, 2);
      expect((decoded[0] as Map<String, dynamic>)['role'], 'user');
      expect((decoded[1] as Map<String, dynamic>)['role'], 'assistant');

      // Verify: index should also exist (unprefixed).
      final indexRaw = prefs.getString('_chat_conversation_index');
      expect(indexRaw, isNotNull, reason: 'Conversation index should exist');
      final indexDecoded = jsonDecode(indexRaw!) as List<dynamic>;
      expect(indexDecoded.length, 1);
      expect((indexDecoded[0] as Map<String, dynamic>)['id'], conversationId);
    });

    test('migrateAnonymousToUser finds eagerly persisted anonymous data',
        () async {
      SharedPreferences.setMockInitialValues({});

      // Step 1: Simulate eager persistence (anonymous chat screen saves after
      // each coach response with userId = null).
      ConversationStore.setCurrentUserId(null);
      final store = ConversationStore();
      const conversationId = 'anonymous_9876543210';

      final messages = [
        ChatMessage(
          role: 'user',
          content: 'Est-ce que mon 3a est optimal',
          timestamp: DateTime(2026, 4, 12, 11, 0),
        ),
        ChatMessage(
          role: 'assistant',
          content: 'Bonne question. Votre 3a depend de votre situation.',
          timestamp: DateTime(2026, 4, 12, 11, 1),
        ),
      ];

      await store.saveConversation(conversationId, messages);

      // Step 2: Simulate auth_provider._migrateLocalDataIfNeeded() calling
      // migrateAnonymousToUser after account creation.
      const userId = 'user_abc123';
      await ConversationStore.migrateAnonymousToUser(userId);

      // Step 3: Verify data is now under user-prefixed keys.
      ConversationStore.setCurrentUserId(userId);
      final migrated = await store.loadConversation(conversationId);
      expect(migrated.length, 2, reason: 'Both messages should be migrated');
      expect(migrated[0].role, 'user');
      expect(migrated[1].role, 'assistant');

      // Step 4: Verify anonymous (unprefixed) data was cleaned up.
      final prefs = await SharedPreferences.getInstance();
      final anonData = prefs.getString('_chat_conversations_$conversationId');
      expect(anonData, isNull,
          reason: 'Anonymous data should be removed after migration');
      final anonIndex = prefs.getString('_chat_conversation_index');
      expect(anonIndex, isNull,
          reason: 'Anonymous index should be removed after migration');
    });
  });
}
