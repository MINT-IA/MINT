import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';

Widget _wrap() {
  return const MaterialApp(
    locale: Locale('fr'),
    localizationsDelegates: [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    home: OnboardingShellScreen(),
  );
}

Future<void> _openAxes(WidgetTester tester) async {
  await tester.pumpWidget(_wrap());
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('onboarding-entry-open')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    FeatureFlags.enableMint2FirstExperienceEntry = true;
  });

  tearDown(() {
    FeatureFlags.enableMint2FirstExperienceEntry = false;
  });

  test('onboarding Mint 2 signal axes do not call RvC calculators', () {
    final roots = <Directory>[
      Directory('lib/screens/onboarding/mvp_wedge'),
      Directory('lib/models'),
    ];
    final hits = <String>[];

    for (final root in roots) {
      if (!root.existsSync()) continue;
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.contains('ArbitrageEngine.compareRenteVsCapital') ||
              line.contains('ApiService.compareRenteVsCapital') ||
              RegExp(r'(^|[^A-Za-z0-9_])computeRenteVsCapital\(')
                  .hasMatch(line)) {
            hits.add('${entity.path}:${i + 1}: $line');
          }
        }
      }
    }

    expect(
      hits,
      isEmpty,
      reason: 'Slice 2C signal axes may save intent, not calculate RvC.',
    );
  });

  testWidgets('housing and fiscal axes stay signal-only after tap',
      (tester) async {
    await _openAxes(tester);

    const labels = [
      'Logement : 2e / 3e pilier',
      '3a et rachats : impact fiscal',
    ];
    for (var index = 0; index < labels.length; index++) {
      final label = labels[index];
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();

      expect(find.text('Choisis le sujet que tu veux éclairer d\'abord.'),
          findsOneWidget);
      expect(find.text(label), findsWidgets);
      expect(find.text('Intérêt enregistré'), findsNWidgets(index + 1));
      expect(find.textContaining('/mois'), findsNothing);
      expect(find.textContaining('CHF'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
