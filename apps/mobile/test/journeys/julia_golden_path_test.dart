// julia_golden_path_test.dart
//
// Integration test: Julia golden path — expat_us (FATCA), fiscalite intent.
// Traces: intent -> quick_start -> premier_eclairage -> plan -> coach.
//
// Julia persona: 38 ans, ZG (Zug), fiscalite intent, 180'000 CHF/an.
// Service-level tests (not widget E2E) — consistent with project convention.
//
// Validates:
//  - Navigation pipeline (intent routing -> stress_impots)
//  - Data flow (premier eclairage for tax stress, high earner)
//  - Onboarding completion flag lifecycle
//  - Regional voice (ZG = Deutschschweiz, crypto valley)
//  - Error recovery (nonExistentChipKey returns null, age=17 underage)

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/services/premier_eclairage_selector.dart';
import 'package:mint_mobile/services/coach/intent_router.dart';
import 'package:mint_mobile/services/minimal_profile_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/voice/regional_voice_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────
//  JULIA PERSONA CONSTANTS
// ─────────────────────────────────────────────────────────────────

const juliaAge = 38;
const juliaCanton = 'ZG';
const juliaIntent = 'marriage';
const juliaSalary = 180000.0;
const juliaChipKey = 'intentChipFiscalite';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 1: Navigation Pipeline
  // ─────────────────────────────────────────────────────────────────

  group('Julia golden path - navigation pipeline', () {
    test('intent chip intentChipFiscalite resolves to budget_overview', () {
      final mapping = IntentRouter.forChipKey(juliaChipKey);

      expect(mapping, isNotNull);
      expect(mapping!.goalIntentTag, equals('budget_overview'));
      expect(mapping.lifeEventFamily, equals('patrimoine'));
    });

    test('intent chip routes to /fiscalite-overview via suggestedRoute', () {
      final mapping = IntentRouter.forChipKey(juliaChipKey);

      expect(mapping, isNotNull);
      expect(mapping!.suggestedRoute, equals('/fiscalite-overview'));
    });

    test('intent chip stressType is stress_impots', () {
      final mapping = IntentRouter.forChipKey(juliaChipKey);

      expect(mapping, isNotNull);
      expect(mapping!.stressType, equals('stress_impots'));
    });

    test('quick_start validation accepts Julia profile (38, 180000, ZG)', () {
      final result = MinimalProfileService.compute(
        age: juliaAge,
        grossSalary: juliaSalary,
        canton: juliaCanton,
      );

      expect(result, isNotNull);
      expect(result.age, equals(juliaAge));
      expect(result.canton, equals(juliaCanton));
      expect(result.grossMonthlySalary, closeTo(juliaSalary / 12, 1.0));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 2: Data Flow
  // ─────────────────────────────────────────────────────────────────

  group('Julia golden path - data flow', () {
    test('Julia profile produces non-null premier eclairage', () {
      final profile = MinimalProfileService.compute(
        age: juliaAge,
        grossSalary: juliaSalary,
        canton: juliaCanton,
      );

      final choc = PremierEclairageSelector.select(
        profile,
        stressType: 'stress_impots',
      );

      expect(choc, isNotNull);
      expect(choc.value, isNotEmpty);
      expect(choc.rawValue, isNonZero);
    });

    test('Julia premier éclairage has valid label and subtitle', () {
      final profile = MinimalProfileService.compute(
        age: juliaAge,
        grossSalary: juliaSalary,
        canton: juliaCanton,
      );

      final choc = PremierEclairageSelector.select(
        profile,
        stressType: 'stress_impots',
      );

      expect(choc.title, isNotEmpty);
      expect(choc.subtitle, isNotEmpty);
    });

    test('Julia profile has valid projections for high-earner in ZG', () {
      final profile = MinimalProfileService.compute(
        age: juliaAge,
        grossSalary: juliaSalary,
        canton: juliaCanton,
      );

      expect(profile.avsMonthlyRente, greaterThan(0));
      expect(profile.totalMonthlyRetirement, greaterThan(0));
      // High earner should have significant tax saving potential
      expect(profile.taxSaving3a, greaterThan(0));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 3: Onboarding Completion Flag
  // ─────────────────────────────────────────────────────────────────

  group('Julia golden path - onboarding completion', () {
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
      await ReportPersistenceService.setSelectedOnboardingIntent(juliaIntent);

      final completed =
          await ReportPersistenceService.isMiniOnboardingCompleted();
      expect(completed, isFalse);
    });

    test('full pipeline sets completion flag at end', () async {
      await ReportPersistenceService.setSelectedOnboardingIntent(juliaIntent);
      expect(
        await ReportPersistenceService.isMiniOnboardingCompleted(),
        isFalse,
      );

      MinimalProfileService.compute(
        age: juliaAge,
        grossSalary: juliaSalary,
        canton: juliaCanton,
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
  //  GROUP 4: Regional Voice (ZG = Deutschschweiz)
  // ─────────────────────────────────────────────────────────────────

  group('Julia golden path - regional voice', () {
    test('RegionalVoiceService.forCanton(ZG) returns deutschschweiz region',
        () {
      final flavor = RegionalVoiceService.forCanton(juliaCanton);

      expect(flavor.region, equals(SwissRegion.deutschschweiz));
    });

    test('ZG flavor contains Deutschschweiz expressions', () {
      final flavor = RegionalVoiceService.forCanton(juliaCanton);

      expect(flavor.localExpressions, isNotEmpty);
    });

    test('ZG flavor has non-empty prompt addition', () {
      final flavor = RegionalVoiceService.forCanton(juliaCanton);

      expect(flavor.promptAddition, isNotEmpty);
      expect(flavor.financialCultureNote, isNotEmpty);
      expect(flavor.humorStyle, isNotEmpty);
    });

    test('ZG canton note mentions Zug specifics', () {
      final flavor = RegionalVoiceService.forCanton(juliaCanton);

      expect(flavor.cantonNote, isNotEmpty);
      // ZG note should reference Zug characteristics (crypto valley, fiscal)
      expect(flavor.cantonNote.toLowerCase(), contains('zug'));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 5: Error Recovery
  // ─────────────────────────────────────────────────────────────────

  group('Julia golden path - error recovery', () {
    test(
        'IntentRouter.forChipKey with nonExistentChipKey returns null (not crash)',
        () {
      final mapping = IntentRouter.forChipKey('nonExistentChipKey');

      expect(mapping, isNull);
    });

    test(
        'MinimalProfileService.compute with age=17 (underage, below working age) '
        'produces valid result without crash', () {
      final result = MinimalProfileService.compute(
        age: 17,
        grossSalary: juliaSalary,
        canton: juliaCanton,
      );

      expect(result, isNotNull);
      expect(result.age, equals(17));
      // 17-year-old has no contribution years but should not crash
      expect(result.grossMonthlySalary, greaterThan(0));
    });

    test('PremierEclairageSelector handles underage profile gracefully', () {
      final profile = MinimalProfileService.compute(
        age: 17,
        grossSalary: juliaSalary,
        canton: juliaCanton,
      );

      final choc = PremierEclairageSelector.select(
        profile,
        stressType: 'stress_impots',
      );

      expect(choc, isNotNull);
      expect(choc.value, isNotEmpty);
    });
  });
}
