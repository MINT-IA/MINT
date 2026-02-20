import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/screens/main_tabs/explore_tab.dart';
import 'package:mint_mobile/screens/coach/coach_dashboard_screen.dart';
import 'package:mint_mobile/screens/coach/coach_agir_screen.dart';
import 'package:mint_mobile/screens/profile_screen.dart';
import 'package:mint_mobile/widgets/mentor_fab.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/notification_service.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/user_activity_provider.dart';

/// Shell principal de navigation MINT Coach
///
/// Architecture 4 tabs — Sprint C10 :
/// - DASHBOARD : Tableau de bord coach (CoachDashboardScreen)
/// - AGIR : Timeline d'actions et check-in (CoachAgirScreen)
/// - APPRENDRE : Simulateurs, evenements de vie, education (ExploreTab)
/// - PROFIL : Profil utilisateur (ProfileScreen)
/// - MENTOR : Compagnon toujours accessible (FAB)
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  final AnalyticsService _analytics = AnalyticsService();
  bool _budgetLoaded = false;
  int _lastKnownSimulatorCount = 0;

  /// Timestamp when the app was last paused (backgrounded)
  DateTime? _lastPauseTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _lastPauseTime = DateTime.now();
    }
    if (state == AppLifecycleState.resumed) {
      // Check for deep link from notification tap
      final pendingRoute = NotificationService.consumePendingRoute();
      if (pendingRoute != null && pendingRoute.isNotEmpty && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            GoRouter.of(context).go(pendingRoute);
          }
        });
      }

      // Show welcome-back snackbar if away > 1 hour
      if (_lastPauseTime != null) {
        final away = DateTime.now().difference(_lastPauseTime!);
        if (away.inHours >= 1 && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bienvenue ! Tes donnees sont a jour.'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          });
        }
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_budgetLoaded) {
      _budgetLoaded = true;
      // Restaurer le budget depuis SharedPreferences si disponible
      final budgetProvider = context.read<BudgetProvider>();
      if (budgetProvider.inputs == null) {
        budgetProvider.loadFromStorage();
      }
    }
  }

  final List<Widget> _tabs = const [
    CoachDashboardScreen(),
    CoachAgirScreen(),
    ExploreTab(),
    ProfileScreen(),
  ];

  final List<String> _tabNames = const [
    'dashboard',
    'agir',
    'apprendre',
    'profil',
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

          // FAB Mentor (toujours visible, contextuel par tab)
          Positioned(
            right: 20,
            bottom: 90,
            child: MentorFAB(currentTabIndex: _currentIndex),
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
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Dashboard',
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.flash_on_outlined,
                activeIcon: Icons.flash_on,
                label: 'Agir',
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore,
                label: 'Apprendre',
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profil',
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
        onTap: () {
          if (_currentIndex != index) {
            _analytics.trackTabSwitch(_tabNames[_currentIndex], _tabNames[index]);

            // Feedback loop: snackbar au retour sur Dashboard si nouveaux simulateurs explores
            if (index == 0) {
              final activity = context.read<UserActivityProvider>();
              final currentCount = activity.exploredSimulators.length;
              if (currentCount > _lastKnownSimulatorCount && _lastKnownSimulatorCount > 0) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Recommandations mises a jour'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                });
              }
              _lastKnownSimulatorCount = currentCount;
            }

            setState(() => _currentIndex = index);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? MintColors.primary : MintColors.textMuted,
                size: 22,
              ),
              const SizedBox(height: 2),
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
