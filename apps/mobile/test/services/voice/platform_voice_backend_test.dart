/// PlatformVoiceBackend tests — Sprint S63 (P1-B STT).
///
/// 10 tests covering:
///   - STT returns false when channel is absent (graceful degradation)
///   - STT returns true when speech_to_text channel responds
///   - Capabilities detection does not crash
///   - Graceful degradation on missing plugin (MissingPluginException)
///   - listen() throws UnsupportedError when STT unavailable
///   - cancelListening() is a no-op when STT not initialized (no throw)
///   - stopSpeaking() is a no-op when TTS is unavailable
///   - resetCache() clears cached availability
///   - isTtsAvailable() caches result on repeated calls
///   - speak() throws UnsupportedError when TTS unavailable
///
/// Note: In test environment, channel calls throw MissingPluginException
/// unless a mock handler is registered — the backend handles this gracefully.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/voice/platform_voice_backend.dart';

// ────────────────────────────────────────────────────────────
//  Helpers
// ────────────────────────────────────────────────────────────

/// Sets up a mock MethodChannel that returns [response] for any invocation.
void _mockChannel(String channel, {Object? response}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    MethodChannel(channel),
    (call) async => response,
  );
}

/// Sets up a mock MethodChannel that throws [PlatformException].
void _mockChannelThrowsPlatform(String channel) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    MethodChannel(channel),
    (call) async => throw PlatformException(code: 'UNAVAILABLE'),
  );
}

/// Removes the mock so the channel falls back to MissingPluginException.
void _removeMock(String channel) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(MethodChannel(channel), null);
}

// ────────────────────────────────────────────────────────────
//  Tests
// ────────────────────────────────────────────────────────────

void main() {
  // Make sure test framework handles platform channel exceptions correctly.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlatformVoiceBackend — capabilities detection', () {
    tearDown(() {
      // Clear any mocks installed by individual tests.
      _removeMock('flutter_tts');
      _removeMock('plugin.csdcorp.com/speech_recognition');
    });

    test('isSttAvailable returns false when plugin not installed (default)', () async {
      // No mock → MissingPluginException → false.
      final backend = PlatformVoiceBackend();
      final result = await backend.isSttAvailable();
      expect(result, isFalse);
    });

    test('isTtsAvailable returns false when plugin not installed (default)', () async {
      // No mock → MissingPluginException → false.
      final backend = PlatformVoiceBackend();
      final result = await backend.isTtsAvailable();
      expect(result, isFalse);
    });

    test('isTtsAvailable returns true when platform channel responds positively', () async {
      _mockChannel('flutter_tts', response: true);
      final backend = PlatformVoiceBackend();
      final result = await backend.isTtsAvailable();
      expect(result, isTrue);
    });

    test('isTtsAvailable returns false when platform channel returns null', () async {
      _mockChannel('flutter_tts', response: null);
      final backend = PlatformVoiceBackend();
      final result = await backend.isTtsAvailable();
      expect(result, isFalse);
    });

    test('isTtsAvailable returns false on PlatformException', () async {
      _mockChannelThrowsPlatform('flutter_tts');
      final backend = PlatformVoiceBackend();
      final result = await backend.isTtsAvailable();
      expect(result, isFalse);
    });

    test('isSttAvailable returns true when speech_to_text channel responds', () async {
      _mockChannel('plugin.csdcorp.com/speech_recognition', response: true);
      final backend = PlatformVoiceBackend();
      final result = await backend.isSttAvailable();
      expect(result, isTrue);
    });

    test('isTtsAvailable caches result — channel called only once', () async {
      var callCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter_tts'),
        (call) async {
          callCount++;
          return true;
        },
      );
      final backend = PlatformVoiceBackend();
      await backend.isTtsAvailable();
      await backend.isTtsAvailable(); // second call — must use cache
      expect(callCount, equals(1));
    });

    test('resetCache clears cached availability', () async {
      var callCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter_tts'),
        (call) async {
          callCount++;
          return true;
        },
      );
      final backend = PlatformVoiceBackend();
      await backend.isTtsAvailable();
      backend.resetCache();
      await backend.isTtsAvailable(); // should probe again after reset
      expect(callCount, equals(2));
    });
  });

  group('PlatformVoiceBackend — graceful degradation', () {
    tearDown(() {
      _removeMock('flutter_tts');
      _removeMock('plugin.csdcorp.com/speech_recognition');
    });

    test('listen() throws UnsupportedError when STT unavailable', () async {
      final backend = PlatformVoiceBackend();
      expect(
        () => backend.listen(),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('cancelListening() is a no-op — does not throw', () async {
      final backend = PlatformVoiceBackend();
      await backend.cancelListening(); // must not throw
    });

    test('stopSpeaking() is a no-op when TTS unavailable — does not throw',
        () async {
      // No mock → TTS unavailable → stopSpeaking should do nothing silently.
      final backend = PlatformVoiceBackend();
      await backend.stopSpeaking(); // must not throw
    });

    test('speak() throws UnsupportedError when TTS unavailable', () async {
      // No mock → isTtsAvailable returns false → speak throws.
      final backend = PlatformVoiceBackend();
      expect(
        () => backend.speak('Bonjour'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
