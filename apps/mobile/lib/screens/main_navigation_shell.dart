import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/screens/pulse/pulse_screen.dart'
    show PulseScreen, NavigationShellState;
import 'package:mint_mobile/screens/main_tabs/mint_coach_tab.dart';
import 'package:mint_mobile/screens/profile_screen.dart';
import 'package:mint_mobile/widgets/mentor_fab.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/notification_service.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/user_activity_provider.dart';

/// Shell principal de navigation MINT V1
///
/// Architecture 3 tabs — S49 :
/// - PULSE : Ou j'en suis (score + priorite + pastilles + FRI)
/// - MINT  : Que faire (coach chat + Response Cards + simulations)
/// - MOI   : Qui je suis (fiche resumee editable + conjoint + parametres)
/// - FAB Mentor : visible sur Pulse et Moi, masque sur Mint
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

  static const List<Widget> _tabs = [
    PulseScreen(),
    MintCoachTab(),
    ProfileScreen(),
  ];

  static const List<String> _tabNames = [
    'pulse',
    'mint',
    'moi',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NavigationShellState.register(_switchTabCallback);
  }

  void _switchTabCallback(int index) {
    if (index >= 0 && index < _tabs.length && mounted) {
      setState(() => _currentIndex = index);
      _analytics.trackScreenView('/${_tabNames[index]}');
    }
  }

  @override
  void dispose() {
    NavigationShellState.unregister();
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
                SnackBar(
                  content: Text(S.of(context)!.shellWelcomeBack),
                  duration: const Duration(seconds: 3),
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
      final budgetProvider = context.read<BudgetProvider>();
      if (budgetProvider.inputs == null) {
        budgetProvider.loadFromStorage();
      }
    }

    // Auto-sync budget when profile changes
    final coachProvider = context.watch<CoachProfileProvider>();
    if (coachProvider.profileUpdatedSinceBudget && coachProvider.hasProfile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final budgetProv = context.read<BudgetProvider>();
          budgetProv.refreshFromProfile(coachProvider.profile!);
          coachProvider.markBudgetSynced();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hide FAB on Mint tab (index 1) — already the coach
    final showFab = _currentIndex != 1;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _tabs,
          ),
          if (showFab)
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
    final isCompact = MediaQuery.of(context).size.height <= 760;
    return Container(
      decoration: BoxDecoration(
        color: MintColors.white,
        boxShadow: [
          BoxShadow(
            color: MintColors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: isCompact ? 2 : 4,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.show_chart_outlined,
                activeIcon: Icons.show_chart,
                label: S.of(context)!.tabPulse,
                isCompact: isCompact,
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.chat_bubble_outline,
                activeIcon: Icons.chat_bubble,
                label: S.of(context)!.tabMint,
                isCompact: isCompact,
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: S.of(context)!.tabMoi,
                isCompact: isCompact,
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
    required bool isCompact,
  }) {
    final isActive = _currentIndex == index;

    return Expanded(
      child: Semantics(
        label: label,
        button: true,
        child: InkWell(
        onTap: () {
          if (_currentIndex != index) {
            _analytics.trackTabSwitch(
                _tabNames[_currentIndex], _tabNames[index]);

            // Feedback loop: snackbar on return to Pulse if new simulators explored
            if (index == 0) {
              final activity = context.read<UserActivityProvider>();
              final currentCount = activity.exploredSimulators.length;
              if (currentCount > _lastKnownSimulatorCount &&
                  _lastKnownSimulatorCount > 0) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text(S.of(context)!.shellRecommendationsUpdated),
                        duration: const Duration(seconds: 2),
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
          padding: EdgeInsets.symmetric(vertical: isCompact ? 4 : 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? MintColors.primary : MintColors.textMuted,
                size: isCompact ? 20 : 22,
              ),
              SizedBox(height: isCompact ? 1 : 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: isCompact ? 9 : 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color:
                      isActive ? MintColors.primary : MintColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
