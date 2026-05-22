/// R7 legacy-user-lockout migration for sub-phase 01.5.
///
/// **Why this service exists (Gemini R7, REVIEWS.md):** plan 02-01 changed
/// the `nationality == null` fallback from `swissNative` to `unknown`. On
/// the next app open, every cached profile with `usTaxPerson == null AND
/// nationality == null` (the legacy ambiguous shape that shipped pre-fix)
/// would otherwise be reclassified as `FinancialArchetype.unknown` and
/// kicked to `/waitlist` — a mass-eviction event. The migration flags
/// these profiles so the onboarding orchestrator forces a one-question
/// US-tax-person re-onboarding on the next session — `CoachProfile` then
/// resolves the fresh FATCA signal and the archetype derives normally
/// from real user input.
///
/// **Codex C1 HIGH (REVIEWS.md 2026-05-22) — data-truth boundary:**
/// the previous draft of this plan wrote `nationality='CH'` to legacy
/// null-nationality profiles. That is the exact class of data-truth
/// corruption sub-phase 01.5 is designed to PREVENT — writing CH to a
/// user who didn't declare it is the bug-class this phase exists to
/// close. The migration is FLAG-ONLY: it sets a SharedPreferences flag
/// (`coachProfile:needsUsTaxPersonReOnboarding`) and never writes any
/// value to the profile's nationality field. The orchestrator reads the
/// flag BEFORE archetype detection and routes to the US-tax-person Q
/// step (plan 03 Task 1). Once the Q is answered, the screen calls
/// `clearReOnboardingFlag()` and the archetype getter resolves from the
/// fresh user-declared FATCA signal.
///
/// **Idempotent:** protected by `coachProfile:migration_01_5_done`.
/// Once set, subsequent calls early-return (no rewrite of the
/// re-onboarding flag, no profile reads).
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../providers/coach_profile_provider.dart';

class ProfileMigrationService {
  ProfileMigrationService({SharedPreferences? prefs})
      : _prefsOverride = prefs;

  final SharedPreferences? _prefsOverride;

  /// Idempotency flag — once set, subsequent migration calls early-return.
  static const String _doneFlag = 'coachProfile:migration_01_5_done';

  /// Re-onboarding flag — read by the orchestrator's pre-archetype guard
  /// (plan 03 Task 2) and cleared by the US-tax-person screen on answer
  /// (plan 03 Task 1).
  static const String _reOnboardFlag =
      'coachProfile:needsUsTaxPersonReOnboarding';

  Future<SharedPreferences> _prefs() async {
    return _prefsOverride ?? await SharedPreferences.getInstance();
  }

  /// Flag a legacy-ambiguous profile for forced US-tax-person re-onboarding
  /// on the next session.
  ///
  /// Returns `true` iff this call FLAGGED a legacy profile for re-onboarding.
  /// Returns `false` if the migration was a no-op (already done, no cached
  /// profile, or profile already carries a discriminating signal).
  ///
  /// **No nationality rewrite — flag-based only.** See class doc for the
  /// Codex C1 HIGH rationale.
  Future<bool> grandfatherLegacyProfile({
    required CoachProfileProvider provider,
  }) async {
    final prefs = await _prefs();

    // Idempotency: previous migration already ran.
    if (prefs.getBool(_doneFlag) == true) {
      return false;
    }

    final profile = provider.profile;
    if (profile == null) {
      // First-launch user with no cached profile — nothing to grandfather.
      // Set the done flag so we don't re-check on every cold start.
      await prefs.setBool(_doneFlag, true);
      return false;
    }

    // Only grandfather profiles that are ambiguous on BOTH FATCA signals
    // (usTaxPerson) AND nationality. Any positive signal means the user
    // already provided a discriminating input — the gate will fire
    // correctly for them via the plan 02-01 archetype getter.
    final isLegacyAmbiguous =
        profile.usTaxPerson == null && profile.nationality == null;
    if (!isLegacyAmbiguous) {
      await prefs.setBool(_doneFlag, true);
      return false;
    }

    // Codex C1 HIGH fix (REVIEWS.md 2026-05-22): FLAG ONLY. Do NOT write
    // any value to the profile's nationality field. The orchestrator's
    // pre-archetype guard (plan 03 Task 2) reads `_reOnboardFlag` and
    // routes to the US-tax-person Q step BEFORE archetype detection.
    // Once answered, the archetype getter resolves from the fresh
    // user-declared FATCA signal (usTaxPerson and/or nationality).
    await prefs.setBool(_reOnboardFlag, true);
    await prefs.setBool(_doneFlag, true);
    return true;
  }

  /// Read by the orchestrator's pre-archetype guard (plan 03 Task 2) to
  /// detect whether a returning legacy user must answer the FATCA Q now.
  Future<bool> needsUsTaxPersonReOnboarding() async {
    final prefs = await _prefs();
    return prefs.getBool(_reOnboardFlag) ?? false;
  }

  /// Called by the US-tax-person screen (plan 03 Task 1) AFTER the user
  /// answers the FATCA Q. Idempotent — safe to call when the flag is
  /// already absent.
  Future<void> clearReOnboardingFlag() async {
    final prefs = await _prefs();
    await prefs.remove(_reOnboardFlag);
  }
}
