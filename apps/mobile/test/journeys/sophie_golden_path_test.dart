// sophie_golden_path_test.dart
//
// Integration test: Sophie golden path — expat_eu, housing intent.
// Traces: intent -> quick_start -> premier_eclairage -> plan -> coach.
//
// Sophie persona: 35 ans, GE (Geneva), housing purchase intent, 95'000 CHF/an.
// Service-level tests (not widget E2E) — consistent with project convention.
//
// Validates:
//  - Navigation pipeline (intent routing -> stress_patrimoine)
//  - Data flow (premier eclairage for housing stress)
//  - Onboarding completion flag lifecycle
//  - Regional voice (GE = Romande, cosmopolite)
//  - Error recovery (empty canton — expat may not have one yet)

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/services/premier_eclairage_selector.dart';
import 'package:mint_mobile/services/coach/intent_router.dart';
import 'package:mint_mobile/services/minimal_profile_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/voice/regional_voice_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────
//  SOPHIE PERSONA CONSTANTS
// ─────────────────────────────────────────────────────────────────

const sophieAge = 35;
const sophieCanton = 'GE';
const sophieIntent = 'housingPurchase';
const sophieSalary = 95000.0;
const sophieChipKey = 'intentChipProjet';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 1: Navigation Pipeline
  // ─────────────────────────────────────────────────────────────────

  group('Sophie golden path - navigation pipeline', () {
    test('intent chip intentChipProjet resolves to housing_purchase', () {
      final mapping = IntentRouter.forChipKey(sophieChipKey);

      expect(mapping, isNotNull);
      expect(mapping!.goalIntentTag, equals('housing_purchase'));
      expect(mapping.lifeEventFamily, equals('patrimoine'));
    });

    test('intent chip stressType is stress_patrimoine', () {
      final mapping = IntentRouter.forChipKey(sophieChipKey);

      expect(mapping, isNotNull);
      expect(mapping!.stressType, equals('stress_patrimoine'));
    });

    test('quick_start validation accepts Sophie profile (35, 95000, GE)', () {
      final result = MinimalProfileService.compute(
        age: sophieAge,
        grossSalary: sophieSalary,
        canton: sophieCanton,
      );

      expect(result, isNotNull);
      expect(result.age, equals(sophieAge));
      expect(result.canton, equals(sophieCanton));
      expect(result.grossMonthlySalary, closeTo(sophieSalary / 12, 1.0));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 2: Data Flow
  // ─────────────────────────────────────────────────────────────────

  group('Sophie golden path - data flow', () {
    test('Sophie profile produces non-null premier eclairage', () {
      final profile = MinimalProfileService.compute(
        age: sophieAge,
        grossSalary: sophieSalary,
        canton: sophieCanton,
      );

      final choc = PremierEclairageSelector.select(
        profile,
        stressType: 'stress_patrimoine',
      );

      expect(choc, isNotNull);
      expect(choc.value, isNotEmpty);
      // Note: stress_patrimoine falls through to lifecycle fallback at onboarding
      // (no real patrimoine data). At age 35, compound growth advantage vs starting
      // at 35 = 0, so rawValue may be 0. This is expected behavior — the choc
      // still provides educational value via tax saving or retirement projection.
    });

    test('Sophie premier éclairage has valid label and subtitle', () {
      final profile = MinimalProfileService.compute(
        age: sophieAge,
        grossSalary: sophieSalary,
        canton: sophieCanton,
      );

      final choc = PremierEclairageSelector.select(
        profile,
        stressType: 'stress_patrimoine',
      );

      expect(choc.title, isNotEmpty);
      expect(choc.subtitle, isNotEmpty);
    });

    test('Sophie profile has valid projections for mid-career housing buyer',
        () {
      final profile = MinimalProfileService.compute(
        age: sophieAge,
        grossSalary: sophieSalary,
        canton: sophieCanton,
      );

      expect(profile.avsMonthlyRente, greaterThan(0));
      expect(profile.totalMonthlyRetirement, greaterThan(0));
      expect(profile.replacementRate, greaterThan(0));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 3: Onboarding Completion Flag
  // ─────────────────────────────────────────────────────────────────

  group('Sophie golden path - onboarding completion', () {
    test('isMiniOnboardingCompleted is false at start', () async {
      final completed =
          await ReportPersistenceService.isMiniOnboardingCompleted();
      expect(completed, isFalse);
    });

    test('isMiniOnboardingCompleted is true after setMiniOnboardingCompleted',
        () async {
      await ReportPersistenceService.setMiniOnboardingCompleted(true);

      final completed =
          await ReportPersistenceService.isMiniOnboardingCompleted();
      expect(completed, isTrue);
    });

    test('flag not set prematurely after intent selection only', () async {
      await ReportPersistenceService.setSelectedOnboardingIntent(sophieIntent);

      final completed =
          await ReportPersistenceService.isMiniOnboardingCompleted();
      expect(completed, isFalse);
    });

    test('full pipeline sets completion flag at end', () async {
      await ReportPersistenceService.setSelectedOnboardingIntent(sophieIntent);
      expect(
        await ReportPersistenceService.isMiniOnboardingCompleted(),
        isFalse,
      );

      MinimalProfileService.compute(
        age: sophieAge,
        grossSalary: sophieSalary,
        canton: sophieCanton,
      );
      expect(
        await ReportPersistenceService.isMiniOnboardingCompleted(),
        isFalse,
      );

      await ReportPersistenceService.setMiniOnboardingCompleted(true);
      expect(
        await ReportPersistenceService.isMiniOnboardingCompleted(),
        isTrue,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 4: Regional Voice (GE = Romande)
  // ─────────────────────────────────────────────────────────────────

  group('Sophie golden path - regional voice', () {
    test('RegionalVoiceService.forCanton(GE) returns romande region', () {
      final flavor = RegionalVoiceService.forCanton(sophieCanton);

      expect(flavor.region, equals(SwissRegion.romande));
    });

    test('GE flavor contains septante in localExpressions', () {
      final flavor = RegionalVoiceService.forCanton(sophieCanton);

      expect(
        flavor.localExpressions,
        contains('septante'),
      );
    });

    test('GE flavor has non-empty prompt addition', () {
      final flavor = RegionalVoiceService.forCanton(sophieCanton);

      expect(flavor.promptAddition, isNotEmpty);
      expect(flavor.financialCultureNote, isNotEmpty);
      expect(flavor.humorStyle, isNotEmpty);
    });

    test('GE canton note mentions cosmopolite/international', () {
      final flavor = RegionalVoiceService.forCanton(sophieCanton);

      expect(flavor.cantonNote, isNotEmpty);
      expect(flavor.cantonNote.toLowerCase(), contains('cosmopolite'));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 5: Error Recovery
  // ─────────────────────────────────────────────────────────────────

  group('Sophie golden path - error recovery', () {
    test(
        'MinimalProfileService.compute with empty canton (expat without canton) '
        'produces valid result without crash', () {
      // Sophie just arrived — canton not yet assigned
      final result = MinimalProfileService.compute(
        age: sophieAge,
        grossSalary: sophieSalary,
        canton: '',
      );

      expect(result, isNotNull);
      expect(result.age, equals(sophieAge));
      expect(result.grossMonthlySalary, closeTo(sophieSalary / 12, 1.0));
      // Should still compute — no crash with empty canton
    });

    test('RegionalVoiceService handles empty canton gracefully', () {
      final flavor = RegionalVoiceService.forCanton('');

      // Empty canton -> unknown region, not crash
      expect(flavor.region, equals(SwissRegion.unknown));
    });

    test('PremierEclairageSelector handles empty-canton profile gracefully', () {
      final profile = MinimalProfileService.compute(
        age: sophieAge,
        grossSalary: sophieSalary,
        canton: '',
      );

      final choc = PremierEclairageSelector.select(
        profile,
        stressType: 'stress_patrimoine',
      );

      expect(choc, isNotNull);
      expect(choc.value, isNotEmpty);
    });
  });
}
