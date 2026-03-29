import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/screens/pulse/pulse_screen.dart'
    show PulseScreen, NavigationShellState;
import 'package:mint_mobile/screens/main_tabs/mint_coach_tab.dart';
import 'package:mint_mobile/screens/main_tabs/explore_tab.dart';
import 'package:mint_mobile/screens/main_tabs/dossier_tab.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/notification_service.dart';
import 'package:mint_mobile/services/session_snapshot_service.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';

/// Shell principal de navigation MINT — S52 UX Cohesion
///
/// Architecture 4 tabs (NAVIGATION_GRAAL_V10.md) :
/// - AUJOURD'HUI : Où j'en suis (1 phrase + 1 chiffre + 1 action + 2 signaux)
/// - COACH       : Aide-moi à décider (chat + voice + response cards)
/// - EXPLORER    : Navigation autonome (7 hubs thématiques)
/// - DOSSIER     : Mes données (profil + documents + couple + réglages)
///
/// Pas de FAB global — Capture est contextuel (bottom sheet depuis Aujourd'hui/Coach).
///
/// Deep-link support via query param:
///   /home?tab=0  → Aujourd'hui
///   /home?tab=1  → Coach
///   /home?tab=2  → Explorer
///   /home?tab=3  → Dossier
/// Convenience aliases: /app/today, /app/coach, /app/explore, /app/dossier
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
  bool _tabIndexResolved = false;

  /// Timestamp when the app was last paused (backgrounded).
  DateTime? _lastPauseTime;

  static const List<Widget> _tabs = [
    PulseScreen(),    // 0: Aujourd'hui
    MintCoachTab(),   // 1: Coach
    ExploreTab(),     // 2: Explorer
    DossierTab(),     // 3: Dossier
  ];

  static const List<String> _tabNames = [
    'today',
    'coach',
    'explore',
    'dossier',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NavigationShellState.register(_switchTabCallback);

    // V5-5 audit fix: check for pending notification deep link on cold start.
    // On cold start, didChangeAppLifecycleState(resumed) is never called,
    // so we must also check here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pendingRoute = NotificationService.consumePendingRoute();
      if (pendingRoute != null && pendingRoute.isNotEmpty && mounted) {
        GoRouter.of(context).go(pendingRoute);
      }
    });
  }

  void _switchTabCallback(int index) {
    if (index >= 0 && index < _tabs.length && mounted) {
      setState(() => _currentIndex = index);
      _analytics.trackScreenView('/${_tabNames[index]}');
      // Sync URL for programmatic tab switches (e.g. from PulseScreen).
      try {
        GoRouter.of(context).go('/home?tab=$index');
      } catch (_) {
        // No GoRouter in tree (unit tests).
      }
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
      _saveSessionSnapshot();
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

      // Show delta snackbar if away > 1 hour and state changed
      if (_lastPauseTime != null) {
        final away = DateTime.now().difference(_lastPauseTime!);
        if (away.inHours >= 1 && mounted) {
          _showDeltaOnResume();
        }
      }
    }
  }

  /// Persist a lightweight snapshot of key metrics on app pause.
  void _saveSessionSnapshot() {
    try {
      final coachProvider = context.read<CoachProfileProvider>();
      if (!coachProvider.hasProfile) return;
      final profile = coachProvider.profile!;
      final confidence = ConfidenceScorer.score(profile);
      SessionSnapshotService.save(SessionSnapshot(
        confidenceScore: confidence.score,
        monthlyRetirementIncome: 0, // Computed lazily on resume
        fhsScore: 0, // FHS tracked separately via FhsDailyScore
        savedAt: DateTime.now(),
      ));
    } catch (_) {}
  }

  /// On resume, compare current confidence vs saved snapshot.
  void _showDeltaOnResume() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final previous = await SessionSnapshotService.load();
      if (previous == null) {
        // First session — show generic welcome back
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(S.of(context)!.shellWelcomeBack),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      try {
        if (!mounted) return;
        final coachProvider = context.read<CoachProfileProvider>();
        if (!coachProvider.hasProfile) return;
        final profile = coachProvider.profile!;
        final currentConfidence = ConfidenceScorer.score(profile).score;
        final delta = SessionSnapshotService.computeDelta(
          previous: previous,
          currentConfidence: currentConfidence,
          currentMonthlyRetirement: 0,
          currentFhs: 0,
        );

        if (!mounted) return;
        if (delta.isSignificant) {
          final msg = delta.confidenceDelta >= 3
              ? S.of(context)!.shellWelcomeBackDeltaPts(delta.confidenceDelta.round())
              : S.of(context)!.shellWelcomeBack;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(S.of(context)!.shellWelcomeBack),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (_) {
        // Fallback to generic welcome back
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(S.of(context)!.shellWelcomeBack),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Resolve the initial tab from the ?tab= query parameter (deep-link support).
    // Only runs once — subsequent route changes within the shell do NOT reset the tab.
    // GoRouterState.of() throws a StateError when no GoRouter is present (e.g. in
    // tests that use plain MaterialApp(home:)); we catch that and keep the default.
    if (!_tabIndexResolved) {
      _tabIndexResolved = true;
      try {
        final rawTab =
            GoRouterState.of(context).uri.queryParameters['tab'];
        if (rawTab != null) {
          final tabIndex = int.tryParse(rawTab) ?? 0;
          if (tabIndex >= 0 && tabIndex < _tabs.length) {
            _currentIndex = tabIndex;
          }
        }
      } catch (_) {
        // No GoRouter in tree — keep default tab 0.
      }
    }

    if (!_budgetLoaded) {
      _budgetLoaded = true;
      final budgetProvider = context.read<BudgetProvider>();
      if (budgetProvider.inputs == null) {
        budgetProvider.loadFromStorage();
      }
    }

    // Auto-sync budget when profile changes.
    // FIX-029: use context.select to only rebuild when the sync flag changes,
    // not on every notifyListeners() from CoachProfileProvider.
    final needsBudgetSync = context.select<CoachProfileProvider, bool>(
      (p) => p.profileUpdatedSinceBudget && p.hasProfile,
    );
    if (needsBudgetSync) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final coachProv = context.read<CoachProfileProvider>();
          final budgetProv = context.read<BudgetProvider>();
          budgetProv.refreshFromProfile(coachProv.profile!);
          coachProv.markBudgetSynced();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // V11-3: Re-read ?tab= on every build so that subsequent go('/home?tab=3')
    // calls actually update the tab, not just the first one.
    try {
      final rawTab =
          GoRouterState.of(context).uri.queryParameters['tab'];
      if (rawTab != null) {
        final tabIndex = int.tryParse(rawTab) ?? 0;
        if (tabIndex >= 0 && tabIndex < _tabs.length && tabIndex != _currentIndex) {
          // Schedule the state update to avoid calling setState during build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _currentIndex != tabIndex) {
              setState(() => _currentIndex = tabIndex);
            }
          });
        }
      }
    } catch (_) {
      // No GoRouter in tree (unit tests).
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final l = S.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: MintColors.porcelaine,
        border: Border(
          top: BorderSide(
            color: MintColors.textPrimary.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                index: 0,
                currentIndex: _currentIndex,
                icon: Icons.today_outlined,
                activeIcon: Icons.today,
                label: l.tabToday,
                onTap: () => _onTap(0),
              ),
              _NavItem(
                index: 1,
                currentIndex: _currentIndex,
                icon: Icons.chat_bubble_outline,
                activeIcon: Icons.chat_bubble,
                label: l.tabMint,
                onTap: () => _onTap(1),
              ),
              _NavItem(
                index: 2,
                currentIndex: _currentIndex,
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore,
                label: l.tabExplore,
                onTap: () => _onTap(2),
              ),
              _NavItem(
                index: 3,
                currentIndex: _currentIndex,
                icon: Icons.folder_outlined,
                activeIcon: Icons.folder,
                label: l.tabDossier,
                onTap: () => _onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTap(int index) {
    if (_currentIndex == index) return;
    _analytics.trackTabSwitch(_tabNames[_currentIndex], _tabNames[index]);
    setState(() => _currentIndex = index);
    // Keep the URL in sync so deep links and state restoration work after
    // the initial mount.  We use `go` (not `push`) because the shell is
    // the root destination — we replace the current URL, never stack.
    try {
      GoRouter.of(context).go('/home?tab=$index');
    } catch (_) {
      // No GoRouter in tree (unit tests with plain MaterialApp).
    }
  }
}

/// Single bottom nav item — minimal, clean.
class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == index;
    return Expanded(
      child: Semantics(
        label: label,
        button: true,
        selected: isActive,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  color: isActive ? MintColors.primary : MintColors.textSecondary,
                  size: 22,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: MintTextStyles.labelSmall(
                    color: isActive
                        ? MintColors.primary
                        : MintColors.textSecondary,
                  ).copyWith(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
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
