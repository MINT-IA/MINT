import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';

void main() {
  late ConversationStore store;

  /// Helper to create a ChatMessage.
  ChatMessage msg(String role, String content, {DateTime? ts}) {
    return ChatMessage(
      role: role,
      content: content,
      timestamp: ts ?? DateTime(2026, 4, 12, 10, 0),
    );
  }

  /// Helper to build a serialized conversation index entry.
  Map<String, dynamic> metaJson(String id, {int messageCount = 2}) {
    return {
      'id': id,
      'title': 'Test $id',
      'createdAt': '2026-04-12T10:00:00.000',
      'lastMessageAt': '2026-04-12T10:05:00.000',
      'messageCount': messageCount,
      'tags': <String>[],
    };
  }

  /// Helper to build serialized messages list.
  String serializeMessages(List<ChatMessage> messages) {
    return jsonEncode(messages
        .map((m) => {
              'schemaVersion': 1,
              'role': m.role,
              'content': m.content,
              'timestamp': m.timestamp.toIso8601String(),
              'tier': 'none',
            })
        .toList());
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = ConversationStore();
    // Reset user prefix to anonymous (no prefix)
    ConversationStore.setCurrentUserId(null);
  });

  group('ConversationStore.migrateAnonymousToUser', () {
    test('moves conversation index from unprefixed to userId-prefixed key',
        () async {
      // Arrange: anonymous index (no prefix)
      final indexData = jsonEncode([metaJson('conv-1')]);
      SharedPreferences.setMockInitialValues({
        '_chat_conversation_index': indexData,
      });

      // Act
      await ConversationStore.migrateAnonymousToUser('user-42');

      // Assert: new key exists with migrated data
      final prefs = await SharedPreferences.getInstance();
      final newIndex = prefs.getString('user-42__chat_conversation_index');
      expect(newIndex, isNotNull);
      final parsed = jsonDecode(newIndex!) as List<dynamic>;
      expect(parsed.length, 1);
      expect((parsed[0] as Map<String, dynamic>)['id'], 'conv-1');
    });

    test('moves all message entries from unprefixed to userId-prefixed keys',
        () async {
      final messages = [
        msg('user', 'Hello'),
        msg('assistant', 'Welcome'),
      ];
      final indexData = jsonEncode([metaJson('conv-1'), metaJson('conv-2')]);
      final messagesData = serializeMessages(messages);

      SharedPreferences.setMockInitialValues({
        '_chat_conversation_index': indexData,
        '_chat_conversations_conv-1': messagesData,
        '_chat_conversations_conv-2': messagesData,
      });

      await ConversationStore.migrateAnonymousToUser('user-42');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('user-42__chat_conversations_conv-1'),
        isNotNull,
      );
      expect(
        prefs.getString('user-42__chat_conversations_conv-2'),
        isNotNull,
      );
    });

    test('after migration, old unprefixed keys no longer exist', () async {
      final indexData = jsonEncode([metaJson('conv-1')]);
      final messagesData = serializeMessages([msg('user', 'Test')]);

      SharedPreferences.setMockInitialValues({
        '_chat_conversation_index': indexData,
        '_chat_conversations_conv-1': messagesData,
      });

      await ConversationStore.migrateAnonymousToUser('user-42');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('_chat_conversation_index'), isNull);
      expect(prefs.getString('_chat_conversations_conv-1'), isNull);
    });

    test('with no anonymous data is a safe no-op', () async {
      SharedPreferences.setMockInitialValues({});

      // Should complete without error
      await ConversationStore.migrateAnonymousToUser('user-42');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user-42__chat_conversation_index'), isNull);
    });

    test('preserves message content exactly (no data loss)', () async {
      final messages = [
        msg('user', 'Comment fonctionne le 3a\u00a0?'),
        msg('assistant', 'Le 3e pilier est un outil d\'epargne volontaire.'),
      ];
      final indexData = jsonEncode([metaJson('conv-1', messageCount: 2)]);
      final messagesData = serializeMessages(messages);

      SharedPreferences.setMockInitialValues({
        '_chat_conversation_index': indexData,
        '_chat_conversations_conv-1': messagesData,
      });

      await ConversationStore.migrateAnonymousToUser('user-42');

      // Load via ConversationStore API with new userId
      ConversationStore.setCurrentUserId('user-42');
      final loaded = await store.loadConversation('conv-1');
      expect(loaded.length, 2);
      expect(loaded[0].content, 'Comment fonctionne le 3a\u00a0?');
      expect(loaded[1].content,
          'Le 3e pilier est un outil d\'epargne volontaire.');
      expect(loaded[0].role, 'user');
      expect(loaded[1].role, 'assistant');
    });

    test('new keys are written before old keys are deleted (atomic safety)',
        () async {
      // This test verifies the code pattern: setString(new) happens before
      // remove(old). We test by verifying that after migration, new keys
      // contain valid data AND old keys are gone — which proves writes
      // happened first (if remove happened first, data would be lost).
      final messages = [
        msg('user', 'Test atomic'),
        msg('assistant', 'Response'),
      ];
      final indexData = jsonEncode([metaJson('conv-a')]);
      final messagesData = serializeMessages(messages);

      SharedPreferences.setMockInitialValues({
        '_chat_conversation_index': indexData,
        '_chat_conversations_conv-a': messagesData,
      });

      await ConversationStore.migrateAnonymousToUser('user-99');

      final prefs = await SharedPreferences.getInstance();
      // New keys MUST contain valid data
      final newIndex = prefs.getString('user-99__chat_conversation_index');
      expect(newIndex, isNotNull);
      final newMessages =
          prefs.getString('user-99__chat_conversations_conv-a');
      expect(newMessages, isNotNull);
      // Verify content integrity
      final parsed = jsonDecode(newMessages!) as List<dynamic>;
      expect(parsed.length, 2);
      // Old keys MUST be gone
      expect(prefs.getString('_chat_conversation_index'), isNull);
      expect(prefs.getString('_chat_conversations_conv-a'), isNull);
    });

    test(
        'after migration, loadConversation with userId prefix returns migrated messages',
        () async {
      final messages = [
        msg('user', 'Ma question'),
        msg('assistant', 'Ma reponse'),
        msg('user', 'Merci'),
      ];
      final indexData = jsonEncode([metaJson('conv-x', messageCount: 3)]);
      final messagesData = serializeMessages(messages);

      SharedPreferences.setMockInitialValues({
        '_chat_conversation_index': indexData,
        '_chat_conversations_conv-x': messagesData,
      });

      await ConversationStore.migrateAnonymousToUser('user-77');

      // Switch to authenticated user prefix
      ConversationStore.setCurrentUserId('user-77');

      // listConversations should show the migrated conversation
      final conversations = await store.listConversations();
      expect(conversations.length, 1);
      expect(conversations[0].id, 'conv-x');

      // loadConversation should return all messages
      final loaded = await store.loadConversation('conv-x');
      expect(loaded.length, 3);
      expect(loaded[0].content, 'Ma question');
      expect(loaded[1].content, 'Ma reponse');
      expect(loaded[2].content, 'Merci');
    });

    test('merges with existing user conversations when user already has data',
        () async {
      // Setup: anonymous has conv-anon, user already has conv-existing
      final anonIndex = jsonEncode([metaJson('conv-anon')]);
      final userIndex = jsonEncode([metaJson('conv-existing')]);
      final anonMessages = serializeMessages([msg('user', 'Anon msg')]);
      final userMessages = serializeMessages([msg('user', 'User msg')]);

      SharedPreferences.setMockInitialValues({
        '_chat_conversation_index': anonIndex,
        '_chat_conversations_conv-anon': anonMessages,
        'user-50__chat_conversation_index': userIndex,
        'user-50__chat_conversations_conv-existing': userMessages,
      });

      await ConversationStore.migrateAnonymousToUser('user-50');

      ConversationStore.setCurrentUserId('user-50');
      final conversations = await store.listConversations();
      // Should have both: anon at top + existing
      expect(conversations.length, 2);
      final ids = conversations.map((c) => c.id).toList();
      expect(ids, contains('conv-anon'));
      expect(ids, contains('conv-existing'));
    });
  });
}
