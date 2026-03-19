import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';

void main() {
  late ConversationStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = ConversationStore();
  });

  // Helper to create ChatMessage
  ChatMessage _msg(String role, String content, {DateTime? ts}) {
    return ChatMessage(
      role: role,
      content: content,
      timestamp: ts ?? DateTime(2026, 3, 18, 10, 0),
    );
  }

  // ── ConversationMeta ────────────────────────────────────────────

  group('ConversationMeta', () {
    test('toJson/fromJson roundtrip preserves all fields', () {
      final meta = ConversationMeta(
        id: 'abc-123',
        title: 'Test conversation',
        createdAt: DateTime(2026, 1, 1),
        lastMessageAt: DateTime(2026, 3, 18),
        messageCount: 5,
        summary: 'First message summary',
        tags: ['retraite', 'lpp'],
        lastMessagePreview: 'Preview text',
      );
      final json = meta.toJson();
      final restored = ConversationMeta.fromJson(json);
      expect(restored.id, meta.id);
      expect(restored.title, meta.title);
      expect(restored.createdAt.toIso8601String(),
          meta.createdAt.toIso8601String());
      expect(restored.messageCount, 5);
      expect(restored.summary, 'First message summary');
      expect(restored.tags, ['retraite', 'lpp']);
      expect(restored.lastMessagePreview, 'Preview text');
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'x',
        'title': 'T',
        'createdAt': '2026-01-01T00:00:00.000',
        'lastMessageAt': '2026-01-01T00:00:00.000',
      };
      final meta = ConversationMeta.fromJson(json);
      expect(meta.messageCount, 0);
      expect(meta.summary, isNull);
      expect(meta.tags, isEmpty);
      expect(meta.lastMessagePreview, isNull);
    });

    test('copyWith updates only specified fields', () {
      final meta = ConversationMeta(
        id: 'a',
        title: 'Old',
        createdAt: DateTime(2026, 1, 1),
        lastMessageAt: DateTime(2026, 1, 1),
        messageCount: 1,
      );
      final updated = meta.copyWith(title: 'New', messageCount: 5);
      expect(updated.id, 'a'); // unchanged
      expect(updated.title, 'New');
      expect(updated.messageCount, 5);
    });
  });

  // ── saveConversation / loadConversation ──────────────────────────

  group('saveConversation + loadConversation', () {
    test('saves and loads messages correctly', () async {
      final messages = [
        _msg('user', 'Bonjour'),
        _msg('assistant', 'Salut !'),
      ];
      await store.saveConversation('conv-1', messages);
      final loaded = await store.loadConversation('conv-1');
      expect(loaded.length, 2);
      expect(loaded[0].role, 'user');
      expect(loaded[0].content, 'Bonjour');
      expect(loaded[1].role, 'assistant');
    });

    test('returns empty list for non-existent conversation', () async {
      final loaded = await store.loadConversation('does-not-exist');
      expect(loaded, isEmpty);
    });

    test('skips save when messages list is empty', () async {
      await store.saveConversation('empty', []);
      final loaded = await store.loadConversation('empty');
      expect(loaded, isEmpty);
    });

    test('preserves timestamp on roundtrip', () async {
      final ts = DateTime(2026, 3, 18, 14, 30, 45);
      final messages = [_msg('user', 'Test', ts: ts)];
      await store.saveConversation('ts-test', messages);
      final loaded = await store.loadConversation('ts-test');
      expect(loaded.first.timestamp, ts);
    });

    test('preserves tier on roundtrip', () async {
      final messages = [
        ChatMessage(
          role: 'assistant',
          content: 'Response',
          timestamp: DateTime(2026, 3, 18),
          tier: ChatTier.byok,
        ),
      ];
      await store.saveConversation('tier-test', messages);
      final loaded = await store.loadConversation('tier-test');
      expect(loaded.first.tier, ChatTier.byok);
    });

    test('preserves suggestedActions and disclaimers', () async {
      final messages = [
        ChatMessage(
          role: 'assistant',
          content: 'Hello',
          timestamp: DateTime(2026, 3, 18),
          suggestedActions: ['Action 1', 'Action 2'],
          disclaimers: ['Disclaimer 1'],
        ),
      ];
      await store.saveConversation('extras', messages);
      final loaded = await store.loadConversation('extras');
      expect(loaded.first.suggestedActions, ['Action 1', 'Action 2']);
      expect(loaded.first.disclaimers, ['Disclaimer 1']);
    });
  });

  // ── listConversations ───────────────────────────────────────────

  group('listConversations', () {
    test('returns empty list initially', () async {
      final list = await store.listConversations();
      expect(list, isEmpty);
    });

    test('returns conversations sorted by lastMessageAt descending', () async {
      await store.saveConversation('old', [
        _msg('user', 'Old message', ts: DateTime(2026, 1, 1)),
      ]);
      await store.saveConversation('new', [
        _msg('user', 'New message', ts: DateTime(2026, 3, 18)),
      ]);
      final list = await store.listConversations();
      expect(list.length, 2);
      expect(list.first.id, 'new');
      expect(list.last.id, 'old');
    });

    test('generates title from first user message', () async {
      await store.saveConversation('titled', [
        _msg('user', 'Comment fonctionne le 3a ?'),
        _msg('assistant', 'Le 3a est un pilier...'),
      ]);
      final list = await store.listConversations();
      expect(list.first.title, 'Comment fonctionne le 3a ?');
    });

    test('truncates long titles to 50 chars + ellipsis', () async {
      final longMsg = 'A' * 100;
      await store.saveConversation('long-title', [
        _msg('user', longMsg),
      ]);
      final list = await store.listConversations();
      expect(list.first.title.length, 53); // 50 + "..."
    });

    test('uses "Conversation" as title when no user message', () async {
      await store.saveConversation('no-user', [
        _msg('system', 'System init'),
      ]);
      final list = await store.listConversations();
      expect(list.first.title, 'Conversation');
    });
  });

  // ── deleteConversation ──────────────────────────────────────────

  group('deleteConversation', () {
    test('removes conversation and its messages', () async {
      await store.saveConversation('to-delete', [
        _msg('user', 'Will be deleted'),
      ]);
      await store.deleteConversation('to-delete');
      final list = await store.listConversations();
      expect(list, isEmpty);
      final messages = await store.loadConversation('to-delete');
      expect(messages, isEmpty);
    });

    test('deleting non-existent conversation does not throw', () async {
      await store.deleteConversation('ghost');
      // No exception
    });
  });

  // ── renameConversation ──────────────────────────────────────────

  group('renameConversation', () {
    test('updates the title in the index', () async {
      await store.saveConversation('rename-me', [
        _msg('user', 'Original title'),
      ]);
      await store.renameConversation('rename-me', 'New Title');
      final list = await store.listConversations();
      expect(list.first.title, 'New Title');
    });

    test('renaming non-existent conversation does nothing', () async {
      await store.renameConversation('ghost', 'Title');
      // No exception, no side effects
    });
  });

  // ── Tag inference ──────────────────────────────────────────────

  group('tag inference', () {
    test('infers retraite tag from message content', () async {
      await store.saveConversation('tags-retraite', [
        _msg('user', 'Quand puis-je prendre ma retraite ?'),
      ]);
      final list = await store.listConversations();
      expect(list.first.tags, contains('retraite'));
    });

    test('infers multiple tags from mixed content', () async {
      await store.saveConversation('tags-multi', [
        _msg('user', 'Mon LPP et mon budget retraite'),
      ]);
      final list = await store.listConversations();
      expect(list.first.tags, containsAll(['lpp', 'budget', 'retraite']));
    });

    test('infers immobilier tag from hypotheque keyword', () async {
      await store.saveConversation('tags-immo', [
        _msg('user', 'Je cherche une hypothèque'),
      ]);
      final list = await store.listConversations();
      expect(list.first.tags, contains('immobilier'));
    });
  });

  // ── Summary generation ──────────────────────────────────────────

  group('summary generation', () {
    test('generates summary from first user message', () async {
      await store.saveConversation('summary-test', [
        _msg('user', 'Comment optimiser mes impots ?'),
        _msg('assistant', 'Voici quelques pistes...'),
      ]);
      final list = await store.listConversations();
      expect(list.first.summary, contains('impots'));
    });

    test('truncates summary at 120 chars', () async {
      final longMsg = 'X' * 200;
      await store.saveConversation('summary-long', [
        _msg('user', longMsg),
      ]);
      final list = await store.listConversations();
      expect(list.first.summary!.length, 123); // 120 + "..."
    });
  });

  // ── lastMessagePreview ──────────────────────────────────────────

  group('lastMessagePreview', () {
    test('truncates at 80 chars + ellipsis for long messages', () async {
      final longMsg = 'Z' * 200;
      await store.saveConversation('preview-long', [
        _msg('user', longMsg),
      ]);
      final list = await store.listConversations();
      expect(list.first.lastMessagePreview!.length, 83); // 80 + "..."
    });

    test('keeps short message as-is', () async {
      await store.saveConversation('preview-short', [
        _msg('user', 'Short'),
      ]);
      final list = await store.listConversations();
      expect(list.first.lastMessagePreview, 'Short');
    });
  });

  // ── Update existing conversation ────────────────────────────────

  group('update existing conversation', () {
    test('preserves original title and createdAt on update', () async {
      await store.saveConversation('evolving', [
        _msg('user', 'First message', ts: DateTime(2026, 1, 1)),
      ]);
      await store.saveConversation('evolving', [
        _msg('user', 'First message', ts: DateTime(2026, 1, 1)),
        _msg('assistant', 'Reply', ts: DateTime(2026, 3, 18)),
      ]);
      final list = await store.listConversations();
      final meta = list.firstWhere((m) => m.id == 'evolving');
      expect(meta.title, 'First message'); // original title preserved
      expect(meta.createdAt, DateTime(2026, 1, 1)); // original date preserved
      expect(meta.messageCount, 2); // updated
    });
  });
}
