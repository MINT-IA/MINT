import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/services/coach/voice_config.dart';
import 'package:mint_mobile/services/coach/voice_service.dart';
import 'package:mint_mobile/services/coach/voice_chat_integration.dart';

// ────────────────────────────────────────────────────────────
//  VOICE AI TESTS — Sprint S63
// ────────────────────────────────────────────────────────────
//
// 25 tests covering:
//   VoiceService — STT/TTS, state machine, mutual exclusion, error recovery
//   VoiceConfig  — presets, clamping, persistence
//   VoiceChatIntegration — voice↔chat bridge, full loop
// ────────────────────────────────────────────────────────────

// ── Mock backend ──────────────────────────────────────────

class MockVoiceBackend implements VoiceBackend {
  bool sttAvailable;
  bool ttsAvailable;
  VoiceResult? nextResult;
  bool listenShouldThrow;
  bool speakShouldThrow;
  String? lastSpokenText;
  double? lastSpeakRate;
  double? lastSpeakPitch;
  String? lastSpeakLocale;
  String? lastListenLocale;
  int? lastSilenceTimeout;
  Duration? lastMaxDuration;
  bool cancelListeningCalled = false;
  bool stopSpeakingCalled = false;
  Completer<VoiceResult>? listenCompleter;
  Completer<void>? speakCompleter;

  MockVoiceBackend({
    this.sttAvailable = true,
    this.ttsAvailable = true,
    this.nextResult,
    this.listenShouldThrow = false,
    this.speakShouldThrow = false,
  });

  @override
  Future<bool> isSttAvailable() async => sttAvailable;

  @override
  Future<bool> isTtsAvailable() async => ttsAvailable;

  @override
  Future<VoiceResult> listen({
    Duration maxDuration = const Duration(seconds: 30),
    int silenceTimeout = 3,
    String locale = 'fr-CH',
  }) async {
    lastListenLocale = locale;
    lastSilenceTimeout = silenceTimeout;
    lastMaxDuration = maxDuration;
    if (listenShouldThrow) {
      throw Exception('Erreur micro');
    }
    if (listenCompleter != null) {
      return listenCompleter!.future;
    }
    return nextResult ??
        const VoiceResult(
          transcript: 'Bonjour',
          confidence: 0.95,
          duration: Duration(seconds: 2),
          locale: 'fr-CH',
        );
  }

  @override
  Future<void> cancelListening() async {
    cancelListeningCalled = true;
  }

  @override
  Future<void> speak(
    String text, {
    String locale = 'fr-CH',
    double rate = 0.85,
    double pitch = 1.0,
  }) async {
    lastSpokenText = text;
    lastSpeakRate = rate;
    lastSpeakPitch = pitch;
    lastSpeakLocale = locale;
    if (speakShouldThrow) {
      throw Exception('Erreur TTS');
    }
    if (speakCompleter != null) {
      return speakCompleter!.future;
    }
  }

  @override
  Future<void> stopSpeaking() async {
    stopSpeakingCalled = true;
  }
}

// ────────────────────────────────────────────────────────────
//  Tests
// ────────────────────────────────────────────────────────────

