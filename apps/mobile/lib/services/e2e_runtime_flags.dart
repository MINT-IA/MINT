import 'package:flutter/foundation.dart';

class E2eRuntimeFlags {
  E2eRuntimeFlags._();

  @visibleForTesting
  static bool? proofAnchorsOverride;

  @visibleForTesting
  static bool? mint2FirstExperienceEntryOverride;

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

  @visibleForTesting
  static void resetForTest() {
    proofAnchorsOverride = null;
    mint2FirstExperienceEntryOverride = null;
  }
}
