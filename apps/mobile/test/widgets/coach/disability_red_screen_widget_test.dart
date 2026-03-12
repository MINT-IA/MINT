import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/disability_red_screen_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  Widget buildWidget() => const MaterialApp(
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
            child: DisabilityRedScreenWidget(
              monthlyExpenses: 5200,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('filet'), findsWidgets);
  });

  testWidgets('shows salarié vs indépendant columns', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Salarié'), findsOneWidget);
    expect(find.textContaining('Toi'), findsOneWidget);
  });

  testWidgets('shows 0 CHF for indépendant', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('0 CHF'), findsWidgets);
  });

  testWidgets('shows chiffre-choc 14 months', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('14'), findsWidgets);
  });

  testWidgets('shows question about perte de gain', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('perte de gain'), findsWidgets);
  });

  testWidgets('shows answer buttons', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.text('Oui'), findsOneWidget);
    expect(find.text('Non'), findsOneWidget);
  });

  testWidgets('tapping Non shows feedback', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.text('Non'));
    await tester.pump();
    expect(find.textContaining('prioritaire'), findsOneWidget);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('rouge')), findsOneWidget);
  });
}
