import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/screens/onboarding/quick_start_screen.dart';

import 'golden_test_helpers.dart';

void main() {
  setUp(() async {
    await setupGoldenEnvironment();
    SharedPreferences.setMockInitialValues({
      'nLPD_consent_given': true,
      'analytics_consent_given': true,
    });
  });

  group('Quick Start Screen Golden Tests', () {
    testWidgets('warmup — preload fonts (no assertions)', (tester) async {
      setGoldenViewport(tester);
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpGoldenWidget(tester, buildGoldenWidget(const QuickStartScreen()),
          warmup: kFontWarmupDuration);
    });

    testWidgets('quick start — top (form fields)', (tester) async {
      setGoldenViewport(tester);
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpGoldenWidget(
          tester, buildGoldenWidget(const QuickStartScreen()));

      await expectLater(
        find.byType(QuickStartScreen),
        matchesGoldenFile('goldens/quick_start_top.png'),
      );
    });

    testWidgets('quick start — scrolled to preview + CTA', (tester) async {
      setGoldenViewport(tester);
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpGoldenWidget(
          tester, buildGoldenWidget(const QuickStartScreen()));

      final scrollable = find.byType(SingleChildScrollView);
      if (scrollable.evaluate().isNotEmpty) {
        await tester.drag(scrollable, const Offset(0, -400),
            warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 300));
      }

      await expectLater(
        find.byType(QuickStartScreen),
        matchesGoldenFile('goldens/quick_start_bottom.png'),
      );
    });
  });
}
