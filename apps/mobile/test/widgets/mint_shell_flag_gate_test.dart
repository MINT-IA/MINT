// Phase 96 D-01 + D-02 — MintShell flag-gated NavigationBar tests.
//
// Validates the visible-index ↔ branch-index remap when
// FeatureFlags.chatTabVisible toggles. The GoRouter StatefulShellRoute
// branch list stays at length 4 (CoachChatScreen stays registered, D-02);
// only the NavigationBar.destinations list collapses to 3 when the flag
// is false. T-96-W1-NavDrift mitigation.
//
// The visible-index → branch-index remap is the #1 pitfall per
// 96-RESEARCH.md. We expose it as a pure function on MintShell so the
// test can assert correctness without constructing a real
// StatefulNavigationShell (GoRouter-internal type, not trivially
// instantiable in widget tests).

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/widgets/mint_shell.dart';

void main() {
  group('MintShell visible↔branch index remap', () {
    setUp(() {
      FeatureFlags.chatTabVisible = true;
    });

    test('flag=true: visibleToBranch is identity (0→0, 1→1, 2→2, 3→3)', () {
      FeatureFlags.chatTabVisible = true;
      expect(MintShell.visibleToBranchIndex(0), 0);
      expect(MintShell.visibleToBranchIndex(1), 1);
      expect(MintShell.visibleToBranchIndex(2), 2);
      expect(MintShell.visibleToBranchIndex(3), 3);
    });

    test(
      'flag=false: visibleToBranch skips Coach branch '
      '(0→0, 1→1, 2→3)',
      () {
        FeatureFlags.chatTabVisible = false;
        expect(MintShell.visibleToBranchIndex(0), 0);
        expect(MintShell.visibleToBranchIndex(1), 1);
        // visible-index 2 (Explorer) → GoRouter branch-index 3.
        expect(MintShell.visibleToBranchIndex(2), 3);
      },
    );

    test('flag=true: branchToVisible is identity', () {
      FeatureFlags.chatTabVisible = true;
      expect(MintShell.branchToVisibleIndex(0), 0);
      expect(MintShell.branchToVisibleIndex(1), 1);
      expect(MintShell.branchToVisibleIndex(2), 2);
      expect(MintShell.branchToVisibleIndex(3), 3);
    });

    test(
      'flag=false: branchToVisible folds Coach branch out '
      '(branch 3 Explorer → visible 2)',
      () {
        FeatureFlags.chatTabVisible = false;
        expect(MintShell.branchToVisibleIndex(0), 0);
        expect(MintShell.branchToVisibleIndex(1), 1);
        // Branch-index 2 (Coach) is invisible when flag=false. The remap
        // clamps it onto the nearest visible neighbour (visible 1, Mon
        // Argent) so the NavigationBar selectedIndex never points off-list.
        expect(MintShell.branchToVisibleIndex(2), 1);
        expect(MintShell.branchToVisibleIndex(3), 2);
      },
    );

    test('round-trip identity for every visible index when flag=false', () {
      FeatureFlags.chatTabVisible = false;
      for (var visible = 0; visible < 3; visible++) {
        final branch = MintShell.visibleToBranchIndex(visible);
        expect(MintShell.branchToVisibleIndex(branch), visible,
            reason: 'round-trip should be identity for visible=$visible');
      }
    });
  });
}
