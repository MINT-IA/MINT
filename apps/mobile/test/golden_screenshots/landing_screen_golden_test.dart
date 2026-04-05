import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/screens/landing_screen.dart';

import 'golden_test_helpers.dart';

void main() {
  setUp(() async {
    await setupGoldenEnvironment();
  });

  group('Landing Screen Golden Tests', () {
    // First test warms up Google Fonts cache. Fonts are downloaded once
    // and cached for subsequent tests in this process.
    testWidgets('warmup — preload fonts (no assertions)', (tester) async {
      tester.view.physicalSize = kGoldenDeviceSize * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.runAsync(() async {
        await tester.pumpWidget(
          buildGoldenWidget(const LandingScreen()),
        );
        // Wait for Google Fonts HTTP download to complete
        await Future.delayed(const Duration(seconds: 5));
      });
      await tester.pump();
      // No assertions — just warming up the font cache
    });

    testWidgets('landing — top of page (hero + translator cards)',
        (tester) async {
      tester.view.physicalSize = kGoldenDeviceSize * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Dismiss consent banner by pre-setting SharedPreferences
      SharedPreferences.setMockInitialValues({
        'analytics_consent_given': true,
      });

      await tester.runAsync(() async {
        await tester.pumpWidget(
          buildGoldenWidget(const LandingScreen()),
        );
        await Future.delayed(const Duration(seconds: 3));
      });
      await tester.pump();

      await expectLater(
        find.byType(LandingScreen),
        matchesGoldenFile('goldens/landing_top.png'),
      );
    });

    testWidgets('landing — scrolled to quick calc + CTA', (tester) async {
      tester.view.physicalSize = kGoldenDeviceSize * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({
        'analytics_consent_given': true,
      });

      await tester.runAsync(() async {
        await tester.pumpWidget(
          buildGoldenWidget(const LandingScreen()),
        );
        await Future.delayed(const Duration(seconds: 3));
      });
      await tester.pump();

      // Scroll down to see quick calc section
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

    testWidgets('landing — scrolled to bottom (CTA + trust bar)',
        (tester) async {
      tester.view.physicalSize = kGoldenDeviceSize * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({
        'analytics_consent_given': true,
      });

      await tester.runAsync(() async {
        await tester.pumpWidget(
          buildGoldenWidget(const LandingScreen()),
        );
        await Future.delayed(const Duration(seconds: 3));
      });
      await tester.pump();

      // Scroll to bottom
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
