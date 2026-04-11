// nadia_golden_path_test.dart
//
// Integration test: Nadia golden path — expat_non_eu, autre intent.
// Traces: intent -> quick_start -> premier_eclairage -> plan -> coach.
//
// Nadia persona: 28 ans, TI (Ticino), autre intent, 65'000 CHF/an.
// Service-level tests (not widget E2E) — consistent with project convention.
//
// Validates:
//  - Navigation pipeline (intent routing -> stress_retraite)
//  - Data flow (premier eclairage for general stress, young profile)
//  - Onboarding completion flag lifecycle
//  - Regional voice (TI = svizzeraItaliana, warm Mediterranean flair)
//  - Error recovery (double setMiniOnboardingCompleted idempotent, unknown canton)

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/services/premier_eclairage_selector.dart';
import 'package:mint_mobile/services/coach/intent_router.dart';
import 'package:mint_mobile/services/minimal_profile_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/voice/regional_voice_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────
//  NADIA PERSONA CONSTANTS
// ─────────────────────────────────────────────────────────────────

const nadiaAge = 28;
const nadiaCanton = 'TI';
const nadiaIntent = 'birth';
const nadiaSalary = 65000.0;
const nadiaChipKey = 'intentChipAutre';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 1: Navigation Pipeline
  // ─────────────────────────────────────────────────────────────────

  group('Nadia golden path - navigation pipeline', () {
    test('intent chip intentChipAutre resolves to retirement_choice', () {
      final mapping = IntentRouter.forChipKey(nadiaChipKey);

      expect(mapping, isNotNull);
      expect(mapping!.goalIntentTag, equals('retirement_choice'));
      expect(mapping.lifeEventFamily, equals('professionnel'));
    });

    test('intent chip stressType is stress_retraite', () {
      final mapping = IntentRouter.forChipKey(nadiaChipKey);

      expect(mapping, isNotNull);
      expect(mapping!.stressType, equals('stress_retraite'));
    });

    test('quick_start validation accepts Nadia profile (28, 65000, TI)', () {
      final result = MinimalProfileService.compute(
        age: nadiaAge,
        grossSalary: nadiaSalary,
        canton: nadiaCanton,
      );

      expect(result, isNotNull);
      expect(result.age, equals(nadiaAge));
      expect(result.canton, equals(nadiaCanton));
      expect(result.grossMonthlySalary, closeTo(nadiaSalary / 12, 1.0));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 2: Data Flow
  // ─────────────────────────────────────────────────────────────────

  group('Nadia golden path - data flow', () {
    test('Nadia profile produces non-null premier eclairage', () {
      final profile = MinimalProfileService.compute(
        age: nadiaAge,
        grossSalary: nadiaSalary,
        canton: nadiaCanton,
      );

      final choc = PremierEclairageSelector.select(
        profile,
        stressType: 'stress_retraite',
      );

      expect(choc, isNotNull);
      expect(choc.value, isNotEmpty);
      expect(choc.rawValue, isNonZero);
    });

    test('Nadia premier éclairage has valid label and subtitle', () {
      final profile = MinimalProfileService.compute(
        age: nadiaAge,
        grossSalary: nadiaSalary,
        canton: nadiaCanton,
      );

      final choc = PremierEclairageSelector.select(
        profile,
        stressType: 'stress_retraite',
      );

      expect(choc.title, isNotEmpty);
      expect(choc.subtitle, isNotEmpty);
    });

    test('Nadia profile has valid projections for young expat', () {
      final profile = MinimalProfileService.compute(
        age: nadiaAge,
        grossSalary: nadiaSalary,
        canton: nadiaCanton,
      );

      expect(profile.avsMonthlyRente, greaterThan(0));
      expect(profile.totalMonthlyRetirement, greaterThan(0));
      expect(profile.replacementRate, greaterThan(0));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 3: Onboarding Completion Flag
  // ─────────────────────────────────────────────────────────────────

  group('Nadia golden path - onboarding completion', () {
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
      await ReportPersistenceService.setSelectedOnboardingIntent(nadiaIntent);

      final completed =
          await ReportPersistenceService.isMiniOnboardingCompleted();
      expect(completed, isFalse);
    });

    test('full pipeline sets completion flag at end', () async {
      await ReportPersistenceService.setSelectedOnboardingIntent(nadiaIntent);
      expect(
        await ReportPersistenceService.isMiniOnboardingCompleted(),
        isFalse,
      );

      MinimalProfileService.compute(
        age: nadiaAge,
        grossSalary: nadiaSalary,
        canton: nadiaCanton,
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
  //  GROUP 4: Regional Voice (TI = Svizzera Italiana)
  // ─────────────────────────────────────────────────────────────────

  group('Nadia golden path - regional voice', () {
    test('RegionalVoiceService.forCanton(TI) returns svizzeraItaliana region',
        () {
      final flavor = RegionalVoiceService.forCanton(nadiaCanton);

      // TI maps to italiana enum value (SwissRegion.italiana)
      expect(flavor.region, equals(SwissRegion.italiana));
    });

    test('TI flavor contains grotto in localExpressions', () {
      final flavor = RegionalVoiceService.forCanton(nadiaCanton);

      expect(
        flavor.localExpressions,
        contains('grotto'),
      );
    });

    test('TI flavor has non-empty prompt addition with Italian warmth', () {
      final flavor = RegionalVoiceService.forCanton(nadiaCanton);

      expect(flavor.promptAddition, isNotEmpty);
      expect(flavor.financialCultureNote, isNotEmpty);
      expect(flavor.humorStyle, isNotEmpty);
      // Should reference Italian/Ticino warmth
      expect(flavor.promptAddition.toLowerCase(), contains('svizzera italiana'));
    });

    test('TI canton note mentions Ticino specifics', () {
      final flavor = RegionalVoiceService.forCanton(nadiaCanton);

      expect(flavor.cantonNote, isNotEmpty);
      expect(flavor.cantonNote.toLowerCase(), contains('ticino'));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 5: Error Recovery
  // ─────────────────────────────────────────────────────────────────

  group('Nadia golden path - error recovery', () {
    test(
        'setMiniOnboardingCompleted(true) called twice is idempotent',
        () async {
      await ReportPersistenceService.setMiniOnboardingCompleted(true);
      await ReportPersistenceService.setMiniOnboardingCompleted(true);

      final completed =
          await ReportPersistenceService.isMiniOnboardingCompleted();
      expect(completed, isTrue);
      // No error — idempotent operation
    });

    test(
        'MinimalProfileService.compute with unknown canton XX '
        'produces valid result without crash', () {
      final result = MinimalProfileService.compute(
        age: nadiaAge,
        grossSalary: nadiaSalary,
        canton: 'XX',
      );

      expect(result, isNotNull);
      expect(result.age, equals(nadiaAge));
      expect(result.canton, equals('XX'));
      // Unknown canton should still compute — no crash
      expect(result.grossMonthlySalary, greaterThan(0));
    });

    test('RegionalVoiceService handles unknown canton XX gracefully', () {
      final flavor = RegionalVoiceService.forCanton('XX');

      expect(flavor.region, equals(SwissRegion.unknown));
      expect(flavor.promptAddition, isEmpty);
    });

    test('PremierEclairageSelector handles unknown-canton profile gracefully', () {
      final profile = MinimalProfileService.compute(
        age: nadiaAge,
        grossSalary: nadiaSalary,
        canton: 'XX',
      );

      final choc = PremierEclairageSelector.select(
        profile,
        stressType: 'stress_retraite',
      );

      expect(choc, isNotNull);
      expect(choc.value, isNotEmpty);
    });
  });
}
