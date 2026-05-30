import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/screens/coach/coach_chat_screen.dart';

void main() {
  CoachProfile profile({required DepensesProfile depenses}) {
    return CoachProfile(
      birthYear: 1985,
      canton: 'ZH',
      salaireBrutMensuel: 8000,
      nombreDeMois: 12,
      patrimoine: const PatrimoineProfile(epargneLiquide: 12000),
      depenses: depenses,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2050),
        label: 'Retraite',
      ),
    );
  }

  test('coach context liquidity months ignore implausible housing', () {
    final invalidHousing = coachContextMonthsLiquidity(
      profile(
        depenses: const DepensesProfile(
          loyer: 19272200,
          assuranceMaladie: 420,
        ),
      ),
    );
    final plausibleOnly = coachContextMonthsLiquidity(
      profile(
        depenses: const DepensesProfile(assuranceMaladie: 420),
      ),
    );

    expect(invalidHousing, plausibleOnly);
    expect(invalidHousing, closeTo(28.5714, 0.0001));
  });
}
