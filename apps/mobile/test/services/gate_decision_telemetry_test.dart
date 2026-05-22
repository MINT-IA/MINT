// Sub-phase 01.5 W02-T05 Task 2 — gate_decision_by_signal_state telemetry.
//
// R4 (Codex) observability counter. Records every gate evaluation with
// the signal-state breakdown + the resolved archetype so we can detect:
//   - unexpected pass-through (gate did NOT fire when it should have)
//   - mass false-positive (high gate_fired rate on swiss_native users)
//   - kill-switch bypass volume
//   - legacy-grandfathered cohort migration churn
//
// We expose a test-only `debugRecorderHook` to capture the emitted
// attribute map without mocking sentry_flutter (same pattern as
// FeatureFlags.debugCoachHardGateWarningHook from plan 02-04).

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/telemetry/gate_decision_telemetry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GateDecisionTelemetry.recordDecision', () {
    setUp(() {
      // Fresh SharedPreferences for each test — needed because
      // GateDecisionTelemetry consults the legacy re-onboarding flag.
      SharedPreferences.setMockInitialValues({});
      GateDecisionTelemetry.debugRecorderHook = null;
    });

    tearDown(() {
      GateDecisionTelemetry.debugRecorderHook = null;
    });

    /// Helper — build a CoachProfile with explicit FATCA signal shape.
    /// Uses [CoachProfile.defaults] + copyWith to avoid hardcoding the full
    /// required-field set (mirrors CoachProfile.fromWizardAnswers behavior).
    CoachProfile _profile({
      String? nationality,
      bool? usTaxPerson,
      String? residencePermit,
      String? employmentStatus,
      int? arrivalAge,
    }) {
      return CoachProfile.defaults().copyWith(
        nationality: nationality,
        usTaxPerson: usTaxPerson,
        residencePermit: residencePermit,
        employmentStatus: employmentStatus,
        arrivalAge: arrivalAge,
      );
    }

    test(
      'telemetry_records_decision_swiss_native '
      '(nationality=CH → archetype=swiss_native, gate does NOT fire)',
      () async {
        final captured = <Map<String, String>>[];
        GateDecisionTelemetry.debugRecorderHook = (name, attrs) {
          expect(name, 'gate_decision_by_signal_state');
          captured.add(Map<String, String>.from(attrs));
        };

        final p = _profile(nationality: 'CH');
        await GateDecisionTelemetry.recordDecision(
          profile: p,
          computedArchetype: p.archetype,
          gateFired: false,
          killSwitchEnabled: true,
        );

        expect(captured, hasLength(1));
        expect(captured.single['archetype'], 'swiss_native');
        expect(captured.single['gate_fired'], 'false');
        expect(captured.single['signal_nationality'], 'set');
        expect(captured.single['signal_us_tax_person'], 'null');
        expect(captured.single['legacy_grandfathered'], 'false');
      },
    );

    test(
      'telemetry_records_decision_expat_us '
      '(usTaxPerson=true → archetype=expat_us, gate fires)',
      () async {
        final captured = <Map<String, String>>[];
        GateDecisionTelemetry.debugRecorderHook = (name, attrs) {
          captured.add(Map<String, String>.from(attrs));
        };

        final p = _profile(usTaxPerson: true);
        await GateDecisionTelemetry.recordDecision(
          profile: p,
          computedArchetype: p.archetype,
          gateFired: true,
          killSwitchEnabled: true,
        );

        expect(captured, hasLength(1));
        expect(captured.single['archetype'], 'expat_us');
        expect(captured.single['gate_fired'], 'true');
        expect(captured.single['signal_us_tax_person'], 'true');
      },
    );

    test(
      'telemetry_records_decision_unknown '
      '(all signals null → archetype=unknown, gate fires)',
      () async {
        final captured = <Map<String, String>>[];
        GateDecisionTelemetry.debugRecorderHook = (name, attrs) {
          captured.add(Map<String, String>.from(attrs));
        };

        final p = _profile();
        await GateDecisionTelemetry.recordDecision(
          profile: p,
          computedArchetype: p.archetype,
          gateFired: true,
          killSwitchEnabled: true,
        );

        expect(captured, hasLength(1));
        expect(captured.single['archetype'], 'unknown');
        expect(captured.single['gate_fired'], 'true');
        expect(captured.single['signal_us_tax_person'], 'null');
        expect(captured.single['signal_nationality'], 'null');
        expect(captured.single['legacy_grandfathered'], 'false');
      },
    );

    test(
      'telemetry_records_decision_kill_switch_disabled '
      '(killSwitchEnabled=false is recorded as a tag even though the '
      'redirect is bypassed)',
      () async {
        final captured = <Map<String, String>>[];
        GateDecisionTelemetry.debugRecorderHook = (name, attrs) {
          captured.add(Map<String, String>.from(attrs));
        };

        final p = _profile(usTaxPerson: true);
        await GateDecisionTelemetry.recordDecision(
          profile: p,
          computedArchetype: p.archetype,
          gateFired: false, // kill switch off → no redirect
          killSwitchEnabled: false,
        );

        expect(captured, hasLength(1));
        expect(captured.single['kill_switch_enabled'], 'false');
        expect(captured.single['gate_fired'], 'false',
            reason: 'gate_fired tracks the actual redirect, not the policy '
                'decision; when the kill switch is off, gate_fired=false');
      },
    );

    test(
      'telemetry_records_decision_legacy_grandfathered '
      '(needsUsTaxPersonReOnboarding=true → legacy_grandfathered=true '
      'in tags, dashboard can distinguish natural vs migrated gates — '
      'Codex C1 cohort tracking)',
      () async {
        // Pre-set the re-onboarding flag — this is what
        // ProfileMigrationService.grandfatherLegacyProfile writes.
        SharedPreferences.setMockInitialValues({
          'coachProfile:needsUsTaxPersonReOnboarding': true,
        });

        final captured = <Map<String, String>>[];
        GateDecisionTelemetry.debugRecorderHook = (name, attrs) {
          captured.add(Map<String, String>.from(attrs));
        };

        // Legacy ambiguous profile (all signals null → unknown).
        final p = _profile();
        await GateDecisionTelemetry.recordDecision(
          profile: p,
          computedArchetype: p.archetype,
          gateFired: true,
          killSwitchEnabled: true,
        );

        expect(captured, hasLength(1));
        expect(captured.single['archetype'], 'unknown');
        expect(captured.single['legacy_grandfathered'], 'true',
            reason: 'Migrated legacy cohort MUST be distinguishable from '
                'natural all-signals-null users so we can monitor churn');
      },
    );
  });
}
