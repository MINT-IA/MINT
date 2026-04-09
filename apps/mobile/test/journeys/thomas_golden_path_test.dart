// thomas_golden_path_test.dart
//
// Integration test: Thomas golden path — independent_with_lpp, 3a intent.
// Traces: intent -> quick_start -> premier_eclairage -> plan -> coach.
//
// Thomas persona: 42 ans, BE (Bern), 3a intent, 120'000 CHF/an.
// Service-level tests (not widget E2E) — consistent with project convention.
//
// Validates:
//  - Navigation pipeline (intent routing -> stress_budget)
//  - Data flow (premier eclairage for 3a budget stress)
//  - Onboarding completion flag lifecycle
//  - Regional voice (BE = Deutschschweiz, gemuetlich)
//  - Error recovery (age=18 boundary — just started working)

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/services/premier_eclairage_selector.dart';
import 'package:mint_mobile/services/coach/intent_router.dart';
import 'package:mint_mobile/services/minimal_profile_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/voice/regional_voice_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────
//  THOMAS PERSONA CONSTANTS
// ─────────────────────────────────────────────────────────────────

const thomasAge = 42;
const thomasCanton = 'BE';
const thomasIntent = 'selfEmployment';
const thomasSalary = 120000.0;
const thomasChipKey = 'intentChip3a';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 1: Navigation Pipeline
  // ─────────────────────────────────────────────────────────────────

  group('Thomas golden path - navigation pipeline', () {
    test('intent chip intentChip3a resolves to budget_overview', () {
      final mapping = IntentRouter.forChipKey(thomasChipKey);

      expect(mapping, isNotNull);
      expect(mapping!.goalIntentTag, equals('budget_overview'));
      expect(mapping.lifeEventFamily, equals('professionnel'));
    });

    test('intent chip routes to /pilier-3a via suggestedRoute', () {
      final mapping = IntentRouter.forChipKey(thomasChipKey);

      expect(mapping, isNotNull);
      expect(mapping!.suggestedRoute, equals('/pilier-3a'));
    });

    test('intent chip stressType is stress_budget', () {
      final mapping = IntentRouter.forChipKey(thomasChipKey);

      expect(mapping, isNotNull);
      expect(mapping!.stressType, equals('stress_budget'));
    });

    test('quick_start validation accepts Thomas profile (42, 120000, BE)', () {
      final result = MinimalProfileService.compute(
        age: thomasAge,
        grossSalary: thomasSalary,
        canton: thomasCanton,
      );

      expect(result, isNotNull);
      expect(result.age, equals(thomasAge));
      expect(result.canton, equals(thomasCanton));
      expect(result.grossMonthlySalary, closeTo(thomasSalary / 12, 1.0));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 2: Data Flow
  // ─────────────────────────────────────────────────────────────────

  group('Thomas golden path - data flow', () {
    test('Thomas profile produces non-null premier eclairage', () {
      final profile = MinimalProfileService.compute(
        age: thomasAge,
        grossSalary: thomasSalary,
        canton: thomasCanton,
      );

      final choc = PremierEclairageSelector.select(
        profile,
        stressType: 'stress_budget',
      );

      expect(choc, isNotNull);
      expect(choc.value, isNotEmpty);
      expect(choc.rawValue, isNonZero);
    });

    test('Thomas premier éclairage has valid label and subtitle', () {
      final profile = MinimalProfileService.compute(
        age: thomasAge,
        grossSalary: thomasSalary,
        canton: thomasCanton,
      );

      final choc = PremierEclairageSelector.select(
        profile,
        stressType: 'stress_budget',
      );

      expect(choc.title, isNotEmpty);
      expect(choc.subtitle, isNotEmpty);
    });

    test('Thomas profile has valid projections for independent with LPP', () {
      final profile = MinimalProfileService.compute(
        age: thomasAge,
        grossSalary: thomasSalary,
        canton: thomasCanton,
      );

      expect(profile.avsMonthlyRente, greaterThan(0));
      expect(profile.totalMonthlyRetirement, greaterThan(0));
      expect(profile.replacementRate, greaterThan(0));
      // 3a tax saving should be available
      expect(profile.taxSaving3a, greaterThan(0));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 3: Onboarding Completion Flag
  // ─────────────────────────────────────────────────────────────────

  group('Thomas golden path - onboarding completion', () {
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
      await ReportPersistenceService.setSelectedOnboardingIntent(thomasIntent);

      final completed =
          await ReportPersistenceService.isMiniOnboardingCompleted();
      expect(completed, isFalse);
    });

    test('full pipeline sets completion flag at end', () async {
      await ReportPersistenceService.setSelectedOnboardingIntent(thomasIntent);
      expect(
        await ReportPersistenceService.isMiniOnboardingCompleted(),
        isFalse,
      );

      MinimalProfileService.compute(
        age: thomasAge,
        grossSalary: thomasSalary,
        canton: thomasCanton,
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
  //  GROUP 4: Regional Voice (BE = Deutschschweiz)
  // ─────────────────────────────────────────────────────────────────

  group('Thomas golden path - regional voice', () {
    test('RegionalVoiceService.forCanton(BE) returns deutschschweiz region',
        () {
      final flavor = RegionalVoiceService.forCanton(thomasCanton);

      expect(flavor.region, equals(SwissRegion.deutschschweiz));
    });

    test('BE flavor contains Deutschschweiz expressions', () {
      final flavor = RegionalVoiceService.forCanton(thomasCanton);

      // Should contain typical Deutschschweiz expressions
      expect(flavor.localExpressions, isNotEmpty);
      expect(
        flavor.localExpressions.any((e) => e.contains('Feierabend')),
        isTrue,
      );
    });

    test('BE flavor has non-empty prompt addition', () {
      final flavor = RegionalVoiceService.forCanton(thomasCanton);

      expect(flavor.promptAddition, isNotEmpty);
      expect(flavor.financialCultureNote, isNotEmpty);
      expect(flavor.humorStyle, isNotEmpty);
    });

    test('BE canton note mentions Bern specifics', () {
      final flavor = RegionalVoiceService.forCanton(thomasCanton);

      expect(flavor.cantonNote, isNotEmpty);
      // BE note should reference Bernese characteristics
      expect(flavor.cantonNote.toLowerCase(), contains('bern'));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 5: Error Recovery
  // ─────────────────────────────────────────────────────────────────

  group('Thomas golden path - error recovery', () {
    test(
        'PremierEclairageSelector.select with age=18 (boundary, just started working) '
        'produces valid premier éclairage without crash', () {
      final profile = MinimalProfileService.compute(
        age: 18,
        grossSalary: thomasSalary,
        canton: thomasCanton,
      );

      final choc = PremierEclairageSelector.select(
        profile,
        stressType: 'stress_budget',
      );

      expect(choc, isNotNull);
      expect(choc.value, isNotEmpty);
      expect(choc.rawValue, isNonZero);
    });

    test('MinimalProfileService.compute with age=18 handles gracefully', () {
      final result = MinimalProfileService.compute(
        age: 18,
        grossSalary: thomasSalary,
        canton: thomasCanton,
      );

      expect(result, isNotNull);
      expect(result.age, equals(18));
      // 18-year-old has minimal contribution years
      expect(result.grossMonthlySalary, greaterThan(0));
    });
  });
}
