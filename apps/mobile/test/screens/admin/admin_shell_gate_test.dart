// Phase 32 Plan 03 Wave 3 — live MAP-02b gate test.
//
// Two gates must both be true for /admin/routes to mount (D-10):
//   1. Compile-time: --dart-define=ENABLE_ADMIN=1 (tree-shakes registry in prod)
//   2. Runtime: FeatureFlags.isAdmin returns true
// Either gate false -> AdminGate.isAvailable == false, route not mounted.
//
// Note: `bool.fromEnvironment` constants cannot be overridden at test runtime
// in a single invocation; the ENABLE_ADMIN=1 branch is exercised by running
// `flutter test --dart-define=ENABLE_ADMIN=1 test/screens/admin/admin_shell_gate_test.dart`
// (local manual + future CI hook). This default run asserts the prod-default
// false branch, which is the critical tree-shake / T-32-04 contract.
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/screens/admin/admin_gate.dart';

void main() {
  group('AdminGate (MAP-02b, D-10)', () {
    test('isAvailable is false when ENABLE_ADMIN is unset (prod default)', () {
      // In test runs, `--dart-define=ENABLE_ADMIN=1` is NOT passed, so
      // `const bool.fromEnvironment('ENABLE_ADMIN', defaultValue: false)`
      // returns false. `AdminGate.isAvailable` is therefore false.
      expect(AdminGate.isAvailable, isFalse);
    });
  });
}
