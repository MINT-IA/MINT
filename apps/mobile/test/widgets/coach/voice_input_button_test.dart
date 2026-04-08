/// Widget tests for VoiceInputButton — Sprint S63.
///
/// 10 tests covering:
///   - Renders mic icon in idle state
///   - Accessibility label present (no hardcoded strings)
///   - Active state shows primary color background
///   - Processing state shows progress indicator
///   - Tapping calls voiceService.listen
///   - Tapping while listening calls stopListening
///   - onTranscription callback fires on result
///   - onUnavailable fires when STT is off
///   - Button respects config voiceButtonSize
///   - Semantics node is a button
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/coach/voice_config.dart';
import 'package:mint_mobile/services/coach/voice_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/coach/voice_input_button.dart';

// ────────────────────────────────────────────────────────────
//  Mock backend
// ────────────────────────────────────────────────────────────

class _MockBackend implements VoiceBackend {
  bool sttAvailable;
  bool ttsAvailable = true;
  VoiceResult? nextResult;
  String? lastLocale;
  bool cancelListeningCalled = false;
  Completer<VoiceResult>? listenCompleter;

  _MockBackend({
    this.sttAvailable = true,
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
    lastLocale = locale;
    if (listenCompleter != null) return listenCompleter!.future;
    return nextResult ?? const VoiceResult(transcript: 'Bonjour');
  }

  @override
  Future<void> cancelListening() async {
    cancelListeningCalled = true;
  }

  @override
  Future<void> speak(String text,
      {String locale = 'fr-CH',
      double rate = 0.85,
      double pitch = 1.0}) async {}

  @override
  Future<void> stopSpeaking() async {}
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
    // Pre-mark voice disclosure as shown to skip the consent dialog in tests.
    SharedPreferences.setMockInitialValues({
      '_voice_disclosure_shown': true,
    });
  });

  group('VoiceInputButton', () {
    testWidgets('renders mic icon in idle state', (tester) async {
      final backend = _MockBackend();
      final service = VoiceService(backend: backend);
      addTearDown(service.dispose);

      await tester.pumpWidget(_buildApp(
        VoiceInputButton(
          voiceService: service,
          onTranscription: (_) {},
        ),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    });

    testWidgets('accessibility label is present (Semantics button)', (tester) async {
      final backend = _MockBackend();
      final service = VoiceService(backend: backend);
      addTearDown(service.dispose);

      await tester.pumpWidget(_buildApp(
        VoiceInputButton(
          voiceService: service,
          onTranscription: (_) {},
        ),
      ));
      await tester.pump();

      // Verify the Semantics widget exists with button role
      expect(find.bySemanticsLabel(RegExp(r'.+')), findsWidgets);
      // Verify InkWell is the tappable button element
      expect(find.byType(InkWell), findsOneWidget);
      // Label comes from i18n — must be non-empty
      final semantics = tester.getSemantics(find.byType(VoiceInputButton));
      expect(semantics.label, isNotEmpty);
      // Must NOT be a hardcoded string
      expect(semantics.label, isNot(equals('voiceMicLabel')));
    });

    testWidgets('label is not a hardcoded key', (tester) async {
      final backend = _MockBackend();
      final service = VoiceService(backend: backend);
      addTearDown(service.dispose);

      await tester.pumpWidget(_buildApp(
        VoiceInputButton(
          voiceService: service,
          onTranscription: (_) {},
        ),
      ));
      await tester.pump();

      // The localised French string for voiceMicLabel is "Parler au micro"
      final semantics = tester.getSemantics(find.byType(VoiceInputButton));
      expect(semantics.label, equals('Parler au micro'));
    });

    testWidgets('shows mic icon in listening state with primary background',
        (tester) async {
      final backend = _MockBackend();
      final service = VoiceService(backend: backend);
      addTearDown(service.dispose);

      // Set state to listening
      backend.listenCompleter = Completer<VoiceResult>();
      unawaited(service.listen());
      await tester.pump();

      await tester.pumpWidget(_buildApp(
        VoiceInputButton(
          voiceService: service,
          onTranscription: (_) {},
        ),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.mic), findsOneWidget);

      // Background should use MintColors.primary — verify via Material widget
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(VoiceInputButton),
          matching: find.byType(Material),
        ).last,
      );
      expect(material.color, equals(MintColors.primary));

      backend.listenCompleter!.complete(const VoiceResult(transcript: ''));
    });

    testWidgets('shows progress indicator in processing state', (tester) async {
      final backend = _MockBackend();
      final service = VoiceService(backend: backend);
      addTearDown(service.dispose);

      await tester.pumpWidget(_buildApp(
        VoiceInputButton(
          voiceService: service,
          onTranscription: (_) {},
        ),
      ));
      await tester.pump();

      // Manually set processing state
      service.state.value = VoiceState.processing;
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('tapping calls listen and fires onTranscription', (tester) async {
      final backend = _MockBackend(sttAvailable: true);
      backend.nextResult = const VoiceResult(transcript: 'Bonjour');
      final service = VoiceService(backend: backend);
      addTearDown(service.dispose);

      String? received;
      await tester.pumpWidget(_buildApp(
        VoiceInputButton(
          voiceService: service,
          onTranscription: (t) => received = t,
        ),
      ));
      await tester.pump();

      await tester.tap(find.byType(VoiceInputButton));
      await tester.pumpAndSettle();

      expect(received, equals('Bonjour'));
    });

    testWidgets('tapping while listening calls stopListening', (tester) async {
      final backend = _MockBackend();
      backend.listenCompleter = Completer<VoiceResult>();
      final service = VoiceService(backend: backend);
      addTearDown(service.dispose);

      unawaited(service.listen());
      await tester.pump();

      await tester.pumpWidget(_buildApp(
        VoiceInputButton(
          voiceService: service,
          onTranscription: (_) {},
        ),
      ));
      await tester.pump();

      expect(service.state.value, equals(VoiceState.listening));

      await tester.tap(find.byType(VoiceInputButton));
      await tester.pumpAndSettle();

      expect(backend.cancelListeningCalled, isTrue);
      expect(service.state.value, equals(VoiceState.idle));

      backend.listenCompleter!.complete(const VoiceResult(transcript: ''));
    });

    testWidgets('fires onUnavailable when STT unavailable', (tester) async {
      final backend = _MockBackend(sttAvailable: false);
      final service = VoiceService(backend: backend);
      addTearDown(service.dispose);

      var unavailableCalled = false;
      await tester.pumpWidget(_buildApp(
        VoiceInputButton(
          voiceService: service,
          onTranscription: (_) {},
          onUnavailable: () => unavailableCalled = true,
        ),
      ));
      await tester.pump();

      await tester.tap(find.byType(VoiceInputButton));
      await tester.pumpAndSettle();

      expect(unavailableCalled, isTrue);
    });

    testWidgets('respects config voiceButtonSize (standard = 48)', (tester) async {
      final backend = _MockBackend();
      final service = VoiceService(backend: backend);
      addTearDown(service.dispose);

      await tester.pumpWidget(_buildApp(
        VoiceInputButton(
          voiceService: service,
          onTranscription: (_) {},
          config: VoiceConfig.standard, // 48.0
        ),
      ));
      await tester.pump();

      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(VoiceInputButton),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(sizedBox.width, equals(48.0));
      expect(sizedBox.height, equals(48.0));
    });

    testWidgets('respects config voiceButtonSize (seniorFriendly = 72)', (tester) async {
      final backend = _MockBackend();
      final service = VoiceService(backend: backend);
      addTearDown(service.dispose);

      await tester.pumpWidget(_buildApp(
        VoiceInputButton(
          voiceService: service,
          onTranscription: (_) {},
          config: VoiceConfig.seniorFriendly, // 72.0
        ),
      ));
      await tester.pump();

      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(VoiceInputButton),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(sizedBox.width, equals(72.0));
      expect(sizedBox.height, equals(72.0));
    });

    testWidgets('Semantics label changes to listening text when recording',
        (tester) async {
      final backend = _MockBackend();
      backend.listenCompleter = Completer<VoiceResult>();
      final service = VoiceService(backend: backend);
      addTearDown(service.dispose);

      unawaited(service.listen());
      await tester.pump();

      await tester.pumpWidget(_buildApp(
        VoiceInputButton(
          voiceService: service,
          onTranscription: (_) {},
        ),
      ));
      await tester.pump();

      final semantics = tester.getSemantics(find.byType(VoiceInputButton));
      // In listening state the label is voiceMicListening = "J'écoute…"
      expect(semantics.label, isNotEmpty);
      expect(semantics.label, isNot(equals('Parler au micro')));

      backend.listenCompleter!.complete(const VoiceResult(transcript: ''));
    });
  });
}
