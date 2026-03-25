/// Platform voice backend — Sprint S63 (STT activated P1-B).
///
/// Implements [VoiceBackend] using Flutter platform channels to probe
/// native TTS/STT availability with graceful degradation.
///
/// Strategy:
///   STT  — uses `speech_to_text` plugin. Probes channel for availability.
///           Returns [VoiceResult] with final transcript (no streaming).
///           Catches [MissingPluginException] so the app never crashes.
///   TTS  — probes `flutter_tts` channel; degrades gracefully on missing plugin.
///          Returns false when the channel is absent (web, desktop, no plugin).
///
/// Graceful degradation contract:
///   - isSttAvailable()  → true only when speech_to_text channel responds
///   - isTtsAvailable()  → true only when platform channel responds positively
///   - listen()          → transcribes speech via speech_to_text plugin
///   - speak()           → speaks text via flutter_tts plugin
///   - cancelListening() → stops listening via speech_to_text plugin
///   - stopSpeaking()    → no-op (or invokes stop channel if TTS was probed)
///
/// Compliance: no PII ever passes through this layer directly.
/// Privacy: this backend holds no user state.
///
/// References: Flutter platform channels docs, flutter_tts package API,
///             speech_to_text package API.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:mint_mobile/services/coach/voice_service.dart';

// ────────────────────────────────────────────────────────────
//  Channel names — must match flutter_tts plugin internals
// ────────────────────────────────────────────────────────────

/// Method channel name used by the `flutter_tts` plugin (if installed).
const _kFlutterTtsChannel = 'flutter_tts';

/// Method channel name used by the `speech_to_text` plugin (if installed).
const _kSpeechToTextChannel = 'plugin.csdcorp.com/speech_recognition';

// ────────────────────────────────────────────────────────────
//  PlatformVoiceBackend
// ────────────────────────────────────────────────────────────

/// A [VoiceBackend] that probes native platform channels.
///
/// When plugins are absent the backend degrades to unavailable rather than
/// crashing — identical contract to [StubVoiceBackend] but with real probing.
///
/// Usage (inject into [VoiceService]):
/// ```dart
/// final voice = VoiceService(backend: PlatformVoiceBackend());
/// ```
class PlatformVoiceBackend implements VoiceBackend {
  // ── Lazy-cached availability ──────────────────────────────

  /// Cached TTS availability — null means not yet probed.
  bool? _ttsAvailable;

  /// Cached STT availability — null means not yet probed.
  bool? _sttAvailable;

  // ── Platform channels ─────────────────────────────────────

  /// Method channel for TTS probing (flutter_tts).
  static const _ttsChannel = MethodChannel(_kFlutterTtsChannel);

  /// Method channel for STT probing (speech_to_text).
  static const _sttChannel = MethodChannel(_kSpeechToTextChannel);

  // ── STT plugin instance ────────────────────────────────────

  /// Lazy-initialized speech_to_text instance.
  stt.SpeechToText? _speech;

  /// Whether the speech_to_text plugin has been initialized.
  bool _speechInitialized = false;

  // ── Availability ──────────────────────────────────────────

  /// STT availability — probes `speech_to_text` channel.
  ///
  /// Returns true only when the platform channel responds without error.
  /// Catches [MissingPluginException] (plugin not installed) and [PlatformException]
  /// (mic permission denied or engine unavailable), returning false in both cases.
  @override
  Future<bool> isSttAvailable() async {
    if (_sttAvailable != null) return _sttAvailable!;
    _sttAvailable = await _probeStt();
    return _sttAvailable!;
  }

  /// TTS availability — probes `flutter_tts` channel.
  ///
  /// Returns true only when the platform channel responds without error.
  /// Catches [MissingPluginException] (plugin not installed) and [PlatformException]
  /// (device-level TTS not configured), returning false in both cases.
  @override
  Future<bool> isTtsAvailable() async {
    if (_ttsAvailable != null) return _ttsAvailable!;
    _ttsAvailable = await _probeTts();
    return _ttsAvailable!;
  }

  // ── STT ───────────────────────────────────────────────────

