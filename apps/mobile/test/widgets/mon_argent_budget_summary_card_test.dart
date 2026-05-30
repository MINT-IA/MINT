import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/budget_plan.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/widgets/mon_argent/budget_summary_card.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('renders a stable budget flow visual', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const BudgetSummaryCard(
          snapshot: BudgetSnapshot(
            present: PresentBudget(
              monthlyNet: 8000,
              monthlyCharges: 5200,
              monthlySavings: 700,
              monthlyFree: 2100,
            ),
            capImpacts: [],
            stage: BudgetStage.presentOnly,
            confidenceScore: 64,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      tester
          .getSemantics(find.byKey(const Key('mon_argent_budget_flow_bar')))
          .identifier,
      'mon_argent_budget_flow_bar',
    );
  });

  testWidgets('prefers canonical snapshot over provider plan duplicates',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const BudgetSummaryCard(
          snapshot: BudgetSnapshot(
            present: PresentBudget(
              monthlyNet: 8000,
              monthlyCharges: 5200,
              monthlySavings: 700,
              monthlyFree: 2100,
            ),
            capImpacts: [],
            stage: BudgetStage.presentOnly,
            confidenceScore: 64,
          ),
          inputs: BudgetInputs(
            payFrequency: PayFrequency.monthly,
            netIncome: 5379,
            housingCost: 2200,
            debtPayments: 0,
            taxProvision: 520,
            healthInsurance: 420,
            style: BudgetStyle.envelopes3,
          ),
          plan: BudgetPlan(
            available: 2239,
            variables: 2239,
            future: 0,
            stopRuleTriggered: false,
            emergencyFundMonths: 0,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text("8'000\u00a0CHF"), findsOneWidget);
    expect(find.text("5'900\u00a0CHF"), findsOneWidget);
    expect(find.text("2'100\u00a0CHF"), findsOneWidget);
    expect(find.text("5'379\u00a0CHF"), findsNothing);
    expect(find.text("3'140\u00a0CHF"), findsNothing);
    expect(find.text("2'239\u00a0CHF"), findsNothing);
  });
}
