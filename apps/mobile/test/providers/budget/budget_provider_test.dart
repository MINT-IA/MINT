import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/data/budget/budget_local_store.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('hydrates from storage when no profile is available', () async {
    await BudgetLocalStore().saveInputs(_storedBudgetInputs);

    final provider = BudgetProvider();

    await provider.hydrateFromProfileState(
      profile: null,
      isPartialProfile: false,
    );

    expect(provider.inputs, isNotNull);
    expect(provider.inputs!.netIncome, 8000);
    expect(provider.inputs!.housingCost, 2200);
    expect(provider.inputs!.healthInsurance, 420);
    expect(provider.source, BudgetDataSource.storage);
    expect(provider.hasFreshInputs, isFalse);
  });

  test('keeps stored budget when profile is partial', () async {
    await BudgetLocalStore().saveInputs(_storedBudgetInputs);

    final provider = BudgetProvider();

    await provider.hydrateFromProfileState(
      profile: _profileWithBudget(housingCost: 1100, healthInsurance: 390),
      isPartialProfile: true,
    );

    expect(provider.inputs, isNotNull);
    expect(provider.inputs!.netIncome, 8000);
    expect(provider.inputs!.housingCost, 2200);
    expect(provider.inputs!.healthInsurance, 420);
    expect(provider.source, BudgetDataSource.storage);
    expect(provider.hasFreshInputs, isFalse);
  });

  test('full profile replaces profile-derived cache and clears fallback cache',
      () async {
    final profile = _profileWithBudget(housingCost: 1100, healthInsurance: 390);
    await BudgetLocalStore().saveInputs(
      BudgetInputs.fromCoachProfile(profile),
      origin: StoredBudgetInputsOrigin.profileDerived,
    );

    final provider = BudgetProvider();

    await provider.hydrateFromProfileState(
      profile: profile,
      isPartialProfile: false,
    );

    expect(provider.inputs, isNotNull);
    expect(provider.inputs!.housingCost, 1100);
    expect(provider.inputs!.healthInsurance, 390);
    expect(provider.inputs!.netIncome, isNot(8000));
    expect(provider.source, BudgetDataSource.profile);
    expect(provider.hasFreshInputs, isTrue);
    expect(await BudgetLocalStore().loadInputs(), isNull);
  });

  test('full profile leaves direct-input fallback cache intact', () async {
    await BudgetLocalStore().saveInputs(_storedBudgetInputs);

    final provider = BudgetProvider();

    await provider.hydrateFromProfileState(
      profile: _profileWithBudget(housingCost: 1100, healthInsurance: 390),
      isPartialProfile: false,
    );

    final stored = await BudgetLocalStore().loadInputs();
    expect(provider.source, BudgetDataSource.profile);
    expect(stored, isNotNull);
    expect(stored!.netIncome, 8000);
    expect(stored.housingCost, 2200);
    expect(await BudgetLocalStore().loadInputsOrigin(),
        StoredBudgetInputsOrigin.directInput);
  });

  test('full profile keeps direct-input cache even when values match',
      () async {
    final profile = _profileWithBudget(housingCost: 1100, healthInsurance: 390);
    final matchingDirectInputs = BudgetInputs.fromCoachProfile(profile);
    await BudgetLocalStore().saveInputs(matchingDirectInputs);

    final provider = BudgetProvider();

    await provider.hydrateFromProfileState(
      profile: profile,
      isPartialProfile: false,
    );

    final stored = await BudgetLocalStore().loadInputs();
    expect(provider.source, BudgetDataSource.profile);
    expect(stored, isNotNull);
    expect(stored!.housingCost, matchingDirectInputs.housingCost);
    expect(await BudgetLocalStore().loadInputsOrigin(),
        StoredBudgetInputsOrigin.directInput);
  });

  test('full profile does not persist phantom default expenses', () async {
    final profile = CoachProfile.fromWizardAnswers({
      'q_birth_year': 1988,
      'q_canton': 'VD',
      'q_net_income_period_chf': 6000,
      'q_pay_frequency': 'monthly',
    });
    final provider = BudgetProvider();

    await provider.hydrateFromProfileState(
      profile: profile,
      isPartialProfile: false,
    );

    expect(profile.depenses.loyer, 1500);
    expect(profile.dataSources.containsKey('depenses.loyer'), isFalse);
    expect(provider.inputs, isNotNull);
    expect(provider.inputs!.housingCost, 0);
    expect(provider.inputs!.healthInsurance, 0);
    expect(provider.source, BudgetDataSource.profile);
    expect(provider.hasFreshInputs, isFalse);
  });

  test('setInputs marks direct inputs as fresh', () async {
    final provider = BudgetProvider();

    await provider.setInputs(_storedBudgetInputs);

    expect(provider.inputs, isNotNull);
    expect(provider.source, BudgetDataSource.directInput);
    expect(provider.hasFreshInputs, isTrue);
  });

  test('clear resets source freshness', () async {
    final provider = BudgetProvider();

    await provider.setInputs(_storedBudgetInputs);
    await provider.clear();

    expect(provider.inputs, isNull);
    expect(provider.source, BudgetDataSource.none);
    expect(provider.hasFreshInputs, isFalse);
  });
}

const _storedBudgetInputs = BudgetInputs(
  payFrequency: PayFrequency.monthly,
  netIncome: 8000,
  housingCost: 2200,
  debtPayments: 0,
  taxProvision: 950,
  healthInsurance: 420,
);

CoachProfile _profileWithBudget({
  required double housingCost,
  required double healthInsurance,
}) {
  return CoachProfile(
    birthYear: 1988,
    canton: 'VD',
    salaireBrutMensuel: 6000,
    depenses: DepensesProfile(
      loyer: housingCost,
      assuranceMaladie: healthInsurance,
    ),
    dataSources: const {
      'depenses.loyer': ProfileDataSource.userInput,
      'depenses.assuranceMaladie': ProfileDataSource.userInput,
    },
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2055),
      label: 'Retraite',
    ),
  );
}
