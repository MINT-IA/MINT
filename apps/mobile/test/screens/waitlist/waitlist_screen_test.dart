import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/waitlist_provider.dart';
import 'package:mint_mobile/screens/waitlist/waitlist_args.dart';
import 'package:mint_mobile/screens/waitlist/waitlist_screen.dart';
import 'package:mint_mobile/services/waitlist_service.dart';
import 'package:provider/provider.dart';

/// Service shim that lets each test drive the HTTP response.
class _FakeWaitlistService extends WaitlistService {
  _FakeWaitlistService({required this.responseBuilder}) : super.test();

  final Future<http.Response> Function(http.Request req) responseBuilder;

  @override
  Future<String> resolveSessionId() async => 'test-session-uuid';

  @override
  http.Client get httpClient => MockClient((req) => responseBuilder(req));

  @override
  String get baseUrlOverride => 'https://example.test';
}

Widget _wrapWithApp({
  required Widget child,
  Locale locale = const Locale('fr'),
  WaitlistService? service,
}) {
  final svc = service ??
      _FakeWaitlistService(
        responseBuilder: (req) async => http.Response('{}', 201),
      );
  return MaterialApp(
    locale: locale,
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    home: ChangeNotifierProvider<WaitlistProvider>(
      create: (_) => WaitlistProvider(service: svc),
      child: child,
    ),
  );
}

