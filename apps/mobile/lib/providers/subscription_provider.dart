import 'package:flutter/foundation.dart';
import 'package:mint_mobile/services/subscription_service.dart';

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

  SubscriptionProvider()
      : _state = SubscriptionService.currentState() {
    refreshFromBackend();
  }

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
  Future<bool> upgrade([SubscriptionTier targetTier = SubscriptionTier.premium]) async {
    final success = await SubscriptionService.upgradeTo(targetTier);
    if (success) {
      _state = SubscriptionService.currentState();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Start a 14-day free trial.
  Future<bool> startTrial() async {
    final success = await SubscriptionService.startTrial();
    if (success) {
      _state = SubscriptionService.currentState();
      notifyListeners();
    }
    return success;
  }

  /// Restore previous purchases.
  Future<void> restore() async {
    _state = await SubscriptionService.restorePurchases();
    notifyListeners();
  }

  /// Refresh state from service (useful after external changes).
  void refresh() {
    _state = SubscriptionService.currentState();
    notifyListeners();
  }

  Future<void> refreshFromBackend() async {
    _state = await SubscriptionService.refreshFromBackend();
    _lastRefresh = DateTime.now();
    notifyListeners();
  }

  /// FIX-083: Refresh on app resume if last refresh was > 1 hour ago.
  /// Prevents users staying "premium" hours after expiration.
  Future<void> refreshIfStale() async {
    if (DateTime.now().difference(_lastRefresh).inHours >= 1) {
      await refreshFromBackend();
    }
  }
}
