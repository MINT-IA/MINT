// Sub-phase 01.5 W02-T05 Task 1 — ProfileMigrationService tests.
//
// R7 (Gemini) legacy-user-lockout migration. Covers the 6 core behaviors:
//   1. Migration sets the re-onboarding flag ONLY for legacy ambiguous profiles
//      (usTaxPerson == null AND nationality == null).
//   2. Migration is a no-op for profiles with positive `nationality`.
//   3. Migration is a no-op for profiles with positive `usTaxPerson`.
//   4. Migration is idempotent — second run is a no-op.
//   5. Migration on a fresh / null profile sets the done flag without
//      setting the re-onboarding flag.
//   6. The re-onboarding flag is consumable (cleared once the US-tax-person
//      Q is answered).
//
// **Codex C1 HIGH (REVIEWS.md 2026-05-22):** Behavior 1 explicitly asserts
// that `profile.nationality` STAYS as it was (null) after migration. The
// data-truth boundary test (`nationality_remains_null`) is in the
// `profile_migration_legacy_grandfather_test.dart` file.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/profile_migration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileMigrationService.grandfatherLegacyProfile', () {
    test(
      'sets re-onboarding flag on legacy ambiguous profile '
      '(usTaxPerson=null AND nationality=null)',
      () async {
        SharedPreferences.setMockInitialValues({
          // Seed a minimal wizard_answers_v2 payload with NEITHER
          // q_us_tax_person NOR a nationality key — the legacy pre-fix
          // ambiguous shape. `wizard_completed=true` so loadFromWizard
          // materializes the profile (CoachProfileProvider.loadFromWizard
          // gates on this flag).
          'wizard_answers_v2': '{"q_birth_year": 1990, "q_canton": "VD"}',
          'wizard_completed': true,
        });
        final provider = CoachProfileProvider();
        await provider.loadFromWizard();

        final migrated = await ProfileMigrationService()
            .grandfatherLegacyProfile(provider: provider);

        expect(migrated, isTrue,
            reason: 'Legacy ambiguous profile MUST be flagged');

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool('coachProfile:needsUsTaxPersonReOnboarding'),
          isTrue,
          reason: 're-onboarding flag must be persisted',
        );
        expect(
          prefs.getBool('coachProfile:migration_01_5_done'),
          isTrue,
          reason: 'migration done flag must be set',
        );
      },
    );

    test(
      'is a no-op on a profile with existing nationality (e.g. FR)',
      () async {
        SharedPreferences.setMockInitialValues({
          'wizard_answers_v2':
              '{"q_birth_year": 1990, "q_canton": "VD", "q_nationality": "FR"}',
          'wizard_completed': true,
        });
        final provider = CoachProfileProvider();
        await provider.loadFromWizard();

        final migrated = await ProfileMigrationService()
            .grandfatherLegacyProfile(provider: provider);

        expect(migrated, isFalse,
            reason: 'Profile with declared nationality is not legacy-ambiguous');

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool('coachProfile:needsUsTaxPersonReOnboarding'),
          isNull,
          reason: 're-onboarding flag must NOT be set',
        );
        expect(
          prefs.getBool('coachProfile:migration_01_5_done'),
          isTrue,
          reason: 'migration done flag must be set (so we do not re-check)',
        );
      },
    );

    test(
      'is a no-op on a profile with usTaxPerson already set',
      () async {
        SharedPreferences.setMockInitialValues({
          'wizard_answers_v2':
              '{"q_birth_year": 1990, "q_canton": "VD", "q_us_tax_person": true}',
          'wizard_completed': true,
        });
        final provider = CoachProfileProvider();
        await provider.loadFromWizard();

        final migrated = await ProfileMigrationService()
            .grandfatherLegacyProfile(provider: provider);

        expect(migrated, isFalse,
            reason:
                'Profile with declared US-tax-person is not legacy-ambiguous');

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool('coachProfile:needsUsTaxPersonReOnboarding'),
          isNull,
        );
        expect(
          prefs.getBool('coachProfile:migration_01_5_done'),
          isTrue,
        );
      },
    );

    test('is idempotent — second run is a no-op', () async {
      SharedPreferences.setMockInitialValues({
        'wizard_answers_v2': '{"q_birth_year": 1990, "q_canton": "VD"}',
        'wizard_completed': true,
        // Pre-seed the done flag — simulates a previous migration run.
        'coachProfile:migration_01_5_done': true,
      });
      final provider = CoachProfileProvider();
      await provider.loadFromWizard();

      final migrated = await ProfileMigrationService()
          .grandfatherLegacyProfile(provider: provider);

      expect(migrated, isFalse,
          reason: 'Second run must early-return on the done flag');

      final prefs = await SharedPreferences.getInstance();
      // Re-onboarding flag was NOT set by this run (no-op).
      expect(
        prefs.getBool('coachProfile:needsUsTaxPersonReOnboarding'),
        isNull,
      );
    });

    test(
      'is a no-op for new profiles (provider.profile == null) — sets done flag only',
      () async {
        // No wizard_answers_v2 → loadFromWizard leaves _profile null.
        SharedPreferences.setMockInitialValues({});
        final provider = CoachProfileProvider();
        await provider.loadFromWizard();

        final migrated = await ProfileMigrationService()
            .grandfatherLegacyProfile(provider: provider);

        expect(migrated, isFalse,
            reason: 'No cached profile → nothing to grandfather');

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool('coachProfile:needsUsTaxPersonReOnboarding'),
          isNull,
        );
        expect(
          prefs.getBool('coachProfile:migration_01_5_done'),
          isTrue,
          reason:
              'Done flag must still be set so we do not re-check on next start',
        );
      },
    );

    test(
      'clearReOnboardingFlag consumes the flag once',
      () async {
        SharedPreferences.setMockInitialValues({
          'coachProfile:needsUsTaxPersonReOnboarding': true,
        });

        final svc = ProfileMigrationService();
        expect(await svc.needsUsTaxPersonReOnboarding(), isTrue);

        await svc.clearReOnboardingFlag();

        expect(await svc.needsUsTaxPersonReOnboarding(), isFalse);
      },
    );
  });
}
