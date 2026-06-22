// Phase 32 Plan 03 Wave 3 — live MAP-02b gate test.
//
// Two gates must both be true for /admin/routes to mount (D-10):
//   1. Compile-time: --dart-define=ENABLE_ADMIN=1 (tree-shakes registry in prod)
//   2. Runtime: FeatureFlags.isAdmin returns true
// Either gate false -> AdminGate.isAvailable == false, route not mounted.
//
// Note: `bool.fromEnvironment` constants cannot be overridden at test runtime
// in a single invocation; the ENABLE_ADMIN=1 branch is exercised by running
// `flutter test --dart-define=ENABLE_ADMIN=1 --dart-define=ENABLE_DEBUG_TOOLS=1 test/screens/admin/admin_shell_gate_test.dart`
// (local manual + future CI hook). This default run asserts the prod-default
// false branch, which is the critical tree-shake / T-32-04 contract.
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/screens/admin/admin_gate.dart';
import 'package:mint_mobile/screens/admin/mint_debug_tools_gate.dart';

const _adminFlagValue = String.fromEnvironment(
  'ENABLE_ADMIN',
  defaultValue: 'false',
);
const _debugToolsFlagValue = String.fromEnvironment(
  'ENABLE_DEBUG_TOOLS',
  defaultValue: 'false',
);
const _adminFlagEnabled = _adminFlagValue == 'true' || _adminFlagValue == '1';
const _debugToolsFlagEnabled =
    _debugToolsFlagValue == 'true' || _debugToolsFlagValue == '1';

void main() {
  group('AdminGate (MAP-02b, D-10)', () {
    test('isAvailable is false when ENABLE_ADMIN is unset (prod default)', () {
      if (_adminFlagEnabled) {
        markTestSkipped('enabled-mode run');
        return;
      }
      expect(AdminGate.isAvailable, isFalse);
    });

    test('debug tools are false when ENABLE_DEBUG_TOOLS is unset', () {
      if (_adminFlagEnabled && !_debugToolsFlagEnabled) {
        expect(AdminGate.isAvailable, isTrue);
        expect(MintDebugToolsGate.isAvailable, isFalse);
        return;
      }
      if (_debugToolsFlagEnabled) {
        markTestSkipped('enabled-mode run');
        return;
      }
      expect(MintDebugToolsGate.isAvailable, isFalse);
    });

    test('admin and debug tools are true when compile-time flags are enabled',
        () {
      if (!_adminFlagEnabled || !_debugToolsFlagEnabled) {
        markTestSkipped(
          'run with --dart-define=ENABLE_ADMIN=1 '
          '--dart-define=ENABLE_DEBUG_TOOLS=1',
        );
        return;
      }
      expect(AdminGate.isAvailable, isTrue);
      expect(MintDebugToolsGate.isAvailable, isTrue);
    });
  });
}
