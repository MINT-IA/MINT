// anna_golden_path_test.dart
//
// Integration test: Anna golden path — cross_border, new job intent.
// Traces: intent -> quick_start -> premier_eclairage -> plan -> coach.
//
// Anna persona: 30 ans, BS (Basel-Stadt), new job intent, 78'000 CHF/an.
// Service-level tests (not widget E2E) — consistent with project convention.
//
// Validates:
//  - Navigation pipeline (intent routing -> stress_budget)
//  - Data flow (premier eclairage for new job stress)
//  - Onboarding completion flag lifecycle
//  - Regional voice (BS = Deutschschweiz, Fasnacht/pharma)
//  - Error recovery (age=65, retirement age boundary)

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/services/premier_eclairage_selector.dart';
import 'package:mint_mobile/services/coach/intent_router.dart';
import 'package:mint_mobile/services/minimal_profile_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/voice/regional_voice_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────
//  ANNA PERSONA CONSTANTS
// ─────────────────────────────────────────────────────────────────

const annaAge = 30;
const annaCanton = 'BS';
const annaIntent = 'newJob';
const annaSalary = 78000.0;
const annaChipKey = 'intentChipNouvelEmploi';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 1: Navigation Pipeline
  // ─────────────────────────────────────────────────────────────────

  group('Anna golden path - navigation pipeline', () {
    test('intent chip intentChipNouvelEmploi resolves to new_job', () {
      final mapping = IntentRouter.forChipKey(annaChipKey);

      expect(mapping, isNotNull);
      expect(mapping!.goalIntentTag, equals('new_job'));
      expect(mapping.lifeEventFamily, equals('professionnel'));
    });

    test('intent chip routes to /rente-vs-capital via suggestedRoute', () {
      final mapping = IntentRouter.forChipKey(annaChipKey);

      expect(mapping, isNotNull);
      expect(mapping!.suggestedRoute, equals('/rente-vs-capital'));
    });

    test('intent chip stressType is stress_budget', () {
      final mapping = IntentRouter.forChipKey(annaChipKey);

      expect(mapping, isNotNull);
      expect(mapping!.stressType, equals('stress_budget'));
    });

    test('quick_start validation accepts Anna profile (30, 78000, BS)', () {
      final result = MinimalProfileService.compute(
        age: annaAge,
        grossSalary: annaSalary,
        canton: annaCanton,
      );

      expect(result, isNotNull);
      expect(result.age, equals(annaAge));
      expect(result.canton, equals(annaCanton));
      expect(result.grossMonthlySalary, closeTo(annaSalary / 12, 1.0));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 2: Data Flow
  // ─────────────────────────────────────────────────────────────────

  group('Anna golden path - data flow', () {
    test('Anna profile produces non-null premier eclairage', () {
      final profile = MinimalProfileService.compute(
        age: annaAge,
        grossSalary: annaSalary,
        canton: annaCanton,
      );

      final choc = PremierEclairageSelector.select(
        profile,
        stressType: 'stress_budget',
      );

      expect(choc, isNotNull);
      expect(choc.value, isNotEmpty);
      expect(choc.rawValue, isNonZero);
    });

    test('Anna premier éclairage has valid label and subtitle', () {
      final profile = MinimalProfileService.compute(
        age: annaAge,
        grossSalary: annaSalary,
        canton: annaCanton,
      );

      final choc = PremierEclairageSelector.select(
        profile,
        stressType: 'stress_budget',
      );

      expect(choc.title, isNotEmpty);
      expect(choc.subtitle, isNotEmpty);
    });

    test('Anna profile has valid projections for young cross-border worker',
        () {
      final profile = MinimalProfileService.compute(
        age: annaAge,
        grossSalary: annaSalary,
        canton: annaCanton,
      );

      expect(profile.avsMonthlyRente, greaterThan(0));
      expect(profile.totalMonthlyRetirement, greaterThan(0));
      expect(profile.replacementRate, greaterThan(0));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 3: Onboarding Completion Flag
  // ─────────────────────────────────────────────────────────────────

  group('Anna golden path - onboarding completion', () {
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
      await ReportPersistenceService.setSelectedOnboardingIntent(annaIntent);

      final completed =
          await ReportPersistenceService.isMiniOnboardingCompleted();
      expect(completed, isFalse);
    });

    test('full pipeline sets completion flag at end', () async {
      await ReportPersistenceService.setSelectedOnboardingIntent(annaIntent);
      expect(
        await ReportPersistenceService.isMiniOnboardingCompleted(),
        isFalse,
      );

      MinimalProfileService.compute(
        age: annaAge,
        grossSalary: annaSalary,
        canton: annaCanton,
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
  //  GROUP 4: Regional Voice (BS = Deutschschweiz)
  // ─────────────────────────────────────────────────────────────────

  group('Anna golden path - regional voice', () {
    test('RegionalVoiceService.forCanton(BS) returns deutschschweiz region',
        () {
      final flavor = RegionalVoiceService.forCanton(annaCanton);

      expect(flavor.region, equals(SwissRegion.deutschschweiz));
    });

    test('BS flavor contains Deutschschweiz expressions', () {
      final flavor = RegionalVoiceService.forCanton(annaCanton);

      expect(flavor.localExpressions, isNotEmpty);
    });

    test('BS flavor has non-empty prompt addition', () {
      final flavor = RegionalVoiceService.forCanton(annaCanton);

      expect(flavor.promptAddition, isNotEmpty);
      expect(flavor.financialCultureNote, isNotEmpty);
      expect(flavor.humorStyle, isNotEmpty);
    });

    test('BS canton note mentions Basel specifics', () {
      final flavor = RegionalVoiceService.forCanton(annaCanton);

      expect(flavor.cantonNote, isNotEmpty);
      // BS note should reference Basel characteristics (Fasnacht, pharma)
      expect(flavor.cantonNote.toLowerCase(), contains('basel'));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  //  GROUP 5: Error Recovery
  // ─────────────────────────────────────────────────────────────────

  group('Anna golden path - error recovery', () {
    test(
        'MinimalProfileService.compute with age=65 (retirement age boundary) '
        'produces valid result with replacement rate', () {
      final result = MinimalProfileService.compute(
        age: 65,
        grossSalary: annaSalary,
        canton: annaCanton,
      );

      expect(result, isNotNull);
      expect(result.age, equals(65));
      // At retirement age, projections should still be valid
      expect(result.grossMonthlySalary, greaterThan(0));
      expect(result.replacementRate, greaterThanOrEqualTo(0));
    });

    test('PremierEclairageSelector handles age=65 boundary gracefully', () {
      final profile = MinimalProfileService.compute(
        age: 65,
        grossSalary: annaSalary,
        canton: annaCanton,
      );

      final choc = PremierEclairageSelector.select(
        profile,
        stressType: 'stress_budget',
      );

      expect(choc, isNotNull);
      expect(choc.value, isNotEmpty);
    });
  });
}
