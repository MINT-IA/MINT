import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/theme/wcag_helper.dart';

/// Unit tests for the pure-Dart WCAG 2.1 contrast helper.
///
/// Reference values are taken from the W3C WCAG 2.1 spec
/// (https://www.w3.org/TR/WCAG21/#dfn-contrast-ratio) and from
/// the WebAIM contrast checker (https://webaim.org/resources/contrastchecker/).
void main() {
  group('WcagHelper.relativeLuminance', () {
    test('pure white = 1.0', () {
      expect(
        WcagHelper.relativeLuminance(const Color(0xFFFFFFFF)),
        closeTo(1.0, 1e-6),
      );
    });

    test('pure black = 0.0', () {
      expect(
        WcagHelper.relativeLuminance(const Color(0xFF000000)),
        closeTo(0.0, 1e-6),
      );
    });

    test('mid-grey 0x808080 ≈ 0.2159', () {
      expect(
        WcagHelper.relativeLuminance(const Color(0xFF808080)),
        closeTo(0.2159, 1e-3),
      );
    });
  });

  group('WcagHelper.contrastRatio', () {
    test('white on black = 21:1', () {
      expect(
        WcagHelper.contrastRatio(
          const Color(0xFFFFFFFF),
          const Color(0xFF000000),
        ),
        closeTo(21.0, 1e-3),
      );
    });

    test('black on white = 21:1 (symmetric)', () {
      expect(
        WcagHelper.contrastRatio(
          const Color(0xFF000000),
          const Color(0xFFFFFFFF),
        ),
        closeTo(21.0, 1e-3),
      );
    });

    test('same color = 1:1', () {
      expect(
        WcagHelper.contrastRatio(
          const Color(0xFF595960),
          const Color(0xFF595960),
        ),
        closeTo(1.0, 1e-6),
      );
    });

    test('#777 on white ≈ 4.48:1 (WebAIM reference)', () {
      // 0x777777 vs white is the canonical "AA borderline" pair.
      expect(
        WcagHelper.contrastRatio(
          const Color(0xFF777777),
          const Color(0xFFFFFFFF),
        ),
        closeTo(4.48, 0.05),
      );
    });

    test('#595959 on white ≈ 7.0:1 (AAA threshold reference)', () {
      // 0x595959 vs white is the canonical "exact AAA normal text"
      // reference pair from WebAIM.
      expect(
        WcagHelper.contrastRatio(
          const Color(0xFF595959),
          const Color(0xFFFFFFFF),
        ),
        closeTo(7.0, 0.05),
      );
    });
  });

  group('WcagHelper constants', () {
    test('AAA normal text floor = 7.0', () {
      expect(WcagHelper.aaaNormalTextFloor, 7.0);
    });

    test('AAA large text floor = 4.5', () {
      expect(WcagHelper.aaaLargeTextFloor, 4.5);
    });
  });
}
