import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/cross_pillar_calculator.dart';

void main() {
  CoachProfile profile({required DepensesProfile depenses}) {
    return CoachProfile(
      birthYear: 1977,
      canton: 'VS',
      nationality: 'CH',
      salaireBrutMensuel: 122207 / 12,
      nombreDeMois: 12,
      employmentStatus: 'salarie',
      etatCivil: CoachCivilStatus.marie,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2042),
        label: 'Retraite Julien',
      ),
      prevoyance: const PrevoyanceProfile(
        avoirLppTotal: 70377,
        rachatMaximum: 539414,
        tauxConversion: lppTauxConversionMinDecimal,
        totalEpargne3a: 32000,
        canContribute3a: true,
      ),
      patrimoine: const PatrimoineProfile(epargneLiquide: 50000),
      depenses: depenses,
    );
  }

  test('budget reallocation ignores implausible housing', () {
    final result = CrossPillarCalculator.analyze(
      profile: profile(
        depenses: const DepensesProfile(
          loyer: 19272200,
          assuranceMaladie: 420,
        ),
      ),
    );

    final realloc = result.insights
        .where((i) => i.type == CrossPillarType.budgetReallocation)
        .singleOrNull;

    expect(realloc, isNotNull);
    expect(realloc!.details['chargesFixesMensuelles'], 420);
    expect(realloc.details['margeLibreMensuelle'], greaterThan(500));
  });
}
