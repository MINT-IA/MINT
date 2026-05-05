// Phase 57 PR-B — wiring test for AnonymousChatScreen × AnonymousChatPersistence.
//
// What we cover :
//
//   1. Hydrate path : a fresh, non-expired snapshot pre-populates the
//      message list (closes the « 3-msg dead-end » UX bug).
//   2. Expired snapshot : screen mounts blank — we do NOT show stale
//      content past the 7-day TTL.
//   3. Save path : sending a message calls persistence.save with the
//      correct role/content payload.
//   4. Clear path : the auth-flow consent boundary is wired ; calling
//      `AnonymousChatPersistence().clear()` removes the snapshot key
//      (this is the contract auth_provider._migrateLocalDataIfNeeded
//      relies on after register_success).
//
// We use a thin in-memory fake `_RecordingPersistence` that wraps a real
// `AnonymousChatPersistence` over `SharedPreferences.setMockInitialValues`
// so we observe save/clear/load semantics without re-implementing the
// envelope codec — the data-layer tests in PR-A already cover that.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/anonymous/anonymous_chat_screen.dart';
import 'package:mint_mobile/services/anonymous_chat_persistence.dart';
import 'package:mint_mobile/services/coach_llm_service.dart' show ChatMessage;

/// Records every save/clear call so the test can assert on them, while
/// delegating actual storage to a real `AnonymousChatPersistence`.
class _RecordingPersistence extends AnonymousChatPersistence {
  _RecordingPersistence();

  int saveCalls = 0;
  int clearCalls = 0;
  List<ChatMessage>? lastSavedMessages;
  String? lastSavedIntent;

  @override
  Future<void> save({
    required List<ChatMessage> messages,
    String? intent,
  }) async {
    saveCalls += 1;
    lastSavedMessages = List<ChatMessage>.from(messages);
    lastSavedIntent = intent;
    await super.save(messages: messages, intent: intent);
  }

  @override
  Future<void> clear() async {
    clearCalls += 1;
    await super.clear();
  }
}

Widget _testApp({
  String? intent,
  AnonymousChatPersistence? persistence,
}) {
  return MaterialApp(
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    locale: const Locale('fr'),
    home: AnonymousChatScreen(intent: intent, persistence: persistence),
  );
}

/// Pre-seed SharedPreferences with a `mint.anonymous.chat.v1` envelope.
/// Mirrors the exact codec written by `AnonymousChatPersistence.save`
/// so the screen's load() path picks it up unchanged.
void _seedSnapshot({
  required List<Map<String, String>> messages,
  required Duration relativeExpiry,
  String? intent,
}) {
  final envelope = <String, dynamic>{
    'version': AnonymousChatPersistence.schemaVersion,
    'expiresAt':
        DateTime.now().toUtc().add(relativeExpiry).toIso8601String(),
    if (intent != null) 'intent': intent,
    'messages': messages,
  };
  SharedPreferences.setMockInitialValues(<String, Object>{
    AnonymousChatPersistence.storageKey: jsonEncode(envelope),
  });
}

