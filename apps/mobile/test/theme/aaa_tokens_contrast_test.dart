import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/wcag_helper.dart';

/// Contrast matrix test for the 6 AAA tokens added in plan 02-02.
///
/// Every `*Aaa` token in `MintColors` MUST hit strict WCAG 2.1 AAA
/// normal-text contrast (≥ 7:1) against BOTH legitimate S0-S5
/// background surfaces:
///
///   - `#FFFFFF` — `background`, `card`
///   - `#FCFBF8` — `craie` (warm white)
///
/// No `// RESTRICTED: large text only` escape hatch is allowed —
/// the locked spec is strict AAA on every token. If any token
/// fails on any background, this test goes red and the executor
/// must darken in 2-point increments and retest before committing.
void main() {
  const white = Color(0xFFFFFFFF);
  const craie = Color(0xFFFCFBF8);

  const tokens = <String, Color>{
    'textSecondaryAaa': MintColors.textSecondaryAaa,
    'textMutedAaa': MintColors.textMutedAaa,
    'successAaa': MintColors.successAaa,
    'warningAaa': MintColors.warningAaa,
    'errorAaa': MintColors.errorAaa,
    'infoAaa': MintColors.infoAaa,
  };

  const backgrounds = <String, Color>{
    'white #FFFFFF': white,
    'craie #FCFBF8': craie,
  };

  group('AAA tokens — strict ≥ 7:1 contrast matrix', () {
    tokens.forEach((tokenName, tokenColor) {
      backgrounds.forEach((bgName, bgColor) {
        test('$tokenName on $bgName', () {
          final ratio = WcagHelper.contrastRatio(tokenColor, bgColor);
          expect(
            ratio,
            greaterThanOrEqualTo(WcagHelper.aaaNormalTextFloor),
            reason:
                '$tokenName vs $bgName measured ${ratio.toStringAsFixed(2)}:1 '
                '— must be ≥ 7.0:1 (strict AAA normal text). '
                'Darken in 2-point increments per plan 02-02 protocol.',
          );
        });
      });
    });
  });

  group('AAA tokens — exact hex value guard', () {
    test('textSecondaryAaa = #555560 (darkened from REQ #595960)', () {
      // Deviation: REQ-locked #595960 measured 6.95:1 white / 6.71:1
      // craie, failing strict AAA. Iteration 2 of the auto-darkening
      // protocol (#555560) clears both axes (≥ 7.10:1 craie).
      expect(MintColors.textSecondaryAaa.toARGB32(), 0xFF555560);
    });

    test('textMutedAaa = #525256', () {
      expect(MintColors.textMutedAaa.toARGB32(), 0xFF525256);
    });

    test('successAaa = #0F5E28', () {
      expect(MintColors.successAaa.toARGB32(), 0xFF0F5E28);
    });

    test('warningAaa = #8C3F06', () {
      expect(MintColors.warningAaa.toARGB32(), 0xFF8C3F06);
    });

    test('errorAaa = #8B1D1D', () {
      expect(MintColors.errorAaa.toARGB32(), 0xFF8B1D1D);
    });

    test('infoAaa = #004FA3', () {
      expect(MintColors.infoAaa.toARGB32(), 0xFF004FA3);
    });
  });
}