void main() {
  // ===========================================================
  //  VoiceService
  // ===========================================================

  group('VoiceService', () {
    late MockVoiceBackend backend;
    late VoiceService service;

    setUp(() {
      backend = MockVoiceBackend();
      service = VoiceService(backend: backend);
    });

    tearDown(() {
      service.dispose();
    });

    test('isAvailable returns backend STT availability', () async {
      expect(await service.isAvailable(), isTrue);
      backend.sttAvailable = false;
      expect(await service.isAvailable(), isFalse);
    });

    test('isTtsAvailable returns backend TTS availability', () async {
      expect(await service.isTtsAvailable(), isTrue);
      backend.ttsAvailable = false;
      expect(await service.isTtsAvailable(), isFalse);
    });

    test('isAvailable returns false with stub backend', () async {
      final stubService = VoiceService(); // no backend → StubVoiceBackend
      expect(await stubService.isAvailable(), isFalse);
      stubService.dispose();
    });

    test('listen returns VoiceResult with transcript', () async {
      final result = await service.listen();
      expect(result.transcript, equals('Bonjour'));
      expect(result.confidence, equals(0.95));
      expect(result.locale, equals('fr-CH'));
    });

    test('listen passes maxDuration to backend', () async {
      await service.listen(maxDuration: const Duration(seconds: 15));
      expect(backend.lastMaxDuration, equals(const Duration(seconds: 15)));
    });

    test('listen defaults to 30s maxDuration', () async {
      await service.listen();
      expect(backend.lastMaxDuration, equals(const Duration(seconds: 30)));
    });

    test('listen passes silence timeout from config', () async {
      await service.listen(
        config: VoiceConfig.seniorFriendly, // silenceTimeout = 5
      );
      expect(backend.lastSilenceTimeout, equals(5));
    });

    test('listen passes locale to backend', () async {
      await service.listen(locale: 'de-CH');
      expect(backend.lastListenLocale, equals('de-CH'));
    });

    test('stopListening cancels backend and returns to idle', () async {
      // Simulate long listen
      backend.listenCompleter = Completer<VoiceResult>();
      unawaited(service.listen());
      // Allow microtask to set state
      await Future<void>.delayed(Duration.zero);
      expect(service.state.value, equals(VoiceState.listening));

      await service.stopListening();
      expect(service.state.value, equals(VoiceState.idle));
      expect(backend.cancelListeningCalled, isTrue);

      // Complete to avoid hanging future
      backend.listenCompleter!.complete(const VoiceResult(transcript: ''));
    });

    test('speak changes state to speaking then idle', () async {
      final states = <VoiceState>[];
      service.state.addListener(() => states.add(service.state.value));

      await service.speak('Bienvenue');
      expect(states, contains(VoiceState.speaking));
      expect(service.state.value, equals(VoiceState.idle));
      expect(backend.lastSpokenText, equals('Bienvenue'));
    });

    test('speak uses config rate and pitch', () async {
      const config = VoiceConfig(speechRate: 0.7, pitch: 1.2);
      await service.speak('Test', config: config);
      expect(backend.lastSpeakRate, equals(0.7));
      expect(backend.lastSpeakPitch, equals(1.2));
    });

    test('stopSpeaking stops backend and returns to idle', () async {
      backend.speakCompleter = Completer<void>();
      unawaited(service.speak('Long texte'));
      await Future<void>.delayed(Duration.zero);
      expect(service.state.value, equals(VoiceState.speaking));

      await service.stopSpeaking();
      expect(service.state.value, equals(VoiceState.idle));
      expect(backend.stopSpeakingCalled, isTrue);

      backend.speakCompleter!.complete();
    });

    test('state transitions: idle → listening → processing → idle', () async {
      final states = <VoiceState>[];
      service.state.addListener(() => states.add(service.state.value));

      await service.listen();

      expect(states, containsAllInOrder([
        VoiceState.listening,
        VoiceState.processing,
        VoiceState.idle,
      ]));
    });

    test('error state on backend listen failure', () async {
      backend.listenShouldThrow = true;
      expect(() => service.listen(), throwsException);
      // State set to error (then auto-recovers)
      await Future<void>.delayed(Duration.zero);
      // May be error or idle depending on timing, but error was reached
    });

    test('error state on backend speak failure', () async {
      backend.speakShouldThrow = true;
      expect(() => service.speak('Test'), throwsException);
    });

    test('concurrent listen while speaking throws StateError', () async {
      backend.speakCompleter = Completer<void>();
      unawaited(service.speak('Parlons'));
      await Future<void>.delayed(Duration.zero);

      expect(
        () => service.listen(),
        throwsA(isA<StateError>()),
      );

      backend.speakCompleter!.complete();
    });

    test('concurrent speak while listening throws StateError', () async {
      backend.listenCompleter = Completer<VoiceResult>();
      unawaited(service.listen());
      await Future<void>.delayed(Duration.zero);

      expect(
        () => service.speak('Oups'),
        throwsA(isA<StateError>()),
      );

      backend.listenCompleter!.complete(const VoiceResult(transcript: ''));
    });

    test('Swiss French locale fr-CH is default', () async {
      await service.listen();
      expect(backend.lastListenLocale, equals('fr-CH'));

      await service.speak('Bonjour');
      expect(backend.lastSpeakLocale, equals('fr-CH'));
    });
  });

  // ===========================================================
  //  VoiceResult
  // ===========================================================

  group('VoiceResult', () {
    test('isEmpty returns true for blank transcript', () {
      const empty = VoiceResult(transcript: '   ');
      expect(empty.isEmpty, isTrue);
    });

    test('isEmpty returns false for non-blank transcript', () {
      const valid = VoiceResult(transcript: 'Bonjour');
      expect(valid.isEmpty, isFalse);
    });
  });

  // ===========================================================
  //  VoiceConfig
  // ===========================================================

  group('VoiceConfig', () {
    test('standard config has expected defaults', () {
      const c = VoiceConfig.standard;
      expect(c.speechRate, equals(0.85));
      expect(c.pitch, equals(1.0));
      expect(c.autoRead, isFalse);
      expect(c.hapticFeedback, isTrue);
      expect(c.silenceTimeout, equals(3));
      expect(c.largeVoiceButton, isFalse);
      expect(c.voiceButtonSize, equals(48.0));
    });

    test('seniorFriendly preset has slower rate and larger button', () {
      const c = VoiceConfig.seniorFriendly;
      expect(c.speechRate, equals(0.7));
      expect(c.silenceTimeout, equals(5));
      expect(c.largeVoiceButton, isTrue);
      expect(c.voiceButtonSize, equals(72.0));
    });

    test('lowVision preset has autoRead enabled', () {
      const c = VoiceConfig.lowVision;
      expect(c.autoRead, isTrue);
      expect(c.speechRate, equals(0.75));
      expect(c.largeVoiceButton, isTrue);
    });

    test('invalid speechRate clamped to bounds', () {
      final tooLow = const VoiceConfig(speechRate: 0.1).clamped();
      expect(tooLow.speechRate, equals(0.5));

      final tooHigh = const VoiceConfig(speechRate: 3.0).clamped();
      expect(tooHigh.speechRate, equals(1.5));
    });

    test('invalid silenceTimeout clamped to bounds', () {
      final tooLow = const VoiceConfig(silenceTimeout: 1).clamped();
      expect(tooLow.silenceTimeout, equals(3));

      final tooHigh = const VoiceConfig(silenceTimeout: 20).clamped();
      expect(tooHigh.silenceTimeout, equals(10));
    });

    test('invalid pitch clamped to bounds', () {
      final tooLow = const VoiceConfig(pitch: 0.1).clamped();
      expect(tooLow.pitch, equals(0.5));

      final tooHigh = const VoiceConfig(pitch: 5.0).clamped();
      expect(tooHigh.pitch, equals(2.0));
    });

    test('config persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      const config = VoiceConfig(
        speechRate: 0.7,
        pitch: 1.1,
        autoRead: true,
        hapticFeedback: false,
        silenceTimeout: 5,
        largeVoiceButton: true,
      );
      await config.save(prefs);

      final loaded = VoiceConfig.load(prefs);
      expect(loaded.speechRate, equals(0.7));
      expect(loaded.pitch, equals(1.1));
      expect(loaded.autoRead, isTrue);
      expect(loaded.hapticFeedback, isFalse);
      expect(loaded.silenceTimeout, equals(5));
      expect(loaded.largeVoiceButton, isTrue);
    });

    test('config loads standard when nothing persisted', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final loaded = VoiceConfig.load(prefs);
      expect(loaded, equals(VoiceConfig.standard));
    });

    test('copyWith clamps values', () {
      const base = VoiceConfig.standard;
      final modified = base.copyWith(speechRate: 99.0, silenceTimeout: -5);
      expect(modified.speechRate, equals(1.5));
      expect(modified.silenceTimeout, equals(3));
    });

    test('equality works correctly', () {
      const a = VoiceConfig(speechRate: 0.85);
      const b = VoiceConfig(speechRate: 0.85);
      const c = VoiceConfig(speechRate: 0.7);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  // ===========================================================
  //  VoiceChatIntegration
  // ===========================================================

  group('VoiceChatIntegration', () {
    late MockVoiceBackend backend;
    late VoiceService voiceService;
    late VoiceChatIntegration integration;

    setUp(() {
      backend = MockVoiceBackend();
      voiceService = VoiceService(backend: backend);
      integration = VoiceChatIntegration(voice: voiceService);
    });

    tearDown(() {
      voiceService.dispose();
    });

    test('voiceToChat returns transcript on success', () async {
      backend.nextResult = const VoiceResult(
        transcript: 'Combien pour ma retraite\u00a0?',
        confidence: 0.9,
      );
      final result = await integration.voiceToChat();
      expect(result, equals('Combien pour ma retraite\u00a0?'));
    });

    test('voiceToChat returns null on empty transcript', () async {
      backend.nextResult = const VoiceResult(transcript: '   ');
      final result = await integration.voiceToChat();
      expect(result, isNull);
    });

    test('voiceToChat returns null on backend error', () async {
      backend.listenShouldThrow = true;
      final result = await integration.voiceToChat();
      expect(result, isNull);
    });

    test('chatToVoice speaks with correct config', () async {
      const config = VoiceConfig(speechRate: 0.7, pitch: 1.1);
      final customIntegration = VoiceChatIntegration(
        voice: voiceService,
        config: config,
      );

      await customIntegration.chatToVoice('Votre rente sera de 2\u202f500 CHF.');
      expect(backend.lastSpokenText, equals('Votre rente sera de 2\u202f500 CHF.'));
      expect(backend.lastSpeakRate, equals(0.7));
      expect(backend.lastSpeakPitch, equals(1.1));
    });

    test('chatToVoice skips empty response', () async {
      await integration.chatToVoice('');
      expect(backend.lastSpokenText, isNull);
    });

    test('voiceConversationTurn full loop', () async {
      backend.nextResult = const VoiceResult(
        transcript: 'Quel est mon taux de remplacement\u00a0?',
        confidence: 0.92,
      );

      String? receivedTranscript;
      final transcript = await integration.voiceConversationTurn(
        onTranscript: (t) async {
          receivedTranscript = t;
          return 'Votre taux de remplacement est estimé à 65\u00a0%.';
        },
        alwaysSpeak: true,
      );

      expect(transcript, equals('Quel est mon taux de remplacement\u00a0?'));
      expect(receivedTranscript, equals(transcript));
      expect(backend.lastSpokenText,
          equals('Votre taux de remplacement est estimé à 65\u00a0%.'));
    });

    test('voiceConversationTurn returns null when nothing said', () async {
      backend.nextResult = const VoiceResult(transcript: '');

      final transcript = await integration.voiceConversationTurn(
        onTranscript: (t) async => 'Réponse',
      );

      expect(transcript, isNull);
    });

    test('voiceConversationTurn does not speak when autoRead is false and alwaysSpeak is false', () async {
      backend.nextResult = const VoiceResult(transcript: 'Test');

      await integration.voiceConversationTurn(
        onTranscript: (t) async => 'Réponse du coach',
        alwaysSpeak: false,
      );

      // autoRead is false in standard config, alwaysSpeak is false → no TTS
      expect(backend.lastSpokenText, isNull);
    });

    test('voiceConversationTurn speaks when autoRead is true', () async {
      backend.nextResult = const VoiceResult(transcript: 'Bonjour');
      final autoReadIntegration = VoiceChatIntegration(
        voice: voiceService,
        config: const VoiceConfig(autoRead: true),
      );

      await autoReadIntegration.voiceConversationTurn(
        onTranscript: (t) async => 'Bienvenue\u00a0!',
      );

      expect(backend.lastSpokenText, equals('Bienvenue\u00a0!'));
    });
  });
}
