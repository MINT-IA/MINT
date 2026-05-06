// Plan 93-03 (COMP-03 / CLAUDE.md règle 9):
// Verify FrontalierScreen (Tab 1 — Impôts) renders MintTrameConfiance.inline
// at the end of the result column, with a 4-axis source NOT hardcoded inline.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/frontalier_screen.dart';
import 'package:mint_mobile/widgets/trust/mint_trame_confiance.dart';

Widget _buildScreen() {
  return const MaterialApp(
    locale: Locale('fr'),
    localizationsDelegates: [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    home: FrontalierScreen(),
  );
}

void main() {
  group('FrontalierScreen — Plan 93-03 confidence trame', () {
    testWidgets(
        'renders MintTrameConfiance.inline once at end of tax result column',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Tab 1 (Impôts) is the default — _recalculateTax() ran in initState,
      // so the tax result card with the trame is already mounted.
      expect(find.byType(MintTrameConfiance), findsOneWidget);
    });

    test('source binding: confidence is NOT a hardcoded inline construction',
        () {
      final source = File(
        'lib/screens/frontalier_screen.dart',
      ).readAsStringSync();

      expect(
        RegExp(r'MintTrameConfiance\.inline\(').hasMatch(source),
        isTrue,
        reason: 'frontalier must mount MintTrameConfiance.inline',
      );

      final hardcoded = RegExp(
        r'MintTrameConfiance\.inline\(\s*confidence:\s*EnhancedConfidence\(\s*completeness:',
      );
      expect(
        hardcoded.hasMatch(source),
        isFalse,
        reason:
            'CLAUDE.md règle 9: confidence MUST be bound to a getter / factory, '
            'not a hardcoded EnhancedConfidence(completeness: …) literal.',
      );
    });
  });

  group(
    'FrontalierScreen — golden [local-only]',
    () {
      testWidgets('matches frontalier_with_confidence_badge.png',
          (tester) async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await expectLater(
          find.byType(MintTrameConfiance),
          matchesGoldenFile('goldens/frontalier_with_confidence_badge.png'),
        );
      });
    },
    skip: 'local-only — Flutter pixel goldens unstable across CI font rendering',
  );
}
