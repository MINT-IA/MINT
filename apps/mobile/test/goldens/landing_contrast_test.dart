// Contraste AAA de la landing — SÉPARÉ DES GOLDENS LE 2026-08-14.
//
// Il vivait dans landing_golden_test.dart. Marquer ce fichier `local-only`
// pour ses comparaisons de PIXELS aurait emporté ces assertions avec lui — et
// une vérification d'accessibilité aurait disparu de la CI en silence, sans
// qu'aucune ligne ne le dise.
//
// Or le contraste ne dépend pas du rendu des polices : c'est une arithmétique
// sur des couleurs. Il n'a aucune raison d'être exclu.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/theme/colors.dart';

void main() {
  group('Landing v2 AAA contrast (≥ 7.0 on craie)', () {
    const bg = MintColors.craie;

    test('textPrimary on craie — paragraphe-mère', () {
      final ratio = _wcagContrastRatio(MintColors.textPrimary, bg);
      expect(ratio, greaterThanOrEqualTo(7.0),
          reason: 'paragraphe-mère must be AAA on craie');
    });

    test('craie on textPrimary — CTA pill inverse', () {
      // CTA is craie foreground on textPrimary background — inverse surface.
      final ratio =
          _wcagContrastRatio(MintColors.craie, MintColors.textPrimary);
      expect(ratio, greaterThanOrEqualTo(7.0),
          reason: 'CTA pill text must be AAA on inverse fill');
    });

    test('textSecondaryAaa on craie — privacy micro-phrase', () {
      final ratio = _wcagContrastRatio(MintColors.textSecondaryAaa, bg);
      expect(ratio, greaterThanOrEqualTo(7.0),
          reason: 'privacy micro-phrase must be AAA on craie');
    });

    test('textMutedAaa on craie — legal footer', () {
      final ratio = _wcagContrastRatio(MintColors.textMutedAaa, bg);
      expect(ratio, greaterThanOrEqualTo(7.0),
          reason: 'legal footer must be AAA on craie');
    });
  });
}

// --- Inline WCAG 2.1 contrast helper -----------------------------------------
//
// Formula: (L1 + 0.05) / (L2 + 0.05) where L1 >= L2, and L is relative
// luminance computed from sRGB channels after gamma decode.
// Reference: https://www.w3.org/TR/WCAG21/#dfn-contrast-ratio

double _wcagContrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

double _relativeLuminance(Color c) {
  final r = _channel(c.r);
  final g = _channel(c.g);
  final bch = _channel(c.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * bch;
}

double _channel(double v) {
  return v <= 0.03928
      ? v / 12.92
      : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}
