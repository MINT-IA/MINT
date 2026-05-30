import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/fri_computation_service.dart';

void main() {
  ProjectionResult projection() {
    const scenario = ProjectionScenario(
      label: 'Base',
      points: [],
      capitalFinal: 500000,
      revenuAnnuelRetraite: 50000,
      decomposition: {'avs': 30000, 'lpp': 20000},
    );
    return const ProjectionResult(
      prudent: scenario,
      base: scenario,
      optimiste: scenario,
      tauxRemplacementBase: 0.6,
      milestones: [],
      disclaimer: 'test',
      sources: [],
    );
  }

  CoachProfile profile({required DepensesProfile depenses}) {
    return CoachProfile(
      birthYear: 1977,
      canton: 'VS',
      salaireBrutMensuel: 10000,
      employmentStatus: 'salarie',
      patrimoine: const PatrimoineProfile(
        epargneLiquide: 50000,
        investissements: 100000,
      ),
      depenses: depenses,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2042),
        label: 'Retraite',
      ),
    );
  }

  test('implausible housing does not crush liquidity axis', () {
    final invalidHousing = FriComputationService.compute(
      profile: profile(
        depenses: const DepensesProfile(
          loyer: 19272200,
          assuranceMaladie: 420,
          transport: 200,
        ),
      ),
      projection: projection(),
    );
    final plausibleOnly = FriComputationService.compute(
      profile: profile(
        depenses: const DepensesProfile(
          assuranceMaladie: 420,
          transport: 200,
        ),
      ),
      projection: projection(),
    );

    expect(
      invalidHousing.liquidite,
      plausibleOnly.liquidite,
      reason:
          'FRI must ignore impossible expense components before scoring liquidity',
    );
  });
}
