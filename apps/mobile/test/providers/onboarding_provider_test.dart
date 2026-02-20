import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/providers/onboarding_provider.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('initial state is empty and cannot advance', () {
    final provider = OnboardingProvider();
    expect(provider.currentStep, 0);
    expect(provider.canAdvanceFromStep1, isFalse);
    expect(provider.canAdvanceFromStep2, isFalse);
    expect(provider.canAdvanceFromStep3, isFalse);
    expect(provider.canAdvanceFromStep4, isFalse);
  });

  test('resume step computes from partial answers', () async {
    await ReportPersistenceService.saveAnswers({
      'q_financial_stress_check': 'budget',
      'q_birth_year': 1990,
      'q_canton': 'VD',
      'q_net_income_period_chf': 6000,
      'q_employment_status': 'employee',
      'q_household_type': 'single',
    });

    final provider = OnboardingProvider();
    await provider.initFromPersistence();

    expect(provider.computeResumeStep(), 3);
  });

  test('build snapshot includes household + civil status + drafts', () {
    final provider = OnboardingProvider()
      ..stressChoice = 'tax'
      ..birthYear = 1991
      ..canton = 'GE'
      ..incomeMonthly = 8000
      ..employmentStatus = 'employee'
      ..householdType = 'family'
      ..mainGoal = 'retirement'
      ..draftBirthYear = '1991';

    final snapshot = provider.buildAnswersSnapshot();
    expect(snapshot['q_household_type'], 'family');
    expect(snapshot['q_civil_status'], 'married');
    expect(snapshot['q_children'], 1);
    expect(snapshot['mini_draft_birth_year'], '1991');
    expect(snapshot['q_has_pension_fund'], 'yes');
  });

  test('complete mini onboarding persists completion flag', () async {
    final provider = OnboardingProvider()
      ..stressChoice = 'budget'
      ..birthYear = 1990
      ..canton = 'VD'
      ..incomeMonthly = 7000
      ..employmentStatus = 'employee'
      ..householdType = 'single'
      ..mainGoal = 'retirement';

    final merged = await provider.completeMiniOnboarding();
    expect(merged, isNotNull);
    expect(await ReportPersistenceService.isMiniOnboardingCompleted(), isTrue);
  });
}
