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
  });

  test('resume step computes from partial answers', () async {
    await ReportPersistenceService.saveAnswers({
      'q_financial_stress_check': 'budget',
      'q_birth_year': 1990,
      'q_canton': 'VD',
      'q_net_income_period_chf': 6000,
      'q_employment_status': 'employee',
      'q_household_type': 'single',
      'q_housing_status': 'tenant',
      'q_housing_cost_period_chf': 1800,
    });

    final provider = OnboardingProvider();
    await provider.initFromPersistence();

    // All step 1+2 data present → resume at step 2 (goal)
    expect(provider.computeResumeStep(), 2);
  });

  test('build snapshot includes household + civil status + drafts', () {
    final provider = OnboardingProvider()
      ..stressChoices = {'tax'}
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
    // family/single_parent don't pre-fill children count — wizard asks for exact count
    expect(snapshot.containsKey('q_children'), isFalse);
    expect(snapshot['mini_draft_birth_year'], '1991');
    expect(snapshot['q_has_pension_fund'], 'yes');
  });

  test('complete mini onboarding persists completion flag', () async {
    final provider = OnboardingProvider()
      ..stressChoices = {'budget'}
      ..birthYear = 1990
      ..canton = 'VD'
      ..incomeMonthly = 7000
      ..employmentStatus = 'employee'
      ..householdType = 'single'
      ..housingStatus = 'tenant'
      ..housingCostMonthly = 1800
      ..mainGoal = 'retirement';

    final merged = await provider.completeMiniOnboarding();
    expect(merged, isNotNull);
    expect(await ReportPersistenceService.isMiniOnboardingCompleted(), isTrue);
  });

  test('couple household requires partner data to advance step 2', () {
    final provider = OnboardingProvider()
      ..incomeMonthly = 7000
      ..employmentStatus = 'employee'
      ..householdType = 'couple'
      ..housingStatus = 'tenant'
      ..housingCostMonthly = 1800;

    expect(provider.canAdvanceFromStep2, isFalse);

    provider
      ..civilStatusChoice = 'married'
      ..partnerIncome = 5200
      ..partnerBirthYear = 1992
      ..partnerEmploymentStatus = 'employee';

    expect(provider.canAdvanceFromStep2, isTrue);
  });

  test('concubinage maps to cohabiting and uses individual taxation', () {
    final provider = OnboardingProvider()
      ..householdType = 'couple'
      ..civilStatusChoice = 'concubinage'
      ..incomeMonthly = 8000
      ..partnerIncome = 6000
      ..partnerBirthYear = 1992
      ..partnerEmploymentStatus = 'employee'
      ..birthYear = 1990
      ..canton = 'VD'
      ..employmentStatus = 'employee';

    final snapshot = provider.buildAnswersSnapshot();

    // civilStatusForHousehold maps 'concubinage' → 'cohabiting' (wizard value)
    expect(snapshot['q_civil_status'], 'cohabiting');
    // isConcubinage helper
    expect(provider.isConcubinage, isTrue);
    // Individual adult count for LAMal (not couple)
    expect(provider.adultCountForHousehold('couple'), 1);
  });

  test('switching to single clears partner fields from snapshot', () {
    final provider = OnboardingProvider()
      ..householdType = 'couple'
      ..civilStatusChoice = 'concubinage'
      ..partnerIncome = 4800
      ..partnerBirthYear = 1993
      ..partnerEmploymentStatus = 'self_employed'
      ..draftPartnerIncome = '4800'
      ..draftPartnerBirthYear = '1993';

    provider.setHouseholdType('single');
    final snapshot = provider.buildAnswersSnapshot();

    expect(snapshot.containsKey('q_partner_net_income_chf'), isFalse);
    expect(snapshot.containsKey('q_partner_birth_year'), isFalse);
    expect(snapshot.containsKey('q_partner_employment_status'), isFalse);
    expect(snapshot.containsKey('q_civil_status_choice'), isFalse);
    expect(snapshot.containsKey('mini_draft_partner_income'), isFalse);
    expect(snapshot.containsKey('mini_draft_partner_birth_year'), isFalse);
  });

  test('single_parent keeps single civil status and lets wizard ask children count', () {
    final provider = OnboardingProvider()..householdType = 'single_parent';
    final snapshot = provider.buildAnswersSnapshot();

    expect(provider.isHouseholdWithPartner, isFalse);
    expect(snapshot['q_civil_status'], 'single');
    // single_parent doesn't pre-fill children — wizard asks for exact count (1, 2, 3+)
    expect(snapshot.containsKey('q_children'), isFalse);
  });
}
