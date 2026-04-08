import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/screens/landing_screen.dart';

import 'golden_test_helpers.dart';

// Phase 7 (L1.7 Landing v2) rebuilt LandingScreen as a single full-screen
// calm promise surface: wordmark + paragraphe-mère + CTA + privacy
// micro-phrase + legal footer. There is no SingleChildScrollView,
// no trust bar, no quick-calc section — so the legacy "scrolled to quick
// calc" and "bottom (CTA + trust bar)" variants no longer apply.
//
// A single top-of-page golden is sufficient for visual regression.
void main() {
  setUp(() async {
    await setupGoldenEnvironment();
    // Dismiss consent banner
    SharedPreferences.setMockInitialValues({
      'analytics_consent_given': true,
    });
  });

  group('Landing Screen Golden Tests', () {
    // Warmup: preloads Google Fonts via real HTTP.
    // This test has no assertions — it exists to cache fonts for subsequent tests.
    // It may fail due to async font timers; that's expected.
    testWidgets('warmup — preload fonts (no assertions)', (tester) async {
      setGoldenViewport(tester);
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpGoldenWidget(tester, buildGoldenWidget(const LandingScreen()),
          warmup: kFontWarmupDuration);
    });

    testWidgets('landing — top of page (Phase 7 calm promise surface)',
        (tester) async {
      setGoldenViewport(tester);
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpGoldenWidget(tester, buildGoldenWidget(const LandingScreen()));

      await expectLater(
        find.byType(LandingScreen),
        matchesGoldenFile('goldens/landing_top.png'),
      );
    });
  });
}
