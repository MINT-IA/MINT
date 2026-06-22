import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/services/debug/mint_debug_spine_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:patrol/patrol.dart';

const _runningFromPatrolCli = bool.hasEnvironment('PATROL_APP_BUNDLE_ID') ||
    bool.hasEnvironment('PATROL_TEST_LABEL') ||
    bool.hasEnvironment('PATROL_WAIT');

const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
const _adminFlag = String.fromEnvironment(
  'ENABLE_ADMIN',
  defaultValue: 'false',
);
const _debugToolsFlag = String.fromEnvironment(
  'ENABLE_DEBUG_TOOLS',
  defaultValue: 'false',
);
const _adminEnabled = _adminFlag == 'true' || _adminFlag == '1';
const _debugToolsEnabled = _debugToolsFlag == 'true' || _debugToolsFlag == '1';
const _disableBetaModal = bool.fromEnvironment('MINT_DISABLE_BETA_MODAL');
const _mint2FirstExperience =
    bool.fromEnvironment('MINT_E2E_MINT2_FIRST_EXPERIENCE');
const _proofAnchors = bool.fromEnvironment('MINT_E2E_PROOF_ANCHORS');

void main() {
  patrolTest(
    'launches Mint and exposes redacted Debug Spine JSON',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 2)),
    ($) async {
      expect(_apiBaseUrl, isNotEmpty);
      expect(_disableBetaModal, isTrue);
      expect(_mint2FirstExperience, isTrue);
      expect(_proofAnchors, isTrue);
      expect(_adminEnabled, isTrue);
      expect(_debugToolsEnabled, isTrue);

      FeatureFlags.applyRuntimeOverrides();

      // Patrol docs require pumping the app widget instead of calling main().
      // main() owns runApp/Sentry/error-boundary setup that hides test failures.
      await $.pumpWidgetAndSettle(const MintApp());

      final redacted = await MintDebugSpineService.loadRedactedJson();
      final residue = redacted['residue']! as Map<String, Object?>;
      final encoded = json.encode(redacted);

      expect(redacted['schemaVersion'], MintDebugSpineSnapshot.schemaVersion);
      expect(residue.keys, contains('wizardAnswers'));
      expect(residue.keys, contains('budgetInputs'));
      expect(residue.keys, contains('networkSummary'));
      expect(encoded, isNot(contains('q_net_income_period_chf')));
      expect(encoded, isNot(contains('CHF')));
      expect(encoded, isNot(contains('Authorization')));
      expect(encoded, isNot(contains('token')));
      expect(encoded, isNot(contains('@')));
    },
  );
}
