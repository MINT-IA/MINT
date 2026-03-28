/// Widget tests for VoiceOutputButton — Sprint S63.
///
/// 7 tests covering:
///   - Renders speaker icon in idle state
///   - Accessibility label present
///   - Label is not a hardcoded key (i18n verified)
///   - Tapping starts speak; icon changes to stop
///   - Tapping again calls stopSpeaking
///   - When TTS unavailable, tap does nothing
///   - Label changes to stop text while speaking
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/coach/voice_service.dart';
import 'package:mint_mobile/widgets/coach/voice_output_button.dart';

// ────────────────────────────────────────────────────────────
//  Mock backend
// ────────────────────────────────────────────────────────────

class _MockBackend implements VoiceBackend {
  bool ttsAvailable;
  String? lastSpoken;
  bool stopSpeakingCalled = false;
  Completer<void>? speakCompleter;

  _MockBackend({
    this.ttsAvailable = true,
  });

  @override
  Future<bool> isSttAvailable() async => true;
  @override
  Future<bool> isTtsAvailable() async => ttsAvailable;

  @override
  Future<VoiceResult> listen({
    Duration maxDuration = const Duration(seconds: 30),
    int silenceTimeout = 3,
    String locale = 'fr-CH',
  }) async =>
      throw UnsupportedError('Not used in output button tests');

  @override
  Future<void> cancelListening() async {}

  @override
  Future<void> speak(String text,
      {String locale = 'fr-CH',
      double rate = 0.85,
      double pitch = 1.0}) async {
    lastSpoken = text;
    if (speakCompleter != null) return speakCompleter!.future;
  }

  @override
  Future<void> stopSpeaking() async {
    stopSpeakingCalled = true;
  }
}

// ────────────────────────────────────────────────────────────
//  Helpers
// ────────────────────────────────────────────────────────────

Widget _buildApp(Widget child) {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

// ────────────────────────────────────────────────────────────
//  Tests
// ────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('VoiceOutputButton', () {
    testWidgets('renders speaker icon in idle state', (tester) async {
      final backend = _MockBackend();
      final service = VoiceService(backend: backend);
      addTearDown(service.dispose);

      await tester.pumpWidget(_buildApp(
        VoiceOutputButton(
          voiceService: service,
          text: 'Votre rente sera de 2\u202f500 CHF.',
        ),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    });

    testWidgets('accessibility label is present', (tester) async {
      final backend = _MockBackend();
      final service = VoiceService(backend: backend);
      addTearDown(service.dispose);

      await tester.pumpWidget(_buildApp(
        VoiceOutputButton(
          voiceService: service,
          text: 'Test',
        ),
      ));
      await tester.pump();

      // Verify there's an accessible button (IconButton)
      expect(find.byType(IconButton), findsOneWidget);
      final semantics = tester.getSemantics(find.byType(VoiceOutputButton));
      expect(semantics.label, isNotEmpty);
    });

    testWidgets('label is localised — not a raw key', (tester) async {
      final backend = _MockBackend();
      final service = VoiceService(backend: backend);
      addTearDown(service.dispose);

      await tester.pumpWidget(_buildApp(
        VoiceOutputButton(
          voiceService: service,
          text: 'Test',
        ),
      ));
      await tester.pump();

      final semantics = tester.getSemantics(find.byType(VoiceOutputButton));
      // French localised value = "Écouter la réponse"
      expect(semantics.label, equals('\u00c9couter la r\u00e9ponse'));
      // Not the raw key
      expect(semantics.label, isNot(equals('voiceSpeakerLabel')));
    });

    testWidgets('tapping starts TTS and icon changes to stop', (tester) async {
      final backend = _MockBackend();
      backend.speakCompleter = Completer<void>();
      final service = VoiceService(backend: backend);
      addTearDown(service.dispose);

      await tester.pumpWidget(_buildApp(
        VoiceOutputButton(
          voiceService: service,
          text: 'Bienvenue',
        ),
      ));
      await tester.pump();

      await tester.tap(find.byType(VoiceOutputButton));
      await tester.pump();

      // After tapping, should show stop icon
      expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
      expect(backend.lastSpoken, equals('Bienvenue'));

      backend.speakCompleter!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('tapping while speaking calls stopSpeaking', (tester) async {
      final backend = _MockBackend();
      backend.speakCompleter = Completer<void>();
      final service = VoiceService(backend: backend);
      addTearDown(service.dispose);

      final widget = VoiceOutputButton(
        voiceService: service,
        text: 'Long text',
      );

      await tester.pumpWidget(_buildApp(widget));
      await tester.pump();

      // First tap — starts speaking
      await tester.tap(find.byType(VoiceOutputButton));
      await tester.pump();

      expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);

      // Second tap — stops speaking
      await tester.tap(find.byType(VoiceOutputButton));
      await tester.pumpAndSettle();

      expect(backend.stopSpeakingCalled, isTrue);

      backend.speakCompleter!.complete();
    });

    testWidgets('when TTS unavailable, tap does nothing', (tester) async {
      final backend = _MockBackend(ttsAvailable: false);
      final service = VoiceService(backend: backend);
      addTearDown(service.dispose);

      await tester.pumpWidget(_buildApp(
        VoiceOutputButton(
          voiceService: service,
          text: 'Test',
        ),
      ));
      await tester.pump();

      await tester.tap(find.byType(VoiceOutputButton));
      await tester.pumpAndSettle();

      // Icon should remain speaker (not stop) since nothing started
      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
      expect(backend.lastSpoken, isNull);
    });

    testWidgets('label changes to stop text while speaking', (tester) async {
      final backend = _MockBackend();
      backend.speakCompleter = Completer<void>();
      final service = VoiceService(backend: backend);
      addTearDown(service.dispose);

      await tester.pumpWidget(_buildApp(
        VoiceOutputButton(
          voiceService: service,
          text: 'Retraite',
        ),
      ));
      await tester.pump();

      // Tap to start
      await tester.tap(find.byType(VoiceOutputButton));
      await tester.pump();

      final semantics = tester.getSemantics(find.byType(VoiceOutputButton));
      // French localised value for voiceSpeakerStop = "Arrêter la lecture"
      expect(semantics.label, equals('Arr\u00eater la lecture'));

      backend.speakCompleter!.complete();
      await tester.pumpAndSettle();
    });
  });
}