void main() {
  group('WaitlistArgs', () {
    test('default constructor: archetype null, source=onboarding_hard_gate',
        () {
      const args = WaitlistArgs();
      expect(args.archetype, isNull);
      expect(args.source, 'onboarding_hard_gate');
    });

    test('custom archetype, default source', () {
      const args = WaitlistArgs(archetype: 'expat_us');
      expect(args.archetype, 'expat_us');
      expect(args.source, 'onboarding_hard_gate');
    });

    test('custom archetype + source round-trip', () {
      const args = WaitlistArgs(archetype: 'cross_border', source: 'settings');
      expect(args.archetype, 'cross_border');
      expect(args.source, 'settings');
    });
  });

  group('WaitlistScreen — initial form', () {
    testWidgets('renders title, 3 body paragraphs, email field, CTA',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithApp(child: const WaitlistScreen(args: WaitlistArgs())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Encore en chantier pour ton profil'), findsOneWidget);
      expect(
        find.textContaining('MINT est calibré aujourd\'hui'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Ton profil correspond à une situation'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Laisse-nous ton email'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsOneWidget);
      // CTA button (key set on the form).
      expect(find.byKey(const Key('waitlist-cta')), findsOneWidget);
    });

    testWidgets('offers a profile correction exit before email submission',
        (tester) async {
      var correctionRequested = false;

      await tester.pumpWidget(
        _wrapWithApp(
          child: WaitlistScreen(
            args: const WaitlistArgs(archetype: 'expat_us'),
            onCorrectProfile: () => correctionRequested = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('waitlist-correct-profile-cta')));
      await tester.pumpAndSettle();

      expect(correctionRequested, isTrue);
    });

    testWidgets('CTA disabled until email valid AND consent checked',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithApp(child: const WaitlistScreen(args: WaitlistArgs())),
      );
      await tester.pumpAndSettle();

      // Initial state: CTA disabled (button.onPressed == null).
      final ctaFinder = find.byKey(const Key('waitlist-cta'));
      var button = tester.widget<FilledButton>(ctaFinder);
      expect(button.onPressed, isNull);

      // Enter a valid email — CTA still disabled (consent unchecked).
      await tester.enterText(find.byType(TextField), 'test@example.ch');
      await tester.pumpAndSettle();
      button = tester.widget<FilledButton>(ctaFinder);
      expect(button.onPressed, isNull,
          reason: 'CTA must stay disabled until consent is checked');

      // Tap the consent checkbox.
      await tester.tap(find.byKey(const Key('waitlist-consent-checkbox')));
      await tester.pumpAndSettle();
      button = tester.widget<FilledButton>(ctaFinder);
      expect(button.onPressed, isNotNull,
          reason: 'CTA must enable once email valid + consent given');
    });

    testWidgets('invalid email keeps CTA disabled even with consent checked',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithApp(child: const WaitlistScreen(args: WaitlistArgs())),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'not-an-email');
      await tester.tap(find.byKey(const Key('waitlist-consent-checkbox')));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('waitlist-cta')),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('WaitlistScreen — success state', () {
    testWidgets('renders success copy + back-to-home CTA after 201',
        (tester) async {
      final svc = _FakeWaitlistService(
        responseBuilder: (req) async => http.Response(
          '{"id":"abc","createdAt":"2026-05-22"}',
          201,
        ),
      );
      await tester.pumpWidget(
        _wrapWithApp(
          child:
              const WaitlistScreen(args: WaitlistArgs(archetype: 'expat_us')),
          service: svc,
        ),
      );
      await tester.pumpAndSettle();

      // Fill form + tap CTA.
      await tester.enterText(find.byType(TextField), 'test@example.ch');
      await tester.tap(find.byKey(const Key('waitlist-consent-checkbox')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('waitlist-cta')));
      await tester.pumpAndSettle();

      // Form is gone; success copy + back-to-home CTA visible.
      expect(find.byType(TextField), findsNothing);
      expect(
        find.text(
            'Merci, on revient vers toi dès que ton profil est pris en charge.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('waitlist-success-cta')), findsOneWidget);
      // Success icon rendered.
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });
  });

  group('WaitlistScreen — error state', () {
    testWidgets('shows inline bad-email message after 400', (tester) async {
      final svc = _FakeWaitlistService(
        responseBuilder: (req) async => http.Response(
          '{"detail":"Email invalide"}',
          400,
        ),
      );
      await tester.pumpWidget(
        _wrapWithApp(
          child:
              const WaitlistScreen(args: WaitlistArgs(archetype: 'expat_us')),
          service: svc,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'bad@example.ch');
      await tester.tap(find.byKey(const Key('waitlist-consent-checkbox')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('waitlist-cta')));
      await tester.pumpAndSettle();

      // Form still visible (inline error). Bad-email copy shown.
      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.text(
            'Cette adresse email ne semble pas valide. Vérifie la syntaxe.'),
        findsOneWidget,
      );
    });
  });

  group('WaitlistScreen — submitting state', () {
    testWidgets('shows MintLoadingIndicator inside CTA while submitting',
        (tester) async {
      // Delay the response so we can observe the submitting frame.
      final completer = Completer<http.Response>();
      final svc = _FakeWaitlistService(
        responseBuilder: (req) async => completer.future,
      );
      await tester.pumpWidget(
        _wrapWithApp(
          child:
              const WaitlistScreen(args: WaitlistArgs(archetype: 'expat_us')),
          service: svc,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'test@example.ch');
      await tester.tap(find.byKey(const Key('waitlist-consent-checkbox')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('waitlist-cta')));
      await tester.pump(); // submitting frame, not settled yet

      // Loading indicator visible inside the CTA.
      expect(
        find.descendant(
          of: find.byKey(const Key('waitlist-cta')),
          matching: find.byType(CupertinoActivityIndicator),
        ),
        findsOneWidget,
      );

      // Unblock the response so the test can complete cleanly.
      completer.complete(http.Response('{"id":"x","createdAt":"now"}', 201));
      await tester.pumpAndSettle();
    });
  });

  group('WaitlistScreen — locale switching', () {
    testWidgets('renders German title under Locale("de")', (tester) async {
      await tester.pumpWidget(
        _wrapWithApp(
          child: const WaitlistScreen(args: WaitlistArgs()),
          locale: const Locale('de'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Noch in Arbeit für dein Profil'), findsOneWidget);
    });
  });

  group('WaitlistScreen — accessibility', () {
    testWidgets('title carries Semantics(header: true)', (tester) async {
      await tester.pumpWidget(
        _wrapWithApp(child: const WaitlistScreen(args: WaitlistArgs())),
      );
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(
        find.text('Encore en chantier pour ton profil'),
      );
      expect(semantics.flagsCollection.isHeader, isTrue);
    });
  });
}
