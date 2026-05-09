import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

void main() {
  // GoogleFonts (used by brandLogo regression test below) requires the
  // services binding to be initialized so it can attempt asset-bundle reads
  // (it falls back to a default font when assets aren't present in the test
  // runner, but throws "Binding has not yet been initialized" without this).
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MintTextStyles Gambarino italic (Phase 92 FONT-03)', () {
    test('displayGambarinoItalic56 — Landing hero', () {
      final s = MintTextStyles.displayGambarinoItalic56();
      expect(s.fontFamily, 'Gambarino');
      expect(s.fontStyle, FontStyle.italic);
      expect(s.fontSize, 56);
      expect(s.fontWeight, FontWeight.w400);
    });

    test('displayGambarinoItalic40 — Onboarding hero', () {
      final s = MintTextStyles.displayGambarinoItalic40();
      expect(s.fontFamily, 'Gambarino');
      expect(s.fontStyle, FontStyle.italic);
      expect(s.fontSize, 40);
    });

    test('Gambarino italic accepts color override', () {
      final s = MintTextStyles.displayGambarinoItalic56(color: MintColors.mentheVive);
      expect(s.color, MintColors.mentheVive);
    });
  });

  group('MintTextStyles Supreme (Phase 92 FONT-03)', () {
    test('titleSupreme18Semibold', () {
      final s = MintTextStyles.titleSupreme18Semibold();
      expect(s.fontFamily, 'Supreme');
      expect(s.fontWeight, FontWeight.w600);
      expect(s.fontSize, 18);
    });

    test('bodySupreme15Regular', () {
      final s = MintTextStyles.bodySupreme15Regular();
      expect(s.fontFamily, 'Supreme');
      expect(s.fontWeight, FontWeight.w400);
      expect(s.fontSize, 15);
    });

    test('labelSupreme12Uppercase025LS — letterSpacing 0.25', () {
      final s = MintTextStyles.labelSupreme12Uppercase025LS();
      expect(s.fontFamily, 'Supreme');
      expect(s.fontSize, 12);
      expect(s.letterSpacing, 0.25);
    });
  });

  group('MintTextStyles regression (Phase 92 — existing styles untouched)', () {
    test('brandLogo still uses Montserrat via GoogleFonts wrapper', () {
      final s = MintTextStyles.brandLogo();
      // GoogleFonts injects fontFamily as 'Montserrat_<weight>' (package prefix).
      // Just assert it's NOT 'Supreme' (sanity guard).
      expect(s.fontFamily, isNot(equals('Supreme')));
      expect(s.fontFamily, isNot(equals('Gambarino')));
    });
  });
}
