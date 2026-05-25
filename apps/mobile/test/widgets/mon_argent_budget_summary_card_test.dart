import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