  /// Start listening — uses `speech_to_text` plugin for transcription.
  ///
  /// Waits for the final result (no streaming). Returns [VoiceResult] with
  /// the transcript text, confidence score, and locale.
  ///
  /// Throws [UnsupportedError] when STT is not available on this device.
  /// Throws [PlatformException] on engine error (caller should catch).
  @override
  Future<VoiceResult> listen({
    Duration maxDuration = const Duration(seconds: 30),
    int silenceTimeout = 3,
    String locale = 'fr-CH',
  }) async {
    if (!await isSttAvailable()) {
      throw UnsupportedError(
        'La reconnaissance vocale n\'est pas disponible sur cet appareil.',
      );
    }

    try {
      final speech = await _ensureSpeechInit();
      final completer = Completer<VoiceResult>();
      final stopwatch = Stopwatch()..start();

      speech.listen(
        onResult: (result) {
          // Only return when the speech engine confirms this is the final result.
          if (result.finalResult && !completer.isCompleted) {
            stopwatch.stop();
            completer.complete(VoiceResult(
              transcript: result.recognizedWords,
              confidence: result.confidence,
              duration: stopwatch.elapsed,
              locale: locale,
            ));
          }
        },
        listenFor: maxDuration,
        pauseFor: Duration(seconds: silenceTimeout),
        localeId: locale,
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: true,
          partialResults: false,
          listenMode: stt.ListenMode.confirmation,
        ),
      );

      // Timeout guard — if the plugin never fires a final result, return empty.
      final timeout = maxDuration + const Duration(seconds: 2);
      return completer.future.timeout(
        timeout,
        onTimeout: () {
          stopwatch.stop();
          speech.stop();
          return VoiceResult(
            transcript: '',
            confidence: 0.0,
            duration: stopwatch.elapsed,
            locale: locale,
          );
        },
      );
    } on MissingPluginException {
      _sttAvailable = false;
      throw UnsupportedError(
        'La reconnaissance vocale n\'est pas disponible sur cet appareil.',
      );
    } on PlatformException {
      rethrow;
    }
  }

  /// Cancel an in-progress listen — stops the speech_to_text plugin.
  @override
  Future<void> cancelListening() async {
    if (_speechInitialized && _speech != null) {
      try {
        await _speech!.cancel();
      } on MissingPluginException {
        _sttAvailable = false;
      } on PlatformException {
        // Engine error during cancel — swallow silently.
      }
    }
  }

  // ── TTS ───────────────────────────────────────────────────

  /// Speak text — delegates to flutter_tts channel if available.
  ///
  /// Throws [UnsupportedError] when TTS is unavailable.
  /// Throws [PlatformException] on engine error (caller should catch).
  @override
  Future<void> speak(
    String text, {
    String locale = 'fr-CH',
    double rate = 0.85,
    double pitch = 1.0,
  }) async {
    if (!await isTtsAvailable()) {
      throw UnsupportedError(
        'La synthèse vocale n\'est pas disponible sur cet appareil.',
      );
    }
    try {
      // Set locale, rate, pitch then speak.
      // TODO(V5-8a): TTS completion is not awaited — invokeMethod('speak')
      // returns when the platform channel acknowledges the call, NOT when
      // speech finishes. Await TTS completion when a real provider replaces
      // the flutter_tts stub (e.g. via a completion callback or Completer).
      await _ttsChannel.invokeMethod<void>('setLanguage', locale);
      await _ttsChannel.invokeMethod<void>('setSpeechRate', rate);
      await _ttsChannel.invokeMethod<void>('setPitch', pitch);
      await _ttsChannel.invokeMethod<void>('speak', text);
    } on MissingPluginException {
      _ttsAvailable = false;
      throw UnsupportedError(
        'La synthèse vocale n\'est pas disponible sur cet appareil.',
      );
    } on PlatformException {
      rethrow;
    }
  }

  /// Stop speaking — invokes flutter_tts stop if available.
  @override
  Future<void> stopSpeaking() async {
    if (_ttsAvailable != true) return;
    try {
      await _ttsChannel.invokeMethod<void>('stop');
    } on MissingPluginException {
      _ttsAvailable = false;
    } on PlatformException {
      // Engine error during stop — swallow silently.
    }
  }

  // ── Private probe helpers ─────────────────────────────────

  /// Probe the flutter_tts channel to check TTS availability.
  ///
  /// Returns true only when the `isLanguageAvailable` call responds.
  /// Any [MissingPluginException] → plugin not installed → false.
  /// Any [PlatformException] → device TTS not configured → false.
  static Future<bool> _probeTts() async {
    try {
      // `isLanguageAvailable` is the lightest flutter_tts call — returns bool.
      final result = await _ttsChannel.invokeMethod<bool>(
        'isLanguageAvailable',
        'fr-CH',
      );
      return result ?? false;
    } on MissingPluginException {
      // Plugin is not in pubspec — graceful degradation.
      return false;
    } on PlatformException {
      // Platform TTS engine not configured (e.g., no TTS engine on device).
      return false;
    } catch (_) {
      // Any unexpected error — degrade gracefully.
      return false;
    }
  }

  /// Probe the speech_to_text channel to check STT availability.
  ///
  /// Returns true only when the `has_permission` call responds successfully.
  static Future<bool> _probeStt() async {
    try {
      final result = await _sttChannel.invokeMethod<bool>('has_permission');
      return result ?? false;
    } on MissingPluginException {
      // Plugin not installed — STT unavailable.
      return false;
    } on PlatformException {
      // Permission denied or engine unavailable.
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Initialize the speech_to_text instance if not already done.
  ///
  /// Returns the initialized [stt.SpeechToText] instance.
  /// Throws if initialization fails.
  Future<stt.SpeechToText> _ensureSpeechInit() async {
    if (_speechInitialized && _speech != null) return _speech!;
    _speech = stt.SpeechToText();
    final available = await _speech!.initialize();
    if (!available) {
      _speech = null;
      _sttAvailable = false;
      throw UnsupportedError(
        'La reconnaissance vocale n\'est pas disponible sur cet appareil.',
      );
    }
    _speechInitialized = true;
    return _speech!;
  }

  /// Reset cached availability — useful for testing or after permission change.
  void resetCache() {
    _ttsAvailable = null;
    _sttAvailable = null;
    _speechInitialized = false;
    _speech = null;
  }
}
