// pierre_golden_path_test.dart
//
// Integration test: Pierre golden path — returning_swiss, bilan intent.
// Traces: intent -> quick_start -> chiffre_choc -> plan -> coach.
//
// Pierre persona: 50 ans, VS (Valais), bilan intent, 110'000 CHF/an.
// Service-level tests (not widget E2E) — consistent with project convention.
//
// Validates:
//  - Navigation pipeline (intent routing -> stress_retraite)
//  - Data flow (premier eclairage for bilan stress, 50yo VS)
//  - Onboarding completion flag lifecycle
//  - Regional voice (VS = Romande, direct montagnard)
//  - Error recovery (salary=999999, extreme high salary)

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/services/chiffre_choc_selector.dart';
import 'package:mint_mobile/services/coach/intent_router.dart';
import 'package:mint_mobile/services/minimal_profile_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/voice/regional_voice_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────
//  PIERRE PERSONA CONSTANTS
// ─────────────────────────────────────────────────────────────────

const pierreAge = 50;
const pierreCanton = 'VS';
const pierreIntent = 'cantonMove';
const pierreSalary = 110000.0;
const pierreChipKey = 'intentChipBilan';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 1: Navigation Pipeline
  // ─────────────────────────────────────────────────────────────────

  group('Pierre golden path - navigation pipeline', () {
    test('intent chip intentChipBilan resolves to retirement_choice', () {
      final mapping = IntentRouter.forChipKey(pierreChipKey);

      expect(mapping, isNotNull);
      expect(mapping!.goalIntentTag, equals('retirement_choice'));
      expect(mapping.lifeEventFamily, equals('professionnel'));
    });

    test('intent chip routes to /bilan-retraite via suggestedRoute', () {
      final mapping = IntentRouter.forChipKey(pierreChipKey);

      expect(mapping, isNotNull);
      expect(mapping!.suggestedRoute, equals('/bilan-retraite'));
    });

    test('intent chip stressType is stress_retraite', () {
      final mapping = IntentRouter.forChipKey(pierreChipKey);

      expect(mapping, isNotNull);
      expect(mapping!.stressType, equals('stress_retraite'));
    });

    test('quick_start validation accepts Pierre profile (50, 110000, VS)',
        () {
      final result = MinimalProfileService.compute(
        age: pierreAge,
        grossSalary: pierreSalary,
        canton: pierreCanton,
      );

      expect(result, isNotNull);
      expect(result.age, equals(pierreAge));
      expect(result.canton, equals(pierreCanton));
      expect(result.grossMonthlySalary, closeTo(pierreSalary / 12, 1.0));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 2: Data Flow
  // ─────────────────────────────────────────────────────────────────

  group('Pierre golden path - data flow', () {
    test('Pierre profile produces non-null premier eclairage', () {
      final profile = MinimalProfileService.compute(
        age: pierreAge,
        grossSalary: pierreSalary,
        canton: pierreCanton,
      );

      final choc = ChiffreChocSelector.select(
        profile,
        stressType: 'stress_retraite',
      );

      expect(choc, isNotNull);
      expect(choc.value, isNotEmpty);
      expect(choc.rawValue, isNonZero);
    });

    test('Pierre chiffre choc has valid label and subtitle', () {
      final profile = MinimalProfileService.compute(
        age: pierreAge,
        grossSalary: pierreSalary,
        canton: pierreCanton,
      );

      final choc = ChiffreChocSelector.select(
        profile,
        stressType: 'stress_retraite',
      );

      expect(choc.title, isNotEmpty);
      expect(choc.subtitle, isNotEmpty);
    });

    test('Pierre profile has valid retirement projections for 50yo VS', () {
      final profile = MinimalProfileService.compute(
        age: pierreAge,
        grossSalary: pierreSalary,
        canton: pierreCanton,
      );

      expect(profile.avsMonthlyRente, greaterThan(0));
      expect(profile.totalMonthlyRetirement, greaterThan(0));
      expect(profile.replacementRate, greaterThan(0));
      expect(profile.replacementRate, lessThan(1.0));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 3: Onboarding Completion Flag
  // ─────────────────────────────────────────────────────────────────

  group('Pierre golden path - onboarding completion', () {
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
      await ReportPersistenceService.setSelectedOnboardingIntent(pierreIntent);

      final completed =
          await ReportPersistenceService.isMiniOnboardingCompleted();
      expect(completed, isFalse);
    });

    test('full pipeline sets completion flag at end', () async {
      await ReportPersistenceService.setSelectedOnboardingIntent(pierreIntent);
      expect(
        await ReportPersistenceService.isMiniOnboardingCompleted(),
        isFalse,
      );

      MinimalProfileService.compute(
        age: pierreAge,
        grossSalary: pierreSalary,
        canton: pierreCanton,
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
  //  GROUP 4: Regional Voice (VS = Romande)
  // ─────────────────────────────────────────────────────────────────

  group('Pierre golden path - regional voice', () {
    test('RegionalVoiceService.forCanton(VS) returns romande region', () {
      final flavor = RegionalVoiceService.forCanton(pierreCanton);

      expect(flavor.region, equals(SwissRegion.romande));
    });

    test('VS flavor contains septante in localExpressions', () {
      final flavor = RegionalVoiceService.forCanton(pierreCanton);

      expect(
        flavor.localExpressions,
        contains('septante'),
      );
    });

    test('VS flavor has non-empty prompt addition', () {
      final flavor = RegionalVoiceService.forCanton(pierreCanton);

      expect(flavor.promptAddition, isNotEmpty);
      expect(flavor.financialCultureNote, isNotEmpty);
      expect(flavor.humorStyle, isNotEmpty);
    });

    test('VS canton note mentions Valais/montagnard specifics', () {
      final flavor = RegionalVoiceService.forCanton(pierreCanton);

      expect(flavor.cantonNote, isNotEmpty);
      expect(flavor.cantonNote.toLowerCase(), contains('valais'));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 5: Error Recovery
  // ─────────────────────────────────────────────────────────────────

  group('Pierre golden path - error recovery', () {
    test(
        'MinimalProfileService.compute with salary=999999 (extreme high salary) '
        'produces valid projections without overflow', () {
      final result = MinimalProfileService.compute(
        age: pierreAge,
        grossSalary: 999999,
        canton: pierreCanton,
      );

      expect(result, isNotNull);
      expect(result.age, equals(pierreAge));
      expect(result.grossMonthlySalary, greaterThan(0));
      // Should not overflow — valid finite projections
      expect(result.avsMonthlyRente.isFinite, isTrue);
      expect(result.totalMonthlyRetirement.isFinite, isTrue);
      expect(result.replacementRate.isFinite, isTrue);
    });

    test('ChiffreChocSelector handles extreme salary gracefully', () {
      final profile = MinimalProfileService.compute(
        age: pierreAge,
        grossSalary: 999999,
        canton: pierreCanton,
      );

      final choc = ChiffreChocSelector.select(
        profile,
        stressType: 'stress_retraite',
      );

      expect(choc, isNotNull);
      expect(choc.value, isNotEmpty);
      expect(choc.rawValue.isFinite, isTrue);
    });
  });
}
