// Unit tests for the `screen_pump` golden test helper.
//
// These tests are the ONLY part of test/goldens/ that runs on CI — they
// pin the helper's public surface so downstream phases (8a, 8c, 9, 12)
// can rely on stable dimensions and locale wiring without depending on
// image-diff goldens (which are local-run only, per ci.yml and README).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';

import 'screen_pump.dart';

void main() {
  group('specFor', () {
    test('iPhone 14 Pro has locked 390x844 @ 3.0x', () {
      final spec = specFor(GoldenDevice.iphone14Pro);
      expect(spec.name, 'iPhone 14 Pro');
      expect(spec.size, const Size(390, 844));
      expect(spec.devicePixelRatio, 3.0);
    });

    test('Galaxy A14 has locked 411x914 @ 2.625x', () {
      final spec = specFor(GoldenDevice.galaxyA14);
      expect(spec.name, 'Galaxy A14');
      expect(spec.size, const Size(411, 914));
      expect(spec.devicePixelRatio, 2.625);
    });
  });

  group('pumpScreen', () {
    testWidgets('iphone14Pro sets view size 390x844 @ 3.0x', (tester) async {
      await pumpScreen(
        tester,
        device: GoldenDevice.iphone14Pro,
        child: const SizedBox.shrink(),
      );
      final view = tester.view;
      expect(view.devicePixelRatio, 3.0);
      expect(view.physicalSize, const Size(390 * 3.0, 844 * 3.0));
    });

    testWidgets('galaxyA14 sets view size 411x914 @ 2.625x', (tester) async {
      await pumpScreen(
        tester,
        device: GoldenDevice.galaxyA14,
        child: const SizedBox.shrink(),
      );
      final view = tester.view;
      expect(view.devicePixelRatio, 2.625);
      expect(view.physicalSize, const Size(411 * 2.625, 914 * 2.625));
    });

    testWidgets('wraps child in MaterialApp with MINT S delegate', (tester) async {
      await pumpScreen(
        tester,
        child: Builder(
          builder: (context) {
            // Reading S.of MUST succeed — proves the delegate is mounted.
            final s = S.of(context);
            return Text(
              s != null ? 'localized' : 'missing',
              textDirection: TextDirection.ltr,
            );
          },
        ),
      );
      expect(find.text('localized'), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('locale parameter defaults to fr', (tester) async {
      Locale? seen;
      await pumpScreen(
        tester,
        child: Builder(
          builder: (context) {
            seen = Localizations.localeOf(context);
            return const SizedBox.shrink();
          },
        ),
      );
      expect(seen, const Locale('fr'));
    });

    testWidgets('disableAnimations flag reaches MediaQuery', (tester) async {
      bool? flag;
      await pumpScreen(
        tester,
        disableAnimations: true,
        child: Builder(
          builder: (context) {
            flag = MediaQuery.of(context).disableAnimations;
            return const SizedBox.shrink();
          },
        ),
      );
      expect(flag, isTrue);
    });
  });
}
