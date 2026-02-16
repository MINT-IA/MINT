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
/// if (sub.isCoach) { ... }
/// ```
class SubscriptionProvider extends ChangeNotifier {
  SubscriptionState _state;

  SubscriptionProvider()
      : _state = SubscriptionService.currentState();

  /// Current subscription state.
  SubscriptionState get state => _state;

  /// Current tier.
  SubscriptionTier get tier => _state.tier;

  /// Whether the user has Coach tier (paid or trial).
  bool get isCoach => _state.tier == SubscriptionTier.coach && _state.isActive;

  /// Whether the user is on a free trial.
  bool get isTrial => _state.isTrialActive;

  /// Days remaining in trial (0 if not on trial).
  int get trialDaysRemaining => _state.trialDaysRemaining;

  /// Check if a specific Coach feature is accessible.
  bool hasAccess(CoachFeature feature) {
    return SubscriptionService.hasAccess(feature);
  }

  /// Upgrade to Coach tier.
  Future<void> upgrade() async {
    final success = await SubscriptionService.upgradeTo(SubscriptionTier.coach);
    if (success) {
      _state = SubscriptionService.currentState();
      notifyListeners();
    }
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
}
