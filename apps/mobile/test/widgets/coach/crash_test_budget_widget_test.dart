import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/crash_test_budget_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  final lines = [
    const BudgetLine(
      label: 'Loyer',
      emoji: '🏠',
      normalAmount: 2100,
      survivalAmount: 2100,
      status: BudgetLineStatus.locked,
    ),
    const BudgetLine(
      label: 'Pilier 3a',
      emoji: '🏦',
      normalAmount: 605,
      survivalAmount: 0,
      status: BudgetLineStatus.paused,
    ),
    const BudgetLine(
      label: 'Loisirs',
      emoji: '🎭',
      normalAmount: 500,
      survivalAmount: 100,
      status: BudgetLineStatus.cut,
    ),
  ];

  Widget buildWidget({double? reserveMonths}) => MaterialApp(
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
            child: CrashTestBudgetWidget(
              monthlyIncome: 6000,
              survivalIncome: 4200,
              lines: lines,
              reserveMonths: reserveMonths,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Crash-test'), findsOneWidget);
  });

  testWidgets('shows survie label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('survie'), findsWidgets);
  });

  testWidgets('shows column headers', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Survie'), findsOneWidget);
  });

  testWidgets('shows locked line', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Loyer'), findsOneWidget);
  });

  testWidgets('shows paused and cut lines', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('3a'), findsOneWidget);
    expect(find.textContaining('Loisirs'), findsOneWidget);
  });

  testWidgets('shows TOTAL row', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('TOTAL'), findsOneWidget);
  });

  testWidgets('shows margin row', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Marge'), findsOneWidget);
  });

  testWidgets('shows reserve panel when provided', (tester) async {
    await tester.pumpWidget(buildWidget(reserveMonths: 4.5));
    expect(find.textContaining('4.5'), findsOneWidget);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('Crash-test')), findsOneWidget);
  });
}
