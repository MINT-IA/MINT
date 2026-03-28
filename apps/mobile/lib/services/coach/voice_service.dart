/// Voice AI service — Sprint S63.
///
/// Abstract voice layer with pluggable STT/TTS backends.
/// Uses injectable [VoiceBackend] for testability — no direct dependency
/// on platform plugins. Default backend stubs return unavailable.
///
/// Swiss French (`fr-CH`) as default locale. Rate 0.85 for accessibility.
///
/// [VoiceStateMachine] is used internally to validate every state transition.
/// Invalid transitions (e.g. listen while speaking) throw [StateError] before
/// touching the backend — providing a clean guard layer independent of the
/// [VoiceBackend] implementation.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mint_mobile/services/voice/voice_state_machine.dart';

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

  /// Internal state machine — validates every transition before it occurs.
  ///
  /// [VoiceStateMachine] uses [VoiceMode] (its own enum); [VoiceService]
  /// maps to/from [VoiceState] for the public API. They stay in sync via
  /// [_applyMode].
  final VoiceStateMachine _machine = VoiceStateMachine();

  /// Cancellation generation counter.
  ///
  /// Incremented whenever [stopListening], [stopSpeaking], or [_forceIdle]
  /// is called. In-flight listen/speak coroutines compare their captured
  /// generation to [_generation] before applying further state transitions —
  /// if different, the operation was cancelled and they exit silently.
  int _generation = 0;

  /// Whether [dispose] has been called. Prevents setting state on a disposed
  /// notifier (e.g. from the error-recovery timer).
  bool _disposed = false;

  /// Create a VoiceService with the given [backend].
  VoiceService({VoiceBackend? backend})
      : _backend = backend ?? StubVoiceBackend();

  // ── State helpers ─────────────────────────────────────────

  /// Safely set state, guarding against use-after-dispose.
  void _setState(VoiceState newState) {
    if (!_disposed) state.value = newState;
  }

  /// Apply a [VoiceMode] through the state machine, then mirror it to the
  /// public [VoiceState] notifier. Throws [StateError] on invalid transitions
  /// (propagated from [VoiceStateMachine.transition]).
  void _applyMode(VoiceMode mode) {
    _machine.transition(mode);
    _setState(_modeToState(mode));
  }

  /// Force both the state machine and the public notifier back to idle.
  ///
  /// Increments [_generation] so any in-flight coroutine that captured the
  /// old generation will detect cancellation and exit without applying further
  /// state transitions.
  ///
  /// Used for error recovery and cancellation — always succeeds.
  void _forceIdle() {
    _generation++;
    _machine.forceIdle();
    _setState(VoiceState.idle);
  }

  /// Map [VoiceMode] → [VoiceState] for the public API.
  static VoiceState _modeToState(VoiceMode mode) {
    switch (mode) {
      case VoiceMode.idle:
        return VoiceState.idle;
      case VoiceMode.listening:
        return VoiceState.listening;
      case VoiceMode.processing:
        return VoiceState.processing;
      case VoiceMode.speaking:
        return VoiceState.speaking;
    }
  }

  // ── STT ──────────────────────────────────────────────────

  /// Check whether speech recognition is available.
  Future<bool> isAvailable() => _backend.isSttAvailable();

  /// Check whether text-to-speech is available.
  Future<bool> isTtsAvailable() => _backend.isTtsAvailable();

  /// Start listening and return the transcription result.
  ///
  /// Respects [config] for silence timeout. Max duration capped at 30 s.
  /// [VoiceStateMachine] guards against calling this while speaking or
  /// already listening — throws [StateError] in both cases.
  /// On backend error: sets [state] to [VoiceState.error] then
  /// auto-recovers to idle after 500 ms.
  Future<VoiceResult> listen({
    Duration? maxDuration,
    String locale = 'fr-CH',
    VoiceConfig config = VoiceConfig.standard,
  }) async {
    // State machine validates: only idle → listening is allowed.
    // Throws StateError if we are already listening or speaking.
    if (!_machine.canStartListening) {
      final current = state.value;
      if (current == VoiceState.speaking) {
        throw StateError(
            'Impossible d\'écouter pendant la synthèse vocale');
      }
      throw StateError('Écoute déjà en cours');
    }

    _applyMode(VoiceMode.listening);
    // Capture generation before the async gap. If stopListening() fires while
    // the backend awaits, _generation is incremented and the coroutine exits.
    final gen = _generation;
    try {
      final result = await _backend.listen(
        maxDuration: maxDuration ?? const Duration(seconds: 30),
        silenceTimeout: config.silenceTimeout,
        locale: locale,
      );
      // Cancelled while waiting — do not apply further transitions.
      if (gen != _generation) return result;
      _applyMode(VoiceMode.processing);
      // In a real implementation, post-processing (punctuation, etc.) goes here.
      _applyMode(VoiceMode.idle);
      return result;
    } catch (e) {
      // If already force-idled by cancellation, do not double-set error.
      if (gen != _generation) rethrow;
      _setState(VoiceState.error);
      // Auto-recover to idle so next call works.
      Future.delayed(
          const Duration(milliseconds: 500), _forceIdle);
      rethrow;
    }
  }

  /// Stop an in-progress listen.
  Future<void> stopListening() async {
    if (state.value == VoiceState.listening) {
      await _backend.cancelListening();
      _forceIdle();
    }
  }

  // ── TTS ──────────────────────────────────────────────────

  /// Speak [text] aloud using the given [config].
  ///
  /// [VoiceStateMachine] guards against calling this while listening.
  /// Throws [StateError] when mic is active.
  Future<void> speak(
    String text, {
    String locale = 'fr-CH',
    VoiceConfig config = VoiceConfig.standard,
  }) async {
    // State machine validates: idle → speaking and processing → speaking.
    if (!_machine.canStartSpeaking) {
      throw StateError(
          'Impossible de parler pendant l\'écoute');
    }

    _applyMode(VoiceMode.speaking);
    // Capture generation before the async gap.
    final gen = _generation;
    try {
      await _backend.speak(
        text,
        locale: locale,
        rate: config.speechRate,
        pitch: config.pitch,
      );
      if (gen != _generation) return; // cancelled by stopSpeaking()
      _applyMode(VoiceMode.idle);
    } catch (e) {
      if (gen != _generation) rethrow;
      _setState(VoiceState.error);
      Future.delayed(
          const Duration(milliseconds: 500), _forceIdle);
      rethrow;
    }
  }

  /// Stop speaking immediately.
  Future<void> stopSpeaking() async {
    if (state.value == VoiceState.speaking) {
      await _backend.stopSpeaking();
      _forceIdle();
    }
  }

  /// Dispose resources.
  void dispose() {
    _disposed = true;
    state.dispose();
  }
}
