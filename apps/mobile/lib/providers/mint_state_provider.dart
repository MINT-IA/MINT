/// MintStateProvider — reactive wrapper around [MintStateEngine].
///
/// Holds the latest [MintUserState] and notifies listeners whenever it
/// is recomputed. Consumers (Pulse tab, Coach, widgets) call:
///
///   context.watch<MintStateProvider>().state
///
/// to read the latest unified state without querying services directly.
///
/// Recomputation is triggered by calling [recompute] — typically from
/// a [CoachProfileProvider] listener in app.dart when the profile changes.
///
/// Compliance:
///   - No user-facing strings (all in ARB files via service layers).
///   - No identifiable data stored in this provider.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/mint_user_state.dart';
import 'package:mint_mobile/services/coach/precomputed_insights_service.dart';
import 'package:mint_mobile/services/mint_state_engine.dart';
import 'package:mint_mobile/services/session_epoch.dart';

typedef MintStateCompute = Future<MintUserState> Function(
  CoachProfile profile,
  SharedPreferences prefs,
);

/// Reactive provider for the unified [MintUserState].
///
/// State lifecycle:
///   1. App start: [state] is null. Consumers show loading/empty states.
///   2. CoachProfileProvider loads profile → [recompute] called.
///   3. [state] becomes non-null → all consumers update.
///   4. Profile changes → [recompute] called again → [state] updates.
///
/// Thread safety: [recompute] is guarded against concurrent calls.
/// Rapid successive calls are debounced: a new call cancels the in-flight one
/// by tracking [_isRecomputing] and queuing at most one pending recompute.
class MintStateProvider extends ChangeNotifier {
  MintStateProvider({
    SessionEpoch? sessionEpoch,
    MintStateCompute? computeState,
  })  : _sessionEpoch = sessionEpoch ?? SessionEpoch(),
        _computeState = computeState ?? _defaultComputeState;

  final SessionEpoch _sessionEpoch;
  final MintStateCompute _computeState;
  MintUserState? _state;
  bool _isRecomputing = false;
  bool _pendingRecompute = false;
  CoachProfile? _pendingProfile;

  /// Last profile used for a full recomputation.
  ///
  /// Guards against redundant work when [ChangeNotifierProxyProvider] calls
  /// [recompute] on every rebuild even if the profile has not changed.
  CoachProfile? _lastProfile;

  /// The latest unified user state. Null until first [recompute] completes.
  MintUserState? get state => _state;

  /// True when a recomputation is in progress.
  bool get isRecomputing => _isRecomputing;

  /// True when a state has been computed at least once.
  bool get hasState => _state != null;

  /// Recompute state from [profile].
  ///
  /// If a recomputation is already in progress, the new call is queued and
  /// will run immediately after the current one completes.
  ///
  /// Safe to call on every profile update — rapid calls collapse to one.
  /// Calls with a profile identical to the last computed profile are no-ops.
  /// Use [forceRecompute] when non-profile state changed (e.g. goal selection).
  Future<void> recompute(CoachProfile profile) async {
    // Guard: skip if profile is identical to the last full computation.
    // This prevents redundant work when ChangeNotifierProxyProvider rebuilds
    // without a real profile change.
    if (profile == _lastProfile) return;
    return _doRecompute(profile);
  }

  /// Force recompute even if profile hasn't changed.
  /// Use when non-profile state changed (goal selection, cap completion, etc.).
  Future<void> forceRecompute(CoachProfile profile) async {
    return _doRecompute(profile);
  }

  Future<void> _doRecompute(CoachProfile profile) async {
    late final SessionEpochGuard sessionGuard;
    try {
      sessionGuard = _sessionEpoch.capture();
    } on SessionEpochInvalidated {
      return;
    }
    if (_isRecomputing) {
      // Queue the latest profile — discard any previous pending call.
      _pendingRecompute = true;
      _pendingProfile = profile;
      return;
    }

    _isRecomputing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      sessionGuard.assertCurrent();
      final newState = await _computeState(profile, prefs);
      sessionGuard.assertCurrent();
      await _sessionEpoch.runGuardedPersistence(
        sessionGuard,
        () => PrecomputedInsightsService.computeAndCache(
          state: newState,
          prefs: prefs,
          beforeWrite: sessionGuard.assertCurrent,
        ),
      );
      sessionGuard.assertCurrent();
      _state = newState;
      // Mark this profile as successfully computed AFTER state is set.
      // If _doRecompute throws, _lastProfile stays at its previous value,
      // so the next recompute(sameProfile) will retry instead of no-op.
      _lastProfile = profile;
      sessionGuard.assertCurrent();
      notifyListeners();
    } on SessionEpochInvalidated {
      // Session termination owns the clear/purge boundary. Old account work
      // must not publish, cache, log an error, or alter a new session's flags.
    } catch (e) {
      if (!_isCurrent(sessionGuard)) return;
      debugPrint('[MintStateProvider] Recompute error: $e');
      // Engine errors must not crash the app.
      // State remains at its previous value.
      // _lastProfile is NOT set here — next call with same profile will retry.
    } finally {
      if (_isCurrent(sessionGuard)) {
        _isRecomputing = false;
        if (_pendingRecompute && _pendingProfile != null) {
          _pendingRecompute = false;
          final queued = _pendingProfile!;
          _pendingProfile = null;
          // Recurse for the queued call — use _doRecompute to bypass the
          // identical-profile guard. The queued call may have come from
          // forceRecompute, which must always run regardless of _lastProfile.
          await _doRecompute(queued);
        }
      }
    }
  }

  /// Force-clear the state (e.g. on sign-out or data reset).
  Future<void> clear() async {
    // Cache deletion belongs to the session-termination transaction. Do not
    // publish an empty provider until the durable old-account cache is gone;
    // a failed deletion keeps the coordinator blocked with memory untouched.
    final prefs = await SharedPreferences.getInstance();
    await PrecomputedInsightsService.clear(prefs);
    _state = null;
    _isRecomputing = false;
    _pendingRecompute = false;
    _pendingProfile = null;
    _lastProfile = null;
    notifyListeners();
  }

  /// Inject a pre-built state for widget tests.
  ///
  /// Allows tests to seed [MintUserState] without running the full
  /// [MintStateEngine] pipeline. Production code must never call this.
  @visibleForTesting
  void injectStateForTest(MintUserState state) {
    _state = state;
    notifyListeners();
  }

  static Future<MintUserState> _defaultComputeState(
    CoachProfile profile,
    SharedPreferences prefs,
  ) =>
      MintStateEngine.compute(profile: profile, prefs: prefs);

  static bool _isCurrent(SessionEpochGuard guard) {
    try {
      guard.assertCurrent();
      return true;
    } on SessionEpochInvalidated {
      return false;
    }
  }
}
