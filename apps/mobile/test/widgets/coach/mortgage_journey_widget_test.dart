import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/mortgage_journey_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  Widget buildWidget({int currentStep = 0}) => MaterialApp(
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
            child: MortgageJourneyWidget(currentStep: currentStep),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('achat immobilier'), findsWidgets);
  });

  testWidgets('shows step counter', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('1 / 7'), findsWidgets);
  });

  testWidgets('shows step 1 content by default', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Étape 1'), findsWidgets);
    expect(find.textContaining('peux acheter'), findsWidgets);
  });

  testWidgets('shows FINMA reference on step 1', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('FINMA'), findsWidgets);
  });

  testWidgets('shows action box on step 1', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('simulateur'), findsWidgets);
  });

  testWidgets('navigates to step 2 on tap', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.textContaining('suivante'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Étape 2'), findsWidgets);
    expect(find.textContaining('fonds propres'), findsWidgets);
  });

  testWidgets('shows LPP reference on step 2', (tester) async {
    await tester.pumpWidget(buildWidget(currentStep: 1));
    expect(find.textContaining('LPP'), findsWidgets);
  });

  testWidgets('can start on step 4 (amortissement)', (tester) async {
    await tester.pumpWidget(buildWidget(currentStep: 3));
    expect(find.textContaining('Étape 4'), findsWidgets);
    expect(find.textContaining('mortissement'), findsWidgets);
  });

  testWidgets('shows valeur locative on step 5', (tester) async {
    await tester.pumpWidget(buildWidget(currentStep: 4));
    expect(find.textContaining('locative'), findsWidgets);
    expect(find.textContaining('LIFD'), findsWidgets);
  });

  testWidgets('shows completion badge on last step', (tester) async {
    await tester.pumpWidget(buildWidget(currentStep: 6));
    expect(find.textContaining('complet'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsWidgets);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(
      find.bySemanticsLabel(
          RegExp('parcours fléché achat immobilier', caseSensitive: false)),
      findsOneWidget,
    );
  });
}
