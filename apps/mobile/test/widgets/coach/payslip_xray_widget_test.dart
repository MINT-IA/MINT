import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/payslip_xray_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  final lines = [
    const PayslipLine(
      label: 'AVS / AI / APG',
      emoji: '\ud83e\uddf1',
      amount: 291.5,
      percentage: 5.3,
      explanation: 'Rente vieillesse.',
      legalRef: 'LAVS art. 3',
    ),
    const PayslipLine(
      label: 'LPP',
      emoji: '\ud83c\udfe6',
      amount: 193.0,
      percentage: 3.5,
      explanation: '2e pilier.',
      legalRef: 'LPP art. 14',
    ),
    const PayslipLine(
      label: 'AC',
      emoji: '\ud83e\ude82',
      amount: 60.5,
      percentage: 1.1,
      explanation: 'Assurance-ch\u00f4mage.',
      legalRef: 'LACI art. 3',
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
          body: PayslipXRayWidget(
            grossSalary: 5500,
            netSalary: 4210,
            deductions: lines,
            employerHiddenCost: 654,
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Radiographie'), findsOneWidget);
  });

  testWidgets('shows gross and net amounts', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('5'), findsWidgets); // 5500
    expect(find.textContaining('4'), findsWidgets); // 4210
  });

  testWidgets('shows deduction labels', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('AVS'), findsOneWidget);
    expect(find.textContaining('LPP'), findsOneWidget);
  });

  testWidgets('shows employer hidden cost section', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('employeur'), findsWidgets);
  });

  testWidgets('tap expands a deduction line', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.textContaining('AVS').first);
    await tester.pump();
    expect(find.textContaining('Rente'), findsOneWidget);
  });

  testWidgets('shows legal ref on expanded line', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.textContaining('AVS').first);
    await tester.pump();
    expect(find.textContaining('LAVS'), findsOneWidget);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('Radiographie')), findsOneWidget);
  });
}
