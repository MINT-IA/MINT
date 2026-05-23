/// Phase 01.5 W02-T07 Task 4 — WaitlistScreen i18n widget tests across
/// all 6 locales.
///
/// Per plan 02-02 Task 1 contract :
///   * FR / EN / DE carry distinct translated titles (canonical copy block).
///   * IT / ES / PT carry the FR fallback (per UI-SPEC §6 — full
///     translation deferred to 01.6 cleanup pass).
///
/// These widget tests prove the WaitlistScreen renders cleanly in every
/// locale and pins the expected title string per locale — any future
/// change that breaks parity (e.g. dropping a key in one locale, or
/// silently switching the IT/ES/PT fallback to English) is caught here
/// instead of slipping through to a user-visible bug.
///
/// Why widget tests and not pure-string tests : the WaitlistScreen
/// consumes the title through `S.of(context)!.waitlistTitle`. Validating
/// the localized string requires a real `MaterialApp` with the right
/// `Locale` AND `localizationsDelegates` — a pure string-lookup test
/// would miss bugs in the delegate resolution chain.
library;

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

/// Service shim that never submits — i18n tests don't exercise the
/// network path.
class _NoopWaitlistService extends WaitlistService {
  _NoopWaitlistService() : super.test();
  @override
  Future<String> resolveSessionId() async => 'i18n-test-session';
  @override
  http.Client get httpClient =>
      MockClient((_) async => http.Response('{}', 201));
  @override
  String get baseUrlOverride => 'https://example.test';
}

Widget _wrapWithLocale(Locale locale) {
  return ChangeNotifierProvider<WaitlistProvider>(
    create: (_) => WaitlistProvider(service: _NoopWaitlistService()),
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: const WaitlistScreen(args: WaitlistArgs()),
    ),
  );
}

/// The 3 ARB-published titles. IT / ES / PT all carry the FR string per
/// the plan 02-02 fallback convention.
const _kFrTitle = 'Encore en chantier pour ton profil';
const _kEnTitle = 'Still being built for your profile';
const _kDeTitle = 'Noch in Arbeit für dein Profil';

void main() {
  group('WaitlistScreen — i18n across 6 locales', () {
    testWidgets('waitlist_screen_renders_in_fr', (tester) async {
      await tester.pumpWidget(_wrapWithLocale(const Locale('fr')));
      await tester.pumpAndSettle();
      expect(find.text(_kFrTitle), findsOneWidget,
          reason: 'FR title must render exactly once');
    });

    testWidgets('waitlist_screen_renders_in_en', (tester) async {
      await tester.pumpWidget(_wrapWithLocale(const Locale('en')));
      await tester.pumpAndSettle();
      expect(find.text(_kEnTitle), findsOneWidget,
          reason: 'EN title must render exactly once');
    });

    testWidgets('waitlist_screen_renders_in_de', (tester) async {
      await tester.pumpWidget(_wrapWithLocale(const Locale('de')));
      await tester.pumpAndSettle();
      expect(find.text(_kDeTitle), findsOneWidget,
          reason: 'DE title must render exactly once');
    });

    testWidgets('waitlist_screen_renders_in_it_fallback (FR text)',
        (tester) async {
      // Per plan 02-02 Task 1: IT carries FR fallback until 01.6 cleanup.
      await tester.pumpWidget(_wrapWithLocale(const Locale('it')));
      await tester.pumpAndSettle();
      expect(find.text(_kFrTitle), findsOneWidget,
          reason:
              'IT locale must surface FR fallback per UI-SPEC §6 (01.6 cleanup)');
    });

    testWidgets('waitlist_screen_renders_in_es_fallback (FR text)',
        (tester) async {
      await tester.pumpWidget(_wrapWithLocale(const Locale('es')));
      await tester.pumpAndSettle();
      expect(find.text(_kFrTitle), findsOneWidget,
          reason:
              'ES locale must surface FR fallback per UI-SPEC §6 (01.6 cleanup)');
    });

    testWidgets('waitlist_screen_renders_in_pt_fallback (FR text)',
        (tester) async {
      await tester.pumpWidget(_wrapWithLocale(const Locale('pt')));
      await tester.pumpAndSettle();
      expect(find.text(_kFrTitle), findsOneWidget,
          reason:
              'PT locale must surface FR fallback per UI-SPEC §6 (01.6 cleanup)');
    });
  });
}
