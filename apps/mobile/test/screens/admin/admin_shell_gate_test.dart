// Phase 32 Wave 0 stub — MAP-02b gate: ENABLE_ADMIN=1 AND FeatureFlags.isAdmin.
// Implementation: Plan 32-03 Wave 3.
//
// Two gates must both be true for /admin/routes to mount (D-10):
//   1. Compile-time: --dart-define=ENABLE_ADMIN=1 (tree-shakes registry in prod)
//   2. Runtime: FeatureFlags.isAdmin returns true
// Either gate false -> AdminGate.isAvailable == false, route returns 404.
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminGate (MAP-02b, D-10)', () {
    test('AdminGate.isAvailable=false when ENABLE_ADMIN=0', () {
      // Will assert AdminGate.isAvailable == false when ENABLE_ADMIN compile-time
      // flag is 0 (default for prod builds). Tree-shake VALIDATION in J0 Task 1.
    }, skip: 'Plan 32-03 Wave 3 implements AdminGate');

    test('AdminGate.isAvailable=true only when both compile-time + runtime flags set', () {
      // Will parametric-test the 4 combinations:
      //   (ENABLE_ADMIN=0, isAdmin=false) -> false
      //   (ENABLE_ADMIN=0, isAdmin=true)  -> false  (compile gate wins)
      //   (ENABLE_ADMIN=1, isAdmin=false) -> false  (runtime gate wins)
      //   (ENABLE_ADMIN=1, isAdmin=true)  -> true   (only this combination)
    }, skip: 'Plan 32-03 Wave 3');
  });
}
