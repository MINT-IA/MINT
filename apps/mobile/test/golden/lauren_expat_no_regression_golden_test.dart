/// Phase 01.5 W02-T07 Task 3 — Lauren expat /waitlist no-regression golden.
///
/// Pins the WaitlistScreen (plan 02-02) rendered in FR with
/// `WaitlistArgs(archetype: 'expat_us')`. This is the NEW destination for
/// gated users (FATCA path) — no prior baseline existed, so this golden
/// is the explicit pin of the new expected output.
///
/// Per CLAUDE.md §4 « Julien+Lauren golden » convention : Julien =
/// swiss_native canonical user, Lauren = US-expat canonical user. The
/// `julien_expat_us` walker seed (plan 02-06) carries Lauren's archetype
/// signals (usTaxPerson:true, nationality:'US') — naming convention is
/// orthogonal.
///
/// Scope decision : we golden the WaitlistScreen in its INITIAL form
/// state (no email entered, consent unchecked). This is the entry-frame
/// the gated user sees post-redirect — capturing the success state would
/// require a real network mock and is orthogonal to the « no UI
/// regression » assertion.
///
/// Font handling : Supreme is bundled (no GoogleFonts in any widget on
/// the WaitlistScreen render path — verified by grep at Task 3 design
/// time).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/waitlist_provider.dart';
import 'package:mint_mobile/screens/waitlist/waitlist_args.dart';
import 'package:mint_mobile/screens/waitlist/waitlist_screen.dart';
import 'package:mint_mobile/services/waitlist_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Deterministic service shim — the golden never submits, so this only
/// exists to satisfy the WaitlistProvider constructor contract.
class _NoopWaitlistService extends WaitlistService {
  _NoopWaitlistService() : super.test();
  @override
  Future<String> resolveSessionId() async => 'golden-test-session';
  @override
  http.Client get httpClient =>
      MockClient((_) async => http.Response('{}', 201));
  @override
  String get baseUrlOverride => 'https://example.test';
}

Future<void> _loadFontFromAssets(String family, String assetPath) async {
  final loader = FontLoader(family);
  final ByteData bytes = await rootBundle.load(assetPath);
  loader.addFont(Future<ByteData>.value(bytes));
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFontFromAssets(
      'Supreme',
      'assets/fonts/Supreme-Regular.otf',
    );
    await _loadFontFromAssets(
      'Supreme',
      'assets/fonts/Supreme-Medium.otf',
    );
    await _loadFontFromAssets(
      'Supreme',
      'assets/fonts/Supreme-Bold.otf',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'lauren_expat_us_waitlist_golden — initial FR rendering of the '
    'expat_us /waitlist destination',
    (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ChangeNotifierProvider<WaitlistProvider>(
          create: (_) => WaitlistProvider(service: _NoopWaitlistService()),
          child: MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            home: const WaitlistScreen(
              args: WaitlistArgs(archetype: 'expat_us'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(WaitlistScreen),
        matchesGoldenFile('goldens/lauren_expat_us_waitlist.png'),
      );
    },
  );
}
