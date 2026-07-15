import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/budget_living_engine.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

CoachProfile _profile() => CoachProfile(
      birthYear: 1985,
      canton: 'VD',
      etatCivil: CoachCivilStatus.marie,
      salaireBrutMensuel: 8000.0,
      nombreDeMois: 13.0,
      bonusPourcentage: 10.0,
      monthlyTaxProvisionDeclared: 900.0,
      conjoint: const ConjointProfile(
        birthYear: 1987,
        salaireBrutMensuel: 5000.0,
        nombreDeMois: 13.5,
        bonusPourcentage: 5.0,
      ),
      depenses: const DepensesProfile(
        loyer: 1800.0,
        assuranceMaladie: 420.0,
        electricite: 90.0,
        autresDepensesFixes: 160.0,
      ),
      dettes: const DetteProfile(mensualiteCreditConso: 350.0),
      patrimoine: const PatrimoineProfile(epargneLiquide: 12000.0),
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2050),
        label: 'Retraite',
      ),
      dataSources: const {
        'depenses.assuranceMaladie': ProfileDataSource.userInput,
      },
    );

void main() {
  test(
      'canonical profile and MintState honour cadence and bonus for the couple',
      () {
    final profile = _profile();
    final expectedOwn = NetIncomeBreakdown.compute(
      grossSalary: 8000.0 * 13.0 * 1.10,
      canton: profile.canton,
      age: profile.age,
    ).monthlyNetPayslip;
    final expectedPartner = NetIncomeBreakdown.compute(
      grossSalary: 5000.0 * 13.5 * 1.05,
      canton: profile.canton,
      age: profile.conjoint!.age!,
    ).monthlyNetPayslip;

    final inputs = BudgetInputs.fromCoachProfile(profile);
    final present = BudgetLivingEngine.compute(profile).present;

    final expectedNet = expectedOwn + expectedPartner;
    expect(inputs.netIncome, closeTo(expectedNet, 0.001));
    expect(present.monthlyNet, closeTo(expectedNet, 0.001));
  });

  test('CoachProfile budget facade cannot diverge from canonical projection',
      () {
    final profile = _profile();

    expect(
      profile.toBudgetInputs().toMap(),
      BudgetInputs.fromCoachProfile(profile).toMap(),
    );
  });

  test('independent annual declared net is canonical for profile and MintState',
      () {
    final profile = CoachProfile(
      birthYear: 1985,
      canton: 'GE',
      salaireBrutMensuel: 0.0,
      employmentStatus: 'independant',
      selfEmployedNetIncome: 120000.0,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2050),
        label: 'Retraite',
      ),
    );
    final inputs = BudgetInputs.fromCoachProfile(profile);
    final present = BudgetLivingEngine.compute(profile).present;

    expect(
      (inputs: inputs.netIncome, mintState: present.monthlyNet),
      const (inputs: 10000.0, mintState: 10000.0),
    );
  });
}
