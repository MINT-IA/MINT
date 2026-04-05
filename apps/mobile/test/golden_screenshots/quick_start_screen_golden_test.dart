import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/screens/onboarding/quick_start_screen.dart';

import 'golden_test_helpers.dart';

void main() {
  setUp(() async {
    await setupGoldenEnvironment();
  });

  group('Quick Start Screen Golden Tests', () {
    testWidgets('warmup — preload fonts', (tester) async {
      tester.view.physicalSize = kGoldenDeviceSize * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({'nLPD_consent_given': true});

      await tester.runAsync(() async {
        await tester.pumpWidget(
          buildGoldenWidget(const QuickStartScreen()),
        );
        await Future.delayed(const Duration(seconds: 5));
      });
      await tester.pump();
    });

    testWidgets('quick start — default state (new user)', (tester) async {
      tester.view.physicalSize = kGoldenDeviceSize * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({'nLPD_consent_given': true});

      await tester.runAsync(() async {
        await tester.pumpWidget(
          buildGoldenWidget(const QuickStartScreen()),
        );
        await Future.delayed(const Duration(seconds: 3));
      });
      await tester.pump();

      await expectLater(
        find.byType(QuickStartScreen),
        matchesGoldenFile('goldens/quick_start_top.png'),
      );
    });

    testWidgets('quick start — scrolled to preview + CTA', (tester) async {
      tester.view.physicalSize = kGoldenDeviceSize * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({'nLPD_consent_given': true});

      await tester.runAsync(() async {
        await tester.pumpWidget(
          buildGoldenWidget(const QuickStartScreen()),
        );
        await Future.delayed(const Duration(seconds: 3));
      });
      await tester.pump();

      final scrollable = find.byType(SingleChildScrollView);
      if (scrollable.evaluate().isNotEmpty) {
        await tester.drag(scrollable, const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 300));
      }

      await expectLater(
        find.byType(QuickStartScreen),
        matchesGoldenFile('goldens/quick_start_bottom.png'),
      );
    });
  });
}
