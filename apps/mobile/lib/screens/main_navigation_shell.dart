import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/providers/subscription_provider.dart';
import 'package:mint_mobile/screens/pulse/pulse_screen.dart'
    show NavigationShellState;
import 'package:mint_mobile/screens/main_tabs/mint_coach_tab.dart';
import 'package:mint_mobile/screens/main_tabs/explore_tab.dart';
import 'package:mint_mobile/screens/main_tabs/mint_home_screen.dart';
import 'package:mint_mobile/widgets/profile_drawer.dart';
import 'package:mint_mobile/models/coach_entry_payload.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/notification_service.dart';
import 'package:mint_mobile/services/session_snapshot_service.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/services/ios_iap_service.dart';

/// Shell principal de navigation MINT — Wire Spec V2
///
/// Architecture 3 tabs + drawer (WIRE_SPEC_V2.md) :
/// - MINT HOME   : Chiffre choc + leviers + cursor (MintHomeScreen)
/// - COACH       : Aide-moi à décider (chat + voice + response cards)
/// - EXPLORER    : Navigation autonome (7 hubs thématiques)
/// - DOSSIER     : Accessible via endDrawer (ProfileDrawer), not a tab
///
/// Pas de FAB global — Capture est contextuel (bottom sheet depuis Home/Coach).
///
/// Deep-link support via query param:
///   /home?tab=0  → MINT Home
///   /home?tab=1  → Coach
///   /home?tab=2  → Explorer
///   /home?tab=3  → Opens ProfileDrawer (backward compat)
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

  // Wire Spec V2: 3 tabs + drawer (not const because MintHomeScreen needs callback)
  late final List<Widget> _tabs = [
    MintHomeScreen(onSwitchToCoach: _switchToCoachWithPayload),  // 0: MINT Home
    const MintCoachTab(),   // 1: Coach
    const ExploreTab(),     // 2: Explorer
  ];

  static const List<String> _tabNames = [
    'home',
    'coach',
    'explore',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NavigationShellState.register(_switchTabCallback);

    // V5-5 audit fix: check for pending notification deep link on cold start.
    // On cold start, didChangeAppLifecycleState(resumed) is never called,
    // so we must also check here.
    // FIX-051: Defer deep link until profile is loaded to avoid crash
    // on screens that access profile data.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pendingRoute = NotificationService.consumePendingRoute();
      if (pendingRoute == null || pendingRoute.isEmpty || !mounted) return;
      try {
        final profileReady = context.read<CoachProfileProvider>().hasProfile;
        if (profileReady) {
          GoRouter.of(context).go(pendingRoute);
        } else {
          // Profile not loaded yet — store route and navigate when ready.
          // The didChangeDependencies will pick it up on next profile update.
          NotificationService.pendingRoute = pendingRoute;
        }
      } catch (_) {
        // No provider in tree — navigate anyway (auth screens don't need profile).
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

  /// Wire Spec V2: Switch to coach tab with a structured payload.
  /// Called from MintHomeScreen when user taps chiffre, lever, chip, or input bar.
  void _switchToCoachWithPayload(CoachEntryPayload? payload) {
    if (!mounted) return;
    setState(() => _currentIndex = 1); // Switch to coach tab
    _analytics.trackScreenView('/coach');
    // TODO: Pass payload to CoachChatScreen via a shared state mechanism
    // (e.g., a ValueNotifier or Provider). For now, the tab switch works
    // and the payload will be consumed in a future iteration.
    try {
      GoRouter.of(context).go('/home?tab=1');
    } catch (_) {}
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
      // FIX-W11: Check for missed deadlines (e.g. app killed before 3a reminder)
      NotificationService.checkMissedDeadlines();

      // Check for deep link from notification tap
      final pendingRoute = NotificationService.consumePendingRoute();
      if (pendingRoute != null && pendingRoute.isNotEmpty && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            GoRouter.of(context).go(pendingRoute);
          }
        });
      }

      // FIX-083: Refresh subscription state on resume (prevents stale premium).
      try {
        context.read<SubscriptionProvider>().refreshIfStale();
      } catch (_) {} // Provider may not be in tree during tests

      // FIX-W11-3: Auto-restore IAP purchases on resume (crash recovery).
      // If app crashed during purchase, user is charged but features not unlocked.
      try {
        if (IosIapService.isSupportedPlatform) {
          IosIapService.restoreAndSync();
        }
      } catch (_) {} // Best-effort, don't block resume

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
  ///
  /// Wire Spec V2 §3.4: Uses MintUserState (pre-computed by MintStateEngine)
  /// when available, so monthlyRetirementIncome and friScore are real values.
  /// Falls back to confidence-only snapshot when state is not yet computed.
  void _saveSessionSnapshot() {
    try {
      // Prefer MintUserState which already has all metrics computed.
      final mintState = context.read<MintStateProvider>().state;
      if (mintState != null) {
        SessionSnapshotService.save(SessionSnapshot(
          confidenceScore: mintState.confidenceScore,
          monthlyRetirementIncome:
              mintState.budgetGap?.totalRevenusMensuel ?? 0,
          fhsScore: mintState.friScore ?? 0,
          savedAt: DateTime.now(),
        ));
        return;
      }

      // Fallback: state not computed yet — save confidence only.
      final coachProvider = context.read<CoachProfileProvider>();
      if (!coachProvider.hasProfile) return;
      final profile = coachProvider.profile!;
      final confidence = ConfidenceScorer.score(profile);
      SessionSnapshotService.save(SessionSnapshot(
        confidenceScore: confidence.score,
        monthlyRetirementIncome: 0,
        fhsScore: 0,
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
          // Wire Spec V2: tab=3 (old Dossier) opens drawer instead
          if (tabIndex == 3) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Scaffold.of(context).openEndDrawer();
              }
            });
            // Stay on current tab, don't set _currentIndex to 3
          } else if (tabIndex >= 0 && tabIndex < _tabs.length) {
            _currentIndex = tabIndex;
          }
        }
      } catch (_) {
        // No GoRouter in tree — keep default tab 0.
      }
    }

    // FIX: Consume deferred deep link once profile becomes available.
    // When cold-start deep link fires before profile is loaded, the route
    // is stored back in NotificationService.pendingRoute and consumed here
    // on the next didChangeDependencies (triggered by Provider rebuild).
    if (NotificationService.pendingRoute != null) {
      try {
        final profileReady = context.read<CoachProfileProvider>().hasProfile;
        if (profileReady) {
          final deferred = NotificationService.consumePendingRoute();
          if (deferred != null && deferred.isNotEmpty && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) GoRouter.of(context).go(deferred);
            });
          }
        }
      } catch (_) {
        // No provider — ignore.
      }
    }

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
    // V11-3: Re-read ?tab= on every build so that subsequent go('/home?tab=3')
    // calls actually update the tab, not just the first one.
    try {
      final rawTab =
          GoRouterState.of(context).uri.queryParameters['tab'];
      if (rawTab != null) {
        final tabIndex = int.tryParse(rawTab) ?? 0;
        // Wire Spec V2: tab=3 (old Dossier) opens drawer instead
        if (tabIndex == 3) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              try {
                Scaffold.of(context).openEndDrawer();
              } catch (_) {}
            }
          });
        } else if (tabIndex >= 0 && tabIndex < _tabs.length && tabIndex != _currentIndex) {
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

    return PopScope(
      canPop: false,
      child: Scaffold(
        endDrawer: const ProfileDrawer(),
        body: IndexedStack(
          index: _currentIndex,
          children: _tabs,
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
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
