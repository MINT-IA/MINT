import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/monte_carlo_service.dart';
import 'package:mint_mobile/services/retirement_projection_service.dart';

void main() {
  CoachProfile profile({required DepensesProfile depenses}) {
    return CoachProfile(
      firstName: 'Budget',
      birthYear: DateTime.now().year - 45,
      canton: 'ZH',
      salaireBrutMensuel: 8000,
      nombreDeMois: 12,
      employmentStatus: 'salarie',
      etatCivil: CoachCivilStatus.celibataire,
      prevoyance: const PrevoyanceProfile(
        avoirLppTotal: 180000,
        totalEpargne3a: 50000,
        nombre3a: 2,
      ),
      patrimoine: const PatrimoineProfile(
        epargneLiquide: 20000,
        investissements: 50000,
      ),
      depenses: depenses,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2046),
        label: 'Retraite',
      ),
    );
  }

  test('retirement projection ignores implausible housing expense', () {
    final invalidHousing = RetirementProjectionService.project(
      profile: profile(
        depenses: const DepensesProfile(
          loyer: 19272200,
          assuranceMaladie: 420,
        ),
      ),
    );
    final plausibleOnly = RetirementProjectionService.project(
      profile: profile(
        depenses: const DepensesProfile(assuranceMaladie: 420),
      ),
    );

    expect(
      invalidHousing.budgetGap.depensesMensuelles,
      plausibleOnly.budgetGap.depensesMensuelles,
    );
    expect(invalidHousing.budgetGap.depensesMensuelles, lessThan(10000));
  });

  test('Monte Carlo projection ignores implausible housing expense', () async {
    final invalidHousing = await MonteCarloProjectionService.simulate(
      profile: profile(
        depenses: const DepensesProfile(
          loyer: 19272200,
          assuranceMaladie: 420,
        ),
      ),
      numSimulations: 80,
      seed: 42,
    );
    final plausibleOnly = await MonteCarloProjectionService.simulate(
      profile: profile(
        depenses: const DepensesProfile(assuranceMaladie: 420),
      ),
      numSimulations: 80,
      seed: 42,
    );

    expect(invalidHousing.ruinProbability, plausibleOnly.ruinProbability);
    expect(invalidHousing.medianAt65, plausibleOnly.medianAt65);
  });
}
