import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/profile_drawer.dart';

/// Persistent 3-tab shell: Aujourd'hui | Coach | Explorer.
///
/// Wire Spec V2 — Shell scaffold with Material 3 NavigationBar and
/// ProfileDrawer mounted as endDrawer. Each tab preserves state via
/// [StatefulShellRoute.indexedStack].
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      endDrawer: const ProfileDrawer(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        backgroundColor: MintColors.craie,
        indicatorColor: MintColors.success.withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today, color: MintColors.success),
            label: "Aujourd'hui",
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble, color: MintColors.success),
            label: 'Coach',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore, color: MintColors.success),
            label: 'Explorer',
          ),
        ],
      ),
    );
  }
}
