import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/services/preview_shell_policy.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/profile_drawer.dart';

/// Persistent 4-tab shell: Aujourd'hui | Mon argent | Coach | Explorer.
///
/// Navigation V11 — Shell scaffold with Material 3 NavigationBar and
/// ProfileDrawer mounted as endDrawer. Each tab preserves state via
/// [StatefulShellRoute.indexedStack].
///
/// Phase 96 D-01 — when `FeatureFlags.chatTabVisible` is `false`, the
/// Coach destination is dropped from the NavigationBar (3-tab nav). The
/// GoRouter StatefulShellRoute branch list stays at length 4 so the
/// Coach route remains addressable via MintChatOverlay. The
/// [visibleToBranchIndex] + [branchToVisibleIndex] helpers below
/// translate between the user-facing slot index and the GoRouter
/// branch index — this is the #1 pitfall per 96-RESEARCH.md.
class MintShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MintShell({required this.navigationShell, super.key});

  /// Open the ProfileDrawer from any descendant widget.
  ///
  /// Screens that want a profile icon in their AppBar call this:
  /// ```dart
  /// IconButton(
  ///   icon: const Icon(Icons.person_outline),
  ///   onPressed: () => MintShell.openDrawer(context),
  /// )
  /// ```
  static void openDrawer(BuildContext context) {
    Scaffold.of(context).openEndDrawer();
  }

  /// Branch-index that the GoRouter shell hosts for the Coach tab.
  /// Stays at 2 regardless of the flag — branches list length is 4.
  static const int _coachBranchIndex = 2;

  /// Map a NavigationBar visible slot to the GoRouter branch index.
  ///
  /// When `FeatureFlags.chatTabVisible` is `true`, identity.
  /// When `false`, the Coach branch is hidden — visible slot 2
  /// (Explorer) maps to branch 3.
  /// Coque préversion : le coach est masqué par la politique en plus du
  /// flag runtime ; l'explorer (dernière branche) est masqué sans décaler
  /// les index précédents.
  static bool get _showCoachTab =>
      FeatureFlags.chatTabVisible &&
      PreviewShellPolicy.instance.showCoachTab;

  static int visibleToBranchIndex(int visibleIndex) {
    if (_showCoachTab) return visibleIndex;
    return visibleIndex >= _coachBranchIndex
        ? visibleIndex + 1
        : visibleIndex;
  }

  /// Map a GoRouter branch index to the NavigationBar visible slot.
  ///
  /// When `FeatureFlags.chatTabVisible` is `true`, identity.
  /// When `false`, the Coach branch (index 2) collapses onto the
  /// nearest preceding visible slot (Mon argent, visible 1) so the
  /// NavigationBar selectedIndex never points off-list when Coach is
  /// the active branch (e.g. when MintChatOverlay routes to Coach
  /// while the Coach tab is hidden).
  static int branchToVisibleIndex(int branchIndex) {
    if (_showCoachTab) return branchIndex;
    if (branchIndex == _coachBranchIndex) return _coachBranchIndex - 1;
    return branchIndex > _coachBranchIndex ? branchIndex - 1 : branchIndex;
  }

  static Widget _tabIcon({
    required String identifier,
    required IconData icon,
    Color? color,
  }) {
    return Semantics(
      identifier: identifier,
      child: Icon(icon, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      endDrawer: const ProfileDrawer(),
      bottomNavigationBar: Builder(
        builder: (ctx) {
          final l = S.of(ctx)!;
          final showChatTab = _showCoachTab;
          final destinations = <NavigationDestination>[
            NavigationDestination(
              icon: _tabIcon(
                identifier: 'nav_tab_aujourdhui',
                icon: Icons.today_outlined,
              ),
              selectedIcon: _tabIcon(
                identifier: 'nav_tab_aujourdhui',
                icon: Icons.today,
                color: MintColors.success,
              ),
              label: l.tabAujourdhui,
            ),
            NavigationDestination(
              icon: _tabIcon(
                identifier: 'nav_tab_mon_argent',
                icon: Icons.savings_outlined,
              ),
              selectedIcon: _tabIcon(
                identifier: 'nav_tab_mon_argent',
                icon: Icons.savings,
                color: MintColors.success,
              ),
              label: l.tabMonArgent,
            ),
            if (showChatTab)
              NavigationDestination(
                icon: _tabIcon(
                  identifier: 'nav_tab_coach',
                  icon: Icons.chat_bubble_outline,
                ),
                selectedIcon: _tabIcon(
                  identifier: 'nav_tab_coach',
                  icon: Icons.chat_bubble,
                  color: MintColors.success,
                ),
                label: l.tabCoach,
              ),
            if (PreviewShellPolicy.instance.showExplorerTab)
            NavigationDestination(
              icon: _tabIcon(
                identifier: 'nav_tab_explorer',
                icon: Icons.explore_outlined,
              ),
              selectedIcon: _tabIcon(
                identifier: 'nav_tab_explorer',
                icon: Icons.explore,
                color: MintColors.success,
              ),
              label: l.tabExplorer,
            ),
          ];
          return NavigationBar(
            selectedIndex: branchToVisibleIndex(navigationShell.currentIndex),
            onDestinationSelected: (visibleIndex) {
              final branchIndex = visibleToBranchIndex(visibleIndex);
              navigationShell.goBranch(
                branchIndex,
                initialLocation: branchIndex == navigationShell.currentIndex,
              );
            },
            backgroundColor: MintColors.craie,
            indicatorColor: MintColors.success.withValues(alpha: 0.12),
            destinations: destinations,
          );
        },
      ),
    );
  }
}
