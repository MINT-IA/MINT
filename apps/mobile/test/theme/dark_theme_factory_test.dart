import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart' show buildDarkTheme;
import 'package:mint_mobile/theme/colors.dart';

void main() {
  group('ThemeData.dark factory (Phase 92 FONT-04)', () {
    test('buildDarkTheme returns ThemeData with brightness dark', () {
      final theme = buildDarkTheme();
      expect(theme.brightness, Brightness.dark);
    });

    test('buildDarkTheme scaffoldBackgroundColor is MintColors.darkBg', () {
      final theme = buildDarkTheme();
      expect(theme.scaffoldBackgroundColor, MintColors.darkBg);
    });

    test('buildDarkTheme colorScheme uses dark tokens', () {
      final theme = buildDarkTheme();
      expect(theme.colorScheme.brightness, Brightness.dark);
      // onSurface in dark mode should be the dark ink (warm off-white)
      expect(theme.colorScheme.onSurface, MintColors.darkInk);
    });
  });
}
