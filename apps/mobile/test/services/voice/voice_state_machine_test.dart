/// VoiceStateMachine tests — Sprint S63.
///
/// 20 tests covering:
///   - Initial state is idle
///   - All valid transitions succeed
///   - Invalid transitions throw StateError
///   - canStartListening / canStartSpeaking logic
///   - forceIdle always works (error recovery)
///   - isBusy reflects non-idle state
///   - toString reflects current state
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/voice/voice_state_machine.dart';

void main() {
  group('VoiceStateMachine', () {
    // ── Initial state ─────────────────────────────────────

    test('initial state is idle', () {
      final sm = VoiceStateMachine();
      expect(sm.state, equals(VoiceMode.idle));
    });

    test('isBusy is false in initial state', () {
      final sm = VoiceStateMachine();
      expect(sm.isBusy, isFalse);
    });

    // ── Valid transitions ─────────────────────────────────

    test('idle → listening is valid', () {
      final sm = VoiceStateMachine();
      sm.transition(VoiceMode.listening);
      expect(sm.state, equals(VoiceMode.listening));
    });

    test('listening → processing is valid', () {
      final sm = VoiceStateMachine();
      sm.transition(VoiceMode.listening);
      sm.transition(VoiceMode.processing);
      expect(sm.state, equals(VoiceMode.processing));
    });

    test('processing → speaking is valid', () {
      final sm = VoiceStateMachine();
      sm.transition(VoiceMode.listening);
      sm.transition(VoiceMode.processing);
      sm.transition(VoiceMode.speaking);
      expect(sm.state, equals(VoiceMode.speaking));
    });

    test('speaking → idle is valid', () {
      final sm = VoiceStateMachine();
      sm.transition(VoiceMode.listening);
      sm.transition(VoiceMode.processing);
      sm.transition(VoiceMode.speaking);
      sm.transition(VoiceMode.idle);
      expect(sm.state, equals(VoiceMode.idle));
    });

    test('processing → idle is valid (transcription failed)', () {
      final sm = VoiceStateMachine();
      sm.transition(VoiceMode.listening);
      sm.transition(VoiceMode.processing);
      sm.transition(VoiceMode.idle);
      expect(sm.state, equals(VoiceMode.idle));
    });

    test('listening → idle is valid (user cancelled)', () {
      final sm = VoiceStateMachine();
      sm.transition(VoiceMode.listening);
      sm.transition(VoiceMode.idle);
      expect(sm.state, equals(VoiceMode.idle));
    });

    test('idle → speaking is valid (direct TTS without STT)', () {
      final sm = VoiceStateMachine();
      sm.transition(VoiceMode.speaking);
      expect(sm.state, equals(VoiceMode.speaking));
    });

    test('full happy path: idle → listening → processing → speaking → idle', () {
      final sm = VoiceStateMachine();
      sm.transition(VoiceMode.listening);
      sm.transition(VoiceMode.processing);
      sm.transition(VoiceMode.speaking);
      sm.transition(VoiceMode.idle);
      expect(sm.state, equals(VoiceMode.idle));
    });

    // ── Invalid transitions ───────────────────────────────

    test('listening → speaking is invalid (must go through processing)', () {
      final sm = VoiceStateMachine();
      sm.transition(VoiceMode.listening);
      expect(
        () => sm.transition(VoiceMode.speaking),
        throwsA(isA<StateError>()),
      );
    });

    test('speaking → listening is invalid', () {
      final sm = VoiceStateMachine();
      sm.transition(VoiceMode.listening);
      sm.transition(VoiceMode.processing);
      sm.transition(VoiceMode.speaking);
      expect(
        () => sm.transition(VoiceMode.listening),
        throwsA(isA<StateError>()),
      );
    });

    test('speaking → processing is invalid', () {
      final sm = VoiceStateMachine();
      sm.transition(VoiceMode.listening);
      sm.transition(VoiceMode.processing);
      sm.transition(VoiceMode.speaking);
      expect(
        () => sm.transition(VoiceMode.processing),
        throwsA(isA<StateError>()),
      );
    });

    test('idle → processing is invalid', () {
      final sm = VoiceStateMachine();
      expect(
        () => sm.transition(VoiceMode.processing),
        throwsA(isA<StateError>()),
      );
    });

    test('StateError message is descriptive', () {
      final sm = VoiceStateMachine();
      sm.transition(VoiceMode.listening);
      try {
        sm.transition(VoiceMode.speaking);
        fail('Expected StateError');
      } on StateError catch (e) {
        expect(e.message, contains('listening'));
        expect(e.message, contains('speaking'));
      }
    });

    test('invalid transition does not change state', () {
      final sm = VoiceStateMachine();
      sm.transition(VoiceMode.listening);
      expect(sm.state, equals(VoiceMode.listening));
      try {
        sm.transition(VoiceMode.speaking);
      } on StateError {
        // expected
      }
      // State must stay as listening — not corrupted.
      expect(sm.state, equals(VoiceMode.listening));
    });

    // ── forceIdle (error/cancel recovery) ─────────────────

    test('forceIdle from listening returns to idle', () {
      final sm = VoiceStateMachine();
      sm.transition(VoiceMode.listening);
      sm.forceIdle();
      expect(sm.state, equals(VoiceMode.idle));
    });

    test('forceIdle from processing returns to idle', () {
      final sm = VoiceStateMachine();
      sm.transition(VoiceMode.listening);
      sm.transition(VoiceMode.processing);
      sm.forceIdle();
      expect(sm.state, equals(VoiceMode.idle));
    });

    test('forceIdle from speaking returns to idle', () {
      final sm = VoiceStateMachine();
      sm.transition(VoiceMode.listening);
      sm.transition(VoiceMode.processing);
      sm.transition(VoiceMode.speaking);
      sm.forceIdle();
      expect(sm.state, equals(VoiceMode.idle));
    });

    test('forceIdle from idle is a no-op (does not throw)', () {
      final sm = VoiceStateMachine();
      sm.forceIdle(); // already idle — must not throw
      expect(sm.state, equals(VoiceMode.idle));
    });

    test('forceIdle then transition works (machine is reusable)', () {
      final sm = VoiceStateMachine();
      sm.transition(VoiceMode.listening);
      sm.forceIdle();
      sm.transition(VoiceMode.listening); // should not throw
      expect(sm.state, equals(VoiceMode.listening));
    });

    // ── canStartListening / canStartSpeaking guards ────────

    test('canStartListening is true only in idle', () {
      final sm = VoiceStateMachine();
      expect(sm.canStartListening, isTrue); // idle

      sm.transition(VoiceMode.listening);
      expect(sm.canStartListening, isFalse); // listening

      sm.transition(VoiceMode.processing);
      expect(sm.canStartListening, isFalse); // processing

      sm.transition(VoiceMode.speaking);
      expect(sm.canStartListening, isFalse); // speaking

      sm.forceIdle();
      expect(sm.canStartListening, isTrue); // back to idle
    });

    test('canStartSpeaking is true in idle and processing', () {
      final sm = VoiceStateMachine();
      expect(sm.canStartSpeaking, isTrue); // idle

      sm.transition(VoiceMode.listening);
      expect(sm.canStartSpeaking, isFalse); // listening — mic active

      sm.transition(VoiceMode.processing);
      expect(sm.canStartSpeaking, isTrue); // processing — response ready

      sm.transition(VoiceMode.speaking);
      expect(sm.canStartSpeaking, isFalse); // already speaking

      sm.forceIdle();
      expect(sm.canStartSpeaking, isTrue); // back to idle
    });

    // ── isBusy ────────────────────────────────────────────

    test('isBusy is true for all non-idle states', () {
      final sm = VoiceStateMachine();
      expect(sm.isBusy, isFalse);

      sm.transition(VoiceMode.listening);
      expect(sm.isBusy, isTrue);

      sm.transition(VoiceMode.processing);
      expect(sm.isBusy, isTrue);

      sm.transition(VoiceMode.speaking);
      expect(sm.isBusy, isTrue);

      sm.forceIdle();
      expect(sm.isBusy, isFalse);
    });

    // ── toString ──────────────────────────────────────────

    test('toString reflects current state', () {
      final sm = VoiceStateMachine();
      expect(sm.toString(), contains('idle'));

      sm.transition(VoiceMode.listening);
      expect(sm.toString(), contains('listening'));
    });
  });

  // ── VoiceMode enum ────────────────────────────────────────

  group('VoiceMode enum', () {
    test('has exactly 4 values', () {
      expect(VoiceMode.values.length, equals(4));
    });

    test('contains expected values', () {
      expect(
        VoiceMode.values,
        containsAll([
          VoiceMode.idle,
          VoiceMode.listening,
          VoiceMode.processing,
          VoiceMode.speaking,
        ]),
      );
    });

    test('names match expected strings', () {
      expect(VoiceMode.idle.name, equals('idle'));
      expect(VoiceMode.listening.name, equals('listening'));
      expect(VoiceMode.processing.name, equals('processing'));
      expect(VoiceMode.speaking.name, equals('speaking'));
    });
  });
}
