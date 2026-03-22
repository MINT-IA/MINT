/// Platform voice backend — Sprint S63.
///
/// Implements [VoiceBackend] using Flutter platform channels to probe
/// native TTS/STT availability WITHOUT adding pubspec dependencies.
///
/// Strategy:
///   STT  — always returns false until `speech_to_text` plugin is added.
///           Catches [MissingPluginException] so the app never crashes.
///   TTS  — probes `flutter_tts` channel; degrades gracefully on missing plugin.
///          Returns false when the channel is absent (web, desktop, no plugin).
///
/// Graceful degradation contract:
///   - isSttAvailable()  → always false (no plugin)
///   - isTtsAvailable()  → true only when platform channel responds positively
///   - listen()          → throws [UnsupportedError] (STT unavailable)
///   - speak()           → throws [UnsupportedError] (TTS unavailable)
///   - cancelListening() → no-op
///   - stopSpeaking()    → no-op (or invokes stop channel if TTS was probed)
///
/// Compliance: no PII ever passes through this layer directly.
/// Privacy: this backend holds no user state.
///
/// References: Flutter platform channels docs, flutter_tts package API.
library;

import 'dart:async';

import 'package:flutter/services.dart';

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

  /// Cached STT availability — always false (no plugin).
  bool? _sttAvailable;

  // ── Platform channels ─────────────────────────────────────

  /// Method channel for TTS probing (flutter_tts).
  static const _ttsChannel = MethodChannel(_kFlutterTtsChannel);

  /// Method channel for STT probing (speech_to_text).
  static const _sttChannel = MethodChannel(_kSpeechToTextChannel);

  // ── Availability ──────────────────────────────────────────

  /// STT is not available — returns false until `speech_to_text` is added.
  ///
  /// Probes the platform channel so the result is honest and future-proof.
  /// If the channel responds, STT is considered available.
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

  /// Start listening — not available without `speech_to_text` plugin.
  ///
  /// Always throws [UnsupportedError] describing how to enable STT.
  @override
  Future<VoiceResult> listen({
    Duration maxDuration = const Duration(seconds: 30),
    int silenceTimeout = 3,
    String locale = 'fr-CH',
  }) async {
    throw UnsupportedError(
      'La reconnaissance vocale n\'est pas disponible sur cet appareil. '
      'Ajoutez le plugin speech_to_text pour l\'activer.',
    );
  }

  /// Cancel listening — no-op (STT unavailable).
  @override
  Future<void> cancelListening() async {}

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

  /// Reset cached availability — useful for testing or after permission change.
  void resetCache() {
    _ttsAvailable = null;
    _sttAvailable = null;
  }
}
