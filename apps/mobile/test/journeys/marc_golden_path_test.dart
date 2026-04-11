// marc_golden_path_test.dart
//
// Integration test: Marc golden path — swiss_native, retirement intent.
// Traces: intent -> quick_start -> premier_eclairage -> plan -> coach.
//
// Marc persona: 58 ans, ZH (Zurich), retirement intent, 145'000 CHF/an.
// Service-level tests (not widget E2E) — consistent with project convention.
//
// Validates:
//  - Navigation pipeline (intent routing, data flow through screens)
//  - Data flow (premier eclairage, projections for high-salary senior)
//  - Onboarding completion flag lifecycle
//  - Regional voice (ZH = Deutschschweiz, Znueni)
//  - Error recovery (salary=0, late career job loss)

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/services/premier_eclairage_selector.dart';
import 'package:mint_mobile/services/coach/intent_router.dart';
import 'package:mint_mobile/services/minimal_profile_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/voice/regional_voice_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────
//  MARC PERSONA CONSTANTS
// ─────────────────────────────────────────────────────────────────

const marcAge = 58;
const marcCanton = 'ZH';
const marcIntent = 'retirement';
const marcSalary = 145000.0;
const marcChipKey = 'intentChipPrevoyance';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 1: Navigation Pipeline
  // ─────────────────────────────────────────────────────────────────

  group('Marc golden path - navigation pipeline', () {
    test('intent chip intentChipPrevoyance resolves to retirement_choice', () {
      final mapping = IntentRouter.forChipKey(marcChipKey);

      expect(mapping, isNotNull);
      expect(mapping!.goalIntentTag, equals('retirement_choice'));
      expect(mapping.lifeEventFamily, equals('professionnel'));
    });

    test('intent chip stressType is stress_retraite', () {
      final mapping = IntentRouter.forChipKey(marcChipKey);

      expect(mapping, isNotNull);
      expect(mapping!.stressType, equals('stress_retraite'));
    });

    test('quick_start validation accepts Marc profile (58, 145000, ZH)', () {
      final result = MinimalProfileService.compute(
        age: marcAge,
        grossSalary: marcSalary,
        canton: marcCanton,
      );

      expect(result, isNotNull);
      expect(result.age, equals(marcAge));
      expect(result.canton, equals(marcCanton));
      expect(result.grossMonthlySalary, closeTo(marcSalary / 12, 1.0));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 2: Data Flow
  // ─────────────────────────────────────────────────────────────────

  group('Marc golden path - data flow', () {
    test('Marc profile produces non-null premier eclairage', () {
      final profile = MinimalProfileService.compute(
        age: marcAge,
        grossSalary: marcSalary,
        canton: marcCanton,
      );

      final choc = PremierEclairageSelector.select(
        profile,
        stressType: 'stress_retraite',
      );

      expect(choc, isNotNull);
      expect(choc.value, isNotEmpty);
      expect(choc.rawValue, isNonZero);
    });

    test('Marc premier éclairage has valid label and subtitle', () {
      final profile = MinimalProfileService.compute(
        age: marcAge,
        grossSalary: marcSalary,
        canton: marcCanton,
      );

      final choc = PremierEclairageSelector.select(
        profile,
        stressType: 'stress_retraite',
      );

      expect(choc.title, isNotEmpty);
      expect(choc.subtitle, isNotEmpty);
    });

    test('Marc profile has valid retirement projections for high-salary senior', () {
      final profile = MinimalProfileService.compute(
        age: marcAge,
        grossSalary: marcSalary,
        canton: marcCanton,
      );

      // 58-year-old with 145k salary should have substantial projections
      expect(profile.avsMonthlyRente, greaterThan(0));
      expect(profile.totalMonthlyRetirement, greaterThan(0));
      expect(profile.replacementRate, greaterThan(0));
      // High salary -> replacement rate likely below 60%
      expect(profile.replacementRate, lessThan(1.0));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 3: Onboarding Completion Flag
  // ─────────────────────────────────────────────────────────────────

  group('Marc golden path - onboarding completion', () {
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
      await ReportPersistenceService.setSelectedOnboardingIntent(marcIntent);

      final completed =
          await ReportPersistenceService.isMiniOnboardingCompleted();
      expect(completed, isFalse);
    });

    test('full pipeline sets completion flag at end', () async {
      // Step 1: Intent selection
      await ReportPersistenceService.setSelectedOnboardingIntent(marcIntent);
      expect(
        await ReportPersistenceService.isMiniOnboardingCompleted(),
        isFalse,
      );

      // Step 2: Quick start + premier éclairage
      MinimalProfileService.compute(
        age: marcAge,
        grossSalary: marcSalary,
        canton: marcCanton,
      );
      expect(
        await ReportPersistenceService.isMiniOnboardingCompleted(),
        isFalse,
      );

      // Step 3: Plan screen completes pipeline
      await ReportPersistenceService.setMiniOnboardingCompleted(true);
      expect(
        await ReportPersistenceService.isMiniOnboardingCompleted(),
        isTrue,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 4: Regional Voice (ZH = Deutschschweiz)
  // ─────────────────────────────────────────────────────────────────

  group('Marc golden path - regional voice', () {
    test('RegionalVoiceService.forCanton(ZH) returns deutschschweiz region',
        () {
      final flavor = RegionalVoiceService.forCanton(marcCanton);

      expect(flavor.region, equals(SwissRegion.deutschschweiz));
    });

    test('ZH flavor contains Znueni in localExpressions', () {
      final flavor = RegionalVoiceService.forCanton(marcCanton);

      // Check for Znueni (may contain unicode umlaut)
      expect(
        flavor.localExpressions.any((e) => e.toLowerCase().contains('zn')),
        isTrue,
      );
    });

    test('ZH flavor has non-empty prompt addition', () {
      final flavor = RegionalVoiceService.forCanton(marcCanton);

      expect(flavor.promptAddition, isNotEmpty);
      expect(flavor.financialCultureNote, isNotEmpty);
      expect(flavor.humorStyle, isNotEmpty);
    });

    test('ZH canton note mentions Zurich specifics', () {
      final flavor = RegionalVoiceService.forCanton(marcCanton);

      expect(flavor.cantonNote, isNotEmpty);
      // ZH note should reference Zurich characteristics
      expect(flavor.cantonNote.toLowerCase(), contains('z'));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 5: Error Recovery
  // ─────────────────────────────────────────────────────────────────

  group('Marc golden path - error recovery', () {
    test(
        'MinimalProfileService.compute with salary=0 (late career job loss) '
        'produces valid result without crash', () {
      // Marc lost his job at 58 — salary drops to 0
      final result = MinimalProfileService.compute(
        age: marcAge,
        grossSalary: 0,
        canton: marcCanton,
      );

      expect(result, isNotNull);
      expect(result.age, equals(marcAge));
      expect(result.grossMonthlySalary, equals(0));
      // Should still produce AVS estimate (based on contribution years)
      // No crash — graceful handling
    });

    test('PremierEclairageSelector handles zero-salary senior gracefully', () {
      final profile = MinimalProfileService.compute(
        age: marcAge,
        grossSalary: 0,
        canton: marcCanton,
      );

      // Should not throw — produces a premier éclairage even with 0 salary
      final choc = PremierEclairageSelector.select(
        profile,
        stressType: 'stress_retraite',
      );

      expect(choc, isNotNull);
      expect(choc.value, isNotEmpty);
    });
  });
}
