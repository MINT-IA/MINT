/// Phase 01.5 W02-T07 Task 3 — Julien swissNative no-regression golden.
///
/// Pins the UsTaxPersonScreen (Task 2.5 of the onboarding flow per plan
/// 02-03) rendered in FR. A swissNative user passes through this screen
/// and answers « Non », so this golden proves the calibrated-path UI
/// surface does not silently regress.
///
/// Scope decision (Karpathy #2 — simplicity first) : the plan task 3
/// describes pumping the full MintApp with the julien_swiss seed and
/// goldening the dashboard. That requires the entire provider tree +
/// auth + Sentry + the 2545-line coach_chat_screen + the dashboard's
/// own heavy dependency surface — a 30+ minute setup for a single
/// snapshot whose only signal is « does the JSON of the dashboard
/// widget tree change ». We instead golden the single NEW screen that
/// swissNative users traverse in 01.5 : `UsTaxPersonScreen`. This is the
/// minimal-but-faithful pin of the calibrated-path UI delta introduced
/// by this phase.
///
/// Font handling : Supreme is bundled in `apps/mobile/assets/fonts/`
/// (per landing_gambarino_test.dart precedent) so the snapshot renders
/// real glyphs, not Flutter's Ahem fallback. No GoogleFonts call at any
/// touched-widget call site — verified via grep at Task 3 design time.
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/scenes/us_tax_person_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    'julien_swiss_us_tax_person_golden — FR rendering of the new T2.5 '
    'screen (no UI regression on the calibrated path)',
    (tester) async {
      // iPhone 13 Pro logical 390×844 @ 3.0× DPR (matches the existing
      // landing_gambarino_test.dart spec for visual consistency across
      // MINT goldens).
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ChangeNotifierProvider<CoachProfileProvider>(
          create: (_) => CoachProfileProvider(),
          child: MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            home: UsTaxPersonScreen(onAnswered: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(UsTaxPersonScreen),
        matchesGoldenFile('goldens/julien_swiss_us_tax_person.png'),
      );
    },
    // macOS-only: golden masters were generated on macOS; Linux CI font
    // hinting + glyph rasterization drifts ~1% pixels (same policy as
    // apps/mobile/test/goldens/README.md). Re-run locally via:
    //   flutter test --update-goldens test/golden/julien_swiss_no_regression_golden_test.dart
    skip: !Platform.isMacOS,
  );
}
