import 'dart:convert';

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

  // Tranche firstJob PR-E (E2) — handoff /first-job -> coach : receiptId +
  // inputsHash + receiptInputs portés par l'URL, transmis au backend pour la
  // résolution serveur du MoneyTruthReceipt (SPEC §4.3, double ceinture :
  // resolved via le store, pending via receiptInputs).
  final receiptId = query['receiptId']?.trim();
  final inputsHash = query['inputsHash']?.trim();
  final receiptInputs = _decodeReceiptInputs(query['receiptInputs']);
  final hasReceipt = receiptId != null && receiptId.isNotEmpty;

  if (debugMode && e2eUserMessage != null && e2eUserMessage.isNotEmpty) {
    return CoachEntryPayload(
      source: CoachEntrySource.direct,
      topic: topic,
      userMessage: e2eUserMessage,
      receiptId: hasReceipt ? receiptId : null,
      inputsHash: hasReceipt ? inputsHash : null,
      receiptInputs: hasReceipt ? receiptInputs : null,
    );
  }

  if ((topic != null && topic.isNotEmpty) || hasReceipt) {
    return CoachEntryPayload(
      source: CoachEntrySource.direct,
      topic: topic,
      receiptId: hasReceipt ? receiptId : null,
      inputsHash: hasReceipt ? inputsHash : null,
      receiptInputs: hasReceipt ? receiptInputs : null,
    );
  }

  return null;
}

/// Décode `receiptInputs` (JSON encodé dans l'URL). Best-effort : un JSON
/// malformé ou absent -> null (le coach retombe sur `not_found`, jamais un
/// crash de routage).
Map<String, dynamic>? _decodeReceiptInputs(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}
