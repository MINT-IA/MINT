import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/avs_gap_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  Widget buildWidget() => const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: AvsGapWidget(
              currentContributionYears: 30,
              currentAge: 50,
              initialYearsAbroad: 5,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('AVS'), findsWidgets);
  });

  testWidgets('shows trou AVS label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('trou'), findsWidgets);
  });

  testWidgets('shows slider', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('shows years abroad label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('5 ans'), findsWidgets);
  });

  testWidgets('shows rente amounts', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('CHF'), findsWidgets);
  });

  testWidgets('shows LAVS legal reference', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('LAVS'), findsWidgets);
  });

  testWidgets('shows lifetime loss section', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('20 ans'), findsWidgets);
  });

  testWidgets('annual loss uses 12 months and excludes December supplement',
      (tester) async {
    await tester.pumpWidget(buildWidget());

    expect(find.textContaining('× 12 mois'), findsOneWidget);
    expect(
      find.textContaining('supplément AVS de décembre'),
      findsOneWidget,
    );
    expect(find.textContaining('n’est pas inclus'), findsOneWidget);
    expect(find.textContaining('× 13'), findsNothing);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsWidgets);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(
      find.bySemanticsLabel(RegExp('trou AVS', caseSensitive: false)),
      findsOneWidget,
    );
  });

  test('avsGapCalculation stays ×12 in all six ARB locales', () {
    const arbPaths = <String>[
      'lib/l10n/app_fr.arb',
      'lib/l10n/app_en.arb',
      'lib/l10n/app_de.arb',
      'lib/l10n/app_es.arb',
      'lib/l10n/app_it.arb',
      'lib/l10n/app_pt.arb',
    ];
    final decemberTerms = RegExp(
      r'décembre|december|dezember|diciembre|dicembre|dezembro',
      caseSensitive: false,
    );
    final legacyAnnualization = RegExp(
      r'×\s*13|13\s*(mois|months|monate|meses|mesi)',
      caseSensitive: false,
    );

    for (final path in arbPaths) {
      final arb =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      final calculation = arb['avsGapCalculation'] as String;

      expect(calculation, contains('12'), reason: path);
      expect(calculation, isNot(contains(legacyAnnualization)), reason: path);
      expect(calculation, contains(decemberTerms), reason: path);
      expect(
        RegExp(r's[eé]par').hasMatch(calculation.toLowerCase()),
        isTrue,
        reason: path,
      );
    }
  });
}
