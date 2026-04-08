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

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/screens/landing_screen.dart';
import 'package:mint_mobile/theme/colors.dart';

import 'helpers/screen_pump.dart';

void main() {
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

  group('Landing v2 AAA contrast (≥ 7.0 on craie)', () {
    const bg = MintColors.craie;

    test('textPrimary on craie — paragraphe-mère', () {
      final ratio = _wcagContrastRatio(MintColors.textPrimary, bg);
      expect(ratio, greaterThanOrEqualTo(7.0),
          reason: 'paragraphe-mère must be AAA on craie');
    });

    test('craie on textPrimary — CTA pill inverse', () {
      // CTA is craie foreground on textPrimary background — inverse surface.
      final ratio = _wcagContrastRatio(MintColors.craie, MintColors.textPrimary);
      expect(ratio, greaterThanOrEqualTo(7.0),
          reason: 'CTA pill text must be AAA on inverse fill');
    });

    test('textSecondaryAaa on craie — privacy micro-phrase', () {
      final ratio = _wcagContrastRatio(MintColors.textSecondaryAaa, bg);
      expect(ratio, greaterThanOrEqualTo(7.0),
          reason: 'privacy micro-phrase must be AAA on craie');
    });

    test('textMutedAaa on craie — legal footer', () {
      final ratio = _wcagContrastRatio(MintColors.textMutedAaa, bg);
      expect(ratio, greaterThanOrEqualTo(7.0),
          reason: 'legal footer must be AAA on craie');
    });
  });
}

// --- Inline WCAG 2.1 contrast helper -----------------------------------------
//
// Formula: (L1 + 0.05) / (L2 + 0.05) where L1 >= L2, and L is relative
// luminance computed from sRGB channels after gamma decode.
// Reference: https://www.w3.org/TR/WCAG21/#dfn-contrast-ratio

double _wcagContrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

double _relativeLuminance(Color c) {
  final r = _channel(c.red / 255.0);
  final g = _channel(c.green / 255.0);
  final bch = _channel(c.blue / 255.0);
  return 0.2126 * r + 0.7152 * g + 0.0722 * bch;
}

double _channel(double v) {
  return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}
