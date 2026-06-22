import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/data/budget/budget_local_store.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('round-trips budget quality flags for relaunch', () async {
    final store = BudgetLocalStore();
    const inputs = BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: 8000,
      housingCost: 2200,
      debtPayments: 0,
      taxProvision: 950,
      healthInsurance: 420,
      otherFixedCosts: 0,
      isTaxEstimated: true,
      isHealthEstimated: false,
      isHousingMissing: true,
      isHealthMissing: true,
      isOtherFixedMissing: true,
      emergencyFundMonths: 3,
    );

    await store.saveInputs(inputs);
    final restored = await store.loadInputs();

    expect(restored, isNotNull);
    expect(restored!.isTaxEstimated, isTrue);
    expect(restored.isHealthEstimated, isFalse);
    expect(restored.isHousingMissing, isTrue);
    expect(restored.isHealthMissing, isTrue);
    expect(restored.isOtherFixedMissing, isTrue);
    expect(restored.emergencyFundMonths, 3);
  });

  test('hasAnyData and clear cover custom budget overrides', () async {
    final store = BudgetLocalStore();

    await store.saveOverride('custom', 0.42);

    expect(await store.hasAnyData(), isTrue);

    await store.clear();

    expect(await store.hasAnyData(), isFalse);
    expect(await store.getOverride('custom'), isNull);
  });
}
