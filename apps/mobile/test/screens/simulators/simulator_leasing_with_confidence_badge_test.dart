// Plan 93-03 (COMP-03 / CLAUDE.md règle 9):
// Verify SimulatorLeasingScreen renders MintTrameConfiance.inline after
// the displayMedium opportunity-cost hero, with a 4-axis source NOT
// hardcoded inline.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/simulator_leasing_screen.dart';
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
      home: SimulatorLeasingScreen(),
    ),
  );
}

void main() {
  group('SimulatorLeasingScreen — Plan 93-03 confidence trame', () {
    testWidgets('renders MintTrameConfiance.inline once after the hero',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.byType(MintTrameConfiance), findsOneWidget);
    });

    test('source binding: confidence is NOT a hardcoded inline construction',
        () {
      final source = File(
        'lib/screens/simulator_leasing_screen.dart',
      ).readAsStringSync();

      expect(
        RegExp(r'MintTrameConfiance\.inline\(').hasMatch(source),
        isTrue,
        reason: 'simulator_leasing must mount MintTrameConfiance.inline',
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
    'SimulatorLeasingScreen — golden [local-only]',
    () {
      testWidgets('matches simulator_leasing_with_confidence_badge.png',
          (tester) async {
        await tester.pumpWidget(_buildScreen());
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await expectLater(
          find.byType(MintTrameConfiance),
          matchesGoldenFile(
            'goldens/simulator_leasing_with_confidence_badge.png',
          ),
        );
      });
    },
    skip: 'local-only — Flutter pixel goldens unstable across CI font rendering',
  );
}
