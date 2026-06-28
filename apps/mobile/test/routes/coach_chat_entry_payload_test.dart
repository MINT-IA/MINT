import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_entry_payload.dart';
import 'package:mint_mobile/routes/coach_chat_entry_payload.dart';

void main() {
  group('coachChatEntryPayloadFromQuery', () {
    test('maps topic query to structured context payload', () {
      final payload = coachChatEntryPayloadFromQuery(
        {'topic': 'pillar3a'},
        debugMode: false,
      );

      expect(payload, isNotNull);
      expect(payload!.source, CoachEntrySource.direct);
      expect(payload.topic, 'pillar3a');
      expect(payload.userMessage, isNull);
    });

    test('maps debug e2eUserMessage query to first user message', () {
      final payload = coachChatEntryPayloadFromQuery(
        {
          'topic': 'pillar3a',
          'e2eUserMessage': ' Quel est le plafond legal 3a 2026 avec LPP ? ',
        },
        debugMode: true,
      );

      expect(payload, isNotNull);
      expect(payload!.source, CoachEntrySource.direct);
      expect(payload.topic, 'pillar3a');
      expect(
        payload.userMessage,
        'Quel est le plafond legal 3a 2026 avec LPP ?',
      );
    });

    test('ignores e2eUserMessage outside debug builds', () {
      final payload = coachChatEntryPayloadFromQuery(
        {'e2eUserMessage': 'Quel est le plafond legal 3a 2026 avec LPP ?'},
        debugMode: false,
      );

      expect(payload, isNull);
    });
  });
}
