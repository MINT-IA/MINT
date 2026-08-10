import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/e2e_runtime_flags.dart';

void main() {
  tearDown(E2eRuntimeFlags.resetForTest);

  test('runtime E2E flags stay off by default in tests', () {
    E2eRuntimeFlags.resetForTest();

    expect(E2eRuntimeFlags.proofAnchors, isFalse);
    expect(E2eRuntimeFlags.mint2FirstExperienceEntry, isFalse);
    expect(E2eRuntimeFlags.mintNext3aHarness, isFalse);
    expect(E2eRuntimeFlags.mintNext3aRemoteFlag, isNull);
    expect(E2eRuntimeFlags.mintNext3aScenario, isEmpty);
    expect(E2eRuntimeFlags.mintNext3aLeg, isEmpty);
    expect(E2eRuntimeFlags.mintNext3aFlagOffLeg, isEmpty);
    expect(E2eRuntimeFlags.mintNext3aForceScenarioFailure, isFalse);
    expect(E2eRuntimeFlags.mintNextHousing, isFalse);
  });

  test('Mint Next housing harness is explicit and resettable', () {
    E2eRuntimeFlags.mintNextHousingOverride = true;
    expect(E2eRuntimeFlags.mintNextHousing, isTrue);

    E2eRuntimeFlags.resetForTest();
    expect(E2eRuntimeFlags.mintNextHousing, isFalse);
  });

  test('runtime E2E flags can be overridden by focused tests', () {
    E2eRuntimeFlags.proofAnchorsOverride = true;
    E2eRuntimeFlags.mint2FirstExperienceEntryOverride = true;

    expect(E2eRuntimeFlags.proofAnchors, isTrue);
    expect(E2eRuntimeFlags.mint2FirstExperienceEntry, isTrue);
  });

  test('Mint Next 3a harness values are bounded and resettable', () {
    E2eRuntimeFlags.mintNext3aHarnessOverride = true;
    E2eRuntimeFlags.mintNext3aRemoteFlagOverride = false;
    E2eRuntimeFlags.mintNext3aScenarioOverride = 'safe_exit_no_save';
    E2eRuntimeFlags.mintNext3aLegOverride = 'single';

    expect(E2eRuntimeFlags.mintNext3aHarness, isTrue);
    expect(E2eRuntimeFlags.mintNext3aRemoteFlag, isFalse);
    expect(E2eRuntimeFlags.mintNext3aScenario, 'safe_exit_no_save');
    expect(E2eRuntimeFlags.mintNext3aLeg, 'single');

    E2eRuntimeFlags.resetForTest();
    expect(E2eRuntimeFlags.mintNext3aHarness, isFalse);
    expect(E2eRuntimeFlags.mintNext3aRemoteFlag, isNull);
    expect(E2eRuntimeFlags.mintNext3aScenario, isEmpty);
    expect(E2eRuntimeFlags.mintNext3aLeg, isEmpty);
  });

  test('unknown Mint Next 3a scenario fails closed', () {
    E2eRuntimeFlags.mintNext3aScenarioOverride = 'dump_profile';

    expect(E2eRuntimeFlags.mintNext3aScenario, isEmpty);
  });

  test('hostile cleanup selectors are bounded and resettable', () {
    E2eRuntimeFlags.mintNext3aScenarioOverride =
        'cleanup_after_forced_scenario_failure';
    E2eRuntimeFlags.mintNext3aForceScenarioFailureOverride = true;

    expect(
      E2eRuntimeFlags.mintNext3aScenario,
      'cleanup_after_forced_scenario_failure',
    );
    expect(E2eRuntimeFlags.mintNext3aForceScenarioFailure, isTrue);

    E2eRuntimeFlags.resetForTest();
    expect(E2eRuntimeFlags.mintNext3aScenario, isEmpty);
    expect(E2eRuntimeFlags.mintNext3aForceScenarioFailure, isFalse);
  });

  test('Mint Next 3a inherited-state legs are explicitly bounded', () {
    for (final leg in const {
      'fresh_saved_read',
      'post_delete_absence',
    }) {
      E2eRuntimeFlags.mintNext3aLegOverride = leg;
      expect(E2eRuntimeFlags.mintNext3aLeg, leg);
    }
  });

  test('unknown Mint Next 3a leg fails closed', () {
    E2eRuntimeFlags.mintNext3aLegOverride = 'dump_profile';

    expect(E2eRuntimeFlags.mintNext3aLeg, isEmpty);
  });

  test('Mint Next 3a flag-off legs are separately bounded and resettable', () {
    for (final leg in const {
      'seed_on',
      'delete_only_off',
      'fresh_absence_off',
    }) {
      E2eRuntimeFlags.mintNext3aFlagOffLegOverride = leg;
      expect(E2eRuntimeFlags.mintNext3aFlagOffLeg, leg);
    }

    E2eRuntimeFlags.resetForTest();
    expect(E2eRuntimeFlags.mintNext3aFlagOffLeg, isEmpty);
  });

  test('unknown Mint Next 3a flag-off leg fails closed', () {
    E2eRuntimeFlags.mintNext3aFlagOffLegOverride = 'dump_profile';

    expect(E2eRuntimeFlags.mintNext3aFlagOffLeg, isEmpty);
  });
}
