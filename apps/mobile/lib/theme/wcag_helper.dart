import 'dart:math' as math;
import 'dart:ui' show Color;

/// Pure-Dart WCAG 2.1 §1.4.6 contrast ratio helper.
///
/// Implements the relative luminance formula from
/// https://www.w3.org/TR/WCAG21/#dfn-relative-luminance and the contrast
/// ratio definition from https://www.w3.org/TR/WCAG21/#dfn-contrast-ratio.
///
/// Used by AAA token unit tests to prove every `*Aaa` token in
/// `MintColors` hits ≥ 7:1 (strict AAA normal text) against every
/// legitimate S0–S5 background. Zero package dependencies.
class WcagHelper {
  const WcagHelper._();

  /// AAA contrast floor for normal text (< 18 pt regular / < 14 pt bold).
  static const double aaaNormalTextFloor = 7.0;

  /// AAA contrast floor for large text (≥ 18 pt regular / ≥ 14 pt bold).
  static const double aaaLargeTextFloor = 4.5;

  /// Returns the WCAG 2.1 relative luminance of [color] in [0.0, 1.0].
  static double relativeLuminance(Color color) {
    final r = _channel(color.r);
    final g = _channel(color.g);
    final b = _channel(color.b);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Returns the WCAG 2.1 contrast ratio between [foreground] and
  /// [background]. Result is in [1.0, 21.0].
  static double contrastRatio(Color foreground, Color background) {
    final l1 = relativeLuminance(foreground);
    final l2 = relativeLuminance(background);
    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  static double _channel(double c) {
    if (c <= 0.03928) return c / 12.92;
    return math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }
}
