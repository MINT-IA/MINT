// TolerantGoldenFileComparator — enforces a 1.5% pixel diff tolerance
// for golden screenshot regression tests.
//
// Flutter's default LocalFileComparator requires an exact pixel match (0% diff).
// This comparator allows up to [tolerance] (default 1.5%) pixel difference,
// accounting for platform-level rendering variations (font hinting, anti-aliasing,
// GPU differences between CI and local environments).
//
// Based on the pattern recommended in Flutter SDK documentation:
// https://api.flutter.dev/flutter/flutter_test/goldenFileComparator.html

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [GoldenFileComparator] that allows a configurable pixel diff tolerance.
///
/// Usage (in test main(), before setUp):
/// ```dart
/// goldenFileComparator = TolerantGoldenFileComparator(
///   Uri.parse('test/golden_screenshots/golden_screenshot_test.dart'),
/// );
/// ```
class TolerantGoldenFileComparator extends LocalFileComparator {
  /// Creates a tolerant comparator for golden file tests.
  ///
  /// [testFile] is the URI of the test file (used to resolve relative golden paths).
  /// [tolerance] is the maximum allowed pixel diff ratio (0.0 = exact, 1.0 = any).
  /// Default is 0.015 (1.5%).
  TolerantGoldenFileComparator(
    super.testFile, {
    this.tolerance = 0.015,
  }) : assert(
          0 <= tolerance && tolerance <= 1,
          'tolerance must be between 0 and 1',
        );

  /// Maximum allowed pixel difference ratio.
  ///
  /// 0.015 = 1.5% of pixels may differ without failing the test.
  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    final bool passed = result.passed || result.diffPercent <= tolerance;
    if (passed) {
      result.dispose();
      return true;
    }

    final String error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(
      'Golden "$golden" differs by ${(result.diffPercent * 100).toStringAsFixed(2)}% '
      '(threshold: ${(tolerance * 100).toStringAsFixed(1)}%).\n$error',
    );
  }
}
