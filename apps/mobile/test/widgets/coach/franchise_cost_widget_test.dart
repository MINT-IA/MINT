import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/franchise_cost_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  final options = [
    const FranchiseOption(
      franchiseAmount: 300,
      monthlyPremiumSavings: 0,
    ),
    const FranchiseOption(
      franchiseAmount: 1500,
      monthlyPremiumSavings: 70,
    ),
    const FranchiseOption(
      franchiseAmount: 2500,
      monthlyPremiumSavings: 130,
    ),
  ];

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
            child: FranchiseCostWidget(
              options: options,
              initialConsultationsPerYear: 3,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('franchise'), findsWidgets);
  });

  testWidgets('shows slider', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('shows franchise amounts', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('300'), findsWidgets);
    expect(find.textContaining("2'500"), findsWidgets);
  });

  testWidgets('shows comparison table headers', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Franchise'), findsWidgets);
    expect(find.textContaining('prime'), findsWidgets);
  });

  testWidgets('shows long illness scenario', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('2 ans'), findsWidgets);
  });

  testWidgets('shows breakeven rule', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('2×'), findsOneWidget);
  });

  testWidgets('shows disclaimer with 30.11 deadline', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('30.11'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('Franchise')), findsOneWidget);
  });
}
