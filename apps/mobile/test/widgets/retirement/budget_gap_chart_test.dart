import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/retirement_projection_service.dart';
import 'package:mint_mobile/widgets/retirement/budget_gap_chart.dart';

RetirementBudgetGap _gap({required double? replacementRate}) {
  return RetirementBudgetGap(
    totalRevenusMensuel: 5000,
    avsMensuel: 2500,
    lppMensuel: 1500,
    troisAMensuel: 300,
    libreMensuel: 700,
    impotEstimeMensuel: 400,
    depensesMensuelles: 4500,
    soldeMensuel: 100,
    tauxRemplacement: replacementRate,
    alertes: const [],
  );
}

void main() {
  testWidgets('unknown replacement rate is not rendered as zero percent',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BudgetGapChart(budgetGap: _gap(replacementRate: null)),
        ),
      ),
    );

    expect(find.textContaining('Taux de remplacement'), findsNothing);
    expect(find.textContaining('0%'), findsNothing);
  });

  testWidgets('known replacement rate keeps its badge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BudgetGapChart(budgetGap: _gap(replacementRate: 65)),
        ),
      ),
    );

    expect(find.text('Taux de remplacement : 65%'), findsOneWidget);
  });
}
