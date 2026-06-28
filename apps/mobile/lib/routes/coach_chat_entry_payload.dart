import 'package:flutter/foundation.dart';
import 'package:mint_mobile/models/coach_entry_payload.dart';

/// Builds the contextual payload consumed by `/coach/chat`.
///
/// Production links only carry structured `topic` context. Debug simulator
/// gates may carry `e2eUserMessage` so a runtime proof can exercise the real
/// Coach turn pipeline even when native automation cannot focus Flutter's
/// bottom text field.
CoachEntryPayload? coachChatEntryPayloadFromQuery(
  Map<String, String> query, {
  bool debugMode = kDebugMode,
}) {
  final topic = query['topic'];
  final e2eUserMessage = query['e2eUserMessage']?.trim();

  if (debugMode && e2eUserMessage != null && e2eUserMessage.isNotEmpty) {
    return CoachEntryPayload(
      source: CoachEntrySource.direct,
      topic: topic,
      userMessage: e2eUserMessage,
    );
  }

  if (topic != null && topic.isNotEmpty) {
    return CoachEntryPayload(
      source: CoachEntrySource.direct,
      topic: topic,
    );
  }

  return null;
}
