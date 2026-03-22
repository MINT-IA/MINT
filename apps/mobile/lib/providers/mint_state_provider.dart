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
import 'package:mint_mobile/services/mint_state_engine.dart';

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
  Future<void> recompute(CoachProfile profile) async {
    // Guard: skip if profile is identical to the last full computation.
    // This prevents redundant work when ChangeNotifierProxyProvider rebuilds
    // without a real profile change.
    if (profile == _lastProfile) return;

    if (_isRecomputing) {
      // Queue the latest profile — discard any previous pending call.
      _pendingRecompute = true;
      _pendingProfile = profile;
      return;
    }

    _isRecomputing = true;
    _lastProfile = profile;
    try {
      final prefs = await SharedPreferences.getInstance();
      final newState = await MintStateEngine.compute(
        profile: profile,
        prefs: prefs,
      );
      _state = newState;
      notifyListeners();
    } catch (_) {
      // Engine errors must not crash the app.
      // State remains at its previous value.
    } finally {
      _isRecomputing = false;
      if (_pendingRecompute && _pendingProfile != null) {
        _pendingRecompute = false;
        final queued = _pendingProfile!;
        _pendingProfile = null;
        // Recurse for the queued call.
        await recompute(queued);
      }
    }
  }

  /// Force-clear the state (e.g. on sign-out or data reset).
  void clear() {
    _state = null;
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
}
