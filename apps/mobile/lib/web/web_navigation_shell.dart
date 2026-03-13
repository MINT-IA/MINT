import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Sections exposed in the web navigation.
class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });
}

const _navItems = <_NavItem>[
  _NavItem(
    label: 'Accueil',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    route: '/',
  ),
  _NavItem(
    label: 'Simulateurs',
    icon: Icons.calculate_outlined,
    selectedIcon: Icons.calculate,
    route: '/tools',
  ),
  _NavItem(
    label: 'Pr\u00e9voyance',
    icon: Icons.shield_outlined,
    selectedIcon: Icons.shield,
    route: '/coach/dashboard',
  ),
  _NavItem(
    label: '\u00c9ducation',
    icon: Icons.school_outlined,
    selectedIcon: Icons.school,
    route: '/education/hub',
  ),
  _NavItem(
    label: 'Profil',
    icon: Icons.person_outlined,
    selectedIcon: Icons.person,
    route: '/profile',
  ),
];

/// Shell widget for web navigation.
///
/// - On viewports >= 1024 px: a [NavigationRail] sidebar with extended labels.
/// - On viewports < 1024 px: a [NavigationBar] at the bottom.
class WebNavigationShell extends StatelessWidget {
  final Widget child;

  const WebNavigationShell({super.key, required this.child});

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    // Match in reverse order so more specific prefixes win.
    for (int i = _navItems.length - 1; i >= 0; i--) {
      final route = _navItems[i].route;
      if (route == '/' && location == '/') return i;
      if (route != '/' && location.startsWith(route)) return i;
    }
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    context.go(_navItems[index].route);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 1024;
    final selected = _selectedIndex(context);

    if (isWide) {
      return Row(
        children: [
          NavigationRail(
            extended: true,
            backgroundColor: Colors.white,
            selectedIndex: selected,
            onDestinationSelected: (i) => _onTap(context, i),
            indicatorColor: MintColors.appleSurface,
            selectedIconTheme: const IconThemeData(
              color: MintColors.primary,
              size: 24,
            ),
            unselectedIconTheme: const IconThemeData(
              color: MintColors.textSecondary,
              size: 24,
            ),
            selectedLabelTextStyle: const TextStyle(
              color: MintColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            unselectedLabelTextStyle: const TextStyle(
              color: MintColors.textSecondary,
              fontWeight: FontWeight.w400,
              fontSize: 14,
            ),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Text(
                'Mint',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: MintColors.primary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            destinations: [
              for (final item in _navItems)
                NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: Text(item.label),
                ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1, color: MintColors.lightBorder),
          Expanded(child: child),
        ],
      );
    }

    // Narrow layout: bottom navigation
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) => _onTap(context, i),
        backgroundColor: Colors.white,
        indicatorColor: MintColors.appleSurface,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final item in _navItems)
            NavigationDestination(
              icon: Icon(item.icon, color: MintColors.textSecondary),
              selectedIcon: Icon(item.selectedIcon, color: MintColors.primary),
              label: item.label,
            ),
        ],
      ),
    );
  }
}
