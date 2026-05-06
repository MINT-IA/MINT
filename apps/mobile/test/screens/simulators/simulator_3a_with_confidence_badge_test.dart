// Plan 93-03 (COMP-03 / CLAUDE.md règle 9):
// Verify Simulator3aScreen renders MintTrameConfiance.inline after the
// hero CHF figure, with a 4-axis source NOT hardcoded inline.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/screens/simulator_3a_screen.dart';
import 'package:mint_mobile/widgets/trust/mint_trame_confiance.dart';

Widget _buildScreen() {
  final profileProvider = ProfileProvider();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
      ChangeNotifierProvider<CoachProfileProvider>(
        create: (_) => CoachProfileProvider(),
      ),
    ],
    child: const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: Simulator3aScreen(),
    ),
  );
}

void main() {
  group('Simulator3aScreen — Plan 93-03 confidence trame', () {
    testWidgets('renders MintTrameConfiance.inline once after the hero',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Trame is mounted exactly once in the result section.
      expect(find.byType(MintTrameConfiance), findsOneWidget);
    });

    test('source binding: confidence is NOT a hardcoded inline construction',
        () {
      // Read screen source and assert the trame's `confidence:` argument
      // is bound to a getter / factory call, NOT a literal
      // EnhancedConfidence(completeness: ..., accuracy: ..., ...) inline.
      final source = File(
        'lib/screens/simulator_3a_screen.dart',
      ).readAsStringSync();

      // Must contain at least one MintTrameConfiance.inline mount.
      expect(
        RegExp(r'MintTrameConfiance\.inline\(').hasMatch(source),
        isTrue,
        reason: 'simulator_3a must mount MintTrameConfiance.inline',
      );

      // Must NOT match a literal inline EnhancedConfidence(completeness: …
      // construction handed directly into MintTrameConfiance.inline.
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

  // Image-diff golden tests are skipped on CI (matches existing
  // mtc_golden_test.dart policy — Flutter pixel goldens aren't stable across
  // macOS-dev / Linux-CI font rendering boundary). Regenerate baselines
  // locally with:
  //   cd apps/mobile && flutter test --update-goldens \
  //     test/screens/simulators/simulator_3a_with_confidence_badge_test.dart
  // Then flip `skip:` to `false` for a one-shot local visual review.
  group(
    'Simulator3aScreen — golden [local-only]',
    () {
      testWidgets('matches simulator_3a_with_confidence_badge.png',
          (tester) async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await expectLater(
          find.byType(MintTrameConfiance),
          matchesGoldenFile('goldens/simulator_3a_with_confidence_badge.png'),
        );
      });
    },
    skip: 'local-only — Flutter pixel goldens unstable across CI font rendering',
  );
}
