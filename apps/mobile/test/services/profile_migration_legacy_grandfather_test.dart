// Sub-phase 01.5 W02-T05 Task 1 — Codex C1 HIGH data-truth regression guard.
//
// REVIEWS.md 2026-05-22 §C1 (HIGH blocker): the prior version of this plan
// wrote `nationality='CH'` to legacy null-nationality profiles. That is the
// exact data-truth corruption sub-phase 01.5 is designed to PREVENT — even
// if the FATCA Q corrects the archetype next session, writing CH to a user
// who didn't declare it is the same class of harm the gate is built to
// close.
//
// These tests are the regression guards for that decision:
//   1. legacy_grandfathered_profile_nationality_remains_null — after the
//      migration runs on an ambiguous legacy profile, the `nationality`
//      field is STILL null. NEVER 'CH'. NEVER any value.
//   2. legacy_grandfathered_re_onboarding_flag_is_consumed — once the
//      US-tax-person Q is answered, the flag is cleared exactly once.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/profile_migration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileMigrationService — Codex C1 HIGH data-truth boundary', () {
    test(
      'legacy_grandfathered_profile_nationality_remains_null '
      '(Codex C1 HIGH: migration MUST NOT write CH to nationality)',
      () async {
        // Seed an ambiguous legacy wizard payload: no q_us_tax_person, no
        // q_nationality. This is the exact pre-fix shape that the previous
        // (rejected) migration would have rewritten to CH.
        SharedPreferences.setMockInitialValues({
          'wizard_answers_v2': '{"q_birth_year": 1985, "q_canton": "GE"}',
        });
        final provider = CoachProfileProvider();
        await provider.loadFromWizard();

        // Sanity: pre-migration profile is the legacy ambiguous shape.
        expect(provider.profile, isNotNull);
        expect(provider.profile!.nationality, isNull,
            reason: 'Pre-migration sanity: ambiguous profile has null nationality');
        expect(provider.profile!.usTaxPerson, isNull);

        // Run migration.
        final migrated = await ProfileMigrationService()
            .grandfatherLegacyProfile(provider: provider);

        // Assertion 1: migration flagged the profile.
        expect(migrated, isTrue,
            reason: 'Legacy ambiguous profile MUST be flagged for re-onboarding');

        // Assertion 2 (Codex C1 HIGH blocker): nationality is STILL null.
        // NEVER 'CH'. NEVER any other value. The data-truth boundary holds.
        expect(
          provider.profile?.nationality,
          isNull,
          reason: 'Codex C1 HIGH: migration MUST NOT write CH (or any value) '
              'to nationality. Data-truth boundary preserved. '
              'See 01.5-REVIEWS.md §C1.',
        );
        // usTaxPerson is also untouched.
        expect(provider.profile?.usTaxPerson, isNull,
            reason: 'usTaxPerson is the FATCA signal; flag-based migration '
                'must NOT pre-fill it either');

        // Assertion 3: re-onboarding flag set so the orchestrator routes
        // to the US-tax-person Q on the next session.
        final flag = await ProfileMigrationService()
            .needsUsTaxPersonReOnboarding();
        expect(flag, isTrue);
      },
    );

    test(
      'legacy_grandfathered_re_onboarding_flag_is_consumed_once',
      () async {
        // Migration was run; flag is set; user opens the app again and
        // answers the US-tax-person Q. The Q's `_answer` calls
        // `clearReOnboardingFlag` (wired in us_tax_person_screen.dart).
        SharedPreferences.setMockInitialValues({
          'coachProfile:migration_01_5_done': true,
          'coachProfile:needsUsTaxPersonReOnboarding': true,
        });

        final svc = ProfileMigrationService();
        expect(await svc.needsUsTaxPersonReOnboarding(), isTrue,
            reason: 'Pre-condition: flag is set');

        // Simulate the consumer call (us_tax_person_screen onAnswered).
        await svc.clearReOnboardingFlag();

        // Now the orchestrator on the NEXT entry will skip the
        // pre-archetype guard and resolve the archetype normally from
        // the fresh signal.
        expect(await svc.needsUsTaxPersonReOnboarding(), isFalse,
            reason: 'Post-answer: flag is cleared exactly once');

        // Calling clear again is a safe no-op.
        await svc.clearReOnboardingFlag();
        expect(await svc.needsUsTaxPersonReOnboarding(), isFalse);
      },
    );
  });
}
