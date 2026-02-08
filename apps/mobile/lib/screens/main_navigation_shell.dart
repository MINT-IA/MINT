import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/screens/main_tabs/now_tab.dart';
import 'package:mint_mobile/screens/main_tabs/explore_tab.dart';
import 'package:mint_mobile/screens/main_tabs/track_tab.dart';
import 'package:mint_mobile/widgets/mentor_fab.dart';

/// Shell principal de navigation MINT
///
/// Architecture révolutionnaire : 3 tabs situation-centrés + FAB Mentor
/// - MAINTENANT : Actions contextuelles selon la situation
/// - EXPLORER : Objectifs de vie et simulateurs
/// - SUIVRE : Progrès et achievements
/// - MENTOR : Compagnon toujours accessible (FAB)
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    NowTab(),
    ExploreTab(),
    TrackTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Contenu du tab actif
          IndexedStack(
            index: _currentIndex,
            children: _tabs,
          ),

          // FAB Mentor (toujours visible)
          const Positioned(
            right: 20,
            bottom: 90,
            child: MentorFAB(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.bolt_outlined,
                activeIcon: Icons.bolt,
                label: S.of(context)?.tabNow ?? 'MAINTENANT',
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore,
                label: S.of(context)?.tabExplore ?? 'EXPLORER',
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.insights_outlined,
                activeIcon: Icons.insights,
                label: S.of(context)?.tabTrack ?? 'SUIVRE',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isActive = _currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? MintColors.primary : MintColors.textMuted,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? MintColors.primary : MintColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
