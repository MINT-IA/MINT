import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/data/budget/budget_local_store.dart';
import 'package:mint_mobile/screens/debug/debug_budget_bootstrap_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('persists direct budget inputs for Maestro runtime fixtures',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DebugBudgetBootstrapScreen(
          netIncome: 4500,
          housingCost: 3900,
          healthInsurance: 600,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('e2e_budget_fixture_applied')), findsOne);
    expect(find.textContaining('applied'), findsOne);

    final stored = await BudgetLocalStore().loadInputs();
    expect(stored, isNotNull);
    expect(stored!.netIncome, 4500);
    expect(stored.housingCost, 3900);
    expect(stored.healthInsurance, 600);
    expect(stored.otherFixedCosts, 0);
    expect(await BudgetLocalStore().loadInputsOrigin(),
        StoredBudgetInputsOrigin.directInput);
  });
}
