import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/screens/landing_screen.dart';

import 'golden_test_helpers.dart';

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

    testWidgets('landing — top of page', (tester) async {
      setGoldenViewport(tester);
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpGoldenWidget(tester, buildGoldenWidget(const LandingScreen()));

      await expectLater(
        find.byType(LandingScreen),
        matchesGoldenFile('goldens/landing_top.png'),
      );
    });

    testWidgets('landing — scrolled to quick calc', (tester) async {
      setGoldenViewport(tester);
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpGoldenWidget(tester, buildGoldenWidget(const LandingScreen()));

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -500),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await expectLater(
        find.byType(LandingScreen),
        matchesGoldenFile('goldens/landing_quick_calc.png'),
      );
    });

    testWidgets('landing — bottom (CTA + trust bar)', (tester) async {
      setGoldenViewport(tester);
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpGoldenWidget(tester, buildGoldenWidget(const LandingScreen()));

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1200),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await expectLater(
        find.byType(LandingScreen),
        matchesGoldenFile('goldens/landing_bottom.png'),
      );
    });
  });
}
