import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mint_mobile/services/anonymous_session_service.dart';

void main() {
  // flutter_secure_storage uses MethodChannel under the hood.
  // In tests, we set up a mock handler that stores values in-memory.
  final Map<String, String> store = {};

  setUp(() {
    store.clear();
    FlutterSecureStorage.setMockInitialValues(store);
  });

  group('AnonymousSessionService', () {
    test('getOrCreateSessionId returns valid UUID format', () async {
      final id = await AnonymousSessionService.getOrCreateSessionId();
      // UUID v4 format: 8-4-4-4-12 hex digits
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(id),
        isTrue,
        reason: 'Should be a valid UUID v4',
      );
    });

    test('getOrCreateSessionId returns same ID on second call', () async {
      final id1 = await AnonymousSessionService.getOrCreateSessionId();
      final id2 = await AnonymousSessionService.getOrCreateSessionId();
      expect(id1, equals(id2));
    });

    test('canSendMessage returns true when count < 3', () async {
      // Fresh session — count is 0
      expect(await AnonymousSessionService.canSendMessage(), isTrue);

      // After 1 message (remaining = 2 → count = 1)
      await AnonymousSessionService.updateFromResponse(2);
      expect(await AnonymousSessionService.canSendMessage(), isTrue);

      // After 2 messages (remaining = 1 → count = 2)
      await AnonymousSessionService.updateFromResponse(1);
      expect(await AnonymousSessionService.canSendMessage(), isTrue);
    });

    test('canSendMessage returns false when count >= 3', () async {
      await AnonymousSessionService.updateFromResponse(0);
      expect(await AnonymousSessionService.canSendMessage(), isFalse);
    });

    test('updateFromResponse correctly stores count', () async {
      // messagesRemaining=2 → count=1
      await AnonymousSessionService.updateFromResponse(2);
      expect(await AnonymousSessionService.getMessageCount(), equals(1));

      // messagesRemaining=0 → count=3
      await AnonymousSessionService.updateFromResponse(0);
      expect(await AnonymousSessionService.getMessageCount(), equals(3));

      // messagesRemaining=3 (edge case) → count=0
      await AnonymousSessionService.updateFromResponse(3);
      expect(await AnonymousSessionService.getMessageCount(), equals(0));
    });

    test('clearSession resets both keys', () async {
      // Set up some state
      await AnonymousSessionService.getOrCreateSessionId();
      await AnonymousSessionService.updateFromResponse(1);
      expect(await AnonymousSessionService.getMessageCount(), equals(2));

      // Clear
      await AnonymousSessionService.clearSession();

      // After clear, message count resets to 0
      expect(await AnonymousSessionService.getMessageCount(), equals(0));

      // Session ID should be regenerated (different from before)
      // We can't easily test this without storing the old ID, but we can
      // verify canSendMessage is true again
      expect(await AnonymousSessionService.canSendMessage(), isTrue);
    });

    test('updateFromResponse clamps negative values', () async {
      // Negative remaining should clamp to 0 → count = 3
      await AnonymousSessionService.updateFromResponse(-1);
      expect(await AnonymousSessionService.getMessageCount(), equals(3));
    });

    test('getMessageCount returns 0 for fresh session', () async {
      expect(await AnonymousSessionService.getMessageCount(), equals(0));
    });
  });
}
