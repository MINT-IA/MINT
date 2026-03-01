import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/services/smart_onboarding_draft_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saveDraft is no-op when consent is not granted', () async {
    await SmartOnboardingDraftService.saveDraft(
      age: 42,
      grossSalary: 100000,
      canton: 'VD',
    );

    final draft = await SmartOnboardingDraftService.loadDraft();
    expect(draft, isEmpty);
  });

  test('setConsent(true) enables save/load draft', () async {
    await SmartOnboardingDraftService.setConsent(true);
    await SmartOnboardingDraftService.saveDraft(
      age: 44,
      grossSalary: 120000,
      canton: 'VS',
    );

    final draft = await SmartOnboardingDraftService.loadDraft();
    expect(draft['age'], 44);
    expect(draft['grossSalary'], 120000);
    expect(draft['canton'], 'VS');
  });

  test('setConsent(false) clears stored draft', () async {
    await SmartOnboardingDraftService.setConsent(true);
    await SmartOnboardingDraftService.saveDraft(
      age: 35,
      grossSalary: 90000,
      canton: 'GE',
    );

    await SmartOnboardingDraftService.setConsent(false);
    final draft = await SmartOnboardingDraftService.loadDraft();
    expect(draft, isEmpty);
  });

  test('clearDraft removes only draft payload', () async {
    await SmartOnboardingDraftService.setConsent(true);
    await SmartOnboardingDraftService.saveDraft(
      age: 50,
      grossSalary: 150000,
      canton: 'ZH',
    );

    await SmartOnboardingDraftService.clearDraft();
    final draft = await SmartOnboardingDraftService.loadDraft();
    expect(draft, isEmpty);
    expect(await SmartOnboardingDraftService.isConsentGiven(), isTrue);
  });
}
