/// Voice AI service — Sprint S63.
///
/// Abstract voice layer with pluggable STT/TTS backends.
/// Uses injectable [VoiceBackend] for testability — no direct dependency
/// on platform plugins. Default backend stubs return unavailable.
///
/// Swiss French (`fr-CH`) as default locale. Rate 0.85 for accessibility.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'voice_config.dart';

// ────────────────────────────────────────────────────────────
//  Voice state machine
// ────────────────────────────────────────────────────────────

/// Voice service lifecycle states.
enum VoiceState {
  /// Ready — no operation in progress.
  idle,

  /// STT is actively capturing audio.
  listening,

  /// Transcription is being processed.
  processing,

  /// TTS is reading text aloud.
  speaking,

  /// An error occurred (transient — auto-returns to idle on next call).
  error,
}

// ────────────────────────────────────────────────────────────
//  VoiceResult — STT transcription result
// ────────────────────────────────────────────────────────────

class VoiceResult {
  /// Transcribed text.
  final String transcript;

  /// Confidence score (0.0–1.0). 0 when unavailable.
  final double confidence;

  /// Duration of the audio captured.
  final Duration duration;

  /// Locale used for recognition.
  final String locale;

  const VoiceResult({
    required this.transcript,
    this.confidence = 0.0,
    this.duration = Duration.zero,
    this.locale = 'fr-CH',
  });

  /// True when the transcript is empty or whitespace-only.
  bool get isEmpty => transcript.trim().isEmpty;

  @override
  String toString() =>
      'VoiceResult("$transcript", confidence: $confidence, '
      'duration: ${duration.inMilliseconds}ms, locale: $locale)';
}

// ────────────────────────────────────────────────────────────
//  VoiceBackend — pluggable platform abstraction
// ────────────────────────────────────────────────────────────

/// Abstract backend that wraps platform STT/TTS plugins.
///
/// Implement this to plug in `speech_to_text` + `flutter_tts` or
/// any other engine. The default [StubVoiceBackend] returns unavailable
/// so the app degrades gracefully when no voice plugin is present.
abstract class VoiceBackend {
  /// Whether STT is available on this device.
  Future<bool> isSttAvailable();

  /// Whether TTS is available on this device.
  Future<bool> isTtsAvailable();

  /// Start listening. Returns transcription result when done.
  ///
  /// [maxDuration] — hard cap on listening time (default 30 s).
  /// [silenceTimeout] — stop after this many seconds of silence.
  /// [locale] — BCP-47 locale for recognition.
  Future<VoiceResult> listen({
    Duration maxDuration = const Duration(seconds: 30),
    int silenceTimeout = 3,
    String locale = 'fr-CH',
  });

  /// Cancel an in-progress listen.
  Future<void> cancelListening();

  /// Speak [text] aloud.
  Future<void> speak(
    String text, {
    String locale = 'fr-CH',
    double rate = 0.85,
    double pitch = 1.0,
  });

  /// Stop speaking immediately.
  Future<void> stopSpeaking();
}

/// Stub backend — always unavailable. Used when no plugin is configured.
class StubVoiceBackend implements VoiceBackend {
  @override
  Future<bool> isSttAvailable() async => false;
  @override
  Future<bool> isTtsAvailable() async => false;

  @override
  Future<VoiceResult> listen({
    Duration maxDuration = const Duration(seconds: 30),
    int silenceTimeout = 3,
    String locale = 'fr-CH',
  }) async =>
      throw UnsupportedError('STT non disponible sur cet appareil');

  @override
  Future<void> cancelListening() async {}

  @override
  Future<void> speak(
    String text, {
    String locale = 'fr-CH',
    double rate = 0.85,
    double pitch = 1.0,
  }) async =>
      throw UnsupportedError('TTS non disponible sur cet appareil');

  @override
  Future<void> stopSpeaking() async {}
}

// ────────────────────────────────────────────────────────────
//  VoiceService — main API
// ────────────────────────────────────────────────────────────

class VoiceService {
  /// Injected backend (defaults to stub).
  final VoiceBackend _backend;

  /// Observable voice state.
  final ValueNotifier<VoiceState> state = ValueNotifier(VoiceState.idle);

  /// Whether [dispose] has been called. Prevents setting state on a disposed
  /// notifier (e.g. from the error-recovery timer).
  bool _disposed = false;

  /// Create a VoiceService with the given [backend].
  VoiceService({VoiceBackend? backend})
      : _backend = backend ?? StubVoiceBackend();

  /// Safely set state, guarding against use-after-dispose.
  void _setState(VoiceState newState) {
    if (!_disposed) state.value = newState;
  }

  // ── STT ──────────────────────────────────────────────────

  /// Check whether speech recognition is available.
  Future<bool> isAvailable() => _backend.isSttAvailable();

  /// Check whether text-to-speech is available.
  Future<bool> isTtsAvailable() => _backend.isTtsAvailable();

  /// Start listening and return the transcription result.
  ///
  /// Respects [config] for silence timeout. Max duration capped at 30 s.
  /// Throws on backend error and sets [state] to [VoiceState.error].
  Future<VoiceResult> listen({
    Duration? maxDuration,
    String locale = 'fr-CH',
    VoiceConfig config = VoiceConfig.standard,
  }) async {
    if (state.value == VoiceState.speaking) {
      throw StateError(
          'Impossible d\'écouter pendant la synthèse vocale');
    }
    if (state.value == VoiceState.listening) {
      throw StateError('Écoute déjà en cours');
    }

    _setState(VoiceState.listening);
    try {
      final result = await _backend.listen(
        maxDuration: maxDuration ?? const Duration(seconds: 30),
        silenceTimeout: config.silenceTimeout,
        locale: locale,
      );
      _setState(VoiceState.processing);
      // In a real implementation, post-processing (punctuation, etc.) goes here.
      _setState(VoiceState.idle);
      return result;
    } catch (e) {
      _setState(VoiceState.error);
      // Auto-recover to idle so next call works.
      Future.delayed(
          const Duration(milliseconds: 500), () => _setState(VoiceState.idle));
      rethrow;
    }
  }

  /// Stop an in-progress listen.
  Future<void> stopListening() async {
    if (state.value == VoiceState.listening) {
      await _backend.cancelListening();
      _setState(VoiceState.idle);
    }
  }

  // ── TTS ──────────────────────────────────────────────────

  /// Speak [text] aloud using the given [config].
  Future<void> speak(
    String text, {
    String locale = 'fr-CH',
    VoiceConfig config = VoiceConfig.standard,
  }) async {
    if (state.value == VoiceState.listening) {
      throw StateError(
          'Impossible de parler pendant l\'écoute');
    }

    _setState(VoiceState.speaking);
    try {
      await _backend.speak(
        text,
        locale: locale,
        rate: config.speechRate,
        pitch: config.pitch,
      );
      _setState(VoiceState.idle);
    } catch (e) {
      _setState(VoiceState.error);
      Future.delayed(
          const Duration(milliseconds: 500), () => _setState(VoiceState.idle));
      rethrow;
    }
  }

  /// Stop speaking immediately.
  Future<void> stopSpeaking() async {
    if (state.value == VoiceState.speaking) {
      await _backend.stopSpeaking();
      _setState(VoiceState.idle);
    }
  }

  /// Dispose resources.
  void dispose() {
    _disposed = true;
    state.dispose();
  }
}
