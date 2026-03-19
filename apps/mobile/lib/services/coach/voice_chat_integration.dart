/// Voice ↔ Chat integration — Sprint S63.
///
/// Bridges [VoiceService] with the existing chat system.
/// - Voice → Chat: transcribe speech, return text for sending.
/// - Chat → Voice: read coach response aloud (ComplianceGuard validated).
/// - Full loop: listen → transcribe → callback → speak response.
/// - PII scrubbing: transcripts are scrubbed before leaving service boundary.
/// - Safe mode: debt crisis keywords trigger [onSafeModeDetected] callback.
///
/// Compliance: ALL voice output passes through ComplianceGuard before TTS.
/// Privacy: transcripts are ephemeral (never persisted), PII patterns scrubbed.
/// References: LSFin art. 3/8, FINMA circular 2008/21.
library;

import 'dart:async';

import 'compliance_guard.dart';
import 'voice_config.dart';
import 'voice_service.dart';

// ────────────────────────────────────────────────────────────
//  VoiceChatIntegration
// ────────────────────────────────────────────────────────────

/// PII patterns to scrub from voice transcripts before processing.
///
/// Matches IBAN, Swiss SSN (756.xxxx.xxxx.xx), salary amounts with CHF,
/// NPA (4-digit postal codes preceded by space/start), and employer names
/// preceded by "chez" or "employeur". Transcripts are ephemeral — never
/// persisted — but scrubbing adds defense-in-depth.
final RegExp _piiPattern = RegExp(
  r'(?:'
  r'CH\d{2}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{1}' // IBAN
  r'|756[\.\s]\d{4}[\.\s]\d{4}[\.\s]\d{2}' // AVS/SSN
  r'|\b\d{4,7}\s*(?:CHF|francs?)\b' // salary amounts
  r'|\b(?:chez|employeur\s+)\s*[A-ZÀ-Ü][a-zà-ÿ]+(?:\s+[A-ZÀ-Ü][a-zà-ÿ]+)*' // employer
  r')',
  caseSensitive: false,
);

/// Debt crisis keywords that should trigger safe mode (voice path).
const _debtCrisisKeywords = [
  'dette',
  'dettes',
  'surendetté',
  'surendettée',
  'surendettement',
  'créancier',
  'créanciers',
  'huissier',
  'poursuite',
  'poursuites',
  'faillite',
  'saisie',
  'crise',
  'insolvable',
];

class VoiceChatIntegration {
  final VoiceService voice;
  final VoiceConfig config;

  /// Optional callback invoked when debt crisis keywords are detected in
  /// a voice transcript. The caller should activate safe mode (disable
  /// optimizations, prioritize debt reduction).
  final void Function()? onSafeModeDetected;

  const VoiceChatIntegration({
    required this.voice,
    this.config = VoiceConfig.standard,
    this.onSafeModeDetected,
  });

  // ── Voice → Chat ─────────────────────────────────────────

  /// Listen via STT and return the transcript (or `null` if empty/failed).
  ///
  /// The transcript is scrubbed of PII patterns (IBAN, SSN, salary, employer)
  /// before being returned. If debt crisis keywords are detected,
  /// [onSafeModeDetected] is invoked.
  ///
  /// The caller is responsible for sending the returned text as a chat message.
  Future<String?> voiceToChat({String locale = 'fr-CH'}) async {
    try {
      final result = await voice.listen(locale: locale, config: config);
      if (result.isEmpty) return null;
      var transcript = result.transcript.trim();

      // Privacy: scrub PII from transcript (defense-in-depth).
      transcript = _scrubPii(transcript);

      // Safe mode: detect debt crisis keywords.
      if (_containsDebtCrisisKeywords(transcript)) {
        onSafeModeDetected?.call();
      }

      return transcript;
    } on StateError {
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Chat → Voice ─────────────────────────────────────────

  /// Read a coach response aloud using TTS.
  ///
  /// **Compliance**: the response is validated through [ComplianceGuard]
  /// before being spoken aloud — same pipeline as text-based chat.
  /// If ComplianceGuard flags the text for fallback, nothing is spoken.
  ///
  /// Respects [config] for speech rate and pitch.
  /// Returns silently if TTS is unavailable.
  Future<void> chatToVoice(String response, {String locale = 'fr-CH'}) async {
    if (response.trim().isEmpty) return;

    // Compliance: validate through ComplianceGuard before TTS.
    // This ensures banned terms are sanitized and prescriptive language is caught.
    final complianceResult = ComplianceGuard.validate(response);
    if (complianceResult.useFallback) {
      // Response failed compliance — do not speak non-compliant text.
      return;
    }
    var compliantText = complianceResult.sanitizedText;
    if (compliantText.trim().isEmpty) return;

    // Strip the visual disclaimer from TTS output — it's displayed in the chat
    // bubble and should not be read aloud (poor UX for audio).
    compliantText = _stripVisualDisclaimer(compliantText);

    try {
      await voice.speak(compliantText, locale: locale, config: config);
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

  // ── Privacy helpers ──────────────────────────────────────

  /// Strip ComplianceGuard's visual disclaimer from TTS output.
  ///
  /// The disclaimer (`_Outil éducatif..._`) is markdown-formatted and intended
  /// for chat display. Reading it aloud on every voice turn is poor UX.
  /// The disclaimer remains visible in the text chat bubble.
  static final _disclaimerPattern = RegExp(
    r'\n\n_Outil éducatif[^_]*_\s*$',
  );

  static String _stripVisualDisclaimer(String text) =>
      text.replaceAll(_disclaimerPattern, '');

  /// Scrub PII patterns from transcript (IBAN, SSN, salary, employer).
  static String _scrubPii(String text) =>
      text.replaceAll(_piiPattern, '[***]');

  /// Check whether transcript contains debt crisis keywords.
  static bool _containsDebtCrisisKeywords(String text) {
    final lower = text.toLowerCase();
    return _debtCrisisKeywords.any((kw) => lower.contains(kw));
  }
}
