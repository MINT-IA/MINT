// Dev-only admin surface per D-03 + D-10 (CONTEXT v4).
// English-only by executor discretion — no i18n/ARB keys.
// Phase 34 no_hardcoded_fr.py MUST exempt lib/screens/admin/**
// (TODO: add exemption when Phase 34 plan ships lint-config.yaml).

/// Phase 32 D-03 + D-10 — AdminGate compile-time + runtime check.
///
/// `/admin/*` routes are ONLY mounted when:
///   1. Compile-time: `flutter build ... --dart-define=ENABLE_ADMIN=1` (default 0 = prod).
///   2. Runtime: `FeatureFlags.isAdmin` returns true.
///
/// Both gates are LOCAL — no backend `/admin/me` endpoint (D-10 v4).
/// Phase 33 may add an admin backend endpoint if multi-user admin is needed.
library;

import 'package:mint_mobile/services/feature_flags.dart';

class AdminGate {
  AdminGate._();

  /// Compile-time branch — dead-code-eliminated when false.
  /// Visible to reviewers as `const`, enabling Dart's tree-shake.
  static const bool _compileTimeEnabled =
      bool.fromEnvironment('ENABLE_ADMIN', defaultValue: false);

  /// Both gates must be true. Runtime FeatureFlags.isAdmin is the
  /// second line; compile-time is the tree-shake guarantee.
  static bool get isAvailable => _compileTimeEnabled && FeatureFlags.isAdmin;
}
