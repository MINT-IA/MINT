import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';

void main() {
  test('ready cross-border evidence cannot fabricate 3a eligibility', () {
    final now = DateTime.utc(2026, 7, 17, 12);
    Map<String, Object?> provenance() => <String, Object?>{
          'source': ProfileDataSource.userInput.name,
          'updatedAt': now.toIso8601String(),
          'sourceDate': null,
        };
    final profile = CoachProfile.fromWizardAnswers(<String, dynamic>{
      'q_birth_year': 1985,
      'q_gross_salary_annual': 120000,
      'q_residence_country': 'FR',
      'q_work_country': 'CH',
      'q_work_canton': 'GE',
      '__provenance': <String, Object?>{
        'residenceCountry': provenance(),
        'workCountry': provenance(),
        'workCanton': provenance(),
      },
    }, now: () => now).copyWith(
      prevoyance: const PrevoyanceProfile(canContribute3a: false),
    );

    expect(profile.isCrossBorder, isTrue);
    expect(profile.canContribute3a, isFalse);
  });
}
