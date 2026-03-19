/// Voice accessibility configuration — Sprint S63.
///
/// Configurable speech rate, pitch, silence timeout, and accessibility
/// presets for 50+ users. Persisted via SharedPreferences.
library;

import 'package:shared_preferences/shared_preferences.dart';

// ────────────────────────────────────────────────────────────
//  VoiceConfig — immutable voice settings
// ────────────────────────────────────────────────────────────

class VoiceConfig {
  /// Speech rate for TTS (0.5–1.5). Default 0.85 = slightly slower for clarity.
  final double speechRate;

  /// Pitch for TTS (0.5–2.0). Default 1.0 = natural.
  final double pitch;

  /// Automatically read coach responses aloud.
  final bool autoRead;

  /// Vibrate on voice state changes.
  final bool hapticFeedback;

  /// Seconds of silence before auto-stopping STT (3–10).
  final int silenceTimeout;

  /// Larger touch target for the voice button (accessibility).
  final bool largeVoiceButton;

  const VoiceConfig({
    this.speechRate = 0.85,
    this.pitch = 1.0,
    this.autoRead = false,
    this.hapticFeedback = true,
    this.silenceTimeout = 3,
    this.largeVoiceButton = false,
  });

  // ── Accessibility presets ────────────────────────────────

  /// Standard preset — balanced for most users.
  static const VoiceConfig standard = VoiceConfig();

  /// Senior-friendly — slower speech, longer silence window, larger button.
  static const VoiceConfig seniorFriendly = VoiceConfig(
    speechRate: 0.7,
    pitch: 1.0,
    autoRead: false,
    hapticFeedback: true,
    silenceTimeout: 5,
    largeVoiceButton: true,
  );

  /// Low-vision — slower speech, auto-read enabled, larger button.
  static const VoiceConfig lowVision = VoiceConfig(
    speechRate: 0.75,
    pitch: 1.0,
    autoRead: true,
    hapticFeedback: true,
    silenceTimeout: 5,
    largeVoiceButton: true,
  );

  // ── Clamping ─────────────────────────────────────────────

  /// Returns a new config with values clamped to valid bounds.
  VoiceConfig clamped() => VoiceConfig(
        speechRate: speechRate.clamp(0.5, 1.5),
        pitch: pitch.clamp(0.5, 2.0),
        autoRead: autoRead,
        hapticFeedback: hapticFeedback,
        silenceTimeout: silenceTimeout.clamp(3, 10),
        largeVoiceButton: largeVoiceButton,
      );

  // ── Copy ─────────────────────────────────────────────────

  VoiceConfig copyWith({
    double? speechRate,
    double? pitch,
    bool? autoRead,
    bool? hapticFeedback,
    int? silenceTimeout,
    bool? largeVoiceButton,
  }) =>
      VoiceConfig(
        speechRate: speechRate ?? this.speechRate,
        pitch: pitch ?? this.pitch,
        autoRead: autoRead ?? this.autoRead,
        hapticFeedback: hapticFeedback ?? this.hapticFeedback,
        silenceTimeout: silenceTimeout ?? this.silenceTimeout,
        largeVoiceButton: largeVoiceButton ?? this.largeVoiceButton,
      ).clamped();

  // ── Persistence ──────────────────────────────────────────

  static const _prefix = 'voice_config_';

  /// Save config to SharedPreferences.
  Future<void> save(SharedPreferences prefs) async {
    await prefs.setDouble('${_prefix}speechRate', speechRate);
    await prefs.setDouble('${_prefix}pitch', pitch);
    await prefs.setBool('${_prefix}autoRead', autoRead);
    await prefs.setBool('${_prefix}hapticFeedback', hapticFeedback);
    await prefs.setInt('${_prefix}silenceTimeout', silenceTimeout);
    await prefs.setBool('${_prefix}largeVoiceButton', largeVoiceButton);
  }

  /// Load config from SharedPreferences (returns [standard] if not persisted).
  static VoiceConfig load(SharedPreferences prefs) {
    final rate = prefs.getDouble('${_prefix}speechRate');
    if (rate == null) return standard; // nothing persisted yet
    return VoiceConfig(
      speechRate: rate,
      pitch: prefs.getDouble('${_prefix}pitch') ?? 1.0,
      autoRead: prefs.getBool('${_prefix}autoRead') ?? false,
      hapticFeedback: prefs.getBool('${_prefix}hapticFeedback') ?? true,
      silenceTimeout: prefs.getInt('${_prefix}silenceTimeout') ?? 3,
      largeVoiceButton: prefs.getBool('${_prefix}largeVoiceButton') ?? false,
    ).clamped();
  }

  // ── Voice button size ────────────────────────────────────

  /// Returns the diameter of the voice button in logical pixels.
  double get voiceButtonSize => largeVoiceButton ? 72.0 : 48.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceConfig &&
          runtimeType == other.runtimeType &&
          speechRate == other.speechRate &&
          pitch == other.pitch &&
          autoRead == other.autoRead &&
          hapticFeedback == other.hapticFeedback &&
          silenceTimeout == other.silenceTimeout &&
          largeVoiceButton == other.largeVoiceButton;

  @override
  int get hashCode => Object.hash(
        speechRate,
        pitch,
        autoRead,
        hapticFeedback,
        silenceTimeout,
        largeVoiceButton,
      );

  @override
  String toString() =>
      'VoiceConfig(rate: $speechRate, pitch: $pitch, autoRead: $autoRead, '
      'haptic: $hapticFeedback, silence: ${silenceTimeout}s, '
      'largeBtn: $largeVoiceButton)';
}
