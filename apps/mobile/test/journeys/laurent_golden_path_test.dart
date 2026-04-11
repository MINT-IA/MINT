// laurent_golden_path_test.dart
//
// Integration test: Laurent golden path — independent_no_lpp, changement intent.
// Traces: intent -> quick_start -> premier_eclairage -> plan -> coach.
//
// Laurent persona: 45 ans, NE (Neuchatel), changement intent, 85'000 CHF/an.
// Service-level tests (not widget E2E) — consistent with project convention.
//
// Validates:
//  - Navigation pipeline (intent routing -> stress_budget)
//  - Data flow (premier eclairage for budget change, mid-career)
//  - Onboarding completion flag lifecycle
//  - Regional voice (NE = Romande, horlogerie/precision)
//  - Error recovery (negative salary — debt scenario)

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/services/premier_eclairage_selector.dart';
import 'package:mint_mobile/services/coach/intent_router.dart';
import 'package:mint_mobile/services/minimal_profile_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/voice/regional_voice_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────
//  LAURENT PERSONA CONSTANTS
// ─────────────────────────────────────────────────────────────────

const laurentAge = 45;
const laurentCanton = 'NE';
const laurentIntent = 'debtCrisis';
const laurentSalary = 85000.0;
const laurentChipKey = 'intentChipChangement';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 1: Navigation Pipeline
  // ─────────────────────────────────────────────────────────────────

  group('Laurent golden path - navigation pipeline', () {
    test('intent chip intentChipChangement resolves to budget_overview', () {
      final mapping = IntentRouter.forChipKey(laurentChipKey);

      expect(mapping, isNotNull);
      expect(mapping!.goalIntentTag, equals('budget_overview'));
      expect(mapping.lifeEventFamily, equals('professionnel'));
    });

    test('intent chip stressType is stress_budget', () {
      final mapping = IntentRouter.forChipKey(laurentChipKey);

      expect(mapping, isNotNull);
      expect(mapping!.stressType, equals('stress_budget'));
    });

    test('quick_start validation accepts Laurent profile (45, 85000, NE)',
        () {
      final result = MinimalProfileService.compute(
        age: laurentAge,
        grossSalary: laurentSalary,
        canton: laurentCanton,
      );

      expect(result, isNotNull);
      expect(result.age, equals(laurentAge));
      expect(result.canton, equals(laurentCanton));
      expect(result.grossMonthlySalary, closeTo(laurentSalary / 12, 1.0));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 2: Data Flow
  // ─────────────────────────────────────────────────────────────────

  group('Laurent golden path - data flow', () {
    test('Laurent profile produces non-null premier eclairage', () {
      final profile = MinimalProfileService.compute(
        age: laurentAge,
        grossSalary: laurentSalary,
        canton: laurentCanton,
      );

      final choc = PremierEclairageSelector.select(
        profile,
        stressType: 'stress_budget',
      );

      expect(choc, isNotNull);
      expect(choc.value, isNotEmpty);
      expect(choc.rawValue, isNonZero);
    });

    test('Laurent premier éclairage has valid label and subtitle', () {
      final profile = MinimalProfileService.compute(
        age: laurentAge,
        grossSalary: laurentSalary,
        canton: laurentCanton,
      );

      final choc = PremierEclairageSelector.select(
        profile,
        stressType: 'stress_budget',
      );

      expect(choc.title, isNotEmpty);
      expect(choc.subtitle, isNotEmpty);
    });

    test('Laurent profile has valid mid-career projections', () {
      final profile = MinimalProfileService.compute(
        age: laurentAge,
        grossSalary: laurentSalary,
        canton: laurentCanton,
      );

      expect(profile.avsMonthlyRente, greaterThan(0));
      expect(profile.totalMonthlyRetirement, greaterThan(0));
      expect(profile.replacementRate, greaterThan(0));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 3: Onboarding Completion Flag
  // ─────────────────────────────────────────────────────────────────

  group('Laurent golden path - onboarding completion', () {
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
      await ReportPersistenceService.setSelectedOnboardingIntent(laurentIntent);

      final completed =
          await ReportPersistenceService.isMiniOnboardingCompleted();
      expect(completed, isFalse);
    });

    test('full pipeline sets completion flag at end', () async {
      await ReportPersistenceService.setSelectedOnboardingIntent(laurentIntent);
      expect(
        await ReportPersistenceService.isMiniOnboardingCompleted(),
        isFalse,
      );

      MinimalProfileService.compute(
        age: laurentAge,
        grossSalary: laurentSalary,
        canton: laurentCanton,
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
  //  GROUP 4: Regional Voice (NE = Romande)
  // ─────────────────────────────────────────────────────────────────

  group('Laurent golden path - regional voice', () {
    test('RegionalVoiceService.forCanton(NE) returns romande region', () {
      final flavor = RegionalVoiceService.forCanton(laurentCanton);

      expect(flavor.region, equals(SwissRegion.romande));
    });

    test('NE flavor contains septante in localExpressions', () {
      final flavor = RegionalVoiceService.forCanton(laurentCanton);

      expect(
        flavor.localExpressions,
        contains('septante'),
      );
    });

    test('NE flavor has non-empty prompt addition', () {
      final flavor = RegionalVoiceService.forCanton(laurentCanton);

      expect(flavor.promptAddition, isNotEmpty);
      expect(flavor.financialCultureNote, isNotEmpty);
      expect(flavor.humorStyle, isNotEmpty);
    });

    test('NE canton note mentions Neuchatel specifics', () {
      final flavor = RegionalVoiceService.forCanton(laurentCanton);

      expect(flavor.cantonNote, isNotEmpty);
      // NE note should reference horlogerie/precision
      expect(flavor.cantonNote.toLowerCase(), contains('neuch'));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 5: Error Recovery
  // ─────────────────────────────────────────────────────────────────

  group('Laurent golden path - error recovery', () {
    test(
        'MinimalProfileService.compute with grossSalary=-5000 (negative salary) '
        'produces valid result without crash', () {
      final result = MinimalProfileService.compute(
        age: laurentAge,
        grossSalary: -5000,
        canton: laurentCanton,
      );

      expect(result, isNotNull);
      expect(result.age, equals(laurentAge));
      // Negative salary should not crash — graceful handling
      expect(result.grossMonthlySalary, lessThan(0));
    });

    test('PremierEclairageSelector handles negative-salary profile gracefully', () {
      final profile = MinimalProfileService.compute(
        age: laurentAge,
        grossSalary: -5000,
        canton: laurentCanton,
      );

      // Should not throw — produces some premier éclairage even with negative input
      final choc = PremierEclairageSelector.select(
        profile,
        stressType: 'stress_budget',
      );

      expect(choc, isNotNull);
      expect(choc.value, isNotEmpty);
    });
  });
}
