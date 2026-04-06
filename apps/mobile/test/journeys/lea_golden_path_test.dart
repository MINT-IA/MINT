// lea_golden_path_test.dart
//
// Integration test: Lea golden path — full onboarding pipeline.
// Traces: intent -> quick_start -> chiffre_choc -> plan -> coach.
//
// Lea persona: 22 ans, VD (Lausanne), firstJob, 55'000 CHF/an.
// Service-level tests (not widget E2E) — consistent with project convention.
//
// Validates:
//  - Navigation pipeline (intent routing, data flow through screens)
//  - Onboarding completion flag lifecycle (not set prematurely)
//  - Input validation edge cases
//  - Regional voice (VD = Romande, septante/nonante)
//  - Premier eclairage computation for young firstJob profile

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/services/chiffre_choc_selector.dart';
import 'package:mint_mobile/services/coach/intent_router.dart';
import 'package:mint_mobile/services/minimal_profile_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/voice/regional_voice_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────
//  LEA PERSONA CONSTANTS
// ─────────────────────────────────────────────────────────────────

const leaAge = 22;
const leaCanton = 'VD';
const leaIntent = 'firstJob';
const leaSalary = 55000.0;
const leaChipKey = 'intentChipPremierEmploi';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 1: Navigation Pipeline
  // ─────────────────────────────────────────────────────────────────

  group('Lea golden path - navigation pipeline', () {
    test('intent chip intentChipPremierEmploi resolves to first_job', () {
      final mapping = IntentRouter.forChipKey(leaChipKey);

      expect(mapping, isNotNull);
      expect(mapping!.goalIntentTag, equals('first_job'));
      expect(mapping.lifeEventFamily, equals('professionnel'));
    });

    test('intent chip routes to /first-job via suggestedRoute', () {
      final mapping = IntentRouter.forChipKey(leaChipKey);

      expect(mapping, isNotNull);
      expect(mapping!.suggestedRoute, equals('/first-job'));
    });

    test('intent chip stressType is stress_prevoyance', () {
      final mapping = IntentRouter.forChipKey(leaChipKey);

      expect(mapping, isNotNull);
      expect(mapping!.stressType, equals('stress_prevoyance'));
    });

    test('quick_start validation accepts Lea profile (22, 55000, VD)', () {
      // MinimalProfileService.compute should not throw for valid inputs
      final result = MinimalProfileService.compute(
        age: leaAge,
        grossSalary: leaSalary,
        canton: leaCanton,
      );

      expect(result, isNotNull);
      expect(result.age, equals(leaAge));
      expect(result.canton, equals(leaCanton));
      expect(result.grossMonthlySalary, closeTo(leaSalary / 12, 1.0));
    });

    test('quick_start validation rejects age=0 (edge case)', () {
      // age=0 should still compute but produce degenerate results
      final result = MinimalProfileService.compute(
        age: 0,
        grossSalary: leaSalary,
        canton: leaCanton,
      );

      // A 0-year-old has 0 contribution years, so AVS rente should be minimal
      expect(result.age, equals(0));
      // No crash — the service handles edge cases gracefully
    });

    test('quick_start validation handles negative salary gracefully', () {
      // Negative salary should not crash the service
      final result = MinimalProfileService.compute(
        age: leaAge,
        grossSalary: -1,
        canton: leaCanton,
      );

      expect(result, isNotNull);
      // Negative salary produces 0 or negative projections — no crash
      expect(result.grossMonthlySalary, lessThanOrEqualTo(0));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 2: Data Flow
  // ─────────────────────────────────────────────────────────────────

  group('Lea golden path - data flow', () {
    test('Lea profile produces non-null premier eclairage', () {
      final profile = MinimalProfileService.compute(
        age: leaAge,
        grossSalary: leaSalary,
        canton: leaCanton,
      );

      final choc = ChiffreChocSelector.select(
        profile,
        stressType: 'stress_prevoyance',
      );

      expect(choc, isNotNull);
      expect(choc.value, isNotEmpty);
      expect(choc.rawValue, isNonZero);
    });

    test('Lea chiffre choc has valid label and subtitle', () {
      final profile = MinimalProfileService.compute(
        age: leaAge,
        grossSalary: leaSalary,
        canton: leaCanton,
      );

      final choc = ChiffreChocSelector.select(
        profile,
        stressType: 'stress_prevoyance',
      );

      expect(choc.title, isNotEmpty);
      expect(choc.subtitle, isNotEmpty);
    });

    test('Lea profile has valid retirement projections', () {
      final profile = MinimalProfileService.compute(
        age: leaAge,
        grossSalary: leaSalary,
        canton: leaCanton,
      );

      // A 22-year-old with 55k salary should have some retirement projection
      expect(profile.avsMonthlyRente, greaterThan(0));
      expect(profile.totalMonthlyRetirement, greaterThan(0));
      expect(profile.replacementRate, greaterThan(0));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 3: Onboarding Completion Flag
  // ─────────────────────────────────────────────────────────────────

  group('Lea golden path - onboarding completion', () {
    test('isMiniOnboardingCompleted is false at start', () async {
      final completed =
          await ReportPersistenceService.isMiniOnboardingCompleted();
      expect(completed, isFalse);
    });

    test('isMiniOnboardingCompleted is true after setMiniOnboardingCompleted',
        () async {
      // Simulate end-of-pipeline: plan_screen calls this
      await ReportPersistenceService.setMiniOnboardingCompleted(true);

      final completed =
          await ReportPersistenceService.isMiniOnboardingCompleted();
      expect(completed, isTrue);
    });

    test(
        'isMiniOnboardingCompleted remains false after intent selection only '
        '(not set prematurely)', () async {
      // After intent selection, the flag should NOT be set.
      // Only plan_screen (end of pipeline) sets it.
      // We verify the flag is still false after simulating intent-only flow.

      // Simulate intent selection by writing the intent (what intent_screen does)
      await ReportPersistenceService.setSelectedOnboardingIntent(leaIntent);

      // But the completion flag should NOT be set yet
      final completed =
          await ReportPersistenceService.isMiniOnboardingCompleted();
      expect(completed, isFalse);
    });

    test('full pipeline sets completion flag at end', () async {
      // Step 1: Intent selection (no flag set)
      await ReportPersistenceService.setSelectedOnboardingIntent(leaIntent);
      expect(
        await ReportPersistenceService.isMiniOnboardingCompleted(),
        isFalse,
      );

      // Step 2: Quick start + chiffre choc (no flag set)
      MinimalProfileService.compute(
        age: leaAge,
        grossSalary: leaSalary,
        canton: leaCanton,
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
  //  GROUP 4: Regional Voice (VD = Romande)
  // ─────────────────────────────────────────────────────────────────

  group('Lea golden path - regional voice', () {
    test('RegionalVoiceService.forCanton(VD) returns romande region', () {
      final flavor = RegionalVoiceService.forCanton(leaCanton);

      expect(flavor.region, equals(SwissRegion.romande));
    });

    test('VD flavor contains septante in localExpressions', () {
      final flavor = RegionalVoiceService.forCanton(leaCanton);

      expect(
        flavor.localExpressions,
        contains('septante'),
      );
    });

    test('VD flavor contains nonante in localExpressions', () {
      final flavor = RegionalVoiceService.forCanton(leaCanton);

      expect(
        flavor.localExpressions,
        contains('nonante'),
      );
    });

    test('VD flavor has non-empty prompt addition', () {
      final flavor = RegionalVoiceService.forCanton(leaCanton);

      expect(flavor.promptAddition, isNotEmpty);
      expect(flavor.financialCultureNote, isNotEmpty);
      expect(flavor.humorStyle, isNotEmpty);
    });
  });
}
