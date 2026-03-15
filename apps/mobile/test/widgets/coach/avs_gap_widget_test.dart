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
}
