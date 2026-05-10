import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/theme/colors.dart';

void main() {
  group('MintColors Menthe-vive (Phase 92 FONT-02)', () {
    test('mentheVive is Color(0xFF7DD3B5) per STUB pixel-sample', () {
      expect(MintColors.mentheVive, const Color(0xFF7DD3B5));
    });

    test('mentheVive12 is Color(0x1F7DD3B5) — 12% alpha surface tint', () {
      expect(MintColors.mentheVive12, const Color(0x1F7DD3B5));
    });
  });

  group('MintColors dark palette (Phase 92 FONT-04)', () {
    test('darkBg is a non-null const Color', () {
      expect(MintColors.darkBg, isA<Color>());
    });
    test('darkInk is a non-null const Color', () {
      expect(MintColors.darkInk, isA<Color>());
    });
    test('darkInkSoft is a non-null const Color', () {
      expect(MintColors.darkInkSoft, isA<Color>());
    });
    test('darkBorderSubtle is a non-null const Color', () {
      expect(MintColors.darkBorderSubtle, isA<Color>());
    });
    test('darkMentheVive is a non-null const Color (saturated for dark contrast)', () {
      expect(MintColors.darkMentheVive, isA<Color>());
    });
  });

  group('MintColors regression guard (Phase 92 — no upstream edit)', () {
    test('primary still Color(0xFF1D1D1F)', () {
      expect(MintColors.primary, const Color(0xFF1D1D1F));
    });
    test('inkPrimary still Color(0xFF1A1A1A)', () {
      expect(MintColors.inkPrimary, const Color(0xFF1A1A1A));
    });
  });
}
