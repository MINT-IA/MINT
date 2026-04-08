/// screen_pump — dual-device golden test helper for MINT.
///
/// Provides a single entry point, [pumpScreen], that wraps a widget under
/// test in a `MaterialApp` with MINT localization delegates and configures
/// the test view to match one of the two locked target devices:
///
///   * [GoldenDevice.iphone14Pro] — 390x844 @ 3.0x (CI device)
///   * [GoldenDevice.galaxyA14]   — 411x914 @ 2.625x (local-only per PERF-04)
///
/// ## Usage
///
/// ```dart
/// testWidgets('mtc default', (tester) async {
///   await pumpScreen(
///     tester,
///     device: GoldenDevice.iphone14Pro,
///     child: MintTrameConfiance.inline(
///       confidence: fixture,
///       bloomStrategy: BloomStrategy.never,
///     ),
///   );
///   await expectLater(
///     find.byType(MintTrameConfiance),
///     matchesGoldenFile('goldens/mtc_default.png'),
///   );
/// });
/// ```
///
/// ## Regenerating goldens locally
///
/// ```bash
/// cd apps/mobile
/// flutter test --update-goldens test/goldens/
/// ```
///
/// ## CI scope
///
/// The MINT CI job runs **only** the helper unit tests
/// (`test/goldens/helpers/`). Image-diff golden tests under `test/goldens/s4/`
/// are excluded from CI because Flutter pixel goldens are not stable across
/// the macOS-dev / Linux-CI boundary (same policy as
/// `test/golden_screenshots/` — see ci.yml comment and the README in this
/// directory). They are executed locally by Julien before each release,
/// and the Galaxy A14 subset is a manual gate per PERF-04.
///
/// Plan 04-03 / Phase 4 / Wave 2.
library screen_pump;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';

/// The two locked golden target devices for MINT v2.2.
///
/// Decision reference: `.planning/phases/01-p0a-code-unblockers/01-CONTEXT.md`
/// §D-04 (expert-locked pair).
enum GoldenDevice {
  /// iPhone 14 Pro — 390x844 logical @ 3.0x DPR. Runs on CI.
  iphone14Pro,

  /// Galaxy A14 — 1080x2408 physical / 2.625 DPR = 411x917.71 logical.
  /// Rounded to 411x914 for integer stability (≈ 0.4% height delta, below
  /// any layout break threshold). Runs locally only — excluded from CI per
  /// PERF-04 manual gate.
  galaxyA14,
}

/// Immutable description of a golden device target.
///
/// Exposed publicly so unit tests can read the expected dimensions back.
class GoldenDeviceSpec {
  const GoldenDeviceSpec({
    required this.name,
    required this.size,
    required this.devicePixelRatio,
  });

  final String name;
  final Size size;
  final double devicePixelRatio;
}

const GoldenDeviceSpec _kIphone14Pro = GoldenDeviceSpec(
  name: 'iPhone 14 Pro',
  size: Size(390, 844),
  devicePixelRatio: 3.0,
);

const GoldenDeviceSpec _kGalaxyA14 = GoldenDeviceSpec(
  name: 'Galaxy A14',
  size: Size(411, 914),
  devicePixelRatio: 2.625,
);

/// Returns the immutable [GoldenDeviceSpec] for [device].
///
/// Public so tests can assert sizes without duplicating the constants.
GoldenDeviceSpec specFor(GoldenDevice device) {
  switch (device) {
    case GoldenDevice.iphone14Pro:
      return _kIphone14Pro;
    case GoldenDevice.galaxyA14:
      return _kGalaxyA14;
  }
}

/// Pump [child] inside a fully-configured MINT test scaffold for golden
/// image diffs.
///
/// Sets the test view's `physicalSize` and `devicePixelRatio` to match
/// [device]. Wraps [child] in a `MaterialApp` with the MINT localization
/// delegates, the requested [locale] (default `fr_CH`), and the requested
/// [themeMode] (default light).
///
/// When [disableAnimations] is `true`, the surrounding `MediaQuery` sets
/// `disableAnimations: true` so widgets that honor reduced-motion fall into
/// their fallback path. This is used by the reduced-motion goldens.
///
/// Calls `pumpAndSettle` before returning, so the child is in its final
/// animated state unless animation-sensitive tests take a snapshot earlier.
///
/// The test view overrides are automatically reset at tear-down.
Future<void> pumpScreen(
  WidgetTester tester, {
  required Widget child,
  GoldenDevice device = GoldenDevice.iphone14Pro,
  Locale locale = const Locale('fr'),
  ThemeMode themeMode = ThemeMode.light,
  bool disableAnimations = false,
}) async {
  final GoldenDeviceSpec spec = specFor(device);
  final view = tester.view;
  view.physicalSize = spec.size * spec.devicePixelRatio;
  view.devicePixelRatio = spec.devicePixelRatio;
  addTearDown(() {
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      themeMode: themeMode,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          size: spec.size,
          devicePixelRatio: spec.devicePixelRatio,
          disableAnimations: disableAnimations,
          platformBrightness:
              themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light,
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Material(child: Center(child: child)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
