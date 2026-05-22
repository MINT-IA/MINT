/// R4 (Codex) — observability for the sub-phase 01.5 archetype HARD GATE.
///
/// Records every gate evaluation with the signal-state breakdown + the
/// resolved archetype so dashboards can detect:
///   - unexpected pass-through (gate did NOT fire when it should have)
///   - mass false-positive (high gate_fired rate on swiss_native users)
///   - kill-switch bypass volume
///   - legacy-grandfathered cohort migration churn (Codex C1 + Gemini
///     dashboard suggestion — `legacy_grandfathered` tag)
///
/// Sentry metrics API path uses `Sentry.metrics.count(name, value,
/// attributes: ...)` (sentry_flutter 9.14.0 surface — `count` is the
/// counter primitive in 9.x; the legacy 7.x `increment` API was renamed
/// upstream). Fallback breadcrumb is emitted on plugin init failure so
/// the telemetry contract still ships even when the metrics surface is
/// unavailable. W3 fix (2026-05-22): `pubspec.yaml` pins
/// `sentry_flutter: 9.14.0`, so the metrics API IS available — the
/// try/catch is defense-in-depth, not API-presence detection.
///
/// **PII contract:** tags only carry boolean-shaped strings (`'null'`,
/// `'set'`, `'true'`, `'false'`) + archetype slug + the
/// `legacy_grandfathered` cohort marker. No email, no salary, no canton,
/// no name. T-01.5-53 mitigation.
library;

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../models/coach_profile.dart';
import '../profile_migration_service.dart';

class GateDecisionTelemetry {
  /// Test-only observable hook for the emitted counter. When set, the
  /// production Sentry path is bypassed and the hook receives the
  /// metric `name` + the resolved `attributes` map (already stringified
  /// to `Map<String, String>` for assertion ergonomics). Same pattern
  /// as `FeatureFlags.debugCoachHardGateWarningHook` (plan 02-04).
  ///
  /// Production path is unchanged when the hook is null.
  @visibleForTesting
  static void Function(String name, Map<String, String> attributes)?
      debugRecorderHook;

  /// Metric name surfaced in Sentry — Codex R4 contract. Stable string;
  /// dashboard breakdowns key off `archetype` + `legacy_grandfathered`.
  static const String metricName = 'gate_decision_by_signal_state';

  /// Records one gate decision. Awaits the SharedPreferences read of
  /// the legacy re-onboarding flag (`legacy_grandfathered` cohort
  /// signal); the actual metric emission is non-blocking. Fire-and-forget
  /// from the caller is safe — failures inside the metrics surface are
  /// caught and routed to a breadcrumb fallback.
  static Future<void> recordDecision({
    required CoachProfile profile,
    required FinancialArchetype computedArchetype,
    required bool gateFired,
    required bool killSwitchEnabled,
  }) async {
    final isLegacyGrandfathered =
        await ProfileMigrationService().needsUsTaxPersonReOnboarding();

    final attributes = <String, String>{
      'archetype': computedArchetype.backendName,
      'gate_fired': gateFired.toString(),
      'kill_switch_enabled': killSwitchEnabled.toString(),
      'signal_us_tax_person': _stateLabel(profile.usTaxPerson),
      'signal_nationality': profile.nationality == null ? 'null' : 'set',
      'signal_residence_permit':
          profile.residencePermit == null ? 'null' : 'set',
      // employmentStatus is non-null on the model (default 'salarie'),
      // so we report whether it is the empty / default sentinel.
      'signal_employment_status':
          profile.employmentStatus.isEmpty ? 'null' : 'set',
      'signal_arrival_age': profile.arrivalAge == null ? 'null' : 'set',
      'legacy_grandfathered': isLegacyGrandfathered.toString(),
    };

    final hook = debugRecorderHook;
    if (hook != null) {
      hook(metricName, attributes);
      return;
    }

    try {
      Sentry.metrics.count(
        metricName,
        1,
        attributes: attributes.map(
          (k, v) => MapEntry(k, SentryAttribute.string(v)),
        ),
      );
    } catch (_) {
      // Defense-in-depth: fallback breadcrumb keeps observability if the
      // metrics surface fails to init. Plugin init failures, sentry SDK
      // not started in dev / tests, etc.
      try {
        Sentry.addBreadcrumb(Breadcrumb(
          category: 'gate.decision',
          message: metricName,
          data: attributes,
          level: SentryLevel.info,
        ));
      } catch (_) {
        // Sentry SDK is not initialised at all (e.g. in a unit test that
        // didn't set the hook either). Silent swallow — telemetry must
        // never block a gate evaluation. T-01.5-54 mitigation.
      }
    }
  }

  static String _stateLabel(bool? signal) {
    if (signal == null) return 'null';
    return signal ? 'true' : 'false';
  }
}
