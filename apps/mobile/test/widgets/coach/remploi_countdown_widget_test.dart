import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/remploi_countdown_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  // saleDate in the past (2025-06-01), deadline = 2027-06-01
  // As of 2026-03-07: ~279 days elapsed, ~451 days remaining
  // deferredTax = 36000 → "36'000"

  Widget buildWidget() => MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RemploiCountdownWidget(
              saleDate: DateTime(2025, 6, 1),
              deferredTax: 36000,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('remploi'), findsWidgets);
  });

  testWidgets('shows deferred tax amount', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("36'000"), findsWidgets);
  });

  testWidgets('shows days remaining counter', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('jours restants'), findsWidgets);
  });

  testWidgets('shows progress bar', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('shows deadline date', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('2027'), findsWidgets);
  });

  testWidgets('shows LIFD legal reference', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('LIFD'), findsWidgets);
  });

  testWidgets('shows explanation with 2 years', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('2 ans'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsWidgets);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(
      find.bySemanticsLabel(RegExp('remploi', caseSensitive: false)),
      findsOneWidget,
    );
  });
}
