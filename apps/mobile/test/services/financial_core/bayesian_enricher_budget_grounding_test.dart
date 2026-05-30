import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/bayesian_enricher.dart';

void main() {
  CoachProfile profile({required DepensesProfile depenses}) {
    return CoachProfile(
      birthYear: 1985,
      canton: 'ZH',
      salaireBrutMensuel: 8000,
      employmentStatus: 'salarie',
      depenses: depenses,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2050),
        label: 'Retraite',
      ),
    );
  }

  test('implausible housing does not collapse expense posterior', () {
    final result = BayesianProfileEnricher.enrich(
      profile(
        depenses: const DepensesProfile(
          loyer: 19272200,
          assuranceMaladie: 420,
        ),
      ),
    );

    final estimate = result.estimates['depensesMensuelles']!;

    expect(estimate.mean, 420);
    expect(estimate.isDeclared, isTrue);
    expect(estimate.source, 'posterior:declared+depenses');
  });
}
