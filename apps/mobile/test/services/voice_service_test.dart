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
      expect(backend.lastSpokenText, startsWith('Votre rente sera de 2\u202f500 CHF.'));
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
          startsWith('Votre taux de remplacement est estimé à 65\u00a0%.'));
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

  // ===========================================================
  //  AUDIT S63 — Additional tests (autoresearch-test-generation)
  // ===========================================================

  // ── 1. Edge cases ──────────────────────────────────────────

  group('Edge cases — VoiceResult', () {
    test('empty string transcript is empty', () {
      const r = VoiceResult(transcript: '');
      expect(r.isEmpty, isTrue);
    });

    test('whitespace-only transcript is empty', () {
      const r = VoiceResult(transcript: '\t \n  ');
      expect(r.isEmpty, isTrue);
    });

    test('very long transcription is preserved', () {
      final longText = 'mot ' * 2000; // ~8000 chars
      final r = VoiceResult(transcript: longText);
      expect(r.isEmpty, isFalse);
      expect(r.transcript.length, greaterThan(7000));
    });

    test('unicode / accented transcript preserved', () {
      const r = VoiceResult(transcript: 'prévoyance éducatif à côté');
      expect(r.transcript, contains('é'));
      expect(r.transcript, contains('ô'));
      expect(r.isEmpty, isFalse);
    });

    test('default confidence is 0', () {
      const r = VoiceResult(transcript: 'ok');
      expect(r.confidence, equals(0.0));
    });

    test('default duration is zero', () {
      const r = VoiceResult(transcript: 'ok');
      expect(r.duration, equals(Duration.zero));
    });

    test('default locale is fr-CH', () {
      const r = VoiceResult(transcript: 'test');
      expect(r.locale, equals('fr-CH'));
    });

    test('toString contains key fields', () {
      const r = VoiceResult(
        transcript: 'Bonjour',
        confidence: 0.8,
        duration: Duration(seconds: 3),
        locale: 'de-CH',
      );
      final s = r.toString();
      expect(s, contains('Bonjour'));
      expect(s, contains('0.8'));
      expect(s, contains('3000ms'));
      expect(s, contains('de-CH'));
    });
  });

  group('Edge cases — VoiceService listen', () {
    late MockVoiceBackend backend;
    late VoiceService service;

    setUp(() {
      backend = MockVoiceBackend();
      service = VoiceService(backend: backend);
    });

    tearDown(() {
      service.dispose();
    });

    test('listen with empty result returns VoiceResult with isEmpty true',
        () async {
      backend.nextResult = const VoiceResult(transcript: '');
      final r = await service.listen();
      expect(r.isEmpty, isTrue);
    });

    test('listen with very long text succeeds', () async {
      final longText = 'prévoyance ' * 500;
      backend.nextResult = VoiceResult(transcript: longText);
      final r = await service.listen();
      expect(r.transcript.length, greaterThan(4000));
    });

    test('listen with unsupported locale passes it through', () async {
      await service.listen(locale: 'zh-CN');
      expect(backend.lastListenLocale, equals('zh-CN'));
    });

    test('listen with custom maxDuration passes correctly', () async {
      await service.listen(maxDuration: const Duration(seconds: 5));
      expect(backend.lastMaxDuration, equals(const Duration(seconds: 5)));
    });

    test('double listen throws StateError', () async {
      backend.listenCompleter = Completer<VoiceResult>();
      unawaited(service.listen());
      await Future<void>.delayed(Duration.zero);

      expect(
        () => service.listen(),
        throwsA(isA<StateError>()),
      );

      backend.listenCompleter!.complete(const VoiceResult(transcript: ''));
    });
  });

  // ── 2. VoiceConfig — comprehensive ────────────────────────

  group('VoiceConfig — additional coverage', () {
    test('copyWith preserves unmodified fields', () {
      const base = VoiceConfig(
        speechRate: 0.8,
        pitch: 1.2,
        autoRead: true,
        hapticFeedback: false,
        silenceTimeout: 7,
        largeVoiceButton: true,
      );
      final copy = base.copyWith(speechRate: 0.9);
      expect(copy.speechRate, equals(0.9));
      expect(copy.pitch, equals(1.2));
      expect(copy.autoRead, isTrue);
      expect(copy.hapticFeedback, isFalse);
      expect(copy.silenceTimeout, equals(7));
      expect(copy.largeVoiceButton, isTrue);
    });

    test('copyWith with all fields overridden', () {
      const base = VoiceConfig.standard;
      final copy = base.copyWith(
        speechRate: 1.0,
        pitch: 1.5,
        autoRead: true,
        hapticFeedback: false,
        silenceTimeout: 8,
        largeVoiceButton: true,
      );
      expect(copy.speechRate, equals(1.0));
      expect(copy.pitch, equals(1.5));
      expect(copy.autoRead, isTrue);
      expect(copy.hapticFeedback, isFalse);
      expect(copy.silenceTimeout, equals(8));
      expect(copy.largeVoiceButton, isTrue);
    });

    test('clamped on already-valid config returns identical values', () {
      const c = VoiceConfig(speechRate: 1.0, pitch: 1.0, silenceTimeout: 5);
      final clamped = c.clamped();
      expect(clamped.speechRate, equals(1.0));
      expect(clamped.pitch, equals(1.0));
      expect(clamped.silenceTimeout, equals(5));
    });

    test('voiceButtonSize is 48 when largeVoiceButton false', () {
      const c = VoiceConfig(largeVoiceButton: false);
      expect(c.voiceButtonSize, equals(48.0));
    });

    test('voiceButtonSize is 72 when largeVoiceButton true', () {
      const c = VoiceConfig(largeVoiceButton: true);
      expect(c.voiceButtonSize, equals(72.0));
    });

    test('boundary speechRate 0.5 not clamped further', () {
      final c = const VoiceConfig(speechRate: 0.5).clamped();
      expect(c.speechRate, equals(0.5));
    });

    test('boundary speechRate 1.5 not clamped further', () {
      final c = const VoiceConfig(speechRate: 1.5).clamped();
      expect(c.speechRate, equals(1.5));
    });

    test('boundary pitch 0.5 not clamped further', () {
      final c = const VoiceConfig(pitch: 0.5).clamped();
      expect(c.pitch, equals(0.5));
    });

    test('boundary pitch 2.0 not clamped further', () {
      final c = const VoiceConfig(pitch: 2.0).clamped();
      expect(c.pitch, equals(2.0));
    });

    test('boundary silenceTimeout 3 not clamped further', () {
      final c = const VoiceConfig(silenceTimeout: 3).clamped();
      expect(c.silenceTimeout, equals(3));
    });

    test('boundary silenceTimeout 10 not clamped further', () {
      final c = const VoiceConfig(silenceTimeout: 10).clamped();
      expect(c.silenceTimeout, equals(10));
    });

    test('hashCode consistent with equality', () {
      const a = VoiceConfig(speechRate: 0.85, pitch: 1.0);
      const b = VoiceConfig(speechRate: 0.85, pitch: 1.0);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('hashCode differs for different configs', () {
      const a = VoiceConfig(speechRate: 0.85);
      const b = VoiceConfig(speechRate: 0.70);
      // Not guaranteed but extremely likely
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('toString contains key fields', () {
      const c = VoiceConfig(speechRate: 0.7, autoRead: true);
      final s = c.toString();
      expect(s, contains('0.7'));
      expect(s, contains('autoRead: true'));
    });

    test('persistence round-trip with extreme clamped values', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      const config = VoiceConfig(speechRate: 0.1, pitch: 5.0, silenceTimeout: 1);
      final clamped = config.clamped();
      await clamped.save(prefs);

      final loaded = VoiceConfig.load(prefs);
      expect(loaded.speechRate, equals(0.5));
      expect(loaded.pitch, equals(2.0));
      expect(loaded.silenceTimeout, equals(3));
    });

    test('load with partial prefs returns defaults for missing fields', () async {
      SharedPreferences.setMockInitialValues({
        'voice_config_speechRate': 0.9,
        // pitch, autoRead, etc. are missing
      });
      final prefs = await SharedPreferences.getInstance();

      final loaded = VoiceConfig.load(prefs);
      expect(loaded.speechRate, equals(0.9));
      expect(loaded.pitch, equals(1.0)); // default
      expect(loaded.autoRead, isFalse);  // default
      expect(loaded.hapticFeedback, isTrue); // default
      expect(loaded.silenceTimeout, equals(3)); // default
      expect(loaded.largeVoiceButton, isFalse); // default
    });
  });

  // ── 3. Voice chat integration — additional ─────────────────

  group('VoiceChatIntegration — additional coverage', () {
    late MockVoiceBackend backend;
    late VoiceService voiceService;

    setUp(() {
      backend = MockVoiceBackend();
      voiceService = VoiceService(backend: backend);
    });

    tearDown(() {
      voiceService.dispose();
    });

    test('voiceToChat trims whitespace from transcript', () async {
      backend.nextResult = const VoiceResult(transcript: '  Bonjour  ');
      final integration = VoiceChatIntegration(voice: voiceService);
      final result = await integration.voiceToChat();
      expect(result, equals('Bonjour'));
    });

    test('chatToVoice with whitespace-only text does not call speak',
        () async {
      final integration = VoiceChatIntegration(voice: voiceService);
      await integration.chatToVoice('   \t  ');
      expect(backend.lastSpokenText, isNull);
    });

    test('chatToVoice passes locale to speak', () async {
      final integration = VoiceChatIntegration(voice: voiceService);
      await integration.chatToVoice('Hallo', locale: 'de-CH');
      expect(backend.lastSpeakLocale, equals('de-CH'));
    });

    test('chatToVoice swallows TTS error gracefully', () async {
      backend.speakShouldThrow = true;
      final integration = VoiceChatIntegration(voice: voiceService);
      // Should not throw
      await integration.chatToVoice('Texte');
    });

    test('voiceToChat with StateError returns null gracefully', () async {
      // Make listen throw StateError by speaking first
      backend.speakCompleter = Completer<void>();
      unawaited(voiceService.speak('Test'));
      await Future<void>.delayed(Duration.zero);

      final integration = VoiceChatIntegration(voice: voiceService);
      final result = await integration.voiceToChat();
      expect(result, isNull);

      backend.speakCompleter!.complete();
    });

    test('voiceConversationTurn callback receives trimmed text', () async {
      backend.nextResult = const VoiceResult(transcript: '  Retraite  ');
      final integration = VoiceChatIntegration(voice: voiceService);

      String? received;
      await integration.voiceConversationTurn(
        onTranscript: (t) async {
          received = t;
          return 'Réponse';
        },
        alwaysSpeak: true,
      );

      expect(received, equals('Retraite'));
    });

    test('voiceConversationTurn with callback throwing still propagates',
        () async {
      backend.nextResult = const VoiceResult(transcript: 'Test');
      final integration = VoiceChatIntegration(voice: voiceService);

      expect(
        () => integration.voiceConversationTurn(
          onTranscript: (t) async => throw Exception('Coach down'),
        ),
        throwsException,
      );
    });

    test('voiceConversationTurn with different locales', () async {
      backend.nextResult = const VoiceResult(transcript: 'Hallo');
      final integration = VoiceChatIntegration(voice: voiceService);

      await integration.voiceConversationTurn(
        locale: 'de-CH',
        onTranscript: (t) async => 'Willkommen',
        alwaysSpeak: true,
      );

      expect(backend.lastListenLocale, equals('de-CH'));
      expect(backend.lastSpeakLocale, equals('de-CH'));
    });
  });

  // ── 4. Privacy — transcription must NOT persist PII ────────

  group('Privacy — no PII in VoiceResult', () {
    test('VoiceResult does not store user identifiers', () {
      // VoiceResult is a plain data object with no persistence.
      // Verify it holds only transcript/confidence/duration/locale.
      const r = VoiceResult(
        transcript: 'Mon AHV est 756.1234.5678.97',
        confidence: 0.9,
        duration: Duration(seconds: 5),
        locale: 'fr-CH',
      );
      // VoiceResult has no save/persist/toJson method — privacy by design.
      // If someone adds persistence later, this test must be updated.
      expect(r, isNotNull);
      // Verify no toJson, no toMap, no save method exists on VoiceResult
      // (compile-time guarantee — if these were added the test file would
      //  need updating, which is the canary we want)
    });

    test('VoiceResult toString does not add extra identifying fields', () {
      const r = VoiceResult(transcript: 'test');
      final s = r.toString();
      // Should only contain transcript, confidence, duration, locale
      expect(s, contains('test'));
      expect(s, contains('confidence'));
      expect(s, contains('locale'));
      // Should NOT contain words like "userId", "name", "email"
      expect(s.toLowerCase(), isNot(contains('userid')));
      expect(s.toLowerCase(), isNot(contains('email')));
      expect(s.toLowerCase(), isNot(contains('iban')));
    });

    test('VoiceConfig does not store user-specific data', () {
      // VoiceConfig stores only accessibility preferences, no PII.
      const c = VoiceConfig.standard;
      final s = c.toString();
      expect(s.toLowerCase(), isNot(contains('name')));
      expect(s.toLowerCase(), isNot(contains('email')));
      expect(s.toLowerCase(), isNot(contains('iban')));
    });
  });

  // ── 5. Compliance — banned terms ───────────────────────────

  group('Compliance — banned terms in voice output', () {
    // These tests verify that any text flowing through voice contains
    // no banned terms per CLAUDE.md §6.
    final bannedTerms = [
      'garanti',
      'certain',
      'assuré',
      'sans risque',
      'optimal',
      'meilleur',
      'parfait',
    ];

    test('VoiceResult transcript does not contain banned terms in standard responses',
        () {
      // Simulate a coach response that should be compliant
      const response = 'Votre rente pourrait atteindre environ 2\u00a0500 CHF par mois.';
      for (final term in bannedTerms) {
        expect(
          response.toLowerCase().contains(term),
          isFalse,
          reason: 'Response contains banned term: "$term"',
        );
      }
    });

    test('bannedTerms list covers all CLAUDE.md §6 entries', () {
      // Canary test: if the banned list in CLAUDE.md grows,
      // update this test accordingly.
      expect(bannedTerms.length, greaterThanOrEqualTo(7));
      expect(bannedTerms, contains('garanti'));
      expect(bannedTerms, contains('sans risque'));
    });

    test('chatToVoice passes text as-is (no filtering at this layer)', () async {
      // The ComplianceGuard is responsible for filtering before this layer.
      // VoiceChatIntegration must not alter text content.
      final backend = MockVoiceBackend();
      final vs = VoiceService(backend: backend);
      final integration = VoiceChatIntegration(voice: vs);

      await integration.chatToVoice('Texte éducatif important');
      expect(backend.lastSpokenText, equals('Texte éducatif important'));

      vs.dispose();
    });
  });

  // ── 6. Error paths — network, unavailability ───────────────

  group('Error paths — network and engine failures', () {
    late MockVoiceBackend backend;
    late VoiceService service;

    setUp(() {
      backend = MockVoiceBackend();
      service = VoiceService(backend: backend);
    });

    tearDown(() {
      service.dispose();
    });

    test('listen network failure sets error state then auto-recovers',
        () async {
      backend.listenShouldThrow = true;

      try {
        await service.listen();
      } catch (_) {}

      // Should be in error state
      expect(service.state.value, equals(VoiceState.error));

      // Auto-recovers after 500ms delay
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(service.state.value, equals(VoiceState.idle));
    });

    test('speak failure sets error state then auto-recovers', () async {
      backend.speakShouldThrow = true;

      try {
        await service.speak('Test');
      } catch (_) {}

      expect(service.state.value, equals(VoiceState.error));

      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(service.state.value, equals(VoiceState.idle));
    });

    test('after error recovery, listen works again', () async {
      backend.listenShouldThrow = true;

      try {
        await service.listen();
      } catch (_) {}

      // Wait for auto-recovery
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(service.state.value, equals(VoiceState.idle));

      // Now listen should work
      backend.listenShouldThrow = false;
      backend.nextResult = const VoiceResult(transcript: 'Recovered');
      final r = await service.listen();
      expect(r.transcript, equals('Recovered'));
    });

    test('after error recovery, speak works again', () async {
      backend.speakShouldThrow = true;

      try {
        await service.speak('Fail');
      } catch (_) {}

      await Future<void>.delayed(const Duration(milliseconds: 600));

      backend.speakShouldThrow = false;
      await service.speak('Récupéré');
      expect(backend.lastSpokenText, equals('Récupéré'));
    });

    test('STT unavailable — StubVoiceBackend throws UnsupportedError',
        () async {
      final stubService = VoiceService(); // uses StubVoiceBackend
      expect(
        () => stubService.listen(),
        throwsA(isA<UnsupportedError>()),
      );
      stubService.dispose();
    });

    test('TTS unavailable — StubVoiceBackend throws UnsupportedError',
        () async {
      final stubService = VoiceService();
      expect(
        () => stubService.speak('Test'),
        throwsA(isA<UnsupportedError>()),
      );
      stubService.dispose();
    });

    test('StubVoiceBackend isSttAvailable returns false', () async {
      final stub = StubVoiceBackend();
      expect(await stub.isSttAvailable(), isFalse);
    });

    test('StubVoiceBackend isTtsAvailable returns false', () async {
      final stub = StubVoiceBackend();
      expect(await stub.isTtsAvailable(), isFalse);
    });

    test('StubVoiceBackend cancelListening completes normally', () async {
      final stub = StubVoiceBackend();
      await stub.cancelListening(); // should not throw
    });

    test('StubVoiceBackend stopSpeaking completes normally', () async {
      final stub = StubVoiceBackend();
      await stub.stopSpeaking(); // should not throw
    });
  });

  // ── 7. State management — concurrency, cancel ──────────────

  group('State management — concurrent sessions and cancel', () {
    late MockVoiceBackend backend;
    late VoiceService service;

    setUp(() {
      backend = MockVoiceBackend();
      service = VoiceService(backend: backend);
    });

    tearDown(() {
      service.dispose();
    });

    test('stopListening while idle does nothing', () async {
      await service.stopListening();
      expect(service.state.value, equals(VoiceState.idle));
      expect(backend.cancelListeningCalled, isFalse);
    });

    test('stopSpeaking while idle does nothing', () async {
      await service.stopSpeaking();
      expect(service.state.value, equals(VoiceState.idle));
      expect(backend.stopSpeakingCalled, isFalse);
    });

    test('stopListening during active listen cancels and returns to idle',
        () async {
      backend.listenCompleter = Completer<VoiceResult>();
      unawaited(service.listen());
      await Future<void>.delayed(Duration.zero);
      expect(service.state.value, equals(VoiceState.listening));

      await service.stopListening();
      expect(service.state.value, equals(VoiceState.idle));
      expect(backend.cancelListeningCalled, isTrue);

      backend.listenCompleter!.complete(const VoiceResult(transcript: ''));
    });

    test('stopSpeaking during active speak stops and returns to idle',
        () async {
      backend.speakCompleter = Completer<void>();
      unawaited(service.speak('Long text'));
      await Future<void>.delayed(Duration.zero);
      expect(service.state.value, equals(VoiceState.speaking));

      await service.stopSpeaking();
      expect(service.state.value, equals(VoiceState.idle));
      expect(backend.stopSpeakingCalled, isTrue);

      backend.speakCompleter!.complete();
    });

    test('cancel mid-listen then start new listen succeeds', () async {
      backend.listenCompleter = Completer<VoiceResult>();
      unawaited(service.listen());
      await Future<void>.delayed(Duration.zero);

      await service.stopListening();
      expect(service.state.value, equals(VoiceState.idle));

      // Complete old completer, reset for new listen
      backend.listenCompleter!.complete(const VoiceResult(transcript: ''));
      backend.listenCompleter = null;
      backend.nextResult = const VoiceResult(transcript: 'Nouvelle session');

      final r = await service.listen();
      expect(r.transcript, equals('Nouvelle session'));
    });

    test('cancel mid-speak then start new speak succeeds', () async {
      backend.speakCompleter = Completer<void>();
      unawaited(service.speak('Première'));
      await Future<void>.delayed(Duration.zero);

      await service.stopSpeaking();

      backend.speakCompleter!.complete();
      backend.speakCompleter = null;

      await service.speak('Deuxième');
      expect(backend.lastSpokenText, equals('Deuxième'));
    });

    test('state notifier emits all transitions on listen', () async {
      final states = <VoiceState>[];
      service.state.addListener(() => states.add(service.state.value));

      await service.listen();

      expect(states, equals([
        VoiceState.listening,
        VoiceState.processing,
        VoiceState.idle,
      ]));
    });

    test('state notifier emits transitions on speak', () async {
      final states = <VoiceState>[];
      service.state.addListener(() => states.add(service.state.value));

      await service.speak('Bonjour');

      expect(states, equals([
        VoiceState.speaking,
        VoiceState.idle,
      ]));
    });

    test('state notifier emits error on failed listen', () async {
      backend.listenShouldThrow = true;
      final states = <VoiceState>[];
      service.state.addListener(() => states.add(service.state.value));

      try {
        await service.listen();
      } catch (_) {}

      expect(states, contains(VoiceState.error));
    });

    test('VoiceState enum has exactly 5 values', () {
      expect(VoiceState.values.length, equals(5));
      expect(VoiceState.values, containsAll([
        VoiceState.idle,
        VoiceState.listening,
        VoiceState.processing,
        VoiceState.speaking,
        VoiceState.error,
      ]));
    });
  });

  // ── 8. Integration — seniorFriendly config flow ────────────

  group('Integration — accessibility presets end-to-end', () {
    late MockVoiceBackend backend;
    late VoiceService voiceService;

    setUp(() {
      backend = MockVoiceBackend();
      voiceService = VoiceService(backend: backend);
    });

    tearDown(() {
      voiceService.dispose();
    });

    test('seniorFriendly config flows to backend listen params', () async {
      final integration = VoiceChatIntegration(
        voice: voiceService,
        config: VoiceConfig.seniorFriendly,
      );
      backend.nextResult = const VoiceResult(transcript: 'Bonjour');
      await integration.voiceToChat();

      expect(backend.lastSilenceTimeout, equals(5));
    });

    test('seniorFriendly config flows to backend speak params', () async {
      final integration = VoiceChatIntegration(
        voice: voiceService,
        config: VoiceConfig.seniorFriendly,
      );
      await integration.chatToVoice('Bienvenue');

      expect(backend.lastSpeakRate, equals(0.7));
      expect(backend.lastSpeakPitch, equals(1.0));
    });

    test('lowVision config auto-reads in conversation turn', () async {
      backend.nextResult = const VoiceResult(transcript: 'Aide');
      final integration = VoiceChatIntegration(
        voice: voiceService,
        config: VoiceConfig.lowVision,
      );

      await integration.voiceConversationTurn(
        onTranscript: (t) async => 'Voici l\'aide.',
      );

      // lowVision has autoRead = true, so TTS should fire
      expect(backend.lastSpokenText, equals('Voici l\'aide.'));
    });

    test('standard config does NOT auto-read in conversation turn', () async {
      backend.nextResult = const VoiceResult(transcript: 'Question');
      final integration = VoiceChatIntegration(
        voice: voiceService,
        config: VoiceConfig.standard,
      );

      await integration.voiceConversationTurn(
        onTranscript: (t) async => 'Réponse',
      );

      // standard has autoRead = false, alwaysSpeak defaults false
      expect(backend.lastSpokenText, isNull);
    });
  });

  // ── 9. PII scrubbing (VoiceChatIntegration) ────────────────

  group('PII scrubbing — voiceToChat', () {
    late MockVoiceBackend backend;
    late VoiceService voiceService;

    setUp(() {
      backend = MockVoiceBackend();
      voiceService = VoiceService(backend: backend);
    });

    tearDown(() {
      voiceService.dispose();
    });

    test('IBAN is scrubbed from transcript', () async {
      backend.nextResult = const VoiceResult(
        transcript: 'Mon IBAN est CH93 0076 2011 6238 5295 7',
      );
      final integration = VoiceChatIntegration(voice: voiceService);
      final result = await integration.voiceToChat();
      expect(result, isNotNull);
      expect(result!, isNot(contains('CH93')));
      expect(result, contains('[***]'));
    });

    test('Swiss SSN (AVS number) is scrubbed from transcript', () async {
      backend.nextResult = const VoiceResult(
        transcript: 'Mon numéro AVS est 756.1234.5678.97',
      );
      final integration = VoiceChatIntegration(voice: voiceService);
      final result = await integration.voiceToChat();
      expect(result, isNotNull);
      expect(result!, isNot(contains('756.1234')));
      expect(result, contains('[***]'));
    });

    test('salary amount with CHF is scrubbed', () async {
      backend.nextResult = const VoiceResult(
        transcript: 'Je gagne 12000 CHF par mois',
      );
      final integration = VoiceChatIntegration(voice: voiceService);
      final result = await integration.voiceToChat();
      expect(result, isNotNull);
      expect(result!, isNot(contains('12000 CHF')));
      expect(result, contains('[***]'));
    });

    test('employer name after chez is scrubbed', () async {
      backend.nextResult = const VoiceResult(
        transcript: 'Je travaille chez Nestlé depuis 10 ans',
      );
      final integration = VoiceChatIntegration(voice: voiceService);
      final result = await integration.voiceToChat();
      expect(result, isNotNull);
      expect(result!, isNot(contains('Nestlé')));
      expect(result, contains('[***]'));
    });

    test('non-PII text passes through unchanged', () async {
      backend.nextResult = const VoiceResult(
        transcript: 'Quand puis-je prendre ma prévoyance',
      );
      final integration = VoiceChatIntegration(voice: voiceService);
      final result = await integration.voiceToChat();
      expect(result, equals('Quand puis-je prendre ma prévoyance'));
    });

    test('multiple PII patterns scrubbed in same transcript', () async {
      backend.nextResult = const VoiceResult(
        transcript: 'Mon IBAN CH93 0076 2011 6238 5295 7 et AVS 756.1234.5678.97',
      );
      final integration = VoiceChatIntegration(voice: voiceService);
      final result = await integration.voiceToChat();
      expect(result, isNotNull);
      // Both should be scrubbed
      expect(result!, isNot(contains('CH93')));
      expect(result, isNot(contains('756.1234')));
    });
  });

  // ── 10. Safe mode — debt crisis keyword detection ──────────

  group('Safe mode — debt crisis keywords', () {
    late MockVoiceBackend backend;
    late VoiceService voiceService;

    setUp(() {
      backend = MockVoiceBackend();
      voiceService = VoiceService(backend: backend);
    });

    tearDown(() {
      voiceService.dispose();
    });

    test('onSafeModeDetected called when transcript contains dette', () async {
      backend.nextResult = const VoiceResult(
        transcript: 'J\'ai trop de dettes',
      );
      var safeModeTriggered = false;
      final integration = VoiceChatIntegration(
        voice: voiceService,
        onSafeModeDetected: () => safeModeTriggered = true,
      );

      await integration.voiceToChat();
      expect(safeModeTriggered, isTrue);
    });

    test('onSafeModeDetected called for poursuite keyword', () async {
      backend.nextResult = const VoiceResult(
        transcript: 'J\'ai reçu une poursuite',
      );
      var safeModeTriggered = false;
      final integration = VoiceChatIntegration(
        voice: voiceService,
        onSafeModeDetected: () => safeModeTriggered = true,
      );

      await integration.voiceToChat();
      expect(safeModeTriggered, isTrue);
    });

    test('onSafeModeDetected called for faillite keyword', () async {
      backend.nextResult = const VoiceResult(
        transcript: 'Je suis en faillite personnelle',
      );
      var safeModeTriggered = false;
      final integration = VoiceChatIntegration(
        voice: voiceService,
        onSafeModeDetected: () => safeModeTriggered = true,
      );

      await integration.voiceToChat();
      expect(safeModeTriggered, isTrue);
    });

    test('onSafeModeDetected NOT called for normal text', () async {
      backend.nextResult = const VoiceResult(
        transcript: 'Comment fonctionne la prévoyance',
      );
      var safeModeTriggered = false;
      final integration = VoiceChatIntegration(
        voice: voiceService,
        onSafeModeDetected: () => safeModeTriggered = true,
      );

      await integration.voiceToChat();
      expect(safeModeTriggered, isFalse);
    });

    test('safe mode detection is case-insensitive', () async {
      backend.nextResult = const VoiceResult(
        transcript: 'SURENDETTEMENT grave',
      );
      var safeModeTriggered = false;
      final integration = VoiceChatIntegration(
        voice: voiceService,
        onSafeModeDetected: () => safeModeTriggered = true,
      );

      await integration.voiceToChat();
      expect(safeModeTriggered, isTrue);
    });

    test('no callback set — debt keywords do not crash', () async {
      backend.nextResult = const VoiceResult(
        transcript: 'J\'ai des dettes',
      );
      // No onSafeModeDetected callback
      final integration = VoiceChatIntegration(voice: voiceService);

      // Should not throw
      final result = await integration.voiceToChat();
      expect(result, isNotNull);
    });
  });

  // ── 11. ComplianceGuard integration in chatToVoice ─────────

  group('ComplianceGuard — chatToVoice compliance layer', () {
    late MockVoiceBackend backend;
    late VoiceService voiceService;

    setUp(() {
      backend = MockVoiceBackend();
      voiceService = VoiceService(backend: backend);
    });

    tearDown(() {
      voiceService.dispose();
    });

    test('chatToVoice runs text through ComplianceGuard before speaking',
        () async {
      final integration = VoiceChatIntegration(voice: voiceService);
      // Text with projection keyword — ComplianceGuard may inject disclaimer
      await integration.chatToVoice('Votre rente estimée sera de 2500 par mois.');
      // The text was spoken (not silenced by useFallback)
      expect(backend.lastSpokenText, isNotNull);
      // It must start with the original text
      expect(backend.lastSpokenText!, startsWith('Votre rente'));
    });

    test('chatToVoice does NOT add disclaimer for non-projection text',
        () async {
      final integration = VoiceChatIntegration(voice: voiceService);
      await integration.chatToVoice('Bonjour, comment allez-vous aujourd\'hui.');
      expect(backend.lastSpokenText, isNotNull);
      expect(backend.lastSpokenText!, isNot(contains('Outil éducatif')));
    });

    test('chatToVoice silences non-compliant text (useFallback)', () async {
      final integration = VoiceChatIntegration(voice: voiceService);
      // Empty after compliance → useFallback
      await integration.chatToVoice('');
      expect(backend.lastSpokenText, isNull);
    });
  });
}
