// Plan 93-03 (COMP-03 / CLAUDE.md règle 9):
// Verify DivorceSimulatorScreen renders MintTrameConfiance.inline as a
// SIBLING after MintResultHeroCard once the user has triggered the
// simulation. Source MUST be a getter / factory, not hardcoded inline.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/divorce_simulator_screen.dart';
import 'package:mint_mobile/widgets/premium/mint_result_hero_card.dart';
import 'package:mint_mobile/widgets/trust/mint_trame_confiance.dart';

Widget _buildScreen() {
  return ChangeNotifierProvider<CoachProfileProvider>(
    create: (_) => CoachProfileProvider(),
    child: const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: DivorceSimulatorScreen(),
    ),
  );
}

void main() {
  group('DivorceSimulatorScreen — Plan 93-03 confidence trame', () {
    testWidgets(
        'after simulation: trame mounted as SIBLING after MintResultHeroCard',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Pre-simulation: intro card shown, no hero card yet → no trame.
      expect(find.byType(MintResultHeroCard), findsNothing);
      expect(find.byType(MintTrameConfiance), findsNothing);

      // Scroll the simulate button into view, then tap it.
      // (The screen is in a SingleChildScrollView — the button is below the
      // fold of the test viewport.)
      final simulateButton = find.byType(FilledButton).first;
      await tester.ensureVisible(simulateButton);
      await tester.pumpAndSettle();
      await tester.tap(simulateButton);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Hero card + trame are both mounted exactly once.
      expect(find.byType(MintResultHeroCard), findsOneWidget);
      expect(find.byType(MintTrameConfiance), findsOneWidget);

      // Sibling-mount: the trame is NOT a descendant of MintResultHeroCard.
      // (MintResultHeroCard's public API stays unchanged — no slot prop.)
      final descendantInsideHero = find.descendant(
        of: find.byType(MintResultHeroCard),
        matching: find.byType(MintTrameConfiance),
      );
      expect(
        descendantInsideHero,
        findsNothing,
        reason:
            'MintTrameConfiance must be a SIBLING of MintResultHeroCard, not '
            'inside it (MintResultHeroCard public API unchanged).',
      );
    });

    test('source binding: confidence is NOT a hardcoded inline construction',
        () {
      final source = File(
        'lib/screens/divorce_simulator_screen.dart',
      ).readAsStringSync();

      expect(
        RegExp(r'MintTrameConfiance\.inline\(').hasMatch(source),
        isTrue,
        reason: 'divorce must mount MintTrameConfiance.inline',
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

    test('MintResultHeroCard public constructor signature unchanged', () {
      // Surgical-mount audit (Karpathy practice 3): we did not extend
      // MintResultHeroCard. Its 8 named params remain the only public surface.
      final source = File(
        'lib/widgets/premium/mint_result_hero_card.dart',
      ).readAsStringSync();

      // No confidenceSlot / child slot was added.
      expect(
        RegExp(r'\bconfidenceSlot\b').hasMatch(source),
        isFalse,
        reason:
            'No confidenceSlot was added to MintResultHeroCard — divorce trame '
            'is mounted as SIBLING (Plan 93-03 surgical-mount strategy).',
      );
    });
  });

  group(
    'DivorceSimulatorScreen — golden [local-only]',
    () {
      testWidgets('matches divorce_with_confidence_badge.png', (tester) async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await tester.tap(find.byType(FilledButton).first);
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await expectLater(
          find.byType(MintTrameConfiance),
          matchesGoldenFile('goldens/divorce_with_confidence_badge.png'),
        );
      });
    },
    skip: 'local-only — Flutter pixel goldens unstable across CI font rendering',
  );
}
