/// Voice ↔ Chat integration — Sprint S63.
///
/// Bridges [VoiceService] with the existing chat system.
/// - Voice → Chat: transcribe speech, return text for sending.
/// - Chat → Voice: read coach response aloud.
/// - Full loop: listen → transcribe → callback → speak response.
library;

import 'dart:async';

import 'voice_config.dart';
import 'voice_service.dart';

// ────────────────────────────────────────────────────────────
//  VoiceChatIntegration
// ────────────────────────────────────────────────────────────

class VoiceChatIntegration {
  final VoiceService voice;
  final VoiceConfig config;

  const VoiceChatIntegration({
    required this.voice,
    this.config = VoiceConfig.standard,
  });

  // ── Voice → Chat ─────────────────────────────────────────

  /// Listen via STT and return the transcript (or `null` if empty/failed).
  ///
  /// The caller is responsible for sending the returned text as a chat message.
  Future<String?> voiceToChat({String locale = 'fr-CH'}) async {
    try {
      final result = await voice.listen(locale: locale, config: config);
      if (result.isEmpty) return null;
      return result.transcript.trim();
    } on StateError {
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Chat → Voice ─────────────────────────────────────────

  /// Read a coach response aloud using TTS.
  ///
  /// Respects [config] for speech rate and pitch.
  /// Returns silently if TTS is unavailable.
  Future<void> chatToVoice(String response, {String locale = 'fr-CH'}) async {
    if (response.trim().isEmpty) return;
    try {
      await voice.speak(response, locale: locale, config: config);
    } on StateError {
      // Listening in progress — skip TTS silently.
    } catch (_) {
      // TTS unavailable — degrade gracefully.
    }
  }

  // ── Full conversation turn ───────────────────────────────

  /// Execute a full voice conversation turn:
  /// 1. Listen (STT) → transcript
  /// 2. Pass transcript to [onTranscript] callback (e.g. send to coach)
  /// 3. Await coach response
  /// 4. If [config.autoRead] or [alwaysSpeak], speak the response (TTS)
  ///
  /// Returns the transcript (or `null` if the user said nothing).
  Future<String?> voiceConversationTurn({
    required Future<String> Function(String transcript) onTranscript,
    String locale = 'fr-CH',
    bool alwaysSpeak = false,
  }) async {
    // Step 1 — listen
    final transcript = await voiceToChat(locale: locale);
    if (transcript == null) return null;

    // Step 2+3 — send to coach and get response
    final response = await onTranscript(transcript);

    // Step 4 — speak response if configured
    if (config.autoRead || alwaysSpeak) {
      await chatToVoice(response, locale: locale);
    }

    return transcript;
  }
}
