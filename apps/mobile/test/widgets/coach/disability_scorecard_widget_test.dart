import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/disability_scorecard_widget.dart';

void main() {
  final items = [
    const CoverageItem(
      label: 'APG (perte gain)',
      grade: 'B+',
      detail: '80% pendant 720j max',
      emoji: '🛡️',
    ),
    const CoverageItem(
      label: 'AI (rente)',
      grade: 'C',
      detail: "2'520 CHF max",
    ),
    const CoverageItem(
      label: 'LPP invalidité',
      grade: 'A-',
      detail: '40–70% salaire assuré',
      legalRef: 'LPP art. 23-26',
    ),
    const CoverageItem(
      label: 'Épargne urgence',
      grade: 'D',
      detail: '2 mois de réserve',
    ),
    const CoverageItem(
      label: 'Assurance privée',
      grade: 'F',
      detail: 'Aucune détectée',
    ),
  ];

  Widget buildWidget() => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DisabilityScorecardWidget(
              items: items,
              overallGrade: 'C-',
              lifeDropPercent: 48,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('bulletin'), findsWidgets);
  });

  testWidgets('shows all grade items', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('APG'), findsOneWidget);
    expect(find.textContaining('LPP'), findsWidgets);
  });

  testWidgets('shows grades A-F', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.text('B+'), findsOneWidget);
    expect(find.text('F'), findsOneWidget);
  });

  testWidgets('shows overall grade', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.text('C-'), findsOneWidget);
  });

  testWidgets('shows life drop percent', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('48%'), findsOneWidget);
  });

  testWidgets('shows weakest subject (F = Assurance privée)', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('faible'), findsOneWidget);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('bulletin')), findsOneWidget);
  });
}
