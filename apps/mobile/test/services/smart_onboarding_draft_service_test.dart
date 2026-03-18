import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/services/smart_onboarding_draft_service.dart';

/// Tests for SmartOnboardingDraftService — consent-gated local persistence.
///
/// Privacy: draft is only saved after explicit consent (GDPR/nLPD).
/// No identifiable data is logged.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SmartOnboardingDraftService — consent gating', () {
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
  });

  group('SmartOnboardingDraftService — new tests', () {
    test('isConsentGiven returns false by default', () async {
      expect(await SmartOnboardingDraftService.isConsentGiven(), isFalse);
    });

    test('isConsentGiven returns true after setConsent(true)', () async {
      await SmartOnboardingDraftService.setConsent(true);
      expect(await SmartOnboardingDraftService.isConsentGiven(), isTrue);
    });

    test('savedAt timestamp is included in draft', () async {
      await SmartOnboardingDraftService.setConsent(true);
      await SmartOnboardingDraftService.saveDraft(
        age: 40,
        grossSalary: 80000,
        canton: 'BE',
      );
      final draft = await SmartOnboardingDraftService.loadDraft();
      expect(draft.containsKey('savedAt'), isTrue);
      // savedAt should be a valid ISO 8601 date
      expect(() => DateTime.parse(draft['savedAt'] as String), returnsNormally);
    });

    test('draft with null canton omits canton field', () async {
      await SmartOnboardingDraftService.setConsent(true);
      await SmartOnboardingDraftService.saveDraft(
        age: 30,
        grossSalary: 60000,
        canton: null,
      );
      final draft = await SmartOnboardingDraftService.loadDraft();
      expect(draft.containsKey('canton'), isFalse);
      expect(draft['age'], 30);
      expect(draft['grossSalary'], 60000);
    });

    test('draft with empty canton omits canton field', () async {
      await SmartOnboardingDraftService.setConsent(true);
      await SmartOnboardingDraftService.saveDraft(
        age: 30,
        grossSalary: 60000,
        canton: '',
      );
      final draft = await SmartOnboardingDraftService.loadDraft();
      expect(draft.containsKey('canton'), isFalse);
    });

    test('loadDraft returns empty map for corrupted JSON', () async {
      // Manually set corrupted data in SharedPreferences
      SharedPreferences.setMockInitialValues({
        'mint_onboarding_consent': true,
        'smart_onboarding_draft_v1': 'not-valid-json{{{',
      });
      final draft = await SmartOnboardingDraftService.loadDraft();
      expect(draft, isEmpty,
          reason: 'Corrupted JSON should return empty map gracefully');
    });

    test('loadDraft returns empty map for empty string', () async {
      SharedPreferences.setMockInitialValues({
        'mint_onboarding_consent': true,
        'smart_onboarding_draft_v1': '',
      });
      final draft = await SmartOnboardingDraftService.loadDraft();
      expect(draft, isEmpty);
    });

    test('overwrite draft replaces previous data', () async {
      await SmartOnboardingDraftService.setConsent(true);
      await SmartOnboardingDraftService.saveDraft(
        age: 30,
        grossSalary: 60000,
        canton: 'ZH',
      );
      await SmartOnboardingDraftService.saveDraft(
        age: 45,
        grossSalary: 120000,
        canton: 'GE',
      );
      final draft = await SmartOnboardingDraftService.loadDraft();
      expect(draft['age'], 45);
      expect(draft['grossSalary'], 120000);
      expect(draft['canton'], 'GE');
    });

    test('consent revocation then re-grant requires new save', () async {
      await SmartOnboardingDraftService.setConsent(true);
      await SmartOnboardingDraftService.saveDraft(
        age: 40,
        grossSalary: 100000,
        canton: 'VS',
      );
      // Revoke
      await SmartOnboardingDraftService.setConsent(false);
      // Re-grant
      await SmartOnboardingDraftService.setConsent(true);
      final draft = await SmartOnboardingDraftService.loadDraft();
      expect(draft, isEmpty,
          reason: 'Old draft was cleared on revocation');
    });
  });
}
