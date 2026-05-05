// Phase 57 PR-A — AnonymousChatPersistence unit tests.
//
// Six tests cover the contract documented in
// lib/services/anonymous_chat_persistence.dart :
//
//   1. save / load round-trip preserves the role + content + timestamp
//      triplet exactly.
//   2. TTL expiry : a snapshot whose expiresAt is in the past returns null
//      from load() (clean-slate semantics).
//   3. clear() removes the entry and is idempotent (calling twice is OK).
//   4. intent is preserved when provided ; null when omitted ; empty
//      string is treated as null (envelope hygiene).
//   5. malformed JSON in storage is treated as missing data — load()
//      never throws.
//   6. version mismatch is treated as missing data — never crashes the
//      chat UI on a schema bump.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/services/anonymous_chat_persistence.dart';
import 'package:mint_mobile/services/coach_llm_service.dart' show ChatMessage;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('AnonymousChatPersistence', () {
    test('save/load round-trip preserves role/content/timestamp exactly',
        () async {
      final svc = AnonymousChatPersistence();
      final ts1 = DateTime.utc(2026, 5, 5, 10, 0, 0);
      final ts2 = DateTime.utc(2026, 5, 5, 10, 0, 30);

      await svc.save(messages: [
        ChatMessage(role: 'user', content: 'Bonjour', timestamp: ts1),
        ChatMessage(
            role: 'assistant',
            content: 'Quelle clarté tu cherches ?',
            timestamp: ts2),
      ]);

      final snapshot = await svc.load();
      expect(snapshot, isNotNull);
      expect(snapshot!.messages, hasLength(2));
      expect(snapshot.messages[0].role, 'user');
      expect(snapshot.messages[0].content, 'Bonjour');
      expect(snapshot.messages[0].timestamp.toUtc(), ts1);
      expect(snapshot.messages[1].role, 'assistant');
      expect(snapshot.messages[1].content, 'Quelle clarté tu cherches ?');
      expect(snapshot.messages[1].timestamp.toUtc(), ts2);
    });

    test('TTL expiry returns null on load() (clean-slate semantics)',
        () async {
      // Force-write an envelope whose expiresAt is in the past, then load.
      final prefs = await SharedPreferences.getInstance();
      final pastEnvelope = <String, dynamic>{
        'version': AnonymousChatPersistence.schemaVersion,
        'expiresAt': DateTime.utc(2024, 1, 1).toIso8601String(),
        'messages': [
          {
            'role': 'user',
            'content': 'salut',
            'ts': DateTime.utc(2024, 1, 1).toIso8601String(),
          }
        ],
      };
      await prefs.setString(
        AnonymousChatPersistence.storageKey,
        jsonEncode(pastEnvelope),
      );

      final svc = AnonymousChatPersistence();
      final snapshot = await svc.load();
      expect(snapshot, isNull);

      // isExpired() reports true for the same fixture.
      expect(await svc.isExpired(), isTrue);
    });

    test('clear() removes entry and is idempotent', () async {
      final svc = AnonymousChatPersistence();
      await svc.save(messages: [
        ChatMessage(
            role: 'user', content: 'x', timestamp: DateTime.utc(2026, 5, 5)),
      ]);

      expect(await svc.load(), isNotNull);

      await svc.clear();
      expect(await svc.load(), isNull);

      // Second clear must not throw.
      await svc.clear();
      expect(await svc.load(), isNull);
    });

    test('intent is preserved when provided ; null when omitted or empty',
        () async {
      final svc = AnonymousChatPersistence();
      final ts = DateTime.utc(2026, 5, 5, 10, 0, 0);

      // Provided intent → preserved.
      await svc.save(
        messages: [ChatMessage(role: 'user', content: 'a', timestamp: ts)],
        intent: 'rente_vs_capital',
      );
      var snapshot = await svc.load();
      expect(snapshot!.intent, 'rente_vs_capital');

      // Omitted intent → null on load.
      await svc.clear();
      await svc.save(
        messages: [ChatMessage(role: 'user', content: 'b', timestamp: ts)],
      );
      snapshot = await svc.load();
      expect(snapshot!.intent, isNull);

      // Empty-string intent → treated as null (envelope hygiene).
      await svc.clear();
      await svc.save(
        messages: [ChatMessage(role: 'user', content: 'c', timestamp: ts)],
        intent: '',
      );
      snapshot = await svc.load();
      expect(snapshot!.intent, isNull);
    });

    test('malformed JSON in storage is treated as missing data', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        AnonymousChatPersistence.storageKey,
        '{not-valid-json',
      );
      final svc = AnonymousChatPersistence();
      // Must NOT throw — chat UI treats malformed storage as clean slate.
      final snapshot = await svc.load();
      expect(snapshot, isNull);
      expect(await svc.isExpired(), isFalse);
    });

    test('version mismatch returns null on load()', () async {
      final prefs = await SharedPreferences.getInstance();
      final futureEnvelope = <String, dynamic>{
        'version': AnonymousChatPersistence.schemaVersion + 99,
        'expiresAt': DateTime.utc(2099, 1, 1).toIso8601String(),
        'messages': [
          {
            'role': 'user',
            'content': 'from-the-future',
            'ts': DateTime.utc(2099, 1, 1).toIso8601String(),
          }
        ],
      };
      await prefs.setString(
        AnonymousChatPersistence.storageKey,
        jsonEncode(futureEnvelope),
      );

      final svc = AnonymousChatPersistence();
      final snapshot = await svc.load();
      expect(snapshot, isNull);
    });
  });
}
