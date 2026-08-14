@Tags(<String>['local-only'])
library;

// POURQUOI CE MARQUEUR (2026-08-14)
//
// Ces goldens comparent des PIXELS. Ils sont régénérés sur macOS et
// s'exécutaient jusqu'ici uniquement en local ; la CI Linux rend les polices
// autrement, donc ils y échouent sans qu'aucune régression n'existe.
//
// Ce n'est pas une exception inventée ici : le dépôt applique déjà cette
// doctrine à test/golden_screenshots/ — « pixel diffs are [checked] before
// each release » (ci.yml). Les deux autres fichiers de test/goldens/ portaient
// déjà `local-only` ; celui-ci était le seul sans, par oubli.
//
// Ce qui l'a révélé : la branche a AJOUTÉ le shard qui fait tourner
// test/goldens/ en CI (7ce7c2c67, « 70 fichiers de test ne tournaient jamais »)
// ET régénéré ces masters. Les deux changements sont justes ; leur rencontre
// fait échouer des pixels sur une plateforme qui n'est pas celle de référence.

// Phase 7 — Plan 07-03: Landing v2 dual-device goldens + AAA contrast.
//
// Locks the rebuilt `LandingScreen` (Plan 07-02) visual surface against
// regressions in later phases (8b microtypo, 10.5 friction pass). Covers
// CONTEXT.md D-06 (layout), D-08 (reduced-motion), D-09 (AAA text).
//
// Four golden variants:
//   1. iPhone 14 Pro × fr — animated final state
//   2. iPhone 14 Pro × fr × reduced-motion
//   3. Galaxy A14    × fr — animated final state
//   4. Galaxy A14    × fr × reduced-motion
//
// Plus an inline AAA contrast group that asserts wcag ratio ≥ 7.0 for the
// four landing text surfaces against the craie background (and inverse for
// the CTA pill). No external helper dependency — the ~30 LOC WCAG formula
// is inlined below.
//
// CI scope: these image-diff goldens are LOCAL-ONLY per
// `test/goldens/README.md` — CI only runs `test/goldens/helpers/`. Masters
// are regenerated via `flutter test --update-goldens` on Julien's macOS
// dev machine.


import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/screens/landing_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/screen_pump.dart';

Future<void> _loadFontFromAssets(String family, String assetPath) async {
  final loader = FontLoader(family);
  final ByteData bytes = await rootBundle.load(assetPath);
  loader.addFont(Future<ByteData>.value(bytes));
  await loader.load();
}

void main() {
  setUpAll(() async {
    // MVP-GOOGLEFONTS-PURGE-V1: load bundled Fontshare so LandingScreen's
    // chrome (Supreme via MintTextStyles) renders with canonical glyphs.
    await _loadFontFromAssets('Supreme', 'assets/fonts/Supreme-Regular.otf');
    await _loadFontFromAssets('Supreme', 'assets/fonts/Supreme-Medium.otf');
    await _loadFontFromAssets('Supreme', 'assets/fonts/Supreme-Bold.otf');
    await _loadFontFromAssets(
        'Gambarino', 'assets/fonts/Gambarino-Regular.otf');
  });

  setUp(() async {
    // BetaProgramDisclosureSheet.maybeShow() calls SharedPreferences in
    // LandingScreen.initState. Without this mock the Landing v2 goldens
    // throw MissingPluginException (was masked previously by the GoogleFonts
    // timer-pending exception ; surfaced after MVP-GOOGLEFONTS-PURGE-V1).
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Landing v2 goldens', () {
    testWidgets('iPhone 14 Pro × fr — animated final state', (tester) async {
      await pumpScreen(
        tester,
        device: GoldenDevice.iphone14Pro,
        child: const LandingScreen(),
      );
      await expectLater(
        find.byType(LandingScreen),
        matchesGoldenFile('masters/landing_iphone14pro_fr.png'),
      );
    });

    testWidgets('iPhone 14 Pro × fr × reduced-motion', (tester) async {
      await pumpScreen(
        tester,
        device: GoldenDevice.iphone14Pro,
        disableAnimations: true,
        child: const LandingScreen(),
      );
      // Reduced-motion path sets controller.value = 1.0 in a post-frame
      // callback; pumpAndSettle in the helper already drained it.
      await expectLater(
        find.byType(LandingScreen),
        matchesGoldenFile('masters/landing_iphone14pro_fr_reduced_motion.png'),
      );
    });

    testWidgets('Galaxy A14 × fr — animated final state', (tester) async {
      await pumpScreen(
        tester,
        device: GoldenDevice.galaxyA14,
        child: const LandingScreen(),
      );
      await expectLater(
        find.byType(LandingScreen),
        matchesGoldenFile('masters/landing_galaxya14_fr.png'),
      );
    });

    testWidgets('Galaxy A14 × fr × reduced-motion', (tester) async {
      await pumpScreen(
        tester,
        device: GoldenDevice.galaxyA14,
        disableAnimations: true,
        child: const LandingScreen(),
      );
      await expectLater(
        find.byType(LandingScreen),
        matchesGoldenFile('masters/landing_galaxya14_fr_reduced_motion.png'),
      );
    });

    testWidgets('no framework exceptions on either device × textScale 1.0',
        (tester) async {
      await pumpScreen(
        tester,
        device: GoldenDevice.galaxyA14,
        child: const LandingScreen(),
      );
      expect(tester.takeException(), isNull);
    });
  });

}
