/// Voice state machine — Sprint S63.
///
/// Encapsulates the valid lifecycle transitions for the voice loop:
///   idle → listening → processing → speaking → idle
///
/// Used by [VoiceService] to guard against concurrent/invalid operations.
/// Any invalid transition throws [StateError] with a descriptive message.
/// The `any → idle` (error/cancel) escape hatch is always permitted.
///
/// Design:
///   - Immutable transition table — no state held outside [_state].
///   - [canStartListening] / [canStartSpeaking] for UI guard checks.
///   - [forceIdle] for error recovery and cancellation paths.
///
/// References:
///   - docs/BLUEPRINT_COACH_AI_LAYER.md
///   - voice_service.dart — VoiceState enum
library;

// ────────────────────────────────────────────────────────────
//  VoiceMode — state machine enum
// ────────────────────────────────────────────────────────────

/// States of the voice loop.
///
/// Mirrors [VoiceState] in `voice_service.dart` but lives in its own
/// enum to keep the state machine self-contained and independently testable.
enum VoiceMode {
  /// No voice operation in progress. Ready to accept new commands.
  idle,

  /// STT is actively capturing audio from the microphone.
  listening,

  /// STT captured audio; transcription is being processed.
  processing,

  /// TTS is reading text aloud to the user.
  speaking,
}

// ────────────────────────────────────────────────────────────
//  Transition table
// ────────────────────────────────────────────────────────────

/// Valid state transitions: `from → {allowed targets}`.
///
/// Any transition that ends in [VoiceMode.idle] is handled by [forceIdle]
/// and always allowed (error recovery / user cancel).
const Map<VoiceMode, Set<VoiceMode>> _validTransitions = {
  VoiceMode.idle: {VoiceMode.listening, VoiceMode.speaking},
  VoiceMode.listening: {VoiceMode.processing, VoiceMode.idle},
  VoiceMode.processing: {VoiceMode.speaking, VoiceMode.idle},
  VoiceMode.speaking: {VoiceMode.idle},
};

// ────────────────────────────────────────────────────────────
//  VoiceStateMachine
// ────────────────────────────────────────────────────────────

/// Validates and tracks transitions through the voice lifecycle.
///
/// ```dart
/// final sm = VoiceStateMachine();
/// sm.transition(VoiceMode.listening);    // idle → listening ✓
/// sm.transition(VoiceMode.processing);   // listening → processing ✓
/// sm.transition(VoiceMode.speaking);     // processing → speaking ✓
/// sm.forceIdle();                        // speaking → idle ✓ (always ok)
/// ```
class VoiceStateMachine {
  VoiceMode _state = VoiceMode.idle;

  /// The current voice mode.
  VoiceMode get state => _state;

  // ── Guard checks ──────────────────────────────────────────

  /// Whether the machine is ready to start listening (STT).
  ///
  /// True only when [state] is [VoiceMode.idle].
  bool get canStartListening => _state == VoiceMode.idle;

  /// Whether the machine is ready to start speaking (TTS).
  ///
  /// True when [state] is [VoiceMode.idle] (direct speak) or
  /// [VoiceMode.processing] (response ready, switching to TTS).
  bool get canStartSpeaking =>
      _state == VoiceMode.idle || _state == VoiceMode.processing;

  /// Whether any voice operation is in progress.
  bool get isBusy => _state != VoiceMode.idle;

  // ── Transitions ───────────────────────────────────────────

  /// Attempt to transition to [to].
  ///
  /// Throws [StateError] when the transition is not in the valid table.
  /// Transitions to [VoiceMode.idle] should use [forceIdle] instead —
  /// they are always valid and do not throw.
  ///
  /// Throws [StateError] with a descriptive French message on invalid
  /// transitions (matching MINT's French-first error messaging convention).
  void transition(VoiceMode to) {
    // Idle is always reachable via forceIdle.  If called via transition(),
    // also allow it (convenience) — every path can return to idle.
    if (to == VoiceMode.idle) {
      _state = VoiceMode.idle;
      return;
    }

    final allowed = _validTransitions[_state];
    if (allowed == null || !allowed.contains(to)) {
      throw StateError(
        'Transition vocale invalide\u00a0: '
        '${_state.name} → ${to.name} n\'est pas autorisée.',
      );
    }
    _state = to;
  }

  /// Force the machine back to [VoiceMode.idle] unconditionally.
  ///
  /// Used for error recovery, user interruption, and cancellation.
  /// Never throws — always succeeds.
  void forceIdle() {
    _state = VoiceMode.idle;
  }

  @override
  String toString() => 'VoiceStateMachine(${_state.name})';
}