void main() {
  // The SharedPreferences plugin caches a singleton across getInstance()
  // calls in the same isolate. setUp() must therefore re-prime the mock
  // BEFORE every test — otherwise a prior test's seed bleeds in. Same for
  // FlutterSecureStorage (used by AnonymousSessionService) ; without a
  // mock, the canSendMessage gate throws and _sendMessage early-returns
  // before persistence.save is reached.
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  group('AnonymousChatScreen × AnonymousChatPersistence wiring', () {
    testWidgets('hydrates fresh snapshot into message list', (tester) async {
      final now = DateTime.now().toUtc();
      _seedSnapshot(
        relativeExpiry: const Duration(days: 1),
        messages: [
          {
            'role': 'user',
            'content': 'Mon test fraichement persiste',
            'ts': now.subtract(const Duration(minutes: 2)).toIso8601String(),
          },
          {
            'role': 'assistant',
            'content': 'Reponse coach hydratee depuis le disque',
            'ts': now.subtract(const Duration(minutes: 1)).toIso8601String(),
          },
        ],
      );

      await tester.pumpWidget(_testApp(persistence: _RecordingPersistence()));
      // initState's postFrameCallback awaits load() then calls setState.
      // First pump fires the postFrameCallback ; we need to drain the
      // microtask queue (the await inside) and then a second pump for
      // the setState frame to land.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Mon test fraichement persiste'), findsOneWidget);
      expect(
        find.text('Reponse coach hydratee depuis le disque'),
        findsOneWidget,
      );
    });

    testWidgets('expired snapshot renders blank canvas', (tester) async {
      final now = DateTime.now().toUtc();
      _seedSnapshot(
        // Negative expiry → already expired.
        relativeExpiry: const Duration(days: -1),
        messages: [
          {
            'role': 'user',
            'content': 'Ce message est trop vieux',
            'ts': now.subtract(const Duration(days: 8)).toIso8601String(),
          },
          {
            'role': 'assistant',
            'content': 'Cette reponse est trop vieille',
            'ts': now.subtract(const Duration(days: 8)).toIso8601String(),
          },
        ],
      );

      await tester.pumpWidget(_testApp(persistence: _RecordingPersistence()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      // Stale content MUST NOT surface past the 7-day TTL.
      expect(find.text('Ce message est trop vieux'), findsNothing);
      expect(find.text('Cette reponse est trop vieille'), findsNothing);
    });

    testWidgets('send-message triggers persistence.save with user content',
        (tester) async {
      final recording = _RecordingPersistence();

      await tester.pumpWidget(_testApp(persistence: recording));
      // Drain initState postFrameCallback (load() + setState).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Pre-condition : nothing saved yet (empty initial snapshot).
      expect(recording.saveCalls, 0);

      // Type a message and submit via the keyboard "send" action.
      // _sendMessage awaits AnonymousSessionService.canSendMessage() then
      // does the optimistic append + _persistToSharedPreferences synchronously
      // before kicking off the LLM API call. Multiple pumps drain the await
      // chain ; the API call itself fails in the test env (no fixture for
      // /anonymous/chat) but lands in the catch branch which still executes
      // a save() — either path proves the wiring.
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'Premier message persiste');
      await tester.pump();
      // Tap the send IconButton ; this calls _sendMessage(_inputController.text)
      // synchronously (the controller already holds our entered text).
      final sendButton = find.byIcon(Icons.send_rounded);
      expect(sendButton, findsOneWidget);
      // warnIfMissed=false so the test passes even if the icon is in a
      // partially off-screen position in the default test viewport.
      await tester.tap(sendButton, warnIfMissed: false);
      // Drain the await chain (canSendMessage SecureStorage probe +
      // SharedPreferences fallback + setState).
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(
        recording.saveCalls,
        greaterThanOrEqualTo(1),
        reason: 'persistence.save must be called after the user-send append',
      );
      final saved = recording.lastSavedMessages;
      expect(saved, isNotNull);
      expect(saved!.any((m) => m.role == 'user'), isTrue);
      expect(
        saved.any((m) => m.content == 'Premier message persiste'),
        isTrue,
        reason: 'the saved snapshot must include the just-typed user message',
      );

      // Let any in-flight LLM error path / 800ms delays settle so they
      // don't leak Timers into subsequent tests.
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    test('AnonymousChatPersistence().clear() removes the snapshot key', () async {
      final now = DateTime.now().toUtc();
      _seedSnapshot(
        relativeExpiry: const Duration(days: 1),
        messages: [
          {
            'role': 'user',
            'content': 'avant clear',
            'ts': now.toIso8601String(),
          },
        ],
      );

      // Sanity : the seeded snapshot is loadable before clear().
      final persistence = AnonymousChatPersistence();
      final before = await persistence.load();
      expect(before, isNotNull);
      expect(before!.messages.length, 1);

      // This is the exact call wired into auth_provider._migrateLocalDataIfNeeded
      // immediately after ConversationStore.migrateAnonymousToUser — we
      // assert here that it actually drops the SharedPreferences key, so
      // a regression in the auth wiring would surface as this test failing
      // in tandem with a behavioural smoke.
      await persistence.clear();

      final after = await persistence.load();
      expect(after, isNull,
          reason:
              'clear() must remove the mint.anonymous.chat.v1 envelope so '
              'no anonymous transcript survives past register_success');
    });
  });
}
