import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

void main() {
  // Asset-bundle reads (used by the bundled-font regression below) require
  // the services binding to be initialized.
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

  group('MintTextStyles regression (MVP-GOOGLEFONTS-PURGE-V1)', () {
    // Updated 2026-05-10 — after the GoogleFonts purge, brandLogo and the
    // 20 other legacy helpers (display*, headline*, title*, body*, label*,
    // micro, editorial*) all reference bundled Fontshare families directly
    // (Supreme for sans, Gambarino italic for editorial). The previous
    // assertion (« brandLogo still uses Montserrat ») is obsolete.
    test('brandLogo uses bundled Supreme', () {
      final s = MintTextStyles.brandLogo();
      expect(s.fontFamily, equals('Supreme'));
      expect(s.fontWeight, FontWeight.w800);
      expect(s.letterSpacing, 3);
    });

    test('headlineLarge uses bundled Supreme (was Montserrat)', () {
      final s = MintTextStyles.headlineLarge();
      expect(s.fontFamily, equals('Supreme'));
    });

    test('bodyMedium uses bundled Supreme (was Inter)', () {
      final s = MintTextStyles.bodyMedium();
      expect(s.fontFamily, equals('Supreme'));
    });

    test('editorialDisplay uses bundled Gambarino italic (was Fraunces)', () {
      final s = MintTextStyles.editorialDisplay();
      expect(s.fontFamily, equals('Gambarino'));
      expect(s.fontStyle, FontStyle.italic);
    });
  });
}
