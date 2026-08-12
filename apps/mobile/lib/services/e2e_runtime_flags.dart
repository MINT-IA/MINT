import 'package:flutter/foundation.dart';

class E2eRuntimeFlags {
  E2eRuntimeFlags._();

  static const _mintNext3aScenarios = {
    'save_kill_relaunch_fresh_read',
    'delete_kill_relaunch_absent',
    'safe_exit_no_save',
    'cleanup_after_forced_scenario_failure',
  };

  static const _mintNext3aLegs = {
    'save',
    'fresh_saved_read',
    'delete',
    'post_delete_absence',
    'single',
  };

  static const _mintNext3aFlagOffLegs = {
    'seed_on',
    'delete_only_off',
    'fresh_absence_off',
  };

  @visibleForTesting
  static bool? proofAnchorsOverride;

  @visibleForTesting
  static bool? mint2FirstExperienceEntryOverride;

  @visibleForTesting
  static bool? mintNext3aHarnessOverride;

  @visibleForTesting
  static bool? mintNext3aRemoteFlagOverride;

  @visibleForTesting
  static String? mintNext3aScenarioOverride;

  @visibleForTesting
  static String? mintNext3aLegOverride;

  @visibleForTesting
  static String? mintNext3aFlagOffLegOverride;

  @visibleForTesting
  static bool? mintNext3aForceScenarioFailureOverride;

  @visibleForTesting
  static bool? mintNextHousingOverride;

  @visibleForTesting
  static bool? mintNextDomicileOverride;

  @visibleForTesting
  static bool? mintNextEtatCivilOverride;

  @visibleForTesting
  static bool? mintNextRevenuOverride;

  @visibleForTesting
  static bool? mintNextLppAffiliationOverride;

  @visibleForTesting
  static bool? mintNextVersements3aOverride;

  static bool get proofAnchors {
    if (kReleaseMode) return false;
    return proofAnchorsOverride ??
        const bool.fromEnvironment(
          'MINT_E2E_PROOF_ANCHORS',
          defaultValue: false,
        );
  }

  static bool get mint2FirstExperienceEntry {
    if (kReleaseMode) return false;
    return mint2FirstExperienceEntryOverride ??
        const bool.fromEnvironment(
          'MINT_E2E_MINT2_FIRST_EXPERIENCE',
          defaultValue: false,
        );
  }

  static bool get mintNext3aHarness {
    if (kReleaseMode) return false;
    return mintNext3aHarnessOverride ??
        const bool.fromEnvironment(
          'MINT_E2E_MINT_NEXT_3A_HARNESS',
          defaultValue: false,
        );
  }

  static bool? get mintNext3aRemoteFlag {
    if (kReleaseMode) return null;
    if (mintNext3aRemoteFlagOverride != null) {
      return mintNext3aRemoteFlagOverride;
    }
    const value = String.fromEnvironment('MINT_E2E_MINT_NEXT_3A_REMOTE_FLAG');
    return switch (value) {
      'on' => true,
      'off' => false,
      _ => null,
    };
  }

  static String get mintNext3aScenario {
    if (kReleaseMode) return '';
    final value = mintNext3aScenarioOverride ??
        const String.fromEnvironment('MINT_E2E_MINT_NEXT_3A_SCENARIO');
    return _mintNext3aScenarios.contains(value) ? value : '';
  }

  static String get mintNext3aLeg {
    if (kReleaseMode) return '';
    final value = mintNext3aLegOverride ??
        const String.fromEnvironment('MINT_E2E_MINT_NEXT_3A_LEG');
    return _mintNext3aLegs.contains(value) ? value : '';
  }

  static String get mintNext3aFlagOffLeg {
    if (kReleaseMode) return '';
    final value = mintNext3aFlagOffLegOverride ??
        const String.fromEnvironment('MINT_E2E_MINT_NEXT_3A_FLAG_OFF_LEG');
    return _mintNext3aFlagOffLegs.contains(value) ? value : '';
  }

  static bool get mintNext3aForceScenarioFailure {
    if (kReleaseMode) return false;
    return mintNext3aForceScenarioFailureOverride ??
        const bool.fromEnvironment(
          'MINT_E2E_FORCE_SCENARIO_FAILURE',
          defaultValue: false,
        );
  }

  static bool get mintNextHousing {
    if (kReleaseMode) return false;
    return mintNextHousingOverride ??
        const bool.fromEnvironment(
          'MINT_E2E_MINT_NEXT_HOUSING',
          defaultValue: false,
        );
  }

  static bool get mintNextDomicile {
    if (kReleaseMode) return false;
    return mintNextDomicileOverride ??
        const bool.fromEnvironment(
          'MINT_E2E_MINT_NEXT_DOMICILE',
          defaultValue: false,
        );
  }

  static bool get mintNextEtatCivil {
    if (kReleaseMode) return false;
    return mintNextEtatCivilOverride ??
        const bool.fromEnvironment(
          'MINT_E2E_MINT_NEXT_ETAT_CIVIL',
          defaultValue: false,
        );
  }

  static bool get mintNextRevenu {
    if (kReleaseMode) return false;
    return mintNextRevenuOverride ??
        const bool.fromEnvironment(
          'MINT_E2E_MINT_NEXT_REVENU',
          defaultValue: false,
        );
  }

  static bool get mintNextLppAffiliation {
    if (kReleaseMode) return false;
    return mintNextLppAffiliationOverride ??
        const bool.fromEnvironment(
          'MINT_E2E_MINT_NEXT_LPP_AFFILIATION',
          defaultValue: false,
        );
  }

  static bool get mintNextVersements3a {
    if (kReleaseMode) return false;
    return mintNextVersements3aOverride ??
        const bool.fromEnvironment(
          'MINT_E2E_MINT_NEXT_VERSEMENTS_3A',
          defaultValue: false,
        );
  }

  @visibleForTesting
  static bool? mintNextVertical3aOverride;

  static bool get mintNextVertical3a {
    if (kReleaseMode) return false;
    return mintNextVertical3aOverride ??
        const bool.fromEnvironment(
          'MINT_E2E_MINT_NEXT_VERTICAL_3A',
          defaultValue: false,
        );
  }

  @visibleForTesting
  static bool? mintNextMarge3aOverride;

  static bool get mintNextMarge3a {
    if (kReleaseMode) return false;
    return mintNextMarge3aOverride ??
        const bool.fromEnvironment(
          'MINT_E2E_MINT_NEXT_MARGE_3A',
          defaultValue: false,
        );
  }

  @visibleForTesting
  static void resetForTest() {
    proofAnchorsOverride = null;
    mintNextMarge3aOverride = null;
    mintNextVertical3aOverride = null;
    mint2FirstExperienceEntryOverride = null;
    mintNext3aHarnessOverride = null;
    mintNext3aRemoteFlagOverride = null;
    mintNext3aScenarioOverride = null;
    mintNext3aLegOverride = null;
    mintNext3aFlagOffLegOverride = null;
    mintNext3aForceScenarioFailureOverride = null;
    mintNextHousingOverride = null;
    mintNextDomicileOverride = null;
    mintNextEtatCivilOverride = null;
    mintNextRevenuOverride = null;
    mintNextLppAffiliationOverride = null;
    mintNextVersements3aOverride = null;
  }
}
