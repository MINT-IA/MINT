import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/coach_narrative_service.dart';

void main() {
  test('system prompt ignores implausible housing for liquidity months', () {
    final profile = CoachProfile(
      firstName: 'Julien',
      birthYear: 1990,
      canton: 'VD',
      salaireBrutMensuel: 7000,
      employmentStatus: 'salarie',
      patrimoine: const PatrimoineProfile(epargneLiquide: 12000),
      depenses: const DepensesProfile(
        loyer: 19272200,
        assuranceMaladie: 420,
      ),
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2055, 12, 31),
        label: 'Retraite',
      ),
    );

    final prompt = CoachNarrativeService.buildSystemPromptForTest(
      profile: profile,
      scoreHistory: [
        {'date': DateTime(2026, 1).toIso8601String(), 'score': 55},
        {'date': DateTime(2026, 2).toIso8601String(), 'score': 58},
        {'date': DateTime(2026, 3).toIso8601String(), 'score': 62},
      ],
    );

    expect(prompt, contains('- Fonds urgence : 28.6 mois'));
    expect(prompt, isNot(contains('19272200')));
    expect(prompt, isNot(contains('- Fonds urgence : 0.0 mois')));
  });
}
