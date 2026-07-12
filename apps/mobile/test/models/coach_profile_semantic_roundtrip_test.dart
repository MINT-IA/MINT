import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';

void main() {
  test('legacy household and employment aliases serialize canonically', () {
    final profile = CoachProfile.fromWizardAnswers({
      'q_birth_year': 1985,
      'q_civil_status': 'married',
      'q_employment_status': 'self_employed',
      'q_self_employed_income': 90000,
    });

    expect(profile.etatCivil, CoachCivilStatus.marie);
    expect(profile.employmentStatus, 'independant');

    final json = profile.toJson();
    expect(json['etatCivil'], 'marie');
    expect(json['employmentStatus'], 'self_employed');

    final restored = CoachProfile.fromJson(json);
    expect(restored.etatCivil, CoachCivilStatus.marie);
    expect(restored.employmentStatus, 'independant');
  });

  test('explicit unemployed never falls back to employee', () {
    for (final alias in ['unemployed', 'chomage', 'chômage']) {
      final profile = CoachProfile.fromWizardAnswers({
        'q_birth_year': 1985,
        'q_employment_status': alias,
      });
      expect(profile.employmentStatus, 'chomage', reason: alias);
      expect(profile.toJson()['employmentStatus'], 'unemployed');
    }
  });
}
