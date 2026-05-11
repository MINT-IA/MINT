// Phase 96 W3 VERB-06 — chatTabVisible walkback path integration test.
//
// Behavior contract (96-03-PLAN.md §Task 3) :
// - Test 1 — applyFromMap({'chatTabVisible': true}) → 4-tab nav.
// - Test 2 — applyFromMap({'chatTabVisible': false}) → 3-tab nav.
// - Test 3 — full walkback cycle (false → true → false) preserves the
//   final flag state ; the in-flight ConversationStore (existing
//   Provider) is unaffected by flag flips because the flag only
//   changes nav visibility, not the route registration (D-02).
//
// The flag is a static `bool` field on FeatureFlags. MintShell.
// visibleToBranchIndex / branchToVisibleIndex are pure functions over
// the static flag — we assert them directly without mounting a real
// StatefulNavigationShell.

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/widgets/mint_shell.dart';

void main() {
  // Always restore the production default (true) at teardown so other
  // suites don't inherit a flipped state.
  final originalValue = FeatureFlags.chatTabVisible;
  tearDown(() {
    FeatureFlags.chatTabVisible = originalValue;
  });

  group('VERB-06 — chatTabVisible walkback path', () {
    test('Test 1 — applyFromMap(true) flips flag + 4-tab remap holds',
        () {
      FeatureFlags.chatTabVisible = false;
      expect(FeatureFlags.chatTabVisible, isFalse);

      FeatureFlags.applyFromMap(<String, dynamic>{'chatTabVisible': true});

      expect(FeatureFlags.chatTabVisible, isTrue);

      // 4-tab remap : visible index 2 is the (now-visible) Coach
      // branch ; identity mapping when flag is true.
      expect(MintShell.visibleToBranchIndex(0), equals(0));
      expect(MintShell.visibleToBranchIndex(1), equals(1));
      expect(MintShell.visibleToBranchIndex(2), equals(2));
      expect(MintShell.visibleToBranchIndex(3), equals(3));
    });

    test('Test 2 — applyFromMap(false) flips flag + 3-tab remap skips Coach',
        () {
      FeatureFlags.chatTabVisible = true;

      FeatureFlags.applyFromMap(<String, dynamic>{'chatTabVisible': false});

      expect(FeatureFlags.chatTabVisible, isFalse);

      // 3-tab remap : visible index 2 ("Explorer" slot) maps to
      // branch index 3 because Coach (branch 2) is hidden.
      expect(MintShell.visibleToBranchIndex(0), equals(0));
      expect(MintShell.visibleToBranchIndex(1), equals(1));
      expect(MintShell.visibleToBranchIndex(2), equals(3));
    });

    test('Test 3 — walkback (false → true → false) preserves final state',
        () {
      FeatureFlags.chatTabVisible = false;
      FeatureFlags.applyFromMap(<String, dynamic>{'chatTabVisible': true});
      expect(FeatureFlags.chatTabVisible, isTrue);
      FeatureFlags.applyFromMap(<String, dynamic>{'chatTabVisible': false});
      expect(FeatureFlags.chatTabVisible, isFalse);

      // The reverse-remap also walks back : visible index 2 again
      // routes to branch 3 (Explorer), Coach is hidden again.
      expect(MintShell.visibleToBranchIndex(2), equals(3));
      // GoRouter branch index 2 (Coach) is unreachable from the
      // 3-tab nav as its own slot ; per mint_shell.dart:64-66 it
      // collapses onto the nearest preceding visible slot (Mon argent,
      // visible 1) so the NavigationBar selectedIndex never points
      // off-list when MintChatOverlay routes to Coach while the Coach
      // tab is hidden.
      expect(MintShell.branchToVisibleIndex(2), equals(1));
    });

    test('applyFromMap with no chatTabVisible key leaves flag untouched',
        () {
      FeatureFlags.chatTabVisible = false;
      FeatureFlags.applyFromMap(<String, dynamic>{'enableOpenBanking': true});
      expect(FeatureFlags.chatTabVisible, isFalse);
      FeatureFlags.chatTabVisible = true;
      FeatureFlags.applyFromMap(<String, dynamic>{'enableOpenBanking': true});
      expect(FeatureFlags.chatTabVisible, isTrue);
    });

    test('applyFromMap rejects non-bool values (must equal true literal)',
        () {
      FeatureFlags.chatTabVisible = true;
      // The existing applyFromMap convention is strict-equality to `true` ;
      // any non-`true` value flips the flag to `false`.
      FeatureFlags.applyFromMap(<String, dynamic>{'chatTabVisible': 'true'});
      expect(FeatureFlags.chatTabVisible, isFalse);
      FeatureFlags.applyFromMap(<String, dynamic>{'chatTabVisible': 1});
      expect(FeatureFlags.chatTabVisible, isFalse);
    });
  });
}
