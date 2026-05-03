import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/auth_provider.dart';

/// Phase 52 T-52-04 — One-time migration notification.
///
/// Detects users who registered BEFORE Phase 52 (i.e. have
/// `auth_local_mode = false` persisted) and surfaces a one-shot
/// `SnackBar` informing them about the new cloud-sync toggle in
/// Settings › Confidentialité.
///
/// Detection rule (panel spec):
///   isLoggedIn && !isLoading
///     && prefs.containsKey('auth_local_mode')
///     && prefs.getBool('auth_local_mode') == false
///     && prefs.getBool('auth_phase52_migration_shown') != true
///
/// Per D-01 the register flow no longer creates `auth_local_mode`
/// for new users (default true from initState), so the
/// `containsKey` clause naturally filters them out.
///
/// Idempotency:
///   * `auth_phase52_migration_shown` is written BEFORE showing
///     the SnackBar so a crash mid-show doesn't trigger re-show.
///   * A process-level static flag guards rebuild storms.
///
/// Test seams: [getMessenger] and [getNavContext] return the
/// `ScaffoldMessengerState` and `BuildContext` to render against;
/// production wires them to global keys, tests wire them to local
/// keys. [onCtaTap] is the navigation callback used by the action
/// chip; production calls `GoRouter.go('/settings/confidentialite')`,
/// tests assert it was called.
class MigrationNoticeListener extends StatefulWidget {
  const MigrationNoticeListener({
    super.key,
    required this.child,
    required this.getMessenger,
    required this.getNavContext,
    required this.onCtaTap,
  });

  final Widget child;
  final ScaffoldMessengerState? Function() getMessenger;
  final BuildContext? Function() getNavContext;
  final VoidCallback onCtaTap;

  /// SharedPreferences key — written before the SnackBar shows so the
  /// notice is never repeated on a clean cold start.
  static const String prefsKeyShown = 'auth_phase52_migration_shown';

  /// Phase 52.1 N-3: how long `isLoading` must be stable false before
  /// the SnackBar is allowed to fire. Prevents the toast from showing
  /// during the splash → login transition or during a profile refetch.
  /// Tests can override to `Duration.zero` for instant assertions.
  @visibleForTesting
  static Duration stabilityDelay = const Duration(seconds: 3);

  /// Process-level dedup. Exposed for tests so each test starts clean.
  @visibleForTesting
  static void resetForTesting() {
    _MigrationNoticeListenerState._shownThisProcess = false;
  }

  @override
  State<MigrationNoticeListener> createState() =>
      _MigrationNoticeListenerState();
}

class _MigrationNoticeListenerState extends State<MigrationNoticeListener> {
  static bool _shownThisProcess = false;

  AuthProvider? _bound;

  /// Phase 52.1 N-3: pending fire timer. Started when `isLoading=false`
  /// and conditions look promising; cancelled if `isLoading` flips back
  /// to true (e.g. profile refetch in flight). Only fires the SnackBar
  /// after the configured `stabilityDelay`.
  Timer? _stabilityTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    if (!identical(_bound, auth)) {
      _bound?.removeListener(_onAuthTick);
      auth.addListener(_onAuthTick);
      _bound = auth;
      _onAuthTick();
    }
  }

  @override
  void dispose() {
    _stabilityTimer?.cancel();
    _bound?.removeListener(_onAuthTick);
    super.dispose();
  }

  /// Reactive entry point. Called on every AuthProvider tick.
  /// Phase 52.1 N-3: defers the actual show by [stabilityDelay] so a
  /// transient `isLoading=true` (profile refetch, etc.) doesn't fire
  /// the SnackBar mid-transition. Cancels any pending timer if loading
  /// flips back true.
  void _onAuthTick() {
    if (_shownThisProcess) return;
    final auth = _bound;
    if (auth == null) return;
    if (auth.isLoading || !auth.isLoggedIn) {
      _stabilityTimer?.cancel();
      _stabilityTimer = null;
      return;
    }
    if (_stabilityTimer != null && _stabilityTimer!.isActive) return;
    _stabilityTimer = Timer(MigrationNoticeListener.stabilityDelay, () {
      if (!mounted) return;
      // Re-verify state at fire time — auth may have flipped during
      // the delay window.
      final a = _bound;
      if (a == null || a.isLoading || !a.isLoggedIn) return;
      _attemptShow();
    });
  }

  Future<void> _attemptShow() async {
    if (_shownThisProcess) return;
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('auth_local_mode')) return;
    if (prefs.getBool('auth_local_mode') != false) return;
    if (prefs.getBool(MigrationNoticeListener.prefsKeyShown) == true) return;
    _shownThisProcess = true;
    await prefs.setBool(MigrationNoticeListener.prefsKeyShown, true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = widget.getMessenger();
      final navContext = widget.getNavContext();
      if (messenger == null || navContext == null) return;
      final l = S.of(navContext);
      if (l == null) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.settingsPrivacyMigrationToast),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: l.settingsPrivacyMigrationToastCta,
            onPressed: widget.onCtaTap,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
