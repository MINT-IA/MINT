import 'package:flutter/foundation.dart';
import 'package:mint_mobile/services/subscription_service.dart';
import 'package:mint_mobile/services/session_epoch.dart';

/// Provider wrapping [SubscriptionService] for reactive UI updates.
///
/// Usage with Provider:
/// ```dart
/// ChangeNotifierProvider(
///   create: (_) => SubscriptionProvider(),
/// ),
/// ```
///
/// Access in widgets:
/// ```dart
/// final sub = context.watch<SubscriptionProvider>();
/// if (sub.isPaid) { ... }
/// ```
class SubscriptionProvider extends ChangeNotifier {
  SubscriptionState _state;
  DateTime _lastRefresh = DateTime.now();
  bool _isRefreshing = false;

  SubscriptionProvider({SessionEpoch? sessionEpoch})
      : _sessionEpoch = sessionEpoch ?? SessionEpoch(),
        _state = const SubscriptionState(
          tier: SubscriptionTier.free,
          source: SubscriptionSource.mock,
        );

  final SessionEpoch _sessionEpoch;

  /// Current subscription state.
  SubscriptionState get state => _state;

  /// Current tier.
  SubscriptionTier get tier => _state.tier;

  /// Whether the user has any paid tier active (starter, premium, or couplePlus).
  bool get isPaid => _state.tier.isPaid && _state.isActive;

  /// Legacy alias: whether the user has a paid subscription.
  /// Kept for backward compatibility with existing UI code.
  bool get isCoach => isPaid;

  /// Whether the user is on a free trial.
  bool get isTrial => _state.isTrialActive;

  /// Days remaining in trial (0 if not on trial).
  int get trialDaysRemaining => _state.trialDaysRemaining;

  /// Check if a specific Coach feature is accessible.
  bool hasAccess(CoachFeature feature) {
    return SubscriptionService.hasAccess(feature);
  }

  /// Upgrade to a specific tier (defaults to premium for backward compat).
  Future<bool> upgrade(
      [SubscriptionTier targetTier = SubscriptionTier.premium]) async {
    final guard = _sessionEpoch.capture();
    final success = await _sessionEpoch.runGuardedPersistence(
      guard,
      () => SubscriptionService.upgradeTo(targetTier),
    );
    guard.assertCurrent();
    if (success) {
      _state = SubscriptionService.currentState();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Start a 14-day free trial.
  Future<bool> startTrial() async {
    final guard = _sessionEpoch.capture();
    final success = await _sessionEpoch.runGuardedPersistence(
      guard,
      SubscriptionService.startTrial,
    );
    guard.assertCurrent();
    if (success) {
      _state = SubscriptionService.currentState();
      notifyListeners();
    }
    return success;
  }

  /// Restore previous purchases.
  Future<void> restore() async {
    final guard = _sessionEpoch.capture();
    final state = await _sessionEpoch.runGuardedPersistence(
      guard,
      SubscriptionService.restorePurchases,
    );
    guard.assertCurrent();
    _state = state;
    notifyListeners();
  }

  /// Refresh state from service (useful after external changes).
  void refresh() {
    if (_sessionEpoch.isTerminationBlocked) return;
    _state = SubscriptionService.currentState();
    notifyListeners();
  }

  Future<void> refreshFromBackend() async {
    if (_isRefreshing) return;
    final guard = _sessionEpoch.capture();
    _isRefreshing = true;
    try {
      final state = await SubscriptionService.refreshFromBackend();
      guard.assertCurrent();
      _state = state;
      _lastRefresh = DateTime.now();
      notifyListeners();
    } on SessionEpochInvalidated {
      return;
    } finally {
      try {
        guard.assertCurrent();
        _isRefreshing = false;
      } on SessionEpochInvalidated {
        // Session clear owns the state.
      }
    }
  }

  /// FIX-083 + FIX-W11-3: Refresh on app resume if last refresh was > 15 min ago.
  /// Reduced from 1 hour to 15 minutes for cross-device subscription consistency.
  Future<void> refreshIfStale() async {
    if (DateTime.now().difference(_lastRefresh).inMinutes >= 15) {
      await refreshFromBackend();
    }
  }

  void clearSessionMemoryAfterPurge() {
    SubscriptionService.resetToDefault();
    _state = SubscriptionService.currentState();
    _isRefreshing = false;
    _lastRefresh = DateTime.now();
    notifyListeners();
  }
}
