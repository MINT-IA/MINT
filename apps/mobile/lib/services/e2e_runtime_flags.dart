import 'package:flutter/foundation.dart';

class E2eRuntimeFlags {
  E2eRuntimeFlags._();

  @visibleForTesting
  static bool? proofAnchorsOverride;

  static bool get proofAnchors {
    if (kReleaseMode) return false;
    return proofAnchorsOverride ??
        const bool.fromEnvironment(
          'MINT_E2E_PROOF_ANCHORS',
          defaultValue: false,
        );
  }

  @visibleForTesting
  static void resetForTest() {
    proofAnchorsOverride = null;
  }
}
