// Regression test for BUG-P1-A02: anon chat permanent lockout when the
// `/anonymous/chat` 200 response drops the `messagesRemaining` key.
//
// Before: `final remaining = json['messagesRemaining'] as int? ?? 0;`
//         `await AnonymousSessionService.updateFromResponse(remaining);`
//         → count = 3 - 0 = 3 → user locked out on the very first reply.
// After:  the helper only writes when the key is present.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:mint_mobile/services/anonymous_session_service.dart';
import 'package:mint_mobile/services/coach/coach_chat_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, String> store = {};
  setUp(() {
    store.clear();
    FlutterSecureStorage.setMockInitialValues(store);
  });

  group('syncAnonymousRemainingFromResponse', () {
    test('present: writes count = 3 - remaining', () async {
      await CoachChatApiService.syncAnonymousRemainingFromResponse({
        'messagesRemaining': 2,
      });
      expect(await AnonymousSessionService.getMessageCount(), 1);
      expect(await AnonymousSessionService.canSendMessage(), isTrue);
    });

    test('present and zero: locks out (rate-limit semantics)', () async {
      await CoachChatApiService.syncAnonymousRemainingFromResponse({
        'messagesRemaining': 0,
      });
      expect(await AnonymousSessionService.getMessageCount(), 3);
      expect(await AnonymousSessionService.canSendMessage(), isFalse);
    });

    test('absent: count untouched, user can still send', () async {
      // Backend returned 200 OK but dropped the key (schema drift, partial
      // payload, future change). The helper must NOT lock the user out.
      await CoachChatApiService.syncAnonymousRemainingFromResponse({
        'message': 'whatever',
      });
      expect(await AnonymousSessionService.getMessageCount(), 0);
      expect(await AnonymousSessionService.canSendMessage(), isTrue);
    });

    test('absent on a fresh session, then present on the next turn',
        () async {
      // First reply: backend dropped the key → no write.
      await CoachChatApiService.syncAnonymousRemainingFromResponse({
        'message': 'a',
      });
      expect(await AnonymousSessionService.getMessageCount(), 0);

      // Second reply: backend includes it → state catches up.
      await CoachChatApiService.syncAnonymousRemainingFromResponse({
        'messagesRemaining': 1,
      });
      expect(await AnonymousSessionService.getMessageCount(), 2);
      expect(await AnonymousSessionService.canSendMessage(), isTrue);
    });

    test('non-int messagesRemaining: cast fails → null → no write', () async {
      // Defensive: a stringy value should not crash and should not lock out.
      await CoachChatApiService.syncAnonymousRemainingFromResponse({
        'messagesRemaining': 'oops',
      });
      expect(await AnonymousSessionService.getMessageCount(), 0);
    });
  });
}
